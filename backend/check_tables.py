import pymysql

DB_CONFIG = {
    'host': '127.0.0.1',
    'user': 'root',
    'password': '',
    'database': 'sacco_db',
    'cursorclass': pymysql.cursors.DictCursor
}

try:
    conn = pymysql.connect(**DB_CONFIG)
    cursor = conn.cursor()
    cursor.execute("SHOW TABLES")
    tables = cursor.fetchall()
    print("Tables in sacco_db:")
    for table in tables:
        print(table)
    cursor.close()
    conn.close()
except Exception as e:
    print(f"Error: {e}")
