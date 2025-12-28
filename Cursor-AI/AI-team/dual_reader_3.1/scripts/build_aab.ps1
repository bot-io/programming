# Build AAB Script for Windows (PowerShell)
# This script builds a release AAB (Android App Bundle) for Google Play Store

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Building Release AAB (App Bundle)" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# Check if Flutter is installed
$flutterCheck = flutter --version 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Flutter is not installed or not in PATH" -ForegroundColor Red
    exit 1
}

# Check for signing configuration
$projectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$keyPropertiesPath = Join-Path $projectRoot "android\key.properties"
$keystoreFile = $null

if (Test-Path $keyPropertiesPath) {
    # Extract keystore file path from key.properties
    $storeFileLine = Get-Content $keyPropertiesPath | Where-Object { $_ -match "^storeFile=" }
    if ($storeFileLine) {
        $keystoreFile = ($storeFileLine -split '=')[1].Trim()
        if ($keystoreFile) {
            # Handle relative paths
            if ($keystoreFile -like "../*") {
                $keystoreFile = Join-Path $projectRoot $keystoreFile.Substring(3)
            } elseif (-not [System.IO.Path]::IsPathRooted($keystoreFile)) {
                $keystoreFile = Join-Path (Join-Path $projectRoot "android") $keystoreFile
            }
        }
    }
}

if (-not (Test-Path $keyPropertiesPath) -or -not $keystoreFile -or -not (Test-Path $keystoreFile)) {
    Write-Host "`nWarning: key.properties not found or keystore file missing!" -ForegroundColor Yellow
    Write-Host "AAB will be built with debug signing (not suitable for Play Store)" -ForegroundColor Yellow
    Write-Host "`nTo set up signing:" -ForegroundColor Yellow
    Write-Host "  1. Copy android/key.properties.template to android/key.properties" -ForegroundColor White
    Write-Host "  2. Fill in your keystore details" -ForegroundColor White
    Write-Host "  3. Or run: scripts/generate_keystore.ps1" -ForegroundColor White
    Write-Host ""
    $continue = Read-Host "Continue anyway? (y/N)"
    if ($continue -ne "y" -and $continue -ne "Y") {
        exit 0
    }
} else {
    Write-Host "`nUsing signing configuration from key.properties" -ForegroundColor Green
}

# Navigate to project root
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptPath
Set-Location $projectRoot

Write-Host "`nCleaning previous builds..." -ForegroundColor Yellow
flutter clean
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Failed to clean build" -ForegroundColor Red
    exit 1
}

Write-Host "`nGetting dependencies..." -ForegroundColor Yellow
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Failed to get dependencies" -ForegroundColor Red
    exit 1
}

Write-Host "`nBuilding release AAB..." -ForegroundColor Yellow
flutter build appbundle --release

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n=========================================" -ForegroundColor Green
    Write-Host "AAB Build Successful!" -ForegroundColor Green
    Write-Host "=========================================" -ForegroundColor Green
    Write-Host "`nAAB Location: build/app/outputs/bundle/release/app-release.aab" -ForegroundColor Cyan
    
    # Get version info
    $pubspecContent = Get-Content "pubspec.yaml" -Raw
    if ($pubspecContent -match "version:\s*(\d+\.\d+\.\d+)\+(\d+)") {
        $versionName = $matches[1]
        $versionCode = $matches[2]
        Write-Host "Version: $versionName (Build: $versionCode)" -ForegroundColor Cyan
    }
    
    $aabPath = Join-Path $projectRoot "build\app\outputs\bundle\release\app-release.aab"
    if (Test-Path $aabPath) {
        $aabSize = [math]::Round((Get-Item $aabPath).Length / 1MB, 2)
        Write-Host "`nAAB Size: $aabSize MB" -ForegroundColor Cyan
    }
    
    Write-Host "`nTo upload to Play Store:" -ForegroundColor Yellow
    Write-Host "  1. Go to Google Play Console (https://play.google.com/console)" -ForegroundColor White
    Write-Host "  2. Navigate to your app > Release > Production (or Internal/Alpha/Beta)" -ForegroundColor White
    Write-Host "  3. Create new release and upload the AAB file" -ForegroundColor White
    Write-Host "  4. Fill in release notes and submit for review" -ForegroundColor White
    Write-Host "`nFile: build/app/outputs/bundle/release/app-release.aab" -ForegroundColor Cyan
    Write-Host "`nBuild completed successfully!" -ForegroundColor Green
} else {
    Write-Host "`n=========================================" -ForegroundColor Red
    Write-Host "AAB Build Failed!" -ForegroundColor Red
    Write-Host "=========================================" -ForegroundColor Red
    exit 1
}
