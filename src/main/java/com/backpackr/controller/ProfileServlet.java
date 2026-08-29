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
import java.util.regex.Pattern;

import com.backpackr.dao.UserDAO;
import com.backpackr.model.User;
import com.backpackr.util.UploadPaths;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.MultipartConfig;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;
import jakarta.servlet.http.Part;

/**
 * NEW FEATURE (Profile enhancements): profile.jsp was previously read-only
 * (just displayed name/email/mobile/join date and a few stat counts, with
 * no way to change any of it, and no profile photo support at all). This
 * servlet handles both new actions the enhanced profile.jsp form submits:
 *   action=updateInfo  - name / email / mobile number
 *   action=uploadPhoto - a profile picture (multipart)
 *
 * Password changes are intentionally NOT handled here - see UserDAO's
 * updateProfile() comment for why that's kept as a separate concern.
 */
@WebServlet("/profile")
@MultipartConfig(
    maxFileSize = 5 * 1024 * 1024,       // 5 MB - profile photos don't need to be huge
    maxRequestSize = 6 * 1024 * 1024,
    fileSizeThreshold = 1024 * 1024
)
public class ProfileServlet extends HttpServlet {

    private static final long serialVersionUID = 1L;
    private final UserDAO userDAO = new UserDAO();

    private static final Set<String> ALLOWED_IMAGE_EXTENSIONS =
        new HashSet<>(Arrays.asList("jpg", "jpeg", "png", "gif", "webp"));

    private static final Pattern EMAIL_PATTERN =
        Pattern.compile("^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$");

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        HttpSession session = request.getSession(false);
        User user = (session != null) ? (User) session.getAttribute("currentUser") : null;

        if (user == null) {
            response.sendRedirect("login.jsp");
            return;
        }

        String action = request.getParameter("action");

        try {
            if ("uploadPhoto".equals(action)) {
                handleUploadPhoto(request, response, session, user);
            } else {
                handleUpdateInfo(request, response, session, user);
            }
        } catch (IllegalArgumentException e) {
            String section = "uploadPhoto".equals(action) ? "photo" : "details";
            response.sendRedirect("profile.jsp?section=" + section + "&error=" + urlSafe(e.getMessage()));
        } catch (Exception e) {
            e.printStackTrace();
            response.sendRedirect("profile.jsp?error=Unexpected+error+while+updating+your+profile");
        }
    }

    private void handleUpdateInfo(HttpServletRequest request, HttpServletResponse response,
            HttpSession session, User user) throws IOException {

        String name = trim(request.getParameter("name"));
        String email = trim(request.getParameter("email"));
        String mobile = trim(request.getParameter("mobileNumber"));

        // Same validation shape as RegisterServlet - required fields,
        // plausible email, plausible mobile number.
        if (name == null || name.isEmpty() || email == null || email.isEmpty()) {
            response.sendRedirect("profile.jsp?section=details&error=Name+and+email+are+required");
            return;
        }
        if (!EMAIL_PATTERN.matcher(email).matches()) {
            response.sendRedirect("profile.jsp?section=details&error=Please+enter+a+valid+email+address");
            return;
        }
        if (mobile != null && !mobile.isEmpty() && !mobile.matches("[0-9+\\-() ]{7,15}")) {
            response.sendRedirect("profile.jsp?section=details&error=Please+enter+a+valid+mobile+number");
            return;
        }
        if (!email.equalsIgnoreCase(user.getEmail()) && userDAO.emailExistsForOtherUser(email, user.getUserId())) {
            response.sendRedirect("profile.jsp?section=details&error=That+email+is+already+in+use+by+another+account");
            return;
        }

        boolean success = userDAO.updateProfile(user.getUserId(), name, email, mobile);

        if (success) {
            // Keep the session's cached User object in sync so the new
            // details show up immediately everywhere (navbar initial,
            // sidebar, etc.) without requiring the person to log out and
            // back in.
            user.setName(name);
            user.setEmail(email);
            user.setMobileNumber(mobile);
            session.setAttribute("currentUser", user);
            response.sendRedirect("profile.jsp?success=Profile+updated");
        } else {
            response.sendRedirect("profile.jsp?section=details&error=Could+not+update+your+profile,+please+try+again");
        }
    }

    private void handleUploadPhoto(HttpServletRequest request, HttpServletResponse response,
            HttpSession session, User user) throws IOException, ServletException {

        Part filePart = request.getPart("photo");
        if (filePart == null || filePart.getSize() == 0) {
            response.sendRedirect("profile.jsp?section=photo&error=Please+choose+an+image+to+upload");
            return;
        }

        // Same server-side image validation as AddPlaceServlet - the
        // client-side accept="image/*" hint doesn't stop a direct POST.
        String contentType = filePart.getContentType();
        if (contentType == null || !contentType.toLowerCase().startsWith("image/")) {
            throw new IllegalArgumentException("Only+image+files+can+be+uploaded");
        }
        String originalName = filePart.getSubmittedFileName();
        String extension = (originalName != null && originalName.contains("."))
                ? originalName.substring(originalName.lastIndexOf(".")).toLowerCase()
                : "";
        String extNoDot = extension.startsWith(".") ? extension.substring(1) : extension;
        if (!ALLOWED_IMAGE_EXTENSIONS.contains(extNoDot)) {
            throw new IllegalArgumentException("Unsupported+image+file+type");
        }

        File uploadDir = UploadPaths.getExternalUploadDir();
        String fileName = "profile_" + user.getUserId() + "_" + UUID.randomUUID() + extension;
        File targetFile = new File(uploadDir, fileName);

        try (InputStream in = filePart.getInputStream();
             OutputStream out = Files.newOutputStream(targetFile.toPath())) {
            in.transferTo(out);
        }

        // Same "/uploads/<name>" relative web path convention as
        // AddPlaceServlet's place photos - served by UploadedImageServlet.
        String webPath = "uploads/" + fileName;
        boolean success = userDAO.updateProfileImage(user.getUserId(), webPath);

        if (success) {
            user.setProfileImage(webPath);
            session.setAttribute("currentUser", user);
            response.sendRedirect("profile.jsp?success=Profile+photo+updated");
        } else {
            // BUG FIX (per user request - real fix, not a hidden error):
            // UserDAO now auto-creates USERS.PROFILE_IMAGE the first time
            // it's needed, so reaching this branch means that auto-create
            // itself failed (almost certainly a DB-privilege issue, not a
            // missing-migration issue anymore) - the message reflects
            // that instead of pointing at a manual script as the first
            // suggestion.
            response.sendRedirect("profile.jsp?section=photo&error="
                    + urlSafe("Could not save your photo - the app couldn't add the required database column automatically (likely a DB permissions issue). Run sql/02_add_profile_image.sql manually, or check the server log for details."));
        }
    }

    private String trim(String value) {
        return value == null ? null : value.trim();
    }

    private String urlSafe(String value) {
        return value.replace(" ", "+");
    }
}
