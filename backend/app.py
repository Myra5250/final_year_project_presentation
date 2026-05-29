from flask import Flask, request, jsonify
from flask_cors import CORS
import pymysql
import bcrypt
from datetime import datetime, date
import uuid
import json
from decimal import Decimal
import jwt
from functools import wraps
from datetime import datetime, timedelta
import random
import smtplib
from email.mime.text import MIMEText
import os

# Simple .env file loader
env_path = os.path.join(os.path.dirname(__file__), '.env')
if os.path.exists(env_path):
    with open(env_path, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith('#'):
                if '=' in line:
                    key, val = line.split('=', 1)
                    os.environ[key.strip()] = val.strip()

app = Flask(__name__)
CORS(app)

from flask.json.provider import DefaultJSONProvider
app.config['SECRET_KEY'] = 'supersecretkey123'

# Custom JSON Provider to handle Decimal and datetime objects from MySQL
class CustomJSONProvider(DefaultJSONProvider):
    def default(self, obj):
        if isinstance(obj, Decimal):
            return float(obj)
        if isinstance(obj, (datetime, date)):
            return obj.isoformat()
        return super().default(obj)

app.json = CustomJSONProvider(app)


# ===== DATABASE CONFIG =====
DB_CONFIG = {
    'host': '127.0.0.1',
    'user': 'root',
    'password': '',
    'database': 'sacco_db',
    'cursorclass': pymysql.cursors.DictCursor,
    'connect_timeout': 5
}

def get_db_connection():
    """Get a new DB connection"""
    return pymysql.connect(**DB_CONFIG)

def send_email(to_email, subject, body):
    """
    Utility function to send an email. 
    Uses SMTP configuration from environment variables if present, 
    otherwise falls back to printing to console.
    """
    smtp_server = os.environ.get('SMTP_SERVER', 'smtp.gmail.com')
    smtp_port_str = os.environ.get('SMTP_PORT', '587')
    try:
        smtp_port = int(smtp_port_str)
    except ValueError:
        smtp_port = 587
        
    smtp_user = os.environ.get('SMTP_USER')
    smtp_password = os.environ.get('SMTP_PASSWORD')
    smtp_from = os.environ.get('SMTP_FROM', smtp_user or 'noreply@youthsacco.com')

    print(f"\n--- EMAIL TO: {to_email} ---")
    print(f"Subject: {subject}")
    print(f"Body:\n{body}")
    print("---------------------------------\n")

    if smtp_user and smtp_password:
        try:
            msg = MIMEText(body)
            msg['Subject'] = subject
            msg['From'] = smtp_from
            msg['To'] = to_email
            
            with smtplib.SMTP(smtp_server, smtp_port) as server:
                server.starttls()
                server.login(smtp_user, smtp_password)
                server.send_message(msg)
            print(f"Email successfully sent to {to_email} via SMTP.")
        except Exception as e:
            print(f"Failed to send email to {to_email} via SMTP: {e}")
    else:
        print("SMTP credentials not configured (set SMTP_USER and SMTP_PASSWORD in .env). Printed to console only.")

def init_db():
    """Add missing columns to existing tables for extended configuration and create notifications table"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Create notifications table if not exists
        create_notifications_table = """
        CREATE TABLE IF NOT EXISTS notifications (
            id INT AUTO_INCREMENT PRIMARY KEY,
            user_id INT NULL,
            title VARCHAR(255) NOT NULL,
            message TEXT NOT NULL,
            is_unread BOOLEAN DEFAULT TRUE,
            is_admin BOOLEAN DEFAULT FALSE,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        )
        """
        try:
            cursor.execute(create_notifications_table)
        except Exception as e:
            print(f"[DB] Notifications table creation warning: {e}")

        migrations = [
            "ALTER TABLE system_config ADD COLUMN IF NOT EXISTS min_balance DECIMAL(12,2) DEFAULT 5000.00",
            "ALTER TABLE system_config ADD COLUMN IF NOT EXISTS loan_multiplier DECIMAL(5,2) DEFAULT 3.0",
            "ALTER TABLE system_config ADD COLUMN IF NOT EXISTS reg_fee DECIMAL(10,2) DEFAULT 10000.00",
            "ALTER TABLE system_config ADD COLUMN IF NOT EXISTS max_withdraw DECIMAL(12,2) DEFAULT 5000000.00",
            "ALTER TABLE system_config ADD COLUMN IF NOT EXISTS maintenance_mode TINYINT(1) DEFAULT 0",
            "ALTER TABLE system_config ADD COLUMN IF NOT EXISTS allow_register TINYINT(1) DEFAULT 1",
            "ALTER TABLE system_config ADD COLUMN IF NOT EXISTS allow_loans TINYINT(1) DEFAULT 1",
            "ALTER TABLE users ADD COLUMN IF NOT EXISTS mfa_code VARCHAR(6)",
            "ALTER TABLE users ADD COLUMN IF NOT EXISTS mfa_expires_at DATETIME",
            "ALTER TABLE users ADD COLUMN IF NOT EXISTS reset_code VARCHAR(6)",
            "ALTER TABLE users ADD COLUMN IF NOT EXISTS reset_expires_at DATETIME",
        ]
        for sql in migrations:
            try:
                cursor.execute(sql)
            except Exception:
                pass
        conn.commit()
        conn.close()
        print("[DB] Init completed.")
    except Exception as e:
        print(f"[DB] Init warning: {e}")

init_db()

def create_notification(user_id, title, message, is_admin=False, cursor=None):
    """Utility helper to create a database notification"""
    should_close = False
    conn = None
    if cursor is None:
        try:
            conn = get_db_connection()
            cursor = conn.cursor()
            should_close = True
        except Exception as e:
            print(f"[Notifications] DB connection error: {e}")
            return False
            
    try:
        cursor.execute("""
            INSERT INTO notifications (user_id, title, message, is_unread, is_admin, created_at)
            VALUES (%s, %s, %s, TRUE, %s, NOW())
        """, (user_id, title, message, is_admin))
        if should_close:
            conn.commit()
        return True
    except Exception as e:
        print(f"[Notifications] Error creating notification: {e}")
        if should_close and conn:
            conn.rollback()
        return False
    finally:
        if should_close and conn:
            conn.close()

def validate_json(data, required_fields):
    """Utility to validate JSON data and types"""
    if not data or not isinstance(data, dict):
        return False, "Invalid or missing JSON body"
    for field in required_fields:
        if field not in data:
            return False, f"Field '{field}' is required"
    return True, None

def generate_token(user_id):
    payload = {
        'user_id': user_id,
        'exp': datetime.utcnow() + timedelta(hours=24)
    }
    token = jwt.encode(payload, app.config['SECRET_KEY'], algorithm='HS256')
    return token

def token_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        token = None
        if 'Authorization' in request.headers:
            token = request.headers['Authorization'].split(" ")[1]

        if not token:
            return jsonify({'message': 'Token is missing'}), 401

        try:
            data = jwt.decode(token, app.config['SECRET_KEY'], algorithms=['HS256'])
            request.user_id = data['user_id']
        except:
            return jsonify({'message': 'Token is invalid'}), 401
        return f(*args, **kwargs)
    return decorated

def admin_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        token = None
        if 'Authorization' in request.headers:
            token = request.headers['Authorization'].split(" ")[1]

        if not token:
            return jsonify({'message': 'Token is missing'}), 401

        try:
            data = jwt.decode(token, app.config['SECRET_KEY'], algorithms=['HS256'])
            user_id = data['user_id']
            
            conn = get_db_connection()
            cursor = conn.cursor()
            cursor.execute("SELECT is_admin FROM users WHERE id = %s", (user_id,))
            user = cursor.fetchone()
            conn.close()
            
            if not user or not user['is_admin']:
                return jsonify({'message': 'Admin permission required'}), 403
                
            request.user_id = user_id
        except:
            return jsonify({'message': 'Token is invalid'}), 401

        return f(*args, **kwargs)

    return decorated

# ===== USER ROUTES =====
@app.route('/api/register', methods=['POST'])
def register():
    data = request.get_json()
    is_valid, error = validate_json(data, ['username', 'email', 'password', 'phone_number', 'full_name'])
    if not is_valid:
        return jsonify({'error': error}), 400
    
    phone = data.get('phone_number', '')
    if not phone.isdigit() or len(phone) != 10:
        return jsonify({'error': 'Phone number must be exactly 10 digits and contain only numbers'}), 400
    
    conn = None
    try:
        # Hash password
        password_bytes = str(data['password']).encode('utf-8')
        hashed_password = bcrypt.hashpw(password_bytes, bcrypt.gensalt()).decode('utf-8')
        
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Check existing user
        cursor.execute("SELECT id FROM users WHERE email=%s OR username=%s", 
                       (data['email'], data['username']))
        if cursor.fetchone():
            return jsonify({'error': 'Email or username already exists'}), 400
        
        # Insert user
        cursor.execute("""
            INSERT INTO users (username, email, password, phone_number, full_name, created_at)
            VALUES (%s, %s, %s, %s, %s, %s)
        """, (data['username'], data['email'], hashed_password, 
              data['phone_number'], data['full_name'], datetime.now()))
        
        user_id = int(cursor.lastrowid)
        
        # Create account
        cursor.execute("""
            INSERT INTO accounts (user_id, balance, savings_balance, created_at)
            VALUES (%s, 0.00, 0.00, %s)
        """, (user_id, datetime.now()))
        
        conn.commit()
        return jsonify({'message': 'User registered successfully', 'user_id': user_id}), 201

    except Exception as e:
        if conn: conn.rollback()
        return jsonify({'error': str(e)}), 500
    finally:
        if conn: conn.close()

@app.route('/api/admin/register', methods=['POST'])
def admin_register():
    data = request.get_json()
    required = ['username', 'email', 'password', 'phone_number', 'full_name']
    is_valid, error = validate_json(data, required)
    if not is_valid:
        return jsonify({'error': error}), 400
    
    phone = data.get('phone_number', '')
    if not phone.isdigit() or len(phone) != 10:
        return jsonify({'error': 'Phone number must be exactly 10 digits and contain only numbers'}), 400
    
    conn = None
    try:
        password_bytes = str(data['password']).encode('utf-8')
        hashed_password = bcrypt.hashpw(password_bytes, bcrypt.gensalt()).decode('utf-8')
        
        conn = get_db_connection()
        cursor = conn.cursor()
        
        cursor.execute("SELECT id FROM users WHERE email=%s OR username=%s", 
                       (data['email'], data['username']))
        if cursor.fetchone():
            return jsonify({'error': 'Email or username already exists'}), 400
        
        cursor.execute("""
            INSERT INTO users (username, email, password, phone_number, full_name, is_admin, created_at)
            VALUES (%s, %s, %s, %s, %s, TRUE, %s)
        """, (data['username'], data['email'], hashed_password, 
              data['phone_number'], data['full_name'], datetime.now()))
        
        user_id = int(cursor.lastrowid)
        
        cursor.execute("""
            INSERT INTO accounts (user_id, balance, savings_balance, created_at)
            VALUES (%s, 0.00, 0.00, %s)
        """, (user_id, datetime.now()))
        
        conn.commit()
        return jsonify({'message': 'Admin registered successfully', 'user_id': user_id}), 201

    except Exception as e:
        if conn: conn.rollback()
        return jsonify({'error': str(e)}), 500
    finally:
        if conn: conn.close()
    
@app.route('/api/login', methods=['POST'])
def login():
    data = request.json
    email = data['email']
    password = data['password']

    conn = get_db_connection()
    cursor = conn.cursor(pymysql.cursors.DictCursor)

    cursor.execute("SELECT * FROM users WHERE email=%s", (email,))
    user = cursor.fetchone()

    if not user:
        return jsonify({'message': 'User not found'}), 404

    if not bcrypt.checkpw(password.encode('utf-8'), user['password'].encode('utf-8')):
        return jsonify({'message': 'Invalid password'}), 401

    mfa_code = str(random.randint(100000, 999999))
    expires_at = datetime.now() + timedelta(minutes=10)
    
    cursor.execute("UPDATE users SET mfa_code=%s, mfa_expires_at=%s WHERE id=%s", (mfa_code, expires_at, user['id']))
    conn.commit()
    
    send_email(user['email'], "Your Login Code", f"Your verification code is: {mfa_code}\\nThis code expires in 10 minutes.")
    
    return jsonify({
        'message': 'MFA code sent',
        'requires_mfa': True,
        'email': user['email']
    }), 200

@app.route('/api/login/verify', methods=['POST'])
def verify_mfa():
    data = request.json
    email = data.get('email')
    code = data.get('code')
    
    conn = get_db_connection()
    cursor = conn.cursor(pymysql.cursors.DictCursor)
    
    cursor.execute("SELECT * FROM users WHERE email=%s", (email,))
    user = cursor.fetchone()
    
    if not user:
        return jsonify({'message': 'User not found'}), 404
        
    if user['mfa_code'] != code or not user['mfa_expires_at'] or user['mfa_expires_at'] < datetime.now():
        return jsonify({'message': 'Invalid or expired code'}), 401
        
    # Clear the code
    cursor.execute("UPDATE users SET mfa_code=NULL, mfa_expires_at=NULL WHERE id=%s", (user['id'],))
    conn.commit()
    
    token = generate_token(user['id'])
    
    return jsonify({
        'message': 'Login successful',
        'token': token,
        'user': {
            'id': user['id'],
            'username': user['username'],
            'email': user['email'],
            'is_admin': bool(user.get('is_admin', False))
        }
    }), 200

@app.route('/api/forgot-password', methods=['POST'])
def forgot_password():
    data = request.json
    email = data.get('email')
    
    conn = get_db_connection()
    cursor = conn.cursor(pymysql.cursors.DictCursor)
    
    cursor.execute("SELECT id, email FROM users WHERE email=%s", (email,))
    user = cursor.fetchone()
    
    if not user:
        return jsonify({'message': 'If the email exists, a reset code was sent.'}), 200
        
    reset_code = str(random.randint(100000, 999999))
    expires_at = datetime.now() + timedelta(minutes=15)
    
    cursor.execute("UPDATE users SET reset_code=%s, reset_expires_at=%s WHERE id=%s", (reset_code, expires_at, user['id']))
    conn.commit()
    
    send_email(user['email'], "Password Reset", f"Your password reset code is: {reset_code}\\nThis code expires in 15 minutes.")
    
    return jsonify({'message': 'If the email exists, a reset code was sent.', 'email': user['email']}), 200

@app.route('/api/reset-password', methods=['POST'])
def reset_password():
    data = request.json
    email = data.get('email')
    code = data.get('code')
    new_password = data.get('new_password')
    
    conn = get_db_connection()
    cursor = conn.cursor(pymysql.cursors.DictCursor)
    
    cursor.execute("SELECT * FROM users WHERE email=%s", (email,))
    user = cursor.fetchone()
    
    if not user:
        return jsonify({'message': 'User not found'}), 404
        
    if user['reset_code'] != code or not user['reset_expires_at'] or user['reset_expires_at'] < datetime.now():
        return jsonify({'message': 'Invalid or expired code'}), 401
        
    hashed_password = bcrypt.hashpw(new_password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')
    
    cursor.execute("UPDATE users SET password=%s, reset_code=NULL, reset_expires_at=NULL WHERE id=%s", (hashed_password, user['id']))
    conn.commit()
    
    return jsonify({'message': 'Password reset successfully'}), 200

@app.route('/api/users', methods=['GET'])
@token_required
def get_users():
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT id, username, email, full_name, phone_number FROM users")
        users = cursor.fetchall()
        return jsonify(users), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        if conn: conn.close()

# ===== ACCOUNT & TRANSACTION ROUTES =====
@app.route('/api/account/<int:user_id>', methods=['GET'])
@token_required
def get_account(user_id):
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            SELECT a.*, u.username, u.email, u.full_name 
            FROM accounts a
            JOIN users u ON a.user_id = u.id
            WHERE a.user_id=%s
        """, (user_id,))
        account = cursor.fetchone()
        if not account:
            return jsonify({'error': 'Account not found'}), 404
        return jsonify(account), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        if conn: conn.close()

@app.route('/api/transactions/<int:user_id>', methods=['GET'])
def get_transactions(user_id):
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM transactions WHERE user_id = %s ORDER BY created_at DESC", (user_id,))
        transactions = cursor.fetchall()
        return jsonify(transactions), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        if conn: conn.close()

@app.route('/api/transfer', methods=['POST'])
def transfer():
    data = request.get_json()
    is_valid, error = validate_json(data, ['sender_id', 'receiver_email', 'amount'])
    if not is_valid:
        return jsonify({'error': error}), 400
    
    amount = Decimal(str(data['amount']))
    if amount <= 0:
        return jsonify({'error': 'Amount must be greater than zero'}), 400

    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Get sender
        cursor.execute("SELECT u.full_name, u.username, a.balance FROM accounts a JOIN users u ON a.user_id = u.id WHERE a.user_id = %s", (data['sender_id'],))
        sender = cursor.fetchone()
        if not sender or Decimal(str(sender['balance'])) < amount:
            return jsonify({'error': 'Insufficient balance'}), 400
            
        # Get receiver
        cursor.execute("SELECT id FROM users WHERE email = %s", (data['receiver_email'],))
        receiver = cursor.fetchone()
        if not receiver:
            return jsonify({'error': 'Receiver not found'}), 404
            
        receiver_id = receiver['id']
        if receiver_id == int(data['sender_id']):
            return jsonify({'error': 'Cannot transfer to yourself'}), 400
        
        ref = f"TRF-{uuid.uuid4().hex[:8].upper()}"
        
        # Atomic transfer
        cursor.execute("UPDATE accounts SET balance = balance - %s WHERE user_id = %s", (amount, data['sender_id']))
        cursor.execute("""
            INSERT INTO transactions (user_id, amount, transaction_type, status, reference_code, description)
            VALUES (%s, %s, 'TRANSFER', 'COMPLETED', %s, %s)
        """, (data['sender_id'], amount, ref, f"Transfer to {data['receiver_email']}"))
        
        cursor.execute("UPDATE accounts SET balance = balance + %s WHERE user_id = %s", (amount, receiver_id))
        cursor.execute("""
            INSERT INTO transactions (user_id, amount, transaction_type, status, reference_code, description)
            VALUES (%s, %s, 'TRANSFER', 'COMPLETED', %s, %s)
        """, (receiver_id, amount, ref, f"Transfer from user #{data['sender_id']}"))
        
        # Create notification for sender
        create_notification(
            user_id=data['sender_id'],
            title="Transfer Successful",
            message=f"You have successfully transferred UGX {int(amount):,} to {data['receiver_email']}. Reference: {ref}.",
            is_admin=False,
            cursor=cursor
        )
        
        # Create notification for receiver
        sender_name = sender['full_name'] or sender['username']
        create_notification(
            user_id=receiver_id,
            title="Funds Received",
            message=f"You have received UGX {int(amount):,} from {sender_name}. Reference: {ref}.",
            is_admin=False,
            cursor=cursor
        )
        
        conn.commit()
        return jsonify({'message': 'Transfer successful', 'reference': ref}), 200
    except Exception as e:
        if conn: conn.rollback()
        return jsonify({'error': str(e)}), 500
    finally:
        if conn: conn.close()

@app.route('/api/deposit', methods=['POST'])
@token_required
def deposit():
    data = request.get_json()
    is_valid, error = validate_json(data, ['user_id', 'amount'])
    if not is_valid:
        return jsonify({'error': error}), 400
        
    try:
        amount = Decimal(str(data['amount']))
        if amount <= 0:
            return jsonify({'error': 'Amount must be greater than zero'}), 400
    except Exception:
        return jsonify({'error': 'Invalid amount format'}), 400

    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Check user
        cursor.execute("SELECT id FROM users WHERE id = %s", (data['user_id'],))
        if not cursor.fetchone():
            return jsonify({'error': 'User not found'}), 404
            
        ref = f"DEP-{uuid.uuid4().hex[:8].upper()}"
        
        # Update balance
        cursor.execute("UPDATE accounts SET balance = balance + %s, savings_balance = savings_balance + %s WHERE user_id = %s", (amount, amount, data['user_id']))
        
        # Record transaction
        cursor.execute("""
            INSERT INTO transactions (user_id, amount, transaction_type, status, reference_code, description)
            VALUES (%s, %s, 'DEPOSIT', 'COMPLETED', %s, 'Cash Deposit')
        """, (data['user_id'], amount, ref))
        
        # Create user notification
        create_notification(
            user_id=data['user_id'],
            title="Deposit Received",
            message=f"You have successfully deposited UGX {int(amount):,} to your savings account. Reference: {ref}.",
            is_admin=False,
            cursor=cursor
        )
        
        conn.commit()
        return jsonify({'message': 'Deposit successful', 'reference': ref}), 200
    except Exception as e:
        if conn: conn.rollback()
        return jsonify({'error': str(e)}), 500
    finally:
        if conn: conn.close()

@app.route('/api/withdraw', methods=['POST'])
@token_required
def withdraw():
    data = request.get_json()
    is_valid, error = validate_json(data, ['user_id', 'amount'])
    if not is_valid:
        return jsonify({'error': error}), 400
        
    try:
        amount = Decimal(str(data['amount']))
        if amount <= 0:
            return jsonify({'error': 'Amount must be greater than zero'}), 400
    except Exception:
        return jsonify({'error': 'Invalid amount format'}), 400

    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Check balance
        cursor.execute("SELECT balance FROM accounts WHERE user_id = %s", (data['user_id'],))
        row = cursor.fetchone()
        if not row:
            return jsonify({'error': 'Account not found'}), 404
        
        current_balance = Decimal(str(row['balance']))
        if current_balance < amount:
            return jsonify({'error': 'Insufficient balance'}), 400
            
        ref = f"WDL-{uuid.uuid4().hex[:8].upper()}"
        
        # Update balance
        cursor.execute("UPDATE accounts SET balance = balance - %s WHERE user_id = %s", (amount, data['user_id']))
        
        # Record transaction
        cursor.execute("""
            INSERT INTO transactions (user_id, amount, transaction_type, status, reference_code, description)
            VALUES (%s, %s, 'WITHDRAWAL', 'COMPLETED', %s, 'Cash Withdrawal')
        """, (data['user_id'], amount, ref))
        
        # Create user notification
        create_notification(
            user_id=data['user_id'],
            title="Withdrawal Successful",
            message=f"You have successfully withdrawn UGX {int(amount):,} from your account. Reference: {ref}.",
            is_admin=False,
            cursor=cursor
        )
        
        conn.commit()
        return jsonify({'message': 'Withdrawal successful', 'reference': ref}), 200
    except Exception as e:
        if conn: conn.rollback()
        return jsonify({'error': str(e)}), 500
    finally:
        if conn: conn.close()

# ===== LOAN ROUTES =====
@app.route('/api/loans/<int:user_id>', methods=['GET'])
def get_loans(user_id):
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM loans WHERE user_id = %s ORDER BY applied_at DESC", (user_id,))
        loans = cursor.fetchall()
        return jsonify(loans), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        if conn: conn.close()

@app.route('/api/loans/apply', methods=['POST'])
def apply_loan():
    data = request.get_json()
    required = ['user_id', 'amount', 'duration_months', 'reason']
    is_valid, error = validate_json(data, required)
    if not is_valid:
        return jsonify({'error': error}), 400
        
    try:
        amount = Decimal(str(data['amount']))
        if amount <= 0:
            return jsonify({'error': 'Loan amount must be greater than zero'}), 400
    except Exception:
        return jsonify({'error': 'Invalid amount format'}), 400

    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Check if user exists
        cursor.execute("SELECT id, username, full_name FROM users WHERE id = %s", (data['user_id'],))
        user = cursor.fetchone()
        if not user:
            return jsonify({'error': 'User not found'}), 404

        # Check if user has pending loans
        cursor.execute("SELECT id FROM loans WHERE user_id = %s AND status = 'PENDING'", (data['user_id'],))
        if cursor.fetchone():
            return jsonify({'error': 'You already have a pending loan application'}), 400
            
        # Insert loan
        cursor.execute("""
            INSERT INTO loans (user_id, amount, duration_months, reason, status, applied_at)
            VALUES (%s, %s, %s, %s, 'PENDING', %s)
        """, (data['user_id'], amount, data['duration_months'], data['reason'], datetime.now()))
        
        # Create notifications
        user_display_name = user['full_name'] or user['username']
        create_notification(
            user_id=data['user_id'],
            title="Loan Under Consideration",
            message=f"Your loan application for UGX {int(amount):,} has been received and is under consideration.",
            is_admin=False,
            cursor=cursor
        )
        create_notification(
            user_id=None,
            title="New Loan Application",
            message=f"Member {user_display_name} has applied for a loan of UGX {int(amount):,}.",
            is_admin=True,
            cursor=cursor
        )
        
        conn.commit()
        return jsonify({'message': 'Loan application submitted successfully'}), 201
    except Exception as e:
        if conn: conn.rollback()
        return jsonify({'error': str(e)}), 500
    finally:
        if conn: conn.close()

@app.route('/api/loans/repay', methods=['POST'])
def repay_loan():
    data = request.get_json()
    is_valid, error = validate_json(data, ['user_id', 'loan_id', 'amount'])
    if not is_valid:
        return jsonify({'error': error}), 400
        
    try:
        amount = Decimal(str(data['amount']))
        if amount <= 0:
            return jsonify({'error': 'Repayment amount must be positive'}), 400
    except Exception:
        return jsonify({'error': 'Invalid amount format'}), 400

    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Check loan
        cursor.execute("SELECT * FROM loans WHERE id = %s AND user_id = %s", (data['loan_id'], data['user_id']))
        loan = cursor.fetchone()
        if not loan:
            return jsonify({'error': 'Loan not found'}), 404
        if loan['status'] == 'PAID':
            return jsonify({'error': 'Loan is already fully paid'}), 400
            
        # Check balance
        cursor.execute("SELECT balance FROM accounts WHERE user_id = %s", (data['user_id'],))
        account = cursor.fetchone()
        if not account or Decimal(str(account['balance'])) < amount:
            return jsonify({'error': 'Insufficient balance to repay loan'}), 400
            
        ref = f"LRP-{uuid.uuid4().hex[:8].upper()}"
        
        # Deduct from balance
        cursor.execute("UPDATE accounts SET balance = balance - %s WHERE user_id = %s", (amount, data['user_id']))
        
        # Record transaction
        cursor.execute("""
            INSERT INTO transactions (user_id, amount, transaction_type, status, reference_code, description)
            VALUES (%s, %s, 'LOAN_REPAYMENT', 'COMPLETED', %s, %s)
        """, (data['user_id'], amount, ref, f"Repayment for Loan #{data['loan_id']}"))
        
        # Update loan status (simplified: mark as PAID if repaying full amount or more)
        if amount >= Decimal(str(loan['amount'])):
            cursor.execute("UPDATE loans SET status = 'PAID' WHERE id = %s", (data['loan_id'],))
        
        conn.commit()
        return jsonify({'message': 'Loan repayment successful', 'reference': ref}), 200
    except Exception as e:
        if conn: conn.rollback()
        return jsonify({'error': str(e)}), 500
    finally:
        if conn: conn.close()

@app.route('/api/shares/buy', methods=['POST'])
@token_required
def buy_shares():
    data = request.get_json()
    is_valid, error = validate_json(data, ['user_id', 'amount'])
    if not is_valid:
        return jsonify({'error': error}), 400
        
    try:
        amount = Decimal(str(data['amount']))
        if amount <= 0:
            return jsonify({'error': 'Amount must be greater than zero'}), 400
    except Exception:
        return jsonify({'error': 'Invalid amount format'}), 400

    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Check cash balance
        cursor.execute("SELECT balance FROM accounts WHERE user_id = %s", (data['user_id'],))
        row = cursor.fetchone()
        if not row:
            return jsonify({'error': 'Account not found'}), 404
        
        current_balance = Decimal(str(row['balance']))
        if current_balance < amount:
            return jsonify({'error': 'Insufficient cash balance to purchase shares'}), 400
            
        ref = f"SHR-{uuid.uuid4().hex[:8].upper()}"
        
        # 1. Deduct from cash balance
        cursor.execute("UPDATE accounts SET balance = balance - %s WHERE user_id = %s", (amount, data['user_id']))
        # 2. Add to shares balance
        cursor.execute("UPDATE accounts SET shares_balance = shares_balance + %s WHERE user_id = %s", (amount, data['user_id']))
        
        # Get share price
        cursor.execute("SELECT share_price FROM system_config WHERE id = 1")
        config_row = cursor.fetchone()
        share_price = Decimal(str(config_row['share_price'] if config_row else 100.00))
        shares_count = amount / share_price
        
        # Record transaction
        cursor.execute("""
            INSERT INTO transactions (user_id, amount, transaction_type, status, reference_code, description)
            VALUES (%s, %s, 'SHARE_PURCHASE', 'COMPLETED', %s, %s)
        """, (data['user_id'], amount, ref, f"Purchased {int(shares_count)} Shares"))
        
        # Create user notification
        create_notification(
            user_id=data['user_id'],
            title="Shares Purchased",
            message=f"You have successfully purchased {int(shares_count)} shares worth UGX {int(amount):,}. Reference: {ref}.",
            is_admin=False,
            cursor=cursor
        )
        
        conn.commit()
        return jsonify({'message': 'Shares purchased successfully', 'reference': ref}), 200
    except Exception as e:
        if conn: conn.rollback()
        return jsonify({'error': str(e)}), 500
    finally:
        if conn: conn.close()

@app.route('/api/user/summary/<int:user_id>', methods=['GET'])
def get_user_summary(user_id):
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Account info
        cursor.execute("""
            SELECT u.username, u.full_name, a.balance, a.savings_balance, a.shares_balance 
            FROM users u JOIN accounts a ON u.id = a.user_id WHERE u.id = %s
        """, (user_id,))
        user_data = cursor.fetchone()
        if not user_data:
            return jsonify({'error': 'User not found'}), 404
            
        # Recent transactions
        cursor.execute("SELECT * FROM transactions WHERE user_id = %s ORDER BY created_at DESC LIMIT 5", (user_id,))
        recent = cursor.fetchall()
        
        return jsonify({
            'user': user_data,
            'recent_transactions': recent
        }), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        if conn: conn.close()

# ===== ADMIN ROUTES =====
@app.route('/api/admin/stats', methods=['GET'])
@admin_required
def get_admin_stats():
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Total Users
        cursor.execute("SELECT COUNT(*) as total FROM users")
        total_users = cursor.fetchone()['total']
        
        # Total Savings
        cursor.execute("SELECT SUM(savings_balance) as total FROM accounts")
        total_savings = cursor.fetchone()['total'] or 0
        
        # Total Shares
        cursor.execute("SELECT SUM(shares_balance) as total FROM accounts")
        total_shares = cursor.fetchone()['total'] or 0
        
        # Pending Loans
        cursor.execute("SELECT COUNT(*) as total FROM loans WHERE status = 'PENDING'")
        pending_loans = cursor.fetchone()['total']
        
        # Total Disbursed (Simplified)
        cursor.execute("SELECT SUM(amount) as total FROM loans WHERE status = 'APPROVED'")
        total_disbursed = cursor.fetchone()['total'] or 0
        
        return jsonify({
            'total_users': total_users,
            'total_savings': float(total_savings),
            'total_shares': float(total_shares),
            'pending_loans': pending_loans,
            'total_disbursed': float(total_disbursed)
        }), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        if conn: conn.close()

@app.route('/api/admin/users', methods=['GET'])
@admin_required
def admin_get_users():
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            SELECT u.id, u.username, u.email, u.full_name, u.phone_number, u.created_at,
                   a.balance, a.savings_balance, a.shares_balance
            FROM users u
            JOIN accounts a ON u.id = a.user_id
        """)
        users = cursor.fetchall()
        return jsonify(users), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        if conn: conn.close()

@app.route('/api/admin/loans', methods=['GET'])
@admin_required
def admin_get_loans():
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            SELECT l.*, u.username, u.full_name 
            FROM loans l 
            JOIN users u ON l.user_id = u.id 
            ORDER BY l.applied_at DESC
        """)
        loans = cursor.fetchall()
        return jsonify(loans), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        if conn: conn.close()

@app.route('/api/admin/loans/action', methods=['POST'])
@admin_required
def admin_loan_action():
    data = request.json
    loan_id = data.get('loan_id')
    action = data.get('action') # 'APPROVED' or 'REJECTED'
    
    if action not in ['APPROVED', 'REJECTED']:
        return jsonify({'error': 'Invalid action'}), 400
        
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Get loan details
        cursor.execute("SELECT * FROM loans WHERE id = %s", (loan_id,))
        loan = cursor.fetchone()
        if not loan:
            return jsonify({'error': 'Loan not found'}), 404
            
        if loan['status'] != 'PENDING':
            return jsonify({'error': 'Loan already processed'}), 400
            
        # Update loan status
        cursor.execute("UPDATE loans SET status = %s, approved_at = %s WHERE id = %s", 
                       (action, datetime.now() if action == 'APPROVED' else None, loan_id))
        
        amount = loan['amount']
        user_id = loan['user_id']

        # If approved, disburse funds
        if action == 'APPROVED':
            ref = f"LDS-{uuid.uuid4().hex[:8].upper()}"
            
            # Add to balance
            cursor.execute("UPDATE accounts SET balance = balance + %s WHERE user_id = %s", (amount, user_id))
            
            # Record transaction
            cursor.execute("""
                INSERT INTO transactions (user_id, amount, transaction_type, status, reference_code, description)
                VALUES (%s, %s, 'LOAN_DISBURSEMENT', 'COMPLETED', %s, %s)
            """, (user_id, amount, ref, f"Disbursement for Loan #{loan_id}"))

        # Create user notification
        if action == 'APPROVED':
            create_notification(
                user_id=user_id,
                title="Loan Approved! 🎉",
                message=f"Congratulations! Your loan application for UGX {int(amount):,} has been APPROVED and the funds have been credited to your account.",
                is_admin=False,
                cursor=cursor
            )
        else:
            create_notification(
                user_id=user_id,
                title="Loan Application Rejected",
                message=f"We regret to inform you that your loan application for UGX {int(amount):,} has been rejected.",
                is_admin=False,
                cursor=cursor
            )
            
        conn.commit()
        return jsonify({'message': f'Loan {action.lower()} successfully'}), 200
    except Exception as e:
        if conn: conn.rollback()
        return jsonify({'error': str(e)}), 500
    finally:
        if conn: conn.close()

@app.route('/api/admin/config', methods=['GET', 'POST'])
@admin_required
def admin_config():
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        if request.method == 'POST':
            data = request.json
            field_map = {
                'interest_rate': 'loan_interest_rate',
                'share_price': 'share_price',
                'min_balance': 'min_balance',
                'loan_multiplier': 'loan_multiplier',
                'reg_fee': 'reg_fee',
                'max_withdraw': 'max_withdraw',
                'maintenance_mode': 'maintenance_mode',
                'allow_register': 'allow_register',
                'allow_loans': 'allow_loans',
            }
            updates = []
            values = []
            for key, col in field_map.items():
                if key in data and data[key] is not None:
                    updates.append(f"{col} = %s")
                    values.append(data[key])
            if updates:
                cursor.execute(f"UPDATE system_config SET {', '.join(updates)} WHERE id = 1", values)
                conn.commit()
            return jsonify({'message': 'Configuration updated successfully'}), 200
            
        cursor.execute("SELECT * FROM system_config WHERE id = 1")
        config = cursor.fetchone()
        return jsonify(config), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        if conn: conn.close()


@app.route('/api/config', methods=['GET'])
def public_config():
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            SELECT loan_interest_rate, share_price, min_balance, loan_multiplier, 
                   reg_fee, max_withdraw, maintenance_mode, allow_register, allow_loans 
            FROM system_config WHERE id = 1
        """)
        config = cursor.fetchone()
        if not config:
            return jsonify({
                'loan_interest_rate': 5.0,
                'share_price': 100.0,
                'min_balance': 5000.0,
                'loan_multiplier': 3.0,
                'reg_fee': 10000.0,
                'max_withdraw': 5000000.0,
                'maintenance_mode': 0,
                'allow_register': 1,
                'allow_loans': 1
            }), 200
        return jsonify(config), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        if conn: conn.close()


@app.route('/api/admin/admins', methods=['GET'])
@admin_required
def get_admin_users():
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            SELECT id, username, email, full_name, phone_number, created_at
            FROM users WHERE is_admin = TRUE ORDER BY created_at DESC
        """)
        admins = cursor.fetchall()
        return jsonify(admins), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        if conn: conn.close()


@app.route('/api/admin/profile', methods=['GET', 'PUT'])
@admin_required
def admin_profile():
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        if request.method == 'GET':
            cursor.execute(
                "SELECT id, username, email, full_name, phone_number, created_at FROM users WHERE id = %s",
                (request.user_id,)
            )
            user = cursor.fetchone()
            if not user:
                return jsonify({'error': 'User not found'}), 404
            return jsonify(user), 200
        
        # PUT - update profile
        data = request.json
        updates = []
        values = []
        
        if data.get('full_name'):
            updates.append("full_name = %s")
            values.append(data['full_name'])
        if data.get('username'):
            updates.append("username = %s")
            values.append(data['username'])
        if data.get('email'):
            updates.append("email = %s")
            values.append(data['email'])
        if data.get('phone_number'):
            phone = data['phone_number']
            if not phone.isdigit() or len(phone) != 10:
                return jsonify({'error': 'Phone number must be exactly 10 digits and contain only numbers'}), 400
            updates.append("phone_number = %s")
            values.append(phone)
        
        # Password change
        if data.get('new_password'):
            if not data.get('current_password'):
                return jsonify({'error': 'Current password is required'}), 400
            cursor.execute("SELECT password FROM users WHERE id = %s", (request.user_id,))
            user = cursor.fetchone()
            if not user or not bcrypt.checkpw(data['current_password'].encode('utf-8'), user['password'].encode('utf-8')):
                return jsonify({'error': 'Current password is incorrect'}), 401
            hashed = bcrypt.hashpw(data['new_password'].encode('utf-8'), bcrypt.gensalt()).decode('utf-8')
            updates.append("password = %s")
            values.append(hashed)
        
        if updates:
            values.append(request.user_id)
            cursor.execute(f"UPDATE users SET {', '.join(updates)}, updated_at = NOW() WHERE id = %s", values)
            conn.commit()
        
        return jsonify({'message': 'Profile updated successfully'}), 200
    except Exception as e:
        if conn: conn.rollback()
        return jsonify({'error': str(e)}), 500
    finally:
        if conn: conn.close()


@app.route('/api/admin/transactions', methods=['GET'])
@admin_required
def admin_get_transactions():
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            SELECT t.*, u.username 
            FROM transactions t 
            JOIN users u ON t.user_id = u.id 
            ORDER BY t.created_at DESC
        """)
        transactions = cursor.fetchall()
        return jsonify(transactions), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        if conn: conn.close()


# ===== NOTIFICATION ROUTES =====
@app.route('/api/notifications', methods=['GET'])
@token_required
def get_user_notifications():
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            SELECT * FROM notifications 
            WHERE user_id = %s AND is_admin = FALSE 
            ORDER BY created_at DESC
        """, (request.user_id,))
        notifications = cursor.fetchall()
        return jsonify(notifications), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        if conn: conn.close()

@app.route('/api/notifications/<int:notif_id>/read', methods=['PUT'])
@token_required
def mark_user_notification_read(notif_id):
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            UPDATE notifications 
            SET is_unread = FALSE 
            WHERE id = %s AND user_id = %s AND is_admin = FALSE
        """, (notif_id, request.user_id))
        conn.commit()
        return jsonify({'message': 'Notification marked as read'}), 200
    except Exception as e:
        if conn: conn.rollback()
        return jsonify({'error': str(e)}), 500
    finally:
        if conn: conn.close()

@app.route('/api/notifications/read-all', methods=['PUT'])
@token_required
def mark_all_user_notifications_read():
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            UPDATE notifications 
            SET is_unread = FALSE 
            WHERE user_id = %s AND is_admin = FALSE
        """, (request.user_id,))
        conn.commit()
        return jsonify({'message': 'All notifications marked as read'}), 200
    except Exception as e:
        if conn: conn.rollback()
        return jsonify({'error': str(e)}), 500
    finally:
        if conn: conn.close()

@app.route('/api/admin/notifications', methods=['GET'])
@admin_required
def get_admin_notifications():
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            SELECT * FROM notifications 
            WHERE is_admin = TRUE 
            ORDER BY created_at DESC
        """)
        notifications = cursor.fetchall()
        return jsonify(notifications), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        if conn: conn.close()

@app.route('/api/admin/notifications/<int:notif_id>/read', methods=['PUT'])
@admin_required
def mark_admin_notification_read(notif_id):
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            UPDATE notifications 
            SET is_unread = FALSE 
            WHERE id = %s AND is_admin = TRUE
        """, (notif_id,))
        conn.commit()
        return jsonify({'message': 'Admin notification marked as read'}), 200
    except Exception as e:
        if conn: conn.rollback()
        return jsonify({'error': str(e)}), 500
    finally:
        if conn: conn.close()

@app.route('/api/admin/notifications/read-all', methods=['PUT'])
@admin_required
def mark_all_admin_notifications_read():
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            UPDATE notifications 
            SET is_unread = FALSE 
            WHERE is_admin = TRUE
        """)
        conn.commit()
        return jsonify({'message': 'All admin notifications marked as read'}), 200
    except Exception as e:
        if conn: conn.rollback()
        return jsonify({'error': str(e)}), 500
    finally:
        if conn: conn.close()


# ===== HEALTH CHECK =====
@app.route('/api/health', methods=['GET'])
def health_check():
    return jsonify({'status': 'ok', 'message': 'API is running'}), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8000, debug=True)
