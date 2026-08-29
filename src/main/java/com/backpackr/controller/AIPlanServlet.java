package com.backpackr.controller;

import java.io.IOException;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

import com.backpackr.dao.PlaceDAO;
import com.backpackr.dao.TripDAO;
import com.backpackr.dao.TripStopDAO;
import com.backpackr.model.Place;
import com.backpackr.model.Trip;
import com.backpackr.model.TripStop;
import com.backpackr.model.User;
import com.backpackr.util.GeminiService;
import com.backpackr.util.GeminiService.ItineraryDay;
import com.backpackr.util.GeminiService.ItineraryResult;
import com.backpackr.util.GeminiService.ItineraryStop;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

@WebServlet("/aiPlan")
public class AIPlanServlet extends HttpServlet {

    private static final long serialVersionUID = 1L;
    private TripDAO tripDAO = new TripDAO();
    private TripStopDAO tripStopDAO = new TripStopDAO();
    private PlaceDAO placeDAO = new PlaceDAO();
    private GeminiService geminiService = new GeminiService();

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        HttpSession session = request.getSession(false);
        User user = (session != null) ? (User) session.getAttribute("currentUser") : null;
        if (user == null) {
            response.sendRedirect("login.jsp");
            return;
        }

        int tripId;
        try {
            tripId = Integer.parseInt(request.getParameter("tripId"));
        } catch (Exception e) {
            response.sendRedirect("trips.jsp?error=Missing+trip");
            return;
        }

        Trip trip = tripDAO.getTripById(tripId);
        if (trip == null || trip.getUserId() != user.getUserId()) {
            response.sendRedirect("trips.jsp?error=Trip+not+found");
            return;
        }

        String travelMode = paramOr(request, "travelMode", "Car");
        String groupType = paramOr(request, "groupType", "Solo");
        String interests = paramOr(request, "interests", "Nature, Food");
        String adventureLevel = paramOr(request, "adventureLevel", "Moderate");

        try {
            // Places already hand-picked by the user via the "+" button
            List<TripStop> currentStops = tripStopDAO.getStopsForTrip(tripId);
            List<Place> selectedPlaces = new ArrayList<>();
            Set<Integer> selectedIds = new HashSet<>();
            for (TripStop ts : currentStops) {
                Place p = placeDAO.getPlaceById(ts.getPlaceId());
                if (p != null) {
                    selectedPlaces.add(p);
                    selectedIds.add(p.getPlaceId());
                }
            }

            // Broaden the candidate pool from the same destination, falling back to everything
            List<Place> candidatePool = placeDAO.getPlacesByLocation(trip.getStartLocation());
            if (candidatePool.isEmpty()) {
                candidatePool = placeDAO.getAllPlaces();
            }
            List<Place> filteredPool = new ArrayList<>();
            for (Place p : candidatePool) {
                if (!selectedIds.contains(p.getPlaceId())) {
                    filteredPool.add(p);
                }
                if (filteredPool.size() >= 40) break; // keep the prompt a reasonable size
            }

            ItineraryResult result = geminiService.generateItinerary(
                selectedPlaces, filteredPool, trip.getTotalDays(), trip.getTotalBudget(),
                travelMode, groupType, interests, adventureLevel
            );

            if (!result.success || result.days.isEmpty()) {
                String msg = result.errorMessage != null ? result.errorMessage : "AI could not build a plan";
                response.sendRedirect("ai_planner.jsp?tripId=" + tripId + "&error=" + encode(msg));
                return;
            }

            // Replace existing stops with the AI's day-wise plan
            tripStopDAO.deleteStopsForTrip(tripId);
            int order = 1;
            for (ItineraryDay day : result.days) {
                for (ItineraryStop stop : day.stops) {
                    tripStopDAO.addStop(tripId, stop.placeId, order++, day.dayNumber, stop.note);
                }
            }
            tripDAO.updateAiSummary(tripId, result.overallSummary);

            response.sendRedirect("trips.jsp?success=AI+itinerary+generated+for+" + encode(trip.getTripName()));
        } catch (Exception e) {
            e.printStackTrace();
            response.sendRedirect("ai_planner.jsp?tripId=" + tripId + "&error=" + encode("Unexpected error while planning"));
        }
    }

    private String paramOr(HttpServletRequest request, String name, String fallback) {
        String v = request.getParameter(name);
        return (v == null || v.trim().isEmpty()) ? fallback : v.trim();
    }

    private String encode(String value) {
        try {
            return URLEncoder.encode(value, StandardCharsets.UTF_8);
        } catch (Exception e) {
            return "";
        }
    }
}
