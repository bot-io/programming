#!/bin/bash
# Deployment Verification Script for Dual Reader 3.1 Web App
# This script verifies that the web build is ready for deployment

set -e

BUILD_DIR="${1:-build/web}"
CHECK_PWA=true
CHECK_FILES=true
CHECK_MANIFEST=true
CHECK_SERVICE_WORKER=true
CHECK_ICONS=true
CHECK_SIZE=true

# Parse arguments
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
        --no-files)
            CHECK_FILES=false
            shift
            ;;
        --no-manifest)
            CHECK_MANIFEST=false
            shift
            ;;
        --no-service-worker)
            CHECK_SERVICE_WORKER=false
            shift
            ;;
        --no-icons)
            CHECK_ICONS=false
            shift
            ;;
        --no-size)
            CHECK_SIZE=false
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS] [BUILD_DIR]"
            echo ""
            echo "Options:"
            echo "  --build-dir DIR      Build directory (default: build/web)"
            echo "  --no-pwa             Skip PWA checks"
            echo "  --no-files           Skip file checks"
            echo "  --no-manifest        Skip manifest checks"
            echo "  --no-service-worker  Skip service worker checks"
            echo "  --no-icons           Skip icon checks"
            echo "  --no-size            Skip size checks"
            echo "  -h, --help           Show this help"
            exit 0
            ;;
        *)
            BUILD_DIR="$1"
            shift
            ;;
    esac
done

ALL_CHECKS_PASSED=true

echo "🔍 Verifying Web Build for Deployment..."
echo ""

# Check if build directory exists
if [ ! -d "$BUILD_DIR" ]; then
    echo "❌ Build directory not found: $BUILD_DIR"
    echo "   Run 'flutter build web --release' first"
    exit 1
fi

echo "✅ Build directory found: $BUILD_DIR"
echo ""

# Check required files
if [ "$CHECK_FILES" = true ]; then
    echo "📄 Checking Required Files..."
    
    REQUIRED_FILES=(
        "index.html:true"
        "main.dart.js:true"
        "flutter.js:true"
        "manifest.json:$CHECK_PWA"
        "flutter_service_worker.js:$CHECK_PWA"
    )
    
    for FILE_INFO in "${REQUIRED_FILES[@]}"; do
        IFS=':' read -r FILE REQUIRED <<< "$FILE_INFO"
        FILE_PATH="$BUILD_DIR/$FILE"
        
        if [ "$REQUIRED" = "true" ]; then
            if [ -f "$FILE_PATH" ]; then
                if command -v stat &> /dev/null; then
                    FILE_SIZE=$(stat -f%z "$FILE_PATH" 2>/dev/null || stat -c%s "$FILE_PATH" 2>/dev/null || echo "0")
                    FILE_SIZE_KB=$((FILE_SIZE / 1024))
                    echo "   ✅ $FILE ($FILE_SIZE_KB KB)"
                else
                    echo "   ✅ $FILE"
                fi
            else
                echo "   ❌ $FILE - NOT FOUND"
                ALL_CHECKS_PASSED=false
            fi
        else
            if [ -f "$FILE_PATH" ]; then
                echo "   ✅ $FILE (optional)"
            fi
        fi
    done
    
    echo ""
fi

# Check PWA manifest
if [ "$CHECK_MANIFEST" = true ] && [ "$CHECK_PWA" = true ]; then
    echo "📱 Checking PWA Manifest..."
    
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
            
            if [ "$ICON_COUNT" -ge 2 ]; then
                echo "   ✅ icons: $ICON_COUNT icons"
            else
                echo "   ⚠️  icons: Only $ICON_COUNT icon(s) (minimum 2 recommended)"
            fi
            
            # Check for required icon sizes
            if [ -f "$BUILD_DIR/icons/icon-192x192.png" ]; then
                echo "   ✅ Icon size 192x192 found"
            else
                echo "   ⚠️  Icon size 192x192 missing (recommended)"
            fi
            
            if [ -f "$BUILD_DIR/icons/icon-512x512.png" ]; then
                echo "   ✅ Icon size 512x512 found"
            else
                echo "   ⚠️  Icon size 512x512 missing (recommended)"
            fi
        else
            echo "   ⚠️  jq not found. Install jq for manifest validation."
            echo "   ✅ manifest.json exists"
        fi
    else
        echo "   ❌ manifest.json not found"
        ALL_CHECKS_PASSED=false
    fi
    
    echo ""
fi

# Check service worker
if [ "$CHECK_SERVICE_WORKER" = true ] && [ "$CHECK_PWA" = true ]; then
    echo "⚙️  Checking Service Worker..."
    
    SW_PATH="$BUILD_DIR/flutter_service_worker.js"
    if [ -f "$SW_PATH" ]; then
        # Check for service worker registration in index.html
        INDEX_PATH="$BUILD_DIR/index.html"
        if [ -f "$INDEX_PATH" ]; then
            if grep -q "flutter_service_worker.js\|serviceWorker.register" "$INDEX_PATH" 2>/dev/null; then
                echo "   ✅ Service worker registration found in index.html"
            else
                echo "   ⚠️  Service worker registration not found in index.html"
            fi
        fi
        
        if command -v stat &> /dev/null; then
            SW_SIZE=$(stat -f%z "$SW_PATH" 2>/dev/null || stat -c%s "$SW_PATH" 2>/dev/null || echo "0")
            SW_SIZE_KB=$((SW_SIZE / 1024))
            echo "   ✅ flutter_service_worker.js found ($SW_SIZE_KB KB)"
        else
            echo "   ✅ flutter_service_worker.js found"
        fi
    else
        echo "   ⚠️  flutter_service_worker.js not found (may be generated during build)"
    fi
    
    echo ""
fi

# Check icons
if [ "$CHECK_ICONS" = true ] && [ "$CHECK_PWA" = true ]; then
    echo "🖼️  Checking PWA Icons..."
    
    ICONS_DIR="$BUILD_DIR/icons"
    if [ -d "$ICONS_DIR" ]; then
        ICON_COUNT=$(find "$ICONS_DIR" -name "icon-*.png" 2>/dev/null | wc -l)
        
        if [ "$ICON_COUNT" -gt 0 ]; then
            echo "   ✅ Found $ICON_COUNT icon file(s)"
            
            if [ -f "$ICONS_DIR/icon-192x192.png" ]; then
                echo "   ✅ Icon 192x192 found"
            else
                echo "   ⚠️  Icon 192x192 missing (recommended)"
            fi
            
            if [ -f "$ICONS_DIR/icon-512x512.png" ]; then
                echo "   ✅ Icon 512x512 found"
            else
                echo "   ⚠️  Icon 512x512 missing (recommended)"
            fi
        else
            echo "   ⚠️  No icons found in icons/ directory"
        fi
    else
        echo "   ⚠️  Icons directory not found"
    fi
    
    echo ""
fi

# Check build size
if [ "$CHECK_SIZE" = true ]; then
    echo "📊 Build Size Analysis..."
    
    if command -v du &> /dev/null; then
        BUILD_SIZE=$(du -sk "$BUILD_DIR" 2>/dev/null | cut -f1)
        BUILD_SIZE_MB=$((BUILD_SIZE / 1024))
        echo "   Total size: $BUILD_SIZE_MB MB"
    fi
    
    # Check main.dart.js size
    MAIN_JS_PATH="$BUILD_DIR/main.dart.js"
    if [ -f "$MAIN_JS_PATH" ]; then
        if command -v stat &> /dev/null; then
            MAIN_JS_SIZE=$(stat -f%z "$MAIN_JS_PATH" 2>/dev/null || stat -c%s "$MAIN_JS_PATH" 2>/dev/null || echo "0")
            MAIN_JS_SIZE_MB=$((MAIN_JS_SIZE / 1048576))
            echo "   main.dart.js: $MAIN_JS_SIZE_MB MB"
            
            if [ "$MAIN_JS_SIZE_MB" -gt 5 ]; then
                echo "   ⚠️  Large bundle size detected (>5MB). Consider optimization."
            elif [ "$MAIN_JS_SIZE_MB" -gt 3 ]; then
                echo "   ⚠️  Bundle size is moderate (3-5MB). Monitor performance."
            else
                echo "   ✅ Bundle size is reasonable (<3MB)"
            fi
        fi
    fi
    
    # Check for large assets
    LARGE_ASSETS=$(find "$BUILD_DIR" -type f -size +1M 2>/dev/null | head -5)
    if [ -n "$LARGE_ASSETS" ]; then
        echo "   ⚠️  Large assets found:"
        echo "$LARGE_ASSETS" | while read -r asset; do
            if command -v stat &> /dev/null; then
                ASSET_SIZE=$(stat -f%z "$asset" 2>/dev/null || stat -c%s "$asset" 2>/dev/null || echo "0")
                ASSET_SIZE_MB=$((ASSET_SIZE / 1048576))
                ASSET_NAME=$(basename "$asset")
                echo "      - $ASSET_NAME : $ASSET_SIZE_MB MB"
            fi
        done
    else
        echo "   ✅ No unusually large assets detected"
    fi
    
    echo ""
fi

# Check for common issues
echo "🔍 Checking for Common Issues..."

# Check for source maps
SOURCE_MAPS=$(find "$BUILD_DIR" -name "*.js.map" 2>/dev/null | wc -l)
if [ "$SOURCE_MAPS" -gt 0 ]; then
    echo "   ⚠️  Source maps found. Consider removing for production."
else
    echo "   ✅ No source maps found (good for production)"
fi

# Check for .nojekyll (GitHub Pages)
if [ -f "$BUILD_DIR/.nojekyll" ]; then
    echo "   ✅ .nojekyll file found (GitHub Pages ready)"
else
    echo "   ⚠️  .nojekyll file not found (needed for GitHub Pages)"
fi

# Check for 404.html (GitHub Pages)
if [ -f "$BUILD_DIR/404.html" ]; then
    echo "   ✅ 404.html found (GitHub Pages SPA routing)"
else
    echo "   ⚠️  404.html not found (needed for GitHub Pages SPA routing)"
fi

echo ""

# Summary
echo "📋 Verification Summary"
echo ""

if [ "$ALL_CHECKS_PASSED" = true ]; then
    echo "✅ All critical checks passed!"
    echo ""
    echo "📝 Next Steps:"
    echo "   1. Test locally: cd $BUILD_DIR && python3 -m http.server 8000"
    echo "   2. Verify PWA in Chrome DevTools (Application tab)"
    echo "   3. Deploy to your hosting platform"
    echo ""
    echo "✨ Build is ready for deployment!"
    exit 0
else
    echo "❌ Some checks failed. Please fix the issues above before deploying."
    exit 1
fi
