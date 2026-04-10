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
-- ROUTES (cumulative distance from origin in km)
-- ─────────────────────────────────────────────────────────────

-- Train 12028: NDLS → JP → SBC
INSERT INTO Route (train_id, station_id, stop_number, arrival_time, departure_time, distance_km) VALUES
(1, 1, 1, NULL,       '06:00:00', 0),
(1, 8, 2, '09:30:00', '09:35:00', 310),
(1, 4, 3, '20:00:00', NULL,       2150);

-- Train 12951: NDLS → BCT
INSERT INTO Route (train_id, station_id, stop_number, arrival_time, departure_time, distance_km) VALUES
(2, 1, 1, NULL,       '16:55:00', 0),
(2, 2, 2, '08:15:00', NULL,       1384);

-- Train 11013: MAS → SC → SBC
INSERT INTO Route (train_id, station_id, stop_number, arrival_time, departure_time, distance_km) VALUES
(3, 3, 1, NULL,       '07:00:00', 0),
(3, 6, 2, '14:00:00', '14:10:00', 790),
(3, 4, 3, '21:30:00', NULL,       1160);

-- Train 22691: NDLS → HWH
INSERT INTO Route (train_id, station_id, stop_number, arrival_time, departure_time, distance_km) VALUES
(4, 1, 1, NULL,       '17:00:00', 0),
(4, 5, 2, '10:05:00', NULL,       1450);

-- ─────────────────────────────────────────────────────────────
-- SCHEDULES (running dates, relative to today for repeatability)
-- ─────────────────────────────────────────────────────────────
INSERT INTO Schedule (train_id, journey_date, source_station_id, dest_station_id, status) VALUES
(1, CURDATE() + INTERVAL 1 DAY, 1, 4, 'OnTime'),
(1, CURDATE() + INTERVAL 2 DAY, 1, 4, 'OnTime'),
(2, CURDATE() + INTERVAL 1 DAY, 1, 2, 'OnTime'),
(2, CURDATE() + INTERVAL 3 DAY, 1, 2, 'OnTime'),
(3, CURDATE() + INTERVAL 1 DAY, 3, 4, 'OnTime'),
(4, CURDATE() + INTERVAL 2 DAY, 1, 5, 'OnTime');

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
