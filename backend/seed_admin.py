"""
seed_admin.py — Create the Super Admin account on your cloud database.

Usage:
    1. Set DATABASE_URL in your environment or .env file
       e.g.  DATABASE_URL=mysql+pymysql://user:pass@host:3306/dbname
    2. Run:  python seed_admin.py

Only one Super Admin is allowed. If one already exists, this script will exit.
"""

import os
import sys
import getpass

try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    env_path = os.path.join(os.path.dirname(__file__), '.env')
    if os.path.exists(env_path):
        with open(env_path, 'r', encoding='utf-8') as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#') and '=' in line:
                    k, v = line.split('=', 1)
                    os.environ.setdefault(k.strip(), v.strip())

try:
    import pymysql
    import bcrypt
except ImportError:
    sys.exit("ERROR: Run  pip install pymysql bcrypt  first.")

DATABASE_URL = os.environ.get('DATABASE_URL', '')

if DATABASE_URL:
    from urllib.parse import urlparse
    _url = DATABASE_URL.replace('mysql+pymysql://', 'mysql://')
    parsed = urlparse(_url)
    DB_CONFIG = {
        'host':     parsed.hostname,
        'user':     parsed.username,
        'password': parsed.password,
        'database': parsed.path.lstrip('/'),
        'port':     parsed.port or 3306,
        'cursorclass': pymysql.cursors.DictCursor,
        'ssl':      {'ssl_disabled': False},
    }
else:
    DB_CONFIG = {
        'host':     os.environ.get('DB_HOST', '127.0.0.1'),
        'user':     os.environ.get('DB_USER', 'root'),
        'password': os.environ.get('DB_PASSWORD', ''),
        'database': os.environ.get('DB_NAME', 'sacco_db'),
        'port':     int(os.environ.get('DB_PORT', 3306)),
        'cursorclass': pymysql.cursors.DictCursor,
    }

ROLE_SUPER_ADMIN = 'SUPER_ADMIN'

print("\n=== Youth SACCO — Create Super Admin Account ===\n")
print("Note: Only ONE Super Admin is allowed in the system.\n")

full_name    = input("Full Name    : ").strip()
username     = input("Username     : ").strip()
email        = input("Email        : ").strip()
phone        = input("Phone (10 digits): ").strip()
# Allow password via env var for non‑interactive use
password = os.getenv('SUPERADMIN_PASSWORD')
if not password:
    try:
        password = getpass.getpass("Password     : ")
    except Exception:
        print("[!] getpass failed, falling back to visible input.")
        password = input("Password (visible)     : ")
confirm = os.getenv('SUPERADMIN_CONFIRM')
if not confirm:
    try:
        confirm = getpass.getpass("Confirm pass : ")
    except Exception:
        print("[!] getpass failed, falling back to visible input.")
        confirm = input("Confirm pass (visible) : ")

if password != confirm:
    sys.exit("ERROR: Passwords do not match.")
if not phone.isdigit() or len(phone) != 10:
    sys.exit("ERROR: Phone must be exactly 10 digits.")
if not all([full_name, username, email, password]):
    sys.exit("ERROR: All fields are required.")

hashed = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')

try:
    conn   = pymysql.connect(**DB_CONFIG)
    cursor = conn.cursor()

    cursor.execute("SELECT COUNT(*) as cnt FROM admins WHERE role = %s", (ROLE_SUPER_ADMIN,))
    if cursor.fetchone()['cnt'] > 0:
        conn.close()
        sys.exit("ERROR: A Super Admin already exists. Use the Super Admin dashboard to create other admins.")

    cursor.execute("SELECT id FROM admins WHERE email = %s OR username = %s", (email, username))
    if cursor.fetchone():
        conn.close()
        sys.exit("ERROR: An admin with that email or username already exists.")

    cursor.execute("""
        INSERT INTO admins (username, email, password, phone_number, full_name, role, is_active)
        VALUES (%s, %s, %s, %s, %s, %s, 1)
    """, (username, email, hashed, phone, full_name, ROLE_SUPER_ADMIN))
    conn.commit()
    conn.close()

    print(f"\nSuper Admin account created successfully!")
    print(f"   Name  : {full_name}")
    print(f"   Email : {email}")
    print(f"   Role  : {ROLE_SUPER_ADMIN}")
    print(f"   Login at your admin web panel — you will be directed to the Super Admin Control Center.\n")

except Exception as e:
    sys.exit(f"ERROR: Database error — {e}")
