-- ============================================================
--  Youth SACCO — Full Database Schema
--  Run this once against a fresh database.
--  All columns (including those added by migration scripts) are
--  included here so the cloud database needs no separate migrations.
-- ============================================================

-- Users table
CREATE TABLE IF NOT EXISTS users (
    id               INT AUTO_INCREMENT PRIMARY KEY,
    username         VARCHAR(150) UNIQUE NOT NULL,
    email            VARCHAR(255) UNIQUE NOT NULL,
    password         VARCHAR(255) NOT NULL,
    phone_number     VARCHAR(15) UNIQUE,
    full_name        VARCHAR(255),
    -- MFA / password-reset one-time codes
    mfa_code         VARCHAR(6),
    mfa_expires_at   DATETIME,
    reset_code       VARCHAR(6),
    reset_expires_at DATETIME,
    created_at       DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at       DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Accounts table (one per user)
CREATE TABLE IF NOT EXISTS accounts (
    id               INT AUTO_INCREMENT PRIMARY KEY,
    user_id          INT UNIQUE NOT NULL,
    balance          DECIMAL(12, 2) DEFAULT 0.00,
    savings_balance  DECIMAL(12, 2) DEFAULT 0.00,
    shares_balance   DECIMAL(12, 2) DEFAULT 0.00,
    created_at       DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at       DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Transactions table
CREATE TABLE IF NOT EXISTS transactions (
    id               INT AUTO_INCREMENT PRIMARY KEY,
    user_id          INT NOT NULL,
    amount           DECIMAL(12, 2) NOT NULL,
    transaction_type ENUM(
        'DEPOSIT', 'WITHDRAWAL', 'LOAN_DISBURSEMENT',
        'LOAN_REPAYMENT', 'TRANSFER', 'SHARE_PURCHASE', 'DIVIDEND_PAYOUT'
    ) NOT NULL,
    status           ENUM('PENDING', 'COMPLETED', 'FAILED') DEFAULT 'PENDING',
    reference_code   VARCHAR(50) UNIQUE,
    description      TEXT,
    created_at       DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Loans table
CREATE TABLE IF NOT EXISTS loans (
    id               INT AUTO_INCREMENT PRIMARY KEY,
    user_id          INT NOT NULL,
    amount           DECIMAL(12, 2) NOT NULL,
    interest_rate    DECIMAL(5, 2) DEFAULT 5.0,
    duration_months  INT DEFAULT 1,
    status           ENUM('PENDING', 'APPROVED', 'REJECTED', 'PAID') DEFAULT 'PENDING',
    reason           TEXT,
    applied_at       DATETIME DEFAULT CURRENT_TIMESTAMP,
    approved_at      DATETIME,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- System configuration (single row, id=1)
CREATE TABLE IF NOT EXISTS system_config (
    id               INT PRIMARY KEY DEFAULT 1,
    loan_interest_rate DECIMAL(5, 2)  DEFAULT 5.0,
    share_price      DECIMAL(10, 2)   DEFAULT 100.00,
    min_balance      DECIMAL(12, 2)   DEFAULT 5000.00,
    loan_multiplier  DECIMAL(5, 2)    DEFAULT 3.0,
    reg_fee          DECIMAL(10, 2)   DEFAULT 10000.00,
    max_withdraw     DECIMAL(12, 2)   DEFAULT 5000000.00,
    maintenance_mode TINYINT(1)       DEFAULT 0,
    allow_register   TINYINT(1)       DEFAULT 1,
    allow_loans      TINYINT(1)       DEFAULT 1,
    updated_at       DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Seed default system config
INSERT IGNORE INTO system_config (
    id, loan_interest_rate, share_price, min_balance,
    loan_multiplier, reg_fee, max_withdraw, maintenance_mode, allow_register, allow_loans
) VALUES (1, 5.0, 100.00, 5000.00, 3.0, 10000.00, 5000000.00, 0, 1, 1);

-- Admins table (separate from users)
CREATE TABLE IF NOT EXISTS admins (
    id               INT AUTO_INCREMENT PRIMARY KEY,
    username         VARCHAR(150) UNIQUE NOT NULL,
    email            VARCHAR(255) UNIQUE NOT NULL,
    password         VARCHAR(255) NOT NULL,
    phone_number     VARCHAR(15) UNIQUE,
    full_name        VARCHAR(255),
    role             VARCHAR(50) DEFAULT 'ADMIN',
    is_active        TINYINT(1)       DEFAULT 1,
    mfa_code         VARCHAR(6),
    mfa_expires_at   DATETIME,
    reset_code       VARCHAR(6),
    reset_expires_at DATETIME,
    created_at       DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at       DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Admin audit log (tracks Super Admin and admin actions)
CREATE TABLE IF NOT EXISTS admin_audit_log (
    id               INT AUTO_INCREMENT PRIMARY KEY,
    admin_id         INT NOT NULL,
    action           VARCHAR(100) NOT NULL,
    target_type      VARCHAR(50),
    target_id        INT,
    details          TEXT,
    created_at       DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (admin_id) REFERENCES admins(id) ON DELETE CASCADE
);

-- Notifications table
CREATE TABLE IF NOT EXISTS notifications (
    id         INT AUTO_INCREMENT PRIMARY KEY,
    user_id    INT NULL,
    title      VARCHAR(255) NOT NULL,
    message    TEXT NOT NULL,
    is_unread  BOOLEAN DEFAULT TRUE,
    is_admin   BOOLEAN DEFAULT FALSE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
