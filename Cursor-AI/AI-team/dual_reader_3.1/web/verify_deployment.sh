#!/bin/bash
# Deployment Verification Script for Dual Reader 3.1
# This script verifies that the web build is ready for deployment

set -e  # Exit on error

# Default values
BUILD_DIR="build/web"
CHECK_PWA=true
CHECK_SECURITY=true
CHECK_PERFORMANCE=true

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --build-dir)
            BUILD_DIR="$2"
            shift 2
            ;;
        --no-pwa)
            CHECK_PWA=false
            shift
            ;;
        --no-security)
            CHECK_SECURITY=false
            shift
            ;;
        --no-performance)
            CHECK_PERFORMANCE=false
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --build-dir DIR     Build directory (default: build/web)"
            echo "  --no-pwa            Skip PWA checks"
            echo "  --no-security       Skip security checks"
            echo "  --no-performance    Skip performance checks"
            echo "  -h, --help          Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

echo "🔍 Verifying Dual Reader 3.1 Web Build..."
echo ""

ALL_CHECKS_PASSED=true

# Check if build directory exists
if [ ! -d "$BUILD_DIR" ]; then
    echo "❌ Build directory not found: $BUILD_DIR"
    echo "   Run 'flutter build web --release' first"
    exit 1
fi

echo "✅ Build directory found: $BUILD_DIR"
echo ""

# Check required files
echo "📋 Checking required files..."
REQUIRED_FILES=(
    "index.html:true:Main HTML file"
    "main.dart.js:true:Compiled Dart code"
    "flutter.js:true:Flutter web engine"
    "manifest.json:$CHECK_PWA:PWA manifest"
    "flutter_service_worker.js:$CHECK_PWA:Service worker"
)

for FILE_INFO in "${REQUIRED_FILES[@]}"; do
    IFS=':' read -r FILE REQUIRED DESC <<< "$FILE_INFO"
    FILE_PATH="$BUILD_DIR/$FILE"
    
    if [ -f "$FILE_PATH" ]; then
        if command -v stat &> /dev/null; then
            FILE_SIZE=$(stat -f%z "$FILE_PATH" 2>/dev/null || stat -c%s "$FILE_PATH" 2>/dev/null || echo "0")
            FILE_SIZE_KB=$((FILE_SIZE / 1024))
            echo "   ✅ $FILE ($FILE_SIZE_KB KB)"
        else
            echo "   ✅ $FILE"
        fi
    elif [ "$REQUIRED" = "true" ]; then
        echo "   ❌ $FILE - MISSING ($DESC)"
        ALL_CHECKS_PASSED=false
    else
        echo "   ⚠️  $FILE - MISSING (optional)"
    fi
done

echo ""

# Check PWA configuration
if [ "$CHECK_PWA" = true ]; then
    echo "📱 Checking PWA configuration..."
    
    # Check manifest.json
    MANIFEST_PATH="$BUILD_DIR/manifest.json"
    if [ -f "$MANIFEST_PATH" ]; then
        if command -v jq &> /dev/null; then
            MANIFEST_NAME=$(jq -r '.name' "$MANIFEST_PATH" 2>/dev/null || echo "")
            MANIFEST_SHORT_NAME=$(jq -r '.short_name' "$MANIFEST_PATH" 2>/dev/null || echo "")
            MANIFEST_START_URL=$(jq -r '.start_url' "$MANIFEST_PATH" 2>/dev/null || echo "")
            MANIFEST_DISPLAY=$(jq -r '.display' "$MANIFEST_PATH" 2>/dev/null || echo "")
            ICON_COUNT=$(jq '.icons | length' "$MANIFEST_PATH" 2>/dev/null || echo "0")
            
            [ -n "$MANIFEST_NAME" ] && echo "   ✅ name: $MANIFEST_NAME" || echo "   ❌ name: Missing"
            [ -n "$MANIFEST_SHORT_NAME" ] && echo "   ✅ short_name: $MANIFEST_SHORT_NAME" || echo "   ❌ short_name: Missing"
            [ -n "$MANIFEST_START_URL" ] && echo "   ✅ start_url: $MANIFEST_START_URL" || echo "   ❌ start_url: Missing"
            [ -n "$MANIFEST_DISPLAY" ] && echo "   ✅ display: $MANIFEST_DISPLAY" || echo "   ❌ display: Missing"
            [ "$ICON_COUNT" -gt 0 ] && echo "   ✅ icons: $ICON_COUNT icons" || echo "   ❌ icons: No icons found"
            
            if [ "$ICON_COUNT" -eq 0 ]; then
                ALL_CHECKS_PASSED=false
            fi
        else
            echo "   ⚠️  jq not found. Install jq for manifest validation."
        fi
    else
        echo "   ❌ manifest.json not found"
        ALL_CHECKS_PASSED=false
    fi
    
    # Check service worker
    SW_PATH="$BUILD_DIR/flutter_service_worker.js"
    if [ -f "$SW_PATH" ]; then
        echo "   ✅ Service worker found"
    else
        echo "   ⚠️  Service worker not found (may be generated at runtime)"
    fi
    
    # Check icons directory
    ICONS_DIR="$BUILD_DIR/icons"
    if [ -d "$ICONS_DIR" ]; then
        ICON_COUNT=$(find "$ICONS_DIR" -name "*.png" 2>/dev/null | wc -l)
        echo "   ✅ Icons directory found ($ICON_COUNT icons)"
    else
        echo "   ⚠️  Icons directory not found"
    fi
    
    echo ""
fi

# Check build size
if [ "$CHECK_PERFORMANCE" = true ]; then
    echo "📊 Checking build size..."
    
    if command -v du &> /dev/null; then
        BUILD_SIZE=$(du -sk "$BUILD_DIR" 2>/dev/null | cut -f1)
        BUILD_SIZE_MB=$((BUILD_SIZE / 1024))
        echo "   Total size: $BUILD_SIZE_MB MB"
    fi
    
    # Check main.dart.js size
    MAIN_JS_PATH="$BUILD_DIR/main.dart.js"
    if [ -f "$MAIN_JS_PATH" ]; then
        MAIN_JS_SIZE=$(stat -f%z "$MAIN_JS_PATH" 2>/dev/null || stat -c%s "$MAIN_JS_PATH" 2>/dev/null || echo "0")
        MAIN_JS_SIZE_MB=$((MAIN_JS_SIZE / 1048576))
        echo "   main.dart.js: $MAIN_JS_SIZE_MB MB"
        
        if [ "$MAIN_JS_SIZE_MB" -gt 5 ]; then
            echo "   ⚠️  Large bundle size detected. Consider code splitting."
        elif [ "$MAIN_JS_SIZE_MB" -lt 2 ]; then
            echo "   ✅ Bundle size is reasonable"
        fi
    fi
    
    # Check for source maps
    SOURCE_MAPS=$(find "$BUILD_DIR" -name "*.js.map" 2>/dev/null | wc -l)
    if [ "$SOURCE_MAPS" -gt 0 ]; then
        echo "   ⚠️  Source maps found ($SOURCE_MAPS files). Consider removing for production."
    else
        echo "   ✅ No source maps found (good for production)"
    fi
    
    echo ""
fi

# Summary
echo "📝 Verification Summary:"
if [ "$ALL_CHECKS_PASSED" = true ]; then
    echo "   ✅ All critical checks passed!"
    echo ""
    echo "✨ Build is ready for deployment!"
    exit 0
else
    echo "   ❌ Some checks failed. Please fix issues before deploying."
    echo ""
    echo "⚠️  Build may not be ready for deployment."
    exit 1
fi
