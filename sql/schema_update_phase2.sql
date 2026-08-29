-- ============================================================
-- Backpackr Phase 2 Schema Update
-- AI-generated day-wise itinerary support
-- ============================================================

ALTER TABLE TRIP_STOPS ADD (
    DAY_NUMBER      NUMBER DEFAULT 1,
    AI_NOTE         VARCHAR2(1000)
);

ALTER TABLE TRIPS ADD (
    AI_SUMMARY      VARCHAR2(2000)
);

COMMIT;
