-- ============================================================
--   RAILWAY RESERVATION SYSTEM — 03_functions_procedures.sql
--   Helper function + 4 stored procedures
--   Run AFTER 01_schema.sql and 02_sample_data.sql
-- ============================================================
USE railway_db;

-- ============================================================
-- FUNCTION: generate_pnr
-- Generates a unique 10-digit alphanumeric PNR number.
-- Loops until a PNR not already in the Booking table is found.
-- ============================================================
DELIMITER $$
CREATE FUNCTION generate_pnr() RETURNS CHAR(10)
    READS SQL DATA
    DETERMINISTIC
BEGIN
    DECLARE pnr_val    CHAR(10);
    DECLARE exists_flag INT DEFAULT 1;
    WHILE exists_flag > 0 DO
        SET pnr_val = CONCAT(
            LPAD(FLOOR(RAND() * 10000), 4, '0'),
            LPAD(FLOOR(RAND() * 10000), 4, '0'),
            LPAD(FLOOR(RAND() * 100),   2, '0')
        );
        SELECT COUNT(*) INTO exists_flag
          FROM Booking WHERE pnr = pnr_val;
    END WHILE;
    RETURN pnr_val;
END$$
DELIMITER ;


-- ============================================================
-- PROCEDURE: sp_calculate_fare
-- Dynamically calculates ticket fare.
-- Formula: (distance_km × fare_per_km + 5% GST) × num_passengers
--
-- IN  p_train_id          — Train for distance lookup
-- IN  p_source_station_id — Journey origin
-- IN  p_dest_station_id   — Journey destination
-- IN  p_class_code        — e.g. '3A', 'SL', '2A'
-- IN  p_num_passengers    — Number of passengers
-- OUT p_fare              — Calculated total fare (INR)
-- ============================================================
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
    DECLARE v_tax_rate DECIMAL(4,2)      DEFAULT 0.05;   -- 5% GST

    SELECT distance_km INTO v_src_km
      FROM Route
     WHERE train_id = p_train_id
       AND station_id = p_source_station_id;

    SELECT distance_km INTO v_dst_km
      FROM Route
     WHERE train_id = p_train_id
       AND station_id = p_dest_station_id;

    SET v_distance = ABS(v_dst_km - v_src_km);

    SELECT fare_per_km INTO v_fpm
      FROM Seat_Class
     WHERE class_code = p_class_code;

    SET v_base = v_distance * v_fpm;
    SET p_fare = ROUND((v_base + (v_base * v_tax_rate)) * p_num_passengers, 2);
END$$
DELIMITER ;


-- ============================================================
-- PROCEDURE: sp_search_trains
-- Find all available trains between two stations on a date.
-- Returns trains ordered by departure time.
--
-- IN  p_source_code — Station code e.g. 'NDLS'
-- IN  p_dest_code   — Station code e.g. 'SBC'
-- IN  p_date        — Journey date
-- ============================================================
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
    JOIN  Train     t     ON t.train_id          = sch.train_id
    JOIN  Route     r_src ON r_src.train_id      = t.train_id
    JOIN  Station   src   ON src.station_id      = r_src.station_id
                          AND src.station_code   = p_source_code
    JOIN  Route     r_dst ON r_dst.train_id      = t.train_id
    JOIN  Station   dst   ON dst.station_id      = r_dst.station_id
                          AND dst.station_code   = p_dest_code
    WHERE sch.journey_date   = p_date
      AND r_src.stop_number  < r_dst.stop_number   -- direction guard
      AND sch.status        != 'Cancelled'
    ORDER BY r_src.departure_time;
END$$
DELIMITER ;


-- ============================================================
-- PROCEDURE: sp_book_ticket   (ACID — full transaction)
-- Books a ticket for a passenger. Assigns a seat if available,
-- otherwise places on waitlist. Generates PNR and payment record.
--
-- Concurrency safety: FOR UPDATE locks prevent double-booking
-- even when multiple sessions run simultaneously.
--
-- IN  p_passenger_id      — Passenger making the booking
-- IN  p_schedule_id       — Which train run to book
-- IN  p_class_code        — Seat class ('1A','2A','3A','SL','CC','2S')
-- IN  p_source_station_id — Boarding station
-- IN  p_dest_station_id   — Alighting station
-- IN  p_num_passengers    — Number of passengers (1–6)
-- IN  p_payment_method    — 'UPI','CreditCard','DebitCard', etc.
-- OUT p_pnr               — Generated PNR number
-- OUT p_status            — 'Confirmed' | 'Waitlisted' | 'FAILED' | 'ERROR'
-- OUT p_message           — Human-readable result message
-- ============================================================
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

    -- Step 1: Verify schedule exists and is not cancelled
    SELECT train_id, journey_date
      INTO v_train_id, v_journey_date
      FROM Schedule
     WHERE schedule_id = p_schedule_id
       AND status != 'Cancelled'
    FOR UPDATE;

    IF v_train_id IS NULL THEN
        SET p_status  = 'FAILED';
        SET p_message = 'Schedule not found or is cancelled.';
        ROLLBACK;
        LEAVE proc_body;
    END IF;

    -- Step 2: Resolve class_id from class_code
    SELECT class_id INTO v_class_id
      FROM Seat_Class
     WHERE class_code = p_class_code;

    -- Step 3: Find an available seat — FOR UPDATE prevents race conditions
    SELECT s.seat_id INTO v_seat_id
      FROM Seat s
     WHERE s.train_id = v_train_id
       AND s.class_id = v_class_id
       AND s.seat_id NOT IN (
               SELECT b.seat_id
                 FROM Booking b
                WHERE b.schedule_id    = p_schedule_id
                  AND b.class_id       = v_class_id
                  AND b.booking_status IN ('Confirmed','Waitlisted')
                  AND b.seat_id IS NOT NULL
           )
     LIMIT 1
    FOR UPDATE;

    -- Step 4: Determine booking status
    IF v_seat_id IS NOT NULL THEN
        SET v_book_status = 'Confirmed';
    ELSE
        SET v_book_status = 'Waitlisted';
        SELECT COALESCE(MAX(waitlist_position), 0) + 1
          INTO v_waitlist_pos
          FROM Booking
         WHERE schedule_id    = p_schedule_id
           AND class_id       = v_class_id
           AND booking_status = 'Waitlisted';
    END IF;

    -- Step 5: Calculate fare dynamically
    CALL sp_calculate_fare(
        v_train_id, p_source_station_id, p_dest_station_id,
        p_class_code, p_num_passengers, v_fare
    );

    -- Step 6: Generate unique PNR
    SET p_pnr = generate_pnr();

    -- Step 7: Insert booking record
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

    -- Step 8: Insert payment record
    INSERT INTO Payment (booking_id, amount, payment_method, payment_status, paid_at)
    VALUES (v_booking_id, v_fare, p_payment_method, 'Success', NOW());

    COMMIT;

    SET p_status  = v_book_status;
    SET p_message = CONCAT(
        'Booking ', v_book_status, '. ',
        'PNR: ', p_pnr, '. ',
        'Fare: INR ', v_fare,
        IF(v_book_status = 'Waitlisted',
           CONCAT('. Waitlist position: ', v_waitlist_pos), '')
    );
END$$
DELIMITER ;


-- ============================================================
-- PROCEDURE: sp_cancel_ticket
-- Cancels a booking by PNR. Applies tiered refund policy,
-- logs the cancellation and marks payment as Refunded.
-- The waitlist trigger fires automatically after this update.
--
-- Refund policy:
--   ≥ 3 days before journey → 75% refund
--   ≥ 1 day before journey  → 50% refund
--   < 1 day before journey  →  0% refund
--
-- IN  p_pnr           — PNR to cancel
-- IN  p_reason        — Reason text (optional)
-- OUT p_refund_amount — Calculated refund in INR
-- OUT p_message       — Result message
-- ============================================================
DELIMITER $$
CREATE PROCEDURE sp_cancel_ticket(
    IN  p_pnr           CHAR(10),
    IN  p_reason        VARCHAR(255),
    OUT p_refund_amount DECIMAL(10,2),
    OUT p_message       VARCHAR(200)
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
        ROLLBACK;
        LEAVE proc_body;
    END IF;

    IF v_status = 'Cancelled' THEN
        SET p_message = 'This booking is already cancelled.';
        ROLLBACK;
        LEAVE proc_body;
    END IF;

    -- Apply refund policy
    SET v_days_left = DATEDIFF(v_journey_date, CURDATE());

    IF    v_days_left >= 3 THEN SET v_refund_pct = 0.75;
    ELSEIF v_days_left >= 1 THEN SET v_refund_pct = 0.50;
    ELSE                         SET v_refund_pct = 0.00;
    END IF;

    SET p_refund_amount = ROUND(v_fare * v_refund_pct, 2);

    -- Cancel booking and free seat
    UPDATE Booking
       SET booking_status    = 'Cancelled',
           seat_id           = NULL,
           waitlist_position = NULL
     WHERE booking_id = v_booking_id;
    -- ↑ This UPDATE fires trg_promote_waitlist automatically

    -- Log cancellation
    INSERT INTO Cancellation (booking_id, cancellation_reason, refund_amount, refund_status)
    VALUES (v_booking_id, p_reason, p_refund_amount, 'Pending');

    -- Mark payment as refunded
    UPDATE Payment
       SET payment_status = 'Refunded'
     WHERE booking_id = v_booking_id;

    COMMIT;

    SET p_message = CONCAT(
        'PNR ', p_pnr, ' cancelled. ',
        'Refund: INR ', p_refund_amount,
        ' (', ROUND(v_refund_pct * 100, 0), '% of INR ', v_fare, ').'
    );
END$$
DELIMITER ;


-- ============================================================
-- PROCEDURE: sp_pnr_status
-- One-call PNR lookup using vw_pnr_status view.
--
-- IN p_pnr — The PNR to query
-- ============================================================
DELIMITER $$
CREATE PROCEDURE sp_pnr_status(IN p_pnr CHAR(10))
BEGIN
    SELECT * FROM vw_pnr_status WHERE pnr = p_pnr;
END$$
DELIMITER ;
