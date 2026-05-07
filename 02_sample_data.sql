-- ============================================================
--   RAILWAY RESERVATION SYSTEM — 02_sample_data.sql
--   All INSERT statements for demo / testing
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
-- ROUTES — Every train covers ALL 8 stations
--
--  Station IDs:
--    1=NDLS(New Delhi)  2=BCT(Mumbai)  3=MAS(Chennai)
--    4=SBC(Bengaluru)   5=HWH(Kolkata) 6=SC(Hyderabad)
--    7=PUNE(Pune)       8=JP(Jaipur)
-- ─────────────────────────────────────────────────────────────

-- Train 1 (12028 Shatabdi): NDLS→JP→HWH→MAS→SC→SBC→PUNE→BCT
INSERT INTO Route (train_id, station_id, stop_number, arrival_time, departure_time, distance_km) VALUES
(1, 1, 1, NULL,       '06:00:00',   0),
(1, 8, 2, '09:30:00', '09:35:00',  310),
(1, 5, 3, '20:00:00', '20:15:00', 1450),
(1, 3, 4, '14:00:00', '14:20:00', 2860),
(1, 6, 5, '21:00:00', '21:15:00', 3650),
(1, 4, 6, '04:30:00', '04:45:00', 4020),
(1, 7, 7, '12:00:00', '12:15:00', 4870),
(1, 2, 8, '17:30:00', NULL,        5200);

-- Train 2 (12951 Mumbai Rajdhani): BCT→PUNE→SBC→SC→MAS→HWH→JP→NDLS
INSERT INTO Route (train_id, station_id, stop_number, arrival_time, departure_time, distance_km) VALUES
(2, 2, 1, NULL,       '16:55:00',   0),
(2, 7, 2, '19:45:00', '19:55:00',  191),
(2, 4, 3, '03:30:00', '03:45:00', 1041),
(2, 6, 4, '11:00:00', '11:15:00', 1411),
(2, 3, 5, '18:30:00', '18:50:00', 2201),
(2, 5, 6, '12:00:00', '12:20:00', 3391),
(2, 8, 7, '09:00:00', '09:15:00', 4841),
(2, 1, 8, '13:00:00', NULL,        5151);

-- Train 3 (11013 Coimbatore Express): MAS→SC→SBC→PUNE→BCT→NDLS→JP→HWH
INSERT INTO Route (train_id, station_id, stop_number, arrival_time, departure_time, distance_km) VALUES
(3, 3, 1, NULL,       '07:00:00',   0),
(3, 6, 2, '14:00:00', '14:10:00',  790),
(3, 4, 3, '21:30:00', '21:45:00', 1160),
(3, 7, 4, '05:30:00', '05:45:00', 2010),
(3, 2, 5, '08:30:00', '08:50:00', 2201),
(3, 1, 6, '08:00:00', '08:20:00', 3585),
(3, 8, 7, '11:45:00', '11:55:00', 3895),
(3, 5, 8, '22:30:00', NULL,        5345);

-- Train 4 (22691 Rajdhani Express): NDLS→HWH→MAS→SC→SBC→PUNE→BCT→JP
INSERT INTO Route (train_id, station_id, stop_number, arrival_time, departure_time, distance_km) VALUES
(4, 1, 1, NULL,       '17:00:00',   0),
(4, 5, 2, '10:05:00', '10:20:00', 1450),
(4, 3, 3, '06:00:00', '06:20:00', 2860),
(4, 6, 4, '13:30:00', '13:45:00', 3650),
(4, 4, 5, '21:00:00', '21:15:00', 4020),
(4, 7, 6, '04:45:00', '05:00:00', 4870),
(4, 2, 7, '08:00:00', '08:15:00', 5061),
(4, 8, 8, '22:00:00', NULL,        6445);

-- ─────────────────────────────────────────────────────────────
-- SCHEDULES — All 4 trains for the next 365 days
-- ─────────────────────────────────────────────────────────────
DROP PROCEDURE IF EXISTS seed_schedules;
DELIMITER $$
CREATE PROCEDURE seed_schedules()
BEGIN
    DECLARE i INT DEFAULT 0;
    DECLARE journey_day DATE;
    WHILE i < 365 DO
        SET journey_day = CURDATE() + INTERVAL i DAY;
        INSERT IGNORE INTO Schedule (train_id, journey_date, source_station_id, dest_station_id, status)
        VALUES (1, journey_day, 1, 2, 'OnTime');
        INSERT IGNORE INTO Schedule (train_id, journey_date, source_station_id, dest_station_id, status)
        VALUES (2, journey_day, 2, 1, 'OnTime');
        INSERT IGNORE INTO Schedule (train_id, journey_date, source_station_id, dest_station_id, status)
        VALUES (3, journey_day, 3, 5, 'OnTime');
        INSERT IGNORE INTO Schedule (train_id, journey_date, source_station_id, dest_station_id, status)
        VALUES (4, journey_day, 1, 8, 'OnTime');
        SET i = i + 1;
    END WHILE;
END$$
DELIMITER ;
CALL seed_schedules();
DROP PROCEDURE IF EXISTS seed_schedules;

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
