#!/bin/bash
# Web Build and Deployment Acceptance Criteria Verification Script
# Verifies all acceptance criteria for web build and deployment configuration
#
# Usage:
#   ./verify_web_build_deployment.sh                    # Verify all criteria
#   ./verify_web_build_deployment.sh --build-only        # Verify build only
#   ./verify_web_build_deployment.sh --deploy-only       # Verify deployment config only

set -e

BUILD_ONLY=false
DEPLOY_ONLY=false
VERBOSE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --build-only)
            BUILD_ONLY=true
            shift
            ;;
        --deploy-only)
            DEPLOY_ONLY=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --build-only    Verify build configuration only"
            echo "  --deploy-only   Verify deployment configuration only"
            echo "  --verbose       Show verbose output"
            echo "  -h, --help      Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

echo "========================================="
echo "Web Build & Deployment Verification"
echo "========================================="
echo ""

# Get project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

ALL_PASSED=true
ISSUES=()

# ============================================
# 1. Optimized Web Build Configuration
# ============================================
if [ "$DEPLOY_ONLY" = false ]; then
    echo "1. Optimized Web Build Configuration"
    echo "   Checking build scripts and configuration..."
    
    # Check build scripts exist
    BUILD_SCRIPTS=(
        "scripts/build_web.ps1:Windows Build Script:false"
        "web/build_web.sh:Linux/Mac Build Script:true"
        "web/build_web.ps1:Web Build Script:false"
    )
    
    for SCRIPT_INFO in "${BUILD_SCRIPTS[@]}"; do
        IFS=':' read -r SCRIPT_PATH SCRIPT_NAME REQUIRED <<< "$SCRIPT_INFO"
        FULL_PATH="$PROJECT_ROOT/$SCRIPT_PATH"
        
        if [ -f "$FULL_PATH" ]; then
            echo "   ✅ $SCRIPT_NAME found"
            
            # Check for optimization flags
            if grep -q "tree-shake-icons\|tree_shake" "$FULL_PATH" && \
               grep -q "canvaskit\|web-renderer" "$FULL_PATH" && \
               grep -q "--release\|Release" "$FULL_PATH"; then
                echo "      ✅ Optimization flags present"
            else
                echo "      ⚠️  Missing optimization flags"
                ISSUES+=("$SCRIPT_NAME: Missing optimization flags")
            fi
        else
            if [ "$REQUIRED" = "true" ]; then
                echo "   ❌ $SCRIPT_NAME NOT FOUND"
                ALL_PASSED=false
                ISSUES+=("$SCRIPT_NAME: Missing")
            fi
        fi
    done
    
    # Check pubspec.yaml
    PUBSPEC_PATH="$PROJECT_ROOT/pubspec.yaml"
    if [ -f "$PUBSPEC_PATH" ]; then
        echo "   ✅ pubspec.yaml found"
    else
        echo "   ❌ pubspec.yaml NOT FOUND"
        ALL_PASSED=false
        ISSUES+=("pubspec.yaml: Missing")
    fi
    
    echo ""
fi

# ============================================
# 2. PWA Manifest Finalized
# ============================================
if [ "$DEPLOY_ONLY" = false ]; then
    echo "2. PWA Manifest Finalized"
    echo "   Checking manifest.json..."
    
    MANIFEST_PATH="$PROJECT_ROOT/web/manifest.json"
    if [ -f "$MANIFEST_PATH" ]; then
        echo "   ✅ manifest.json found"
        
        # Check if jq is available for JSON parsing
        if command -v jq &> /dev/null; then
            # Check required fields
            REQUIRED_FIELDS=("name" "short_name" "start_url" "display" "icons")
            for FIELD in "${REQUIRED_FIELDS[@]}"; do
                VALUE=$(jq -r ".$FIELD" "$MANIFEST_PATH" 2>/dev/null || echo "")
                if [ -n "$VALUE" ] && [ "$VALUE" != "null" ]; then
                    echo "      ✅ $FIELD: Present"
                else
                    echo "      ❌ $FIELD: MISSING"
                    ALL_PASSED=false
                    ISSUES+=("manifest.json: Missing field '$FIELD'")
                fi
            done
            
            # Check icons
            ICON_COUNT=$(jq '.icons | length' "$MANIFEST_PATH" 2>/dev/null || echo "0")
            if [ "$ICON_COUNT" -gt 0 ]; then
                # Check for required icon sizes
                HAS_192=false
                HAS_512=false
                
                for i in $(seq 0 $((ICON_COUNT - 1))); do
                    SIZES=$(jq -r ".icons[$i].sizes" "$MANIFEST_PATH" 2>/dev/null || echo "")
                    if echo "$SIZES" | grep -q "192"; then
                        HAS_192=true
                    fi
                    if echo "$SIZES" | grep -q "512"; then
                        HAS_512=true
                    fi
                done
                
                if [ "$HAS_192" = true ] && [ "$HAS_512" = true ]; then
                    echo "      ✅ Required icon sizes present (192x192, 512x512)"
                else
                    echo "      ❌ Missing required icon sizes"
                    [ "$HAS_192" = false ] && ISSUES+=("manifest.json: Missing 192x192 icon")
                    [ "$HAS_512" = false ] && ISSUES+=("manifest.json: Missing 512x512 icon")
                    ALL_PASSED=false
                fi
            else
                echo "      ❌ No icons defined"
                ALL_PASSED=false
                ISSUES+=("manifest.json: No icons defined")
            fi
            
            # Check display mode
            DISPLAY_MODE=$(jq -r ".display" "$MANIFEST_PATH" 2>/dev/null || echo "")
            VALID_MODES=("standalone" "fullscreen" "minimal-ui" "browser")
            if [[ " ${VALID_MODES[@]} " =~ " ${DISPLAY_MODE} " ]]; then
                echo "      ✅ Display mode valid: $DISPLAY_MODE"
            else
                echo "      ⚠️  Display mode may be invalid: $DISPLAY_MODE"
            fi
        else
            echo "      ⚠️  jq not found. Install jq for manifest validation."
            echo "      (Manifest file exists but cannot be validated)"
        fi
    else
        echo "   ❌ manifest.json NOT FOUND"
        ALL_PASSED=false
        ISSUES+=("manifest.json: Missing")
    fi
    
    echo ""
fi

# ============================================
# 3. Service Worker Configured
# ============================================
if [ "$DEPLOY_ONLY" = false ]; then
    echo "3. Service Worker Configured"
    echo "   Checking service worker configuration..."
    
    # Check service worker file
    SW_PATH="$PROJECT_ROOT/web/service-worker.js"
    if [ -f "$SW_PATH" ]; then
        echo "   ✅ service-worker.js found"
        
        SW_CONTENT=$(cat "$SW_PATH")
        if echo "$SW_CONTENT" | grep -q "install\|addEventListener.*install" && \
           echo "$SW_CONTENT" | grep -q "activate\|addEventListener.*activate" && \
           echo "$SW_CONTENT" | grep -q "fetch\|addEventListener.*fetch"; then
            echo "      ✅ Service worker events configured"
        else
            echo "      ⚠️  Some service worker events may be missing"
        fi
    else
        echo "   ⚠️  service-worker.js not found (Flutter generates its own)"
    fi
    
    # Check index.html for service worker registration
    INDEX_PATH="$PROJECT_ROOT/web/index.html"
    if [ -f "$INDEX_PATH" ]; then
        INDEX_CONTENT=$(cat "$INDEX_PATH")
        if echo "$INDEX_CONTENT" | grep -q "service.*worker\|flutter_service_worker"; then
            echo "   ✅ Service worker referenced in index.html"
        else
            echo "   ⚠️  Service worker may not be registered in index.html"
        fi
    fi
    
    echo ""
fi

# ============================================
# 4. Build Scripts for Web Deployment
# ============================================
if [ "$DEPLOY_ONLY" = false ]; then
    echo "4. Build Scripts for Web Deployment"
    echo "   Checking deployment scripts..."
    
    DEPLOY_SCRIPTS=(
        "scripts/deploy_github_pages.ps1:GitHub Pages Deployment:false"
        "scripts/deploy_netlify.ps1:Netlify Deployment:false"
        "scripts/deploy_vercel.ps1:Vercel Deployment:false"
    )
    
    for SCRIPT_INFO in "${DEPLOY_SCRIPTS[@]}"; do
        IFS=':' read -r SCRIPT_PATH SCRIPT_NAME REQUIRED <<< "$SCRIPT_INFO"
        FULL_PATH="$PROJECT_ROOT/$SCRIPT_PATH"
        
        if [ -f "$FULL_PATH" ]; then
            echo "   ✅ $SCRIPT_NAME script found"
        else
            if [ "$REQUIRED" = "true" ]; then
                echo "   ❌ $SCRIPT_NAME script NOT FOUND"
                ALL_PASSED=false
                ISSUES+=("$SCRIPT_NAME: Missing")
            fi
        fi
    done
    
    echo ""
fi

# ============================================
# 5. Deployment Documentation
# ============================================
if [ "$BUILD_ONLY" = false ]; then
    echo "5. Deployment Documentation"
    echo "   Checking deployment documentation..."
    
    DOCS=(
        "docs/WEB_DEPLOYMENT_GUIDE.md:Web Deployment Guide:true"
        "docs/WEB_BUILD_AND_DEPLOYMENT.md:Build and Deployment Guide:true"
        "web/README.md:Web README:false"
    )
    
    for DOC_INFO in "${DOCS[@]}"; do
        IFS=':' read -r DOC_PATH DOC_NAME REQUIRED <<< "$DOC_INFO"
        FULL_PATH="$PROJECT_ROOT/$DOC_PATH"
        
        if [ -f "$FULL_PATH" ]; then
            echo "   ✅ $DOC_NAME found"
            
            # Check for key sections
            DOC_CONTENT=$(cat "$FULL_PATH")
            HAS_GITHUB_PAGES=false
            HAS_NETLIFY=false
            HAS_VERCEL=false
            
            echo "$DOC_CONTENT" | grep -qi "GitHub Pages\|github.*pages" && HAS_GITHUB_PAGES=true
            echo "$DOC_CONTENT" | grep -qi "Netlify\|netlify" && HAS_NETLIFY=true
            echo "$DOC_CONTENT" | grep -qi "Vercel\|vercel" && HAS_VERCEL=true
            
            if [ "$HAS_GITHUB_PAGES" = true ] && [ "$HAS_NETLIFY" = true ] && [ "$HAS_VERCEL" = true ]; then
                echo "      ✅ All deployment platforms documented"
            else
                echo "      ⚠️  Some deployment platforms may be missing"
            fi
        else
            if [ "$REQUIRED" = "true" ]; then
                echo "   ❌ $DOC_NAME NOT FOUND"
                ALL_PASSED=false
                ISSUES+=("$DOC_NAME: Missing")
            fi
        fi
    done
    
    echo ""
fi

# ============================================
# 6. Platform Configuration Files
# ============================================
if [ "$BUILD_ONLY" = false ]; then
    echo "6. Platform Configuration Files"
    echo "   Checking platform-specific configurations..."
    
    # GitHub Pages
    NO_JEKYLL_PATH="$PROJECT_ROOT/web/.nojekyll"
    CUSTOM_404_PATH="$PROJECT_ROOT/web/404.html"
    [ -f "$NO_JEKYLL_PATH" ] && echo "   ✅ .nojekyll file found (GitHub Pages)" || echo "   ⚠️  .nojekyll file not found"
    [ -f "$CUSTOM_404_PATH" ] && echo "   ✅ 404.html found (GitHub Pages)" || echo "   ⚠️  404.html not found"
    
    # Netlify
    NETLIFY_TOML_PATH="$PROJECT_ROOT/netlify.toml"
    if [ -f "$NETLIFY_TOML_PATH" ]; then
        echo "   ✅ netlify.toml found"
        
        NETLIFY_CONTENT=$(cat "$NETLIFY_TOML_PATH")
        HAS_BUILD_CMD=false
        HAS_PUBLISH_DIR=false
        HAS_REDIRECTS=false
        
        echo "$NETLIFY_CONTENT" | grep -q "build.*command\|command\s*=" && HAS_BUILD_CMD=true
        echo "$NETLIFY_CONTENT" | grep -q "publish\s*=" && HAS_PUBLISH_DIR=true
        echo "$NETLIFY_CONTENT" | grep -q "redirects\|\[\[redirects\]\]" && HAS_REDIRECTS=true
        
        if [ "$HAS_BUILD_CMD" = true ] && [ "$HAS_PUBLISH_DIR" = true ] && [ "$HAS_REDIRECTS" = true ]; then
            echo "      ✅ Netlify configuration complete"
        else
            echo "      ⚠️  Netlify configuration may be incomplete"
        fi
    else
        echo "   ⚠️  netlify.toml not found"
    fi
    
    # Vercel
    VERCEL_JSON_PATH="$PROJECT_ROOT/web/vercel.json"
    if [ -f "$VERCEL_JSON_PATH" ]; then
        echo "   ✅ vercel.json found"
        
        if command -v jq &> /dev/null; then
            HAS_BUILD_CMD=false
            HAS_OUTPUT_DIR=false
            
            jq -e '.buildCommand // .build' "$VERCEL_JSON_PATH" > /dev/null 2>&1 && HAS_BUILD_CMD=true
            jq -e '.outputDirectory // .output' "$VERCEL_JSON_PATH" > /dev/null 2>&1 && HAS_OUTPUT_DIR=true
            
            if [ "$HAS_BUILD_CMD" = true ] || [ "$HAS_OUTPUT_DIR" = true ]; then
                echo "      ✅ Vercel configuration present"
            else
                echo "      ⚠️  Vercel configuration may be incomplete"
            fi
        else
            echo "      ⚠️  jq not found. Cannot validate vercel.json"
        fi
    else
        echo "   ⚠️  vercel.json not found"
    fi
    
    # GitHub Actions
    GITHUB_WORKFLOW_PATH="$PROJECT_ROOT/.github/workflows/deploy-web.yml"
    if [ -f "$GITHUB_WORKFLOW_PATH" ]; then
        echo "   ✅ GitHub Actions workflow found"
        
        WORKFLOW_CONTENT=$(cat "$GITHUB_WORKFLOW_PATH")
        echo "$WORKFLOW_CONTENT" | grep -qi "build\|Build" && \
        echo "$WORKFLOW_CONTENT" | grep -qi "deploy\|Deploy" && \
        echo "      ✅ GitHub Actions workflow configured"
    else
        echo "   ⚠️  GitHub Actions workflow not found"
    fi
    
    echo ""
fi

# ============================================
# 7. PWA Icons
# ============================================
if [ "$DEPLOY_ONLY" = false ]; then
    echo "7. PWA Icons"
    echo "   Checking PWA icons..."
    
    ICONS_DIR="$PROJECT_ROOT/web/icons"
    if [ -d "$ICONS_DIR" ]; then
        echo "   ✅ Icons directory found"
        
        REQUIRED_ICONS=("icon-192x192.png" "icon-512x512.png")
        for ICON in "${REQUIRED_ICONS[@]}"; do
            ICON_PATH="$ICONS_DIR/$ICON"
            if [ -f "$ICON_PATH" ]; then
                echo "      ✅ $ICON found"
            else
                echo "      ❌ $ICON NOT FOUND"
                ALL_PASSED=false
                ISSUES+=("PWA Icons: Missing $ICON")
            fi
        done
    else
        echo "   ❌ Icons directory NOT FOUND"
        ALL_PASSED=false
        ISSUES+=("PWA Icons: Directory missing")
    fi
    
    echo ""
fi

# ============================================
# Summary
# ============================================
echo "========================================="
echo "Verification Summary"
echo "========================================="
echo ""

if [ "$ALL_PASSED" = true ] && [ ${#ISSUES[@]} -eq 0 ]; then
    echo "✅ All acceptance criteria verified!"
    echo ""
    echo "The web build and deployment configuration is complete and ready for production."
    echo ""
    echo "Next steps:"
    echo "1. Run build: bash web/build_web.sh"
    echo "2. Test locally: cd build/web && python3 -m http.server 8000"
    echo "3. Deploy to your chosen platform (see docs/WEB_BUILD_AND_DEPLOYMENT_COMPLETE.md)"
    exit 0
else
    echo "⚠️  Some issues found:"
    echo ""
    for ISSUE in "${ISSUES[@]}"; do
        echo "  - $ISSUE"
    done
    echo ""
    echo "Please fix these issues before deployment."
    exit 1
fi
