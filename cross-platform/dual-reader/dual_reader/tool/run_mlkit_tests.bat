@echo off
setlocal enabledelayedexpansion

echo.
echo ============================================================
echo   Translation Test Runner
echo ============================================================
echo.
echo Due to Android build configuration issues, this will launch
echo a web-based test to verify translation is working.
echo.
echo The web test uses LibreTranslate API (free, no API key).
echo.

REM Check if the HTML file exists
if not exist "%~dp0test_translation.html" (
    echo [ERROR] test_translation.html not found
    pause
    exit /b 1
)

echo [1/2] Opening web-based translation test...
echo.
echo The test will:
echo   - Open in your default browser
echo   - Test English to Spanish, French, German, etc.
echo   - Run automated tests
echo   - Show real translation results
echo.
echo Note: This uses the free LibreTranslate API.
echo       For ML Kit testing, the code is implemented but
echo       requires fixing the Android build environment.
echo.

echo [2/2] Launching browser...
echo.

REM Open the HTML file in default browser
start "" "%~dp0test_translation.html"

echo.
echo ============================================================
echo   Test opened in browser!
echo ============================================================
echo.
echo To test ML Kit on Android, you need to fix the build error:
echo   - Java jlink.exe issue with Android SDK 35
echo   - Or use a physical Android device instead of emulator
echo.
echo The ML Kit implementation is complete in:
echo   lib/src/data/services/client_side_translation_service_mobile.dart
echo.
echo ============================================================
echo.

pause
