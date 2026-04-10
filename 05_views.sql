-- ============================================================
--   RAILWAY RESERVATION SYSTEM — 05_views.sql
--   Six analytical and operational views
--   Run AFTER 01_schema.sql and 02_sample_data.sql
-- ============================================================
USE railway_db;

-- ============================================================
-- VIEW 1: vw_pnr_status
-- Full journey snapshot for a given PNR.
-- Used by: passengers checking booking status, help desk
-- ============================================================
CREATE OR REPLACE VIEW vw_pnr_status AS
SELECT
    b.pnr,
    p.full_name                                           AS passenger_name,
    p.email,
    p.phone,
    t.train_number,
    t.train_name,
    t.train_type,
    src.station_name                                      AS from_station,
    src.station_code                                      AS from_code,
    dst.station_name                                      AS to_station,
    dst.station_code                                      AS to_code,
    b.journey_date,
    sch.status                                            AS train_status,
    sch.delay_minutes,
    sc.class_code,
    sc.class_name                                         AS seat_class,
    COALESCE(CONCAT(s.coach_number, '/', s.seat_number),
             'Not Assigned')                              AS seat_info,
    COALESCE(s.berth_type, '—')                           AS berth_type,
    b.num_passengers,
    b.fare,
    b.booking_status,
    b.waitlist_position,
    py.payment_method,
    py.payment_status,
    py.transaction_ref,
    b.booking_date
FROM  Booking      b
JOIN  Passenger    p   ON p.passenger_id     = b.passenger_id
JOIN  Schedule     sch ON sch.schedule_id    = b.schedule_id
JOIN  Train        t   ON t.train_id         = sch.train_id
JOIN  Station      src ON src.station_id     = b.source_station_id
JOIN  Station      dst ON dst.station_id     = b.dest_station_id
JOIN  Seat_Class   sc  ON sc.class_id        = b.class_id
LEFT JOIN Seat     s   ON s.seat_id          = b.seat_id
LEFT JOIN Payment  py  ON py.booking_id      = b.booking_id;


-- ============================================================
-- VIEW 2: vw_seat_availability
-- Seats booked vs available per schedule, class and station pair.
-- Used by: booking engine, admin dashboard
-- ============================================================
CREATE OR REPLACE VIEW vw_seat_availability AS
SELECT
    sch.schedule_id,
    t.train_number,
    t.train_name,
    sch.journey_date,
    src.station_name                    AS from_station,
    dst.station_name                    AS to_station,
    sc.class_code,
    sc.class_name,
    COUNT(s.seat_id)                    AS total_seats,
    SUM(CASE
            WHEN b.booking_status IN ('Confirmed','Waitlisted') THEN 1
            ELSE 0
        END)                            AS booked_seats,
    COUNT(s.seat_id) - SUM(CASE
            WHEN b.booking_status IN ('Confirmed','Waitlisted') THEN 1
            ELSE 0
        END)                            AS available_seats,
    SUM(CASE
            WHEN b.booking_status = 'Waitlisted' THEN 1
            ELSE 0
        END)                            AS on_waitlist
FROM  Schedule   sch
JOIN  Train      t   ON t.train_id         = sch.train_id
JOIN  Station    src ON src.station_id     = sch.source_station_id
JOIN  Station    dst ON dst.station_id     = sch.dest_station_id
JOIN  Seat       s   ON s.train_id         = t.train_id
JOIN  Seat_Class sc  ON sc.class_id        = s.class_id
LEFT JOIN Booking b  ON b.seat_id          = s.seat_id
                     AND b.schedule_id     = sch.schedule_id
GROUP BY
    sch.schedule_id, t.train_number, t.train_name,
    sch.journey_date, src.station_name, dst.station_name,
    sc.class_code, sc.class_name;


-- ============================================================
-- VIEW 3: vw_daily_revenue
-- Gross revenue, total refunds and net revenue per day/train/class.
-- Used by: revenue reports, finance team
-- ============================================================
CREATE OR REPLACE VIEW vw_daily_revenue AS
SELECT
    DATE(b.booking_date)                AS booking_day,
    t.train_name,
    sc.class_name,
    COUNT(b.booking_id)                 AS total_bookings,
    SUM(b.fare)                         AS gross_revenue,
    SUM(CASE
            WHEN b.booking_status = 'Cancelled'
            THEN COALESCE(c.refund_amount, 0)
            ELSE 0
        END)                            AS total_refunds,
    SUM(b.fare) - SUM(CASE
            WHEN b.booking_status = 'Cancelled'
            THEN COALESCE(c.refund_amount, 0)
            ELSE 0
        END)                            AS net_revenue
FROM  Booking        b
JOIN  Schedule       sch ON sch.schedule_id = b.schedule_id
JOIN  Train          t   ON t.train_id      = sch.train_id
JOIN  Seat_Class     sc  ON sc.class_id     = b.class_id
LEFT JOIN Cancellation c ON c.booking_id    = b.booking_id
GROUP BY
    DATE(b.booking_date), t.train_name, sc.class_name;


-- ============================================================
-- VIEW 4: vw_route_popularity
-- Most booked source→destination pairs. Useful for planning.
-- Used by: route analytics, marketing
-- ============================================================
CREATE OR REPLACE VIEW vw_route_popularity AS
SELECT
    src.station_name         AS from_station,
    dst.station_name         AS to_station,
    COUNT(b.booking_id)      AS total_bookings,
    SUM(b.num_passengers)    AS total_passengers,
    SUM(b.fare)              AS total_revenue,
    ROUND(AVG(b.fare), 2)   AS avg_fare
FROM  Booking  b
JOIN  Station  src ON src.station_id = b.source_station_id
JOIN  Station  dst ON dst.station_id = b.dest_station_id
WHERE b.booking_status != 'Cancelled'
GROUP BY src.station_name, dst.station_name
ORDER BY total_bookings DESC;


-- ============================================================
-- VIEW 5: vw_waitlist_summary
-- Current waitlist depth per schedule and class.
-- Used by: admin monitoring, customer care
-- ============================================================
CREATE OR REPLACE VIEW vw_waitlist_summary AS
SELECT
    t.train_number,
    t.train_name,
    sch.journey_date,
    sc.class_code,
    sc.class_name,
    COUNT(b.booking_id)        AS waitlisted_count,
    MIN(b.waitlist_position)   AS first_in_queue,
    MAX(b.waitlist_position)   AS last_in_queue
FROM  Booking    b
JOIN  Schedule   sch ON sch.schedule_id = b.schedule_id
JOIN  Train      t   ON t.train_id      = sch.train_id
JOIN  Seat_Class sc  ON sc.class_id     = b.class_id
WHERE b.booking_status = 'Waitlisted'
GROUP BY
    t.train_number, t.train_name,
    sch.journey_date, sc.class_code, sc.class_name;


-- ============================================================
-- VIEW 6: vw_train_occupancy
-- Occupancy percentage per train per schedule.
-- Used by: operational dashboard, capacity planning
-- ============================================================
CREATE OR REPLACE VIEW vw_train_occupancy AS
SELECT
    t.train_number,
    t.train_name,
    sch.journey_date,
    COUNT(s.seat_id)                                              AS total_seats,
    SUM(CASE WHEN b.booking_status = 'Confirmed' THEN 1 ELSE 0 END)
                                                                  AS confirmed_seats,
    SUM(CASE WHEN b.booking_status = 'Waitlisted' THEN 1 ELSE 0 END)
                                                                  AS waitlisted_seats,
    ROUND(
        SUM(CASE WHEN b.booking_status = 'Confirmed' THEN 1 ELSE 0 END)
        / NULLIF(COUNT(s.seat_id), 0) * 100,
    2)                                                            AS occupancy_pct
FROM  Schedule   sch
JOIN  Train      t  ON t.train_id     = sch.train_id
JOIN  Seat       s  ON s.train_id     = t.train_id
LEFT JOIN Booking b ON b.seat_id      = s.seat_id
                    AND b.schedule_id  = sch.schedule_id
GROUP BY
    t.train_number, t.train_name, sch.journey_date;
