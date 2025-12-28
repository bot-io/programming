#!/bin/bash
# GitHub Pages Deployment Script for Dual Reader 3.1
# This script builds and deploys the web app to GitHub Pages

set -e  # Exit on error

# Default values
REPO_NAME="dual_reader_3.1"
BRANCH="gh-pages"
DRY_RUN=false
BUILD_ONLY=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --repo-name)
            REPO_NAME="$2"
            shift 2
            ;;
        --branch)
            BRANCH="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --build-only)
            BUILD_ONLY=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --repo-name NAME   Repository name (default: dual_reader_3.1)"
            echo "  --branch BRANCH    Branch to deploy to (default: gh-pages)"
            echo "  --dry-run          Show what would be deployed without deploying"
            echo "  --build-only       Build only, skip deployment"
            echo "  -h, --help         Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

echo "🚀 Deploying Dual Reader 3.1 to GitHub Pages..."
echo ""

# Check if Flutter is available
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter not found. Please install Flutter first."
    exit 1
fi

FLUTTER_VERSION=$(flutter --version | head -n 1)
echo "✅ Flutter found: $FLUTTER_VERSION"

# Check if Git is available
if ! command -v git &> /dev/null; then
    echo "❌ Git not found. Please install Git first."
    exit 1
fi

GIT_VERSION=$(git --version)
echo "✅ Git found: $GIT_VERSION"

# Check if we're in a Git repository
if [ ! -d ".git" ]; then
    echo "❌ Not in a Git repository. Please run this script from the project root."
    exit 1
fi

# Get dependencies
echo "📦 Getting dependencies..."
if ! flutter pub get > /dev/null 2>&1; then
    echo "❌ Failed to get dependencies!"
    exit 1
fi

# Build web app
echo "🔨 Building web app for GitHub Pages..."
BASE_HREF="/$REPO_NAME/"
echo "   Base href: $BASE_HREF"

if ! flutter build web --release --base-href "$BASE_HREF" --tree-shake-icons --web-renderer canvaskit; then
    echo "❌ Build failed!"
    exit 1
fi

echo "✅ Build completed successfully!"
echo ""

if [ "$BUILD_ONLY" = true ]; then
    echo "📝 Build-only mode. Skipping deployment."
    echo "   Build output: build/web/"
    exit 0
fi

# Verify build output
echo "🔍 Verifying build output..."
BUILD_DIR="build/web"
REQUIRED_FILES=("index.html" "main.dart.js" "flutter.js" "manifest.json")

for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$BUILD_DIR/$file" ]; then
        echo "❌ Required file not found: $file"
        exit 1
    fi
done

echo "✅ All required files present"
echo ""

if [ "$DRY_RUN" = true ]; then
    echo "🔍 Dry run mode. Would deploy:"
    echo "   Repository: $REPO_NAME"
    echo "   Branch: $BRANCH"
    echo "   Source: $BUILD_DIR"
    echo ""
    echo "   To actually deploy, run without --dry-run flag"
    exit 0
fi

# Check if gh-pages branch exists
echo "🌿 Checking Git branches..."
if git show-ref --verify --quiet refs/heads/$BRANCH || git show-ref --verify --quiet refs/remotes/origin/$BRANCH; then
    echo "   Checking out $BRANCH branch..."
    git checkout $BRANCH 2>&1 || git checkout -b $BRANCH 2>&1
else
    echo "   Creating $BRANCH branch..."
    git checkout --orphan $BRANCH 2>&1
    git rm -rf . 2>&1 || true
fi

# Copy build files
echo "📋 Copying build files..."
cp -r $BUILD_DIR/* .

# Add .nojekyll file (prevents Jekyll processing)
echo "📄 Creating .nojekyll file..."
touch .nojekyll

# Stage all files
echo "📝 Staging files..."
git add -A 2>&1

# Check if there are changes
if git diff --staged --quiet; then
    echo "ℹ️  No changes to commit."
    git checkout master 2>&1 || git checkout main 2>&1
    exit 0
fi

# Commit changes
echo "💾 Committing changes..."
COMMIT_MESSAGE="Deploy Dual Reader 3.1 to GitHub Pages - $(date '+%Y-%m-%d %H:%M:%S')"
git commit -m "$COMMIT_MESSAGE" 2>&1 || echo "⚠️  Commit failed or no changes to commit."

# Push to GitHub
echo "🚀 Pushing to GitHub..."
if ! git push origin $BRANCH --force 2>&1; then
    echo "❌ Failed to push to GitHub!"
    echo "   Make sure you have push access to the repository."
    git checkout master 2>&1 || git checkout main 2>&1
    exit 1
fi

# Switch back to master/main branch
git checkout master 2>&1 || git checkout main 2>&1

echo ""
echo "✅ Deployment completed successfully!"
echo ""
echo "📝 Next Steps:"
echo "   1. Go to repository Settings → Pages"
echo "   2. Select source: $BRANCH branch"
echo "   3. Your site will be available at:"
echo "      https://[username].github.io/$REPO_NAME/"
echo ""
echo "✨ Done!"
