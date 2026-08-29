-- ============================================================
-- Backpackr - Align PLACES column names with the application code
--
-- ROOT CAUSE (Add Place always fails with "Could not save your place"):
-- PlaceDAO.createPlace()'s INSERT statement hard-codes the column names
-- AVG_COST, BEST_TIME and ADDED_BY. On this database, PLACES was created
-- with different names for the same concepts:
--
--     AVERAGE_COST         instead of   AVG_COST
--     BEST_TIME_TO_VISIT   instead of   BEST_TIME
--     CONTRIBUTOR_ID        instead of  ADDED_BY
--
-- Oracle throws ORA-00904 "invalid identifier" on the INSERT the moment it
-- hits a column name that doesn't exist, PlaceDAO.createPlace() catches
-- that exception and returns -1, and AddPlaceServlet shows the generic
-- "Could not save your place, please try again" message - the real error
-- only ever appeared in the server console log.
--
-- Renaming (rather than rewriting the Java/SQL in PlaceDAO/SavedPlaceDAO)
-- is the safer fix here: it's non-destructive (all existing data and rows
-- are preserved exactly, only the column label changes) and it's one
-- small script instead of hand-editing SQL text in two different DAO
-- classes.
--
-- SAFE TO RUN NO MATTER WHAT STATE YOUR DATABASE IS IN - same pattern as
-- run_this_once.sql: each rename is attempted and any error (already
-- renamed, source column missing, etc.) is caught and reported instead of
-- stopping the script.
-- ============================================================

SET SERVEROUTPUT ON

BEGIN
  EXECUTE IMMEDIATE 'ALTER TABLE PLACES RENAME COLUMN AVERAGE_COST TO AVG_COST';
  DBMS_OUTPUT.PUT_LINE('Renamed PLACES.AVERAGE_COST -> AVG_COST');
EXCEPTION WHEN OTHERS THEN
  DBMS_OUTPUT.PUT_LINE('AVG_COST rename skipped (likely already done): ' || SQLERRM);
END;
/

BEGIN
  EXECUTE IMMEDIATE 'ALTER TABLE PLACES RENAME COLUMN BEST_TIME_TO_VISIT TO BEST_TIME';
  DBMS_OUTPUT.PUT_LINE('Renamed PLACES.BEST_TIME_TO_VISIT -> BEST_TIME');
EXCEPTION WHEN OTHERS THEN
  DBMS_OUTPUT.PUT_LINE('BEST_TIME rename skipped (likely already done): ' || SQLERRM);
END;
/

BEGIN
  EXECUTE IMMEDIATE 'ALTER TABLE PLACES RENAME COLUMN CONTRIBUTOR_ID TO ADDED_BY';
  DBMS_OUTPUT.PUT_LINE('Renamed PLACES.CONTRIBUTOR_ID -> ADDED_BY');
EXCEPTION WHEN OTHERS THEN
  DBMS_OUTPUT.PUT_LINE('ADDED_BY rename skipped (likely already done): ' || SQLERRM);
END;
/

COMMIT;

-- ---- Verification: confirm the app's expected column names now exist ----
SELECT COLUMN_NAME, DATA_TYPE, NULLABLE
FROM USER_TAB_COLUMNS
WHERE TABLE_NAME = 'PLACES'
  AND COLUMN_NAME IN ('AVG_COST','BEST_TIME','ADDED_BY')
ORDER BY COLUMN_NAME;
