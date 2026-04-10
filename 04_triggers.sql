-- ============================================================
--   RAILWAY RESERVATION SYSTEM — 04_triggers.sql
--   Database triggers for automatic business logic
--   Run AFTER 01_schema.sql
-- ============================================================
USE railway_db;

-- ============================================================
-- TRIGGER: trg_promote_waitlist
--
-- PURPOSE:
--   Automatically promotes the first waitlisted passenger to
--   'Confirmed' whenever a Confirmed booking is cancelled.
--   Also re-sequences remaining waitlist positions.
--
-- FIRES: AFTER UPDATE ON Booking
--        Only when booking_status changes Confirmed → Cancelled
--
-- WHY A TRIGGER (not application code)?
--   • Fires at DB level — guaranteed regardless of which app
--     performs the cancellation
--   • Executes within the same transaction — atomic with the cancel
--   • Cannot be accidentally bypassed or forgotten
-- ============================================================
DELIMITER $$
CREATE TRIGGER trg_promote_waitlist
AFTER UPDATE ON Booking
FOR EACH ROW
BEGIN
    DECLARE v_next_booking_id INT UNSIGNED;
    DECLARE v_freed_seat_id   INT UNSIGNED;
    DECLARE v_train_id        INT UNSIGNED;

    -- Only fire when a Confirmed booking becomes Cancelled
    IF OLD.booking_status = 'Confirmed' AND NEW.booking_status = 'Cancelled' THEN

        -- Identify the train for this schedule
        SELECT train_id INTO v_train_id
          FROM Schedule
         WHERE schedule_id = NEW.schedule_id;

        -- Find an unoccupied seat in the same class on this schedule
        SELECT s.seat_id INTO v_freed_seat_id
          FROM Seat s
         WHERE s.train_id = v_train_id
           AND s.class_id = NEW.class_id
           AND s.seat_id NOT IN (
                   SELECT b.seat_id
                     FROM Booking b
                    WHERE b.schedule_id    = NEW.schedule_id
                      AND b.class_id       = NEW.class_id
                      AND b.booking_status IN ('Confirmed','Waitlisted')
                      AND b.seat_id IS NOT NULL
               )
         LIMIT 1;

        -- Find the first waitlisted passenger (lowest waitlist_position)
        SELECT booking_id INTO v_next_booking_id
          FROM Booking
         WHERE schedule_id    = NEW.schedule_id
           AND class_id       = NEW.class_id
           AND booking_status = 'Waitlisted'
         ORDER BY waitlist_position ASC
         LIMIT 1;

        -- Promote if both a free seat and a waiting passenger exist
        IF v_next_booking_id IS NOT NULL AND v_freed_seat_id IS NOT NULL THEN

            -- Confirm the first waitlisted passenger
            UPDATE Booking
               SET booking_status    = 'Confirmed',
                   seat_id           = v_freed_seat_id,
                   waitlist_position = NULL
             WHERE booking_id = v_next_booking_id;

            -- Re-sequence remaining waitlist to close the gap
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


-- ============================================================
-- TRIGGER: trg_set_booking_date
--
-- PURPOSE:
--   Ensures journey_date on Booking matches the Schedule's
--   journey_date — prevents data inconsistency if the
--   application passes a wrong date.
-- ============================================================
DELIMITER $$
CREATE TRIGGER trg_set_booking_date
BEFORE INSERT ON Booking
FOR EACH ROW
BEGIN
    DECLARE v_jdate DATE;
    SELECT journey_date INTO v_jdate
      FROM Schedule
     WHERE schedule_id = NEW.schedule_id;
    SET NEW.journey_date = v_jdate;
END$$
DELIMITER ;


-- ============================================================
-- TRIGGER: trg_prevent_past_booking
--
-- PURPOSE:
--   Rejects any new booking whose journey date has already passed.
-- ============================================================
DELIMITER $$
CREATE TRIGGER trg_prevent_past_booking
BEFORE INSERT ON Booking
FOR EACH ROW
BEGIN
    IF NEW.journey_date < CURDATE() THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Cannot book a ticket for a past journey date.';
    END IF;
END$$
DELIMITER ;


-- ============================================================
-- TRIGGER: trg_log_refund_processed
--
-- PURPOSE:
--   When a Cancellation refund_status is updated to 'Processed',
--   automatically update the linked Payment record to 'Refunded'
--   (safety net in case direct payment update is missed).
-- ============================================================
DELIMITER $$
CREATE TRIGGER trg_log_refund_processed
AFTER UPDATE ON Cancellation
FOR EACH ROW
BEGIN
    IF OLD.refund_status != 'Processed' AND NEW.refund_status = 'Processed' THEN
        UPDATE Payment
           SET payment_status = 'Refunded'
         WHERE booking_id = NEW.booking_id
           AND payment_status != 'Refunded';
    END IF;
END$$
DELIMITER ;
