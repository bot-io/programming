#!/bin/bash
# Master Android Build Script for Linux/Mac
# This script can build both APK and AAB with various options
#
# Usage:
#   ./build_android.sh APK              # Build universal APK
#   ./build_android.sh APK --split      # Build split APKs
#   ./build_android.sh AAB              # Build AAB for Play Store
#   ./build_android.sh Both             # Build both APK and AAB

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 {APK|AAB|Both} [--split]"
    exit 1
fi

BUILD_TYPE=$1
SPLIT_BUILD=false

if [ "$2" == "--split" ]; then
    SPLIT_BUILD=true
fi

echo "========================================="
echo "Android Build Script"
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
HAS_SIGNING=false

if [ -f "$KEY_PROPERTIES_PATH" ]; then
    HAS_SIGNING=true
else
    echo ""
    echo "Warning: key.properties not found!" >&2
    echo "Builds will use debug signing (not suitable for Play Store)" >&2
    echo "Run: scripts/generate_keystore.sh to create a keystore" >&2
    echo ""
fi

# Get version info
if [ -f "pubspec.yaml" ]; then
    VERSION_LINE=$(grep "^version:" pubspec.yaml)
    if [[ $VERSION_LINE =~ version:[[:space:]]*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+) ]]; then
        VERSION_NAME="${BASH_REMATCH[1]}"
        VERSION_CODE="${BASH_REMATCH[2]}"
        echo "Version: $VERSION_NAME (Build: $VERSION_CODE)"
        echo ""
    fi
fi

# Build function
build_apk() {
    local split=$1
    echo "========================================="
    echo "Building APK"
    echo "========================================="
    
    if [ "$split" = true ]; then
        echo "Building split APKs..."
        flutter build apk --release --split-per-abi
        APK_DIR="$PROJECT_ROOT/build/app/outputs/flutter-apk"
        echo ""
        echo "Split APKs created in: $APK_DIR"
    else
        echo "Building universal APK..."
        flutter build apk --release
        APK_PATH="$PROJECT_ROOT/build/app/outputs/flutter-apk/app-release.apk"
        echo ""
        echo "Universal APK created: $APK_PATH"
    fi
}

build_aab() {
    echo "========================================="
    echo "Building AAB"
    echo "========================================="
    
    echo "Building AAB..."
    flutter build appbundle --release
    
    if [ $? -eq 0 ]; then
        AAB_PATH="$PROJECT_ROOT/build/app/outputs/bundle/release/app-release.aab"
        echo ""
        echo "AAB created: $AAB_PATH"
    else
        echo ""
        echo "AAB build failed!"
        exit 1
    fi
}

# Clean and get dependencies
echo "Cleaning previous builds..."
flutter clean

echo ""
echo "Getting dependencies..."
flutter pub get

echo ""

# Build based on type
case "$BUILD_TYPE" in
    APK)
        build_apk $SPLIT_BUILD
        ;;
    AAB)
        build_aab
        ;;
    Both)
        build_apk false
        echo ""
        build_aab
        ;;
    *)
        echo "Error: Invalid build type. Use: APK, AAB, or Both"
        exit 1
        ;;
esac

echo ""
echo "========================================="
echo "Build Complete!"
echo "========================================="
