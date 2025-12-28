@echo off
title Dual Reader 3.0 - Starting...
color 0A
echo.
echo ========================================
echo    Dual Reader 3.0 - Windows App
echo ========================================
echo.

REM Check Node.js
where node >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Node.js not found!
    echo Please install Node.js from https://nodejs.org/
    pause
    exit /b 1
)

REM Check if in correct directory
if not exist "package.json" (
    echo [ERROR] package.json not found!
    echo Please run this from the dual_reader_3.0 directory
    pause
    exit /b 1
)

REM Install dependencies if needed
if not exist "node_modules" (
    echo [1/3] Installing dependencies...
    call npm install
    if %ERRORLEVEL% NEQ 0 (
        echo [ERROR] Failed to install dependencies
        pause
        exit /b 1
    )
)

REM Start Metro bundler
echo [2/3] Starting Metro bundler...
start "Metro Bundler - Dual Reader" /MIN cmd /k "npm start"
timeout /t 8 /nobreak >nul

REM Start Electron app
echo [3/3] Launching app...
echo.
echo The app window should open shortly...
echo Metro bundler is running in a minimized window.
echo.
call npm run electron

REM Cleanup on exit
taskkill /FI "WINDOWTITLE eq Metro Bundler - Dual Reader*" /T /F >nul 2>&1

