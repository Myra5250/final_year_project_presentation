import pymysql

# Database configuration
DB_CONFIG = {
    'host': '127.0.0.1',  # Use 127.0.0.1 for better compatibility
    'user': 'root',
    'password': '',
    'cursorclass': pymysql.cursors.DictCursor
}

def setup_database():
    conn = None
    try:
        # Connect without specifying database
        print("Connecting to MySQL server...")
        conn = pymysql.connect(**DB_CONFIG)
        cursor = conn.cursor()
        
        # Create database
        print("Creating database 'sacco_db' if not exists...")
        cursor.execute("CREATE DATABASE IF NOT EXISTS sacco_db")
        print("Database 'sacco_db' is ready.")
        
        # Use the database
        cursor.execute("USE sacco_db")
        
        # Read and execute schema
        print("Applying schema.sql...")
        with open('schema.sql', 'r') as f:
            schema = f.read()
            
        # Split by semicolon and execute each statement
        # We handle multi-line statements by joining them correctly
        statements = [s.strip() for s in schema.split(';') if s.strip()]
        for statement in statements:
            try:
                cursor.execute(statement)
            except Exception as e:
                print(f"Error executing statement: {statement[:50]}... \nError: {e}")
                raise
        
        conn.commit()
        print("Tables created successfully!")
        
        cursor.close()
        print("\n[SUCCESS] Database setup complete!")
        
    except Exception as e:
        print(f"\n[ERROR] Database setup failed: {e}")
    finally:
        if conn:
            conn.close()

if __name__ == '__main__':
    setup_database()

    