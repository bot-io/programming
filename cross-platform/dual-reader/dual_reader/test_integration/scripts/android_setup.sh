#!/bin/bash

# Android Emulator Setup Script for E2E Testing
# This script sets up and launches Android emulators for testing

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Android E2E Test Environment Setup ===${NC}"

# Check if Android SDK is available
if ! command -v adb &> /dev/null; then
    echo -e "${RED}Error: adb not found. Please install Android SDK.${NC}"
    exit 1
fi

# Check if emulator command exists
if ! command -v emulator &> /dev/null; then
    echo -e "${RED}Error: emulator command not found. Please install Android SDK.${NC}"
    exit 1
fi

# Configuration
API_LEVEL=33
TARGET="google_apis"
ARCH="x86_64"
DEVICE="Nexus 6"

echo -e "${YELLOW}Configuration:${NC}"
echo "  API Level: $API_LEVEL"
echo "  Target: $TARGET"
echo "  Architecture: $ARCH"
echo "  Device: $DEVICE"
echo ""

# Function to check if emulator exists
emulator_exists() {
    avdmanager list avd | grep -q "Name: test-emulator"
    return $?
}

# Function to create emulator if it doesn't exist
create_emulator() {
    echo -e "${YELLOW}Creating new test emulator...${NC}"
    echo "no" | avdmanager create avd \
        -n test-emulator \
        -k "system-images;android-$API_LEVEL;$TARGET;$ARCH" \
        -d "$DEVICE"

    # Configure emulator
    echo "hw.lcd.density=420" >> ~/.android/avd/test-emulator.avd/config.ini
    echo "hw.ramSize=1536" >> ~/.android/avd/test-emulator.avd/config.ini
    echo "vm.heapSize=256" >> ~/.android/avd/test-emulator.avd/config.ini
    echo "hw.gpu.enabled=yes" >> ~/.android/avd/test-emulator.avd/config.ini

    echo -e "${GREEN}✓ Emulator created${NC}"
}

# Function to start emulator
start_emulator() {
    echo -e "${YELLOW}Starting emulator...${NC}"

    # Start emulator in background
    emulator -avd test-emulator \
        -no-snapshot \
        -no-window \
        -no-boot-anim \
        -gpu auto \
        -skin 1080x1920 &

    # Wait for emulator to boot
    echo "Waiting for emulator to boot..."
    adb wait-for-device

    # Wait for boot to complete
    while [[ "$(adb shell getprop sys.boot_completed 2>/dev/null)" != "1" ]]; do
        echo -n "."
        sleep 2
    done
    echo ""

    echo -e "${GREEN}✓ Emulator is ready${NC}"
}

# Function to unlock emulator
unlock_emulator() {
    echo -e "${YELLOW}Unlocking emulator...${NC}"
    adb shell input keyevent 82
    adb shell input keyevent 4
    echo -e "${GREEN}✓ Emulator unlocked${NC}"
}

# Main setup flow
main() {
    # Check if emulator already exists
    if emulator_exists; then
        echo -e "${YELLOW}Test emulator already exists${NC}"
    else
        create_emulator
    fi

    # Check if emulator is running
    if adb devices | grep -q "emulator"; then
        echo -e "${YELLOW}Emulator already running${NC}"
    else
        start_emulator
        unlock_emulator
    fi

    echo -e "${GREEN}=== Setup Complete ===${NC}"
    echo "Emulator is ready for testing!"
    echo ""
    echo "Device ID: $(adb devices | grep emulator | awk '{print $1}')"
}

# Run main function
main
