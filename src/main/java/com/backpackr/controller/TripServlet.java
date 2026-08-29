package com.backpackr.controller;

import java.io.IOException;
import java.util.List;

import com.backpackr.dao.PlaceDAO;
import com.backpackr.dao.TripDAO;
import com.backpackr.dao.TripStopDAO;
import com.backpackr.model.Place;
import com.backpackr.model.Trip;
import com.backpackr.model.TripStop;
import com.backpackr.model.User;
import com.backpackr.util.AIPlannerService;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

@WebServlet("/trip")
public class TripServlet extends HttpServlet {

    private static final long serialVersionUID = 1L;
    private TripDAO tripDAO = new TripDAO();
    private TripStopDAO tripStopDAO = new TripStopDAO();
    private PlaceDAO placeDAO = new PlaceDAO();
    private AIPlannerService aiPlannerService = new AIPlannerService();

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        doPost(request, response);
    }

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        // Check authentication
        HttpSession session = request.getSession(false);
        User user = (session != null) ? (User) session.getAttribute("currentUser") : null;

        if (user == null) {
            response.sendRedirect("login.jsp");
            return;
        }

        String action = request.getParameter("action");
        if (action == null) {
            response.sendRedirect("trips.jsp");
            return;
        }

        // AJAX actions return JSON instead of redirecting
        if ("addStopAjax".equals(action)) {
            handleAddStopAjax(request, response, user);
            return;
        }

        try {
            switch (action) {
                case "create":
                    handleCreateTrip(request, response, user.getUserId());
                    break;
                case "update":
                    handleUpdateTrip(request, response);
                    break;
                case "delete":
                    handleDeleteTrip(request, response);
                    break;
                case "addStop":
                    handleAddStop(request, response);
                    break;
                case "deleteStop":
                    handleDeleteStop(request, response);
                    break;
                case "aiPlan":
                    handleAIPlan(request, response);
                    break;
                case "optimize":
                    handleOptimizeRoute(request, response);
                    break;
                default:
                    response.sendRedirect("trips.jsp");
            }
        } catch (Exception e) {
            e.printStackTrace();
            response.sendRedirect("trips.jsp?error=An+unexpected+error+occurred");
        }
    }

    private void handleAddStopAjax(HttpServletRequest request, HttpServletResponse response, User user)
            throws IOException {
        response.setContentType("application/json");
        try {
            int placeId = Integer.parseInt(request.getParameter("placeId"));
            String tripIdParam = request.getParameter("tripId");
            int tripId;

            if (tripIdParam == null || tripIdParam.trim().isEmpty()) {
                // No trip specified: create a default trip on the fly so the
                // user never has to leave the search page to start planning.
                //
                // BUG FIX (user report - "analyze and modify Create New
                // Trip"): this used to always name it the generic "My
                // Trip", set the destination to the literal string
                // "Unspecified", and set a fake Rs. 10000 budget that had
                // nothing to do with anything the person actually did -
                // exactly the confusing placeholder data visible on
                // trips.jsp ("Destination: Unspecified", "Budget: Rs.
                // 10000") that prompted this fix. It now looks up the
                // place actually being added and derives a real name/
                // destination from it, and leaves the budget at 0 instead
                // of a made-up number - consistent with trips.jsp only
                // ever showing a budget/cost figure when there's real data
                // behind it (see the "Estimated Cost" header fix).
                List<Trip> existing = tripDAO.getTripsByUser(user.getUserId());
                if (!existing.isEmpty()) {
                    tripId = existing.get(0).getTripId();
                } else {
                    Place firstPlace = placeDAO.getPlaceById(placeId);
                    String destination = (firstPlace != null && firstPlace.getDistrict() != null)
                            ? firstPlace.getDistrict() : "My Trip";

                    Trip trip = new Trip();
                    trip.setUserId(user.getUserId());
                    trip.setTripName("Trip to " + destination);
                    trip.setStartLocation(destination);
                    trip.setTotalBudget(0);
                    trip.setTotalDays(3);
                    tripId = tripDAO.createTrip(trip);
                }
            } else {
                tripId = Integer.parseInt(tripIdParam);
            }

            if (tripId <= 0) {
                response.getWriter().write("{\"success\":false,\"message\":\"Could not resolve a trip\"}");
                return;
            }

            int nextOrder = tripStopDAO.getNextStopOrder(tripId);
            boolean success = tripStopDAO.addStop(tripId, placeId, nextOrder);

            response.getWriter().write(
                "{\"success\":" + success + ",\"tripId\":" + tripId + "}"
            );
        } catch (Exception e) {
            e.printStackTrace();
            response.setStatus(HttpServletResponse.SC_INTERNAL_SERVER_ERROR);
            response.getWriter().write("{\"success\":false,\"message\":\"Unexpected error\"}");
        }
    }

    private void handleCreateTrip(HttpServletRequest request, HttpServletResponse response, int userId)
            throws IOException {
        // NEW FEATURE (per user request): Title, Destination, and Budget
        // are no longer required to create a trip - only sensible
        // defaults matter here since the "possible places" preview on
        // create_trip.jsp already lets the person see relevant places
        // before they've filled in every field. Duration still defaults
        // to 1 day rather than 0, since a 0-day trip isn't meaningful.
        String tripNameParam = trim(request.getParameter("tripName"));
        String startLocationParam = trim(request.getParameter("startLocation"));
        String tripName = (tripNameParam != null) ? tripNameParam : "My Trip";
        String startLocation = startLocationParam; // may be null/blank - trips.jsp already handles that gracefully
        double totalBudget = parseDoubleOrDefault(request.getParameter("totalBudget"), 0);
        int totalDays = parseIntOrDefault(request.getParameter("totalDays"), 1);
        if (totalDays < 1) totalDays = 1;

        Trip trip = new Trip();
        trip.setUserId(userId);
        trip.setTripName(tripName);
        trip.setStartLocation(startLocation);
        trip.setTotalBudget(totalBudget);
        trip.setTotalDays(totalDays);

        int tripId = tripDAO.createTrip(trip);

        if (tripId > 0) {
            // NEW FEATURE (per user request - "add trip" option on the
            // create_trip.jsp places preview): the person can now
            // pre-select places from "Places You Could Visit" before the
            // trip even exists; each selection arrives here as a
            // "placeIds" request parameter (one per selected place, added
            // by create_trip.jsp's JS right before submitting). They're
            // added as this trip's first stops, in the order selected,
            // immediately after the trip itself is created.
            String[] placeIdParams = request.getParameterValues("placeIds");
            if (placeIdParams != null) {
                int stopOrder = 1;
                for (String placeIdStr : placeIdParams) {
                    try {
                        int placeId = Integer.parseInt(placeIdStr.trim());
                        tripStopDAO.addStop(tripId, placeId, stopOrder);
                        stopOrder++;
                    } catch (NumberFormatException e) {
                        // Skip anything malformed rather than failing the
                        // whole trip creation over one bad value.
                    }
                }
            }
            response.sendRedirect("trips.jsp?success=Trip+created+successfully");
        } else {
            response.sendRedirect("create_trip.jsp?error=Failed+to+create+trip");
        }
    }

    private String trim(String value) {
        if (value == null) return null;
        String t = value.trim();
        return t.isEmpty() ? null : t;
    }

    private double parseDoubleOrDefault(String value, double defaultValue) {
        try {
            return (value == null || value.trim().isEmpty()) ? defaultValue : Double.parseDouble(value.trim());
        } catch (NumberFormatException e) {
            return defaultValue;
        }
    }

    private int parseIntOrDefault(String value, int defaultValue) {
        try {
            return (value == null || value.trim().isEmpty()) ? defaultValue : Integer.parseInt(value.trim());
        } catch (NumberFormatException e) {
            return defaultValue;
        }
    }

    private void handleUpdateTrip(HttpServletRequest request, HttpServletResponse response)
            throws IOException {
        int tripId = Integer.parseInt(request.getParameter("tripId"));
        String tripName = request.getParameter("tripName");
        String startLocation = request.getParameter("startLocation");
        double totalBudget = Double.parseDouble(request.getParameter("totalBudget"));
        int totalDays = Integer.parseInt(request.getParameter("totalDays"));

        Trip trip = new Trip();
        trip.setTripId(tripId);
        trip.setTripName(tripName);
        trip.setStartLocation(startLocation);
        trip.setTotalBudget(totalBudget);
        trip.setTotalDays(totalDays);

        boolean success = tripDAO.updateTrip(trip);

        // Optional "redirect" param lets callers (e.g. Saved Trip Details)
        // send the user back to wherever they edited from.
        String redirect = request.getParameter("redirect");
        String base = (redirect != null && !redirect.trim().isEmpty())
                ? redirect
                : ("saved_trip_details.jsp?tripId=" + tripId);
        String sep = base.contains("?") ? "&" : "?";

        if (success) {
            response.sendRedirect(base + sep + "success=Trip+updated+successfully");
        } else {
            response.sendRedirect(base + sep + "error=Failed+to+update+trip");
        }
    }

    private void handleDeleteTrip(HttpServletRequest request, HttpServletResponse response)
            throws IOException {
        int tripId = Integer.parseInt(request.getParameter("tripId"));
        
        // Deleting the trip will cascade delete trip stops in Oracle constraints, 
        // but we delete them manually first for safety.
        tripStopDAO.deleteStopsForTrip(tripId);
        boolean success = tripDAO.deleteTrip(tripId);

        // Optional "redirect" param lets callers send the user back to
        // wherever the delete was triggered from (e.g. Saved Trips list or
        // Saved Trip Details), defaulting to the original trips.jsp target
        // so existing behavior is unchanged when it's not supplied.
        String redirect = request.getParameter("redirect");
        String base = (redirect != null && !redirect.trim().isEmpty()) ? redirect : "trips.jsp";
        String sep = base.contains("?") ? "&" : "?";

        if (success) {
            response.sendRedirect(base + sep + "success=Trip+deleted+successfully");
        } else {
            response.sendRedirect(base + sep + "error=Failed+to+delete+trip");
        }
    }

    private void handleAddStop(HttpServletRequest request, HttpServletResponse response)
            throws IOException {
        int tripId = Integer.parseInt(request.getParameter("tripId"));
        int placeId = Integer.parseInt(request.getParameter("placeId"));

        int nextOrder = tripStopDAO.getNextStopOrder(tripId);
        boolean success = tripStopDAO.addStop(tripId, placeId, nextOrder);

        if (success) {
            response.sendRedirect("trips.jsp?success=Place+added+to+trip");
        } else {
            response.sendRedirect("home.jsp?error=Failed+to+add+place+to+trip");
        }
    }

    private void handleDeleteStop(HttpServletRequest request, HttpServletResponse response)
            throws IOException {
        int stopId = Integer.parseInt(request.getParameter("stopId"));
        int tripId = Integer.parseInt(request.getParameter("tripId"));

        boolean success = tripStopDAO.deleteStop(stopId);

        if (success) {
            // Reorder remaining stops to keep them consecutive (1, 2, 3...)
            List<TripStop> remaining = tripStopDAO.getStopsForTrip(tripId);
            for (int i = 0; i < remaining.size(); i++) {
                tripStopDAO.updateStopOrder(remaining.get(i).getStopId(), i + 1);
            }
            response.sendRedirect("trips.jsp?success=Stop+removed+successfully");
        } else {
            response.sendRedirect("trips.jsp?error=Failed+to+remove+stop");
        }
    }

    private void handleAIPlan(HttpServletRequest request, HttpServletResponse response)
            throws IOException {
        int tripId = Integer.parseInt(request.getParameter("tripId"));

        boolean success = aiPlannerService.autoPlanTrip(tripId);

        if (success) {
            response.sendRedirect("trips.jsp?success=AI+itinerary+generated+successfully");
        } else {
            response.sendRedirect("trips.jsp?error=AI+failed+to+find+places+within+budget");
        }
    }

    private void handleOptimizeRoute(HttpServletRequest request, HttpServletResponse response)
            throws IOException {
        int tripId = Integer.parseInt(request.getParameter("tripId"));

        boolean success = aiPlannerService.optimizeTripRoute(tripId);

        if (success) {
            response.sendRedirect("trips.jsp?success=Route+optimized+for+easiest+travel");
        } else {
            response.sendRedirect("trips.jsp?error=Failed+to+optimize+route");
        }
    }
}