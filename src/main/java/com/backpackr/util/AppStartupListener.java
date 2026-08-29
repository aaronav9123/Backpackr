package com.backpackr.util;

import jakarta.servlet.ServletContextEvent;
import jakarta.servlet.ServletContextListener;
import jakarta.servlet.annotation.WebListener;

/**
 * BUG FIX (Code Review - Incomplete feature: DatabaseSeeder never runs):
 *
 * DatabaseSeeder.seedPlacesIfEmpty() contains a full set of demo places
 * (Goa/Mumbai/Kerala hidden gems, food spots, attractions, etc.) meant to
 * populate a brand-new PLACES table so the app isn't a blank slate the
 * first time it's deployed - but nothing in the project ever called it.
 * There was no web.xml <listener>, no startup hook of any kind, so on a
 * fresh database the "Trending"/"Recently Added" homepage sections and
 * every search simply stayed empty forever until a real user manually
 * added a place.
 *
 * This listener runs once, automatically, the moment the web app starts
 * (Tomcat picks it up via @WebListener - no web.xml wiring needed), and
 * seeding itself is still a no-op if PLACES already has rows, so it's safe
 * on every subsequent restart/redeploy.
 */
@WebListener
public class AppStartupListener implements ServletContextListener {

    @Override
    public void contextInitialized(ServletContextEvent sce) {
        try {
            DatabaseSeeder.seedPlacesIfEmpty();
        } catch (Exception e) {
            // Never let seeding trouble stop the app from starting - the
            // rest of Backpackr works fine (just with an empty PLACES
            // table) even if the DB isn't reachable yet at startup.
            e.printStackTrace();
        }
    }

    @Override
    public void contextDestroyed(ServletContextEvent sce) {
        // Nothing to clean up.
    }
}
