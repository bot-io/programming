#!/bin/bash
# Deployment Verification Script for Linux/Mac
# Verifies that the web build is ready for deployment
#
# Usage:
#   ./verify_deployment.sh                    # Verify build output
#   ./verify_deployment.sh --platform netlify  # Verify for specific platform
#   ./verify_deployment.sh --detailed          # Show detailed information

set -e

PLATFORM="all"
DETAILED=false
FIX_ISSUES=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --platform)
            PLATFORM="$2"
            shift 2
            ;;
        --detailed)
            DETAILED=true
            shift
            ;;
        --fix-issues)
            FIX_ISSUES=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--platform PLATFORM] [--detailed] [--fix-issues]"
            exit 1
            ;;
    esac
done

echo "========================================="
echo "Deployment Verification"
echo "========================================="

# Navigate to project root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
cd "$PROJECT_ROOT"

BUILD_OUTPUT="$PROJECT_ROOT/build/web"
ISSUES=()
WARNINGS=()

# Check if build output exists
if [ ! -d "$BUILD_OUTPUT" ]; then
    echo ""
    echo "❌ Build output not found: $BUILD_OUTPUT"
    echo "   Run 'flutter build web --release' first"
    exit 1
fi

echo ""
echo "Build Output: $BUILD_OUTPUT"
echo ""

# 1. Check Essential Files
echo "1. Checking Essential Files..."
ESSENTIAL_FILES=(
    "index.html:true:Main HTML file"
    "manifest.json:true:PWA manifest"
    "flutter.js:true:Flutter runtime"
    "main.dart.js:true:Main application code"
    "flutter_service_worker.js:true:Service worker"
)

for file_info in "${ESSENTIAL_FILES[@]}"; do
    FILE_NAME="${file_info%%:*}"
    REQUIRED="${file_info#*:}"
    REQUIRED="${REQUIRED%%:*}"
    DESCRIPTION="${file_info##*:}"
    FILE_PATH="$BUILD_OUTPUT/$FILE_NAME"
    
    if [ -f "$FILE_PATH" ]; then
        SIZE=$(du -h "$FILE_PATH" | cut -f1)
        echo "   ✅ $FILE_NAME ($SIZE)"
        if [ "$DETAILED" = true ]; then
            echo "      $DESCRIPTION"
        fi
    else
        if [ "$REQUIRED" = "true" ]; then
            echo "   ❌ $FILE_NAME - MISSING (Required)"
            ISSUES+=("Missing required file: $FILE_NAME")
        else
            echo "   ⚠️  $FILE_NAME - MISSING (Optional)"
            WARNINGS+=("Missing optional file: $FILE_NAME")
        fi
    fi
done

# 2. Verify PWA Manifest
echo ""
echo "2. Verifying PWA Manifest..."
MANIFEST_PATH="$BUILD_OUTPUT/manifest.json"
if [ -f "$MANIFEST_PATH" ]; then
    if command -v jq &> /dev/null; then
        REQUIRED_FIELDS=("name" "short_name" "start_url" "display" "icons" "theme_color" "background_color")
        for field in "${REQUIRED_FIELDS[@]}"; do
            if jq -e ".$field" "$MANIFEST_PATH" > /dev/null 2>&1; then
                if [ "$field" = "icons" ]; then
                    ICON_COUNT=$(jq '.icons | length' "$MANIFEST_PATH")
                    echo "   ✅ $field: $ICON_COUNT icons"
                else
                    VALUE=$(jq -r ".$field" "$MANIFEST_PATH")
                    echo "   ✅ $field: $VALUE"
                fi
            else
                echo "   ❌ Missing field: $field"
                ISSUES+=("manifest.json missing field: $field")
            fi
        done
        
        # Check icon sizes
        if jq -e '.icons[] | select(.sizes | contains("192x192"))' "$MANIFEST_PATH" > /dev/null 2>&1 && \
           jq -e '.icons[] | select(.sizes | contains("512x512"))' "$MANIFEST_PATH" > /dev/null 2>&1; then
            echo "   ✅ Required icon sizes present (192x192, 512x512)"
        else
            echo "   ❌ Missing required icon sizes"
            ISSUES+=("manifest.json missing required icon sizes")
        fi
        
        # Check display mode
        DISPLAY_MODE=$(jq -r ".display" "$MANIFEST_PATH")
        case "$DISPLAY_MODE" in
            standalone|fullscreen|minimal-ui|browser)
                echo "   ✅ Display mode: $DISPLAY_MODE"
                ;;
            *)
                echo "   ⚠️  Invalid display mode: $DISPLAY_MODE"
                WARNINGS+=("manifest.json has invalid display mode")
                ;;
        esac
    else
        echo "   ⚠️  jq not installed, skipping detailed manifest validation"
        echo "   Install jq for detailed validation: sudo apt-get install jq"
        WARNINGS+=("jq not installed for manifest validation")
    fi
else
    echo "   ❌ manifest.json not found"
    ISSUES+=("manifest.json not found")
fi

# 3. Verify Icons
echo ""
echo "3. Verifying PWA Icons..."
ICON_DIR="$BUILD_OUTPUT/icons"
if [ -d "$ICON_DIR" ]; then
    REQUIRED_ICONS=("icon-192x192.png" "icon-512x512.png")
    for icon in "${REQUIRED_ICONS[@]}"; do
        ICON_PATH="$ICON_DIR/$icon"
        if [ -f "$ICON_PATH" ]; then
            SIZE=$(du -h "$ICON_PATH" | cut -f1)
            echo "   ✅ $icon ($SIZE)"
        else
            echo "   ❌ $icon - MISSING"
            ISSUES+=("Missing icon: $icon")
        fi
    done
else
    echo "   ❌ Icons directory not found"
    ISSUES+=("Icons directory not found")
fi

# 4. Verify Service Worker
echo ""
echo "4. Verifying Service Worker..."
SW_PATH="$BUILD_OUTPUT/flutter_service_worker.js"
if [ -f "$SW_PATH" ]; then
    if grep -q "serviceWorkerVersion\|RESOURCES\|CACHE_NAME" "$SW_PATH"; then
        echo "   ✅ Service worker structure valid"
    else
        echo "   ⚠️  Service worker may be incomplete"
        WARNINGS+=("Service worker structure may be incomplete")
    fi
    
    # Check index.html for service worker registration
    INDEX_PATH="$BUILD_OUTPUT/index.html"
    if [ -f "$INDEX_PATH" ]; then
        if grep -q "flutter_service_worker\|service.*worker" "$INDEX_PATH"; then
            echo "   ✅ Service worker referenced in index.html"
        else
            echo "   ⚠️  Service worker may not be registered"
            WARNINGS+=("Service worker may not be registered in index.html")
        fi
    fi
else
    echo "   ❌ Service worker not found"
    ISSUES+=("Service worker not found")
fi

# 5. Check Build Size
echo ""
echo "5. Checking Build Size..."
BUILD_SIZE=$(du -sh "$BUILD_OUTPUT" | cut -f1)
echo "   Total build size: $BUILD_SIZE"

MAIN_JS_PATH="$BUILD_OUTPUT/main.dart.js"
if [ -f "$MAIN_JS_PATH" ]; then
    MAIN_JS_SIZE=$(du -h "$MAIN_JS_PATH" | cut -f1)
    MAIN_JS_SIZE_MB=$(du -m "$MAIN_JS_PATH" | cut -f1)
    echo "   main.dart.js: $MAIN_JS_SIZE"
    
    if [ "$MAIN_JS_SIZE_MB" -gt 5 ]; then
        echo "   ⚠️  main.dart.js is large (>5MB)"
        WARNINGS+=("main.dart.js is large ($MAIN_JS_SIZE_MB MB)")
    else
        echo "   ✅ main.dart.js size is reasonable"
    fi
fi

# 6. Platform-Specific Checks
echo ""
echo "6. Platform-Specific Checks..."

if [ "$PLATFORM" = "all" ] || [ "$PLATFORM" = "github-pages" ]; then
    echo "   GitHub Pages:"
    NOJEKYLL_PATH="$BUILD_OUTPUT/.nojekyll"
    if [ -f "$NOJEKYLL_PATH" ]; then
        echo "      ✅ .nojekyll present"
    else
        echo "      ⚠️  .nojekyll missing (recommended)"
        if [ "$FIX_ISSUES" = true ]; then
            touch "$NOJEKYLL_PATH"
            echo "      ✅ Created .nojekyll"
        else
            WARNINGS+=("GitHub Pages: .nojekyll missing")
        fi
    fi
    
    CUSTOM_404_PATH="$BUILD_OUTPUT/404.html"
    if [ -f "$CUSTOM_404_PATH" ]; then
        echo "      ✅ 404.html present"
    else
        echo "      ⚠️  404.html missing (recommended)"
        if [ "$FIX_ISSUES" = true ]; then
            INDEX_PATH="$BUILD_OUTPUT/index.html"
            if [ -f "$INDEX_PATH" ]; then
                cp "$INDEX_PATH" "$CUSTOM_404_PATH"
                echo "      ✅ Created 404.html from index.html"
            fi
        else
            WARNINGS+=("GitHub Pages: 404.html missing")
        fi
    fi
fi

if [ "$PLATFORM" = "all" ] || [ "$PLATFORM" = "netlify" ]; then
    echo "   Netlify:"
    NETLIFY_TOML="$PROJECT_ROOT/netlify.toml"
    if [ -f "$NETLIFY_TOML" ]; then
        echo "      ✅ netlify.toml present"
    else
        echo "      ⚠️  netlify.toml missing (recommended)"
        WARNINGS+=("Netlify: netlify.toml missing")
    fi
    
    HEADERS_FILE="$PROJECT_ROOT/web/_headers"
    if [ -f "$HEADERS_FILE" ]; then
        echo "      ✅ _headers file present"
    else
        echo "      ⚠️  _headers file missing (optional)"
    fi
fi

if [ "$PLATFORM" = "all" ] || [ "$PLATFORM" = "vercel" ]; then
    echo "   Vercel:"
    VERCEL_JSON_WEB="$PROJECT_ROOT/web/vercel.json"
    VERCEL_JSON_ROOT="$PROJECT_ROOT/vercel.json"
    if [ -f "$VERCEL_JSON_WEB" ]; then
        echo "      ✅ vercel.json present (web/)"
    elif [ -f "$VERCEL_JSON_ROOT" ]; then
        echo "      ✅ vercel.json present (root)"
    else
        echo "      ⚠️  vercel.json missing (recommended)"
        WARNINGS+=("Vercel: vercel.json missing")
    fi
fi

# Summary
echo ""
echo "========================================="
echo "Verification Summary"
echo "========================================="

if [ ${#ISSUES[@]} -eq 0 ] && [ ${#WARNINGS[@]} -eq 0 ]; then
    echo ""
    echo "✅ All checks passed! Build is ready for deployment."
    exit 0
else
    if [ ${#ISSUES[@]} -gt 0 ]; then
        echo ""
        echo "❌ Issues found (${#ISSUES[@]}):"
        for issue in "${ISSUES[@]}"; do
            echo "   - $issue"
        done
    fi
    
    if [ ${#WARNINGS[@]} -gt 0 ]; then
        echo ""
        echo "⚠️  Warnings (${#WARNINGS[@]}):"
        for warning in "${WARNINGS[@]}"; do
            echo "   - $warning"
        done
    fi
    
    if [ ${#ISSUES[@]} -gt 0 ]; then
        echo ""
        echo "❌ Build is NOT ready for deployment. Fix issues above."
        exit 1
    else
        echo ""
        echo "⚠️  Build has warnings but may be deployable."
        exit 0
    fi
fi
