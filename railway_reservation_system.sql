-- ============================================================
--        RAILWAY RESERVATION SYSTEM — MySQL Script
--  Normalized Schema | Triggers | Procedures | Views | Indexes
-- ============================================================

-- ─────────────────────────────────────────────────────────────
-- 0. SETUP
-- ─────────────────────────────────────────────────────────────
DROP DATABASE IF EXISTS railway_db;
CREATE DATABASE railway_db
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;
USE railway_db;

SET FOREIGN_KEY_CHECKS = 0;
SET SQL_MODE = 'STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,ERROR_FOR_DIVISION_BY_ZERO';


-- ==============================================================
-- SECTION 1 — NORMALIZED SCHEMA (3NF)
-- ==============================================================

-- ─────────────────────────────────────────────────────────────
-- 1.1  STATION
-- ─────────────────────────────────────────────────────────────
CREATE TABLE Station (
    station_id    INT          UNSIGNED NOT NULL AUTO_INCREMENT,
    station_code  VARCHAR(10)  NOT NULL,          -- e.g. 'SBC', 'NDLS'
    station_name  VARCHAR(100) NOT NULL,
    city          VARCHAR(80)  NOT NULL,
    state         VARCHAR(80)  NOT NULL,
    zone          VARCHAR(50)  NOT NULL,           -- e.g. 'Southern', 'Northern'
    PRIMARY KEY (station_id),
    UNIQUE KEY uq_station_code (station_code)
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────────────────────
-- 1.2  TRAIN
-- ─────────────────────────────────────────────────────────────
CREATE TABLE Train (
    train_id      INT          UNSIGNED NOT NULL AUTO_INCREMENT,
    train_number  VARCHAR(10)  NOT NULL,           -- e.g. '12028'
    train_name    VARCHAR(120) NOT NULL,
    train_type    ENUM('Express','Superfast','Rajdhani','Shatabdi',
                       'Duronto','Passenger','Local') NOT NULL,
    total_seats   SMALLINT     UNSIGNED NOT NULL,
    PRIMARY KEY (train_id),
    UNIQUE KEY uq_train_number (train_number)
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────────────────────
-- 1.3  ROUTE  (ordered list of stations on a train's path)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE Route (
    route_id       INT      UNSIGNED NOT NULL AUTO_INCREMENT,
    train_id       INT      UNSIGNED NOT NULL,
    station_id     INT      UNSIGNED NOT NULL,
    stop_number    TINYINT  UNSIGNED NOT NULL,    -- 1 = origin, n = terminus
    arrival_time   TIME     NULL,                 -- NULL for first stop
    departure_time TIME     NULL,                 -- NULL for last stop
    distance_km    SMALLINT UNSIGNED NOT NULL DEFAULT 0, -- cumulative from origin
    PRIMARY KEY (route_id),
    UNIQUE KEY uq_train_stop (train_id, stop_number),
    UNIQUE KEY uq_train_station (train_id, station_id),
    CONSTRAINT fk_route_train   FOREIGN KEY (train_id)   REFERENCES Train(train_id),
    CONSTRAINT fk_route_station FOREIGN KEY (station_id) REFERENCES Station(station_id)
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────────────────────
-- 1.4  SCHEDULE  (a specific running date for a train)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE Schedule (
    schedule_id       INT      UNSIGNED NOT NULL AUTO_INCREMENT,
    train_id          INT      UNSIGNED NOT NULL,
    journey_date      DATE     NOT NULL,
    source_station_id INT      UNSIGNED NOT NULL,
    dest_station_id   INT      UNSIGNED NOT NULL,
    status            ENUM('OnTime','Delayed','Cancelled') NOT NULL DEFAULT 'OnTime',
    delay_minutes     SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (schedule_id),
    UNIQUE KEY uq_schedule (train_id, journey_date),
    CONSTRAINT fk_sched_train  FOREIGN KEY (train_id)          REFERENCES Train(train_id),
    CONSTRAINT fk_sched_src    FOREIGN KEY (source_station_id) REFERENCES Station(station_id),
    CONSTRAINT fk_sched_dest   FOREIGN KEY (dest_station_id)   REFERENCES Station(station_id)
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────────────────────
-- 1.5  SEAT_CLASS  (lookup for class definitions & fare factor)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE Seat_Class (
    class_id     TINYINT     UNSIGNED NOT NULL AUTO_INCREMENT,
    class_code   VARCHAR(5)  NOT NULL,    -- e.g. '1A','2A','3A','SL','CC','2S'
    class_name   VARCHAR(50) NOT NULL,
    fare_per_km  DECIMAL(5,2) NOT NULL,  -- base rupees per km
    PRIMARY KEY (class_id),
    UNIQUE KEY uq_class_code (class_code)
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────────────────────
-- 1.6  SEAT  (physical seats on a specific train per class)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE Seat (
    seat_id      INT         UNSIGNED NOT NULL AUTO_INCREMENT,
    train_id     INT         UNSIGNED NOT NULL,
    class_id     TINYINT     UNSIGNED NOT NULL,
    coach_number VARCHAR(5)  NOT NULL,   -- e.g. 'A1', 'B2', 'S3'
    seat_number  VARCHAR(5)  NOT NULL,   -- e.g. '12', '45 LB'
    berth_type   ENUM('Lower','Middle','Upper','Side Lower','Side Upper','Window','Aisle','None')
                 NOT NULL DEFAULT 'None',
    PRIMARY KEY (seat_id),
    UNIQUE KEY uq_seat (train_id, class_id, coach_number, seat_number),
    CONSTRAINT fk_seat_train FOREIGN KEY (train_id) REFERENCES Train(train_id),
    CONSTRAINT fk_seat_class FOREIGN KEY (class_id) REFERENCES Seat_Class(class_id)
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────────────────────
-- 1.7  PASSENGER
-- ─────────────────────────────────────────────────────────────
CREATE TABLE Passenger (
    passenger_id  INT          UNSIGNED NOT NULL AUTO_INCREMENT,
    full_name     VARCHAR(100) NOT NULL,
    gender        ENUM('Male','Female','Other') NOT NULL,
    dob           DATE         NOT NULL,
    email         VARCHAR(150) NOT NULL,
    phone         VARCHAR(15)  NOT NULL,
    id_type       ENUM('Aadhaar','Passport','PAN','VoterID','DrivingLicence') NOT NULL,
    id_number     VARCHAR(30)  NOT NULL,
    created_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (passenger_id),
    UNIQUE KEY uq_email   (email),
    UNIQUE KEY uq_id_doc  (id_type, id_number)
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────────────────────
-- 1.8  BOOKING
-- ─────────────────────────────────────────────────────────────
CREATE TABLE Booking (
    booking_id    INT          UNSIGNED NOT NULL AUTO_INCREMENT,
    pnr           CHAR(10)     NOT NULL,
    passenger_id  INT          UNSIGNED NOT NULL,
    schedule_id   INT          UNSIGNED NOT NULL,
    seat_id       INT          UNSIGNED NULL,           -- NULL while on waitlist
    class_id      TINYINT      UNSIGNED NOT NULL,
    booking_date  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    journey_date  DATE         NOT NULL,
    source_station_id INT      UNSIGNED NOT NULL,
    dest_station_id   INT      UNSIGNED NOT NULL,
    num_passengers    TINYINT  UNSIGNED NOT NULL DEFAULT 1,
    fare          DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    booking_status ENUM('Confirmed','Waitlisted','Cancelled','Completed') NOT NULL DEFAULT 'Confirmed',
    waitlist_position SMALLINT UNSIGNED NULL,           -- NULL unless Waitlisted
    PRIMARY KEY (booking_id),
    UNIQUE KEY uq_pnr (pnr),
    CONSTRAINT fk_book_passenger FOREIGN KEY (passenger_id)       REFERENCES Passenger(passenger_id),
    CONSTRAINT fk_book_schedule  FOREIGN KEY (schedule_id)        REFERENCES Schedule(schedule_id),
    CONSTRAINT fk_book_seat      FOREIGN KEY (seat_id)            REFERENCES Seat(seat_id),
    CONSTRAINT fk_book_class     FOREIGN KEY (class_id)           REFERENCES Seat_Class(class_id),
    CONSTRAINT fk_book_src       FOREIGN KEY (source_station_id)  REFERENCES Station(station_id),
    CONSTRAINT fk_book_dest      FOREIGN KEY (dest_station_id)    REFERENCES Station(station_id)
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────────────────────
-- 1.9  PAYMENT
-- ─────────────────────────────────────────────────────────────
CREATE TABLE Payment (
    payment_id      INT          UNSIGNED NOT NULL AUTO_INCREMENT,
    booking_id      INT          UNSIGNED NOT NULL,
    amount          DECIMAL(10,2) NOT NULL,
    payment_method  ENUM('UPI','CreditCard','DebitCard','NetBanking','Wallet','Cash') NOT NULL,
    transaction_ref VARCHAR(60)  NULL,
    payment_status  ENUM('Pending','Success','Failed','Refunded') NOT NULL DEFAULT 'Pending',
    paid_at         TIMESTAMP    NULL,
    PRIMARY KEY (payment_id),
    CONSTRAINT fk_pay_booking FOREIGN KEY (booking_id) REFERENCES Booking(booking_id)
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────────────────────
-- 1.10  CANCELLATION
-- ─────────────────────────────────────────────────────────────
CREATE TABLE Cancellation (
    cancellation_id   INT           UNSIGNED NOT NULL AUTO_INCREMENT,
    booking_id        INT           UNSIGNED NOT NULL,
    cancelled_at      TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    cancellation_reason VARCHAR(255) NULL,
    refund_amount     DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    refund_status     ENUM('Pending','Processed','Rejected') NOT NULL DEFAULT 'Pending',
    PRIMARY KEY (cancellation_id),
    UNIQUE KEY uq_cancel_booking (booking_id),
    CONSTRAINT fk_cancel_booking FOREIGN KEY (booking_id) REFERENCES Booking(booking_id)
) ENGINE=InnoDB;

SET FOREIGN_KEY_CHECKS = 1;


-- ==============================================================
-- SECTION 2 — PERFORMANCE INDEXES
-- ==============================================================

-- PNR look‑up (very frequent)
CREATE INDEX idx_booking_pnr          ON Booking(pnr);

-- Passenger bookings
CREATE INDEX idx_booking_passenger    ON Booking(passenger_id);

-- Seat availability check per schedule & class
CREATE INDEX idx_booking_schedule     ON Booking(schedule_id, class_id, booking_status);

-- Train schedule search by date
CREATE INDEX idx_schedule_date        ON Schedule(journey_date, train_id);

-- Route traversal
CREATE INDEX idx_route_train_stop     ON Route(train_id, stop_number);

-- Station name search
CREATE INDEX idx_station_name         ON Station(station_name);

-- Waitlist ordering
CREATE INDEX idx_booking_waitlist     ON Booking(schedule_id, class_id, waitlist_position);

-- Cancellation refund queue
CREATE INDEX idx_cancel_refund_status ON Cancellation(refund_status);


-- ==============================================================
-- SECTION 3 — SAMPLE DATA
-- ==============================================================

-- 3.1 Stations
INSERT INTO Station (station_code, station_name, city, state, zone) VALUES
('NDLS', 'New Delhi',          'New Delhi',  'Delhi',         'Northern'),
('BCT',  'Mumbai Central',     'Mumbai',     'Maharashtra',   'Western'),
('MAS',  'Chennai Central',    'Chennai',    'Tamil Nadu',    'Southern'),
('SBC',  'KSR Bengaluru',      'Bengaluru',  'Karnataka',     'South Western'),
('HWH',  'Howrah Junction',    'Kolkata',    'West Bengal',   'Eastern'),
('SC',   'Secunderabad',       'Hyderabad',  'Telangana',     'South Central'),
('PUNE', 'Pune Junction',      'Pune',       'Maharashtra',   'Central'),
('JP',   'Jaipur Junction',    'Jaipur',     'Rajasthan',     'North Western');

-- 3.2 Seat Classes
INSERT INTO Seat_Class (class_code, class_name, fare_per_km) VALUES
('1A',  'First AC',             3.50),
('2A',  'Second AC',            2.20),
('3A',  'Third AC',             1.60),
('SL',  'Sleeper',              0.55),
('CC',  'Chair Car AC',         1.80),
('2S',  'Second Sitting',       0.28);

-- 3.3 Trains
INSERT INTO Train (train_number, train_name, train_type, total_seats) VALUES
('12028', 'Shatabdi Express',   'Shatabdi',  450),
('12951', 'Mumbai Rajdhani',    'Rajdhani',  600),
('11013', 'Coimbatore Express', 'Express',   800),
('22691', 'Rajdhani Express',   'Rajdhani',  500);

-- 3.4 Routes (Train 12028: NDLS → JP → SBC)
INSERT INTO Route (train_id, station_id, stop_number, arrival_time, departure_time, distance_km) VALUES
(1, 1, 1, NULL,       '06:00:00', 0),     -- NDLS (origin)
(1, 8, 2, '09:30:00', '09:35:00', 310),   -- JP
(1, 4, 3, '20:00:00', NULL,       2150);  -- SBC (terminus)

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

-- 3.5 Schedules
INSERT INTO Schedule (train_id, journey_date, source_station_id, dest_station_id, status) VALUES
(1, CURDATE() + INTERVAL 1 DAY,  1, 4, 'OnTime'),
(1, CURDATE() + INTERVAL 2 DAY,  1, 4, 'OnTime'),
(2, CURDATE() + INTERVAL 1 DAY,  1, 2, 'OnTime'),
(2, CURDATE() + INTERVAL 3 DAY,  1, 2, 'OnTime'),
(3, CURDATE() + INTERVAL 1 DAY,  3, 4, 'OnTime'),
(4, CURDATE() + INTERVAL 2 DAY,  1, 5, 'OnTime');

-- 3.6 Seats  (abbreviated — 10 seats per train per class for demo)
DELIMITER $$
CREATE PROCEDURE seed_seats()
BEGIN
    DECLARE t INT DEFAULT 1;
    DECLARE c TINYINT;
    DECLARE s INT;
    WHILE t <= 4 DO
        SET c = 1;
        WHILE c <= 4 DO        -- classes 1A,2A,3A,SL
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

-- 3.7 Passengers
INSERT INTO Passenger (full_name, gender, dob, email, phone, id_type, id_number) VALUES
('Arjun Sharma',   'Male',   '1990-05-12', 'arjun@example.com',   '9876543210', 'Aadhaar',  '123412341234'),
('Priya Nair',     'Female', '1995-08-23', 'priya@example.com',   '9123456789', 'Passport', 'P1234567'),
('Rahul Mehta',    'Male',   '1988-02-14', 'rahul@example.com',   '9988776655', 'Aadhaar',  '567856785678'),
('Sneha Reddy',    'Female', '2000-11-30', 'sneha@example.com',   '9090909090', 'PAN',      'ABCDE1234F'),
('Vikram Singh',   'Male',   '1975-07-04', 'vikram@example.com',  '8800112233', 'VoterID',  'VID987654');


-- ==============================================================
-- SECTION 4 — HELPER FUNCTION: PNR GENERATOR
-- ==============================================================
DELIMITER $$
CREATE FUNCTION generate_pnr() RETURNS CHAR(10)
    READS SQL DATA
    DETERMINISTIC
BEGIN
    DECLARE pnr_val CHAR(10);
    DECLARE exists_flag INT DEFAULT 1;
    WHILE exists_flag > 0 DO
        SET pnr_val = CONCAT(
            LPAD(FLOOR(RAND() * 10000), 4, '0'),
            LPAD(FLOOR(RAND() * 10000), 4, '0'),
            LPAD(FLOOR(RAND() * 100),   2, '0')
        );
        SELECT COUNT(*) INTO exists_flag FROM Booking WHERE pnr = pnr_val;
    END WHILE;
    RETURN pnr_val;
END$$
DELIMITER ;


-- ==============================================================
-- SECTION 5 — STORED PROCEDURE: FARE CALCULATOR
-- ==============================================================
DELIMITER $$
CREATE PROCEDURE sp_calculate_fare(
    IN  p_train_id          INT UNSIGNED,
    IN  p_source_station_id INT UNSIGNED,
    IN  p_dest_station_id   INT UNSIGNED,
    IN  p_class_code        VARCHAR(5),
    IN  p_num_passengers    TINYINT UNSIGNED,
    OUT p_fare              DECIMAL(10,2)
)
BEGIN
    DECLARE v_src_km   SMALLINT UNSIGNED DEFAULT 0;
    DECLARE v_dst_km   SMALLINT UNSIGNED DEFAULT 0;
    DECLARE v_distance SMALLINT UNSIGNED DEFAULT 0;
    DECLARE v_fpm      DECIMAL(5,2)      DEFAULT 0;
    DECLARE v_base     DECIMAL(10,2)     DEFAULT 0;
    DECLARE v_tax_rate DECIMAL(4,2)      DEFAULT 0.05;   -- 5 % GST

    -- Cumulative distances from route
    SELECT distance_km INTO v_src_km
      FROM Route
     WHERE train_id = p_train_id AND station_id = p_source_station_id;

    SELECT distance_km INTO v_dst_km
      FROM Route
     WHERE train_id = p_train_id AND station_id = p_dest_station_id;

    SET v_distance = ABS(v_dst_km - v_src_km);

    -- Fare per km for requested class
    SELECT fare_per_km INTO v_fpm
      FROM Seat_Class
     WHERE class_code = p_class_code;

    -- Base fare + GST × num_passengers
    SET v_base  = v_distance * v_fpm;
    SET p_fare  = ROUND((v_base + (v_base * v_tax_rate)) * p_num_passengers, 2);
END$$
DELIMITER ;


-- ==============================================================
-- SECTION 6 — STORED PROCEDURE: BOOK TICKET  (ACID transaction)
-- ==============================================================
DELIMITER $$
CREATE PROCEDURE sp_book_ticket(
    IN  p_passenger_id        INT UNSIGNED,
    IN  p_schedule_id         INT UNSIGNED,
    IN  p_class_code          VARCHAR(5),
    IN  p_source_station_id   INT UNSIGNED,
    IN  p_dest_station_id     INT UNSIGNED,
    IN  p_num_passengers      TINYINT UNSIGNED,
    IN  p_payment_method      VARCHAR(20),
    OUT p_pnr                 CHAR(10),
    OUT p_status              VARCHAR(20),
    OUT p_message             VARCHAR(200)
)
proc_body: BEGIN
    DECLARE v_train_id     INT UNSIGNED;
    DECLARE v_journey_date DATE;
    DECLARE v_class_id     TINYINT UNSIGNED;
    DECLARE v_seat_id      INT UNSIGNED DEFAULT NULL;
    DECLARE v_fare         DECIMAL(10,2) DEFAULT 0.00;
    DECLARE v_booking_id   INT UNSIGNED;
    DECLARE v_waitlist_pos SMALLINT UNSIGNED DEFAULT NULL;
    DECLARE v_book_status  VARCHAR(20);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_status  = 'ERROR';
        SET p_message = 'Transaction failed — booking rolled back.';
    END;

    START TRANSACTION;

    -- ① Retrieve schedule metadata
    SELECT train_id, journey_date
      INTO v_train_id, v_journey_date
      FROM Schedule
     WHERE schedule_id = p_schedule_id
       AND status != 'Cancelled'
    FOR UPDATE;

    IF v_train_id IS NULL THEN
        SET p_status  = 'FAILED';
        SET p_message = 'Schedule not found or cancelled.';
        ROLLBACK; LEAVE proc_body;   -- exit the labelled block
    END IF;

    -- ② Resolve class_id
    SELECT class_id INTO v_class_id FROM Seat_Class WHERE class_code = p_class_code;

    -- ③ Find an available seat (FOR UPDATE prevents double‑booking)
    SELECT s.seat_id INTO v_seat_id
      FROM Seat s
     WHERE s.train_id = v_train_id
       AND s.class_id = v_class_id
       AND s.seat_id NOT IN (
               SELECT b.seat_id
                 FROM Booking b
                WHERE b.schedule_id = p_schedule_id
                  AND b.class_id    = v_class_id
                  AND b.booking_status IN ('Confirmed','Waitlisted')
                  AND b.seat_id IS NOT NULL
           )
     LIMIT 1
     FOR UPDATE;

    -- ④ Determine Confirmed vs Waitlisted
    IF v_seat_id IS NOT NULL THEN
        SET v_book_status = 'Confirmed';
    ELSE
        SET v_book_status = 'Waitlisted';
        -- Compute next waitlist position
        SELECT COALESCE(MAX(waitlist_position), 0) + 1
          INTO v_waitlist_pos
          FROM Booking
         WHERE schedule_id    = p_schedule_id
           AND class_id       = v_class_id
           AND booking_status = 'Waitlisted';
    END IF;

    -- ⑤ Calculate fare
    CALL sp_calculate_fare(v_train_id, p_source_station_id, p_dest_station_id,
                           p_class_code, p_num_passengers, v_fare);

    -- ⑥ Generate unique PNR
    SET p_pnr = generate_pnr();

    -- ⑦ Insert booking
    INSERT INTO Booking (
        pnr, passenger_id, schedule_id, seat_id, class_id,
        journey_date, source_station_id, dest_station_id,
        num_passengers, fare, booking_status, waitlist_position
    ) VALUES (
        p_pnr, p_passenger_id, p_schedule_id, v_seat_id, v_class_id,
        v_journey_date, p_source_station_id, p_dest_station_id,
        p_num_passengers, v_fare, v_book_status, v_waitlist_pos
    );

    SET v_booking_id = LAST_INSERT_ID();

    -- ⑧ Insert pending payment record
    INSERT INTO Payment (booking_id, amount, payment_method, payment_status)
    VALUES (v_booking_id, v_fare, p_payment_method, 'Success');

    COMMIT;

    SET p_status  = v_book_status;
    SET p_message = CONCAT('Booking ', v_book_status, '. PNR: ', p_pnr,
                           '. Fare: INR ', v_fare);
END$$
DELIMITER ;


-- ==============================================================
-- SECTION 7 — STORED PROCEDURE: CANCEL TICKET
-- ==============================================================
DELIMITER $$
CREATE PROCEDURE sp_cancel_ticket(
    IN  p_pnr              CHAR(10),
    IN  p_reason           VARCHAR(255),
    OUT p_refund_amount    DECIMAL(10,2),
    OUT p_message          VARCHAR(200)
)
proc_body: BEGIN
    DECLARE v_booking_id   INT UNSIGNED;
    DECLARE v_fare         DECIMAL(10,2);
    DECLARE v_status       VARCHAR(20);
    DECLARE v_journey_date DATE;
    DECLARE v_days_left    INT;
    DECLARE v_refund_pct   DECIMAL(4,2) DEFAULT 0.00;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_message = 'Cancellation failed — rolled back.';
    END;

    START TRANSACTION;

    SELECT booking_id, fare, booking_status, journey_date
      INTO v_booking_id, v_fare, v_status, v_journey_date
      FROM Booking
     WHERE pnr = p_pnr
    FOR UPDATE;

    IF v_booking_id IS NULL THEN
        SET p_message = 'PNR not found.';
        ROLLBACK; LEAVE proc_body;
    END IF;

    IF v_status = 'Cancelled' THEN
        SET p_message = 'Booking already cancelled.';
        ROLLBACK; LEAVE proc_body;
    END IF;

    -- Refund policy (Railway rules)
    SET v_days_left = DATEDIFF(v_journey_date, CURDATE());
    IF    v_days_left >= 3 THEN SET v_refund_pct = 0.75;
    ELSEIF v_days_left >= 1 THEN SET v_refund_pct = 0.50;
    ELSE                         SET v_refund_pct = 0.00;
    END IF;

    SET p_refund_amount = ROUND(v_fare * v_refund_pct, 2);

    -- Mark booking cancelled & free the seat
    UPDATE Booking
       SET booking_status     = 'Cancelled',
           seat_id            = NULL,
           waitlist_position  = NULL
     WHERE booking_id = v_booking_id;

    -- Log cancellation
    INSERT INTO Cancellation (booking_id, cancellation_reason, refund_amount, refund_status)
    VALUES (v_booking_id, p_reason, p_refund_amount, 'Pending');

    -- Update payment to Refunded
    UPDATE Payment
       SET payment_status = 'Refunded'
     WHERE booking_id = v_booking_id;

    COMMIT;

    SET p_message = CONCAT('Cancelled PNR ', p_pnr,
                           '. Refund: INR ', p_refund_amount,
                           ' (', v_refund_pct * 100, '%).');
END$$
DELIMITER ;


-- ==============================================================
-- SECTION 8 — TRIGGER: AUTO-PROMOTE WAITLIST ON CANCELLATION
-- ==============================================================
DELIMITER $$
CREATE TRIGGER trg_promote_waitlist
AFTER UPDATE ON Booking
FOR EACH ROW
BEGIN
    DECLARE v_next_booking_id  INT UNSIGNED;
    DECLARE v_freed_seat_id    INT UNSIGNED;
    DECLARE v_train_id         INT UNSIGNED;

    -- Fire only when a Confirmed booking becomes Cancelled
    IF OLD.booking_status = 'Confirmed' AND NEW.booking_status = 'Cancelled' THEN

        -- Find a free seat in the same class/schedule
        SELECT sch.train_id INTO v_train_id
          FROM Schedule sch
         WHERE sch.schedule_id = NEW.schedule_id;

        SELECT s.seat_id INTO v_freed_seat_id
          FROM Seat s
         WHERE s.train_id = v_train_id
           AND s.class_id = NEW.class_id
           AND s.seat_id NOT IN (
                   SELECT b2.seat_id
                     FROM Booking b2
                    WHERE b2.schedule_id    = NEW.schedule_id
                      AND b2.class_id       = NEW.class_id
                      AND b2.booking_status IN ('Confirmed','Waitlisted')
                      AND b2.seat_id        IS NOT NULL
               )
         LIMIT 1;

        -- Find first waitlisted passenger for same schedule & class
        SELECT booking_id INTO v_next_booking_id
          FROM Booking
         WHERE schedule_id    = NEW.schedule_id
           AND class_id       = NEW.class_id
           AND booking_status = 'Waitlisted'
         ORDER BY waitlist_position ASC
         LIMIT 1;

        IF v_next_booking_id IS NOT NULL AND v_freed_seat_id IS NOT NULL THEN
            UPDATE Booking
               SET booking_status    = 'Confirmed',
                   seat_id           = v_freed_seat_id,
                   waitlist_position = NULL
             WHERE booking_id = v_next_booking_id;

            -- Re-sequence remaining waitlist positions
            SET @pos := 0;
            UPDATE Booking
               SET waitlist_position = (@pos := @pos + 1)
             WHERE schedule_id    = NEW.schedule_id
               AND class_id       = NEW.class_id
               AND booking_status = 'Waitlisted'
             ORDER BY waitlist_position ASC;
        END IF;

    END IF;
END$$
DELIMITER ;


-- ==============================================================
-- SECTION 9 — VIEWS
-- ==============================================================

-- 9.1  PNR Status (full journey details in one query)
CREATE OR REPLACE VIEW vw_pnr_status AS
SELECT
    b.pnr,
    p.full_name                           AS passenger_name,
    p.email,
    p.phone,
    t.train_number,
    t.train_name,
    src.station_name                      AS from_station,
    dst.station_name                      AS to_station,
    b.journey_date,
    sc.class_name                         AS seat_class,
    COALESCE(CONCAT(s.coach_number, '/', s.seat_number), 'Not Assigned') AS seat_info,
    COALESCE(s.berth_type, '—')           AS berth_type,
    b.num_passengers,
    b.fare,
    b.booking_status,
    b.waitlist_position,
    py.payment_method,
    py.payment_status,
    b.booking_date
FROM  Booking        b
JOIN  Passenger      p   ON p.passenger_id     = b.passenger_id
JOIN  Schedule       sch ON sch.schedule_id    = b.schedule_id
JOIN  Train          t   ON t.train_id         = sch.train_id
JOIN  Station        src ON src.station_id     = b.source_station_id
JOIN  Station        dst ON dst.station_id     = b.dest_station_id
JOIN  Seat_Class     sc  ON sc.class_id        = b.class_id
LEFT JOIN Seat       s   ON s.seat_id          = b.seat_id
LEFT JOIN Payment    py  ON py.booking_id      = b.booking_id;

-- 9.2  Train Availability  (seats booked vs total per schedule & class)
CREATE OR REPLACE VIEW vw_seat_availability AS
SELECT
    t.train_number,
    t.train_name,
    sch.journey_date,
    src.station_name     AS from_station,
    dst.station_name     AS to_station,
    sc.class_code,
    sc.class_name,
    COUNT(s.seat_id)     AS total_seats,
    SUM(CASE WHEN b.booking_status IN ('Confirmed','Waitlisted') THEN 1 ELSE 0 END)
                         AS booked_seats,
    COUNT(s.seat_id) - SUM(CASE WHEN b.booking_status IN ('Confirmed','Waitlisted') THEN 1 ELSE 0 END)
                         AS available_seats
FROM  Schedule  sch
JOIN  Train     t   ON t.train_id         = sch.train_id
JOIN  Station   src ON src.station_id     = sch.source_station_id
JOIN  Station   dst ON dst.station_id     = sch.dest_station_id
JOIN  Seat      s   ON s.train_id         = t.train_id
JOIN  Seat_Class sc ON sc.class_id        = s.class_id
LEFT JOIN Booking b ON b.seat_id          = s.seat_id
                    AND b.schedule_id     = sch.schedule_id
GROUP BY
    t.train_number, t.train_name, sch.journey_date,
    src.station_name, dst.station_name, sc.class_code, sc.class_name;

-- 9.3  Daily Revenue Report
CREATE OR REPLACE VIEW vw_daily_revenue AS
SELECT
    DATE(b.booking_date) AS booking_day,
    t.train_name,
    sc.class_name,
    COUNT(b.booking_id)  AS total_bookings,
    SUM(b.fare)          AS gross_revenue,
    SUM(CASE WHEN b.booking_status = 'Cancelled'
             THEN COALESCE(c.refund_amount, 0) ELSE 0 END) AS total_refunds,
    SUM(b.fare) - SUM(CASE WHEN b.booking_status = 'Cancelled'
                           THEN COALESCE(c.refund_amount, 0) ELSE 0 END) AS net_revenue
FROM  Booking      b
JOIN  Schedule     sch ON sch.schedule_id = b.schedule_id
JOIN  Train        t   ON t.train_id      = sch.train_id
JOIN  Seat_Class   sc  ON sc.class_id     = b.class_id
LEFT JOIN Cancellation c ON c.booking_id  = b.booking_id
GROUP BY DATE(b.booking_date), t.train_name, sc.class_name;

-- 9.4  Route Popularity (most booked source→destination pairs)
CREATE OR REPLACE VIEW vw_route_popularity AS
SELECT
    src.station_name             AS from_station,
    dst.station_name             AS to_station,
    COUNT(b.booking_id)          AS total_bookings,
    SUM(b.num_passengers)        AS total_passengers,
    SUM(b.fare)                  AS total_revenue,
    ROUND(AVG(b.fare), 2)        AS avg_fare
FROM  Booking  b
JOIN  Station  src ON src.station_id = b.source_station_id
JOIN  Station  dst ON dst.station_id = b.dest_station_id
WHERE b.booking_status != 'Cancelled'
GROUP BY src.station_name, dst.station_name
ORDER BY total_bookings DESC;

-- 9.5  Waitlist Summary
CREATE OR REPLACE VIEW vw_waitlist_summary AS
SELECT
    t.train_number,
    t.train_name,
    sch.journey_date,
    sc.class_code,
    sc.class_name,
    COUNT(b.booking_id)       AS waitlisted_passengers,
    MIN(b.waitlist_position)  AS first_in_queue,
    MAX(b.waitlist_position)  AS last_in_queue
FROM  Booking    b
JOIN  Schedule   sch ON sch.schedule_id = b.schedule_id
JOIN  Train      t   ON t.train_id      = sch.train_id
JOIN  Seat_Class sc  ON sc.class_id     = b.class_id
WHERE b.booking_status = 'Waitlisted'
GROUP BY t.train_number, t.train_name, sch.journey_date, sc.class_code, sc.class_name;

-- 9.6  Train Occupancy Percentage
CREATE OR REPLACE VIEW vw_train_occupancy AS
SELECT
    t.train_number,
    t.train_name,
    sch.journey_date,
    COUNT(s.seat_id)                                            AS total_seats,
    SUM(CASE WHEN b.booking_status = 'Confirmed' THEN 1 ELSE 0 END) AS confirmed_seats,
    ROUND(
        SUM(CASE WHEN b.booking_status = 'Confirmed' THEN 1 ELSE 0 END)
        / COUNT(s.seat_id) * 100 , 2
    )                                                           AS occupancy_pct
FROM  Schedule   sch
JOIN  Train      t   ON t.train_id     = sch.train_id
JOIN  Seat       s   ON s.train_id     = t.train_id
LEFT JOIN Booking b  ON b.seat_id      = s.seat_id
                     AND b.schedule_id = sch.schedule_id
GROUP BY t.train_number, t.train_name, sch.journey_date;


-- ==============================================================
-- SECTION 10 — SEARCH PROCEDURE: TRAINS BETWEEN STATIONS
-- ==============================================================
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
        src.station_name      AS from_station,
        dst.station_name      AS to_station,
        r_src.departure_time  AS departs,
        r_dst.arrival_time    AS arrives,
        sch.status            AS train_status,
        sch.delay_minutes
    FROM  Schedule  sch
    JOIN  Train     t    ON t.train_id         = sch.train_id
    JOIN  Route     r_src ON r_src.train_id    = t.train_id
    JOIN  Station   src  ON src.station_id     = r_src.station_id
                         AND src.station_code  = p_source_code
    JOIN  Route     r_dst ON r_dst.train_id    = t.train_id
    JOIN  Station   dst  ON dst.station_id     = r_dst.station_id
                         AND dst.station_code  = p_dest_code
    WHERE sch.journey_date = p_date
      AND r_src.stop_number < r_dst.stop_number   -- ensure valid direction
      AND sch.status != 'Cancelled'
    ORDER BY r_src.departure_time;
END$$
DELIMITER ;


-- ==============================================================
-- SECTION 11 — PROCEDURE: PNR STATUS LOOKUP
-- ==============================================================
DELIMITER $$
CREATE PROCEDURE sp_pnr_status(IN p_pnr CHAR(10))
BEGIN
    SELECT *
      FROM vw_pnr_status
     WHERE pnr = p_pnr;
END$$
DELIMITER ;


-- ==============================================================
-- SECTION 12 — DEMO: END-TO-END BOOKING SCENARIO
-- ==============================================================

-- ── 12a  Search trains from NDLS → SBC on tomorrow's date ──
CALL sp_search_trains('NDLS', 'SBC', CURDATE() + INTERVAL 1 DAY);

-- ── 12b  Book a ticket for Arjun Sharma ──
SET @pnr     = '';
SET @status  = '';
SET @msg     = '';

CALL sp_book_ticket(
    1,           -- passenger_id  (Arjun Sharma)
    1,           -- schedule_id   (Train 12028, tomorrow)
    '3A',        -- class
    1,           -- source  NDLS
    4,           -- dest    SBC
    1,           -- 1 passenger
    'UPI',       -- payment method
    @pnr, @status, @msg
);
SELECT @pnr AS PNR, @status AS Status, @msg AS Message;

-- ── 12c  Book another ticket (Priya Nair) ──
SET @pnr2 = ''; SET @status2 = ''; SET @msg2 = '';
CALL sp_book_ticket(2, 1, '3A', 1, 4, 2, 'CreditCard', @pnr2, @status2, @msg2);
SELECT @pnr2 AS PNR, @status2 AS Status, @msg2 AS Message;

-- ── 12d  Check PNR status ──
CALL sp_pnr_status(@pnr);

-- ── 12e  Cancel Arjun's booking (triggers waitlist promotion) ──
SET @refund = 0; SET @cancel_msg = '';
CALL sp_cancel_ticket(@pnr, 'Change of plans', @refund, @cancel_msg);
SELECT @refund AS Refund_INR, @cancel_msg AS Message;

-- ── 12f  Verify Priya moved from Waitlisted to Confirmed ──
CALL sp_pnr_status(@pnr2);

-- ── 12g  Check seat availability ──
SELECT * FROM vw_seat_availability LIMIT 10;

-- ── 12h  Revenue report ──
SELECT * FROM vw_daily_revenue;

-- ── 12i  Route popularity ──
SELECT * FROM vw_route_popularity;

-- ── 12j  Fare calculation standalone ──
CALL sp_calculate_fare(1, 1, 4, '2A', 1, @fare);
SELECT @fare AS Calculated_Fare_2A_NDLS_SBC;

-- ==============================================================
-- END OF SCRIPT
-- ==============================================================
