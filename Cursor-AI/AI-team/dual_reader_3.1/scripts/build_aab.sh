#!/bin/bash
# Build AAB Script for Linux/Mac
# This script builds a release AAB (Android App Bundle) for Google Play Store

set -e

echo "========================================="
echo "Building Release AAB (App Bundle)"
echo "========================================="

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "Error: Flutter is not installed or not in PATH"
    exit 1
fi

# Navigate to project root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
cd "$PROJECT_ROOT"

# Check for signing configuration
KEY_PROPERTIES_PATH="$PROJECT_ROOT/android/key.properties"
KEYSTORE_FILE=""

if [ -f "$KEY_PROPERTIES_PATH" ]; then
    # Extract keystore file path from key.properties
    STORE_FILE_LINE=$(grep "^storeFile=" "$KEY_PROPERTIES_PATH" || true)
    if [ -n "$STORE_FILE_LINE" ]; then
        KEYSTORE_FILE=$(echo "$STORE_FILE_LINE" | cut -d'=' -f2 | tr -d ' ')
        if [ -n "$KEYSTORE_FILE" ]; then
            # Handle relative paths
            if [[ "$KEYSTORE_FILE" == ../* ]]; then
                KEYSTORE_FILE="$PROJECT_ROOT/${KEYSTORE_FILE#../}"
            elif [ ! -f "$KEYSTORE_FILE" ] && [ ! "${KEYSTORE_FILE:0:1}" = "/" ]; then
                KEYSTORE_FILE="$PROJECT_ROOT/android/$KEYSTORE_FILE"
            fi
        fi
    fi
fi

if [ ! -f "$KEY_PROPERTIES_PATH" ] || [ -z "$KEYSTORE_FILE" ] || [ ! -f "$KEYSTORE_FILE" ]; then
    echo ""
    echo "Warning: key.properties not found or keystore file missing!" >&2
    echo "AAB will be built with debug signing (not suitable for Play Store)" >&2
    echo ""
    echo "To set up signing:" >&2
    echo "  1. Copy android/key.properties.template to android/key.properties" >&2
    echo "  2. Fill in your keystore details" >&2
    echo "  3. Or run: scripts/generate_keystore.sh" >&2
    echo ""
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
else
    echo ""
    echo "Using signing configuration from key.properties"
fi

echo ""
echo "Cleaning previous builds..."
flutter clean

echo ""
echo "Getting dependencies..."
flutter pub get

echo ""
echo "Building release AAB..."
flutter build appbundle --release

if [ $? -eq 0 ]; then
    echo ""
    echo "========================================="
    echo "AAB Build Successful!"
    echo "========================================="
    echo ""
    echo "AAB Location: build/app/outputs/bundle/release/app-release.aab"
    
    # Get version info
    if [ -f "pubspec.yaml" ]; then
        VERSION_LINE=$(grep "^version:" pubspec.yaml)
        if [[ $VERSION_LINE =~ version:[[:space:]]*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+) ]]; then
            VERSION_NAME="${BASH_REMATCH[1]}"
            VERSION_CODE="${BASH_REMATCH[2]}"
            echo "Version: $VERSION_NAME (Build: $VERSION_CODE)"
        fi
    fi
    
    echo ""
    echo "To upload to Play Store:"
    echo "  1. Go to Google Play Console"
    echo "  2. Navigate to your app > Release > Production"
    echo "  3. Create new release and upload the AAB file"
    echo ""
    echo "File: build/app/outputs/bundle/release/app-release.aab"
else
    echo ""
    echo "========================================="
    echo "AAB Build Failed!"
    echo "========================================="
    exit 1
fi
