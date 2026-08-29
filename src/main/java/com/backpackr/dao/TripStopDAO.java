package com.backpackr.dao;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.util.ArrayList;
import java.util.List;

import com.backpackr.model.TripStop;
import com.backpackr.util.DBConnection;

public class TripStopDAO {

    // BUG FIX (Performance - Code Review): columnExists() runs a
    // DatabaseMetaData round trip against Oracle. addStop()/getStopsForTrip()
    // used to call it fresh on *every single invocation* (i.e. every "Add to
    // Trip" click and every page load that lists a trip's stops), roughly
    // doubling the DB work for no reason since schema shape never changes
    // while the app is running. This mirrors the same cache-once pattern
    // PlaceDAO already uses for its own schema checks.
    private static volatile Boolean hasDayColumnsCache = null;

    private static boolean hasDayColumns() {
        if (hasDayColumnsCache == null) {
            synchronized (TripStopDAO.class) {
                if (hasDayColumnsCache == null) {
                    hasDayColumnsCache = columnExists("TRIP_STOPS", "DAY_NUMBER")
                            && columnExists("TRIP_STOPS", "AI_NOTE");
                }
            }
        }
        return hasDayColumnsCache;
    }

    // NEW FEATURE (trip header budget accuracy): cached the same way, for
    // whether PLACES.AVG_COST exists yet (it's a Phase-1 migration column,
    // same as the columns PlaceDAO defensively checks for).
    private static volatile Boolean hasAvgCostColumnCache = null;

    private static boolean hasAvgCostColumn() {
        if (hasAvgCostColumnCache == null) {
            synchronized (TripStopDAO.class) {
                if (hasAvgCostColumnCache == null) {
                    hasAvgCostColumnCache = columnExists("PLACES", "AVG_COST");
                }
            }
        }
        return hasAvgCostColumnCache;
    }

    // ============================
    // Add Stop to Trip
    // ============================
    public boolean addStop(int tripId, int placeId, int stopOrder) {
        return addStop(tripId, placeId, stopOrder, 1, null);
    }

    // ============================
    // Add Stop to Trip with AI day number + note
    //
    // BUG FIX (Bug 2 - "Add To Trip" / "Could not add to trip"): this
    // INSERT hard-required DAY_NUMBER and AI_NOTE, which only exist on
    // TRIP_STOPS once sql/schema_update_phase2.sql has been run. If it
    // hadn't been, this INSERT failed with an Oracle "invalid identifier"
    // error and the whole "Add to Trip" action reported failure. It now
    // checks once whether those columns exist and falls back to inserting
    // just TRIP_ID/PLACE_ID/STOP_ORDER when they don't, so adding a place
    // to a trip always works - and automatically starts saving day/AI note
    // detail the moment the migration has been applied.
    // ============================
    public boolean addStop(int tripId, int placeId, int stopOrder, int dayNumber, String aiNote) {
        boolean success = false;
        boolean hasDayColumns = hasDayColumns();

        String sql = hasDayColumns
            ? "INSERT INTO TRIP_STOPS (TRIP_ID, PLACE_ID, STOP_ORDER, DAY_NUMBER, AI_NOTE) VALUES (?, ?, ?, ?, ?)"
            : "INSERT INTO TRIP_STOPS (TRIP_ID, PLACE_ID, STOP_ORDER) VALUES (?, ?, ?)";

        try (
            Connection con = DBConnection.getConnection();
            PreparedStatement ps = con.prepareStatement(sql);
        ) {
            ps.setInt(1, tripId);
            ps.setInt(2, placeId);
            ps.setInt(3, stopOrder);
            if (hasDayColumns) {
                ps.setInt(4, dayNumber);
                ps.setString(5, aiNote);
            }

            int rows = ps.executeUpdate();
            if (rows > 0) {
                success = true;
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
        return success;
    }

    private static boolean columnExists(String table, String column) {
        try (Connection con = DBConnection.getConnection()) {
            if (con == null) return false;
            java.sql.DatabaseMetaData meta = con.getMetaData();
            try (ResultSet rs = meta.getColumns(null, null, table, column)) {
                return rs.next();
            }
        } catch (Exception e) {
            e.printStackTrace();
            return false;
        }
    }

    // ============================
    // Get Next Stop Order for a Trip
    // ============================
    public int getNextStopOrder(int tripId) {
        int nextOrder = 1;
        String sql = "SELECT COALESCE(MAX(STOP_ORDER), 0) + 1 FROM TRIP_STOPS WHERE TRIP_ID = ?";

        try (
            Connection con = DBConnection.getConnection();
            PreparedStatement ps = con.prepareStatement(sql);
        ) {
            ps.setInt(1, tripId);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    nextOrder = rs.getInt(1);
                }
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
        return nextOrder;
    }

    // ============================
    // Get All Stops for a Trip
    // ============================
    public List<TripStop> getStopsForTrip(int tripId) {
        List<TripStop> stops = new ArrayList<>();
        boolean hasDayColumns = hasDayColumns();
        boolean hasAvgCost = hasAvgCostColumn();
        String avgCostSelect = hasAvgCost ? ", p.AVG_COST" : "";

        String sql = hasDayColumns
            ? "SELECT ts.STOP_ID, ts.TRIP_ID, ts.PLACE_ID, ts.STOP_ORDER, ts.DAY_NUMBER, ts.AI_NOTE, "
              + "p.PLACE_NAME, p.CATEGORY, p.DISTRICT, p.STATE, p.IMAGE_URL, p.LATITUDE, p.LONGITUDE" + avgCostSelect + " "
              + "FROM TRIP_STOPS ts "
              + "JOIN PLACES p ON ts.PLACE_ID = p.PLACE_ID "
              + "WHERE ts.TRIP_ID = ? "
              + "ORDER BY ts.DAY_NUMBER ASC, ts.STOP_ORDER ASC"
            : "SELECT ts.STOP_ID, ts.TRIP_ID, ts.PLACE_ID, ts.STOP_ORDER, "
              + "p.PLACE_NAME, p.CATEGORY, p.DISTRICT, p.STATE, p.IMAGE_URL, p.LATITUDE, p.LONGITUDE" + avgCostSelect + " "
              + "FROM TRIP_STOPS ts "
              + "JOIN PLACES p ON ts.PLACE_ID = p.PLACE_ID "
              + "WHERE ts.TRIP_ID = ? "
              + "ORDER BY ts.STOP_ORDER ASC";

        try (
            Connection con = DBConnection.getConnection();
            PreparedStatement ps = con.prepareStatement(sql);
        ) {
            ps.setInt(1, tripId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    TripStop ts = new TripStop();
                    ts.setStopId(rs.getInt("STOP_ID"));
                    ts.setTripId(rs.getInt("TRIP_ID"));
                    ts.setPlaceId(rs.getInt("PLACE_ID"));
                    ts.setStopOrder(rs.getInt("STOP_ORDER"));
                    ts.setDayNumber(hasDayColumns ? rs.getInt("DAY_NUMBER") : 1);
                    ts.setAiNote(hasDayColumns ? rs.getString("AI_NOTE") : null);
                    
                    // From joined places
                    ts.setPlaceName(rs.getString("PLACE_NAME"));
                    ts.setCategory(rs.getString("CATEGORY"));
                    ts.setDistrict(rs.getString("DISTRICT"));
                    ts.setState(rs.getString("STATE"));
                    ts.setImageUrl(rs.getString("IMAGE_URL"));
                    ts.setLatitude(rs.getDouble("LATITUDE"));
                    ts.setLongitude(rs.getDouble("LONGITUDE"));
                    ts.setAvgCost(hasAvgCost ? rs.getDouble("AVG_COST") : 0.0);

                    stops.add(ts);
                }
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
        return stops;
    }

    // ============================
    // Delete Stop from Trip
    // ============================
    public boolean deleteStop(int stopId) {
        boolean success = false;
        String sql = "DELETE FROM TRIP_STOPS WHERE STOP_ID = ?";

        try (
            Connection con = DBConnection.getConnection();
            PreparedStatement ps = con.prepareStatement(sql);
        ) {
            ps.setInt(1, stopId);
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
    // Update Stop Order (for manual sort or optimized route)
    // ============================
    public boolean updateStopOrder(int stopId, int newOrder) {
        boolean success = false;
        String sql = "UPDATE TRIP_STOPS SET STOP_ORDER = ? WHERE STOP_ID = ?";

        try (
            Connection con = DBConnection.getConnection();
            PreparedStatement ps = con.prepareStatement(sql);
        ) {
            ps.setInt(1, newOrder);
            ps.setInt(2, stopId);

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
    // Delete All Stops for a Trip
    // ============================
    public boolean deleteStopsForTrip(int tripId) {
        boolean success = false;
        String sql = "DELETE FROM TRIP_STOPS WHERE TRIP_ID = ?";

        try (
            Connection con = DBConnection.getConnection();
            PreparedStatement ps = con.prepareStatement(sql);
        ) {
            ps.setInt(1, tripId);
            ps.executeUpdate();
            success = true; // Returns true since if there are 0 stops, it's still successful
        } catch (Exception e) {
            e.printStackTrace();
        }
        return success;
    }
}
