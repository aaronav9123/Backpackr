package com.backpackr.controller;

import java.io.IOException;
import java.io.PrintWriter;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

import com.backpackr.dao.PlaceDAO;
import com.backpackr.dao.TripStopDAO;
import com.backpackr.model.Place;
import com.backpackr.model.TripStop;
import com.backpackr.model.User;
import com.backpackr.util.AIPlannerService;
import com.backpackr.util.SimpleJson;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

/**
 * NEW FEATURE (redesigned "Plan with AI"): powers the in-page modal on
 * trips.jsp that replaced the old plain link to a separate full-page
 * itinerary generator. Rather than navigating away, the modal calls this
 * servlet (AJAX/JSON) to search Backpackr's own places by:
 *   mode=distance  - within radiusKm of a given lat/lng
 *   mode=time      - reachable within maxMinutes of a given lat/lng
 *                    (estimated the same way the rest of the app already
 *                    estimates travel time - straight-line distance over
 *                    an assumed average speed - rather than calling the
 *                    routing service once per candidate place, which
 *                    would be slow and hammer the free OSRM service for
 *                    what's meant to be a quick "what's nearby" search)
 *   mode=location  - free-text search (place name/description/district/
 *                    state), reusing PlaceDAO.searchPlaces()
 *
 * Every mode excludes places already added to the trip - there's no
 * point suggesting a stop that's already on the itinerary.
 */
@WebServlet("/planSearch")
public class PlanSearchServlet extends HttpServlet {

    private static final long serialVersionUID = 1L;
    private final PlaceDAO placeDAO = new PlaceDAO();
    private final TripStopDAO tripStopDAO = new TripStopDAO();

    // Same assumed average speed AIPlannerService/trips.jsp already used
    // for estimating travel time from a straight-line distance elsewhere
    // in this app, kept consistent rather than inventing a new number.
    private static final double ASSUMED_AVG_SPEED_KMH = 35.0;

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        response.setContentType("application/json");
        response.setCharacterEncoding("UTF-8");

        HttpSession session = request.getSession(false);
        User user = (session != null) ? (User) session.getAttribute("currentUser") : null;
        if (user == null) {
            response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
            writeError(response, "Please log in again.");
            return;
        }

        try {
            // NEW FEATURE (create_trip.jsp "possible places" preview):
            // tripId is now optional. When present, results exclude
            // places already on that trip (the original "Plan with AI"
            // use case). When absent - a brand new trip that doesn't
            // exist yet - every match is shown, since there's nothing to
            // exclude.
            String tripIdParam = request.getParameter("tripId");
            Integer tripId = (tripIdParam != null && !tripIdParam.trim().isEmpty())
                    ? Integer.parseInt(tripIdParam) : null;
            String mode = request.getParameter("mode");

            Set<Integer> existingPlaceIds = new HashSet<>();
            if (tripId != null) {
                for (TripStop s : tripStopDAO.getStopsForTrip(tripId)) {
                    existingPlaceIds.add(s.getPlaceId());
                }
            }

            List<Place> candidates;
            boolean distanceKnown = false;
            double anchorLat = 0, anchorLng = 0;

            if ("location".equals(mode)) {
                String location = request.getParameter("location");
                if (location == null || location.trim().isEmpty()) {
                    writeError(response, "Please enter a location to search for.");
                    return;
                }
                candidates = placeDAO.searchPlaces(location.trim());
            } else if ("distance".equals(mode) || "time".equals(mode)) {
                anchorLat = Double.parseDouble(request.getParameter("lat"));
                anchorLng = Double.parseDouble(request.getParameter("lng"));
                distanceKnown = true;

                double maxKm;
                if ("distance".equals(mode)) {
                    maxKm = Double.parseDouble(request.getParameter("radiusKm"));
                } else {
                    double maxMinutes = Double.parseDouble(request.getParameter("maxMinutes"));
                    maxKm = (maxMinutes / 60.0) * ASSUMED_AVG_SPEED_KMH;
                }

                List<Place> all = placeDAO.getAllPlaces();
                candidates = new ArrayList<>();
                for (Place p : all) {
                    if (!isPlausibleCoordinate(p.getLatitude(), p.getLongitude())) continue;
                    double distanceKm = AIPlannerService.calculateDistance(anchorLat, anchorLng, p.getLatitude(), p.getLongitude());
                    if (distanceKm <= maxKm) {
                        candidates.add(p);
                    }
                }
            } else {
                writeError(response, "Unknown search mode.");
                return;
            }

            StringBuilder json = new StringBuilder("{\"success\":true,\"places\":[");
            boolean first = true;
            int count = 0;
            for (Place p : candidates) {
                if (existingPlaceIds.contains(p.getPlaceId())) continue;
                if (count >= 30) break; // keep the modal responsive/scannable
                if (!first) json.append(",");
                first = false;
                count++;

                double distanceKm = distanceKnown && isPlausibleCoordinate(p.getLatitude(), p.getLongitude())
                        ? AIPlannerService.calculateDistance(anchorLat, anchorLng, p.getLatitude(), p.getLongitude())
                        : -1;

                json.append("{")
                    .append("\"placeId\":").append(p.getPlaceId()).append(",")
                    .append("\"placeName\":\"").append(SimpleJson.escape(p.getPlaceName())).append("\",")
                    .append("\"category\":\"").append(SimpleJson.escape(p.getCategory())).append("\",")
                    .append("\"district\":\"").append(SimpleJson.escape(p.getDistrict())).append("\",")
                    .append("\"state\":\"").append(SimpleJson.escape(p.getState())).append("\",")
                    .append("\"avgCost\":").append(p.getAvgCost()).append(",")
                    .append("\"distanceKm\":").append(distanceKm)
                    .append("}");
            }
            json.append("]}");

            try (PrintWriter out = response.getWriter()) {
                out.print(json);
            }
        } catch (NumberFormatException e) {
            writeError(response, "Please enter a valid number.");
        } catch (Exception e) {
            e.printStackTrace();
            writeError(response, "Something went wrong while searching. Please try again.");
        }
    }

    private boolean isPlausibleCoordinate(double lat, double lng) {
        return (lat != 0.0 || lng != 0.0) && lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
    }

    private void writeError(HttpServletResponse response, String message) throws IOException {
        try (PrintWriter out = response.getWriter()) {
            out.print("{\"success\":false,\"error\":\"" + SimpleJson.escape(message) + "\"}");
        }
    }
}
