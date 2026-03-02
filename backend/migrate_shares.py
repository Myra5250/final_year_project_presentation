import pymysql
import os

def migrate():
    # Database connection details
    db_config = {
        'host': 'localhost',
        'user': 'root',
        'password': '',
        'database': 'sacco_db',
        'cursorclass': pymysql.cursors.DictCursor
    }

    try:
        conn = pymysql.connect(**db_config)
        cursor = conn.cursor()
        
        print("Migrating database...")
        
        # 1. Add shares_balance to accounts
        try:
            cursor.execute("ALTER TABLE accounts ADD COLUMN shares_balance DECIMAL(12, 2) DEFAULT 0.00 AFTER savings_balance")
            print("Added shares_balance column to accounts table.")
        except Exception as e:
            if "Duplicate column name" in str(e):
                print("shares_balance column already exists.")
            else:
                print(f"Error adding shares_balance: {e}")

        # 2. Update transactions ENUM
        try:
            # We need to re-define the column with the new enum values
            cursor.execute("""
                ALTER TABLE transactions MODIFY COLUMN transaction_type 
                ENUM('DEPOSIT', 'WITHDRAWAL', 'LOAN_DISBURSEMENT', 'LOAN_REPAYMENT', 'TRANSFER', 'SHARE_PURCHASE', 'DIVIDEND_PAYOUT') NOT NULL
            """)
            print("Updated transactions ENUM values.")
        except Exception as e:
            print(f"Error updating transactions ENUM: {e}")
            
        conn.commit()
        print("Migration completed successfully.")
        
    except Exception as e:
        print(f"Migration failed: {e}")
    finally:
        if 'conn' in locals():
            conn.close()

if __name__ == "__main__":
    migrate()
