@echo off
REM Click-in-Place Launcher
REM This batch file runs the Click-in-Place application

echo Starting Click-in-Place...
echo.

REM Check if Python is available
python --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Python is not installed or not in PATH
    pause
    exit /b 1
)

REM Check if dependencies are installed
python -c "import pynput" >nul 2>&1
if errorlevel 1 (
    echo Installing required dependencies...
    pip install -r requirements.txt
    if errorlevel 1 (
        echo ERROR: Failed to install dependencies
        pause
        exit /b 1
    )
)

REM ============================================================================
REM PARAMETERS - All parameters are OPTIONAL (defaults will be used if not specified)
REM ============================================================================
REM
REM --interval FLOAT
REM   OPTIONAL - Time in seconds between repeated clicks
REM   Default: 60.0 seconds
REM   Example: --interval 30.0 (clicks every 30 seconds)
REM
REM --repeat-count INTEGER
REM   OPTIONAL - Number of times to repeat the click
REM   Default: 10 clicks
REM   Set to 0 for infinite repeats (clicks indefinitely until stopped)
REM   Example: --repeat-count 5 (will click 5 times total)
REM   Example: --repeat-count 0 (will click indefinitely)
REM
REM --timeout FLOAT
REM   OPTIONAL - Maximum runtime in seconds before program exits automatically
REM   Default: 60.0 seconds
REM   Set to 0 to disable timeout (program runs indefinitely until ESC or completion)
REM   Example: --timeout 120.0 (program exits after 120 seconds)
REM   Example: --timeout 0 (program runs indefinitely)
REM
REM --click-x INTEGER
REM   OPTIONAL - X coordinate for clicking position (screen pixel coordinate)
REM   Must be used together with --click-y
REM   If both --click-x and --click-y are provided, program starts clicking automatically after 5 seconds
REM   If not provided, program waits for user to click with mouse
REM   Example: --click-x 500
REM
REM --click-y INTEGER
REM   OPTIONAL - Y coordinate for clicking position (screen pixel coordinate)
REM   Must be used together with --click-x
REM   If both --click-x and --click-y are provided, program starts clicking automatically after 5 seconds
REM   If not provided, program waits for user to click with mouse
REM   Example: --click-y 300
REM
REM --log-level LEVEL
REM   OPTIONAL - Logging level for detailed output
REM   Default: INFO
REM   Options: DEBUG, INFO, WARNING, ERROR
REM   Example: --log-level DEBUG (most detailed logging)
REM
REM ============================================================================
REM EXAMPLE COMMAND LINES:
REM ============================================================================
REM
REM Example 1: Basic usage with defaults
REM python click_in_place.py --interval 10.0 --repeat-count 10 --log-level INFO
REM   - Clicks every 10 seconds (--interval 10.0)
REM   - Performs 10 clicks total (--repeat-count 10)
REM   - Uses INFO level logging (--log-level INFO)
REM   - Uses default timeout of 60 seconds
REM   - Waits for user to click with mouse (no --click-x/--click-y)
REM
REM Example 2: Infinite repeats
REM python click_in_place.py --interval 5.0 --repeat-count 0 --timeout 300.0
REM   - Clicks every 5 seconds (--interval 5.0)
REM   - Clicks indefinitely (--repeat-count 0)
REM   - Program exits after 300 seconds (--timeout 300.0)
REM
REM Example 3: Infinite runtime
REM python click_in_place.py --interval 2.0 --repeat-count 50 --timeout 0
REM   - Clicks every 2 seconds (--interval 2.0)
REM   - Performs 50 clicks total (--repeat-count 50)
REM   - Program runs indefinitely (--timeout 0)
REM
REM Example 4: Fully infinite (until ESC pressed)
REM python click_in_place.py --interval 1.0 --repeat-count 0 --timeout 0
REM   - Clicks every 1 second (--interval 1.0)
REM   - Clicks indefinitely (--repeat-count 0)
REM   - Program runs indefinitely (--timeout 0)
REM   - Only ESC key will stop the program
REM
REM Example 5: Pre-configured position
REM python click_in_place.py --click-x 500 --click-y 300 --interval 5.0 --repeat-count 20
REM   - Starts clicking at position (500, 300) automatically after 5 seconds
REM   - Clicks every 5 seconds (--interval 5.0)
REM   - Performs 20 clicks total (--repeat-count 20)
REM
REM ============================================================================

REM Run the application - modify parameters below as needed
python click_in_place.py --interval 60.0 --repeat-count 0 --log-level INFO --timeout 0 

pause


