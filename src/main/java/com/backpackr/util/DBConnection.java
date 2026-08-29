package com.backpackr.util;

import java.sql.Connection;
import java.sql.DriverManager;

/**
 * BUG FIX (Code Review - Bug: hard-coded DB credentials):
 *
 * This class used to hard-code the JDBC URL, username and password
 * ("system"/"root" against jdbc:oracle:thin:@localhost:1521:XE) directly in
 * source. That meant the app could only ever run against one specific local
 * database, secrets were committed to source control, and moving to a
 * different Oracle instance (a teammate's machine, a server, a different
 * SID/service name) required editing and recompiling Java code.
 *
 * The connection details are now read from config.properties (same file
 * already used for the Gemini API key - see Config.java), with the original
 * values kept as defaults so existing local setups keep working with zero
 * configuration changes:
 *   DB_URL      (default: jdbc:oracle:thin:@localhost:1521:XE)
 *   DB_USER     (default: system)
 *   DB_PASSWORD (default: root)
 *
 * Connections are still handed out one-per-call (no pooling), which matches
 * the rest of the DAO layer's try-with-resources usage.
 */
public class DBConnection {

    private static final String DEFAULT_URL = "jdbc:oracle:thin:@localhost:1521:XE";
    private static final String DEFAULT_USER = "system";
    private static final String DEFAULT_PASSWORD = "root";

    public static Connection getConnection() {
        Connection con = null;
        try {
            Class.forName("oracle.jdbc.OracleDriver");

            String url = Config.get("DB_URL", DEFAULT_URL);
            String user = Config.get("DB_USER", DEFAULT_USER);
            String password = Config.get("DB_PASSWORD", DEFAULT_PASSWORD);

            con = DriverManager.getConnection(url, user, password);
        } catch (Exception e) {
            e.printStackTrace();
        }
        return con;
    }

    // This lets you test right inside Eclipse without dealing with Tomcat!
    public static void main(String[] args) {
        Connection con = getConnection();
        System.out.println(con != null ? "Database Connected Successfully" : "Database Connection FAILED");
        if (con != null) {
            try { con.close(); } catch (Exception ignored) { }
        }
    }
}
