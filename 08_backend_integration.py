"""
================================================================
  RAILWAY RESERVATION SYSTEM — 08_backend_integration.py
  Python backend using mysql-connector-python
  
  Install dependency:
      pip install mysql-connector-python
  
  Usage:
      python 08_backend_integration.py
================================================================
"""

import mysql.connector
from mysql.connector import Error
from datetime import date, timedelta
from typing import Optional


# ─────────────────────────────────────────────────────────────
# DATABASE CONNECTION
# ─────────────────────────────────────────────────────────────
DB_CONFIG = {
    "host":     "localhost",
    "user":     "root",
    "password":     "nmit1234",
    "database": "railway_db",
    "charset":  "utf8mb4",
}


def get_connection():
    """Return a new database connection."""
    return mysql.connector.connect(**DB_CONFIG)


# ─────────────────────────────────────────────────────────────
# TRAIN SEARCH
# ─────────────────────────────────────────────────────────────
def search_trains(source_code: str, dest_code: str, journey_date: date) -> list[dict]:
    """
    Search for available trains between two stations on a date.

    Args:
        source_code  : Station code e.g. 'NDLS'
        dest_code    : Station code e.g. 'SBC'
        journey_date : Date object

    Returns:
        List of train dicts with schedule_id, timings, status.
    """
    conn = get_connection()
    cursor = conn.cursor(dictionary=True)
    try:
        cursor.callproc("sp_search_trains", [source_code, dest_code, journey_date])
        for result in cursor.stored_results():
            return result.fetchall()
        return []
    finally:
        cursor.close()
        conn.close()


# ─────────────────────────────────────────────────────────────
# SEAT AVAILABILITY
# ─────────────────────────────────────────────────────────────
def get_seat_availability(schedule_id: int) -> list[dict]:
    """
    Return seat availability breakdown by class for a schedule.

    Args:
        schedule_id : ID from the Schedule table

    Returns:
        List of dicts with class_name, total_seats, available_seats, on_waitlist.
    """
    conn = get_connection()
    cursor = conn.cursor(dictionary=True)
    try:
        cursor.execute(
            """
            SELECT class_code, class_name, total_seats,
                   booked_seats, available_seats, on_waitlist
              FROM vw_seat_availability
             WHERE schedule_id = %s
             ORDER BY class_code
            """,
            (schedule_id,),
        )
        return cursor.fetchall()
    finally:
        cursor.close()
        conn.close()


# ─────────────────────────────────────────────────────────────
# FARE CALCULATION
# ─────────────────────────────────────────────────────────────
def calculate_fare(
    train_id: int,
    source_station_id: int,
    dest_station_id: int,
    class_code: str,
    num_passengers: int = 1,
) -> float:
    """
    Calculate ticket fare without creating a booking.

    Returns:
        Fare in INR (float), includes 5% GST.
    """
    conn = get_connection()
    cursor = conn.cursor()
    try:
        args = (train_id, source_station_id, dest_station_id,
                class_code, num_passengers, 0.0)
        result = cursor.callproc("sp_calculate_fare", args)
        return float(result[5])   # OUT parameter index
    finally:
        cursor.close()
        conn.close()


# ─────────────────────────────────────────────────────────────
# BOOK TICKET
# ─────────────────────────────────────────────────────────────
def book_ticket(
    passenger_id: int,
    schedule_id: int,
    class_code: str,
    source_station_id: int,
    dest_station_id: int,
    num_passengers: int,
    payment_method: str,
) -> dict:
    """
    Book a ticket. Returns Confirmed or Waitlisted status.

    Args:
        passenger_id      : From Passenger table
        schedule_id       : From Schedule table
        class_code        : '1A','2A','3A','SL','CC','2S'
        source_station_id : Boarding station
        dest_station_id   : Alighting station
        num_passengers    : 1–6
        payment_method    : 'UPI','CreditCard','DebitCard','NetBanking','Wallet','Cash'

    Returns:
        dict with keys: pnr, status, message
    
    Raises:
        RuntimeError on database error.
    """
    conn = get_connection()
    cursor = conn.cursor()
    try:
        args = (
            passenger_id, schedule_id, class_code,
            source_station_id, dest_station_id,
            num_passengers, payment_method,
            "",   # OUT: pnr
            "",   # OUT: status
            "",   # OUT: message
        )
        result = cursor.callproc("sp_book_ticket", args)
        conn.commit()
        return {
            "pnr":     result[7],
            "status":  result[8],
            "message": result[9],
        }
    except Error as e:
        conn.rollback()
        raise RuntimeError(f"Booking failed: {e}") from e
    finally:
        cursor.close()
        conn.close()


# ─────────────────────────────────────────────────────────────
# PNR STATUS
# ─────────────────────────────────────────────────────────────
def get_pnr_status(pnr: str) -> Optional[dict]:
    """
    Fetch full journey details for a PNR.

    Returns:
        dict with passenger, train, seat, payment info — or None if not found.
    """
    conn = get_connection()
    cursor = conn.cursor(dictionary=True)
    try:
        cursor.execute(
            "SELECT * FROM vw_pnr_status WHERE pnr = %s",
            (pnr,),
        )
        return cursor.fetchone()
    finally:
        cursor.close()
        conn.close()


# ─────────────────────────────────────────────────────────────
# CANCEL TICKET
# ─────────────────────────────────────────────────────────────
def cancel_ticket(pnr: str, reason: str = "") -> dict:
    """
    Cancel a booking by PNR. Triggers automatic waitlist promotion.

    Returns:
        dict with refund_amount (INR) and message.

    Raises:
        RuntimeError on database error.
    """
    conn = get_connection()
    cursor = conn.cursor()
    try:
        args = (pnr, reason, 0.0, "")   # OUT: refund_amount, message
        result = cursor.callproc("sp_cancel_ticket", args)
        conn.commit()
        return {
            "refund_amount": float(result[2]),
            "message":       result[3],
        }
    except Error as e:
        conn.rollback()
        raise RuntimeError(f"Cancellation failed: {e}") from e
    finally:
        cursor.close()
        conn.close()


# ─────────────────────────────────────────────────────────────
# PASSENGER MANAGEMENT
# ─────────────────────────────────────────────────────────────
def register_passenger(
    full_name: str,
    gender: str,
    dob: str,
    email: str,
    phone: str,
    id_type: str,
    id_number: str,
) -> int:
    """
    Register a new passenger. Returns the new passenger_id.

    Args:
        gender  : 'Male' | 'Female' | 'Other'
        dob     : 'YYYY-MM-DD'
        id_type : 'Aadhaar' | 'Passport' | 'PAN' | 'VoterID' | 'DrivingLicence'
    """
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(
            """
            INSERT INTO Passenger
                (full_name, gender, dob, email, phone, id_type, id_number)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
            """,
            (full_name, gender, dob, email, phone, id_type, id_number),
        )
        conn.commit()
        return cursor.lastrowid
    except Error as e:
        conn.rollback()
        raise RuntimeError(f"Registration failed: {e}") from e
    finally:
        cursor.close()
        conn.close()


def get_passenger_bookings(passenger_id: int) -> list[dict]:
    """Return all bookings for a passenger, most recent first."""
    conn = get_connection()
    cursor = conn.cursor(dictionary=True)
    try:
        cursor.execute(
            """
            SELECT b.pnr, t.train_name,
                   src.station_name AS from_station,
                   dst.station_name AS to_station,
                   b.journey_date, sc.class_code,
                   b.fare, b.booking_status, b.booking_date
              FROM Booking     b
              JOIN Schedule    sch ON sch.schedule_id    = b.schedule_id
              JOIN Train       t   ON t.train_id         = sch.train_id
              JOIN Station     src ON src.station_id     = b.source_station_id
              JOIN Station     dst ON dst.station_id     = b.dest_station_id
              JOIN Seat_Class  sc  ON sc.class_id        = b.class_id
             WHERE b.passenger_id = %s
             ORDER BY b.booking_date DESC
            """,
            (passenger_id,),
        )
        return cursor.fetchall()
    finally:
        cursor.close()
        conn.close()


# ─────────────────────────────────────────────────────────────
# ADMIN REPORTS
# ─────────────────────────────────────────────────────────────
def get_daily_revenue(date_from: date, date_to: date) -> list[dict]:
    """Revenue report between two dates."""
    conn = get_connection()
    cursor = conn.cursor(dictionary=True)
    try:
        cursor.execute(
            """
            SELECT * FROM vw_daily_revenue
             WHERE booking_day BETWEEN %s AND %s
             ORDER BY booking_day DESC
            """,
            (date_from, date_to),
        )
        return cursor.fetchall()
    finally:
        cursor.close()
        conn.close()


def get_route_popularity(limit: int = 10) -> list[dict]:
    """Most booked source → destination pairs."""
    conn = get_connection()
    cursor = conn.cursor(dictionary=True)
    try:
        cursor.execute(
            f"SELECT * FROM vw_route_popularity LIMIT {int(limit)}"
        )
        return cursor.fetchall()
    finally:
        cursor.close()
        conn.close()


def get_train_occupancy(journey_date: Optional[date] = None) -> list[dict]:
    """Occupancy % per train. Defaults to tomorrow."""
    if journey_date is None:
        journey_date = date.today() + timedelta(days=1)
    conn = get_connection()
    cursor = conn.cursor(dictionary=True)
    try:
        cursor.execute(
            """
            SELECT * FROM vw_train_occupancy
             WHERE journey_date = %s
             ORDER BY occupancy_pct DESC
            """,
            (journey_date,),
        )
        return cursor.fetchall()
    finally:
        cursor.close()
        conn.close()


# ─────────────────────────────────────────────────────────────
# DEMO — end-to-end scenario
# ─────────────────────────────────────────────────────────────
if __name__ == "__main__":
    tomorrow = date.today() + timedelta(days=1)

    print("=" * 60)
    print("RAILWAY RESERVATION SYSTEM — Demo")
    print("=" * 60)

    # 1. Search trains
    print("\n[1] Searching trains NDLS → SBC ...")
    trains = search_trains("NDLS", "SBC", tomorrow)
    for tr in trains:
        print(f"    {tr['train_number']} {tr['train_name']} | "
              f"Dep {tr['departs']} | Status: {tr['train_status']}")

    if not trains:
        print("    No trains found. Check sample data / schedule dates.")
    else:
        schedule_id = trains[0]["schedule_id"]

        # 2. Availability
        print(f"\n[2] Seat availability for schedule {schedule_id} ...")
        avail = get_seat_availability(schedule_id)
        for row in avail:
            print(f"    {row['class_code']}: {row['available_seats']} free "
                  f"/ {row['total_seats']} total | WL: {row['on_waitlist']}")

        # 3. Fare preview
        print("\n[3] Fare calculation (3A, 1 passenger) ...")
        fare = calculate_fare(trains[0].get("train_id", 1), 1, 4, "3A", 1)
        print(f"    Fare: INR {fare}")

        # 4. Book
        print("\n[4] Booking ticket for passenger 1 ...")
        result = book_ticket(1, schedule_id, "3A", 1, 4, 1, "UPI")
        pnr = result["pnr"]
        print(f"    {result['message']}")

        # 5. PNR status
        print(f"\n[5] PNR status for {pnr} ...")
        status = get_pnr_status(pnr)
        if status:
            print(f"    Passenger : {status['passenger_name']}")
            print(f"    Train     : {status['train_name']}")
            print(f"    Seat      : {status['seat_info']} ({status['berth_type']})")
            print(f"    Status    : {status['booking_status']}")
            print(f"    Fare      : INR {status['fare']}")

        # 6. Cancel
        print(f"\n[6] Cancelling PNR {pnr} ...")
        cancel = cancel_ticket(pnr, "Demo cancellation")
        print(f"    {cancel['message']}")

    # 7. Revenue report
    print("\n[7] Revenue report (last 30 days) ...")
    revenue = get_daily_revenue(
        date.today() - timedelta(days=30), date.today()
    )
    if revenue:
        for row in revenue:
            print(f"    {row['booking_day']} | {row['train_name']} | "
                  f"Net: INR {row['net_revenue']}")
    else:
        print("    No revenue data yet.")

    print("\nDemo complete.")
