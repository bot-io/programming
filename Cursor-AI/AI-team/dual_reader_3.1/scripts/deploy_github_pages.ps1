# GitHub Pages Deployment Script for Dual Reader 3.1
# This script builds and deploys the web app to GitHub Pages

param(
    [string]$RepoName = "dual_reader_3.1",
    [string]$Branch = "gh-pages",
    [switch]$DryRun = $false,
    [switch]$BuildOnly = $false
)

Write-Host "🚀 Deploying Dual Reader 3.1 to GitHub Pages..." -ForegroundColor Cyan
Write-Host ""

# Check if Flutter is available
try {
    $flutterVersion = flutter --version 2>&1 | Select-Object -First 1
    Write-Host "✅ Flutter found: $flutterVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ Flutter not found. Please install Flutter first." -ForegroundColor Red
    exit 1
}

# Check if Git is available
try {
    $gitVersion = git --version 2>&1
    Write-Host "✅ Git found: $gitVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ Git not found. Please install Git first." -ForegroundColor Red
    exit 1
}

# Check if we're in a Git repository
if (-not (Test-Path ".git")) {
    Write-Host "❌ Not in a Git repository. Please run this script from the project root." -ForegroundColor Red
    exit 1
}

# Get dependencies
Write-Host "📦 Getting dependencies..." -ForegroundColor Yellow
flutter pub get | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to get dependencies!" -ForegroundColor Red
    exit 1
}

# Build web app
Write-Host "🔨 Building web app for GitHub Pages..." -ForegroundColor Yellow
$baseHref = "/$RepoName/"
Write-Host "   Base href: $baseHref" -ForegroundColor Gray

flutter build web --release --base-href $baseHref --tree-shake-icons --web-renderer canvaskit

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Build failed!" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Build completed successfully!" -ForegroundColor Green
Write-Host ""

if ($BuildOnly) {
    Write-Host "📝 Build-only mode. Skipping deployment." -ForegroundColor Yellow
    Write-Host "   Build output: build/web/" -ForegroundColor Gray
    exit 0
}

# Verify build output
Write-Host "🔍 Verifying build output..." -ForegroundColor Cyan
$buildDir = "build/web"
$requiredFiles = @("index.html", "main.dart.js", "flutter.js", "manifest.json")

foreach ($file in $requiredFiles) {
    $filePath = Join-Path $buildDir $file
    if (-not (Test-Path $filePath)) {
        Write-Host "❌ Required file not found: $file" -ForegroundColor Red
        exit 1
    }
}

Write-Host "✅ All required files present" -ForegroundColor Green
Write-Host ""

if ($DryRun) {
    Write-Host "🔍 Dry run mode. Would deploy:" -ForegroundColor Yellow
    Write-Host "   Repository: $RepoName" -ForegroundColor Gray
    Write-Host "   Branch: $Branch" -ForegroundColor Gray
    Write-Host "   Source: $buildDir" -ForegroundColor Gray
    Write-Host ""
    Write-Host "   To actually deploy, run without -DryRun flag" -ForegroundColor Yellow
    exit 0
}

# Check if gh-pages branch exists
Write-Host "🌿 Checking Git branches..." -ForegroundColor Cyan
$branches = git branch -a 2>&1
$ghPagesExists = $branches -match "gh-pages" -or $branches -match "origin/gh-pages"

if (-not $ghPagesExists) {
    Write-Host "   Creating gh-pages branch..." -ForegroundColor Yellow
    git checkout --orphan $Branch 2>&1 | Out-Null
    git rm -rf . 2>&1 | Out-Null
} else {
    Write-Host "   Checking out gh-pages branch..." -ForegroundColor Yellow
    git checkout $Branch 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        git checkout -b $Branch 2>&1 | Out-Null
    }
}

# Copy build files
Write-Host "📋 Copying build files..." -ForegroundColor Yellow
Get-ChildItem -Path $buildDir -Recurse | Copy-Item -Destination . -Recurse -Force

# Add .nojekyll file (prevents Jekyll processing)
Write-Host "📄 Creating .nojekyll file..." -ForegroundColor Yellow
"" | Out-File -FilePath ".nojekyll" -Encoding utf8

# Stage all files
Write-Host "📝 Staging files..." -ForegroundColor Yellow
git add -A 2>&1 | Out-Null

# Check if there are changes
$status = git status --porcelain 2>&1
if ([string]::IsNullOrWhiteSpace($status)) {
    Write-Host "ℹ️  No changes to commit." -ForegroundColor Yellow
    git checkout master 2>&1 | Out-Null
    exit 0
}

# Commit changes
Write-Host "💾 Committing changes..." -ForegroundColor Yellow
$commitMessage = "Deploy Dual Reader 3.1 to GitHub Pages - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
git commit -m $commitMessage 2>&1 | Out-Null

if ($LASTEXITCODE -ne 0) {
    Write-Host "⚠️  Commit failed or no changes to commit." -ForegroundColor Yellow
}

# Push to GitHub
Write-Host "🚀 Pushing to GitHub..." -ForegroundColor Yellow
git push origin $Branch --force 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to push to GitHub!" -ForegroundColor Red
    Write-Host "   Make sure you have push access to the repository." -ForegroundColor Yellow
    git checkout master 2>&1 | Out-Null
    exit 1
}

# Switch back to master branch
git checkout master 2>&1 | Out-Null

Write-Host ""
Write-Host "✅ Deployment completed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "📝 Next Steps:" -ForegroundColor Cyan
Write-Host "   1. Go to repository Settings → Pages" -ForegroundColor Gray
Write-Host "   2. Select source: gh-pages branch" -ForegroundColor Gray
Write-Host "   3. Your site will be available at:" -ForegroundColor Gray
Write-Host "      https://[username].github.io/$RepoName/" -ForegroundColor Green
Write-Host ""
Write-Host "✨ Done!" -ForegroundColor Green
