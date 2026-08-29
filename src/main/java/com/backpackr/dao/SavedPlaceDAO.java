package com.backpackr.dao;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.util.ArrayList;
import java.util.List;

import com.backpackr.model.Place;
import com.backpackr.util.DBConnection;

public class SavedPlaceDAO {

    // ============================
    // Check if a place is already saved by a user
    // ============================
    public boolean isSaved(int userId, int placeId) {
        boolean saved = false;
        String sql = "SELECT 1 FROM SAVED_PLACES WHERE USER_ID = ? AND PLACE_ID = ?";

        try (
            Connection con = DBConnection.getConnection();
            PreparedStatement ps = con.prepareStatement(sql);
        ) {
            ps.setInt(1, userId);
            ps.setInt(2, placeId);
            try (ResultSet rs = ps.executeQuery()) {
                saved = rs.next();
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
        return saved;
    }

    // ============================
    // Toggle save state; returns the new state (true = now saved)
    // ============================
    public boolean toggleSave(int userId, int placeId) {
        if (isSaved(userId, placeId)) {
            removeSaved(userId, placeId);
            return false;
        } else {
            addSaved(userId, placeId);
            return true;
        }
    }

    private void addSaved(int userId, int placeId) {
        String sql = "INSERT INTO SAVED_PLACES (USER_ID, PLACE_ID, SAVED_DATE) VALUES (?, ?, SYSDATE)";
        try (
            Connection con = DBConnection.getConnection();
            PreparedStatement ps = con.prepareStatement(sql);
        ) {
            ps.setInt(1, userId);
            ps.setInt(2, placeId);
            ps.executeUpdate();
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    private void removeSaved(int userId, int placeId) {
        String sql = "DELETE FROM SAVED_PLACES WHERE USER_ID = ? AND PLACE_ID = ?";
        try (
            Connection con = DBConnection.getConnection();
            PreparedStatement ps = con.prepareStatement(sql);
        ) {
            ps.setInt(1, userId);
            ps.setInt(2, placeId);
            ps.executeUpdate();
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    // ============================
    // Get all places saved by a user (with rating/contributor info via PlaceDAO join style)
    //
    // BUG FIX / ROBUSTNESS NOTE: this used to hard-code a JOIN on
    // PLACES.ADDED_BY and the RATINGS table directly in the SQL text, and
    // read ADDRESS/AVG_COST/OPENING_TIME/BEST_TIME/MAPS_LINK/CREATED_DATE
    // without checking they exist. If sql/schema_update_phase1.sql hadn't
    // been run yet, this failed outright and "Saved Places" looked empty
    // even for places that genuinely were saved. It now detects what's
    // really in the schema first (same approach as PlaceDAO) so saved
    // places always show, with full detail once the migration is applied.
    // ============================
    public List<Place> getSavedPlaces(int userId) {
        List<Place> places = new ArrayList<>();

        boolean hasAddedBy = columnExists("PLACES", "ADDED_BY");
        boolean hasRatingsTable = tableExists("RATINGS");

        StringBuilder sqlBuilder = new StringBuilder("SELECT p.*, ");
        sqlBuilder.append(hasAddedBy
                ? "u.NAME AS CONTRIBUTOR_NAME, "
                : "CAST(NULL AS VARCHAR2(200)) AS CONTRIBUTOR_NAME, ");
        sqlBuilder.append(hasRatingsTable
                ? "NVL(r.AVG_STARS, 0) AS AVG_RATING, NVL(r.RATING_COUNT, 0) AS RATING_COUNT "
                : "0 AS AVG_RATING, 0 AS RATING_COUNT ");
        sqlBuilder.append("FROM SAVED_PLACES sp ")
                  .append("JOIN PLACES p ON sp.PLACE_ID = p.PLACE_ID ");
        if (hasAddedBy) {
            sqlBuilder.append("LEFT JOIN USERS u ON p.ADDED_BY = u.USER_ID ");
        }
        if (hasRatingsTable) {
            sqlBuilder.append("LEFT JOIN (SELECT PLACE_ID, AVG(STARS) AS AVG_STARS, COUNT(*) AS RATING_COUNT ")
                      .append("           FROM RATINGS GROUP BY PLACE_ID) r ON r.PLACE_ID = p.PLACE_ID ");
        }
        sqlBuilder.append("WHERE sp.USER_ID = ? ORDER BY sp.SAVED_DATE DESC");

        String sql = sqlBuilder.toString();

        try (
            Connection con = DBConnection.getConnection();
            PreparedStatement ps = con.prepareStatement(sql);
        ) {
            ps.setInt(1, userId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    Place p = new Place();
                    p.setPlaceId(rs.getInt("PLACE_ID"));
                    p.setPlaceName(rs.getString("PLACE_NAME"));
                    p.setDistrict(rs.getString("DISTRICT"));
                    p.setState(rs.getString("STATE"));
                    p.setCategory(rs.getString("CATEGORY"));
                    p.setDescription(rs.getString("DESCRIPTION"));
                    p.setLatitude(rs.getDouble("LATITUDE"));
                    p.setLongitude(rs.getDouble("LONGITUDE"));
                    p.setImageUrl(rs.getString("IMAGE_URL"));
                    p.setAddress(hasColumn(rs, "ADDRESS") ? rs.getString("ADDRESS") : null);
                    p.setAvgCost(hasColumn(rs, "AVG_COST") ? rs.getDouble("AVG_COST") : 0);
                    p.setOpeningTime(hasColumn(rs, "OPENING_TIME") ? rs.getString("OPENING_TIME") : null);
                    p.setBestTime(hasColumn(rs, "BEST_TIME") ? rs.getString("BEST_TIME") : null);
                    p.setMapsLink(hasColumn(rs, "MAPS_LINK") ? rs.getString("MAPS_LINK") : null);
                    p.setAddedByName(hasColumn(rs, "CONTRIBUTOR_NAME") ? rs.getString("CONTRIBUTOR_NAME") : null);
                    p.setCreatedDate(hasColumn(rs, "CREATED_DATE") ? rs.getDate("CREATED_DATE") : null);
                    p.setAvgRating(hasColumn(rs, "AVG_RATING") ? rs.getDouble("AVG_RATING") : 0);
                    p.setRatingCount(hasColumn(rs, "RATING_COUNT") ? rs.getInt("RATING_COUNT") : 0);
                    p.setSavedByCurrentUser(true);
                    places.add(p);
                }
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
        return places;
    }

    private boolean columnExists(String table, String column) {
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

    private boolean tableExists(String table) {
        try (Connection con = DBConnection.getConnection()) {
            if (con == null) return false;
            java.sql.DatabaseMetaData meta = con.getMetaData();
            try (ResultSet rs = meta.getTables(null, null, table, new String[]{"TABLE"})) {
                return rs.next();
            }
        } catch (Exception e) {
            e.printStackTrace();
            return false;
        }
    }

    private boolean hasColumn(ResultSet rs, String columnName) {
        try {
            rs.findColumn(columnName);
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    // ============================
    // Get the set of place IDs a user has saved (for quick lookups when rendering search results)
    // ============================
    public List<Integer> getSavedPlaceIds(int userId) {
        List<Integer> ids = new ArrayList<>();
        String sql = "SELECT PLACE_ID FROM SAVED_PLACES WHERE USER_ID = ?";

        try (
            Connection con = DBConnection.getConnection();
            PreparedStatement ps = con.prepareStatement(sql);
        ) {
            ps.setInt(1, userId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    ids.add(rs.getInt("PLACE_ID"));
                }
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
        return ids;
    }
}
