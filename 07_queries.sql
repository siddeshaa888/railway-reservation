-- ============================================================
--   RAILWAY RESERVATION SYSTEM — 07_queries.sql
--   Operational queries, reports and demo scenario
--   Run AFTER all previous files
-- ============================================================
USE railway_db;

-- ============================================================
-- SECTION A — TRAIN SEARCH & AVAILABILITY
-- ============================================================

-- A1: Search trains between two stations on a specific date
CALL sp_search_trains('NDLS', 'SBC', CURDATE() + INTERVAL 1 DAY);

-- A2: Seat availability summary for all schedules
SELECT * FROM vw_seat_availability;

-- A3: Seat availability for a specific schedule and class
SELECT
    class_name,
    total_seats,
    booked_seats,
    available_seats,
    on_waitlist
FROM vw_seat_availability
WHERE schedule_id = 1
ORDER BY class_code;

-- A4: All upcoming scheduled trains (next 7 days)
SELECT
    t.train_number,
    t.train_name,
    sch.journey_date,
    src.station_name AS from_station,
    dst.station_name AS to_station,
    sch.status,
    sch.delay_minutes
FROM Schedule sch
JOIN Train   t   ON t.train_id         = sch.train_id
JOIN Station src ON src.station_id     = sch.source_station_id
JOIN Station dst ON dst.station_id     = sch.dest_station_id
WHERE sch.journey_date BETWEEN CURDATE() AND CURDATE() + INTERVAL 7 DAY
ORDER BY sch.journey_date, t.train_number;


-- ============================================================
-- SECTION B — BOOKING OPERATIONS
-- ============================================================

-- B1: Book a ticket (Arjun Sharma, NDLS → SBC, schedule 1, 3A class)
SET @pnr = ''; SET @status = ''; SET @msg = '';
CALL sp_book_ticket(1, 1, '3A', 1, 4, 1, 'UPI', @pnr, @status, @msg);
SELECT @pnr AS PNR, @status AS Status, @msg AS Message;

-- B2: Book another ticket (Priya Nair — may get waitlisted)
SET @pnr2 = ''; SET @status2 = ''; SET @msg2 = '';
CALL sp_book_ticket(2, 1, '3A', 1, 4, 2, 'CreditCard', @pnr2, @status2, @msg2);
SELECT @pnr2 AS PNR, @status2 AS Status, @msg2 AS Message;

-- B3: Book a 2A ticket (Rahul Mehta)
SET @pnr3 = ''; SET @status3 = ''; SET @msg3 = '';
CALL sp_book_ticket(3, 1, '2A', 1, 4, 1, 'NetBanking', @pnr3, @status3, @msg3);
SELECT @pnr3 AS PNR, @status3 AS Status, @msg3 AS Message;

-- B4: Check fare without booking (standalone fare calculation)
CALL sp_calculate_fare(1, 1, 4, '2A', 1, @fare);
SELECT @fare AS Fare_2A_NDLS_SBC_INR;

CALL sp_calculate_fare(1, 1, 4, '3A', 1, @fare2);
SELECT @fare2 AS Fare_3A_NDLS_SBC_INR;

CALL sp_calculate_fare(1, 1, 4, 'SL', 1, @fare3);
SELECT @fare3 AS Fare_SL_NDLS_SBC_INR;


-- ============================================================
-- SECTION C — PNR STATUS TRACKING
-- ============================================================

-- C1: Check PNR status via procedure
CALL sp_pnr_status(@pnr);

-- C2: Check PNR status directly via view
SELECT
    pnr,
    passenger_name,
    train_number,
    train_name,
    from_station,
    to_station,
    journey_date,
    seat_class,
    seat_info,
    berth_type,
    fare,
    booking_status,
    waitlist_position,
    payment_method,
    payment_status
FROM vw_pnr_status
WHERE pnr = @pnr;

-- C3: All bookings for a specific passenger
SELECT
    b.pnr,
    t.train_name,
    src.station_name AS from_station,
    dst.station_name AS to_station,
    b.journey_date,
    sc.class_code,
    b.fare,
    b.booking_status
FROM Booking b
JOIN Schedule    sch ON sch.schedule_id    = b.schedule_id
JOIN Train       t   ON t.train_id         = sch.train_id
JOIN Station     src ON src.station_id     = b.source_station_id
JOIN Station     dst ON dst.station_id     = b.dest_station_id
JOIN Seat_Class  sc  ON sc.class_id        = b.class_id
WHERE b.passenger_id = 1
ORDER BY b.booking_date DESC;


-- ============================================================
-- SECTION D — CANCELLATION & REFUNDS
-- ============================================================

-- D1: Cancel a booking (triggers waitlist promotion automatically)
SET @refund = 0; SET @cancel_msg = '';
CALL sp_cancel_ticket(@pnr, 'Change of plans', @refund, @cancel_msg);
SELECT @refund AS Refund_INR, @cancel_msg AS Message;

-- D2: Verify waitlist passenger was auto-promoted
CALL sp_pnr_status(@pnr2);

-- D3: View all cancellations with refund status
SELECT
    c.cancellation_id,
    b.pnr,
    p.full_name,
    c.cancelled_at,
    c.cancellation_reason,
    c.refund_amount,
    c.refund_status
FROM Cancellation c
JOIN Booking   b ON b.booking_id   = c.booking_id
JOIN Passenger p ON p.passenger_id = b.passenger_id
ORDER BY c.cancelled_at DESC;

-- D4: All pending refunds (for finance processing)
SELECT
    c.cancellation_id,
    b.pnr,
    p.full_name,
    p.email,
    c.refund_amount,
    c.cancelled_at
FROM Cancellation c
JOIN Booking   b ON b.booking_id   = c.booking_id
JOIN Passenger p ON p.passenger_id = b.passenger_id
WHERE c.refund_status = 'Pending'
ORDER BY c.cancelled_at ASC;


-- ============================================================
-- SECTION E — WAITLIST MANAGEMENT
-- ============================================================

-- E1: View full waitlist for a schedule and class
SELECT
    b.waitlist_position,
    p.full_name,
    p.phone,
    sc.class_name,
    b.pnr,
    b.fare,
    b.booking_date
FROM Booking b
JOIN Passenger  p  ON p.passenger_id = b.passenger_id
JOIN Seat_Class sc ON sc.class_id    = b.class_id
WHERE b.schedule_id    = 1
  AND b.booking_status = 'Waitlisted'
ORDER BY b.waitlist_position ASC;

-- E2: Waitlist summary across all schedules
SELECT * FROM vw_waitlist_summary;

-- E3: Bookings approaching confirmation (waitlist position ≤ 3)
SELECT
    b.pnr,
    p.full_name,
    p.email,
    t.train_name,
    b.journey_date,
    sc.class_name,
    b.waitlist_position
FROM Booking b
JOIN Passenger  p   ON p.passenger_id  = b.passenger_id
JOIN Schedule   sch ON sch.schedule_id = b.schedule_id
JOIN Train      t   ON t.train_id      = sch.train_id
JOIN Seat_Class sc  ON sc.class_id     = b.class_id
WHERE b.booking_status    = 'Waitlisted'
  AND b.waitlist_position <= 3
ORDER BY b.waitlist_position;


-- ============================================================
-- SECTION F — REVENUE & ANALYTICS REPORTS
-- ============================================================

-- F1: Daily revenue report
SELECT * FROM vw_daily_revenue ORDER BY booking_day DESC;

-- F2: Revenue by train (all time)
SELECT
    t.train_name,
    t.train_type,
    COUNT(b.booking_id)                 AS total_bookings,
    SUM(b.num_passengers)               AS total_passengers,
    SUM(b.fare)                         AS gross_revenue,
    ROUND(AVG(b.fare), 2)              AS avg_fare
FROM Booking  b
JOIN Schedule sch ON sch.schedule_id = b.schedule_id
JOIN Train    t   ON t.train_id      = sch.train_id
WHERE b.booking_status != 'Cancelled'
GROUP BY t.train_name, t.train_type
ORDER BY gross_revenue DESC;

-- F3: Revenue by class
SELECT
    sc.class_code,
    sc.class_name,
    COUNT(b.booking_id)   AS bookings,
    SUM(b.fare)           AS total_revenue,
    ROUND(AVG(b.fare),2)  AS avg_fare
FROM Booking   b
JOIN Seat_Class sc ON sc.class_id = b.class_id
WHERE b.booking_status != 'Cancelled'
GROUP BY sc.class_code, sc.class_name
ORDER BY total_revenue DESC;

-- F4: Most popular routes
SELECT * FROM vw_route_popularity LIMIT 10;

-- F5: Top 5 busiest routes by passenger count
SELECT
    src.station_name AS from_station,
    dst.station_name AS to_station,
    COUNT(b.booking_id) AS bookings,
    SUM(b.num_passengers) AS passengers
FROM Booking b
JOIN Station src ON src.station_id = b.source_station_id
JOIN Station dst ON dst.station_id = b.dest_station_id
WHERE b.booking_status != 'Cancelled'
GROUP BY src.station_name, dst.station_name
ORDER BY passengers DESC
LIMIT 5;

-- F6: Train occupancy percentages
SELECT * FROM vw_train_occupancy ORDER BY journey_date, occupancy_pct DESC;

-- F7: Monthly booking trend
SELECT
    DATE_FORMAT(b.booking_date, '%Y-%m') AS month,
    COUNT(b.booking_id)                  AS bookings,
    SUM(b.fare)                          AS revenue
FROM Booking b
WHERE b.booking_status != 'Cancelled'
GROUP BY DATE_FORMAT(b.booking_date, '%Y-%m')
ORDER BY month DESC;


-- ============================================================
-- SECTION G — ADMIN & OPERATIONS QUERIES
-- ============================================================

-- G1: Delayed or cancelled trains today
SELECT
    t.train_number,
    t.train_name,
    sch.status,
    sch.delay_minutes,
    src.station_name AS from_station,
    dst.station_name AS to_station
FROM Schedule sch
JOIN Train   t   ON t.train_id         = sch.train_id
JOIN Station src ON src.station_id     = sch.source_station_id
JOIN Station dst ON dst.station_id     = sch.dest_station_id
WHERE sch.journey_date = CURDATE()
  AND sch.status IN ('Delayed','Cancelled');

-- G2: Passengers travelling tomorrow (manifest)
SELECT
    t.train_number,
    t.train_name,
    src.station_name AS from_station,
    dst.station_name AS to_station,
    p.full_name,
    p.phone,
    sc.class_code,
    s.coach_number,
    s.seat_number,
    s.berth_type,
    b.pnr,
    b.booking_status
FROM Booking b
JOIN Schedule   sch ON sch.schedule_id  = b.schedule_id
JOIN Train      t   ON t.train_id       = sch.train_id
JOIN Station    src ON src.station_id   = b.source_station_id
JOIN Station    dst ON dst.station_id   = b.dest_station_id
JOIN Passenger  p   ON p.passenger_id  = b.passenger_id
JOIN Seat_Class sc  ON sc.class_id     = b.class_id
LEFT JOIN Seat  s   ON s.seat_id       = b.seat_id
WHERE sch.journey_date = CURDATE() + INTERVAL 1 DAY
  AND b.booking_status = 'Confirmed'
ORDER BY t.train_number, sc.class_code, s.coach_number, s.seat_number;

-- G3: Fully booked trains (0 available seats in any class)
SELECT
    train_number,
    train_name,
    journey_date,
    SUM(available_seats) AS total_available
FROM vw_seat_availability
GROUP BY train_number, train_name, journey_date
HAVING total_available = 0;

-- G4: Passengers with multiple upcoming trips
SELECT
    p.full_name,
    p.email,
    COUNT(b.booking_id) AS upcoming_trips
FROM Booking b
JOIN Passenger p ON p.passenger_id = b.passenger_id
WHERE b.journey_date   >= CURDATE()
  AND b.booking_status  = 'Confirmed'
GROUP BY p.passenger_id, p.full_name, p.email
HAVING upcoming_trips > 1
ORDER BY upcoming_trips DESC;
