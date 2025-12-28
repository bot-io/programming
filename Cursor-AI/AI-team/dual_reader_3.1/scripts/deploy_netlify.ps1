# Netlify Deployment Script for Windows (PowerShell)
# Deploys Flutter web app to Netlify
#
# Usage:
#   .\deploy_netlify.ps1                    # Deploy using Netlify CLI
#   .\deploy_netlify.ps1 -SiteId "xxx"      # Deploy to specific site
#   .\deploy_netlify.ps1 -Production       # Deploy to production
#   .\deploy_netlify.ps1 -DryRun            # Show what would be deployed

param(
    [Parameter(Mandatory=$false)]
    [string]$SiteId = "",
    
    [Parameter(Mandatory=$false)]
    [string]$BaseHref = "/",
    
    [switch]$Production,
    [switch]$SkipBuild,
    [switch]$DryRun
)

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Netlify Deployment" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# Navigate to project root
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptPath
Set-Location $projectRoot

# Check if Netlify CLI is installed
$netlifyCheck = netlify --version 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Netlify CLI is not installed" -ForegroundColor Red
    Write-Host "Install it with: npm install -g netlify-cli" -ForegroundColor Yellow
    exit 1
}

Write-Host "Netlify CLI version: $netlifyCheck" -ForegroundColor Cyan
Write-Host ""

# Build web app if not skipped
if (-not $SkipBuild) {
    Write-Host "Building web app..." -ForegroundColor Yellow
    $buildScript = Join-Path $scriptPath "build_web.ps1"
    & $buildScript -Mode Release -BaseHref $BaseHref
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error: Build failed" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "Skipping build (using existing build)" -ForegroundColor Yellow
}

# Verify build output
$buildOutput = Join-Path $projectRoot "build\web"
if (-not (Test-Path $buildOutput)) {
    Write-Host "Error: Build output not found. Run build first." -ForegroundColor Red
    exit 1
}

# Verify Netlify configuration
$netlifyToml = Join-Path $projectRoot "netlify.toml"
if (-not (Test-Path $netlifyToml)) {
    Write-Host "Warning: netlify.toml not found. Creating default configuration..." -ForegroundColor Yellow
    $netlifyConfig = @"
[build]
  command = "flutter build web --release"
  publish = "build/web"

[[redirects]]
  from = "/*"
  to = "/index.html"
  status = 200

[build.environment]
  FLUTTER_VERSION = "stable"
"@
    $netlifyConfig | Out-File -FilePath $netlifyToml -Encoding UTF8
    Write-Host "Created netlify.toml" -ForegroundColor Green
}

if ($DryRun) {
    Write-Host "`nDry run mode - would deploy:" -ForegroundColor Yellow
    Write-Host "  Source: $buildOutput" -ForegroundColor White
    Write-Host "  Site ID: $SiteId" -ForegroundColor White
    Write-Host "  Production: $Production" -ForegroundColor White
    exit 0
}

# Check if logged in to Netlify
Write-Host "Checking Netlify authentication..." -ForegroundColor Yellow
$authCheck = netlify status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Not logged in to Netlify. Please log in:" -ForegroundColor Yellow
    netlify login
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error: Failed to log in to Netlify" -ForegroundColor Red
        exit 1
    }
}

# Deploy to Netlify
Write-Host "`nDeploying to Netlify..." -ForegroundColor Yellow

$deployArgs = @("deploy", "--dir", $buildOutput)

if ($Production) {
    $deployArgs += "--prod"
}

if ($SiteId) {
    $deployArgs += "--site", $SiteId
}

netlify $deployArgs

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n=========================================" -ForegroundColor Green
    Write-Host "Deployment Complete!" -ForegroundColor Green
    Write-Host "=========================================" -ForegroundColor Green
    Write-Host "`nYour app has been deployed to Netlify" -ForegroundColor Cyan
    Write-Host "Check your Netlify dashboard for the URL" -ForegroundColor White
} else {
    Write-Host "`n=========================================" -ForegroundColor Red
    Write-Host "Deployment Failed!" -ForegroundColor Red
    Write-Host "=========================================" -ForegroundColor Red
    exit 1
}
