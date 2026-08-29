package com.backpackr.dao;

import java.sql.Connection;
import java.sql.DatabaseMetaData;
import java.sql.PreparedStatement;
import java.sql.ResultSet;

import com.backpackr.model.User;
import com.backpackr.util.DBConnection;
import com.backpackr.util.PasswordUtil;

public class UserDAO {

    // NEW FEATURE (Profile enhancements): cached the same way PlaceDAO
    // caches its own optional-column checks - PROFILE_IMAGE only exists
    // once it's been added to USERS, so every read/write that touches it
    // checks first and degrades gracefully instead of throwing ORA-00904.
    //
    // BUG FIX (per user request - "investigate the actual cause and fix
    // the feature properly, don't just hide the error"): this used to
    // stop at that check and tell the person to go run
    // sql/02_add_profile_image.sql by hand if the column was missing -
    // technically accurate, but a weak fix for something the app can
    // just do itself. ensureProfileImageColumn() now attempts to add the
    // column automatically the first time it's needed (the app already
    // connects with DDL privileges - see DBConnection's default "system"
    // user), so photo upload works immediately on a fresh database with
    // zero manual SQL steps. The manual script still exists for anyone
    // who prefers to run migrations explicitly / doesn't grant the app's
    // DB user DDL rights in a stricter production setup - see the
    // fallback path below.
    private static volatile Boolean hasProfileImageColumnCache = null;

    private static boolean hasProfileImageColumn() {
        if (hasProfileImageColumnCache == null) {
            synchronized (UserDAO.class) {
                if (hasProfileImageColumnCache == null) {
                    hasProfileImageColumnCache = columnExists("USERS", "PROFILE_IMAGE");
                }
            }
        }
        return hasProfileImageColumnCache;
    }

    /**
     * Ensures USERS.PROFILE_IMAGE exists, creating it on the fly if not.
     * @return true if the column exists (either already did, or was just
     * created successfully) and it's safe to read/write it.
     */
    private static boolean ensureProfileImageColumn() {
        if (hasProfileImageColumn()) return true;

        try (Connection con = DBConnection.getConnection()) {
            if (con == null) return false;
            try (java.sql.Statement stmt = con.createStatement()) {
                stmt.execute("ALTER TABLE USERS ADD PROFILE_IMAGE VARCHAR2(500)");
            }
            synchronized (UserDAO.class) {
                hasProfileImageColumnCache = true;
            }
            return true;
        } catch (Exception e) {
            // Most likely cause: the app's DB user doesn't have ALTER
            // TABLE privileges in this environment. Log it clearly server
            // side so whoever runs this can see exactly why, and fall
            // back to the manual-migration path - updateProfileImage()
            // below still returns false/a clear error to the browser
            // rather than silently pretending it worked.
            System.err.println("Could not auto-add USERS.PROFILE_IMAGE - "
                    + "run sql/02_add_profile_image.sql manually, or grant "
                    + "ALTER TABLE privileges to the app's DB user: " + e.getMessage());
            return false;
        }
    }

    private static boolean columnExists(String table, String column) {
        try (Connection con = DBConnection.getConnection()) {
            if (con == null) return false;
            DatabaseMetaData meta = con.getMetaData();
            try (ResultSet rs = meta.getColumns(null, null, table, column)) {
                return rs.next();
            }
        } catch (Exception e) {
            return false;
        }
    }

    // ============================
    // Register User
    //
    // BUG FIX (Security - plain-text passwords): the password is now
    // salted+hashed with PasswordUtil.hash() before it ever touches SQL, so
    // USERS.PASSWORD never stores a readable password. See PasswordUtil for
    // the full explanation and the backward-compatible login path.
    // ============================
    public boolean registerUser(User user) {
        boolean status = false;
        String sql = "INSERT INTO USERS(NAME, EMAIL, PASSWORD, MOBILE_NUMBER, JOINED_DATE) VALUES (?, ?, ?, ?, SYSDATE)";

        try (
            Connection con = DBConnection.getConnection();
            PreparedStatement ps = con.prepareStatement(sql);
        ) {
            ps.setString(1, user.getName());
            ps.setString(2, user.getEmail());
            ps.setString(3, PasswordUtil.hash(user.getPassword()));
            ps.setString(4, user.getMobileNumber());

            int rows = ps.executeUpdate();
            if (rows > 0) {
                status = true;
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
        return status;
    }

    // ============================
    // Login User
    //
    // BUG FIX (Security - plain-text passwords): this used to run
    // "WHERE EMAIL = ? AND PASSWORD = ?" directly in SQL, which only works
    // when the password column is stored in clear text. It now looks the
    // user up by EMAIL alone and verifies the password in Java with
    // PasswordUtil.matches(), which understands both the new hashed format
    // and any pre-existing plain-text rows. On a successful login with a
    // legacy plain-text row, the password is transparently re-saved in
    // hashed form so the account is upgraded with zero manual migration.
    // ============================
    public User validateUser(String email, String password) {
        User user = null;
        String sql = "SELECT * FROM USERS WHERE EMAIL = ?";

        try (
            Connection con = DBConnection.getConnection();
            PreparedStatement ps = con.prepareStatement(sql);
        ) {
            ps.setString(1, email);

            String storedPassword = null;
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    storedPassword = rs.getString("PASSWORD");
                    if (PasswordUtil.matches(password, storedPassword)) {
                        user = new User();
                        user.setUserId(rs.getInt("USER_ID"));
                        user.setName(rs.getString("NAME"));
                        user.setEmail(rs.getString("EMAIL"));
                        user.setPassword(storedPassword);
                        user.setMobileNumber(rs.getString("MOBILE_NUMBER"));
                        user.setJoinedDate(rs.getDate("JOINED_DATE"));
                        if (hasProfileImageColumn()) {
                            user.setProfileImage(rs.getString("PROFILE_IMAGE"));
                        }
                    }
                }
            }

            if (user != null && !PasswordUtil.isHashed(storedPassword)) {
                upgradeToHashedPassword(con, user.getUserId(), password);
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
        return user;
    }

    // Transparently upgrades a legacy plain-text password row to the
    // salted-hash format the moment its owner successfully logs in.
    private void upgradeToHashedPassword(Connection con, int userId, String plainPassword) {
        String sql = "UPDATE USERS SET PASSWORD = ? WHERE USER_ID = ?";
        try (PreparedStatement ps = con.prepareStatement(sql)) {
            ps.setString(1, PasswordUtil.hash(plainPassword));
            ps.setInt(2, userId);
            ps.executeUpdate();
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    // ============================
    // Check Email Exists
    // ============================
    public boolean emailExists(String email) {
        boolean exists = false;
        String sql = "SELECT EMAIL FROM USERS WHERE EMAIL=?";

        try (
            Connection con = DBConnection.getConnection();
            PreparedStatement ps = con.prepareStatement(sql);
        ) {
            ps.setString(1, email);

            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    exists = true;
                }
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
        return exists;
    }

    // NEW FEATURE (Profile enhancements - editing email): same check as
    // emailExists(), but excludes the current user's own row, so a person
    // editing their profile isn't blocked by "email already taken" simply
    // because it matches the email they already have.
    public boolean emailExistsForOtherUser(String email, int userId) {
        boolean exists = false;
        String sql = "SELECT EMAIL FROM USERS WHERE EMAIL = ? AND USER_ID != ?";

        try (
            Connection con = DBConnection.getConnection();
            PreparedStatement ps = con.prepareStatement(sql);
        ) {
            ps.setString(1, email);
            ps.setInt(2, userId);

            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    exists = true;
                }
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
        return exists;
    }

    // NEW FEATURE (Profile enhancements): update name/email/mobile number.
    // Password is intentionally NOT touched here - changing a password is
    // a separate, more sensitive action that deserves its own explicit
    // "confirm current password" flow, which is out of scope for this
    // basic profile-details edit.
    public boolean updateProfile(int userId, String name, String email, String mobileNumber) {
        boolean success = false;
        String sql = "UPDATE USERS SET NAME = ?, EMAIL = ?, MOBILE_NUMBER = ? WHERE USER_ID = ?";

        try (
            Connection con = DBConnection.getConnection();
            PreparedStatement ps = con.prepareStatement(sql);
        ) {
            ps.setString(1, name);
            ps.setString(2, email);
            ps.setString(3, mobileNumber);
            ps.setInt(4, userId);
            success = ps.executeUpdate() > 0;
        } catch (Exception e) {
            e.printStackTrace();
        }
        return success;
    }

    // NEW FEATURE (Profile enhancements - profile photo upload): saves the
    // path ProfileServlet stored the uploaded image under. Guarded by
    // hasProfileImageColumn() so this is a safe no-op (returns false,
    // doesn't throw) on a database that hasn't run
    // sql/02_add_profile_image.sql yet.
    public boolean updateProfileImage(int userId, String imagePath) {
        if (!ensureProfileImageColumn()) return false;
        boolean success = false;
        String sql = "UPDATE USERS SET PROFILE_IMAGE = ? WHERE USER_ID = ?";

        try (
            Connection con = DBConnection.getConnection();
            PreparedStatement ps = con.prepareStatement(sql);
        ) {
            ps.setString(1, imagePath);
            ps.setInt(2, userId);
            success = ps.executeUpdate() > 0;
        } catch (Exception e) {
            e.printStackTrace();
        }
        return success;
    }
}