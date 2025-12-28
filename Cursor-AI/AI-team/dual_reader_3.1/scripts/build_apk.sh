#!/bin/bash
# Build APK Script for Linux/Mac
# This script builds a release APK for direct installation
#
# Usage:
#   ./build_apk.sh              # Build universal APK (all architectures)
#   ./build_apk.sh --split      # Build split APKs (per architecture)
#   ./build_apk.sh --universal  # Build universal APK (explicit)

set -e

# Determine build type
BUILD_TYPE="universal"
if [[ "$1" == "--split" ]]; then
    BUILD_TYPE="split"
elif [[ "$1" == "--universal" ]]; then
    BUILD_TYPE="universal"
fi

echo "========================================="
echo "Building Release APK"
echo "Build Type: $BUILD_TYPE"
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
if [ ! -f "$KEY_PROPERTIES_PATH" ]; then
    echo ""
    echo "Note: key.properties not found. Using debug signing." >&2
    echo "For release signing, create android/key.properties" >&2
    echo ""
fi

echo ""
echo "Cleaning previous builds..."
flutter clean

echo ""
echo "Getting dependencies..."
flutter pub get

echo ""
if [ "$BUILD_TYPE" == "split" ]; then
    echo "Building release APK (split per ABI)..."
    flutter build apk --release --split-per-abi
    APK_DIR="$PROJECT_ROOT/build/app/outputs/flutter-apk"
    echo ""
    echo "========================================="
    echo "Split APK Build Successful!"
    echo "========================================="
    echo ""
    echo "APK Locations:"
    for apk in "$APK_DIR"/*.apk; do
        if [ -f "$apk" ]; then
            SIZE=$(du -h "$apk" | cut -f1)
            echo "  $(basename "$apk") ($SIZE)"
        fi
    done
    echo ""
    echo "Architecture-specific APKs created:"
    echo "  - app-armeabi-v7a-release.apk (32-bit ARM)"
    echo "  - app-arm64-v8a-release.apk (64-bit ARM)"
    echo "  - app-x86_64-release.apk (64-bit x86)"
else
    echo "Building release APK (universal)..."
    flutter build apk --release
    APK_PATH="$PROJECT_ROOT/build/app/outputs/flutter-apk/app-release.apk"
    echo ""
    echo "========================================="
    echo "Universal APK Build Successful!"
    echo "========================================="
    echo ""
    if [ -f "$APK_PATH" ]; then
        SIZE=$(du -h "$APK_PATH" | cut -f1)
        echo "APK Location: $APK_PATH"
        echo "APK Size: $SIZE"
    fi
fi

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
echo "To install on device:"
if [ "$BUILD_TYPE" == "split" ]; then
    echo "  adb install $APK_DIR/app-arm64-v8a-release.apk  # For 64-bit ARM devices"
    echo "  adb install $APK_DIR/app-armeabi-v7a-release.apk # For 32-bit ARM devices"
else
    echo "  adb install $APK_PATH"
fi
