-- ============================================================
--   RAILWAY RESERVATION SYSTEM — 02_sample_data.sql  (UPDATED)
--   Changes:
--     • Every train now stops at ALL 8 stations (full route)
--     • Every train has a Schedule entry for every day
--       from today through today + 365 days (generated via loop)
--   Run AFTER 01_schema.sql
-- ============================================================
USE railway_db;

-- ─────────────────────────────────────────────────────────────
-- STATIONS (8 major Indian railway stations)
-- ─────────────────────────────────────────────────────────────
INSERT INTO Station (station_code, station_name, city, state, zone) VALUES
('NDLS', 'New Delhi',        'New Delhi',  'Delhi',       'Northern'),
('BCT',  'Mumbai Central',   'Mumbai',     'Maharashtra', 'Western'),
('MAS',  'Chennai Central',  'Chennai',    'Tamil Nadu',  'Southern'),
('SBC',  'KSR Bengaluru',    'Bengaluru',  'Karnataka',   'South Western'),
('HWH',  'Howrah Junction',  'Kolkata',    'West Bengal', 'Eastern'),
('SC',   'Secunderabad',     'Hyderabad',  'Telangana',   'South Central'),
('PUNE', 'Pune Junction',    'Pune',       'Maharashtra', 'Central'),
('JP',   'Jaipur Junction',  'Jaipur',     'Rajasthan',   'North Western');

-- ─────────────────────────────────────────────────────────────
-- SEAT CLASSES with fare rates (₹ per km)
-- ─────────────────────────────────────────────────────────────
INSERT INTO Seat_Class (class_code, class_name, fare_per_km) VALUES
('1A',  'First AC',         3.50),
('2A',  'Second AC',        2.20),
('3A',  'Third AC',         1.60),
('SL',  'Sleeper',          0.55),
('CC',  'Chair Car AC',     1.80),
('2S',  'Second Sitting',   0.28);

-- ─────────────────────────────────────────────────────────────
-- TRAINS
-- ─────────────────────────────────────────────────────────────
INSERT INTO Train (train_number, train_name, train_type, total_seats) VALUES
('12028', 'Shatabdi Express',   'Shatabdi',  450),
('12951', 'Mumbai Rajdhani',    'Rajdhani',  600),
('11013', 'Coimbatore Express', 'Express',   800),
('22691', 'Rajdhani Express',   'Rajdhani',  500);

-- ─────────────────────────────────────────────────────────────
-- ROUTES  — every train covers all 8 stations
--
-- Station IDs (in insert order above):
--   1=NDLS(Delhi)  2=BCT(Mumbai)   3=MAS(Chennai)  4=SBC(Bengaluru)
--   5=HWH(Kolkata) 6=SC(Hyderabad) 7=PUNE(Pune)    8=JP(Jaipur)
--
-- Route order chosen to be geographically sensible for each train:
--   Train 1 (Shatabdi)  : NDLS→JP→PUNE→BCT→SC→MAS→SBC→HWH
--   Train 2 (Mumbai Raj): BCT→PUNE→SC→SBC→MAS→HWH→JP→NDLS
--   Train 3 (Coimbatore): MAS→SBC→SC→PUNE→BCT→JP→NDLS→HWH
--   Train 4 (Rajdhani)  : NDLS→HWH→JP→SC→PUNE→BCT→SBC→MAS
-- ─────────────────────────────────────────────────────────────

-- ── Train 1 (train_id=1): NDLS → JP → PUNE → BCT → SC → MAS → SBC → HWH ──
INSERT INTO Route (train_id, station_id, stop_number, arrival_time, departure_time, distance_km) VALUES
(1, 1, 1, NULL,        '06:00:00',  0),      -- NDLS  origin
(1, 8, 2, '09:30:00',  '09:35:00',  310),    -- JP    +310 km
(1, 7, 3, '15:00:00',  '15:10:00',  1460),   -- PUNE  +1150
(1, 2, 4, '17:30:00',  '17:45:00',  1650),   -- BCT   +190
(1, 6, 5, '23:00:00',  '23:10:00',  2300),   -- SC    +650
(1, 3, 6, '05:30:00',  '05:40:00',  3090),   -- MAS   +790
(1, 4, 7, '11:00:00',  '11:10:00',  3450),   -- SBC   +360
(1, 5, 8, '22:00:00',  NULL,        4900);   -- HWH   +1450  terminus

-- ── Train 2 (train_id=2): BCT → PUNE → SC → SBC → MAS → HWH → JP → NDLS ──
INSERT INTO Route (train_id, station_id, stop_number, arrival_time, departure_time, distance_km) VALUES
(2, 2, 1, NULL,        '16:55:00',  0),      -- BCT   origin
(2, 7, 2, '19:10:00',  '19:20:00',  190),    -- PUNE  +190
(2, 6, 3, '01:30:00',  '01:40:00',  840),    -- SC    +650
(2, 4, 4, '08:00:00',  '08:10:00',  1210),   -- SBC   +370
(2, 3, 5, '13:30:00',  '13:40:00',  1570),   -- MAS   +360
(2, 5, 6, '05:00:00',  '05:10:00',  3020),   -- HWH   +1450
(2, 8, 7, '18:00:00',  '18:10:00',  3840),   -- JP    +820
(2, 1, 8, '21:30:00',  NULL,        4168);   -- NDLS  +328  terminus

-- ── Train 3 (train_id=3): MAS → SBC → SC → PUNE → BCT → JP → NDLS → HWH ──
INSERT INTO Route (train_id, station_id, stop_number, arrival_time, departure_time, distance_km) VALUES
(3, 3, 1, NULL,        '07:00:00',  0),      -- MAS   origin
(3, 4, 2, '12:30:00',  '12:40:00',  360),    -- SBC   +360
(3, 6, 3, '18:00:00',  '18:10:00',  730),    -- SC    +370
(3, 7, 4, '23:30:00',  '23:40:00',  1380),   -- PUNE  +650
(3, 2, 5, '01:45:00',  '02:00:00',  1570),   -- BCT   +190
(3, 8, 6, '13:00:00',  '13:10:00',  2770),   -- JP    +1200
(3, 1, 7, '16:30:00',  '16:40:00',  3080),   -- NDLS  +310
(3, 5, 8, '10:00:00',  NULL,        4530);   -- HWH   +1450  terminus

-- ── Train 4 (train_id=4): NDLS → HWH → JP → SC → PUNE → BCT → SBC → MAS ──
INSERT INTO Route (train_id, station_id, stop_number, arrival_time, departure_time, distance_km) VALUES
(4, 1, 1, NULL,        '17:00:00',  0),      -- NDLS  origin
(4, 5, 2, '10:05:00',  '10:15:00',  1450),   -- HWH   +1450
(4, 8, 3, '22:00:00',  '22:10:00',  2270),   -- JP    +820
(4, 6, 4, '10:00:00',  '10:10:00',  3430),   -- SC    +1160
(4, 7, 5, '15:30:00',  '15:40:00',  4080),   -- PUNE  +650
(4, 2, 6, '17:50:00',  '18:05:00',  4270),   -- BCT   +190
(4, 4, 7, '23:30:00',  '23:40:00',  4640),   -- SBC   +370
(4, 3, 8, '05:00:00',  NULL,        5000);   -- MAS   +360   terminus

-- ─────────────────────────────────────────────────────────────
-- SCHEDULES — every train available on EVERY date
--             (today through today + 365 days)
--
--  source_station_id = first stop of each train's route
--  dest_station_id   = last stop of each train's route
--
--  Train 1: source=1 (NDLS), dest=5 (HWH)
--  Train 2: source=2 (BCT),  dest=1 (NDLS)
--  Train 3: source=3 (MAS),  dest=5 (HWH)
--  Train 4: source=1 (NDLS), dest=3 (MAS)
-- ─────────────────────────────────────────────────────────────
DELIMITER $$
CREATE PROCEDURE seed_schedules()
BEGIN
    DECLARE i INT DEFAULT 0;
    WHILE i <= 365 DO
        INSERT IGNORE INTO Schedule
            (train_id, journey_date, source_station_id, dest_station_id, status)
        VALUES
            (1, CURDATE() + INTERVAL i DAY, 1, 5, 'OnTime'),
            (2, CURDATE() + INTERVAL i DAY, 2, 1, 'OnTime'),
            (3, CURDATE() + INTERVAL i DAY, 3, 5, 'OnTime'),
            (4, CURDATE() + INTERVAL i DAY, 1, 3, 'OnTime');
        SET i = i + 1;
    END WHILE;
END$$
DELIMITER ;

CALL seed_schedules();
DROP PROCEDURE seed_schedules;

-- ─────────────────────────────────────────────────────────────
-- SEATS  (10 seats × 4 classes × 4 trains via loop procedure)
-- ─────────────────────────────────────────────────────────────
DELIMITER $$
CREATE PROCEDURE seed_seats()
BEGIN
    DECLARE t INT DEFAULT 1;
    DECLARE c TINYINT;
    DECLARE s INT;
    WHILE t <= 4 DO
        SET c = 1;
        WHILE c <= 4 DO
            SET s = 1;
            WHILE s <= 10 DO
                INSERT IGNORE INTO Seat (train_id, class_id, coach_number, seat_number, berth_type)
                VALUES (
                    t, c,
                    CONCAT(ELT(c,'A','B','C','S'), CEIL(s/4)),
                    LPAD(s, 2, '0'),
                    ELT(((s-1) MOD 4) + 1, 'Lower','Middle','Upper','Side Lower')
                );
                SET s = s + 1;
            END WHILE;
            SET c = c + 1;
        END WHILE;
        SET t = t + 1;
    END WHILE;
END$$
DELIMITER ;

CALL seed_seats();
DROP PROCEDURE seed_seats;

-- ─────────────────────────────────────────────────────────────
-- PASSENGERS (5 sample passengers)
-- ─────────────────────────────────────────────────────────────
INSERT INTO Passenger (full_name, gender, dob, email, phone, id_type, id_number) VALUES
('Arjun Sharma',  'Male',   '1990-05-12', 'arjun@example.com',  '9876543210', 'Aadhaar',  '123412341234'),
('Priya Nair',    'Female', '1995-08-23', 'priya@example.com',  '9123456789', 'Passport', 'P1234567'),
('Rahul Mehta',   'Male',   '1988-02-14', 'rahul@example.com',  '9988776655', 'Aadhaar',  '567856785678'),
('Sneha Reddy',   'Female', '2000-11-30', 'sneha@example.com',  '9090909090', 'PAN',      'ABCDE1234F'),
('Vikram Singh',  'Male',   '1975-07-04', 'vikram@example.com', '8800112233', 'VoterID',  'VID987654');
