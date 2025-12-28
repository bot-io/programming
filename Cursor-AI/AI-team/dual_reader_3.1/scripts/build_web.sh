#!/bin/bash
# Web Build Script for Linux/Mac
# Builds optimized Flutter web app with PWA support
#
# Usage:
#   ./build_web.sh                    # Build for production
#   ./build_web.sh --release          # Build release (default)
#   ./build_web.sh --debug            # Build debug
#   ./build_web.sh --base-href "/app/" # Build with custom base href

set -e

MODE="release"
BASE_HREF="/"
ANALYZE=false
NO_TREE_SHAKE=false
VERBOSE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --release)
            MODE="release"
            shift
            ;;
        --debug)
            MODE="debug"
            shift
            ;;
        --base-href)
            BASE_HREF="$2"
            shift 2
            ;;
        --analyze)
            ANALYZE=true
            shift
            ;;
        --no-tree-shake)
            NO_TREE_SHAKE=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--release|--debug] [--base-href PATH] [--analyze] [--no-tree-shake] [--verbose]"
            exit 1
            ;;
    esac
done

echo "========================================="
echo "Web Build Script"
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

# Validate base href format
if [[ ! "$BASE_HREF" =~ ^/ ]]; then
    BASE_HREF="/$BASE_HREF"
fi
if [[ ! "$BASE_HREF" =~ /$ ]]; then
    BASE_HREF="$BASE_HREF/"
fi

echo "Build Mode: $MODE"
echo "Base Href: $BASE_HREF"
echo ""

# Clean previous builds
echo "Cleaning previous builds..."
flutter clean

# Get dependencies
echo ""
echo "Getting dependencies..."
flutter pub get

# Run analyzer if requested
if [ "$ANALYZE" = true ]; then
    echo ""
    echo "Running Flutter analyzer..."
    flutter analyze || echo "Warning: Analyzer found issues"
fi

# Build web app
echo ""
echo "========================================="
echo "Building Web App"
echo "========================================="

BUILD_ARGS=("build" "web")

if [ "$MODE" = "release" ]; then
    BUILD_ARGS+=("--release")
else
    BUILD_ARGS+=("--debug")
fi

BUILD_ARGS+=("--base-href" "$BASE_HREF")

if [ "$MODE" = "release" ]; then
    if [ "$NO_TREE_SHAKE" = false ]; then
        BUILD_ARGS+=("--tree-shake-icons")
    fi
    # Use CanvasKit renderer for better performance and smaller bundle size
    BUILD_ARGS+=("--web-renderer" "canvaskit")
fi

if [ "$VERBOSE" = true ]; then
    BUILD_ARGS+=("--verbose")
fi

echo "Running: flutter ${BUILD_ARGS[*]}"
flutter "${BUILD_ARGS[@]}"

if [ $? -ne 0 ]; then
    echo ""
    echo "========================================="
    echo "Build Failed!"
    echo "========================================="
    exit 1
fi

# Verify build output
BUILD_OUTPUT="$PROJECT_ROOT/build/web"
if [ ! -d "$BUILD_OUTPUT" ]; then
    echo "Error: Build output directory not found"
    exit 1
fi

# Copy deployment files for GitHub Pages
echo ""
echo "Preparing deployment files..."

# Create .nojekyll file for GitHub Pages
NOJEKYLL_PATH="$BUILD_OUTPUT/.nojekyll"
if [ ! -f "$NOJEKYLL_PATH" ]; then
    touch "$NOJEKYLL_PATH"
    echo "   Created .nojekyll for GitHub Pages"
fi

# Copy 404.html if it exists in web directory, otherwise create from index.html
WEB_404_PATH="$PROJECT_ROOT/web/404.html"
BUILD_404_PATH="$BUILD_OUTPUT/404.html"
if [ -f "$WEB_404_PATH" ]; then
    cp "$WEB_404_PATH" "$BUILD_404_PATH"
    echo "   Copied 404.html for GitHub Pages"
elif [ ! -f "$BUILD_404_PATH" ]; then
    INDEX_PATH="$BUILD_OUTPUT/index.html"
    if [ -f "$INDEX_PATH" ]; then
        cp "$INDEX_PATH" "$BUILD_404_PATH"
        echo "   Created 404.html from index.html"
    fi
fi

# Copy vercel.json to build output if it exists (for Vercel deployment)
VERCEL_JSON_WEB="$PROJECT_ROOT/web/vercel.json"
VERCEL_JSON_ROOT="$PROJECT_ROOT/vercel.json"
VERCEL_JSON_BUILD="$BUILD_OUTPUT/vercel.json"
if [ -f "$VERCEL_JSON_WEB" ]; then
    cp "$VERCEL_JSON_WEB" "$VERCEL_JSON_BUILD"
    echo "   Copied vercel.json for Vercel deployment"
elif [ -f "$VERCEL_JSON_ROOT" ]; then
    cp "$VERCEL_JSON_ROOT" "$VERCEL_JSON_BUILD"
    echo "   Copied vercel.json for Vercel deployment"
fi

# Check for essential files
ESSENTIAL_FILES=("index.html" "manifest.json" "flutter.js" "main.dart.js")
MISSING_FILES=()

for file in "${ESSENTIAL_FILES[@]}"; do
    if [ ! -f "$BUILD_OUTPUT/$file" ]; then
        MISSING_FILES+=("$file")
    fi
done

if [ ${#MISSING_FILES[@]} -gt 0 ]; then
    echo ""
    echo "Warning: Missing essential files:"
    for file in "${MISSING_FILES[@]}"; do
        echo "  - $file"
    done
fi

# Verify PWA files
if [ "$MODE" = "release" ]; then
    echo ""
    echo "Verifying PWA configuration..."
    
    PWA_FILES=(
        "manifest.json:true"
        "flutter_service_worker.js:true"
        "icons/icon-192x192.png:true"
        "icons/icon-512x512.png:true"
    )
    
    PWA_ISSUES=()
    for pwa_file in "${PWA_FILES[@]}"; do
        FILE_NAME="${pwa_file%%:*}"
        REQUIRED="${pwa_file##*:}"
        FILE_PATH="$BUILD_OUTPUT/$FILE_NAME"
        
        if [ -f "$FILE_PATH" ] || [ -d "$FILE_PATH" ]; then
            echo "   ✅ $FILE_NAME"
        else
            if [ "$REQUIRED" = "true" ]; then
                echo "   ❌ $FILE_NAME - MISSING (Required)"
                PWA_ISSUES+=("$FILE_NAME")
            else
                echo "   ⚠️  $FILE_NAME - MISSING (Optional)"
            fi
        fi
    done
    
    # Verify manifest.json content
    MANIFEST_PATH="$BUILD_OUTPUT/manifest.json"
    if [ -f "$MANIFEST_PATH" ]; then
        if command -v jq &> /dev/null; then
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
                    echo "      ⚠️  manifest.json missing field: $field"
                    PWA_ISSUES+=("manifest.json (missing $field)")
                fi
            done
            
            # Check icon sizes
            if jq -e '.icons[] | select(.sizes | contains("192x192"))' "$MANIFEST_PATH" > /dev/null 2>&1 && \
               jq -e '.icons[] | select(.sizes | contains("512x512"))' "$MANIFEST_PATH" > /dev/null 2>&1; then
                echo "      ✅ Required icon sizes present (192x192, 512x512)"
            else
                echo "      ⚠️  Missing required icon sizes"
                PWA_ISSUES+=("manifest.json (missing required icons)")
            fi
            
            if [ ${#PWA_ISSUES[@]} -eq 0 ]; then
                echo "   ✅ manifest.json structure valid"
            fi
        else
            echo "   ⚠️  jq not installed, skipping detailed manifest validation"
            echo "   Install jq for detailed validation: sudo apt-get install jq"
        fi
    fi
    
    # Verify service worker registration
    INDEX_PATH="$BUILD_OUTPUT/index.html"
    if [ -f "$INDEX_PATH" ]; then
        if grep -q "flutter_service_worker\|service.*worker" "$INDEX_PATH"; then
            echo "   ✅ Service worker referenced in index.html"
        else
            echo "   ⚠️  Service worker may not be registered"
            PWA_ISSUES+=("index.html (service worker not found)")
        fi
    fi
    
    if [ ${#PWA_ISSUES[@]} -gt 0 ]; then
        echo ""
        echo "⚠️  PWA configuration issues found. App may not be installable."
        echo "   Issues: ${PWA_ISSUES[*]}"
    else
        echo ""
        echo "✅ PWA configuration verified!"
        echo "   App is ready for deployment as PWA"
    fi
fi

# Display build info
echo ""
echo "========================================="
echo "Build Complete!"
echo "========================================="
echo "Build output: $BUILD_OUTPUT"
echo ""

# Calculate build size
BUILD_SIZE=$(du -sh "$BUILD_OUTPUT" | cut -f1)
echo "Build size: $BUILD_SIZE"

# List main files
echo ""
echo "Main files:"
ls -lh "$BUILD_OUTPUT" | grep -E "^-" | awk '{print $9, "(" $5 ")"}'

# Check main.dart.js size
MAIN_JS_PATH="$BUILD_OUTPUT/main.dart.js"
if [ -f "$MAIN_JS_PATH" ]; then
    MAIN_JS_SIZE=$(du -h "$MAIN_JS_PATH" | cut -f1)
    echo ""
    echo "main.dart.js size: $MAIN_JS_SIZE"
    MAIN_JS_SIZE_MB=$(du -m "$MAIN_JS_PATH" | cut -f1)
    if [ "$MAIN_JS_SIZE_MB" -gt 5 ]; then
        echo "⚠️  Warning: main.dart.js is large. Consider code splitting."
    fi
fi

echo ""
echo "Next steps:"
echo "1. Test locally: cd build/web && python3 -m http.server 8000"
echo "2. Open browser: http://localhost:8000"
echo "3. Test PWA: Open DevTools > Application > Service Workers"
echo "4. Deploy to hosting:"
echo "   - GitHub Pages: scripts/deploy_github_pages.sh"
echo "   - Netlify: scripts/deploy_netlify.sh"
echo "   - Vercel: scripts/deploy_vercel.sh"
