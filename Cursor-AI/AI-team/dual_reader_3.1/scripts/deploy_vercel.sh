#!/bin/bash
# Vercel Deployment Script for Linux/Mac
# Deploys Flutter web app to Vercel
#
# Usage:
#   ./deploy_vercel.sh                    # Deploy using Vercel CLI
#   ./deploy_vercel.sh --production       # Deploy to production
#   ./deploy_vercel.sh --dry-run         # Show what would be deployed

set -e

BASE_HREF="/"
PRODUCTION=false
SKIP_BUILD=false
DRY_RUN=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --base-href)
            BASE_HREF="$2"
            shift 2
            ;;
        --production)
            PRODUCTION=true
            shift
            ;;
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--base-href PATH] [--production] [--skip-build] [--dry-run]"
            exit 1
            ;;
    esac
done

echo "========================================="
echo "Vercel Deployment"
echo "========================================="

# Navigate to project root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
cd "$PROJECT_ROOT"

# Check if Vercel CLI is installed
if ! command -v vercel &> /dev/null; then
    echo "Error: Vercel CLI is not installed"
    echo "Install it with: npm install -g vercel"
    exit 1
fi

VERCEL_VERSION=$(vercel --version)
echo "Vercel CLI version: $VERCEL_VERSION"
echo ""

# Build web app if not skipped
if [ "$SKIP_BUILD" = false ]; then
    echo "Building web app..."
    "$SCRIPT_DIR/build_web.sh" --release --base-href "$BASE_HREF"
else
    echo "Skipping build (using existing build)"
fi

# Verify build output
BUILD_OUTPUT="$PROJECT_ROOT/build/web"
if [ ! -d "$BUILD_OUTPUT" ]; then
    echo "Error: Build output not found. Run build first."
    exit 1
fi

# Verify Vercel configuration
VERCEL_JSON_WEB="$PROJECT_ROOT/web/vercel.json"
VERCEL_JSON_ROOT="$PROJECT_ROOT/vercel.json"
VERCEL_JSON_BUILD="$BUILD_OUTPUT/vercel.json"

# Copy vercel.json to build output if it exists
if [ -f "$VERCEL_JSON_WEB" ]; then
    cp "$VERCEL_JSON_WEB" "$VERCEL_JSON_BUILD"
    echo "Copied vercel.json to build output"
elif [ -f "$VERCEL_JSON_ROOT" ]; then
    cp "$VERCEL_JSON_ROOT" "$VERCEL_JSON_BUILD"
    echo "Copied vercel.json to build output"
else
    echo "Warning: vercel.json not found"
    echo "Vercel will use default configuration"
fi

if [ "$DRY_RUN" = true ]; then
    echo ""
    echo "Dry run mode - would deploy:"
    echo "  Source: $BUILD_OUTPUT"
    echo "  Production: $PRODUCTION"
    exit 0
fi

# Check if logged in to Vercel
echo "Checking Vercel authentication..."
if ! vercel whoami > /dev/null 2>&1; then
    echo "Not logged in to Vercel. Please log in:"
    vercel login
    if [ $? -ne 0 ]; then
        echo "Error: Failed to log in to Vercel"
        exit 1
    fi
fi

# Deploy to Vercel
echo ""
echo "Deploying to Vercel..."

DEPLOY_ARGS=("--cwd" "$BUILD_OUTPUT")

if [ "$PRODUCTION" = true ]; then
    DEPLOY_ARGS+=("--prod")
fi

vercel "${DEPLOY_ARGS[@]}"

if [ $? -eq 0 ]; then
    echo ""
    echo "========================================="
    echo "Deployment Complete!"
    echo "========================================="
    echo ""
    echo "Your app has been deployed to Vercel"
    echo "Check your Vercel dashboard for the URL"
else
    echo ""
    echo "========================================="
    echo "Deployment Failed!"
    echo "========================================="
    exit 1
fi
