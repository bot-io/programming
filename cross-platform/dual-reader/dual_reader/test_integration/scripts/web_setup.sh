#!/bin/bash

# Web Browser Setup Script for E2E Testing
# This script sets up web browsers for testing

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Web E2E Test Environment Setup ===${NC}"

# Check if Chrome is installed
check_chrome() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if [[ -d "/Applications/Google Chrome.app" ]]; then
            echo "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
            return 0
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        if command -v google-chrome &> /dev/null; then
            command -v google-chrome
            return 0
        elif command -v chromium-browser &> /dev/null; then
            command -v chromium-browser
            return 0
        fi
    fi
    return 1
}

# Check if Firefox is installed
check_firefox() {
    if command -v firefox &> /dev/null; then
        command -v firefox
        return 0
    fi
    return 1
}

# Check if Safari is installed (macOS only)
check_safari() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if command -v safari &> /dev/null; then
            command -v safari
            return 0
        elif [[ -d "/Applications/Safari.app" ]]; then
            echo "/Applications/Safari.app/Contents/MacOS/Safari"
            return 0
        fi
    fi
    return 1
}

# Main setup flow
main() {
    echo -e "${YELLOW}Checking for installed browsers...${NC}"

    # Check Chrome
    if CHROME_PATH=$(check_chrome); then
        echo -e "${GREEN}✓ Chrome found: $CHROME_PATH${NC}"
        export CHROME_PATH
    else
        echo -e "${RED}✗ Chrome not found${NC}"
        echo "  Install Chrome: https://www.google.com/chrome/"
    fi

    # Check Firefox
    if FIREFOX_PATH=$(check_firefox); then
        echo -e "${GREEN}✓ Firefox found: $FIREFOX_PATH${NC}"
        export FIREFOX_PATH
    else
        echo -e "${YELLOW}⚠ Firefox not found (optional)${NC}"
    fi

    # Check Safari
    if SAFARI_PATH=$(check_safari); then
        echo -e "${GREEN}✓ Safari found: $SAFARI_PATH${NC}"
        export SAFARI_PATH
    else
        echo -e "${YELLOW}⚠ Safari not found (macOS only)${NC}"
    fi

    echo ""
    echo -e "${GREEN}=== Setup Complete ===${NC}"
    echo "Web browsers ready for testing!"
    echo ""
    echo "To run web tests:"
    echo "  flutter test integration_test --platform chrome"
    echo ""
}

# Run main function
main
