-- ============================================================
-- Backpackr - Add USERS.PROFILE_IMAGE (profile photo support)
--
-- NEW FEATURE: profile.jsp now supports uploading a profile photo and
-- editing name/email/mobile number. This adds the one new column that
-- needs - PROFILE_IMAGE, storing the path the photo was saved under
-- (same pattern as PLACES.IMAGE_URL for community photo uploads).
--
-- Safe to run more than once - only adds the column if it doesn't
-- already exist.
-- ============================================================

SET SERVEROUTPUT ON

BEGIN
  EXECUTE IMMEDIATE 'ALTER TABLE USERS ADD PROFILE_IMAGE VARCHAR2(500)';
  DBMS_OUTPUT.PUT_LINE('Added USERS.PROFILE_IMAGE');
EXCEPTION WHEN OTHERS THEN
  IF SQLCODE = -1430 THEN -- column already exists
    DBMS_OUTPUT.PUT_LINE('USERS.PROFILE_IMAGE already exists - skipped');
  ELSE
    RAISE;
  END IF;
END;
/

COMMIT;

SELECT COLUMN_NAME, DATA_TYPE FROM USER_TAB_COLUMNS
WHERE TABLE_NAME = 'USERS' AND COLUMN_NAME = 'PROFILE_IMAGE';
