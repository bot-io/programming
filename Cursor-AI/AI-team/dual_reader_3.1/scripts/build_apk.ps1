# Build APK Script for Windows (PowerShell)
# This script builds a release APK for direct installation
#
# Usage:
#   .\build_apk.ps1              # Build universal APK (all architectures)
#   .\build_apk.ps1 -Split       # Build split APKs (per architecture)
#   .\build_apk.ps1 -Universal   # Build universal APK (explicit)

param(
    [switch]$Split,
    [switch]$Universal
)

# Determine build type
$buildType = "universal"
if ($Split) {
    $buildType = "split"
} elseif ($Universal) {
    $buildType = "universal"
}

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Building Release APK" -ForegroundColor Cyan
Write-Host "Build Type: $buildType" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# Check if Flutter is installed
$flutterCheck = flutter --version 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Flutter is not installed or not in PATH" -ForegroundColor Red
    exit 1
}

# Navigate to project root
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptPath
Set-Location $projectRoot

# Check for signing configuration
$keyPropertiesPath = Join-Path $projectRoot "android\key.properties"
if (-not (Test-Path $keyPropertiesPath)) {
    Write-Host "`nNote: key.properties not found. Using debug signing." -ForegroundColor Yellow
    Write-Host "For release signing, create android/key.properties" -ForegroundColor Yellow
    Write-Host ""
}

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

Write-Host ""
if ($buildType -eq "split") {
    Write-Host "Building release APK (split per ABI)..." -ForegroundColor Yellow
    flutter build apk --release --split-per-abi
    if ($LASTEXITCODE -ne 0) {
        Write-Host "`n=========================================" -ForegroundColor Red
        Write-Host "Split APK Build Failed!" -ForegroundColor Red
        Write-Host "=========================================" -ForegroundColor Red
        exit 1
    }
    $apkDir = Join-Path $projectRoot "build\app\outputs\flutter-apk"
    Write-Host "`n=========================================" -ForegroundColor Green
    Write-Host "Split APK Build Successful!" -ForegroundColor Green
    Write-Host "=========================================" -ForegroundColor Green
    Write-Host "`nAPK Locations:" -ForegroundColor Cyan
    $apkFiles = Get-ChildItem "$apkDir\*.apk" -ErrorAction SilentlyContinue
    if ($apkFiles) {
        $apkFiles | ForEach-Object {
            $size = [math]::Round($_.Length / 1MB, 2)
            Write-Host "  $($_.Name) ($size MB)" -ForegroundColor White
        }
    } else {
        Write-Host "  Warning: No APK files found" -ForegroundColor Yellow
    }
    Write-Host "`nArchitecture-specific APKs created:" -ForegroundColor Yellow
    Write-Host "  - app-armeabi-v7a-release.apk (32-bit ARM)" -ForegroundColor White
    Write-Host "  - app-arm64-v8a-release.apk (64-bit ARM)" -ForegroundColor White
    Write-Host "  - app-x86_64-release.apk (64-bit x86)" -ForegroundColor White
} else {
    Write-Host "Building release APK (universal)..." -ForegroundColor Yellow
    flutter build apk --release
    if ($LASTEXITCODE -ne 0) {
        Write-Host "`n=========================================" -ForegroundColor Red
        Write-Host "APK Build Failed!" -ForegroundColor Red
        Write-Host "=========================================" -ForegroundColor Red
        exit 1
    }
    $apkPath = Join-Path $projectRoot "build\app\outputs\flutter-apk\app-release.apk"
    Write-Host "`n=========================================" -ForegroundColor Green
    Write-Host "Universal APK Build Successful!" -ForegroundColor Green
    Write-Host "=========================================" -ForegroundColor Green
    Write-Host ""
    if (Test-Path $apkPath) {
        $apkSize = [math]::Round((Get-Item $apkPath).Length / 1MB, 2)
        Write-Host "APK Location: $apkPath" -ForegroundColor Cyan
        Write-Host "APK Size: $apkSize MB" -ForegroundColor Cyan
    } else {
        Write-Host "Warning: APK file not found at expected location" -ForegroundColor Yellow
    }
}

# Get version info
$pubspecContent = Get-Content "pubspec.yaml" -Raw
if ($pubspecContent -match "version:\s*(\d+\.\d+\.\d+)\+(\d+)") {
    $versionName = $matches[1]
    $versionCode = $matches[2]
    Write-Host "Version: $versionName (Build: $versionCode)" -ForegroundColor Cyan
}

Write-Host "`nTo install on device:" -ForegroundColor Yellow
if ($buildType -eq "split") {
    Write-Host "  adb install $apkDir\app-arm64-v8a-release.apk  # For 64-bit ARM devices" -ForegroundColor White
    Write-Host "  adb install $apkDir\app-armeabi-v7a-release.apk # For 32-bit ARM devices" -ForegroundColor White
    Write-Host "  adb install $apkDir\app-x86_64-release.apk      # For 64-bit x86 devices" -ForegroundColor White
} else {
    Write-Host "  adb install $apkPath" -ForegroundColor White
}

Write-Host "`nBuild completed successfully!" -ForegroundColor Green
