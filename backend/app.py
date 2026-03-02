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
        cursor.execute("SELECT balance FROM accounts WHERE user_id = %s", (data['sender_id'],))
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
        cursor.execute("UPDATE accounts SET balance = balance + %s WHERE user_id = %s", (amount, data['user_id']))
        
        # Record transaction
        cursor.execute("""
            INSERT INTO transactions (user_id, amount, transaction_type, status, reference_code, description)
            VALUES (%s, %s, 'DEPOSIT', 'COMPLETED', %s, 'Cash Deposit')
        """, (data['user_id'], amount, ref))
        
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
        cursor.execute("SELECT id FROM users WHERE id = %s", (data['user_id'],))
        if not cursor.fetchone():
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
        
        # Record transaction
        cursor.execute("""
            INSERT INTO transactions (user_id, amount, transaction_type, status, reference_code, description)
            VALUES (%s, %s, 'SHARE_PURCHASE', 'COMPLETED', %s, 'Share Subscription')
        """, (data['user_id'], amount, ref))
        
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
        
        # If approved, disburse funds
        if action == 'APPROVED':
            amount = loan['amount']
            user_id = loan['user_id']
            ref = f"LDS-{uuid.uuid4().hex[:8].upper()}"
            
            # Add to balance
            cursor.execute("UPDATE accounts SET balance = balance + %s WHERE user_id = %s", (amount, user_id))
            
            # Record transaction
            cursor.execute("""
                INSERT INTO transactions (user_id, amount, transaction_type, status, reference_code, description)
                VALUES (%s, %s, 'LOAN_DISBURSEMENT', 'COMPLETED', %s, %s)
            """, (user_id, amount, ref, f"Disbursement for Loan #{loan_id}"))
            
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
            cursor.execute("""
                UPDATE system_config 
                SET loan_interest_rate = %s, share_price = %s 
                WHERE id = 1
            """, (data.get('interest_rate'), data.get('share_price')))
            conn.commit()
            return jsonify({'message': 'Configuration updated successfully'}), 200
            
        cursor.execute("SELECT * FROM system_config WHERE id = 1")
        config = cursor.fetchone()
        return jsonify(config), 200
    except Exception as e:
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

# ===== HEALTH CHECK =====
@app.route('/api/health', methods=['GET'])
def health_check():
    return jsonify({'status': 'ok', 'message': 'API is running'}), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8000, debug=True)
