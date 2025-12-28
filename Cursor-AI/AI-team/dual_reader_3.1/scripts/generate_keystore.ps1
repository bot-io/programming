# Generate Keystore Script for Windows (PowerShell)
# This script helps create a keystore for signing Android releases

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Android Keystore Generator" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# Check if Java keytool is available
$keytoolCheck = keytool -help 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Java keytool is not installed or not in PATH" -ForegroundColor Red
    Write-Host "Please install Java JDK to use this script" -ForegroundColor Yellow
    exit 1
}

# Navigate to project root
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptPath
$keystorePath = Join-Path $projectRoot "upload-keystore.jks"

if (Test-Path $keystorePath) {
    Write-Host "`nWarning: Keystore already exists at: $keystorePath" -ForegroundColor Yellow
    $overwrite = Read-Host "Overwrite? (y/N)"
    if ($overwrite -ne "y" -and $overwrite -ne "Y") {
        Write-Host "Aborted." -ForegroundColor Yellow
        exit 0
    }
}

Write-Host "`nThis will create a keystore for signing your Android app." -ForegroundColor Yellow
Write-Host "You will be prompted for:" -ForegroundColor Yellow
Write-Host "  - Keystore password (store this securely!)" -ForegroundColor White
Write-Host "  - Key password (can be same as keystore password)" -ForegroundColor White
Write-Host "  - Your name and organization details" -ForegroundColor White
Write-Host ""

$continue = Read-Host "Continue? (y/N)"
if ($continue -ne "y" -and $continue -ne "Y") {
    exit 0
}

Write-Host "`nGenerating keystore..." -ForegroundColor Yellow
Write-Host "Location: $keystorePath" -ForegroundColor Cyan

# Generate keystore
keytool -genkey -v -keystore $keystorePath -keyalg RSA -keysize 2048 -validity 10000 -alias upload

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n=========================================" -ForegroundColor Green
    Write-Host "Keystore Created Successfully!" -ForegroundColor Green
    Write-Host "=========================================" -ForegroundColor Green
    
    Write-Host "`nNext steps:" -ForegroundColor Yellow
    Write-Host "  1. Copy android/key.properties.template to android/key.properties" -ForegroundColor White
    Write-Host "  2. Update android/key.properties with:" -ForegroundColor White
    Write-Host "     storeFile=../upload-keystore.jks" -ForegroundColor Cyan
    Write-Host "     storePassword=<your-store-password>" -ForegroundColor Cyan
    Write-Host "     keyPassword=<your-key-password>" -ForegroundColor Cyan
    Write-Host "     keyAlias=upload" -ForegroundColor Cyan
    Write-Host "`nIMPORTANT: Keep your keystore and passwords secure!" -ForegroundColor Red
    Write-Host "  - Store the keystore file safely (backup recommended)" -ForegroundColor Yellow
    Write-Host "  - Never commit key.properties or keystore to version control" -ForegroundColor Yellow
} else {
    Write-Host "`n=========================================" -ForegroundColor Red
    Write-Host "Keystore Generation Failed!" -ForegroundColor Red
    Write-Host "=========================================" -ForegroundColor Red
    exit 1
}
