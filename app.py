"""
================================================================
  RAILWAY RESERVATION SYSTEM — Flask Web Backend
  File: app.py
  Run:  python3 app.py
  URL:  http://localhost:5000
================================================================
"""

from flask import Flask, request, jsonify, render_template
from flask_cors import CORS
import mysql.connector
import os
from mysql.connector import Error
from datetime import date, timedelta
from typing import Optional

app = Flask(__name__)
CORS(app)

# ─────────────────────────────────────────────────────────────
# DATABASE CONFIG — change password if needed
# ─────────────────────────────────────────────────────────────
DB_CONFIG = {
    "host": os.getenv("MYSQLHOST"),
    "port": int(os.getenv("MYSQLPORT")),
    "user": os.getenv("MYSQLUSER"),
    "password": os.getenv("MYSQLPASSWORD"),
    "database": os.getenv("MYSQLDATABASE")
}
print("DEBUG ENV →",
      os.getenv("MYSQLHOST"),
      os.getenv("MYSQLPORT"),
      os.getenv("MYSQLUSER"),
      os.getenv("MYSQLDATABASE"))
def get_connection():
    return mysql.connector.connect(**DB_CONFIG)

def serialize(obj):
    """Convert non-serializable types for JSON."""
    if isinstance(obj, date):
        return obj.strftime('%Y-%m-%d')
    if hasattr(obj, '__str__'):
        return str(obj)
    return obj

def serialize_row(row):
    if row is None:
        return None
    return {k: serialize(v) for k, v in row.items()}

def serialize_rows(rows):
    return [serialize_row(r) for r in rows]


# ─────────────────────────────────────────────────────────────
# ROUTES — Pages
# ─────────────────────────────────────────────────────────────
@app.route('/')
def index():
    return render_template('index.html')


# ─────────────────────────────────────────────────────────────
# API — Search Trains
# ─────────────────────────────────────────────────────────────
@app.route('/api/search', methods=['POST'])
def search_trains():
    data = request.json
    source = data.get('source')
    dest   = data.get('dest')
    date_  = data.get('date')
    try:
        conn   = get_connection()
        cursor = conn.cursor(dictionary=True)
        cursor.callproc("sp_search_trains", [source, dest, date_])
        results = []
        for result in cursor.stored_results():
            results = serialize_rows(result.fetchall())
        cursor.close()
        conn.close()
        return jsonify({"success": True, "trains": results})
    except Error as e:
        return jsonify({"success": False, "error": str(e)}), 500


# ─────────────────────────────────────────────────────────────
# API — Get Stations
# ─────────────────────────────────────────────────────────────
@app.route('/api/stations', methods=['GET'])
def get_stations():
    try:
        conn   = get_connection()
        cursor = conn.cursor(dictionary=True)
        cursor.execute("SELECT station_id, station_code, station_name, city FROM Station ORDER BY station_name")
        stations = serialize_rows(cursor.fetchall())
        cursor.close()
        conn.close()
        return jsonify({"success": True, "stations": stations})
    except Error as e:
        return jsonify({"success": False, "error": str(e)}), 500


# ─────────────────────────────────────────────────────────────
# API — Seat Availability
# ─────────────────────────────────────────────────────────────
@app.route('/api/availability/<int:schedule_id>', methods=['GET'])
def get_availability(schedule_id):
    try:
        conn   = get_connection()
        cursor = conn.cursor(dictionary=True)
        cursor.execute("""
            SELECT class_code, class_name, total_seats,
                   booked_seats, available_seats, on_waitlist
              FROM vw_seat_availability
             WHERE schedule_id = %s
             ORDER BY class_code
        """, (schedule_id,))
        rows = serialize_rows(cursor.fetchall())
        cursor.close()
        conn.close()
        return jsonify({"success": True, "availability": rows})
    except Error as e:
        return jsonify({"success": False, "error": str(e)}), 500


# ─────────────────────────────────────────────────────────────
# API — Calculate Fare
# ─────────────────────────────────────────────────────────────
@app.route('/api/fare', methods=['POST'])
def calculate_fare():
    data = request.json
    try:
        conn   = get_connection()
        cursor = conn.cursor()
        args   = (data['train_id'], data['source_id'], data['dest_id'],
                  data['class_code'], data.get('num_passengers', 1), 0.0)
        result = cursor.callproc("sp_calculate_fare", args)
        fare   = float(result[5])
        cursor.close()
        conn.close()
        return jsonify({"success": True, "fare": fare})
    except Error as e:
        return jsonify({"success": False, "error": str(e)}), 500


# ─────────────────────────────────────────────────────────────
# API — Register Passenger
# ─────────────────────────────────────────────────────────────
@app.route('/api/passenger/register', methods=['POST'])
def register_passenger():
    data = request.json
    try:
        conn   = get_connection()
        cursor = conn.cursor()
        cursor.execute("""
            INSERT INTO Passenger (full_name, gender, dob, email, phone, id_type, id_number)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
        """, (data['full_name'], data['gender'], data['dob'],
              data['email'], data['phone'], data['id_type'], data['id_number']))
        conn.commit()
        pid = cursor.lastrowid
        cursor.close()
        conn.close()
        return jsonify({"success": True, "passenger_id": pid,
                        "message": f"Passenger registered with ID {pid}"})
    except Error as e:
        return jsonify({"success": False, "error": str(e)}), 500


# ─────────────────────────────────────────────────────────────
# API — Get Passenger by Email
# ─────────────────────────────────────────────────────────────
@app.route('/api/passenger/find', methods=['POST'])
def find_passenger():
    data = request.json
    try:
        conn   = get_connection()
        cursor = conn.cursor(dictionary=True)
        cursor.execute("SELECT * FROM Passenger WHERE email = %s", (data['email'],))
        row = serialize_row(cursor.fetchone())
        cursor.close()
        conn.close()
        if row:
            return jsonify({"success": True, "passenger": row})
        return jsonify({"success": False, "error": "Passenger not found"}), 404
    except Error as e:
        return jsonify({"success": False, "error": str(e)}), 500


# ─────────────────────────────────────────────────────────────
# API — Book Ticket
# ─────────────────────────────────────────────────────────────
@app.route('/api/book', methods=['POST'])
def book_ticket():
    data = request.json
    try:
        conn   = get_connection()
        cursor = conn.cursor()
        args   = (
            data['passenger_id'], data['schedule_id'], data['class_code'],
            data['source_id'], data['dest_id'],
            data.get('num_passengers', 1), data.get('payment_method', 'UPI'),
            "", "", ""
        )
        result = cursor.callproc("sp_book_ticket", args)
        conn.commit()
        cursor.close()
        conn.close()
        return jsonify({
            "success": True,
            "pnr":     result[7],
            "status":  result[8],
            "message": result[9]
        })
    except Error as e:
        return jsonify({"success": False, "error": str(e)}), 500


# ─────────────────────────────────────────────────────────────
# API — PNR Status
# ─────────────────────────────────────────────────────────────
@app.route('/api/pnr/<pnr>', methods=['GET'])
def pnr_status(pnr):
    try:
        conn   = get_connection()
        cursor = conn.cursor(dictionary=True)
        cursor.execute("SELECT * FROM vw_pnr_status WHERE pnr = %s", (pnr,))
        row = serialize_row(cursor.fetchone())
        cursor.close()
        conn.close()
        if row:
            return jsonify({"success": True, "booking": row})
        return jsonify({"success": False, "error": "PNR not found"}), 404
    except Error as e:
        return jsonify({"success": False, "error": str(e)}), 500


# ─────────────────────────────────────────────────────────────
# API — Cancel Ticket
# ─────────────────────────────────────────────────────────────
@app.route('/api/cancel', methods=['POST'])
def cancel_ticket():
    data = request.json
    try:
        conn   = get_connection()
        cursor = conn.cursor()
        args   = (data['pnr'], data.get('reason', 'Cancelled by user'), 0.0, "")
        result = cursor.callproc("sp_cancel_ticket", args)
        conn.commit()
        cursor.close()
        conn.close()
        return jsonify({
            "success":       True,
            "refund_amount": float(result[2]),
            "message":       result[3]
        })
    except Error as e:
        return jsonify({"success": False, "error": str(e)}), 500


# ─────────────────────────────────────────────────────────────
# API — Passenger Booking History
# ─────────────────────────────────────────────────────────────
@app.route('/api/passenger/<int:passenger_id>/bookings', methods=['GET'])
def passenger_bookings(passenger_id):
    try:
        conn   = get_connection()
        cursor = conn.cursor(dictionary=True)
        cursor.execute("""
            SELECT b.pnr, t.train_name, t.train_number,
                   src.station_name AS from_station,
                   dst.station_name AS to_station,
                   b.journey_date, sc.class_code, sc.class_name,
                   b.fare, b.booking_status, b.num_passengers,
                   b.booking_date
              FROM Booking b
              JOIN Schedule   sch ON sch.schedule_id   = b.schedule_id
              JOIN Train      t   ON t.train_id        = sch.train_id
              JOIN Station    src ON src.station_id    = b.source_station_id
              JOIN Station    dst ON dst.station_id    = b.dest_station_id
              JOIN Seat_Class sc  ON sc.class_id       = b.class_id
             WHERE b.passenger_id = %s
             ORDER BY b.booking_date DESC
        """, (passenger_id,))
        rows = serialize_rows(cursor.fetchall())
        cursor.close()
        conn.close()
        return jsonify({"success": True, "bookings": rows})
    except Error as e:
        return jsonify({"success": False, "error": str(e)}), 500


# ─────────────────────────────────────────────────────────────
# API — Dashboard Stats
# ─────────────────────────────────────────────────────────────
@app.route('/api/dashboard', methods=['GET'])
def dashboard():
    try:
        conn   = get_connection()
        cursor = conn.cursor(dictionary=True)

        cursor.execute("SELECT COUNT(*) AS total FROM Booking WHERE booking_status='Confirmed'")
        confirmed = cursor.fetchone()['total']

        cursor.execute("SELECT COUNT(*) AS total FROM Booking WHERE booking_status='Waitlisted'")
        waitlisted = cursor.fetchone()['total']

        cursor.execute("SELECT COALESCE(SUM(fare),0) AS total FROM Booking WHERE booking_status != 'Cancelled'")
        revenue = float(cursor.fetchone()['total'])

        cursor.execute("SELECT COUNT(*) AS total FROM Passenger")
        passengers = cursor.fetchone()['total']

        cursor.execute("SELECT * FROM vw_train_occupancy ORDER BY journey_date LIMIT 6")
        occupancy = serialize_rows(cursor.fetchall())

        cursor.execute("SELECT * FROM vw_route_popularity LIMIT 5")
        popular = serialize_rows(cursor.fetchall())

        cursor.close()
        conn.close()
        return jsonify({
            "success": True,
            "stats": {
                "confirmed":  confirmed,
                "waitlisted": waitlisted,
                "revenue":    revenue,
                "passengers": passengers
            },
            "occupancy": occupancy,
            "popular_routes": popular
        })
    except Error as e:
        return jsonify({"success": False, "error": str(e)}), 500


if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)
