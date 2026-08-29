package com.backpackr.util;

import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.util.Base64;

/**
 * BUG FIX (Code Review - Security: passwords stored/compared in plain text):
 *
 * UserDAO used to INSERT the raw password straight into USERS.PASSWORD and
 * LoginServlet/UserDAO.validateUser() compared it with a plain
 * "WHERE PASSWORD = ?" - meaning every password was sitting in the database
 * (and in every SQL log / backup) in clear text. Anyone with read access to
 * the USERS table - or a single SQL injection anywhere else in the app -
 * would immediately have every user's real password.
 *
 * This class adds a small, dependency-free salted SHA-256 hash
 * (no external library needed, so the project stack/pom is untouched):
 *   stored value = "<base64 salt>:<base64 SHA-256(salt + password)>"
 *
 * UserDAO now stores this hashed form for new registrations, and
 * matches() is used instead of a raw SQL equality check. To avoid breaking
 * any accounts that were registered before this fix (whose PASSWORD column
 * still holds a plain-text value with no ":" hash marker), matches() also
 * accepts a legacy plain-text match; UserDAO transparently re-hashes and
 * saves the password the next time that user logs in successfully, so the
 * whole USERS table migrates to hashed passwords automatically over time
 * with no manual data migration step required.
 */
public class PasswordUtil {

    private static final int SALT_BYTES = 16;

    private PasswordUtil() {
    }

    public static String hash(String plainPassword) {
        try {
            byte[] salt = new byte[SALT_BYTES];
            new SecureRandom().nextBytes(salt);
            byte[] hashed = sha256(salt, plainPassword);
            return Base64.getEncoder().encodeToString(salt) + ":" + Base64.getEncoder().encodeToString(hashed);
        } catch (NoSuchAlgorithmException e) {
            // SHA-256 is guaranteed to be available on every standard JVM;
            // this branch should be unreachable, but never store a raw
            // password if it somehow happened.
            throw new IllegalStateException("SHA-256 not available", e);
        }
    }

    /**
     * @return true if plainPassword matches the stored value, whether that
     * stored value is a modern "salt:hash" pair or a legacy plain-text
     * password left over from before this fix.
     */
    public static boolean matches(String plainPassword, String storedValue) {
        if (plainPassword == null || storedValue == null) return false;

        if (isHashed(storedValue)) {
            try {
                String[] parts = storedValue.split(":", 2);
                byte[] salt = Base64.getDecoder().decode(parts[0]);
                byte[] expected = Base64.getDecoder().decode(parts[1]);
                byte[] actual = sha256(salt, plainPassword);
                return constantTimeEquals(expected, actual);
            } catch (Exception e) {
                return false;
            }
        }

        // Legacy plain-text row (pre-dates this fix) - compare directly.
        return storedValue.equals(plainPassword);
    }

    /** True if the stored value already looks like our "salt:hash" format. */
    public static boolean isHashed(String storedValue) {
        if (storedValue == null) return false;
        String[] parts = storedValue.split(":", 2);
        if (parts.length != 2) return false;
        try {
            Base64.getDecoder().decode(parts[0]);
            Base64.getDecoder().decode(parts[1]);
            return true;
        } catch (IllegalArgumentException e) {
            return false;
        }
    }

    private static byte[] sha256(byte[] salt, String plainPassword) throws NoSuchAlgorithmException {
        MessageDigest digest = MessageDigest.getInstance("SHA-256");
        digest.update(salt);
        return digest.digest(plainPassword.getBytes(java.nio.charset.StandardCharsets.UTF_8));
    }

    private static boolean constantTimeEquals(byte[] a, byte[] b) {
        if (a.length != b.length) return false;
        int result = 0;
        for (int i = 0; i < a.length; i++) {
            result |= a[i] ^ b[i];
        }
        return result == 0;
    }
}
