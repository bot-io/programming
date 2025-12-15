@echo off
REM =====================================================================
REM Directory to Confluence Sync Tool (Windows .bat)
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
SET CONFLUENCE_URL=https://paynetics.atlassian.net
SET EMAIL=svetlin.chobanov@paynetics.digital
SET CONFLUENCE_API_TOKEN=ATATT3xFfGF076BgdjR0HrMPcTVlAGtqiCA3zz6NyQUjgPF4kMqpAujJeVLHy58QfEXhvYglYa2AnI-5T-sWUyUYOeQ7zhCRSMsNDqMQqSHu_1C89yuZ5ics2By6YQXabiL_XeCvmP0TnTwgms8Q94zXHn6IaGbOHr-dtOe4pkc3xLhcNzpWLL8=FCB6D0BE
SET ROOT_PAGE_ID=13653082155
SET DIRECTORY_PATH=C:\Users\svetlin.chobanov\OneDrive - Paynetics\Documents\Cursor\Project\Outputs\Wallets\Wallets-2.0-Pages

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
:: Check if directory exists
:: -------------------------------------------------------------------
IF NOT EXIST "%DIRECTORY_PATH%" (
  echo.
  echo [ERROR] Directory not found: %DIRECTORY_PATH%
  echo Please modify the DIRECTORY_PATH variable in this .bat file.
  echo.
  pause
  exit /b 3
)

:: -------------------------------------------------------------------
:: Run the sync program
:: -------------------------------------------------------------------
echo.
echo =====================================================================
echo Directory to Confluence Sync Tool
echo =====================================================================
echo Directory: %DIRECTORY_PATH%
echo Root Page ID: %ROOT_PAGE_ID%
echo Confluence URL: %CONFLUENCE_URL%
echo Username: %EMAIL%
echo =====================================================================
echo.

python "%~dp0confluence_sync.py" ^
  "%DIRECTORY_PATH%" ^
  "%ROOT_PAGE_ID%" ^
  --url "%CONFLUENCE_URL%" ^
  --username "%EMAIL%" ^
  --api-token "%API_TOKEN%"

IF ERRORLEVEL 1 (
  echo.
  echo [ERROR] Sync failed with error code %ERRORLEVEL%
  pause
  exit /b %ERRORLEVEL%
)

echo.
echo =====================================================================
echo Sync completed successfully!
echo =====================================================================
pause
