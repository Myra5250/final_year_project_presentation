@echo off
echo ============================================
echo  SACCO Backend Setup and Run Script
echo ============================================
echo.

REM --- Check Python ---
python --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Python is not installed or not in PATH.
    echo Please install Python from https://www.python.org/downloads/
    echo Make sure to check "Add Python to PATH" during installation.
    pause
    exit /b 1
)
echo [OK] Python found:
python --version

REM --- Install dependencies ---
echo.
echo [*] Installing Python dependencies...
pip install -r requirements.txt
if errorlevel 1 (
    echo [ERROR] Failed to install dependencies.
    pause
    exit /b 1
)
echo [OK] Dependencies installed.

REM --- Check MySQL ---
echo.
echo [*] Checking MySQL connection...
mysql -u root -e "SELECT 1;" >nul 2>&1
if errorlevel 1 (
    echo [WARNING] MySQL CLI not found or MySQL is not running.
    echo.
    echo  Please ensure MySQL is running. Options:
    echo   - If using XAMPP: Open XAMPP Control Panel and start MySQL
    echo   - If using MySQL Server: Start the MySQL service from Services
    echo.
    echo  Once MySQL is running, press any key to continue...
    pause
) else (
    echo [OK] MySQL is running.

    REM --- Create database and tables ---
    echo.
    echo [*] Setting up database...
    mysql -u root -e "CREATE DATABASE IF NOT EXISTS sacco_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    mysql -u root sacco_db < schema.sql
    echo [OK] Database ready.
)

REM --- Start Flask server ---
echo.
echo ============================================
echo  Starting Flask backend on port 8000...
echo  Admin dashboard: http://127.0.0.1:8000/admin/
echo  API health:      http://127.0.0.1:8000/health
echo  Press Ctrl+C to stop the server.
echo ============================================
echo.
echo  MFA login codes will appear here in the console
echo  (since SMTP is not configured by default).
echo.
python app.py
