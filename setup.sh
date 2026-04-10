#!/bin/bash
# ============================================================
#   Railway Reservation System — One-Shot Setup Script
#   Run from: /home/nmit/DBMS
#   Usage:    bash setup.sh
# ============================================================

set -e  # Exit on any error

DBPASS="nmit1234"
DBUSER="root"
DBNAME="railway_db"

echo ""
echo "======================================================"
echo "  RAILWAY RESERVATION SYSTEM — SETUP"
echo "======================================================"

# ── Step 1: Start MySQL ───────────────────────────────────
echo ""
echo "[1/5] Starting MySQL..."
sudo service mysql start 2>/dev/null || true
sleep 2
echo "      MySQL is running."

# ── Step 2: Set root password ─────────────────────────────
echo ""
echo "[2/5] Configuring MySQL root user..."
sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${DBPASS}'; FLUSH PRIVILEGES;" 2>/dev/null || \
mysql -u root -p"${DBPASS}" -e "SELECT 1;" 2>/dev/null || true
echo "      Password set to: ${DBPASS}"

# ── Step 3: Load SQL files ────────────────────────────────
echo ""
echo "[3/5] Loading SQL files into MySQL..."

FILES=(
    "01_schema.sql"
    "02_sample_data.sql"
    "03_functions_procedures.sql"
    "04_triggers.sql"
    "05_views.sql"
    "06_indexes.sql"
)

for f in "${FILES[@]}"; do
    if [ -f "$f" ]; then
        echo "      Loading $f ..."
        mysql -u ${DBUSER} -p"${DBPASS}" < "$f"
        echo "      ✓ $f done"
    else
        echo "      ✗ WARNING: $f not found — skipping"
    fi
done

# ── Step 4: Verify ────────────────────────────────────────
echo ""
echo "[4/5] Verifying database..."
mysql -u ${DBUSER} -p"${DBPASS}" ${DBNAME} -e "
SELECT 'Tables loaded:' AS '', COUNT(*) AS count FROM information_schema.tables WHERE table_schema='${DBNAME}';
SELECT 'Passengers:' AS '', COUNT(*) AS count FROM Passenger;
SELECT 'Seats:' AS '', COUNT(*) AS count FROM Seat;
SELECT 'Schedules:' AS '', COUNT(*) AS count FROM Schedule;
" 2>/dev/null

# ── Step 5: Python setup ──────────────────────────────────
echo ""
echo "[5/5] Setting up Python backend..."

# Install mysql-connector-python
pip3 install mysql-connector-python --break-system-packages --quiet 2>/dev/null || \
pip3 install mysql-connector-python --quiet 2>/dev/null || true

# Update password in Python file
if [ -f "08_backend_integration.py" ]; then
    sed -i "s/\"password\":.*#.*/\"password\": \"${DBPASS}\",  # auto-set by setup.sh/" 08_backend_integration.py
    # Also try the exact string match
    sed -i 's/"password":     "yourpassword"/"password":     "'"${DBPASS}"'"/' 08_backend_integration.py
    echo "      ✓ Password updated in 08_backend_integration.py"
else
    echo "      ✗ WARNING: 08_backend_integration.py not found"
fi

echo ""
echo "======================================================"
echo "  SETUP COMPLETE!"
echo "======================================================"
echo ""
echo "  Database : ${DBNAME}"
echo "  User     : ${DBUSER}"
echo "  Password : ${DBPASS}"
echo ""
echo "  To run the Python backend demo:"
echo "      python3 08_backend_integration.py"
echo ""
echo "  To run demo SQL queries:"
echo "      mysql -u root -p${DBPASS} < 07_queries.sql"
echo ""
echo "  To open MySQL shell:"
echo "      mysql -u root -p${DBPASS} ${DBNAME}"
echo "======================================================"
