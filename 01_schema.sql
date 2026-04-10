-- ============================================================
--   RAILWAY RESERVATION SYSTEM — 01_schema.sql
--   Database creation + all table definitions (DDL)
-- ============================================================

DROP DATABASE IF EXISTS railway_db;
CREATE DATABASE railway_db
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;
USE railway_db;

SET FOREIGN_KEY_CHECKS = 0;
SET SQL_MODE = 'STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,ERROR_FOR_DIVISION_BY_ZERO';

-- ─────────────────────────────────────────────────────────────
-- TABLE 1: STATION
-- ─────────────────────────────────────────────────────────────
CREATE TABLE Station (
    station_id    INT          UNSIGNED NOT NULL AUTO_INCREMENT,
    station_code  VARCHAR(10)  NOT NULL,
    station_name  VARCHAR(100) NOT NULL,
    city          VARCHAR(80)  NOT NULL,
    state         VARCHAR(80)  NOT NULL,
    zone          VARCHAR(50)  NOT NULL,
    PRIMARY KEY (station_id),
    UNIQUE KEY uq_station_code (station_code)
) ENGINE=InnoDB COMMENT='All railway stations';

-- ─────────────────────────────────────────────────────────────
-- TABLE 2: TRAIN
-- ─────────────────────────────────────────────────────────────
CREATE TABLE Train (
    train_id      INT          UNSIGNED NOT NULL AUTO_INCREMENT,
    train_number  VARCHAR(10)  NOT NULL,
    train_name    VARCHAR(120) NOT NULL,
    train_type    ENUM('Express','Superfast','Rajdhani','Shatabdi',
                       'Duronto','Passenger','Local') NOT NULL,
    total_seats   SMALLINT     UNSIGNED NOT NULL,
    PRIMARY KEY (train_id),
    UNIQUE KEY uq_train_number (train_number)
) ENGINE=InnoDB COMMENT='Train master data';

-- ─────────────────────────────────────────────────────────────
-- TABLE 3: ROUTE  (ordered stops per train)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE Route (
    route_id       INT      UNSIGNED NOT NULL AUTO_INCREMENT,
    train_id       INT      UNSIGNED NOT NULL,
    station_id     INT      UNSIGNED NOT NULL,
    stop_number    TINYINT  UNSIGNED NOT NULL,
    arrival_time   TIME     NULL,
    departure_time TIME     NULL,
    distance_km    SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (route_id),
    UNIQUE KEY uq_train_stop    (train_id, stop_number),
    UNIQUE KEY uq_train_station (train_id, station_id),
    CONSTRAINT fk_route_train   FOREIGN KEY (train_id)   REFERENCES Train(train_id),
    CONSTRAINT fk_route_station FOREIGN KEY (station_id) REFERENCES Station(station_id)
) ENGINE=InnoDB COMMENT='Ordered station stops for each train';

-- ─────────────────────────────────────────────────────────────
-- TABLE 4: SCHEDULE  (one row per train per running date)
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
    CONSTRAINT fk_sched_train FOREIGN KEY (train_id)          REFERENCES Train(train_id),
    CONSTRAINT fk_sched_src   FOREIGN KEY (source_station_id) REFERENCES Station(station_id),
    CONSTRAINT fk_sched_dest  FOREIGN KEY (dest_station_id)   REFERENCES Station(station_id)
) ENGINE=InnoDB COMMENT='A specific running instance of a train on a date';

-- ─────────────────────────────────────────────────────────────
-- TABLE 5: SEAT_CLASS  (fare lookup per class)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE Seat_Class (
    class_id     TINYINT      UNSIGNED NOT NULL AUTO_INCREMENT,
    class_code   VARCHAR(5)   NOT NULL,
    class_name   VARCHAR(50)  NOT NULL,
    fare_per_km  DECIMAL(5,2) NOT NULL,
    PRIMARY KEY (class_id),
    UNIQUE KEY uq_class_code (class_code)
) ENGINE=InnoDB COMMENT='Seat class definitions with base fare rates';

-- ─────────────────────────────────────────────────────────────
-- TABLE 6: SEAT  (physical seats on a train per class)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE Seat (
    seat_id      INT         UNSIGNED NOT NULL AUTO_INCREMENT,
    train_id     INT         UNSIGNED NOT NULL,
    class_id     TINYINT     UNSIGNED NOT NULL,
    coach_number VARCHAR(5)  NOT NULL,
    seat_number  VARCHAR(5)  NOT NULL,
    berth_type   ENUM('Lower','Middle','Upper','Side Lower','Side Upper',
                      'Window','Aisle','None') NOT NULL DEFAULT 'None',
    PRIMARY KEY (seat_id),
    UNIQUE KEY uq_seat (train_id, class_id, coach_number, seat_number),
    CONSTRAINT fk_seat_train FOREIGN KEY (train_id) REFERENCES Train(train_id),
    CONSTRAINT fk_seat_class FOREIGN KEY (class_id) REFERENCES Seat_Class(class_id)
) ENGINE=InnoDB COMMENT='Physical seat inventory per train and class';

-- ─────────────────────────────────────────────────────────────
-- TABLE 7: PASSENGER
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
    UNIQUE KEY uq_email  (email),
    UNIQUE KEY uq_id_doc (id_type, id_number)
) ENGINE=InnoDB COMMENT='Registered passengers';

-- ─────────────────────────────────────────────────────────────
-- TABLE 8: BOOKING  (central associative entity)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE Booking (
    booking_id        INT           UNSIGNED NOT NULL AUTO_INCREMENT,
    pnr               CHAR(10)      NOT NULL,
    passenger_id      INT           UNSIGNED NOT NULL,
    schedule_id       INT           UNSIGNED NOT NULL,
    seat_id           INT           UNSIGNED NULL,
    class_id          TINYINT       UNSIGNED NOT NULL,
    booking_date      TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    journey_date      DATE          NOT NULL,
    source_station_id INT           UNSIGNED NOT NULL,
    dest_station_id   INT           UNSIGNED NOT NULL,
    num_passengers    TINYINT       UNSIGNED NOT NULL DEFAULT 1,
    fare              DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    booking_status    ENUM('Confirmed','Waitlisted','Cancelled','Completed')
                      NOT NULL DEFAULT 'Confirmed',
    waitlist_position SMALLINT      UNSIGNED NULL,
    PRIMARY KEY (booking_id),
    UNIQUE KEY uq_pnr (pnr),
    CONSTRAINT fk_book_passenger FOREIGN KEY (passenger_id)      REFERENCES Passenger(passenger_id),
    CONSTRAINT fk_book_schedule  FOREIGN KEY (schedule_id)       REFERENCES Schedule(schedule_id),
    CONSTRAINT fk_book_seat      FOREIGN KEY (seat_id)           REFERENCES Seat(seat_id),
    CONSTRAINT fk_book_class     FOREIGN KEY (class_id)          REFERENCES Seat_Class(class_id),
    CONSTRAINT fk_book_src       FOREIGN KEY (source_station_id) REFERENCES Station(station_id),
    CONSTRAINT fk_book_dest      FOREIGN KEY (dest_station_id)   REFERENCES Station(station_id)
) ENGINE=InnoDB COMMENT='Ticket bookings — links passenger, schedule and seat';

-- ─────────────────────────────────────────────────────────────
-- TABLE 9: PAYMENT
-- ─────────────────────────────────────────────────────────────
CREATE TABLE Payment (
    payment_id      INT           UNSIGNED NOT NULL AUTO_INCREMENT,
    booking_id      INT           UNSIGNED NOT NULL,
    amount          DECIMAL(10,2) NOT NULL,
    payment_method  ENUM('UPI','CreditCard','DebitCard','NetBanking','Wallet','Cash') NOT NULL,
    transaction_ref VARCHAR(60)   NULL,
    payment_status  ENUM('Pending','Success','Failed','Refunded') NOT NULL DEFAULT 'Pending',
    paid_at         TIMESTAMP     NULL,
    PRIMARY KEY (payment_id),
    CONSTRAINT fk_pay_booking FOREIGN KEY (booking_id) REFERENCES Booking(booking_id)
) ENGINE=InnoDB COMMENT='Payment records linked to each booking';

-- ─────────────────────────────────────────────────────────────
-- TABLE 10: CANCELLATION  (audit log — never delete bookings)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE Cancellation (
    cancellation_id     INT           UNSIGNED NOT NULL AUTO_INCREMENT,
    booking_id          INT           UNSIGNED NOT NULL,
    cancelled_at        TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    cancellation_reason VARCHAR(255)  NULL,
    refund_amount       DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    refund_status       ENUM('Pending','Processed','Rejected') NOT NULL DEFAULT 'Pending',
    PRIMARY KEY (cancellation_id),
    UNIQUE KEY uq_cancel_booking (booking_id),
    CONSTRAINT fk_cancel_booking FOREIGN KEY (booking_id) REFERENCES Booking(booking_id)
) ENGINE=InnoDB COMMENT='Cancellation log with refund tracking';

SET FOREIGN_KEY_CHECKS = 1;
