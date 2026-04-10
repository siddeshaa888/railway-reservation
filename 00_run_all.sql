-- ============================================================
--   RAILWAY RESERVATION SYSTEM — 00_run_all.sql
--   Master script: runs all files in the correct order.
--
--   Usage from terminal:
--       mysql -u root -p < 00_run_all.sql
--
--   Or run each file individually in this order:
--       01_schema.sql
--       02_sample_data.sql
--       03_functions_procedures.sql
--       04_triggers.sql
--       05_views.sql
--       06_indexes.sql
--       07_queries.sql   (optional — demo queries)
-- ============================================================

SOURCE //wsl.localhost/Ubuntu/home/nmit/DBMS/01_schema.sql;
SOURCE //wsl.localhost/Ubuntu/home/nmit/DBMS/02_sample_data.sql;
SOURCE //wsl.localhost/Ubuntu/home/nmit/DBMS/03_functions_procedures.sql;
SOURCE //wsl.localhost/Ubuntu/home/nmit/DBMS/04_triggers.sql;
SOURCE //wsl.localhost/Ubuntu/home/nmit/DBMS/05_views.sql;
SOURCE //wsl.localhost/Ubuntu/home/nmit/DBMS/06_indexes.sql;
-- ── Confirm everything loaded ──────────────────────────────
USE railway_db;

SELECT '== TABLES ==' AS '';
SHOW TABLES;

SELECT '== PROCEDURES ==' AS '';
SHOW PROCEDURE STATUS WHERE Db = 'railway_db';

SELECT '== FUNCTIONS ==' AS '';
SHOW FUNCTION STATUS WHERE Db = 'railway_db';

SELECT '== TRIGGERS ==' AS '';
SHOW TRIGGERS FROM railway_db;

SELECT '== VIEWS ==' AS '';
SHOW FULL TABLES WHERE Table_type = 'VIEW';

SELECT '== INDEXES ON Booking ==' AS '';
SHOW INDEX FROM Booking;

SELECT '== SAMPLE DATA COUNTS ==' AS '';
SELECT 'Station'     AS entity, COUNT(*) AS rows FROM Station
UNION ALL
SELECT 'Train',        COUNT(*) FROM Train
UNION ALL
SELECT 'Route',        COUNT(*) FROM Route
UNION ALL
SELECT 'Schedule',     COUNT(*) FROM Schedule
UNION ALL
SELECT 'Seat_Class',   COUNT(*) FROM Seat_Class
UNION ALL
SELECT 'Seat',         COUNT(*) FROM Seat
UNION ALL
SELECT 'Passenger',    COUNT(*) FROM Passenger
UNION ALL
SELECT 'Booking',      COUNT(*) FROM Booking
UNION ALL
SELECT 'Payment',      COUNT(*) FROM Payment
UNION ALL
SELECT 'Cancellation', COUNT(*) FROM Cancellation;

SELECT 'Setup complete. Run 07_queries.sql for demo queries.' AS Status;
