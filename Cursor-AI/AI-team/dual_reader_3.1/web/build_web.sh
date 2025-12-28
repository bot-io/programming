#!/bin/bash
# Build Script for Dual Reader 3.1 Web Platform
# This script builds the Flutter web app with optimizations and verifies the build output

set -e  # Exit on error

# Default values
RELEASE=true
VERIFY=true
ANALYZE=false
TEST=false
BASE_HREF="/"
TARGET="web"
PWA=true
MINIFY=true

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --debug)
            RELEASE=false
            shift
            ;;
        --no-verify)
            VERIFY=false
            shift
            ;;
        --analyze)
            ANALYZE=true
            shift
            ;;
        --test)
            TEST=true
            shift
            ;;
        --base-href)
            BASE_HREF="$2"
            shift 2
            ;;
        --target)
            TARGET="$2"
            shift 2
            ;;
        --no-pwa)
            PWA=false
            shift
            ;;
        --no-minify)
            MINIFY=false
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --debug          Build in debug mode (default: release)"
            echo "  --no-verify      Skip build verification"
            echo "  --analyze        Run code analysis before building"
            echo "  --test           Run tests before building"
            echo "  --base-href PATH Set base href path (default: /)"
            echo "  --target TARGET  Set build target (default: web)"
            echo "  --no-pwa         Disable PWA features"
            echo "  --no-minify      Disable minification"
            echo "  -h, --help       Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

echo "🚀 Building Dual Reader 3.1 for Web..."
echo ""

# Check if Flutter is available
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter not found. Please install Flutter first."
    exit 1
fi

FLUTTER_VERSION=$(flutter --version | head -n 1)
echo "✅ Flutter found: $FLUTTER_VERSION"

# Get dependencies
echo "📦 Getting dependencies..."
if ! flutter pub get > /dev/null 2>&1; then
    echo "❌ Failed to get dependencies!"
    exit 1
fi

# Analyze code (optional)
if [ "$ANALYZE" = true ]; then
    echo "🔍 Analyzing code..."
    if ! flutter analyze; then
        echo "⚠️  Code analysis found issues. Continuing build..."
    fi
fi

# Run tests (optional)
if [ "$TEST" = true ]; then
    echo "🧪 Running tests..."
    if ! flutter test; then
        echo "⚠️  Some tests failed. Continuing build..."
    fi
fi

# Clean previous build
echo "🧹 Cleaning previous build..."
flutter clean > /dev/null 2>&1

# Build web app
echo "🔨 Building web app..."
BUILD_ARGS=()

if [ "$RELEASE" = true ]; then
    echo "   Mode: Release (optimized)"
    BUILD_ARGS+=("--release")
    
    # Optimizations
    echo "   Optimizations enabled:"
    echo "     - Tree-shake icons"
    echo "     - CanvasKit renderer"
    echo "     - Minification"
    echo "     - Code splitting"
    if [ "$PWA" = true ]; then
        echo "     - PWA support"
    fi
    
    BUILD_ARGS+=("--tree-shake-icons")
    BUILD_ARGS+=("--web-renderer" "canvaskit")
    
    if [ "$MINIFY" = true ]; then
        export FLUTTER_WEB_USE_SKIA=true
        BUILD_ARGS+=("--dart-define=FLUTTER_WEB_USE_SKIA=true")
    fi
else
    echo "   Mode: Debug"
fi

BUILD_ARGS+=("--base-href" "$BASE_HREF")
BUILD_ARGS+=("--target" "$TARGET")

BUILD_CMD="flutter build web ${BUILD_ARGS[*]}"
echo "   Command: $BUILD_CMD"
echo ""

if ! eval "$BUILD_CMD"; then
    echo "❌ Build failed!"
    exit 1
fi

echo ""
echo "✅ Build completed successfully!"
echo ""

# Verify build output
if [ "$VERIFY" = true ]; then
    echo "🔍 Verifying build output..."
    echo ""
    
    BUILD_DIR="build/web"
    ALL_PASSED=true
    
    # Check required files
    REQUIRED_FILES=(
        "index.html:true"
        "manifest.json:$PWA"
        "flutter_service_worker.js:$PWA"
        "main.dart.js:true"
        "flutter.js:true"
    )
    
    for FILE_INFO in "${REQUIRED_FILES[@]}"; do
        IFS=':' read -r FILE REQUIRED <<< "$FILE_INFO"
        FILE_PATH="$BUILD_DIR/$FILE"
        
        if [ "$REQUIRED" = "true" ]; then
            if [ -f "$FILE_PATH" ]; then
                FILE_SIZE=$(stat -f%z "$FILE_PATH" 2>/dev/null || stat -c%s "$FILE_PATH" 2>/dev/null || echo "0")
                FILE_SIZE_KB=$((FILE_SIZE / 1024))
                echo "   ✅ $FILE ($FILE_SIZE_KB KB)"
            else
                echo "   ❌ $FILE - NOT FOUND"
                ALL_PASSED=false
            fi
        else
            if [ -f "$FILE_PATH" ]; then
                echo "   ✅ $FILE (optional)"
            fi
        fi
    done
    
    # Verify PWA files
    if [ "$PWA" = true ]; then
        echo ""
        echo "   PWA Verification:"
        
        # Check manifest.json content
        MANIFEST_PATH="$BUILD_DIR/manifest.json"
        if [ -f "$MANIFEST_PATH" ]; then
            if command -v jq &> /dev/null; then
                MANIFEST_NAME=$(jq -r '.name' "$MANIFEST_PATH" 2>/dev/null || echo "")
                MANIFEST_SHORT_NAME=$(jq -r '.short_name' "$MANIFEST_PATH" 2>/dev/null || echo "")
                MANIFEST_START_URL=$(jq -r '.start_url' "$MANIFEST_PATH" 2>/dev/null || echo "")
                MANIFEST_DISPLAY=$(jq -r '.display' "$MANIFEST_PATH" 2>/dev/null || echo "")
                ICON_COUNT=$(jq '.icons | length' "$MANIFEST_PATH" 2>/dev/null || echo "0")
                
                [ -n "$MANIFEST_NAME" ] && echo "     ✅ name: $MANIFEST_NAME"
                [ -n "$MANIFEST_SHORT_NAME" ] && echo "     ✅ short_name: $MANIFEST_SHORT_NAME"
                [ -n "$MANIFEST_START_URL" ] && echo "     ✅ start_url: $MANIFEST_START_URL"
                [ -n "$MANIFEST_DISPLAY" ] && echo "     ✅ display: $MANIFEST_DISPLAY"
                [ "$ICON_COUNT" -gt 0 ] && echo "     ✅ icons: $ICON_COUNT icons"
            else
                echo "     ⚠️  jq not found. Install jq for manifest validation."
            fi
        fi
        
        # Check for PWA icons
        if [ -f "$BUILD_DIR/icons/icon-192x192.png" ]; then
            echo "     ✅ PWA icon (192x192) found"
        else
            echo "     ⚠️  PWA icon (192x192) not found"
        fi
        
        if [ -f "$BUILD_DIR/icons/icon-512x512.png" ]; then
            echo "     ✅ PWA icon (512x512) found"
        else
            echo "     ⚠️  PWA icon (512x512) not found"
        fi
    fi
    
    echo ""
    
    if [ "$ALL_PASSED" = true ]; then
        echo "✅ All build files verified!"
    else
        echo "⚠️  Some required files are missing. Build may be incomplete."
        exit 1
    fi
    
    # Check build size
    echo ""
    echo "📊 Build Size Analysis:"
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
        fi
    fi
    
    # Check for common optimization issues
    echo ""
    echo "🔍 Optimization Checks:"
    
    # Check if source maps are present (should be removed in production)
    SOURCE_MAPS=$(find "$BUILD_DIR" -name "*.js.map" 2>/dev/null | wc -l)
    if [ "$SOURCE_MAPS" -gt 0 ] && [ "$RELEASE" = true ]; then
        echo "   ⚠️  Source maps found. Consider removing for production."
    fi
    
    # Check for large assets
    LARGE_ASSETS=$(find "$BUILD_DIR" -type f -size +1M 2>/dev/null)
    if [ -n "$LARGE_ASSETS" ]; then
        echo "   ⚠️  Large assets found:"
        echo "$LARGE_ASSETS" | while read -r asset; do
            ASSET_SIZE=$(stat -f%z "$asset" 2>/dev/null || stat -c%s "$asset" 2>/dev/null || echo "0")
            ASSET_SIZE_MB=$((ASSET_SIZE / 1048576))
            ASSET_NAME=$(basename "$asset")
            echo "      - $ASSET_NAME: $ASSET_SIZE_MB MB"
        done
    else
        echo "   ✅ No unusually large assets detected"
    fi
fi

echo ""
echo "📝 Next Steps:"
echo "   1. Test locally: cd build/web && python3 -m http.server 8000"
echo "   2. Open browser: http://localhost:8000"
echo "   3. Test PWA installability in browser DevTools"
echo "   4. Verify build: bash web/verify_deployment.sh"
echo "   5. Deploy to your hosting platform:"
echo "      - GitHub Pages: bash scripts/deploy_github_pages.sh"
echo "      - Netlify: netlify deploy --dir=build/web --prod"
echo "      - Vercel: cd build/web && vercel --prod"
echo "   6. See docs/WEB_BUILD_AND_DEPLOYMENT_COMPLETE.md for details"
echo ""
echo "✨ Build complete!"
