#!/bin/bash
# Web Deployment Verification Script for Linux/macOS
# Verifies web build and deployment readiness
#
# Usage:
#   ./verify_web_deployment.sh                    # Verify build output
#   ./verify_web_deployment.sh -u "https://..."   # Verify deployed app
#   ./verify_web_deployment.sh -p                 # Full PWA verification

set -e

URL=""
PWA=false
BUILD_ONLY=false
VERBOSE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -u|--url)
            URL="$2"
            shift 2
            ;;
        -p|--pwa)
            PWA=true
            shift
            ;;
        --build-only)
            BUILD_ONLY=true
            shift
            ;;
        -v|--verbose)
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
echo "Web Deployment Verification"
echo "========================================="
echo ""

# Navigate to project root
SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_PATH/.." && pwd)"
cd "$PROJECT_ROOT"

ALL_CHECKS_PASSED=true
ISSUES=()

# Check 1: Build Output
echo "1. Checking Build Output..."
BUILD_OUTPUT="$PROJECT_ROOT/build/web"

if [ ! -d "$BUILD_OUTPUT" ]; then
    echo "   ❌ Build output not found: $BUILD_OUTPUT"
    echo "   Run: flutter build web --release"
    ALL_CHECKS_PASSED=false
    ISSUES+=("Build output missing")
else
    echo "   ✅ Build output exists"
    
    # Check essential files
    declare -A ESSENTIAL_FILES=(
        ["index.html"]="Main HTML file"
        ["main.dart.js"]="Main Dart JS bundle"
        ["flutter.js"]="Flutter runtime"
        ["flutter_service_worker.js"]="Service worker"
        ["manifest.json"]="PWA manifest"
    )
    
    for file in "${!ESSENTIAL_FILES[@]}"; do
        FILE_PATH="$BUILD_OUTPUT/$file"
        if [ -f "$FILE_PATH" ]; then
            FILE_SIZE=$(du -h "$FILE_PATH" | cut -f1)
            echo "      ✅ $file ($FILE_SIZE)"
        else
            echo "      ❌ $file - MISSING"
            ALL_CHECKS_PASSED=false
            ISSUES+=("Missing required file: $file")
        fi
    done
fi

# Check 2: PWA Manifest
echo ""
echo "2. Verifying PWA Manifest..."
MANIFEST_PATH="$BUILD_OUTPUT/manifest.json"

if [ -f "$MANIFEST_PATH" ]; then
    if command -v jq &> /dev/null; then
        NAME=$(jq -r '.name' "$MANIFEST_PATH" 2>/dev/null || echo "")
        SHORT_NAME=$(jq -r '.short_name' "$MANIFEST_PATH" 2>/dev/null || echo "")
        START_URL=$(jq -r '.start_url' "$MANIFEST_PATH" 2>/dev/null || echo "")
        DISPLAY=$(jq -r '.display' "$MANIFEST_PATH" 2>/dev/null || echo "")
        ICON_COUNT=$(jq '.icons | length' "$MANIFEST_PATH" 2>/dev/null || echo "0")
        
        [ -n "$NAME" ] && echo "      ✅ name: $NAME" || (echo "      ❌ name: MISSING" && ALL_CHECKS_PASSED=false && ISSUES+=("Manifest missing name"))
        [ -n "$SHORT_NAME" ] && echo "      ✅ short_name: $SHORT_NAME" || (echo "      ❌ short_name: MISSING" && ALL_CHECKS_PASSED=false && ISSUES+=("Manifest missing short_name"))
        [ -n "$START_URL" ] && echo "      ✅ start_url: $START_URL" || (echo "      ❌ start_url: MISSING" && ALL_CHECKS_PASSED=false && ISSUES+=("Manifest missing start_url"))
        [ -n "$DISPLAY" ] && echo "      ✅ display: $DISPLAY" || (echo "      ❌ display: MISSING" && ALL_CHECKS_PASSED=false && ISSUES+=("Manifest missing display"))
        
        if [ "$ICON_COUNT" -gt 0 ]; then
            echo "      ✅ icons: $ICON_COUNT icons defined"
            
            # Check for required icon sizes
            HAS_192=$(jq '.icons[] | select(.sizes | contains("192"))' "$MANIFEST_PATH" 2>/dev/null | wc -l)
            HAS_512=$(jq '.icons[] | select(.sizes | contains("512"))' "$MANIFEST_PATH" 2>/dev/null | wc -l)
            
            if [ "$HAS_192" -gt 0 ] && [ "$HAS_512" -gt 0 ]; then
                echo "      ✅ Required icon sizes present (192x192, 512x512)"
            else
                echo "      ⚠️  Missing required icon sizes"
                [ "$HAS_192" -eq 0 ] && ISSUES+=("Missing 192x192 icon")
                [ "$HAS_512" -eq 0 ] && ISSUES+=("Missing 512x512 icon")
            fi
        else
            echo "      ❌ No icons defined"
            ALL_CHECKS_PASSED=false
            ISSUES+=("Manifest missing icons")
        fi
    else
        echo "      ⚠️  jq not installed, skipping manifest validation"
        echo "      Install jq for full validation: sudo apt-get install jq"
    fi
else
    echo "   ❌ manifest.json not found"
    ALL_CHECKS_PASSED=false
    ISSUES+=("Manifest file missing")
fi

# Check 3: Service Worker
echo ""
echo "3. Verifying Service Worker..."
SW_PATH="$BUILD_OUTPUT/flutter_service_worker.js"

if [ -f "$SW_PATH" ]; then
    echo "   ✅ Service worker file exists"
    
    # Check if service worker is referenced in index.html
    INDEX_PATH="$BUILD_OUTPUT/index.html"
    if [ -f "$INDEX_PATH" ]; then
        if grep -q "flutter_service_worker\|service.*worker" "$INDEX_PATH"; then
            echo "   ✅ Service worker referenced in index.html"
        else
            echo "   ⚠️  Service worker may not be registered"
            ISSUES+=("Service worker not referenced in index.html")
        fi
    fi
else
    echo "   ❌ Service worker not found"
    ALL_CHECKS_PASSED=false
    ISSUES+=("Service worker missing")
fi

# Check 4: Icons
echo ""
echo "4. Verifying Icons..."
ICONS_DIR="$BUILD_OUTPUT/icons"

if [ -d "$ICONS_DIR" ]; then
    REQUIRED_ICONS=("icon-192x192.png" "icon-512x512.png")
    FOUND_ICONS=0
    
    for icon in "${REQUIRED_ICONS[@]}"; do
        ICON_PATH="$ICONS_DIR/$icon"
        if [ -f "$ICON_PATH" ]; then
            echo "      ✅ $icon"
            FOUND_ICONS=$((FOUND_ICONS + 1))
        else
            echo "      ❌ $icon - MISSING"
            ISSUES+=("Missing icon: $icon")
        fi
    done
    
    if [ $FOUND_ICONS -eq ${#REQUIRED_ICONS[@]} ]; then
        echo "   ✅ Required icons present"
    else
        echo "   ⚠️  Some icons missing"
        ALL_CHECKS_PASSED=false
    fi
else
    echo "   ❌ Icons directory not found"
    ALL_CHECKS_PASSED=false
    ISSUES+=("Icons directory missing")
fi

# Check 5: Build Size
echo ""
echo "5. Analyzing Build Size..."
if [ -d "$BUILD_OUTPUT" ]; then
    BUILD_SIZE=$(du -sh "$BUILD_OUTPUT" | cut -f1)
    echo "   Total build size: $BUILD_SIZE"
    
    # Check main.dart.js size
    MAIN_JS_PATH="$BUILD_OUTPUT/main.dart.js"
    if [ -f "$MAIN_JS_PATH" ]; then
        MAIN_JS_SIZE=$(du -h "$MAIN_JS_PATH" | cut -f1)
        MAIN_JS_SIZE_MB=$(du -m "$MAIN_JS_PATH" | cut -f1)
        echo "   main.dart.js: $MAIN_JS_SIZE"
        
        if [ "$MAIN_JS_SIZE_MB" -gt 5 ]; then
            echo "   ⚠️  Large bundle size detected (>5MB)"
            ISSUES+=("Large bundle size: ${MAIN_JS_SIZE_MB}MB")
        else
            echo "   ✅ Bundle size is reasonable"
        fi
    fi
fi

# Check 6: Deployment Files
echo ""
echo "6. Checking Deployment Configuration..."

declare -A DEPLOYMENT_FILES=(
    ["netlify.toml"]="Netlify"
    ["web/vercel.json"]="Vercel"
    ["web/_headers"]="Netlify"
    ["web/404.html"]="GitHub Pages"
    ["web/.nojekyll"]="GitHub Pages"
)

for file in "${!DEPLOYMENT_FILES[@]}"; do
    FILE_PATH="$PROJECT_ROOT/$file"
    PLATFORM="${DEPLOYMENT_FILES[$file]}"
    if [ -f "$FILE_PATH" ]; then
        echo "      ✅ $file ($PLATFORM)"
    else
        echo "      ⚠️  $file - Not found (optional)"
    fi
done

# Check 7: URL Verification (if URL provided)
if [ -n "$URL" ] && [ "$BUILD_ONLY" = false ]; then
    echo ""
    echo "7. Verifying Deployed App..."
    echo "   URL: $URL"
    
    if curl -s -f -o /dev/null -w "%{http_code}" "$URL" | grep -q "200"; then
        echo "   ✅ App is accessible"
        
        # Check for manifest
        MANIFEST_URL="${URL%/}/manifest.json"
        if curl -s -f -o /dev/null -w "%{http_code}" "$MANIFEST_URL" | grep -q "200"; then
            echo "   ✅ Manifest is accessible"
        else
            echo "   ⚠️  Manifest not accessible"
        fi
        
        # Check HTTPS
        if [[ "$URL" == https://* ]]; then
            echo "   ✅ Served over HTTPS (required for PWA)"
        else
            echo "   ⚠️  Not served over HTTPS (PWA requires HTTPS)"
            ISSUES+=("App not served over HTTPS")
        fi
    else
        echo "   ❌ App not accessible"
        ALL_CHECKS_PASSED=false
        ISSUES+=("Failed to access deployed app")
    fi
fi

# Summary
echo ""
echo "========================================="
if [ "$ALL_CHECKS_PASSED" = true ]; then
    echo "✅ All Checks Passed!"
    echo "========================================="
    echo ""
    echo "Your web app is ready for deployment!"
else
    echo "⚠️  Some Issues Found"
    echo "========================================="
    echo ""
    echo "Issues:"
    for issue in "${ISSUES[@]}"; do
        echo "  - $issue"
    done
    echo ""
    echo "Please fix these issues before deploying."
fi

echo ""
echo "Next Steps:"
echo "1. Test locally: cd build/web && python3 -m http.server 8000"
echo "2. Deploy using:"
echo "   - GitHub Pages: scripts/deploy_github_pages.sh"
echo "   - Netlify: scripts/deploy_netlify.sh"
echo "   - Vercel: scripts/deploy_vercel.sh"
echo "3. Verify PWA functionality after deployment"

if [ "$ALL_CHECKS_PASSED" = false ]; then
    exit 1
fi
