package com.backpackr.controller;

import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.file.Files;
import java.util.Arrays;
import java.util.HashSet;
import java.util.Set;
import java.util.UUID;

import com.backpackr.dao.PlaceDAO;
import com.backpackr.model.Place;
import com.backpackr.model.User;
import com.backpackr.util.GoogleMapsLinkParser;
import com.backpackr.util.UploadPaths;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.MultipartConfig;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;
import jakarta.servlet.http.Part;

@WebServlet("/addPlace")
@MultipartConfig(
    maxFileSize = 10 * 1024 * 1024,      // 10 MB per file
    maxRequestSize = 15 * 1024 * 1024,   // 15 MB per request
    fileSizeThreshold = 1024 * 1024      // 1 MB buffered in memory before disk
)
public class AddPlaceServlet extends HttpServlet {

    private static final long serialVersionUID = 1L;
    private PlaceDAO placeDAO = new PlaceDAO();

    private static final Set<String> ALLOWED_IMAGE_EXTENSIONS =
        new HashSet<>(Arrays.asList("jpg", "jpeg", "png", "gif", "webp"));

    // NEW FEATURE (Multi-user duplicate-place prevention): while the user is
    // deciding, on place_exists.jsp, whether to view the existing place or
    // merge their submission into it, the not-yet-saved Place (and which
    // existing PLACE_ID it matched) are held here rather than in a hidden
    // form field, so a re-submitted multipart image doesn't need to be
    // re-uploaded and no submitted text can be tampered with client-side.
    private static final String PENDING_PLACE_SESSION_KEY = "pendingPlaceContribution";
    private static final String PENDING_EXISTING_ID_SESSION_KEY = "pendingExistingPlaceId";

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        HttpSession session = request.getSession(false);
        User user = (session != null) ? (User) session.getAttribute("currentUser") : null;

        if (user == null) {
            response.sendRedirect("login.jsp");
            return;
        }

        // NEW FEATURE (Multi-user duplicate-place prevention): handle the
        // two buttons on place_exists.jsp before touching any of the normal
        // "add a new place" form-parsing logic below - neither of these
        // needs (or receives) the full add-place form fields again.
        String confirmAction = request.getParameter("confirmAction");
        if ("cancel".equals(confirmAction)) {
            discardPendingContribution(session);
            response.sendRedirect("add_place.jsp?error=" + urlSafe("No changes made - feel free to try again"));
            return;
        }
        if ("contribute".equals(confirmAction)) {
            handleConfirmedContribution(request, response, session, user);
            return;
        }

        try {
            Place place = new Place();
            place.setPlaceName(trimOrNull(request.getParameter("placeName")));
            place.setCategory(trimOrNull(request.getParameter("category")));
            place.setDescription(trimOrNull(request.getParameter("description")));
            place.setDistrict(trimOrNull(request.getParameter("district")));
            place.setState(trimOrNull(request.getParameter("state")));
            place.setAddress(trimOrNull(request.getParameter("address")));
            place.setMapsLink(trimOrNull(request.getParameter("mapsLink")));
            // BUG FIX (Security - XSS via javascript: URL): _place_card.jsp
            // renders MAPS_LINK as a clickable <a href>. Without this
            // check, someone could paste "javascript:..." instead of an
            // actual maps link and it would run in any visitor's browser
            // the moment they clicked "View on Google Maps". Only genuine
            // http(s) links are kept; anything else is silently dropped
            // (not a hard validation error - it just means no maps link
            // gets saved, exactly as if the field had been left blank).
            if (place.getMapsLink() != null
                    && !place.getMapsLink().startsWith("http://")
                    && !place.getMapsLink().startsWith("https://")) {
                place.setMapsLink(null);
            }
            place.setOpeningTime(trimOrNull(request.getParameter("openingTime")));
            place.setBestTime(trimOrNull(request.getParameter("bestTime")));
            place.setAddedBy(user.getUserId());

            String latStr = request.getParameter("latitude");
            String lngStr = request.getParameter("longitude");
            String costStr = request.getParameter("estimatedCost");

            place.setLatitude(parseDoubleOrZero(latStr));
            place.setLongitude(parseDoubleOrZero(lngStr));
            place.setAvgCost(parseDoubleOrZero(costStr));

            // BUG FIX (Location accuracy): the lat/lng text fields used to
            // silently default to 0.0 whenever they were left blank or
            // typed wrong, and nothing stopped that (0, 0) from being
            // saved - which is why places were showing up on the map out
            // in the ocean near Africa (0 N, 0 E) instead of anywhere near
            // Kerala. If no usable coordinates were typed in, try pulling
            // them out of the pasted Google Maps link instead (most people
            // can share a Maps link far more easily than type exact
            // decimal coordinates). If we still don't have anything
            // plausible after that, reject the submission with a clear
            // message rather than quietly saving a place nobody will ever
            // be able to find on the map.
            if (place.getPlaceName() == null || place.getCategory() == null
                    || place.getDistrict() == null || place.getState() == null) {
                response.sendRedirect("add_place.jsp?error=Please+fill+in+all+required+fields");
                return;
            }

            boolean hasTypedCoordinates = isPlausibleCoordinate(place.getLatitude(), place.getLongitude());
            if (!hasTypedCoordinates && place.getMapsLink() != null) {
                GoogleMapsLinkParser.LatLng extracted = GoogleMapsLinkParser.extract(place.getMapsLink());
                if (extracted != null) {
                    place.setLatitude(extracted.latitude);
                    place.setLongitude(extracted.longitude);
                    hasTypedCoordinates = true;
                }
            }
            if (!hasTypedCoordinates) {
                response.sendRedirect("add_place.jsp?error="
                        + urlSafe("Please enter accurate coordinates, or paste a Google Maps link we can read them from"));
                return;
            }

            // NEW FEATURE (Multi-user duplicate-place prevention): before
            // creating a new PLACES row, check whether a place already
            // exists at (essentially) this same physical location - using
            // the coordinates just validated above, not the typed name,
            // since different users may name the same spot differently.
            // Small GPS/geocoding drift is tolerated via a configurable
            // radius (see PlaceDAO.findNearbyDuplicate()).
            Place existingNearby = placeDAO.findNearbyDuplicate(place.getLatitude(), place.getLongitude());

            // Handle the uploaded photo (optional, but recommended). This has
            // to happen now regardless of which path we take below - an
            // uploaded file's Part can only be read once per request, so it
            // can't be deferred until after the user picks "view" vs.
            // "contribute" on place_exists.jsp.
            String savedImagePath = handleImageUpload(request);

            if (existingNearby != null) {
                // Don't create a duplicate record. Stash what was typed (and
                // any uploaded photo path) in the session and let the user
                // choose, on place_exists.jsp, whether to view the existing
                // place or merge their info into it.
                place.setImageUrl(savedImagePath);
                session.setAttribute(PENDING_PLACE_SESSION_KEY, place);
                session.setAttribute(PENDING_EXISTING_ID_SESSION_KEY, existingNearby.getPlaceId());
                response.sendRedirect("place_exists.jsp?existingId=" + existingNearby.getPlaceId());
                return;
            }

            place.setImageUrl(savedImagePath != null ? savedImagePath
                    : "https://placehold.co/600x400?text=" + urlSafe(place.getPlaceName()));

            int placeId = placeDAO.createPlace(place);

            if (placeId > 0) {
                response.sendRedirect("home.jsp?success=Thanks!+Your+place+is+now+live+and+searchable");
            } else {
                response.sendRedirect("add_place.jsp?error=Could+not+save+your+place,+please+try+again");
            }
        } catch (IllegalArgumentException e) {
            response.sendRedirect("add_place.jsp?error=" + urlSafe(e.getMessage()));
        } catch (Exception e) {
            e.printStackTrace();
            response.sendRedirect("add_place.jsp?error=Unexpected+error+while+submitting+your+place");
        }
    }

    // Saves the uploaded image under webapp/uploads and returns the relative
    // web path to store on the Place record, or null if no file was sent.
    private String handleImageUpload(HttpServletRequest request)
            throws IOException, ServletException {

        Part filePart = request.getPart("image");

        if (filePart == null || filePart.getSize() == 0) {
            return null;
        }

        // BUG FIX (Security - Code Review: unrestricted file upload): the
        // <input type="file" accept="image/*"> on add_place.jsp is a
        // client-side hint only - nothing stopped a direct POST from
        // uploading any file type (a .html, .jsp, .exe, etc.) and having it
        // saved and served back out under /uploads/*. This now checks both
        // the browser-supplied content type and the file extension against
        // an allow-list of common image formats and rejects anything else
        // before it's written to disk.
        String contentType = filePart.getContentType();
        if (contentType == null || !contentType.toLowerCase().startsWith("image/")) {
            throw new IllegalArgumentException("Only+image+files+can+be+uploaded");
        }

        String originalNameCheck = filePart.getSubmittedFileName();
        String extCheck = (originalNameCheck != null && originalNameCheck.contains("."))
                ? originalNameCheck.substring(originalNameCheck.lastIndexOf(".") + 1).toLowerCase()
                : "";
        if (!ALLOWED_IMAGE_EXTENSIONS.contains(extCheck)) {
            throw new IllegalArgumentException("Unsupported+image+file+type");
        }

        // BUG FIX (Bug 1): save to a stable, absolute folder outside the
        // deployed web app instead of getServletContext().getRealPath(),
        // so the file is always reachable at /uploads/<name> regardless of
        // how Eclipse/Tomcat publishes the project. See UploadPaths and
        // UploadedImageServlet (mapped to /uploads/*) for the serving side.
        File uploadDir = UploadPaths.getExternalUploadDir();

        System.out.println("UPLOAD DIRECTORY = " + uploadDir.getAbsolutePath());

        String originalName = filePart.getSubmittedFileName();

        String extension = "";

        if (originalName != null && originalName.contains(".")) {
            extension = originalName.substring(originalName.lastIndexOf("."));
        }

        String fileName = "place_" + UUID.randomUUID() + extension;

        File targetFile = new File(uploadDir, fileName);

        System.out.println("FILE WILL BE SAVED AS = "
                + targetFile.getAbsolutePath());

        try (InputStream in = filePart.getInputStream();
             OutputStream out = Files.newOutputStream(targetFile.toPath())) {

            in.transferTo(out);
        }

        System.out.println("IMAGE SAVED SUCCESSFULLY");
        System.out.println("Exists = " + targetFile.exists());

        return "uploads/" + fileName;
    }

    // NEW FEATURE (Multi-user duplicate-place prevention): called when the
    // user clicks "Add my info to this place" on place_exists.jsp. Pulls
    // the pending submission back out of the session (never trusts a
    // resubmitted form for the place details - only the existingPlaceId is
    // read from the request, and even that is cross-checked against what
    // was actually matched at submission time) and merges it into the
    // existing place via PlaceDAO.addContribution().
    private void handleConfirmedContribution(HttpServletRequest request, HttpServletResponse response,
            HttpSession session, User user) throws IOException {

        Place pending = (Place) session.getAttribute(PENDING_PLACE_SESSION_KEY);
        Integer pendingExistingId = (Integer) session.getAttribute(PENDING_EXISTING_ID_SESSION_KEY);
        String existingIdParam = request.getParameter("existingPlaceId");

        if (pending == null || pendingExistingId == null || existingIdParam == null
                || !existingIdParam.trim().equals(String.valueOf(pendingExistingId))) {
            discardPendingContribution(session);
            response.sendRedirect("add_place.jsp?error=" + urlSafe("That request has expired, please try again"));
            return;
        }

        boolean ok = placeDAO.addContribution(pendingExistingId, pending, user.getUserId());
        session.removeAttribute(PENDING_PLACE_SESSION_KEY);
        session.removeAttribute(PENDING_EXISTING_ID_SESSION_KEY);

        if (ok) {
            response.sendRedirect("home.jsp?placeId=" + pendingExistingId
                    + "&success=" + urlSafe("Thanks! Your info was added to the existing place"));
        } else {
            response.sendRedirect("add_place.jsp?error=" + urlSafe("Could not add your contribution, please try again"));
        }
    }

    // Drops a pending (not-yet-saved) contribution - used both when the user
    // explicitly cancels on place_exists.jsp and when a contribute attempt
    // can't be trusted (see handleConfirmedContribution()). Best-effort
    // deletes any photo that was already written to disk for it, so
    // cancelled submissions don't leave orphaned files behind.
    private void discardPendingContribution(HttpSession session) {
        if (session == null) {
            return;
        }
        Place pending = (Place) session.getAttribute(PENDING_PLACE_SESSION_KEY);
        if (pending != null && pending.getImageUrl() != null && pending.getImageUrl().startsWith("uploads/")) {
            try {
                File uploaded = new File(UploadPaths.getExternalUploadDir(),
                        pending.getImageUrl().substring("uploads/".length()));
                if (uploaded.exists()) {
                    uploaded.delete();
                }
            } catch (Exception ignored) {
                // Best-effort cleanup only - a leftover file is harmless.
            }
        }
        session.removeAttribute(PENDING_PLACE_SESSION_KEY);
        session.removeAttribute(PENDING_EXISTING_ID_SESSION_KEY);
    }

    private String trimOrNull(String value) {
        if (value == null) return null;
        String t = value.trim();
        return t.isEmpty() ? null : t;
    }

    private double parseDoubleOrZero(String value) {
        try {
            return value == null || value.trim().isEmpty() ? 0.0 : Double.parseDouble(value.trim());
        } catch (NumberFormatException e) {
            return 0.0;
        }
    }

    // BUG FIX (Location accuracy): a small sanity check used to decide
    // whether typed/extracted coordinates are worth trusting - rules out
    // the (0, 0) "null island" default and anything outside real
    // lat/lng range.
    private boolean isPlausibleCoordinate(double lat, double lng) {
        return (lat != 0.0 || lng != 0.0)
                && lat >= -90 && lat <= 90
                && lng >= -180 && lng <= 180;
    }

    private String urlSafe(String value) {
        return value.replace(" ", "+");
    }
}
