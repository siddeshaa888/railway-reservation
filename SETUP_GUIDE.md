# Railway Reservation System — Complete Setup Guide
### For: `/home/nmit/DBMS` on Ubuntu (WSL)

---

## STEP 1 — Open Ubuntu Terminal

Press `Win + R` → type `wsl` → Enter  
OR search **Ubuntu** in the Start menu.

---

## STEP 2 — Install & Start MySQL

```bash
sudo apt update
sudo apt install mysql-server -y
sudo service mysql start
```

Check it's running:
```bash
sudo service mysql status
```
You should see **active (running)**.

---

## STEP 3 — Fix MySQL Root Login (Important!)

Ubuntu 24's MySQL uses socket auth by default. Run this:

```bash
sudo mysql
```

Inside MySQL shell, paste this exactly:
```sql
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'nmit1234';
FLUSH PRIVILEGES;
EXIT;
```

> Your password is now: `nmit1234`  
> You can change it to anything you like — just remember it for Steps 4 & 6.

---

## STEP 4 — Navigate to Your Project Folder

```bash
cd /home/nmit/DBMS
ls
```

You should see all your .sql and .py files. If the folder doesn't exist yet:
```bash
mkdir -p /home/nmit/DBMS
cd /home/nmit/DBMS
```

Then copy your files there from Windows (via File Explorer → `\\wsl.localhost\Ubuntu\home\nmit\DBMS`).

---

## STEP 5 — Load the Database (Run All SQL Files)

Because `00_run_all.sql` uses `SOURCE` commands (which only work inside MySQL interactive shell), run each file individually:

```bash
mysql -u root -p < 01_schema.sql
mysql -u root -p < 02_sample_data.sql
mysql -u root -p < 03_functions_procedures.sql
mysql -u root -p < 04_triggers.sql
mysql -u root -p < 05_views.sql
mysql -u root -p < 06_indexes.sql
```

Enter `nmit1234` (or your chosen password) at each prompt.

**Faster — run all 6 with one command:**
```bash
for f in 01 02 03 04 05 06; do
  echo "Running ${f}..."
  mysql -u root -pnmit1234 < ${f}_*.sql
done
```
> Note: `-pnmit1234` (no space) skips the password prompt.

---

## STEP 6 — Verify the Database Loaded

```bash
mysql -u root -pnmit1234 -e "USE railway_db; SHOW TABLES; SELECT COUNT(*) AS passengers FROM Passenger; SELECT COUNT(*) AS seats FROM Seat;"
```

Expected output:
- **10 tables** listed
- **5 passengers**
- **160 seats**

---

## STEP 7 — Run Demo Queries (Optional)

```bash
mysql -u root -pnmit1234 < 07_queries.sql | head -100
```

Or run interactively:
```bash
mysql -u root -pnmit1234 railway_db
```
Then paste any query from `07_queries.sql`.

---

## STEP 8 — Set Up Python Backend

### 8a. Install the MySQL connector

```bash
pip3 install mysql-connector-python --break-system-packages
```

### 8b. Edit the password in the Python file

```bash
nano 08_backend_integration.py
```

Find line ~20:
```python
"password": "yourpassword",   # ← change this
```

Change to:
```python
"password": "nmit1234",
```

Save: `Ctrl+O` → Enter → `Ctrl+X`

### 8c. Run the backend demo

```bash
python3 08_backend_integration.py
```

---

## STEP 9 — Expected Python Output

```
============================================================
RAILWAY RESERVATION SYSTEM — Demo
============================================================

[1] Searching trains NDLS → SBC ...
    12028 Shatabdi Express | Dep 06:00:00 | Status: OnTime

[2] Seat availability for schedule 1 ...
    1A: 10 free / 10 total | WL: 0
    2A: 10 free / 10 total | WL: 0
    3A: 10 free / 10 total | WL: 0
    SL: 10 free / 10 total | WL: 0

[3] Fare calculation (3A, 1 passenger) ...
    Fare: INR 3592.0

[4] Booking ticket for passenger 1 ...
    Booking Confirmed. PNR: XXXXXXXXXX. Fare: INR 3592.0

[5] PNR status for XXXXXXXXXX ...
    Passenger : Arjun Sharma
    Train     : Shatabdi Express
    Seat      : A1/01 (Lower)
    Status    : Confirmed
    Fare      : INR 3592.00

[6] Cancelling PNR XXXXXXXXXX ...
    PNR XXXXXXXXXX cancelled. Refund: INR 2694.0 (75%)

[7] Revenue report (last 30 days) ...
    (shows today's booking data)

Demo complete.
```

---

## Quick Reference — All Commands in Order

```bash
# 1. Start MySQL
sudo service mysql start

# 2. Set root password (only first time)
sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'nmit1234'; FLUSH PRIVILEGES;"

# 3. Go to project folder
cd /home/nmit/DBMS

# 4. Load all SQL files
for f in 01 02 03 04 05 06; do mysql -u root -pnmit1234 < ${f}_*.sql; done

# 5. Install Python connector
pip3 install mysql-connector-python --break-system-packages

# 6. Edit password in Python file
sed -i 's/yourpassword/nmit1234/' 08_backend_integration.py

# 7. Run backend
python3 08_backend_integration.py
```

---

## Common Errors & Fixes

| Error | Cause | Fix |
|-------|-------|-----|
| `ERROR 1045: Access denied` | Wrong password | Redo Step 3 |
| `mysql: command not found` | MySQL not installed | `sudo apt install mysql-server -y` |
| `ModuleNotFoundError: mysql.connector` | Connector missing | `pip3 install mysql-connector-python --break-system-packages` |
| `ERROR 1050: Table already exists` | DB already loaded | Run `mysql -u root -p < 01_schema.sql` first (it drops & recreates) |
| `Can't connect to MySQL server` | MySQL not running | `sudo service mysql start` |
| `externally-managed-environment` | Ubuntu pip restriction | Add `--break-system-packages` flag |
| `SOURCE command not found` | Used `00_run_all.sql` directly | Use individual files (Step 5 above) |

---

## Architecture Overview

```
Your Files in /home/nmit/DBMS/
│
├── 01_schema.sql          → Creates 10 tables (Station, Train, Route, etc.)
├── 02_sample_data.sql     → Inserts 8 stations, 4 trains, 5 passengers, 160 seats
├── 03_functions_procedures.sql → generate_pnr(), sp_book_ticket(), sp_cancel_ticket()
├── 04_triggers.sql        → Auto waitlist promotion, date validation
├── 05_views.sql           → 6 views (PNR status, seat availability, revenue, etc.)
├── 06_indexes.sql         → 8 performance indexes
├── 07_queries.sql         → Demo queries (optional, for testing)
└── 08_backend_integration.py → Python functions that call all the above
```

The Python backend connects to MySQL and exposes clean functions:
- `search_trains()` → calls `sp_search_trains` procedure
- `book_ticket()` → calls `sp_book_ticket` procedure (ACID transaction)
- `cancel_ticket()` → calls `sp_cancel_ticket` procedure (triggers waitlist)
- `get_pnr_status()` → queries `vw_pnr_status` view
- `get_daily_revenue()` → queries `vw_daily_revenue` view
