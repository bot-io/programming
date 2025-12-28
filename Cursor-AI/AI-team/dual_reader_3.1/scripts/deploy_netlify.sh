#!/bin/bash
# Netlify Deployment Script for Linux/Mac
# Deploys Flutter web app to Netlify
#
# Usage:
#   ./deploy_netlify.sh                    # Deploy using Netlify CLI
#   ./deploy_netlify.sh --site-id "xxx"    # Deploy to specific site
#   ./deploy_netlify.sh --production       # Deploy to production
#   ./deploy_netlify.sh --dry-run          # Show what would be deployed

set -e

SITE_ID=""
BASE_HREF="/"
PRODUCTION=false
SKIP_BUILD=false
DRY_RUN=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --site-id)
            SITE_ID="$2"
            shift 2
            ;;
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
            echo "Usage: $0 [--site-id ID] [--base-href PATH] [--production] [--skip-build] [--dry-run]"
            exit 1
            ;;
    esac
done

echo "========================================="
echo "Netlify Deployment"
echo "========================================="

# Navigate to project root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
cd "$PROJECT_ROOT"

# Check if Netlify CLI is installed
if ! command -v netlify &> /dev/null; then
    echo "Error: Netlify CLI is not installed"
    echo "Install it with: npm install -g netlify-cli"
    exit 1
fi

NETLIFY_VERSION=$(netlify --version)
echo "Netlify CLI version: $NETLIFY_VERSION"
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

# Verify Netlify configuration
NETLIFY_TOML="$PROJECT_ROOT/netlify.toml"
if [ ! -f "$NETLIFY_TOML" ]; then
    echo "Warning: netlify.toml not found. Creating default configuration..."
    cat > "$NETLIFY_TOML" << 'EOF'
[build]
  command = "flutter build web --release"
  publish = "build/web"

[[redirects]]
  from = "/*"
  to = "/index.html"
  status = 200

[build.environment]
  FLUTTER_VERSION = "stable"
EOF
    echo "Created netlify.toml"
fi

if [ "$DRY_RUN" = true ]; then
    echo ""
    echo "Dry run mode - would deploy:"
    echo "  Source: $BUILD_OUTPUT"
    echo "  Site ID: $SITE_ID"
    echo "  Production: $PRODUCTION"
    exit 0
fi

# Check if logged in to Netlify
echo "Checking Netlify authentication..."
if ! netlify status > /dev/null 2>&1; then
    echo "Not logged in to Netlify. Please log in:"
    netlify login
    if [ $? -ne 0 ]; then
        echo "Error: Failed to log in to Netlify"
        exit 1
    fi
fi

# Deploy to Netlify
echo ""
echo "Deploying to Netlify..."

DEPLOY_ARGS=("deploy" "--dir" "$BUILD_OUTPUT")

if [ "$PRODUCTION" = true ]; then
    DEPLOY_ARGS+=("--prod")
fi

if [ -n "$SITE_ID" ]; then
    DEPLOY_ARGS+=("--site" "$SITE_ID")
fi

netlify "${DEPLOY_ARGS[@]}"

if [ $? -eq 0 ]; then
    echo ""
    echo "========================================="
    echo "Deployment Complete!"
    echo "========================================="
    echo ""
    echo "Your app has been deployed to Netlify"
    echo "Check your Netlify dashboard for the URL"
else
    echo ""
    echo "========================================="
    echo "Deployment Failed!"
    echo "========================================="
    exit 1
fi
