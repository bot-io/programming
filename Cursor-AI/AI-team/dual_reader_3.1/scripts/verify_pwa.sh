#!/bin/bash
# PWA Verification Script for Linux/Mac
# Verifies that the PWA is properly configured and installable
#
# Usage:
#   ./verify_pwa.sh                    # Verify PWA in build/web
#   ./verify_pwa.sh --path "custom/path" # Verify custom path
#   ./verify_pwa.sh --url "https://..."  # Verify deployed URL

set -e

PATH_TO_CHECK="build/web"
URL_TO_CHECK=""
DETAILED=false
CHECK_OFFLINE=false
CHECK_INSTALL=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --path)
            PATH_TO_CHECK="$2"
            shift 2
            ;;
        --url)
            URL_TO_CHECK="$2"
            shift 2
            ;;
        --detailed)
            DETAILED=true
            shift
            ;;
        --check-offline)
            CHECK_OFFLINE=true
            shift
            ;;
        --check-install)
            CHECK_INSTALL=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--path PATH] [--url URL] [--detailed] [--check-offline] [--check-install]"
            exit 1
            ;;
    esac
done

echo "========================================="
echo "PWA Verification"
echo "========================================="
echo ""

# Navigate to project root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
cd "$PROJECT_ROOT"

ALL_CHECKS_PASSED=true
WARNINGS=()

# If URL is provided, verify deployed PWA
if [ -n "$URL_TO_CHECK" ]; then
    echo "🌐 Verifying deployed PWA at: $URL_TO_CHECK"
    echo ""
    echo "⚠️  Note: Full PWA verification requires browser testing"
    echo "   Use Chrome DevTools → Application → Manifest for detailed checks"
    echo ""
    
    # Check if URL is accessible
    if curl -s --head --fail "$URL_TO_CHECK" > /dev/null 2>&1; then
        echo "✅ URL is accessible"
        
        # Check HTTPS
        if [[ "$URL_TO_CHECK" == https://* ]]; then
            echo "✅ HTTPS enabled (required for PWA)"
        else
            echo "⚠️  HTTPS not detected (required for PWA installation)"
            WARNINGS+=("HTTPS not enabled")
        fi
    else
        echo "❌ URL is not accessible"
        ALL_CHECKS_PASSED=false
    fi
    
    echo ""
    echo "📋 Manual Verification Steps:"
    echo "   1. Open $URL_TO_CHECK in Chrome/Edge"
    echo "   2. Open DevTools (F12) → Application → Manifest"
    echo "   3. Check for install prompt in address bar"
    echo "   4. Test offline functionality (DevTools → Network → Offline)"
    echo ""
    
    exit 0
fi

# Verify local build
BUILD_PATH="$PROJECT_ROOT/$PATH_TO_CHECK"

if [ ! -d "$BUILD_PATH" ]; then
    echo "❌ Build directory not found: $BUILD_PATH"
    echo "   Run: ./scripts/build_web.sh first"
    exit 1
fi

echo "📁 Verifying PWA in: $BUILD_PATH"
echo ""

# 1. Manifest.json Check
echo "📱 Manifest.json Check"
echo "─────────────────────────────────────────"

MANIFEST_PATH="$BUILD_PATH/manifest.json"
if [ -f "$MANIFEST_PATH" ]; then
    echo "   ✅ manifest.json found"
    
    # Check if jq is available for JSON parsing
    if command -v jq &> /dev/null; then
        # Required fields
        REQUIRED_FIELDS=("name" "short_name" "start_url" "display" "icons")
        
        for field in "${REQUIRED_FIELDS[@]}"; do
            if jq -e ".$field" "$MANIFEST_PATH" > /dev/null 2>&1; then
                if [ "$field" = "icons" ]; then
                    ICON_COUNT=$(jq '.icons | length' "$MANIFEST_PATH")
                    echo "      ✅ $field: $ICON_COUNT icons"
                else
                    VALUE=$(jq -r ".$field" "$MANIFEST_PATH")
                    echo "      ✅ $field: $VALUE"
                fi
            else
                echo "      ❌ $field - MISSING (Required)"
                ALL_CHECKS_PASSED=false
            fi
        done
        
        # Check icons
        if jq -e '.icons' "$MANIFEST_PATH" > /dev/null 2>&1; then
            echo ""
            echo "   🖼️  Icon Sizes Check"
            REQUIRED_ICON_SIZES=(192 512)
            for size in "${REQUIRED_ICON_SIZES[@]}"; do
                if jq -e ".icons[] | select(.sizes | contains(\"${size}x${size}\"))" "$MANIFEST_PATH" > /dev/null 2>&1; then
                    echo "      ✅ Icon $size"
                else
                    echo "      ❌ Icon $size - MISSING (Required for PWA)"
                    ALL_CHECKS_PASSED=false
                fi
            done
        fi
    else
        echo "   ⚠️  jq not installed, skipping detailed manifest validation"
        echo "   Install jq for detailed validation: sudo apt-get install jq"
    fi
else
    echo "   ❌ manifest.json - MISSING"
    ALL_CHECKS_PASSED=false
fi

echo ""

# 2. Service Worker Check
echo "⚙️  Service Worker Check"
echo "─────────────────────────────────────────"

SW_PATH="$BUILD_PATH/flutter_service_worker.js"
if [ -f "$SW_PATH" ]; then
    SW_SIZE=$(du -h "$SW_PATH" | cut -f1)
    echo "   ✅ flutter_service_worker.js found ($SW_SIZE)"
    
    # Check if service worker is referenced in index.html
    INDEX_PATH="$BUILD_PATH/index.html"
    if [ -f "$INDEX_PATH" ]; then
        if grep -q "flutter_service_worker\|service.*worker" "$INDEX_PATH"; then
            echo "   ✅ Service worker referenced in index.html"
        else
            echo "   ⚠️  Service worker may not be registered in index.html"
            WARNINGS+=("Service worker registration check needed")
        fi
    fi
else
    echo "   ❌ flutter_service_worker.js - MISSING"
    ALL_CHECKS_PASSED=false
fi

echo ""

# 3. Icon Files Check
echo "🖼️  Icon Files Check"
echo "─────────────────────────────────────────"

ICON_PATH="$BUILD_PATH/icons"
if [ -d "$ICON_PATH" ]; then
    echo "   ✅ icons/ directory found"
    
    REQUIRED_ICONS=(192 512)
    OPTIONAL_ICONS=(16 32 72 96 128 144 152)
    
    for size in "${REQUIRED_ICONS[@]}"; do
        ICON_FILE="$ICON_PATH/icon-${size}x${size}.png"
        if [ -f "$ICON_FILE" ]; then
            FILE_SIZE=$(du -h "$ICON_FILE" | cut -f1)
            echo "      ✅ icon-${size}x${size}.png ($FILE_SIZE)"
        else
            echo "      ❌ icon-${size}x${size}.png - MISSING (Required)"
            ALL_CHECKS_PASSED=false
        fi
    done
    
    for size in "${OPTIONAL_ICONS[@]}"; do
        ICON_FILE="$ICON_PATH/icon-${size}x${size}.png"
        if [ -f "$ICON_FILE" ]; then
            FILE_SIZE=$(du -h "$ICON_FILE" | cut -f1)
            echo "      ✅ icon-${size}x${size}.png ($FILE_SIZE)"
        fi
    done
else
    echo "   ❌ icons/ directory - MISSING"
    ALL_CHECKS_PASSED=false
fi

echo ""

# 4. Index.html PWA Configuration Check
echo "📄 Index.html PWA Configuration"
echo "─────────────────────────────────────────"

INDEX_PATH="$BUILD_PATH/index.html"
if [ -f "$INDEX_PATH" ]; then
    PWA_CHECKS=(
        "manifest\.json:Manifest link"
        "theme-color:Theme color meta tag"
        "apple-touch-icon:Apple touch icon"
        "viewport:Viewport meta tag"
    )
    
    for check in "${PWA_CHECKS[@]}"; do
        PATTERN="${check%%:*}"
        DESCRIPTION="${check##*:}"
        if grep -q "$PATTERN" "$INDEX_PATH"; then
            echo "   ✅ $DESCRIPTION"
        else
            echo "   ⚠️  $DESCRIPTION - Missing"
            WARNINGS+=("$DESCRIPTION missing")
        fi
    done
else
    echo "   ❌ index.html - MISSING"
    ALL_CHECKS_PASSED=false
fi

echo ""

# 5. Security Check
echo "🔒 Security Check"
echo "─────────────────────────────────────────"

echo "   ℹ️  HTTPS is required for PWA installation"
echo "   ℹ️  Service workers require secure context"
echo "   ℹ️  Test on HTTPS or localhost"

echo ""

# Summary
echo "========================================="
if [ "$ALL_CHECKS_PASSED" = true ]; then
    echo "✅ PWA Verification PASSED"
    echo "   PWA is properly configured!"
    
    if [ ${#WARNINGS[@]} -gt 0 ]; then
        echo ""
        echo "⚠️  Warnings:"
        for warning in "${WARNINGS[@]}"; do
            echo "   - $warning"
        done
    fi
    
    echo ""
    echo "📋 Next Steps:"
    echo "   1. Test locally: cd build/web && python3 -m http.server 8000"
    echo "   2. Open http://localhost:8000 in Chrome/Edge"
    echo "   3. Check DevTools → Application → Manifest"
    echo "   4. Test install prompt"
    echo "   5. Test offline functionality"
    echo "   6. Deploy to hosting platform"
    
    exit 0
else
    echo "❌ PWA Verification FAILED"
    echo "   Please fix the issues above before deploying"
    
    if [ ${#WARNINGS[@]} -gt 0 ]; then
        echo ""
        echo "⚠️  Warnings:"
        for warning in "${WARNINGS[@]}"; do
            echo "   - $warning"
        done
    fi
    
    exit 1
fi
