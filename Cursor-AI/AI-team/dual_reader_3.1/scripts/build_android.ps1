# Master Android Build Script for Windows (PowerShell)
# This script can build both APK and AAB with various options
#
# Usage:
#   .\build_android.ps1 -Type APK              # Build universal APK
#   .\build_android.ps1 -Type APK -Split       # Build split APKs
#   .\build_android.ps1 -Type AAB              # Build AAB for Play Store
#   .\build_android.ps1 -Type Both             # Build both APK and AAB

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("APK", "AAB", "Both")]
    [string]$Type,
    
    [switch]$Split
)

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Android Build Script" -ForegroundColor Cyan
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
$hasSigning = Test-Path $keyPropertiesPath

if (-not $hasSigning) {
    Write-Host "`nWarning: key.properties not found!" -ForegroundColor Yellow
    Write-Host "Builds will use debug signing (not suitable for Play Store)" -ForegroundColor Yellow
    Write-Host "Run: scripts\generate_keystore.ps1 to create a keystore" -ForegroundColor Yellow
    Write-Host ""
}

# Get version info
$pubspecContent = Get-Content "pubspec.yaml" -Raw
if ($pubspecContent -match "version:\s*(\d+\.\d+\.\d+)\+(\d+)") {
    $versionName = $matches[1]
    $versionCode = $matches[2]
    Write-Host "Version: $versionName (Build: $versionCode)" -ForegroundColor Cyan
    Write-Host ""
}

# Build function
function Build-APK {
    param([bool]$SplitBuild)
    
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "Building APK" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    
    if ($SplitBuild) {
        Write-Host "Building split APKs..." -ForegroundColor Yellow
        flutter build apk --release --split-per-abi
        if ($LASTEXITCODE -ne 0) {
            Write-Host "`nAPK build failed!" -ForegroundColor Red
            return $false
        }
        $apkDir = Join-Path $projectRoot "build\app\outputs\flutter-apk"
        Write-Host "`nSplit APKs created in: $apkDir" -ForegroundColor Green
    } else {
        Write-Host "Building universal APK..." -ForegroundColor Yellow
        flutter build apk --release
        if ($LASTEXITCODE -ne 0) {
            Write-Host "`nAPK build failed!" -ForegroundColor Red
            return $false
        }
        $apkPath = Join-Path $projectRoot "build\app\outputs\flutter-apk\app-release.apk"
        Write-Host "`nUniversal APK created: $apkPath" -ForegroundColor Green
    }
    return $true
}

function Build-AAB {
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "Building AAB" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    
    Write-Host "Building AAB..." -ForegroundColor Yellow
    flutter build appbundle --release
    
    if ($LASTEXITCODE -eq 0) {
        $aabPath = Join-Path $projectRoot "build\app\outputs\bundle\release\app-release.aab"
        Write-Host "`nAAB created: $aabPath" -ForegroundColor Green
        return $true
    } else {
        Write-Host "`nAAB build failed!" -ForegroundColor Red
        return $false
    }
}

# Clean and get dependencies
Write-Host "Cleaning previous builds..." -ForegroundColor Yellow
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

# Build based on type
$buildSuccess = $true
switch ($Type) {
    "APK" {
        $buildSuccess = Build-APK -SplitBuild $Split
    }
    "AAB" {
        $buildSuccess = Build-AAB
    }
    "Both" {
        $apkSuccess = Build-APK -SplitBuild $false
        Write-Host ""
        $aabSuccess = Build-AAB
        $buildSuccess = $apkSuccess -and $aabSuccess
    }
}

if ($buildSuccess) {
    Write-Host "`n=========================================" -ForegroundColor Green
    Write-Host "Build Complete!" -ForegroundColor Green
    Write-Host "=========================================" -ForegroundColor Green
} else {
    Write-Host "`n=========================================" -ForegroundColor Red
    Write-Host "Build Failed!" -ForegroundColor Red
    Write-Host "=========================================" -ForegroundColor Red
    exit 1
}
