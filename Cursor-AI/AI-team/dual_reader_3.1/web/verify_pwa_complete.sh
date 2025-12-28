#!/bin/bash
# PWA Verification Script for Dual Reader 3.1
# This script verifies that the PWA is properly configured and installable

set -e

BUILD_DIR="${1:-build/web}"
DETAILED="${2:-false}"

echo "🔍 Verifying PWA Configuration..."
echo ""

ALL_CHECKS_PASSED=true

# Check if build directory exists
if [ ! -d "$BUILD_DIR" ]; then
    echo "❌ Build directory not found: $BUILD_DIR"
    echo "   Run build first: bash web/build_web.sh"
    exit 1
fi

echo "📁 Build Directory: $BUILD_DIR"
echo ""

# 1. Check manifest.json
echo "1️⃣  Checking manifest.json..."
MANIFEST_PATH="$BUILD_DIR/manifest.json"
if [ -f "$MANIFEST_PATH" ]; then
    if command -v jq &> /dev/null; then
        MANIFEST_NAME=$(jq -r '.name' "$MANIFEST_PATH" 2>/dev/null || echo "")
        MANIFEST_SHORT_NAME=$(jq -r '.short_name' "$MANIFEST_PATH" 2>/dev/null || echo "")
        MANIFEST_START_URL=$(jq -r '.start_url' "$MANIFEST_PATH" 2>/dev/null || echo "")
        MANIFEST_DISPLAY=$(jq -r '.display' "$MANIFEST_PATH" 2>/dev/null || echo "")
        MANIFEST_THEME_COLOR=$(jq -r '.theme_color' "$MANIFEST_PATH" 2>/dev/null || echo "")
        MANIFEST_BG_COLOR=$(jq -r '.background_color' "$MANIFEST_PATH" 2>/dev/null || echo "")
        ICON_COUNT=$(jq '.icons | length' "$MANIFEST_PATH" 2>/dev/null || echo "0")
        
        # Check required fields
        [ -z "$MANIFEST_NAME" ] && echo "   ❌ Missing required field: name" && ALL_CHECKS_PASSED=false
        [ -z "$MANIFEST_SHORT_NAME" ] && echo "   ❌ Missing required field: short_name" && ALL_CHECKS_PASSED=false
        [ -z "$MANIFEST_START_URL" ] && echo "   ❌ Missing required field: start_url" && ALL_CHECKS_PASSED=false
        [ -z "$MANIFEST_DISPLAY" ] && echo "   ❌ Missing required field: display" && ALL_CHECKS_PASSED=false
        
        if [ "$DETAILED" = "true" ] || [ -n "$MANIFEST_NAME" ]; then
            [ -n "$MANIFEST_NAME" ] && echo "   ✅ name: $MANIFEST_NAME"
        fi
        if [ "$DETAILED" = "true" ] || [ -n "$MANIFEST_SHORT_NAME" ]; then
            [ -n "$MANIFEST_SHORT_NAME" ] && echo "   ✅ short_name: $MANIFEST_SHORT_NAME"
        fi
        if [ "$DETAILED" = "true" ] || [ -n "$MANIFEST_START_URL" ]; then
            [ -n "$MANIFEST_START_URL" ] && echo "   ✅ start_url: $MANIFEST_START_URL"
        fi
        if [ "$DETAILED" = "true" ] || [ -n "$MANIFEST_DISPLAY" ]; then
            [ -n "$MANIFEST_DISPLAY" ] && echo "   ✅ display: $MANIFEST_DISPLAY"
        fi
        
        # Check icons
        if [ "$ICON_COUNT" -gt 0 ]; then
            echo "   ✅ Icons: $ICON_COUNT icon(s) defined"
            
            # Check for required icon sizes
            if jq -e '.icons[] | select(.sizes == "192x192" or .sizes == "192x192 ")' "$MANIFEST_PATH" > /dev/null 2>&1; then
                [ "$DETAILED" = "true" ] && echo "   ✅ Icon size 192x192 found"
            else
                echo "   ⚠️  Icon size 192x192 not found (recommended)"
            fi
            
            if jq -e '.icons[] | select(.sizes == "512x512" or .sizes == "512x512 ")' "$MANIFEST_PATH" > /dev/null 2>&1; then
                [ "$DETAILED" = "true" ] && echo "   ✅ Icon size 512x512 found"
            else
                echo "   ⚠️  Icon size 512x512 not found (recommended)"
            fi
        else
            echo "   ❌ No icons defined in manifest"
            ALL_CHECKS_PASSED=false
        fi
        
        echo "   ✅ manifest.json is valid"
    else
        echo "   ⚠️  jq not found. Install jq for detailed manifest validation."
        echo "   ✅ manifest.json file exists"
    fi
else
    echo "   ❌ manifest.json not found"
    ALL_CHECKS_PASSED=false
fi

echo ""

# 2. Check service worker
echo "2️⃣  Checking service worker..."
SW_PATH="$BUILD_DIR/flutter_service_worker.js"
if [ -f "$SW_PATH" ]; then
    SW_SIZE=$(stat -f%z "$SW_PATH" 2>/dev/null || stat -c%s "$SW_PATH" 2>/dev/null || echo "0")
    SW_SIZE_KB=$((SW_SIZE / 1024))
    echo "   ✅ flutter_service_worker.js found ($SW_SIZE_KB KB)"
    
    # Check if service worker is referenced in index.html
    INDEX_PATH="$BUILD_DIR/index.html"
    if [ -f "$INDEX_PATH" ]; then
        if grep -q "flutter_service_worker\|service.*worker" "$INDEX_PATH" 2>/dev/null; then
            echo "   ✅ Service worker referenced in index.html"
        else
            echo "   ⚠️  Service worker not referenced in index.html"
        fi
    fi
else
    echo "   ❌ flutter_service_worker.js not found"
    echo "      Flutter should generate this automatically during build"
    ALL_CHECKS_PASSED=false
fi

echo ""

# 3. Check PWA icons
echo "3️⃣  Checking PWA icons..."
ICONS_DIR="$BUILD_DIR/icons"
ICONS_FOUND=0

check_icon() {
    local icon_file="$1"
    local required="$2"
    local icon_path="$ICONS_DIR/$icon_file"
    
    if [ -f "$icon_path" ]; then
        ICONS_FOUND=$((ICONS_FOUND + 1))
        if [ "$DETAILED" = "true" ] || [ "$required" = "true" ]; then
            local icon_size=$(stat -f%z "$icon_path" 2>/dev/null || stat -c%s "$icon_path" 2>/dev/null || echo "0")
            local icon_size_kb=$((icon_size / 1024))
            echo "   ✅ $icon_file ($icon_size_kb KB)"
        fi
        return 0
    else
        if [ "$required" = "true" ]; then
            echo "   ❌ Required icon not found: $icon_file"
            ALL_CHECKS_PASSED=false
            return 1
        else
            [ "$DETAILED" = "true" ] && echo "   ⚠️  Optional icon not found: $icon_file"
            return 1
        fi
    fi
}

check_icon "icon-192x192.png" "true"
check_icon "icon-512x512.png" "true"
check_icon "icon-16x16.png" "false"
check_icon "icon-32x32.png" "false"

if [ $ICONS_FOUND -ge 2 ]; then
    echo "   ✅ Found $ICONS_FOUND icon(s)"
else
    echo "   ⚠️  Only $ICONS_FOUND icon(s) found (at least 2 recommended)"
fi

echo ""

# 4. Check index.html
echo "4️⃣  Checking index.html..."
INDEX_PATH="$BUILD_DIR/index.html"
if [ -f "$INDEX_PATH" ]; then
    INDEX_CONTENT=$(cat "$INDEX_PATH")
    
    if echo "$INDEX_CONTENT" | grep -q 'rel="manifest"'; then
        [ "$DETAILED" = "true" ] && echo "   ✅ manifest.json link found"
    else
        echo "   ❌ manifest.json link not found"
        ALL_CHECKS_PASSED=false
    fi
    
    if echo "$INDEX_CONTENT" | grep -q 'name="theme-color"'; then
        [ "$DETAILED" = "true" ] && echo "   ✅ theme-color meta found"
    else
        echo "   ❌ theme-color meta not found"
        ALL_CHECKS_PASSED=false
    fi
    
    if echo "$INDEX_CONTENT" | grep -q 'name="viewport"'; then
        [ "$DETAILED" = "true" ] && echo "   ✅ viewport meta found"
    else
        echo "   ❌ viewport meta not found"
        ALL_CHECKS_PASSED=false
    fi
    
    if echo "$INDEX_CONTENT" | grep -q 'rel="apple-touch-icon"'; then
        [ "$DETAILED" = "true" ] && echo "   ✅ apple-touch-icon found"
    else
        [ "$DETAILED" = "true" ] && echo "   ⚠️  apple-touch-icon not found (optional)"
    fi
    
    echo "   ✅ index.html structure looks good"
else
    echo "   ❌ index.html not found"
    ALL_CHECKS_PASSED=false
fi

echo ""

# 5. Check HTTPS requirement (informational)
echo "5️⃣  PWA Requirements (Informational)..."
echo "   ℹ️  PWA requires HTTPS in production"
echo "   ℹ️  Service worker requires secure context"
echo "   ℹ️  Localhost is considered secure for testing"

echo ""

# Summary
echo "📊 Verification Summary"
echo ""

if [ "$ALL_CHECKS_PASSED" = true ]; then
    echo "✅ All critical PWA checks passed!"
    echo ""
    echo "📝 Next Steps:"
    echo "   1. Test locally: cd $BUILD_DIR && python3 -m http.server 8000"
    echo "   2. Open browser: http://localhost:8000"
    echo "   3. Open Chrome DevTools → Application → Manifest"
    echo "   4. Check 'Add to Home Screen' prompt"
    echo "   5. Test offline functionality"
    echo "   6. Deploy to production platform"
    exit 0
else
    echo "❌ Some PWA checks failed!"
    echo ""
    echo "💡 Fix the issues above and rebuild:"
    echo "   bash web/build_web.sh"
    exit 1
fi
