#!/bin/bash

# iOS Simulator Setup Script for E2E Testing
# This script sets up and launches iOS simulators for testing

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== iOS E2E Test Environment Setup ===${NC}"

# Check if Xcode tools are available
if ! command -v xcrun &> /dev/null; then
    echo -e "${RED}Error: xcrun not found. Please install Xcode.${NC}"
    exit 1
fi

# Configuration
DEVICE_NAME="iPhone 15 Pro"
OS_VERSION="latest"

echo -e "${YELLOW}Configuration:${NC}"
echo "  Device: $DEVICE_NAME"
echo "  iOS: $OS_VERSION"
echo ""

# Function to list available simulators
list_simulators() {
    echo -e "${YELLOW}Available simulators:${NC}"
    xcrun simctl list devices available | grep "iPhone"
}

# Function to create simulator if needed
create_simulator() {
    echo -e "${YELLOW}Creating simulator...${NC}"
    xcrun simctl create "Test Device" "iPhone 15 Pro" "com.apple.CoreSimulator.SimRuntime.iOS-17-0"
    echo -e "${GREEN}✓ Simulator created${NC}"
}

# Function to start simulator
start_simulator() {
    local device_id=$1

    echo -e "${YELLOW}Starting simulator...${NC}"
    xcrun simctl boot "$device_id"

    # Open Simulator app
    open -a Simulator

    # Wait for simulator to be ready
    echo "Waiting for simulator to boot..."
    sleep 5

    # Wait until boot completes
    while [[ $(xcrun simctl list devices | grep "$device_id" | grep -q "Booted"; echo $?) -ne 0 ]]; do
        echo -n "."
        sleep 2
    done
    echo ""

    echo -e "${GREEN}✓ Simulator is ready${NC}"
}

# Function to get device ID
get_device_id() {
    xcrun simctl list devices | grep "$DEVICE_NAME" | grep -oE "\([0-9A-F-]+\)" | tr -d '()'
}

# Main setup flow
main() {
    # Show available simulators
    list_simulators
    echo ""

    # Get device ID
    DEVICE_ID=$(get_device_id)

    if [[ -z "$DEVICE_ID" ]]; then
        echo -e "${YELLOW}No suitable simulator found, creating one...${NC}"
        create_simulator
        DEVICE_ID=$(get_device_id)
    fi

    echo -e "${YELLOW}Using device: $DEVICE_NAME ($DEVICE_ID)${NC}"

    # Check if simulator is already booted
    if xcrun simctl list devices | grep "$DEVICE_ID" | grep -q "Booted"; then
        echo -e "${YELLOW}Simulator already booted${NC}"
    else
        start_simulator "$DEVICE_ID"
    fi

    echo -e "${GREEN}=== Setup Complete ===${NC}"
    echo "Simulator is ready for testing!"
    echo ""
    echo "Device ID: $DEVICE_ID"
}

# Run main function
main
