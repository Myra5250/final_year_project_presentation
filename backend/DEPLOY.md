# Deploy Youth SACCO Backend to Render

This guide walks you through hosting the Flask API on [Render.com](https://render.com) with a free MySQL database.

## What you need

- GitHub account (repo pushed with the `backend/` folder)
- [Render.com](https://render.com) account (free tier works)
- MySQL database (free options below)

---

## Step 1 — Create a MySQL database

Pick one provider and create a database named `sacco_db`:

| Provider | Notes |
|----------|--------|
| [FreeSQLDatabase.com](https://freesqldatabase.com) | Free, good for demos |
| [PlanetScale](https://planetscale.com) | Free tier, reliable |
| [Railway](https://railway.app) | Easy setup |

After creation, note your connection details: host, port, username, password, database name.

**Connection URL format** (for Render env var):

```
mysql+pymysql://USERNAME:PASSWORD@HOST:PORT/DATABASE_NAME
```

---

## Step 2 — Import the database schema

```bash
cd backend
mysql -h YOUR_HOST -P YOUR_PORT -u YOUR_USER -p YOUR_DATABASE < schema.sql
```

Or import `schema.sql` via phpMyAdmin / MySQL Workbench.

---

## Step 3 — Push code to GitHub

```bash
git add backend/
git commit -m "Prepare backend for Render deployment"
git push origin main
```

---

## Step 4 — Create Render Web Service

1. Go to [dashboard.render.com](https://dashboard.render.com) → **New +** → **Web Service**
2. Connect your GitHub repository
3. Configure:

| Setting | Value |
|---------|--------|
| **Name** | `youth-sacco-backend` |
| **Root Directory** | `backend` |
| **Runtime** | Python 3 |
| **Build Command** | `pip install -r requirements.txt` |
| **Start Command** | `gunicorn wsgi:app --bind 0.0.0.0:$PORT` |
| **Plan** | Free |

---

## Step 5 — Set environment variables

In Render → your service → **Environment**, add:

| Key | Value |
|-----|--------|
| `DATABASE_URL` | Your full MySQL URL from Step 1 |
| `SECRET_KEY` | Long random string |
| `SMTP_SERVER` | `smtp.gmail.com` |
| `SMTP_PORT` | `587` |
| `SMTP_USER` | Your Gmail address |
| `SMTP_PASSWORD` | Gmail App Password |
| `SMTP_FROM` | `noreply@youthsacco.com` |
| `PYTHON_VERSION` | `3.11.0` |

---

## Step 6 — Verify deployment

```bash
curl https://YOUR-SERVICE.onrender.com/health
```

**Admin dashboard:** open in your browser:

```
https://YOUR-SERVICE.onrender.com/admin/
```

Do not open `index.html` directly from your file explorer — always use the URL above so the API connects correctly.

Mobile app API base URL:

```
https://YOUR-SERVICE.onrender.com/api
```

---

## Step 7 — Create the first admin

```bash
cd backend
python seed_admin.py
```

---

## Step 8 — Update mobile app production URL

In `sacco_mobile_application/lib/services/api_service.dart`:

```dart
static const String _productionUrl = 'https://YOUR-SERVICE.onrender.com/api';
```

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `db: error` on `/health` | Check `DATABASE_URL` format |
| Slow first request | Free Render spins down after idle (~30s wake) |
| MFA emails not sent | Set SMTP vars; codes print to Render logs if missing |
