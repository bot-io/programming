@echo off
REM =====================================================================
REM Delete Confluence Pages Tool (Windows .bat)
REM This batch file runs the delete_pages.py script to delete pages listed in a JSON file
REM Requirements: Python 3.x in PATH
REM Token: read from environment variable CONFLUENCE_API_TOKEN
REM   To set it permanently (replace YOUR_NEW_TOKEN):
REM     setx CONFLUENCE_API_TOKEN "YOUR_NEW_TOKEN"
REM   Then close and reopen your terminal/file explorer before re-running.
REM =====================================================================
setlocal enabledelayedexpansion

:: -------------------------------------------------------------------
:: Configuration - Modify these values as needed
:: -------------------------------------------------------------------
SET JSON_FILE=created_pages_20251215_223008.json
SET CONFLUENCE_URL=https://paynetics.atlassian.net
SET EMAIL=svetlin.chobanov@paynetics.digital
SET CONFLUENCE_API_TOKEN=ATATT3xFfGF076BgdjR0HrMPcTVlAGtqiCA3zz6NyQUjgPF4kMqpAujJeVLHy58QfEXhvYglYa2AnI-5T-sWUyUYOeQ7zhCRSMsNDqMQqSHu_1C89yuZ5ics2By6YQXabiL_XeCvmP0TnTwgms8Q94zXHn6IaGbOHr-dtOe4pkc3xLhcNzpWLL8=FCB6D0BE

:: -------------------------------------------------------------------
:: Use environment variable for API token if available, otherwise use hardcoded value
:: -------------------------------------------------------------------
IF NOT "%CONFLUENCE_API_TOKEN%"=="" (
  SET API_TOKEN=%CONFLUENCE_API_TOKEN%
) ELSE (
  SET API_TOKEN=ATATT3xFfGF076BgdjR0HrMPcTVlAGtqiCA3zz6NyQUjgPF4kMqpAujJeVLHy58QfEXhvYglYa2AnI-5T-sWUyUYOeQ7zhCRSMsNDqMQqSHu_1C89yuZ5ics2By6YQXabiL_XeCvmP0TnTwgms8Q94zXHn6IaGbOHr-dtOe4pkc3xLhcNzpWLL8=FCB6D0BE
)

:: -------------------------------------------------------------------
:: Check if API token is set
:: -------------------------------------------------------------------
IF "%API_TOKEN%"=="" (
  echo.
  echo [ERROR] API token is not set.
  echo Please set the CONFLUENCE_API_TOKEN environment variable:
  echo   setx CONFLUENCE_API_TOKEN "YOUR_NEW_TOKEN"
  echo Or modify the CONFLUENCE_API_TOKEN variable in this .bat file.
  echo Then close and reopen this window and double-click the .bat again.
  echo.
  pause
  exit /b 2
)

:: -------------------------------------------------------------------
:: Use command-line argument if provided, otherwise use default variable
:: -------------------------------------------------------------------
SET USE_VAR=1
IF NOT "%~1"=="" (
    REM Check if first argument is --dry-run
    IF /I "%~1"=="--dry-run" (
        REM Keep default JSON_FILE, --dry-run will be passed through
        SET USE_VAR=1
    ) ELSE (
        REM First argument is the JSON file
        SET JSON_FILE=%~1
        SET USE_VAR=0
    )
)

REM Check if Python is available
echo Checking Python installation...
python --version >nul 2>&1
if errorlevel 1 (
    echo.
    echo [ERROR] Python is not installed or not in PATH.
    echo Please install Python 3.7 or later.
    echo.
    pause
    exit /b 1
)
python --version
echo.

REM JSON_FILE is always set (either from variable or argument), so no need to check

REM Check if the JSON file exists
echo Checking for JSON file: %JSON_FILE%
if not exist "%JSON_FILE%" (
    echo.
    echo [ERROR] File not found: %JSON_FILE%
    echo Current directory: %CD%
    echo Please modify the JSON_FILE variable in this .bat file or provide a valid file path.
    echo.
    pause
    exit /b 1
)
echo JSON file found.
echo.


REM Get the directory where this batch file is located
set SCRIPT_DIR=%~dp0

echo Checking for Python script: %SCRIPT_DIR%delete_pages.py
if not exist "%SCRIPT_DIR%delete_pages.py" (
    echo.
    echo [ERROR] Python script not found: %SCRIPT_DIR%delete_pages.py
    echo.
    pause
    exit /b 1
)
echo Python script found.
echo.

REM Run the Python script
echo ================================================================================
echo Running Delete Pages Tool
echo ================================================================================
echo JSON File: %JSON_FILE%
echo Confluence URL: %CONFLUENCE_URL%
echo Username: %EMAIL%
echo Working Directory: %CD%
echo Script Directory: %SCRIPT_DIR%
echo ================================================================================
echo.
echo Note: The script will prompt you for confirmation before deleting.
echo.
echo Starting Python script...
echo.

REM Pass JSON_FILE and remaining arguments to Python script
REM If USE_VAR=0, JSON_FILE was set from %~1, so pass %~2 onwards (skip %~1)
REM If USE_VAR=1, JSON_FILE is from variable, so pass all args (may include --dry-run)

IF "%USE_VAR%"=="0" (
    REM JSON file was provided as argument, pass remaining args starting from %~2
    IF NOT "%~2"=="" (
        python "%SCRIPT_DIR%delete_pages.py" "%JSON_FILE%" --url "%CONFLUENCE_URL%" --username "%EMAIL%" --api-token "%API_TOKEN%" %~2 %~3 %~4 %~5 %~6 %~7 %~8 %~9
    ) ELSE (
        python "%SCRIPT_DIR%delete_pages.py" "%JSON_FILE%" --url "%CONFLUENCE_URL%" --username "%EMAIL%" --api-token "%API_TOKEN%"
    )
) ELSE (
    REM Using variable, pass it and all args (which may include --dry-run)
    IF NOT "%~1"=="" (
        REM Has arguments (like --dry-run), pass them
        python "%SCRIPT_DIR%delete_pages.py" "%JSON_FILE%" --url "%CONFLUENCE_URL%" --username "%EMAIL%" --api-token "%API_TOKEN%" %*
    ) ELSE (
        REM No arguments, just pass JSON_FILE
        python "%SCRIPT_DIR%delete_pages.py" "%JSON_FILE%" --url "%CONFLUENCE_URL%" --username "%EMAIL%" --api-token "%API_TOKEN%"
    )
)

SET PYTHON_EXIT=%ERRORLEVEL%
echo.
echo Python script exit code: %PYTHON_EXIT%
echo.

REM Check exit code
if errorlevel 1 (
    echo.
    echo ================================================================================
    echo Script completed with errors. Check delete_pages.log for details.
    echo ================================================================================
    pause
    exit /b 1
) else (
    echo.
    echo ================================================================================
    echo Script completed successfully.
    echo ================================================================================
)

pause

