-- ============================================================
--   RAILWAY RESERVATION SYSTEM — 06_indexes.sql
--   Performance indexes with justification for each
--   Run AFTER 01_schema.sql
-- ============================================================
USE railway_db;

-- ─────────────────────────────────────────────────────────────
-- INDEX 1: PNR Lookup
-- Most frequent passenger-facing query — must be near-instant.
-- Without this: full table scan across entire Booking table.
-- Type improvement: ALL → const
-- ─────────────────────────────────────────────────────────────
CREATE INDEX idx_booking_pnr
    ON Booking(pnr);

-- ─────────────────────────────────────────────────────────────
-- INDEX 2: Seat Availability Check
-- Composite index covering all three columns used together in
-- the WHERE clause of the seat-search sub-query.
-- Query: WHERE schedule_id=? AND class_id=? AND booking_status IN (...)
-- Type improvement: ALL → ref
-- ─────────────────────────────────────────────────────────────
CREATE INDEX idx_booking_schedule
    ON Booking(schedule_id, class_id, booking_status);

-- ─────────────────────────────────────────────────────────────
-- INDEX 3: Schedule Date Filtering
-- sp_search_trains filters by journey_date first, then train_id.
-- Date is the leading column — most selective for this query.
-- Type improvement: ALL → range
-- ─────────────────────────────────────────────────────────────
CREATE INDEX idx_schedule_date
    ON Schedule(journey_date, train_id);

-- ─────────────────────────────────────────────────────────────
-- INDEX 4: Waitlist Ordering
-- Used in both the trigger (ORDER BY waitlist_position) and the
-- waitlist summary view. Composite keeps all three together.
-- Eliminates: Using filesort → Using index
-- ─────────────────────────────────────────────────────────────
CREATE INDEX idx_booking_waitlist
    ON Booking(schedule_id, class_id, waitlist_position);

-- ─────────────────────────────────────────────────────────────
-- INDEX 5: Station Name Search
-- Allows fast lookup when passengers search by station name
-- instead of code (e.g. autocomplete search boxes).
-- ─────────────────────────────────────────────────────────────
CREATE INDEX idx_station_name
    ON Station(station_name);

-- ─────────────────────────────────────────────────────────────
-- INDEX 6: Route Traversal
-- sp_search_trains joins Route on train_id and checks stop_number.
-- Composite covering both columns avoids a secondary lookup.
-- ─────────────────────────────────────────────────────────────
CREATE INDEX idx_route_train_stop
    ON Route(train_id, stop_number);

-- ─────────────────────────────────────────────────────────────
-- INDEX 7: Passenger Booking History
-- Allows fast retrieval of all bookings for a given passenger.
-- ─────────────────────────────────────────────────────────────
CREATE INDEX idx_booking_passenger
    ON Booking(passenger_id);

-- ─────────────────────────────────────────────────────────────
-- INDEX 8: Refund Queue
-- Allows finance team to quickly fetch all pending refunds
-- without scanning the entire Cancellation table.
-- ─────────────────────────────────────────────────────────────
CREATE INDEX idx_cancel_refund_status
    ON Cancellation(refund_status);


-- ─────────────────────────────────────────────────────────────
-- VERIFY ALL INDEXES (run after creation)
-- ─────────────────────────────────────────────────────────────
SHOW INDEX FROM Booking;
SHOW INDEX FROM Schedule;
SHOW INDEX FROM Station;
SHOW INDEX FROM Route;
SHOW INDEX FROM Cancellation;


-- ─────────────────────────────────────────────────────────────
-- EXPLAIN EXAMPLES — paste these into your report
-- ─────────────────────────────────────────────────────────────

-- PNR lookup — should show type=const after index
EXPLAIN SELECT * FROM Booking WHERE pnr = '1234567890';

-- Seat availability — should show type=ref
EXPLAIN SELECT * FROM Booking
 WHERE schedule_id = 1
   AND class_id = 3
   AND booking_status IN ('Confirmed','Waitlisted');

-- Schedule search by date — should show type=range
EXPLAIN SELECT * FROM Schedule WHERE journey_date = CURDATE() + INTERVAL 1 DAY;
