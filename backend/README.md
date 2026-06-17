# Youth SACCO Backend API

Flask REST API for the Youth SACCO mobile application and admin web dashboard.

## Tech Stack
- **Python 3.11** / **Flask 3.x**
- **MySQL** via PyMySQL
- **JWT** authentication + **bcrypt** password hashing
- **Gunicorn** WSGI server (production)

---

## Local Development

### 1. Install dependencies
```bash
pip install -r requirements.txt
```

### 2. Configure environment
```bash
copy .env.example .env
# Edit .env with your local MySQL credentials
```

### 3. Set up the database
```bash
# Create the sacco_db database in MySQL, then run:
mysql -u root -p sacco_db < schema.sql
```

### 4. Run the server
```bash
python run.py
# API available at http://127.0.0.1:8000/api
```

---

## Deployment (Render + FreeSQLDatabase.com)

**Full step-by-step guide:** see [DEPLOY.md](./DEPLOY.md)

### Quick summary:
1. Get a free MySQL DB at [freesqldatabase.com](https://www.freesqldatabase.com)
2. Run `schema.sql` against it
3. Push this folder to GitHub
4. Create a Web Service on [render.com](https://render.com):
   - **Build:** `pip install -r requirements.txt`
   - **Start:** `gunicorn wsgi:app`
5. Set env vars in Render dashboard (`DATABASE_URL`, `SECRET_KEY`, SMTP)
6. Create first admin: `python seed_admin.py`

---

## Project Structure

```
backend/
├── app.py              # All routes and business logic
├── wsgi.py             # Gunicorn entry point
├── run.py              # Local dev entry point
├── Procfile            # Render/Heroku start command
├── render.yaml         # Render blueprint (optional)
├── schema.sql          # Full database schema
├── seed_admin.py       # Create first admin account
├── requirements.txt    # Python dependencies
├── .env.example        # Environment variable template
└── .gitignore
```

---

## API Endpoints

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| GET | `/health` | — | Health check + DB status |
| POST | `/api/register` | — | Register new member |
| POST | `/api/login` | — | Login (returns JWT) |
| POST | `/api/login/verify` | — | MFA code verification |
| GET | `/api/user/summary/:id` | JWT | Account summary |
| POST | `/api/deposit` | JWT | Deposit funds |
| POST | `/api/withdraw` | JWT | Withdraw funds |
| POST | `/api/transfer` | JWT | Transfer funds |
| POST | `/api/loans/apply` | JWT | Apply for loan |
| POST | `/api/loans/repay` | JWT | Repay loan |
| POST | `/api/shares/buy` | JWT | Buy shares |
| GET | `/api/admin/stats` | Admin JWT | Dashboard stats |
| GET | `/api/admin/users` | Admin JWT | All members |
| GET | `/api/admin/loans` | Admin JWT | All loans |
| POST | `/api/admin/loans/action` | Admin JWT | Approve/reject loan |
| GET/POST | `/api/admin/config` | Admin JWT | System configuration |

---

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `DATABASE_URL` | Cloud only | Full MySQL connection URL |
| `DB_HOST` | Local only | MySQL host (default: 127.0.0.1) |
| `DB_USER` | Local only | MySQL username (default: root) |
| `DB_PASSWORD` | Local only | MySQL password |
| `DB_NAME` | Local only | Database name (default: sacco_db) |
| `SECRET_KEY` | Yes | JWT signing secret |
| `SMTP_USER` | Optional | Gmail address for MFA emails |
| `SMTP_PASSWORD` | Optional | Gmail App Password |