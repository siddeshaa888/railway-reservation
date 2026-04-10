# Railway.app Deployment Guide
## Railway Reservation System — Flask + MySQL

---

## What You Need
- GitHub account (free): https://github.com
- Railway account (free): https://railway.app
- Your project files

---

## PART 1 — Prepare Your Project Files

Your final folder structure must look like this:

```
railway-reservation/          ← Root folder (name it anything)
├── app.py                    ← Flask backend (Railway-ready version)
├── Procfile                  ← Tells Railway how to run the app
├── requirements.txt          ← Python packages
├── .gitignore                ← Files to ignore
├── .env.example              ← Environment variable template
├── railway_reservation_system.sql  ← Combined SQL file
└── templates/
    └── index.html            ← Frontend UI
```

---

## PART 2 — Push to GitHub

### Step 1 — Install Git (if not already)
```bash
sudo apt install git -y
git config --global user.name "Your Name"
git config --global user.email "your@email.com"
```

### Step 2 — Create the project folder and copy files
```bash
mkdir ~/railway-reservation
cd ~/railway-reservation

# Copy all your files here
cp /home/nmit/DBMS/app.py .
cp /home/nmit/DBMS/railway_reservation_system.sql .
cp Procfile requirements.txt .gitignore .env.example .

mkdir templates
cp /home/nmit/DBMS/templates/index.html templates/
```

### Step 3 — Initialize Git repo
```bash
cd ~/railway-reservation
git init
git add .
git commit -m "Initial commit: Railway Reservation System"
```

### Step 4 — Push to GitHub
1. Go to https://github.com/new
2. Create a new repository named: `railway-reservation`
3. Set it to **Public**
4. Do NOT check "Add README"
5. Click **Create repository**
6. Copy the commands GitHub shows you, they look like:

```bash
git remote add origin https://github.com/YOUR_USERNAME/railway-reservation.git
git branch -M main
git push -u origin main
```

Run those 3 commands in your terminal.

---

## PART 3 — Deploy on Railway.app

### Step 1 — Create Railway Account
1. Go to https://railway.app
2. Click **Login** → **Login with GitHub**
3. Authorize Railway to access your GitHub

### Step 2 — Create New Project
1. Click **New Project**
2. Select **Deploy from GitHub repo**
3. Find and select `railway-reservation`
4. Click **Deploy Now**

Railway will automatically detect it's a Python/Flask app and start building.

### Step 3 — Add MySQL Database
1. In your Railway project dashboard, click **+ New**
2. Select **Database**
3. Select **MySQL**
4. Wait for it to provision (takes ~30 seconds)

### Step 4 — Connect MySQL to Your App
1. Click on your **MySQL service**
2. Go to the **Variables** tab
3. You'll see variables like:
   - `MYSQLHOST`
   - `MYSQLPORT`
   - `MYSQLUSER`
   - `MYSQLPASSWORD`
   - `MYSQLDATABASE`

4. Click on your **Flask app service**
5. Go to **Variables** tab
6. Click **+ Add Variable Reference**
7. Add each MySQL variable by referencing the MySQL service:
   - `MYSQLHOST` = `${{MySQL.MYSQLHOST}}`
   - `MYSQLPORT` = `${{MySQL.MYSQLPORT}}`
   - `MYSQLUSER` = `${{MySQL.MYSQLUSER}}`
   - `MYSQLPASSWORD` = `${{MySQL.MYSQLPASSWORD}}`
   - `MYSQLDATABASE` = `railway`

### Step 5 — Load the Database Schema
1. Click on your **MySQL service** in Railway
2. Go to the **Query** tab (or use the Data tab)
3. You'll see a MySQL connection string like:
   ```
   mysql -h roundhouse.proxy.rlwy.net -u root -pXXXXX --port 12345 railway
   ```
4. Run this from your Ubuntu terminal:
   ```bash
   mysql -h <RAILWAY_HOST> -u root -p<PASSWORD> --port <PORT> railway < /home/nmit/DBMS/railway_reservation_system.sql
   ```
   Replace `<RAILWAY_HOST>`, `<PASSWORD>`, `<PORT>` with the values from Railway.

### Step 6 — Generate Public URL
1. Click on your **Flask app service**
2. Go to **Settings** tab
3. Scroll to **Networking**
4. Click **Generate Domain**
5. You'll get a URL like: `https://railway-reservation-production.up.railway.app`

**That's your live app! Share this URL with anyone.**

---

## PART 4 — Verify Everything Works

Visit your Railway URL and check:
- ✅ Dashboard loads with stats
- ✅ Search Trains works
- ✅ Book Ticket works end-to-end
- ✅ PNR Status works
- ✅ Cancel Ticket works

You can also test the health endpoint:
```
https://your-app.up.railway.app/health
```
Should return: `{"database": "connected", "status": "ok"}`

---

## PART 5 — Update the App Later

Whenever you make changes to your code:
```bash
cd ~/railway-reservation
git add .
git commit -m "Update: describe what you changed"
git push
```

Railway automatically redeploys when you push to GitHub. Takes about 60 seconds.

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Build fails | Check `requirements.txt` has correct package names |
| App crashes on start | Check Railway logs → click service → Deployments → View Logs |
| Database connection error | Verify all 5 MySQL env variables are set in Flask service |
| `relation does not exist` | Re-run the SQL file against Railway MySQL |
| 502 Bad Gateway | App crashed — check logs for Python errors |
| Schema not loading | Make sure you're connecting to `railway` database, not `railway_db` |

**Important:** Railway's MySQL database name is `railway` by default, not `railway_db`. The `app.py` reads `MYSQLDATABASE` from environment, so Railway will set this correctly automatically.

---

## Free Tier Limits on Railway
- $5 free credit per month
- Enough for a demo/college project running 24/7
- MySQL: 1GB storage
- No credit card required for hobby tier
