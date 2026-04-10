#!/bin/bash
# ============================================================
#   Railway Reservation System — Frontend Setup & Run
#   Run: bash run_app.sh
# ============================================================

echo ""
echo "======================================================"
echo "  RAILWAY RESERVATION SYSTEM — Web App"
echo "======================================================"

# Install dependencies
echo ""
echo "[1/3] Installing Python packages..."
pip3 install flask flask-cors mysql-connector-python --break-system-packages --quiet
echo "      ✓ Flask, Flask-CORS, MySQL connector installed"

# Check MySQL is running
echo ""
echo "[2/3] Checking MySQL..."
sudo service mysql start 2>/dev/null || true
mysql -u root -pnmit1234 railway_db -e "SELECT 1;" > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "      ✓ MySQL connected to railway_db"
else
    echo "      ✗ MySQL connection failed. Check password in app.py"
    exit 1
fi

# Start Flask
echo ""
echo "[3/3] Starting Flask web server..."
echo ""
echo "======================================================"
echo "  Open your browser and go to:"
echo "  http://localhost:5000"
echo ""
echo "  Press Ctrl+C to stop the server"
echo "======================================================"
echo ""

python3 app.py
