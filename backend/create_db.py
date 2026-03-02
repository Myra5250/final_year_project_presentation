import pymysql

try:
    print("Connecting to MySQL...")
    # Standard configuration for XAMPP/WAMP
    config = {
        'user': 'root',
        'password': '',
        'host': 'localhost',
    }
    
    mydb = pymysql.connect(**config)
    cursor = mydb.cursor()
    print("Creating database sacco_db if not exists...")
    cursor.execute("CREATE DATABASE IF NOT EXISTS sacco_db")
    print("Database check completed.")
    mydb.close()
except Exception as e:
    print(f"Error connecting to MySQL: {e}")
    print("Please ensure XAMPP MySQL is running.")

