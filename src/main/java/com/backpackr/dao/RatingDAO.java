package com.backpackr.dao;

import java.sql.Connection;
import java.sql.PreparedStatement;

import com.backpackr.util.DBConnection;

public class RatingDAO {

    // ============================
    // Submit or update a user's rating for a place (one rating per user/place)
    // ============================
    public boolean rate(int placeId, int userId, int stars) {
        boolean success = false;
        String sql =
            "MERGE INTO RATINGS r " +
            "USING (SELECT ? AS PLACE_ID, ? AS USER_ID FROM DUAL) src " +
            "ON (r.PLACE_ID = src.PLACE_ID AND r.USER_ID = src.USER_ID) " +
            "WHEN MATCHED THEN UPDATE SET r.STARS = ?, r.CREATED_DATE = SYSDATE " +
            "WHEN NOT MATCHED THEN INSERT (PLACE_ID, USER_ID, STARS, CREATED_DATE) " +
            "VALUES (?, ?, ?, SYSDATE)";

        try (
            Connection con = DBConnection.getConnection();
            PreparedStatement ps = con.prepareStatement(sql);
        ) {
            ps.setInt(1, placeId);
            ps.setInt(2, userId);
            ps.setInt(3, stars);
            ps.setInt(4, placeId);
            ps.setInt(5, userId);
            ps.setInt(6, stars);

            int rows = ps.executeUpdate();
            success = rows > 0;
        } catch (Exception e) {
            e.printStackTrace();
        }
        return success;
    }

    // ============================
    // Get the current user's existing rating for a place (0 if none)
    // ============================
    public int getUserRating(int placeId, int userId) {
        int stars = 0;
        String sql = "SELECT STARS FROM RATINGS WHERE PLACE_ID = ? AND USER_ID = ?";

        try (
            Connection con = DBConnection.getConnection();
            PreparedStatement ps = con.prepareStatement(sql);
        ) {
            ps.setInt(1, placeId);
            ps.setInt(2, userId);
            try (var rs = ps.executeQuery()) {
                if (rs.next()) {
                    stars = rs.getInt("STARS");
                }
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
        return stars;
    }
}
