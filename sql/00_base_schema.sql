-- ============================================================
-- Backpackr - Base schema (fresh install)
--
-- BUG FIX (Code Review - Deployment gap): sql/run_this_once.sql and the
-- phase1/phase2 scripts all assume USERS, PLACES, TRIPS and TRIP_STOPS
-- already exist - none of the provided SQL actually creates them. That
-- was fine for continuing an existing project database, but it meant a
-- brand-new deployment (a fresh Oracle XE instance, a new dev's machine,
-- a CI database) had no way to stand the schema up at all.
--
-- This script creates those four base tables. It is written with the
-- same "safe to run no matter what already exists" style as
-- run_this_once.sql (each CREATE TABLE is guarded so re-running this
-- script is harmless), so the full, correct install order for a brand
-- new database is simply:
--
--   1. sql/00_base_schema.sql        <- this file
--   2. sql/run_this_once.sql         <- adds PLACES/TRIPS/TRIP_STOPS
--                                        extra columns + RATINGS,
--                                        SAVED_PLACES, PLACE_IMAGES
--
-- (schema_update_phase1.sql / schema_update_phase2.sql are now folded
-- into run_this_once.sql and only kept for reference - see
-- SETUP_NOTES.md.)
--
-- Column types/lengths below were reverse-engineered directly from the
-- DAO code (UserDAO, PlaceDAO, TripDAO, TripStopDAO) so the app's
-- existing SQL keeps working unmodified.
-- ============================================================

SET SERVEROUTPUT ON

-- ---- USERS ----
BEGIN
  EXECUTE IMMEDIATE '
    CREATE TABLE USERS (
        USER_ID         NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
        NAME            VARCHAR2(150) NOT NULL,
        EMAIL           VARCHAR2(200) NOT NULL,
        -- BUG FIX (Security - plain-text passwords, see PasswordUtil.java):
        -- widened from a typical VARCHAR2(50) so it comfortably fits the
        -- "<base64 salt>:<base64 SHA-256 hash>" format (~70 chars) that
        -- new registrations now store, while still accepting any
        -- legacy plain-text password already in the column.
        PASSWORD        VARCHAR2(200) NOT NULL,
        MOBILE_NUMBER   VARCHAR2(20),
        JOINED_DATE     DATE DEFAULT SYSDATE,
        CONSTRAINT UQ_USERS_EMAIL UNIQUE (EMAIL)
    )';
  DBMS_OUTPUT.PUT_LINE('Created USERS');
EXCEPTION WHEN OTHERS THEN
  IF SQLCODE != -955 THEN RAISE; END IF; -- -955 = name already used by an existing object
  DBMS_OUTPUT.PUT_LINE('USERS already exists - skipped');
END;
/

-- ---- PLACES ----
BEGIN
  EXECUTE IMMEDIATE '
    CREATE TABLE PLACES (
        PLACE_ID        NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
        PLACE_NAME      VARCHAR2(200) NOT NULL,
        DISTRICT        VARCHAR2(100),
        STATE           VARCHAR2(100),
        CATEGORY        VARCHAR2(50),
        DESCRIPTION     VARCHAR2(2000),
        LATITUDE        NUMBER(9,6),
        LONGITUDE       NUMBER(9,6),
        IMAGE_URL       VARCHAR2(500)
    )';
  DBMS_OUTPUT.PUT_LINE('Created PLACES');
EXCEPTION WHEN OTHERS THEN
  IF SQLCODE != -955 THEN RAISE; END IF;
  DBMS_OUTPUT.PUT_LINE('PLACES already exists - skipped');
END;
/
-- NOTE: run sql/run_this_once.sql right after this script to add
-- PLACES.ADDRESS / AVG_COST / OPENING_TIME / BEST_TIME / MAPS_LINK /
-- ADDED_BY / CREATED_DATE, which AddPlaceServlet and the ratings/saved
-- place features all depend on.

-- ---- TRIPS ----
BEGIN
  EXECUTE IMMEDIATE '
    CREATE TABLE TRIPS (
        TRIP_ID         NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
        USER_ID         NUMBER NOT NULL,
        TRIP_NAME       VARCHAR2(200) NOT NULL,
        START_LOCATION  VARCHAR2(200),
        TOTAL_BUDGET    NUMBER(10,2) DEFAULT 0,
        TOTAL_DAYS      NUMBER DEFAULT 1,
        CREATED_DATE    DATE DEFAULT SYSDATE,
        CONSTRAINT FK_TRIPS_USER FOREIGN KEY (USER_ID) REFERENCES USERS(USER_ID)
    )';
  DBMS_OUTPUT.PUT_LINE('Created TRIPS');
EXCEPTION WHEN OTHERS THEN
  IF SQLCODE != -955 THEN RAISE; END IF;
  DBMS_OUTPUT.PUT_LINE('TRIPS already exists - skipped');
END;
/
-- NOTE: run sql/run_this_once.sql right after this script to add
-- TRIPS.AI_SUMMARY, used by the AI Trip Planner.

-- ---- TRIP_STOPS ----
BEGIN
  EXECUTE IMMEDIATE '
    CREATE TABLE TRIP_STOPS (
        STOP_ID         NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
        TRIP_ID         NUMBER NOT NULL,
        PLACE_ID        NUMBER NOT NULL,
        STOP_ORDER      NUMBER DEFAULT 1,
        CONSTRAINT FK_STOP_TRIP FOREIGN KEY (TRIP_ID) REFERENCES TRIPS(TRIP_ID) ON DELETE CASCADE,
        CONSTRAINT FK_STOP_PLACE FOREIGN KEY (PLACE_ID) REFERENCES PLACES(PLACE_ID) ON DELETE CASCADE
    )';
  DBMS_OUTPUT.PUT_LINE('Created TRIP_STOPS');
EXCEPTION WHEN OTHERS THEN
  IF SQLCODE != -955 THEN RAISE; END IF;
  DBMS_OUTPUT.PUT_LINE('TRIP_STOPS already exists - skipped');
END;
/
-- NOTE: run sql/run_this_once.sql right after this script to add
-- TRIP_STOPS.DAY_NUMBER / AI_NOTE, used by the AI Trip Planner's
-- day-by-day itinerary view.

COMMIT;

-- ---- Verification ----
SELECT TABLE_NAME FROM USER_TABLES
WHERE TABLE_NAME IN ('USERS','PLACES','TRIPS','TRIP_STOPS')
ORDER BY TABLE_NAME;
