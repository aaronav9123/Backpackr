package com.backpackr.dao;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.util.ArrayList;
import java.util.List;

import com.backpackr.model.Trip;
import com.backpackr.util.DBConnection;

public class TripDAO {

    // ============================
    // Create Trip
    // ============================
    public int createTrip(Trip trip) {
        int tripId = -1;
        String sql = "INSERT INTO TRIPS (USER_ID, TRIP_NAME, START_LOCATION, TOTAL_BUDGET, TOTAL_DAYS, CREATED_DATE) "
                   + "VALUES (?, ?, ?, ?, ?, SYSDATE)";

        try (
            Connection con = DBConnection.getConnection();
            PreparedStatement ps = con.prepareStatement(sql, new String[]{"TRIP_ID"})
        ) {
            ps.setInt(1, trip.getUserId());
            ps.setString(2, trip.getTripName());
            ps.setString(3, trip.getStartLocation());
            ps.setDouble(4, trip.getTotalBudget());
            ps.setInt(5, trip.getTotalDays());

            ps.executeUpdate();

            try (ResultSet rs = ps.getGeneratedKeys()) {
                if (rs.next()) {
                    tripId = rs.getInt(1);
                }
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
        return tripId;
    }

    // ============================
    // Get Trips by User
    // ============================
    public List<Trip> getTripsByUser(int userId) {
        List<Trip> trips = new ArrayList<>();
        String sql = "SELECT * FROM TRIPS WHERE USER_ID=? ORDER BY TRIP_ID DESC";

        try (
            Connection con = DBConnection.getConnection();
            PreparedStatement ps = con.prepareStatement(sql);
        ) {
            ps.setInt(1, userId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    trips.add(mapTrip(rs));
                }
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
        return trips;
    }

    // ============================
    // Get Single Trip by ID
    // ============================
    public Trip getTripById(int tripId) {
        Trip trip = null;
        String sql = "SELECT * FROM TRIPS WHERE TRIP_ID = ?";

        try (
            Connection con = DBConnection.getConnection();
            PreparedStatement ps = con.prepareStatement(sql);
        ) {
            ps.setInt(1, tripId);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    trip = mapTrip(rs);
                }
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
        return trip;
    }

    // ============================
    // Update Trip (Saved Trips - Edit)
    // ============================
    public boolean updateTrip(Trip trip) {
        boolean success = false;
        String sql = "UPDATE TRIPS SET TRIP_NAME = ?, START_LOCATION = ?, TOTAL_BUDGET = ?, TOTAL_DAYS = ? "
                   + "WHERE TRIP_ID = ?";

        try (
            Connection con = DBConnection.getConnection();
            PreparedStatement ps = con.prepareStatement(sql);
        ) {
            ps.setString(1, trip.getTripName());
            ps.setString(2, trip.getStartLocation());
            ps.setDouble(3, trip.getTotalBudget());
            ps.setInt(4, trip.getTotalDays());
            ps.setInt(5, trip.getTripId());

            int rows = ps.executeUpdate();
            success = rows > 0;
        } catch (Exception e) {
            e.printStackTrace();
        }
        return success;
    }

    // ============================
    // Delete Trip
    // ============================
    public boolean deleteTrip(int tripId) {
        boolean success = false;
        String sql = "DELETE FROM TRIPS WHERE TRIP_ID = ?";

        try (
            Connection con = DBConnection.getConnection();
            PreparedStatement ps = con.prepareStatement(sql);
        ) {
            ps.setInt(1, tripId);
            int rows = ps.executeUpdate();
            if (rows > 0) {
                success = true;
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
        return success;
    }

    // ============================
    // Update AI Summary for a trip
    // ============================
    public boolean updateAiSummary(int tripId, String summary) {
        boolean success = false;
        String sql = "UPDATE TRIPS SET AI_SUMMARY = ? WHERE TRIP_ID = ?";

        try (
            Connection con = DBConnection.getConnection();
            PreparedStatement ps = con.prepareStatement(sql);
        ) {
            ps.setString(1, summary);
            ps.setInt(2, tripId);
            int rows = ps.executeUpdate();
            success = rows > 0;
        } catch (Exception e) {
            e.printStackTrace();
        }
        return success;
    }

    // Helper to map ResultSet to Trip
    private Trip mapTrip(ResultSet rs) throws Exception {
        Trip t = new Trip();
        t.setTripId(rs.getInt("TRIP_ID"));
        t.setUserId(rs.getInt("USER_ID"));
        t.setTripName(rs.getString("TRIP_NAME"));
        t.setStartLocation(rs.getString("START_LOCATION"));
        t.setTotalBudget(rs.getDouble("TOTAL_BUDGET"));
        t.setTotalDays(rs.getInt("TOTAL_DAYS"));
        t.setCreatedDate(rs.getDate("CREATED_DATE"));

        // BUG FIX (Bug 2 - "Add To Trip" failing with ORA-17006 "Invalid
        // column name" from TripDAO.mapTrip()): AI_SUMMARY is only added to
        // TRIPS by sql/schema_update_phase2.sql. If that migration hasn't
        // been run yet on this Oracle instance, rs.getString("AI_SUMMARY")
        // throws, which previously bubbled all the way up and made
        // getTripsByUser()/getTripById() fail entirely - which is exactly
        // what "Add To Trip" calls first. Reading it defensively means
        // trips still load (with a blank AI summary) whether or not the
        // migration has been applied, and picks the real value up
        // automatically once it has. Run sql/schema_update_phase2.sql
        // against your database to enable the AI summary/day-wise
        // itinerary features fully.
        t.setAiSummary(hasColumn(rs, "AI_SUMMARY") ? rs.getString("AI_SUMMARY") : null);
        return t;
    }

    // Checks whether a column is present in this ResultSet without throwing.
    private boolean hasColumn(ResultSet rs, String columnName) {
        try {
            rs.findColumn(columnName);
            return true;
        } catch (Exception e) {
            return false;
        }
    }
}