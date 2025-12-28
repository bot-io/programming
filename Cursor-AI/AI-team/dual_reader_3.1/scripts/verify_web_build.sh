#!/bin/bash
# Web Build Verification Script for Linux/macOS
# Verifies that the web build meets all requirements for deployment

set -e

STRICT=false
VERBOSE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --strict)
            STRICT=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo "========================================="
echo "Web Build Verification"
echo "========================================="
echo ""

# Navigate to project root
SCRIPT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT=$(cd "$SCRIPT_PATH/.." && pwd)
cd "$PROJECT_ROOT"

BUILD_DIR="$PROJECT_ROOT/build/web"
ERRORS=()
WARNINGS=()
PASSED=()

# Check if build directory exists
if [ ! -d "$BUILD_DIR" ]; then
    echo "❌ Build directory not found: $BUILD_DIR"
    echo "   Run 'flutter build web --release' first"
    exit 1
fi

echo "✅ Build directory found: $BUILD_DIR"
echo ""

# Essential files checklist
echo "Checking essential files..."

ESSENTIAL_FILES=("index.html" "manifest.json" "flutter.js" "main.dart.js" "flutter_service_worker.js")

for file in "${ESSENTIAL_FILES[@]}"; do
    FILE_PATH="$BUILD_DIR/$file"
    if [ -f "$FILE_PATH" ]; then
        FILE_SIZE=$(du -h "$FILE_PATH" | cut -f1)
        echo "   ✅ $file ($FILE_SIZE)"
        PASSED+=("$file")
    else
        echo "   ❌ $file - MISSING (Required)"
        ERRORS+=("$file is missing")
    fi
done

echo ""

# Check manifest.json validity
echo "Validating manifest.json..."
MANIFEST_PATH="$BUILD_DIR/manifest.json"
if [ -f "$MANIFEST_PATH" ]; then
    # Check if jq is available for JSON validation
    if command -v jq &> /dev/null; then
        if jq empty "$MANIFEST_PATH" 2>/dev/null; then
            echo "   ✅ manifest.json is valid JSON"
            
            # Check required fields
            REQUIRED_FIELDS=("name" "short_name" "start_url" "display" "icons")
            for field in "${REQUIRED_FIELDS[@]}"; do
                if jq -e ".$field" "$MANIFEST_PATH" > /dev/null 2>&1; then
                    echo "      ✅ Field: $field"
                else
                    echo "      ❌ Missing required field: $field"
                    ERRORS+=("manifest.json missing field: $field")
                fi
            done
        else
            echo "   ❌ Invalid JSON in manifest.json"
            ERRORS+=("manifest.json is invalid JSON")
        fi
    else
        echo "   ⚠️  jq not installed, skipping JSON validation"
        WARNINGS+=("jq not installed for JSON validation")
    fi
else
    echo "   ❌ manifest.json not found"
    ERRORS+=("manifest.json not found")
fi

echo ""

# Check service worker
echo "Checking service worker..."
SW_PATH="$BUILD_DIR/flutter_service_worker.js"
if [ -f "$SW_PATH" ]; then
    if grep -q "serviceWorkerVersion" "$SW_PATH"; then
        echo "   ✅ Service worker contains version info"
    else
        echo "   ⚠️  Service worker may be incomplete"
        WARNINGS+=("Service worker may be incomplete")
    fi
    
    SW_SIZE=$(du -h "$SW_PATH" | cut -f1)
    echo "   ✅ Service worker size: $SW_SIZE"
else
    echo "   ❌ flutter_service_worker.js not found"
    ERRORS+=("flutter_service_worker.js not found")
fi

echo ""

# Check icons directory
echo "Checking icons..."
ICONS_DIR="$BUILD_DIR/icons"
if [ -d "$ICONS_DIR" ]; then
    ICON_COUNT=$(find "$ICONS_DIR" -name "*.png" | wc -l)
    if [ "$ICON_COUNT" -gt 0 ]; then
        echo "   ✅ Found $ICON_COUNT icon files"
        
        # Check for required sizes
        REQUIRED_SIZES=(192 512)
        for size in "${REQUIRED_SIZES[@]}"; do
            if find "$ICONS_DIR" -name "*${size}x${size}*" | grep -q .; then
                echo "      ✅ Icon ${size}x${size} exists"
            else
                echo "      ⚠️  Icon ${size}x${size} missing"
                WARNINGS+=("Icon ${size}x${size} missing")
            fi
        done
    else
        echo "   ⚠️  No icon files found in icons directory"
        WARNINGS+=("No icon files found")
    fi
else
    echo "   ⚠️  Icons directory not found"
    WARNINGS+=("Icons directory not found")
fi

echo ""

# Check build size
echo "Checking build size..."
BUILD_SIZE=$(du -sh "$BUILD_DIR" | cut -f1)
echo "   Total build size: $BUILD_SIZE"

# Check main.dart.js size
MAIN_JS_PATH="$BUILD_DIR/main.dart.js"
if [ -f "$MAIN_JS_PATH" ]; then
    MAIN_JS_SIZE=$(du -h "$MAIN_JS_PATH" | cut -f1)
    echo "   main.dart.js: $MAIN_JS_SIZE"
    
    # Check if size is reasonable (rough check)
    MAIN_JS_SIZE_BYTES=$(stat -f%z "$MAIN_JS_PATH" 2>/dev/null || stat -c%s "$MAIN_JS_PATH" 2>/dev/null || echo "0")
    MAIN_JS_SIZE_MB=$((MAIN_JS_SIZE_BYTES / 1024 / 1024))
    if [ "$MAIN_JS_SIZE_MB" -gt 5 ]; then
        echo "   ⚠️  main.dart.js is large (>5MB). Consider optimization."
        WARNINGS+=("main.dart.js is large")
    else
        echo "   ✅ main.dart.js size is reasonable"
    fi
fi

echo ""

# Check index.html for PWA requirements
echo "Checking index.html for PWA requirements..."
INDEX_PATH="$BUILD_DIR/index.html"
if [ -f "$INDEX_PATH" ]; then
    if grep -q 'manifest\.json' "$INDEX_PATH"; then
        echo "   ✅ Manifest link"
    else
        echo "   ⚠️  Missing: Manifest link"
        WARNINGS+=("index.html missing: Manifest link")
    fi
    
    if grep -qi 'service.*worker\|flutter_service_worker' "$INDEX_PATH"; then
        echo "   ✅ Service worker registration"
    else
        echo "   ⚠️  Missing: Service worker registration"
        WARNINGS+=("index.html missing: Service worker registration")
    fi
    
    if grep -q 'theme-color' "$INDEX_PATH"; then
        echo "   ✅ Theme color meta tag"
    else
        echo "   ⚠️  Missing: Theme color meta tag"
        WARNINGS+=("index.html missing: Theme color meta tag")
    fi
    
    if grep -q 'viewport' "$INDEX_PATH"; then
        echo "   ✅ Viewport meta tag"
    else
        echo "   ⚠️  Missing: Viewport meta tag"
        WARNINGS+=("index.html missing: Viewport meta tag")
    fi
else
    echo "   ❌ index.html not found"
    ERRORS+=("index.html not found")
fi

echo ""

# Summary
echo "========================================="
echo "Verification Summary"
echo "========================================="
echo ""

if [ ${#ERRORS[@]} -eq 0 ]; then
    echo "✅ All required checks passed!"
else
    echo "❌ Found ${#ERRORS[@]} error(s):"
    for error in "${ERRORS[@]}"; do
        echo "   - $error"
    done
fi

if [ ${#WARNINGS[@]} -gt 0 ]; then
    echo ""
    echo "⚠️  Found ${#WARNINGS[@]} warning(s):"
    for warning in "${WARNINGS[@]}"; do
        echo "   - $warning"
    done
fi

echo ""
echo "Files checked: ${#PASSED[@]}"
echo ""

# Exit with error code if strict mode and errors found
if [ "$STRICT" = true ] && [ ${#ERRORS[@]} -gt 0 ]; then
    echo "Strict mode: Exiting with error code"
    exit 1
fi

if [ ${#ERRORS[@]} -eq 0 ]; then
    echo "✅ Build verification complete!"
    exit 0
else
    echo "❌ Build verification failed!"
    exit 1
fi
