"""
migrate_super_admin.py — Add role-based admin controls.

Run once against an existing database:
    python migrate_super_admin.py

What it does:
  1. Adds admins.is_active column if missing
  2. Creates admin_audit_log table if missing
  3. Promotes the oldest admin to SUPER_ADMIN if none exists (only one)
"""

import os
import sys

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
except ImportError:
    sys.exit("ERROR: Run  pip install pymysql  first.")

DATABASE_URL = os.environ.get('DATABASE_URL', '')

if DATABASE_URL:
    from urllib.parse import urlparse
    _url = DATABASE_URL.replace('mysql+pymysql://', 'mysql://')
    parsed = urlparse(_url)
    DB_CONFIG = {
        'host': parsed.hostname,
        'user': parsed.username,
        'password': parsed.password,
        'database': parsed.path.lstrip('/'),
        'port': parsed.port or 3306,
        'cursorclass': pymysql.cursors.DictCursor,
        'ssl': {'ssl_disabled': False},
    }
else:
    DB_CONFIG = {
        'host': os.environ.get('DB_HOST', '127.0.0.1'),
        'user': os.environ.get('DB_USER', 'root'),
        'password': os.environ.get('DB_PASSWORD', ''),
        'database': os.environ.get('DB_NAME', 'sacco_db'),
        'port': int(os.environ.get('DB_PORT', 3306)),
        'cursorclass': pymysql.cursors.DictCursor,
    }

ROLE_SUPER_ADMIN = 'SUPER_ADMIN'


def main():
    conn = pymysql.connect(**DB_CONFIG)
    cursor = conn.cursor()

    print("[1/3] Adding admins.is_active column if missing...")
    try:
        cursor.execute("ALTER TABLE admins ADD COLUMN is_active TINYINT(1) DEFAULT 1")
        print("      Column added.")
    except Exception as e:
        if 'Duplicate column' in str(e):
            print("      Column already exists.")
        else:
            print(f"      Warning: {e}")

    print("[2/3] Creating admin_audit_log table if missing...")
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS admin_audit_log (
            id INT AUTO_INCREMENT PRIMARY KEY,
            admin_id INT NOT NULL,
            action VARCHAR(100) NOT NULL,
            target_type VARCHAR(50),
            target_id INT,
            details TEXT,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (admin_id) REFERENCES admins(id) ON DELETE CASCADE
        )
    """)
    print("      Done.")

    print("[3/3] Ensuring exactly one Super Admin exists...")
    cursor.execute("SELECT COUNT(*) as cnt FROM admins WHERE role = %s", (ROLE_SUPER_ADMIN,))
    super_count = cursor.fetchone()['cnt']

    if super_count == 0:
        cursor.execute("SELECT id, email FROM admins ORDER BY id ASC LIMIT 1")
        first = cursor.fetchone()
        if first:
            cursor.execute(
                "UPDATE admins SET role = %s WHERE id = %s",
                (ROLE_SUPER_ADMIN, first['id'])
            )
            print(f"      Promoted admin #{first['id']} ({first['email']}) to SUPER_ADMIN.")
        else:
            print("      No admins found. Run seed_admin.py or register via the admin web bootstrap.")
    elif super_count > 1:
        cursor.execute(
            "SELECT id, email FROM admins WHERE role = %s ORDER BY id ASC",
            (ROLE_SUPER_ADMIN,)
        )
        supers = cursor.fetchall()
        keep_id = supers[0]['id']
        for extra in supers[1:]:
            cursor.execute(
                "UPDATE admins SET role = 'ADMIN' WHERE id = %s",
                (extra['id'],)
            )
            print(f"      Demoted extra Super Admin #{extra['id']} ({extra['email']}) to ADMIN.")
        print(f"      Kept Super Admin #{keep_id}.")
    else:
        print("      Super Admin already configured.")

    conn.commit()
    conn.close()
    print("\nMigration complete.\n")


if __name__ == '__main__':
    main()
