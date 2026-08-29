package com.backpackr.util;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

import com.backpackr.dao.PlaceDAO;
import com.backpackr.dao.TripDAO;
import com.backpackr.dao.TripStopDAO;
import com.backpackr.model.Place;
import com.backpackr.model.Trip;
import com.backpackr.model.TripStop;

public class AIPlannerService {

    private PlaceDAO placeDAO = new PlaceDAO();
    private TripStopDAO tripStopDAO = new TripStopDAO();
    private TripDAO tripDAO = new TripDAO();

    // ==========================================
    // AI Auto-Plan Trip
    // ==========================================
    public boolean autoPlanTrip(int tripId) {
        Trip trip = tripDAO.getTripById(tripId);
        if (trip == null) {
            return false;
        }

        // Clean existing stops first to regenerate
        tripStopDAO.deleteStopsForTrip(tripId);

        // Fetch candidate places matching the trip's start location
        List<Place> candidates = placeDAO.getPlacesByLocation(trip.getStartLocation());
        
        // Fallback: If no candidate places in that city, get all available places
        if (candidates.isEmpty()) {
            candidates = placeDAO.getAllPlaces();
        }

        if (candidates.isEmpty()) {
            return false;
        }

        // Shuffle candidates to simulate AI variation on each click
        Collections.shuffle(candidates);

        double totalAllocatedCost = 0;
        int stopsCount = 0;
        // Target number of stops based on days: let's aim for 2 stops per day
        int maxStops = Math.max(2, trip.getTotalDays() * 2);

        List<Place> selectedPlaces = new ArrayList<>();

        for (Place p : candidates) {
            if (stopsCount >= maxStops) {
                break;
            }

            // Estimate cost dynamically: use the community-submitted cost if
            // one exists, otherwise fall back to a category-based estimate
            double cost = p.getAvgCost() > 0 ? p.getAvgCost() : getEstimatedCost(p.getCategory());
            
            // Check if this fits in the trip's budget limit
            if (totalAllocatedCost + cost <= trip.getTotalBudget()) {
                selectedPlaces.add(p);
                totalAllocatedCost += cost;
                stopsCount++;
            }
        }

        // If no places fit, at least add 1 cheap place if possible
        if (selectedPlaces.isEmpty()) {
            Place cheapest = candidates.get(0);
            selectedPlaces.add(cheapest);
        }

        // Sort the selected places by nearest-neighbor distance (easiest route) right away!
        List<Place> optimizedRoute = optimizePlacesRoute(selectedPlaces);

        // Insert stops in order
        int order = 1;
        for (Place p : optimizedRoute) {
            tripStopDAO.addStop(tripId, p.getPlaceId(), order++);
        }

        return true;
    }

    // ==========================================
    // Optimize Route using Nearest Neighbor TSP
    // ==========================================
    public boolean optimizeTripRoute(int tripId) {
        List<TripStop> stops = tripStopDAO.getStopsForTrip(tripId);
        if (stops.size() <= 1) {
            return true; // Already optimal
        }

        List<TripStop> unvisited = new ArrayList<>(stops);
        List<TripStop> optimized = new ArrayList<>();

        // Start from the first stop in the list
        TripStop current = unvisited.remove(0);
        optimized.add(current);

        while (!unvisited.isEmpty()) {
            TripStop nearest = null;
            double minDistance = Double.MAX_VALUE;
            int nearestIdx = -1;

            for (int i = 0; i < unvisited.size(); i++) {
                TripStop candidate = unvisited.get(i);
                double dist = calculateDistance(
                    current.getLatitude(), current.getLongitude(),
                    candidate.getLatitude(), candidate.getLongitude()
                );
                if (dist < minDistance) {
                    minDistance = dist;
                    nearest = candidate;
                    nearestIdx = i;
                }
            }

            if (nearest != null) {
                unvisited.remove(nearestIdx);
                optimized.add(nearest);
                current = nearest;
            } else {
                break;
            }
        }

        // Save new order to database
        boolean success = true;
        for (int i = 0; i < optimized.size(); i++) {
            TripStop ts = optimized.get(i);
            boolean updated = tripStopDAO.updateStopOrder(ts.getStopId(), i + 1);
            if (!updated) {
                success = false;
            }
        }

        return success;
    }

    // Heuristic route optimization for a list of places before saving them
    private List<Place> optimizePlacesRoute(List<Place> places) {
        if (places.size() <= 1) {
            return places;
        }

        List<Place> unvisited = new ArrayList<>(places);
        List<Place> optimized = new ArrayList<>();

        Place current = unvisited.remove(0);
        optimized.add(current);

        while (!unvisited.isEmpty()) {
            Place nearest = null;
            double minDistance = Double.MAX_VALUE;
            int nearestIdx = -1;

            for (int i = 0; i < unvisited.size(); i++) {
                Place candidate = unvisited.get(i);
                double dist = calculateDistance(
                    current.getLatitude(), current.getLongitude(),
                    candidate.getLatitude(), candidate.getLongitude()
                );
                if (dist < minDistance) {
                    minDistance = dist;
                    nearest = candidate;
                    nearestIdx = i;
                }
            }

            if (nearest != null) {
                unvisited.remove(nearestIdx);
                optimized.add(nearest);
                current = nearest;
            } else {
                break;
            }
        }

        return optimized;
    }

    // ==========================================
    // Haversine Distance Formula (KM)
    // ==========================================
    public static double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
        final int R = 6371; // Earth's radius in KM
        double latDistance = Math.toRadians(lat2 - lat1);
        double lonDistance = Math.toRadians(lon2 - lon1);
        double a = Math.sin(latDistance / 2) * Math.sin(latDistance / 2)
                 + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2))
                 * Math.sin(lonDistance / 2) * Math.sin(lonDistance / 2);
        double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        return R * c;
    }

    // Fallback cost estimate by category, used only when a place has no
    // community-submitted AVG_COST yet (e.g. seed data or a fresh contribution).
    public static double getEstimatedCost(String category) {
        if (category == null) return 200;
        switch (category) {
            case "Budget Food":
                return 150.0;
            case "Scenic Spot":
                return 100.0;
            case "Local Attraction":
                return 300.0;
            case "Hidden Gem":
                return 500.0;
            default:
                return 250.0;
        }
    }

    // Splits a trip's total budget into a Transport / Stay / Food estimate
    // for the Saved Trip Details "Budget Summary" panel. There is no
    // per-category spend tracked in the schema, so this derives a
    // proportional breakdown straight from the trip's own real
    // TOTAL_BUDGET (42% transport / 33% stay / remainder food) rather than
    // showing any fixed, trip-independent numbers.
    public static double[] estimateBudgetBreakdown(double totalBudget) {
        double transport = Math.round(totalBudget * 0.42);
        double stay = Math.round(totalBudget * 0.33);
        double food = totalBudget - transport - stay;
        return new double[] { transport, stay, food };
    }
}
