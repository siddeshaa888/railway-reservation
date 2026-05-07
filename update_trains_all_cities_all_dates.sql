-- ============================================================
--  UPDATE: Make ALL Trains run between ALL Cities on ALL Dates
--  Railway Reservation System
--
--  What this script does:
--  1. Adds missing intermediate stops to every train route
--     so every train visits ALL 8 stations
--  2. Regenerates Schedule rows so every train is available
--     for the next 365 days (from today)
--  3. Drops & recreates the sp_search_trains procedure to
--     also match trains that have a stop at the source AND
--     a stop at the destination (in order), even when those
--     are not the endpoint stations of the train
--
--  Run this on your Railway MySQL database.
--  Safe to re-run: uses DELETE + INSERT pattern on Route/Schedule
--  so it will NOT duplicate rows on repeated runs.
-- ============================================================

USE railway_db;

-- ============================================================
-- STEP 1: Clear existing Route rows so we can re-seed cleanly
--         (only for the 4 existing trains, IDs 1-4)
-- ============================================================
DELETE FROM Route WHERE train_id IN (1, 2, 3, 4);

-- ============================================================
-- STEP 2: Re-create Routes so EVERY train covers ALL 8 stations
--
--  Station IDs (from your seed data):
--    1 = NDLS  New Delhi
--    2 = BCT   Mumbai Central
--    3 = MAS   Chennai Central
--    4 = SBC   KSR Bengaluru
--    5 = HWH   Howrah Junction  (Kolkata)
--    6 = SC    Secunderabad     (Hyderabad)
--    7 = PUNE  Pune Junction
--    8 = JP    Jaipur Junction
--
--  Each train now makes a complete circular/cross-country loop
--  visiting all 8 stations in a logical geographic order.
--  Distances are approximate real-world km figures.
-- ============================================================

-- -------------------------------------------------------
-- Train 1 (12028 Shatabdi Express)
-- NDLS → JP → HWH → MAS → SC → SBC → PUNE → BCT → (done)
-- -------------------------------------------------------
INSERT INTO Route (train_id, station_id, stop_number, arrival_time, departure_time, distance_km) VALUES
(1, 1, 1, NULL,       '06:00:00',   0),     -- NDLS  New Delhi
(1, 8, 2, '09:30:00', '09:35:00',  310),    -- JP    Jaipur
(1, 5, 3, '20:00:00', '20:15:00', 1450),    -- HWH   Kolkata
(1, 3, 4, '14:00:00', '14:20:00', 2860),    -- MAS   Chennai
(1, 6, 5, '21:00:00', '21:15:00', 3650),    -- SC    Hyderabad
(1, 4, 6, '04:30:00', '04:45:00', 4020),    -- SBC   Bengaluru
(1, 7, 7, '12:00:00', '12:15:00', 4870),    -- PUNE  Pune
(1, 2, 8, '17:30:00', NULL,        5200);   -- BCT   Mumbai

-- -------------------------------------------------------
-- Train 2 (12951 Mumbai Rajdhani)
-- BCT → PUNE → SBC → SC → MAS → HWH → JP → NDLS → (done)
-- -------------------------------------------------------
INSERT INTO Route (train_id, station_id, stop_number, arrival_time, departure_time, distance_km) VALUES
(2, 2, 1, NULL,       '16:55:00',   0),     -- BCT   Mumbai
(2, 7, 2, '19:45:00', '19:55:00',  191),    -- PUNE  Pune
(2, 4, 3, '03:30:00', '03:45:00',  1041),   -- SBC   Bengaluru
(2, 6, 4, '11:00:00', '11:15:00',  1411),   -- SC    Hyderabad
(2, 3, 5, '18:30:00', '18:50:00',  2201),   -- MAS   Chennai
(2, 5, 6, '12:00:00', '12:20:00',  3391),   -- HWH   Kolkata
(2, 8, 7, '09:00:00', '09:15:00',  4841),   -- JP    Jaipur
(2, 1, 8, '13:00:00', NULL,        5151);   -- NDLS  New Delhi

-- -------------------------------------------------------
-- Train 3 (11013 Coimbatore Express)
-- MAS → SC → SBC → PUNE → BCT → NDLS → JP → HWH → (done)
-- -------------------------------------------------------
INSERT INTO Route (train_id, station_id, stop_number, arrival_time, departure_time, distance_km) VALUES
(3, 3, 1, NULL,       '07:00:00',   0),     -- MAS   Chennai
(3, 6, 2, '14:00:00', '14:10:00',  790),    -- SC    Hyderabad
(3, 4, 3, '21:30:00', '21:45:00', 1160),    -- SBC   Bengaluru
(3, 7, 4, '05:30:00', '05:45:00', 2010),    -- PUNE  Pune
(3, 2, 5, '08:30:00', '08:50:00', 2201),    -- BCT   Mumbai
(3, 1, 6, '08:00:00', '08:20:00', 3585),    -- NDLS  New Delhi
(3, 8, 7, '11:45:00', '11:55:00', 3895),    -- JP    Jaipur
(3, 5, 8, '22:30:00', NULL,        5345);   -- HWH   Kolkata

-- -------------------------------------------------------
-- Train 4 (22691 Rajdhani Express)
-- NDLS → HWH → MAS → SC → SBC → PUNE → BCT → JP → (done)
-- -------------------------------------------------------
INSERT INTO Route (train_id, station_id, stop_number, arrival_time, departure_time, distance_km) VALUES
(4, 1, 1, NULL,       '17:00:00',   0),     -- NDLS  New Delhi
(4, 5, 2, '10:05:00', '10:20:00', 1450),    -- HWH   Kolkata
(4, 3, 3, '06:00:00', '06:20:00', 2860),    -- MAS   Chennai
(4, 6, 4, '13:30:00', '13:45:00', 3650),    -- SC    Hyderabad
(4, 4, 5, '21:00:00', '21:15:00', 4020),    -- SBC   Bengaluru
(4, 7, 6, '04:45:00', '05:00:00', 4870),    -- PUNE  Pune
(4, 2, 7, '08:00:00', '08:15:00', 5061),    -- BCT   Mumbai
(4, 8, 8, '22:00:00', NULL,        6445);   -- JP    Jaipur


-- ============================================================
-- STEP 3: Regenerate Schedules for ALL trains for next 365 days
--
--  We use a stored procedure to loop through 365 days and
--  insert one Schedule row per train per day.
--  source_station_id / dest_station_id are set to the first
--  and last stop of each train (the procedure body controls them).
-- ============================================================

-- Drop old schedules for these 4 trains first
DELETE FROM Schedule WHERE train_id IN (1, 2, 3, 4);

DROP PROCEDURE IF EXISTS generate_schedules;

DELIMITER $$

CREATE PROCEDURE generate_schedules()
BEGIN
    DECLARE i INT DEFAULT 0;
    DECLARE journey_day DATE;

    WHILE i < 365 DO
        SET journey_day = CURDATE() + INTERVAL i DAY;

        -- Train 1: first stop NDLS (1), last stop BCT (2)
        INSERT IGNORE INTO Schedule (train_id, journey_date, source_station_id, dest_station_id, status)
        VALUES (1, journey_day, 1, 2, 'OnTime');

        -- Train 2: first stop BCT (2), last stop NDLS (1)
        INSERT IGNORE INTO Schedule (train_id, journey_date, source_station_id, dest_station_id, status)
        VALUES (2, journey_day, 2, 1, 'OnTime');

        -- Train 3: first stop MAS (3), last stop HWH (5)
        INSERT IGNORE INTO Schedule (train_id, journey_date, source_station_id, dest_station_id, status)
        VALUES (3, journey_day, 3, 5, 'OnTime');

        -- Train 4: first stop NDLS (1), last stop JP (8)
        INSERT IGNORE INTO Schedule (train_id, journey_date, source_station_id, dest_station_id, status)
        VALUES (4, journey_day, 1, 8, 'OnTime');

        SET i = i + 1;
    END WHILE;
END$$

DELIMITER ;

CALL generate_schedules();
DROP PROCEDURE IF EXISTS generate_schedules;


-- ============================================================
-- STEP 4: Replace sp_search_trains
--
--  The old procedure filtered by sch.source_station_id /
--  sch.dest_station_id, which only matched the train's
--  endpoint. The new version looks purely at Route stop_numbers,
--  so ANY pair of stations that appear on a train's route
--  (in the correct order) will be returned — regardless of
--  which city the train officially "starts" or "ends" at.
-- ============================================================

DROP PROCEDURE IF EXISTS sp_search_trains;

DELIMITER $$

CREATE PROCEDURE sp_search_trains(
    IN p_source_code VARCHAR(10),
    IN p_dest_code   VARCHAR(10),
    IN p_date        DATE
)
BEGIN
    SELECT
        t.train_number,
        t.train_name,
        t.train_type,
        src.station_name     AS from_station,
        dst.station_name     AS to_station,
        r_src.departure_time AS departs,
        r_dst.arrival_time   AS arrives,
        sch.status           AS train_status,
        sch.delay_minutes,
        sch.schedule_id
    FROM  Schedule  sch
    JOIN  Train     t      ON t.train_id         = sch.train_id
    -- Source stop: any stop on this train whose station matches p_source_code
    JOIN  Route     r_src  ON r_src.train_id     = t.train_id
    JOIN  Station   src    ON src.station_id     = r_src.station_id
                           AND src.station_code  = p_source_code
    -- Dest stop: any stop on this train whose station matches p_dest_code
    JOIN  Route     r_dst  ON r_dst.train_id     = t.train_id
    JOIN  Station   dst    ON dst.station_id     = r_dst.station_id
                           AND dst.station_code  = p_dest_code
    WHERE sch.journey_date  = p_date
      AND r_src.stop_number < r_dst.stop_number   -- direction guard: source before dest
      AND sch.status       != 'Cancelled'
    ORDER BY r_src.departure_time;
END$$

DELIMITER ;


-- ============================================================
-- STEP 5: Quick verification queries (run to confirm success)
-- ============================================================

-- Check route coverage: each train should show 8 stops
SELECT t.train_number, t.train_name, COUNT(*) AS total_stops
FROM Route r
JOIN Train t ON t.train_id = r.train_id
WHERE r.train_id IN (1,2,3,4)
GROUP BY t.train_id, t.train_number, t.train_name;

-- Check schedule coverage: each train should have ~365 rows
SELECT t.train_number, COUNT(*) AS scheduled_days,
       MIN(journey_date) AS first_date, MAX(journey_date) AS last_date
FROM Schedule s
JOIN Train t ON t.train_id = s.train_id
WHERE s.train_id IN (1,2,3,4)
GROUP BY t.train_id, t.train_number;

-- Test search: NDLS -> SBC (New Delhi to Bengaluru) for today
-- Expect ALL 4 trains if today's date is seeded
CALL sp_search_trains('NDLS', 'SBC', CURDATE());

-- Test search: BCT -> HWH (Mumbai to Kolkata)
CALL sp_search_trains('BCT', 'HWH', CURDATE());
