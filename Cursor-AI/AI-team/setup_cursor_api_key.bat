@echo off
REM Setup script for Cursor AI API Key
REM Run this script to set the API key for the current CMD session

set OPENAI_API_KEY=XXXX

echo ========================================
echo Cursor AI API Key Configured
echo ========================================
echo.
echo [OK] OPENAI_API_KEY set for current session
echo.
echo To make this permanent, add to system environment variables:
echo   setx OPENAI_API_KEY "XXXX"
echo.
echo Testing connection...
echo.

REM Test the connection
python -c "import os; from ai_client import create_ai_client; client = create_ai_client(); print('AI Client:', 'Available' if client and client.is_available() else 'Not Available'); print('Provider:', client.provider if client else 'None')"

echo.
echo You can now run the agent team:
echo   cd dual_reader_3.0
echo   python run_team.py
echo.
pause

