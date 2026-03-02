import sys
import traceback
import pymysql

print("Script started")

try:
    print("Connecting to MySQL...")
    config = {
        'user': 'root',
        'password': '',
        'host': '127.0.0.1',
        'port': 3306
    }
    
    conn = pymysql.connect(**config)
    print("Connected successfully!")
    
    cursor = conn.cursor()
    cursor.execute("CREATE DATABASE IF NOT EXISTS sacco_db")
    print("Database 'sacco_db' created or already exists.")
    
    cursor.close()
    conn.close()
    print("Connection closed.")
except Exception:
    traceback.print_exc()
    sys.exit(1)
