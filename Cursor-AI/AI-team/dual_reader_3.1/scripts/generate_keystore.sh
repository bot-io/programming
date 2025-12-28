#!/bin/bash
# Generate Keystore Script for Linux/Mac
# This script helps create a keystore for signing Android releases

set -e

echo "========================================="
echo "Android Keystore Generator"
echo "========================================="

# Check if Java keytool is available
if ! command -v keytool &> /dev/null; then
    echo "Error: Java keytool is not installed or not in PATH"
    echo "Please install Java JDK to use this script"
    exit 1
fi

# Navigate to project root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
KEYSTORE_PATH="$PROJECT_ROOT/upload-keystore.jks"

if [ -f "$KEYSTORE_PATH" ]; then
    echo ""
    echo "Warning: Keystore already exists at: $KEYSTORE_PATH"
    read -p "Overwrite? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi
fi

echo ""
echo "This will create a keystore for signing your Android app."
echo "You will be prompted for:"
echo "  - Keystore password (store this securely!)"
echo "  - Key password (can be same as keystore password)"
echo "  - Your name and organization details"
echo ""

read -p "Continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 0
fi

echo ""
echo "Generating keystore..."
echo "Location: $KEYSTORE_PATH"

# Generate keystore
keytool -genkey -v -keystore "$KEYSTORE_PATH" -keyalg RSA -keysize 2048 -validity 10000 -alias upload

if [ $? -eq 0 ]; then
    echo ""
    echo "========================================="
    echo "Keystore Created Successfully!"
    echo "========================================="
    
    echo ""
    echo "Next steps:"
    echo "  1. Copy android/key.properties.template to android/key.properties"
    echo "  2. Update android/key.properties with:"
    echo "     storeFile=../upload-keystore.jks"
    echo "     storePassword=<your-store-password>"
    echo "     keyPassword=<your-key-password>"
    echo "     keyAlias=upload"
    echo ""
    echo "IMPORTANT: Keep your keystore and passwords secure!"
    echo "  - Store the keystore file safely (backup recommended)"
    echo "  - Never commit key.properties or keystore to version control"
else
    echo ""
    echo "========================================="
    echo "Keystore Generation Failed!"
    echo "========================================="
    exit 1
fi
