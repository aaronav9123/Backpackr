package com.backpackr.dao;

import java.sql.Connection;
import java.sql.DatabaseMetaData;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.util.ArrayList;
import java.util.List;

import com.backpackr.model.Place;
import com.backpackr.util.Config;
import com.backpackr.util.DBConnection;

public class PlaceDAO {

    // ------------------------------------------------------------------
    // BUG FIX / ROBUSTNESS NOTE
    //
    // ADDED_BY, AVG_COST, OPENING_TIME, BEST_TIME, MAPS_LINK, ADDRESS and
    // CREATED_DATE on PLACES, and the RATINGS table itself, only exist once
    // sql/schema_update_phase1.sql (shipped with this project) has actually
    // been run against the database. The original BASE_SELECT hard-coded a
    // JOIN on ADDED_BY and on RATINGS directly in the SQL text - if that
    // migration hadn't been applied yet, EVERY method in this class
    // (search, "Recently Added", category browsing, etc.) failed outright
    // with an Oracle "invalid column/table" error, which was silently
    // swallowed by the catch blocks below and just looked like "no
    // results". The query is now built once, at first use, based on what
    // actually exists in the live schema, so the app works immediately
    // either way and automatically shows the richer data (contributor
    // name, ratings, cost, best time, etc.) the moment the migration has
    // been run - no code change needed.
    // ------------------------------------------------------------------

    private static volatile String baseSelectCache = null;
    private static volatile Boolean hasAddressColumnCache = null;

    private static String getBaseSelect() {
        if (baseSelectCache != null) {
            return baseSelectCache;
        }
        synchronized (PlaceDAO.class) {
            if (baseSelectCache != null) {
                return baseSelectCache;
            }

            boolean hasAddedBy = columnExists("PLACES", "ADDED_BY");
            boolean hasRatingsTable = tableExists("RATINGS");

            StringBuilder sql = new StringBuilder("SELECT p.*, ");
            sql.append(hasAddedBy
                    ? "u.NAME AS CONTRIBUTOR_NAME, "
                    : "CAST(NULL AS VARCHAR2(200)) AS CONTRIBUTOR_NAME, ");
            sql.append(hasRatingsTable
                    ? "NVL(r.AVG_STARS, 0) AS AVG_RATING, NVL(r.RATING_COUNT, 0) AS RATING_COUNT "
                    : "0 AS AVG_RATING, 0 AS RATING_COUNT ");
            sql.append("FROM PLACES p ");
            if (hasAddedBy) {
                sql.append("LEFT JOIN USERS u ON p.ADDED_BY = u.USER_ID ");
            }
            if (hasRatingsTable) {
                sql.append("LEFT JOIN (SELECT PLACE_ID, AVG(STARS) AS AVG_STARS, COUNT(*) AS RATING_COUNT ")
                   .append("           FROM RATINGS GROUP BY PLACE_ID) r ON r.PLACE_ID = p.PLACE_ID ");
            }

            baseSelectCache = sql.toString();
            return baseSelectCache;
        }
    }

    private static boolean hasAddressColumn() {
        if (hasAddressColumnCache == null) {
            synchronized (PlaceDAO.class) {
                if (hasAddressColumnCache == null) {
                    hasAddressColumnCache = columnExists("PLACES", "ADDRESS");
                }
            }
        }
        return hasAddressColumnCache;
    }

    // BUG FIX (Bug: MAPS_LINK submitted by the user was never saved):
    // createPlace()'s INSERT never included MAPS_LINK at all, even though
    // AddPlaceServlet read it from the form and set it on the Place object,
    // and every read-side method (mapPlace()) already pulled it back out of
    // the ResultSet. The column was simply missing from the write path, so
    // it was always NULL in the database no matter what the user typed.
    // Cached the same way as hasAddressColumn() above, so a fresh install
    // that hasn't run the migration yet still works (just without saving a
    // maps link) instead of failing the whole insert.
    private static volatile Boolean hasMapsLinkColumnCache = null;

    private static boolean hasMapsLinkColumn() {
        if (hasMapsLinkColumnCache == null) {
            synchronized (PlaceDAO.class) {
                if (hasMapsLinkColumnCache == null) {
                    hasMapsLinkColumnCache = columnExists("PLACES", "MAPS_LINK");
                }
            }
        }
        return hasMapsLinkColumnCache;
    }

    private static boolean columnExists(String table, String column) {
        try (Connection con = DBConnection.getConnection()) {
            if (con == null) return false;
            DatabaseMetaData meta = con.getMetaData();
            try (ResultSet rs = meta.getColumns(null, null, table, column)) {
                return rs.next();
            }
        } catch (Exception e) {
            e.printStackTrace();
            return false;
        }
    }

    private static boolean tableExists(String table) {
        try (Connection con = DBConnection.getConnection()) {
            if (con == null) return false;
            DatabaseMetaData meta = con.getMetaData();
            try (ResultSet rs = meta.getTables(null, null, table, new String[]{"TABLE"})) {
                return rs.next();
            }
        } catch (Exception e) {
            e.printStackTrace();
            return false;
        }
    }

    // ============================
    // Get All Places
    // ============================
    public List<Place> getAllPlaces() {
        List<Place> places = new ArrayList<>();
        String sql = getBaseSelect() + "ORDER BY p.PLACE_NAME ASC";

        try (
            Connection con = DBConnection.getConnection();
            PreparedStatement ps = con.prepareStatement(sql);
            ResultSet rs = ps.executeQuery();
        ) {
            while (rs.next()) {
                places.add(mapPlace(rs));
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
        return places;
    }

    // ============================
    // Get Places by Category
    // ============================
    public List<Place> getPlacesByCategory(String category) {
        List<Place> places = new ArrayList<>();
        String sql = getBaseSelect() + "WHERE p.CATEGORY = ? ORDER BY p.PLACE_NAME ASC";

        try (
            Connection con = DBConnection.getConnection();
            PreparedStatement ps = con.prepareStatement(sql);
        ) {
            ps.setString(1, category);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    places.add(mapPlace(rs));
                }
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
        return places;
    }

    // ============================
    // Search Places (Matches name, description, district, state or
    // address - case-insensitive). ADDRESS is only searched when that
    // Phase-1 column actually exists in the database (see hasAddressColumn()),
    // so search still works even before the migration has been run.
    // ============================
    public List<Place> searchPlaces(String query) {
        List<Place> places = new ArrayList<>();
        boolean searchAddress = hasAddressColumn();

        String sql = getBaseSelect()
                   + "WHERE LOWER(p.PLACE_NAME) LIKE ? OR "
                   + "LOWER(p.DESCRIPTION) LIKE ? OR "
                   + "LOWER(p.DISTRICT) LIKE ? OR "
                   + "LOWER(p.STATE) LIKE ? "
                   + (searchAddress ? "OR LOWER(p.ADDRESS) LIKE ? " : "")
                   + "ORDER BY p.PLACE_NAME ASC";

        try (
            Connection con = DBConnection.getConnection();
            PreparedStatement ps = con.prepareStatement(sql);
        ) {
            String wildcard = "%" + query.toLowerCase() + "%";
            ps.setString(1, wildcard);
            ps.setString(2, wildcard);
            ps.setString(3, wildcard);
            ps.setString(4, wildcard);
            if (searchAddress) {
                ps.setString(5, wildcard);
            }

            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    places.add(mapPlace(rs));
                }
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
        return places;
    }

    // ============================
    // Search Places filtered further by category (search + chip combined)
    // ============================
    public List<Place> searchPlacesByCategory(String query, String category) {
        List<Place> places = new ArrayList<>();
        boolean searchAddress = hasAddressColumn();

        String sql = getBaseSelect()
                   + "WHERE (LOWER(p.PLACE_NAME) LIKE ? OR LOWER(p.DESCRIPTION) LIKE ? OR "
                   + "LOWER(p.DISTRICT) LIKE ? OR LOWER(p.STATE) LIKE ? "
                   + (searchAddress ? "OR LOWER(p.ADDRESS) LIKE ? " : "")
                   + ") AND p.CATEGORY = ? "
                   + "ORDER BY p.PLACE_NAME ASC";

        try (
            Connection con = DBConnection.getConnection();
            PreparedStatement ps = con.prepareStatement(sql);
        ) {
            String wildcard = "%" + query.toLowerCase() + "%";
            int idx = 1;
            ps.setString(idx++, wildcard);
            ps.setString(idx++, wildcard);
            ps.setString(idx++, wildcard);
            ps.setString(idx++, wildcard);
            if (searchAddress) {
                ps.setString(idx++, wildcard);
            }
            ps.setString(idx, category);

            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    places.add(mapPlace(rs));
                }
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
        return places;
    }

    // ============================
    // Get Place by ID
    // ============================
    public Place getPlaceById(int placeId) {
        Place place = null;
        String sql = getBaseSelect() + "WHERE p.PLACE_ID = ?";

        try (
            Connection con = DBConnection.getConnection();
            PreparedStatement ps = con.prepareStatement(sql);
        ) {
            ps.setInt(1, placeId);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    place = mapPlace(rs);
                }
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
        return place;
    }

    // ============================
    // Find Places by Location Match
    // ============================
    public List<Place> getPlacesByLocation(String location) {
        List<Place> places = new ArrayList<>();
        String sql = getBaseSelect() + "WHERE LOWER(p.DISTRICT) = ? OR LOWER(p.STATE) = ? ORDER BY p.PLACE_NAME ASC";

        try (
            Connection con = DBConnection.getConnection();
            PreparedStatement ps = con.prepareStatement(sql);
        ) {
            ps.setString(1, location.toLowerCase());
            ps.setString(2, location.toLowerCase());
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    places.add(mapPlace(rs));
                }
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
        return places;
    }

    // ============================
    // Recently contributed places (for "Recently Added" / dashboard hints)
    // ============================
    public List<Place> getRecentPlaces(int limit) {

        List<Place> places = new ArrayList<>();

        // Ordered by PLACE_ID (always exists - it's the primary key, and
        // always increases as new places are added) instead of CREATED_DATE,
        // which is a Phase-1 column that may not exist yet.
        String sql = "SELECT * FROM (" + getBaseSelect()
                   + "ORDER BY p.PLACE_ID DESC) WHERE ROWNUM <= ?";

        try (
            Connection con = DBConnection.getConnection();
            PreparedStatement ps = con.prepareStatement(sql);
        ) {
            ps.setInt(1, limit);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    places.add(mapPlace(rs));
                }
            }
        } catch (Exception e) {
            e.printStackTrace();
        }

        return places;
    }

    // ============================
    // Top-rated community places (min. 1 rating), for the homepage's
    // "Trending in the Community" section - never hardcoded.
    // ============================
    public List<Place> getTopRatedPlaces(int limit) {
        List<Place> places = new ArrayList<>();

        if (!tableExists("RATINGS")) {
            // No RATINGS table yet - nothing can be "top rated". Return
            // an empty list instead of letting the query fail.
            return places;
        }

        String sql = "SELECT * FROM (" + getBaseSelect()
                   + "WHERE r.RATING_COUNT > 0 "
                   + "ORDER BY AVG_RATING DESC, RATING_COUNT DESC) WHERE ROWNUM <= ?";

        try (
            Connection con = DBConnection.getConnection();
            PreparedStatement ps = con.prepareStatement(sql);
        ) {
            ps.setInt(1, limit);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    places.add(mapPlace(rs));
                }
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
        return places;
    }

    // ============================
    // Total count of contributed places (used to drive the platform-wide
    // "no adventures shared yet" empty state on the homepage).
    // ============================
    public int getTotalPlaceCount() {
        String sql = "SELECT COUNT(*) FROM PLACES";
        try (
            Connection con = DBConnection.getConnection();
            PreparedStatement ps = con.prepareStatement(sql);
            ResultSet rs = ps.executeQuery();
        ) {
            if (rs.next()) {
                return rs.getInt(1);
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
        return 0;
    }

    // ============================
    // Distinct districts that already have contributed places -
    // powers the "Popular Searches" chips dynamically from real data.
    // ============================
    public List<String> getPopularLocations(int limit) {
        List<String> locations = new ArrayList<>();
        String sql = "SELECT DISTRICT FROM PLACES WHERE DISTRICT IS NOT NULL "
                   + "GROUP BY DISTRICT ORDER BY COUNT(*) DESC FETCH FIRST ? ROWS ONLY";

        try (
            Connection con = DBConnection.getConnection();
            PreparedStatement ps = con.prepareStatement(sql);
        ) {
            ps.setInt(1, limit);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    locations.add(rs.getString("DISTRICT"));
                }
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
        return locations;
    }

    // ============================
    // NEW FEATURE (Multi-user duplicate-place prevention)
    //
    // Different travelers pin the same physical spot with different names,
    // slightly different typed/GPS coordinates, or different spellings -
    // matching on PLACE_NAME alone (or requiring lat/lng to be
    // character-for-character identical) would either miss real duplicates
    // or create a new PLACES row every time someone re-visits a place
    // that's already on the map. Instead this looks for any existing place
    // whose stored LATITUDE/LONGITUDE fall within a small, configurable
    // radius of the newly submitted coordinates (great-circle distance,
    // via the Haversine formula) and treats that as "the same place".
    //
    // The radius defaults to 100 meters (accounts for typical GPS/geocoding
    // drift) and can be tuned per-deployment via the
    // DUPLICATE_PLACE_RADIUS_METERS key in config.properties / an
    // environment variable of the same name, without any code change.
    // ============================

    private static final double EARTH_RADIUS_METERS = 6371000.0;
    private static final double METERS_PER_DEGREE_LATITUDE = 111320.0;

    private static double getDuplicateRadiusMeters() {
        try {
            return Double.parseDouble(Config.get("DUPLICATE_PLACE_RADIUS_METERS", "100"));
        } catch (NumberFormatException e) {
            return 100.0;
        }
    }

    // Great-circle distance between two lat/lng points, in meters.
    private static double distanceMeters(double lat1, double lng1, double lat2, double lng2) {
        double dLat = Math.toRadians(lat2 - lat1);
        double dLng = Math.toRadians(lng2 - lng1);
        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
                 + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2))
                 * Math.sin(dLng / 2) * Math.sin(dLng / 2);
        double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        return EARTH_RADIUS_METERS * c;
    }

    // ============================
    // Find an existing place at (essentially) the same physical location.
    // Returns the closest match within the configured radius, or null if
    // nothing nearby exists yet. A cheap lat/lng bounding-box WHERE clause
    // narrows the candidates down at the database level first (so this
    // scales fine as PLACES grows), then the exact great-circle distance is
    // checked in Java for every candidate in that box.
    // ============================
    public Place findNearbyDuplicate(double latitude, double longitude) {
        double radiusMeters = getDuplicateRadiusMeters();

        double latDelta = radiusMeters / METERS_PER_DEGREE_LATITUDE;
        double cosLat = Math.max(0.01, Math.cos(Math.toRadians(latitude)));
        double lngDelta = radiusMeters / (METERS_PER_DEGREE_LATITUDE * cosLat);

        String sql = getBaseSelect()
                   + "WHERE p.LATITUDE BETWEEN ? AND ? AND p.LONGITUDE BETWEEN ? AND ? "
                   + "ORDER BY p.PLACE_ID ASC";

        Place closest = null;
        double closestDistance = Double.MAX_VALUE;

        try (
            Connection con = DBConnection.getConnection();
            PreparedStatement ps = con.prepareStatement(sql);
        ) {
            ps.setDouble(1, latitude - latDelta);
            ps.setDouble(2, latitude + latDelta);
            ps.setDouble(3, longitude - lngDelta);
            ps.setDouble(4, longitude + lngDelta);

            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    Place candidate = mapPlace(rs);
                    double distance = distanceMeters(latitude, longitude,
                            candidate.getLatitude(), candidate.getLongitude());
                    if (distance <= radiusMeters && distance < closestDistance) {
                        closestDistance = distance;
                        closest = candidate;
                    }
                }
            }
        } catch (Exception e) {
            e.printStackTrace();
        }

        return closest;
    }

    // ============================
    // Merge another traveler's submission into an already-existing place
    // (used when findNearbyDuplicate() found a match and the user chose to
    // "contribute" instead of viewing the existing place). Rather than
    // overwriting whatever the original contributor already filled in,
    // this only fills genuinely empty fields (blank description/address/
    // opening time/best time/maps link, or an unset cost) and always adds
    // any newly uploaded photo as an extra community photo via the
    // existing PLACE_IMAGES table - so multiple contributions enrich the
    // same place instead of overwriting each other's work.
    // ============================
    public boolean addContribution(int placeId, Place contribution, Integer contributorUserId) {
        boolean hasMapsLink = hasMapsLinkColumn();
        boolean updated = false;

        String sql =
            "UPDATE PLACES SET " +
            "DESCRIPTION = CASE WHEN DESCRIPTION IS NULL THEN ? ELSE DESCRIPTION END, " +
            "ADDRESS = CASE WHEN ADDRESS IS NULL THEN ? ELSE ADDRESS END, " +
            "OPENING_TIME = CASE WHEN OPENING_TIME IS NULL THEN ? ELSE OPENING_TIME END, " +
            "BEST_TIME = CASE WHEN BEST_TIME IS NULL THEN ? ELSE BEST_TIME END, " +
            (hasMapsLink ? "MAPS_LINK = CASE WHEN MAPS_LINK IS NULL THEN ? ELSE MAPS_LINK END, " : "") +
            "AVG_COST = CASE WHEN AVG_COST IS NULL OR AVG_COST = 0 THEN ? ELSE AVG_COST END " +
            "WHERE PLACE_ID = ?";

        try (
            Connection con = DBConnection.getConnection();
            PreparedStatement ps = con.prepareStatement(sql);
        ) {
            int idx = 1;
            ps.setString(idx++, contribution.getDescription());
            ps.setString(idx++, contribution.getAddress());
            ps.setString(idx++, contribution.getOpeningTime());
            ps.setString(idx++, contribution.getBestTime());
            if (hasMapsLink) {
                ps.setString(idx++, contribution.getMapsLink());
            }
            ps.setDouble(idx++, contribution.getAvgCost());
            ps.setInt(idx, placeId);

            updated = ps.executeUpdate() > 0;
        } catch (Exception e) {
            e.printStackTrace();
        }

        // A freshly uploaded photo is never dropped, even though it can't
        // overwrite the existing cover image - it's recorded as an
        // additional community photo for this place instead.
        if (contribution.getImageUrl() != null && tableExists("PLACE_IMAGES")) {
            String imgSql = "INSERT INTO PLACE_IMAGES (PLACE_ID, IMAGE_URL, UPLOADED_BY) VALUES (?, ?, ?)";
            try (
                Connection con = DBConnection.getConnection();
                PreparedStatement ps = con.prepareStatement(imgSql);
            ) {
                ps.setInt(1, placeId);
                ps.setString(2, contribution.getImageUrl());
                if (contributorUserId != null) {
                    ps.setInt(3, contributorUserId);
                } else {
                    ps.setNull(3, java.sql.Types.INTEGER);
                }
                ps.executeUpdate();
            } catch (Exception e) {
                e.printStackTrace();
            }
        }

        return updated;
    }

    // ============================
    // Create Place (Community Contribution - no approval required)
    //
    // NOTE: adding a place with cost/best-time/address/contributor detail
    // requires sql/schema_update_phase1.sql to have been run (those are the
    // columns being written to). Run the provided migration script once to
    // enable this fully.
    // ============================
    public int createPlace(Place place) {

        int placeId = -1;

        // BUG FIX (Bug: MAPS_LINK submitted by the user was never saved):
        // MAPS_LINK is now included in the INSERT (only if the column
        // actually exists on this database - see hasMapsLinkColumn()).
        boolean hasMapsLink = hasMapsLinkColumn();

        String sql =
            "INSERT INTO PLACES (" +
            "PLACE_NAME," +
            "CATEGORY," +
            "DESCRIPTION," +
            "ADDRESS," +
            "DISTRICT," +
            "STATE," +
            "LATITUDE," +
            "LONGITUDE," +
            "AVG_COST," +
            "OPENING_TIME," +
            "BEST_TIME," +
            "IMAGE_URL," +
            "ADDED_BY," +
            (hasMapsLink ? "MAPS_LINK," : "") +
            "CREATED_DATE" +
            ") VALUES (" +
            "?,?,?,?,?,?,?,?,?,?,?,?,?," +
            (hasMapsLink ? "?," : "") +
            "SYSDATE)";

        try (
            Connection con = DBConnection.getConnection();
            PreparedStatement ps =
                    con.prepareStatement(sql, new String[]{"PLACE_ID"});
        ) {

            ps.setString(1, place.getPlaceName());
            ps.setString(2, place.getCategory());
            ps.setString(3, place.getDescription());
            ps.setString(4, place.getAddress());
            ps.setString(5, place.getDistrict());
            ps.setString(6, place.getState());
            ps.setDouble(7, place.getLatitude());
            ps.setDouble(8, place.getLongitude());
            ps.setDouble(9, place.getAvgCost());
            ps.setString(10, place.getOpeningTime());
            ps.setString(11, place.getBestTime());
            ps.setString(12, place.getImageUrl());
            ps.setInt(13, place.getAddedBy());
            if (hasMapsLink) {
                ps.setString(14, place.getMapsLink());
            }

            int rows = ps.executeUpdate();

            if(rows>0){
                ResultSet rs = ps.getGeneratedKeys();
                if(rs.next()){
                    placeId = rs.getInt(1);
                }
            }

        } catch (Exception e) {
            e.printStackTrace();
        }

        return placeId;
    }

    // ============================
    // Count places contributed by a user (for profile stats)
    // ============================
    public int countPlacesByUser(int userId) {
        int count = 0;
        if (!columnExists("PLACES", "ADDED_BY")) {
            return 0;
        }
        String sql = "SELECT COUNT(*) FROM PLACES WHERE ADDED_BY = ?";
        try (
            Connection con = DBConnection.getConnection();
            PreparedStatement ps = con.prepareStatement(sql);
        ) {
            ps.setInt(1, userId);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) count = rs.getInt(1);
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
        return count;
    }

    // ============================
    // NEW FEATURE (Profile page - "contributed places" list): full list of
    // places a user contributed, not just the count. Mirrors
    // countPlacesByUser()'s defensive ADDED_BY check so a database that
    // hasn't run the migration yet returns an empty list instead of
    // throwing.
    // ============================
    public List<Place> getPlacesByUser(int userId) {
        List<Place> places = new ArrayList<>();
        if (!columnExists("PLACES", "ADDED_BY")) {
            return places;
        }
        String sql = getBaseSelect() + "WHERE p.ADDED_BY = ? ORDER BY p.PLACE_ID DESC";
        try (
            Connection con = DBConnection.getConnection();
            PreparedStatement ps = con.prepareStatement(sql);
        ) {
            ps.setInt(1, userId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    places.add(mapPlace(rs));
                }
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
        return places;
    }

    // Helper method to map ResultSet to Place model. Every Phase-1 field is
    // read defensively (see hasColumn()) so a partially-migrated database
    // still renders place cards correctly instead of throwing.
    private Place mapPlace(ResultSet rs) throws Exception {
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

        if (hasColumn(rs, "ADDED_BY")) {
            int addedBy = rs.getInt("ADDED_BY");
            p.setAddedBy(rs.wasNull() ? null : addedBy);
        } else {
            p.setAddedBy(null);
        }

        p.setAddedByName(hasColumn(rs, "CONTRIBUTOR_NAME") ? rs.getString("CONTRIBUTOR_NAME") : null);
        p.setCreatedDate(hasColumn(rs, "CREATED_DATE") ? rs.getDate("CREATED_DATE") : null);
        p.setAvgRating(hasColumn(rs, "AVG_RATING") ? rs.getDouble("AVG_RATING") : 0);
        p.setRatingCount(hasColumn(rs, "RATING_COUNT") ? rs.getInt("RATING_COUNT") : 0);
        return p;
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
