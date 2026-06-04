#!/bin/bash

# E2E Test Runner Script
# Provides convenient commands for running E2E tests across platforms

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
PLATFORM="all"
VERBOSE=false
COVERAGE=false
SPECIFIC_TEST=""
HEADLESS=false

# Print usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -p, --platform PLATFORM    Platform to test (android/ios/web/all) [default: all]"
    echo "  -t, --test TEST_FILE       Specific test file to run"
    echo "  -v, --verbose              Enable verbose logging"
    echo "  -c, --coverage             Generate coverage report"
    echo "  -h, --headless             Run in headless mode (CI mode)"
    echo "  --help                     Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                          # Run all tests"
    echo "  $0 -p android               # Run Android tests only"
    echo "  $0 -p web -v                # Run web tests with verbose logging"
    echo "  $0 -t app_lifecycle_test    # Run specific test file"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--platform)
            PLATFORM="$2"
            shift 2
            ;;
        -t|--test)
            SPECIFIC_TEST="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -c|--coverage)
            COVERAGE=true
            shift
            ;;
        -h|--headless)
            HEADLESS=true
            shift
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            exit 1
            ;;
    esac
done

# Print banner
echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Dual Reader E2E Test Runner             ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""

# Set environment variables
export VERBOSE_LOGGING=$VERBOSE
export CI_MODE=$HEADLESS

# Get project root
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_ROOT/dual_reader"

echo -e "${YELLOW}Configuration:${NC}"
echo "  Platform: $PLATFORM"
echo "  Verbose: $VERBOSE"
echo "  Coverage: $COVERAGE"
echo "  Headless: $HEADLESS"
if [[ -n "$SPECIFIC_TEST" ]]; then
    echo "  Test: $SPECIFIC_TEST"
fi
echo ""

# Build flutter test command
build_test_command() {
    local cmd="flutter test integration_test"

    # Add specific test if provided
    if [[ -n "$SPECIFIC_TEST" ]]; then
        cmd="$cmd/$SPECIFIC_TEST"
    fi

    # Add coverage if requested
    if [[ "$COVERAGE" == true ]]; then
        cmd="$cmd --coverage"
    fi

    # Add dart defines
    cmd="$cmd --dart-define=TEST_MODE=true"

    if [[ "$VERBOSE" == true ]]; then
        cmd="$cmd --dart-define=VERBOSE_LOGGING=true"
    fi

    echo "$cmd"
}

# Run Android tests
run_android_tests() {
    echo -e "${GREEN}=== Running Android Tests ===${NC}"

    # Check for connected devices
    if ! adb devices | grep -q "device$"; then
        echo -e "${YELLOW}No Android device connected. Starting emulator...${NC}"
        bash test_integration/scripts/android_setup.sh
    fi

    # Get device ID
    DEVICE_ID=$(adb devices | grep emulator | awk 'NR==1{print $1}')

    if [[ -z "$DEVICE_ID" ]]; then
        echo -e "${RED}No Android device/emulator found${NC}"
        return 1
    fi

    echo "Using device: $DEVICE_ID"

    # Run tests
    local cmd=$(build_test_command)
    $cmd --device-id="$DEVICE_ID"
}

# Run iOS tests
run_ios_tests() {
    echo -e "${GREEN}=== Running iOS Tests ===${NC}"

    if [[ "$OSTYPE" != "darwin"* ]]; then
        echo -e "${RED}iOS tests can only run on macOS${NC}"
        return 1
    fi

    # Check for booted simulator
    if ! xcrun simctl list devices | grep -q "Booted"; then
        echo -e "${YELLOW}No iOS simulator booted. Starting simulator...${NC}"
        bash test_integration/scripts/ios_setup.sh
    fi

    # Get device ID
    DEVICE_ID=$(xcrun simctl list devices | grep "iPhone 15 Pro" | grep -oE "\([0-9A-F-]+\)" | tr -d '()' | head -1)

    if [[ -z "$DEVICE_ID" ]]; then
        echo -e "${RED}No iOS simulator found${NC}"
        return 1
    fi

    echo "Using device: $DEVICE_ID"

    # Run tests
    local cmd=$(build_test_command)
    $cmd --device-id="$DEVICE_ID"
}

# Run Web tests
run_web_tests() {
    echo -e "${GREEN}=== Running Web Tests ===${NC}"

    # Run tests
    local cmd=$(build_test_command)
    $cmd --platform chrome --dart-define=USE_MOCK_TRANSLATION=true
}

# Main test execution
main() {
    local start_time=$(date +%s)
    local exit_code=0

    # Run tests based on platform
    case $PLATFORM in
        android)
            run_android_tests
            exit_code=$?
            ;;
        ios)
            run_ios_tests
            exit_code=$?
            ;;
        web)
            run_web_tests
            exit_code=$?
            ;;
        all)
            # Try all platforms, don't fail on missing platforms
            if command -v adb &> /dev/null; then
                run_android_tests || echo -e "${YELLOW}Android tests skipped${NC}"
            else
                echo -e "${YELLOW}Android tests skipped (Android SDK not found)${NC}"
            fi

            if [[ "$OSTYPE" == "darwin"* ]] && command -v xcrun &> /dev/null; then
                run_ios_tests || echo -e "${YELLOW}iOS tests skipped${NC}"
            else
                echo -e "${YELLOW}iOS tests skipped (macOS only)${NC}"
            fi

            if command -v google-chrome &> /dev/null || command -v chromium-browser &> /dev/null; then
                run_web_tests || echo -e "${YELLOW}Web tests skipped${NC}"
            else
                echo -e "${YELLOW}Web tests skipped (Chrome not found)${NC}"
            fi
            ;;
        *)
            echo -e "${RED}Unknown platform: $PLATFORM${NC}"
            usage
            exit 1
            ;;
    esac

    # Calculate duration
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))

    echo ""
    echo -e "${BLUE}=== Test Run Complete ===${NC}"
    echo "Duration: ${minutes}m ${seconds}s"

    if [[ $exit_code -eq 0 ]]; then
        echo -e "${GREEN}✓ All tests passed!${NC}"
    else
        echo -e "${RED}✗ Some tests failed${NC}"
    fi

    # Show coverage info if generated
    if [[ "$COVERAGE" == true ]] && [[ -f "coverage/lcov.info" ]]; then
        echo ""
        echo -e "${YELLOW}Coverage report generated: coverage/lcov.info${NC}"
    fi

    exit $exit_code
}

# Run main
main
