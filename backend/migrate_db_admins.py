import pymysql
import bcrypt
from datetime import datetime

# Database connection details
DB_CONFIG = {
    'host': '127.0.0.1',
    'user': 'root',
    'password': '',
    'database': 'sacco_db',
    'cursorclass': pymysql.cursors.DictCursor
}

def migrate():
    try:
        conn = pymysql.connect(**DB_CONFIG)
        cursor = conn.cursor()
        print("Connected to database...")

        # 1. Check if we need to migrate (if admins table has 'user_id' column)
        cursor.execute("DESCRIBE admins")
        columns = cursor.fetchall()
        column_names = [col['Field'] for col in columns]

        if 'user_id' not in column_names:
            print("Database has already been migrated (no 'user_id' column in 'admins' table).")
            conn.close()
            return

        print("Starting admin table migration...")

        # 2. Extract existing admin users from users table
        cursor.execute("""
            SELECT u.*, COALESCE(a.role, 'ADMIN') as role
            FROM users u
            LEFT JOIN admins a ON u.id = a.user_id
            WHERE u.is_admin = TRUE
        """)
        admins_to_migrate = cursor.fetchall()
        print(f"Found {len(admins_to_migrate)} admin users to migrate.")

        # 3. Drop the old admins table
        print("Dropping old admins table...")
        cursor.execute("DROP TABLE IF EXISTS admins")

        # 4. Create the new standalone admins table
        print("Creating standalone admins table...")
        cursor.execute("""
            CREATE TABLE admins (
                id INT AUTO_INCREMENT PRIMARY KEY,
                username VARCHAR(150) UNIQUE NOT NULL,
                email VARCHAR(255) UNIQUE NOT NULL,
                password VARCHAR(255) NOT NULL,
                phone_number VARCHAR(15) UNIQUE,
                full_name VARCHAR(255),
                role VARCHAR(50) DEFAULT 'ADMIN',
                mfa_code VARCHAR(6),
                mfa_expires_at DATETIME,
                reset_code VARCHAR(6),
                reset_expires_at DATETIME,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
            )
        """)

        # 5. Insert migrated admins into the new table
        for admin in admins_to_migrate:
            print(f"Migrating admin: {admin['email']}...")
            cursor.execute("""
                INSERT INTO admins (
                    username, email, password, phone_number, full_name, role,
                    mfa_code, mfa_expires_at, reset_code, reset_expires_at, created_at
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            """, (
                admin['username'], admin['email'], admin['password'], admin['phone_number'],
                admin['full_name'], admin['role'], admin.get('mfa_code'), admin.get('mfa_expires_at'),
                admin.get('reset_code'), admin.get('reset_expires_at'), admin['created_at']
            ))

        # 6. Ensure there is at least one admin account (admin@sacco.ug)
        cursor.execute("SELECT COUNT(*) as count FROM admins")
        if cursor.fetchone()['count'] == 0:
            print("No admins found. Seeding default admin account (admin@sacco.ug)...")
            hashed_pwd = bcrypt.hashpw("password123".encode('utf-8'), bcrypt.gensalt()).decode('utf-8')
            cursor.execute("""
                INSERT INTO admins (username, email, password, phone_number, full_name, role)
                VALUES (%s, %s, %s, %s, %s, %s)
            """, ('admin', 'admin@sacco.ug', hashed_pwd, '0700000000', 'Sacco Admin', 'ADMIN'))

        # 7. Delete migrated admins from the users table (to enforce separation)
        for admin in admins_to_migrate:
            print(f"Removing admin {admin['email']} from users table...")
            cursor.execute("DELETE FROM users WHERE id = %s", (admin['id'],))

        # 8. Drop the is_admin column from the users table
        print("Dropping is_admin column from users table...")
        cursor.execute("ALTER TABLE users DROP COLUMN is_admin")

        conn.commit()
        print("Migration complete!")

    except Exception as e:
        print(f"Migration failed: {e}")
        if 'conn' in locals() and conn:
            conn.rollback()
    finally:
        if 'conn' in locals() and conn:
            conn.close()

if __name__ == '__main__':
    migrate()
