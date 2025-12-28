# Vercel Deployment Script for Windows (PowerShell)
# Deploys Flutter web app to Vercel
#
# Usage:
#   .\deploy_vercel.ps1                    # Deploy using Vercel CLI
#   .\deploy_vercel.ps1 -Production       # Deploy to production
#   .\deploy_vercel.ps1 -DryRun            # Show what would be deployed

param(
    [Parameter(Mandatory=$false)]
    [string]$BaseHref = "/",
    
    [switch]$Production,
    [switch]$SkipBuild,
    [switch]$DryRun
)

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Vercel Deployment" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# Navigate to project root
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptPath
Set-Location $projectRoot

# Check if Vercel CLI is installed
$vercelCheck = vercel --version 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Vercel CLI is not installed" -ForegroundColor Red
    Write-Host "Install it with: npm install -g vercel" -ForegroundColor Yellow
    exit 1
}

Write-Host "Vercel CLI version: $vercelCheck" -ForegroundColor Cyan
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

# Verify Vercel configuration
$vercelJsonWeb = Join-Path $projectRoot "web\vercel.json"
$vercelJsonRoot = Join-Path $projectRoot "vercel.json"
$vercelJsonBuild = Join-Path $buildOutput "vercel.json"

# Copy vercel.json to build output if it exists
if (Test-Path $vercelJsonWeb) {
    Copy-Item $vercelJsonWeb $vercelJsonBuild -Force
    Write-Host "Copied vercel.json to build output" -ForegroundColor Green
} elseif (Test-Path $vercelJsonRoot) {
    Copy-Item $vercelJsonRoot $vercelJsonBuild -Force
    Write-Host "Copied vercel.json to build output" -ForegroundColor Green
} else {
    Write-Host "Warning: vercel.json not found" -ForegroundColor Yellow
    Write-Host "Vercel will use default configuration" -ForegroundColor Yellow
}

if ($DryRun) {
    Write-Host "`nDry run mode - would deploy:" -ForegroundColor Yellow
    Write-Host "  Source: $buildOutput" -ForegroundColor White
    Write-Host "  Production: $Production" -ForegroundColor White
    exit 0
}

# Check if logged in to Vercel
Write-Host "Checking Vercel authentication..." -ForegroundColor Yellow
$authCheck = vercel whoami 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Not logged in to Vercel. Please log in:" -ForegroundColor Yellow
    vercel login
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error: Failed to log in to Vercel" -ForegroundColor Red
        exit 1
    }
}

# Deploy to Vercel
Write-Host "`nDeploying to Vercel..." -ForegroundColor Yellow

$deployArgs = @("--cwd", $buildOutput)

if ($Production) {
    $deployArgs += "--prod"
}

vercel $deployArgs

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n=========================================" -ForegroundColor Green
    Write-Host "Deployment Complete!" -ForegroundColor Green
    Write-Host "=========================================" -ForegroundColor Green
    Write-Host "`nYour app has been deployed to Vercel" -ForegroundColor Cyan
    Write-Host "Check your Vercel dashboard for the URL" -ForegroundColor White
} else {
    Write-Host "`n=========================================" -ForegroundColor Red
    Write-Host "Deployment Failed!" -ForegroundColor Red
    Write-Host "=========================================" -ForegroundColor Red
    exit 1
}
