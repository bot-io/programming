@echo off
REM =====================================================================
REM Test Runner for Confluence Sync Tool (Windows .bat)
REM =====================================================================

echo.
echo =====================================================================
echo Running Confluence Sync Test Suite
echo =====================================================================
echo.

python -m pytest test_confluence_sync.py -v --tb=short

IF ERRORLEVEL 1 (
  echo.
  echo [ERROR] Some tests failed!
  pause
  exit /b %ERRORLEVEL%
)

echo.
echo =====================================================================
echo All tests passed!
echo =====================================================================
pause
