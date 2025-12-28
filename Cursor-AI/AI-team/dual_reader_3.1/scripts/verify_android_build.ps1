# Android Build Verification Script for Windows (PowerShell)
# This script verifies that the Android build configuration is complete and correct
#
# Usage:
#   .\verify_android_build.ps1

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Android Build Configuration Verification" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

$errors = @()
$warnings = @()
$success = @()

# Navigate to project root
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptPath
Set-Location $projectRoot

# Check 1: Flutter installation
Write-Host "[1/10] Checking Flutter installation..." -ForegroundColor Yellow
$flutterCheck = flutter --version 2>&1
if ($LASTEXITCODE -eq 0) {
    $flutterVersion = ($flutterCheck | Select-String "Flutter").ToString()
    $success += "Flutter is installed: $flutterVersion"
    Write-Host "  ✓ Flutter installed" -ForegroundColor Green
} else {
    $errors += "Flutter is not installed or not in PATH"
    Write-Host "  ✗ Flutter not found" -ForegroundColor Red
}

# Check 2: Java/keytool availability
Write-Host "[2/10] Checking Java/keytool..." -ForegroundColor Yellow
$keytoolCheck = keytool -help 2>&1
if ($LASTEXITCODE -eq 0) {
    $success += "Java keytool is available"
    Write-Host "  ✓ Java keytool available" -ForegroundColor Green
} else {
    $warnings += "Java keytool not found - signing may not work"
    Write-Host "  ⚠ Java keytool not found" -ForegroundColor Yellow
}

# Check 3: Project structure
Write-Host "[3/10] Checking project structure..." -ForegroundColor Yellow
$requiredFiles = @(
    "pubspec.yaml",
    "android/app/build.gradle",
    "android/build.gradle",
    "android/app/src/main/AndroidManifest.xml"
)

foreach ($file in $requiredFiles) {
    $filePath = Join-Path $projectRoot $file
    if (Test-Path $filePath) {
        Write-Host "  ✓ $file exists" -ForegroundColor Green
    } else {
        $errors += "Required file missing: $file"
        Write-Host "  ✗ $file missing" -ForegroundColor Red
    }
}

# Check 4: Version in pubspec.yaml
Write-Host "[4/10] Checking version configuration..." -ForegroundColor Yellow
$pubspecFile = Join-Path $projectRoot "pubspec.yaml"
if (Test-Path $pubspecFile) {
    $pubspecContent = Get-Content $pubspecFile -Raw
    if ($pubspecContent -match "version:\s*(\d+\.\d+\.\d+)\+(\d+)") {
        $versionName = $matches[1]
        $versionCode = $matches[2]
        $success += "Version configured: $versionName (Build: $versionCode)"
        Write-Host "  ✓ Version: $versionName (Build: $versionCode)" -ForegroundColor Green
    } else {
        $errors += "Invalid version format in pubspec.yaml (expected: x.y.z+build)"
        Write-Host "  ✗ Invalid version format" -ForegroundColor Red
    }
}

# Check 5: Signing configuration
Write-Host "[5/10] Checking signing configuration..." -ForegroundColor Yellow
$keyPropertiesPath = Join-Path $projectRoot "android\key.properties"
if (Test-Path $keyPropertiesPath) {
    $keyProperties = Get-Content $keyPropertiesPath
    $hasStorePassword = $keyProperties | Where-Object { $_ -match "^storePassword=" -and $_ -notmatch "YOUR_STORE_PASSWORD" }
    $hasKeyPassword = $keyProperties | Where-Object { $_ -match "^keyPassword=" -and $_ -notmatch "YOUR_KEY_PASSWORD" }
    $hasKeyAlias = $keyProperties | Where-Object { $_ -match "^keyAlias=" }
    $hasStoreFile = $keyProperties | Where-Object { $_ -match "^storeFile=" }
    
    if ($hasStorePassword -and $hasKeyPassword -and $hasKeyAlias -and $hasStoreFile) {
        # Check if keystore file exists
        $storeFileLine = $keyProperties | Where-Object { $_ -match "^storeFile=" }
        $storeFilePath = ($storeFileLine -split '=')[1].Trim()
        
        if ($storeFilePath -like "../*") {
            $storeFilePath = Join-Path $projectRoot $storeFilePath.Substring(3)
        } elseif (-not [System.IO.Path]::IsPathRooted($storeFilePath)) {
            $storeFilePath = Join-Path (Join-Path $projectRoot "android") $storeFilePath
        }
        
        if (Test-Path $storeFilePath) {
            $success += "Signing configuration complete"
            Write-Host "  ✓ Signing configuration complete" -ForegroundColor Green
        } else {
            $warnings += "Keystore file not found: $storeFilePath"
            Write-Host "  ⚠ Keystore file not found" -ForegroundColor Yellow
        }
    } else {
        $warnings += "key.properties exists but may not be fully configured"
        Write-Host "  ⚠ Signing configuration incomplete" -ForegroundColor Yellow
    }
} else {
    $warnings += "key.properties not found - builds will use debug signing"
    Write-Host "  ⚠ No signing configuration (debug signing will be used)" -ForegroundColor Yellow
}

# Check 6: Build.gradle configuration
Write-Host "[6/10] Checking build.gradle configuration..." -ForegroundColor Yellow
$buildGradlePath = Join-Path $projectRoot "android\app\build.gradle"
if (Test-Path $buildGradlePath) {
    $buildGradleContent = Get-Content $buildGradlePath -Raw
    
    $checks = @{
        "minSdk" = $buildGradleContent -match "minSdk\s+\d+"
        "targetSdk" = $buildGradleContent -match "targetSdk\s+\d+"
        "versionCode" = $buildGradleContent -match "versionCode"
        "versionName" = $buildGradleContent -match "versionName"
        "signingConfigs" = $buildGradleContent -match "signingConfigs"
        "buildTypes" = $buildGradleContent -match "buildTypes"
    }
    
    $allChecksPass = $true
    foreach ($check in $checks.GetEnumerator()) {
        if ($check.Value) {
            Write-Host "  ✓ $($check.Key) configured" -ForegroundColor Green
        } else {
            $allChecksPass = $false
            $errors += "Missing configuration in build.gradle: $($check.Key)"
            Write-Host "  ✗ $($check.Key) missing" -ForegroundColor Red
        }
    }
    
    if ($allChecksPass) {
        $success += "build.gradle configuration complete"
    }
} else {
    $errors += "android/app/build.gradle not found"
}

# Check 7: Build scripts
Write-Host "[7/10] Checking build scripts..." -ForegroundColor Yellow
$buildScripts = @(
    "scripts\build_apk.ps1",
    "scripts\build_aab.ps1",
    "scripts\build_android.ps1",
    "scripts\version_manager.ps1",
    "scripts\generate_keystore.ps1"
)

foreach ($script in $buildScripts) {
    $scriptPath = Join-Path $projectRoot $script
    if (Test-Path $scriptPath) {
        Write-Host "  ✓ $script exists" -ForegroundColor Green
    } else {
        $warnings += "Build script missing: $script"
        Write-Host "  ⚠ $script missing" -ForegroundColor Yellow
    }
}

# Check 8: .gitignore configuration
Write-Host "[8/10] Checking .gitignore..." -ForegroundColor Yellow
$gitignorePath = Join-Path $projectRoot ".gitignore"
if (Test-Path $gitignorePath) {
    $gitignoreContent = Get-Content $gitignorePath -Raw
    $sensitiveFiles = @("key.properties", "*.jks", "*.keystore", "local.properties")
    
    $allIgnored = $true
    foreach ($file in $sensitiveFiles) {
        if ($gitignoreContent -match [regex]::Escape($file)) {
            Write-Host "  ✓ $file is ignored" -ForegroundColor Green
        } else {
            $allIgnored = $false
            $warnings += "$file should be in .gitignore"
            Write-Host "  ⚠ $file not in .gitignore" -ForegroundColor Yellow
        }
    }
    
    if ($allIgnored) {
        $success += "Sensitive files are properly ignored"
    }
} else {
    $warnings += ".gitignore not found"
}

# Check 9: Dependencies
Write-Host "[9/10] Checking Flutter dependencies..." -ForegroundColor Yellow
$pubGet = flutter pub get 2>&1
if ($LASTEXITCODE -eq 0) {
    $success += "Dependencies are up to date"
    Write-Host "  ✓ Dependencies OK" -ForegroundColor Green
} else {
    $errors += "Failed to get Flutter dependencies"
    Write-Host "  ✗ Dependencies check failed" -ForegroundColor Red
}

# Check 10: Build capability test
Write-Host "[10/10] Testing build capability..." -ForegroundColor Yellow
if ($errors.Count -eq 0) {
    Write-Host "  ✓ Build configuration appears valid" -ForegroundColor Green
    $success += "Build configuration is valid"
} else {
    Write-Host "  ✗ Build configuration has errors" -ForegroundColor Red
}

# Summary
Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Verification Summary" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

if ($success.Count -gt 0) {
    Write-Host "✓ Success ($($success.Count)):" -ForegroundColor Green
    foreach ($item in $success) {
        Write-Host "  • $item" -ForegroundColor White
    }
    Write-Host ""
}

if ($warnings.Count -gt 0) {
    Write-Host "⚠ Warnings ($($warnings.Count)):" -ForegroundColor Yellow
    foreach ($item in $warnings) {
        Write-Host "  • $item" -ForegroundColor White
    }
    Write-Host ""
}

if ($errors.Count -gt 0) {
    Write-Host "✗ Errors ($($errors.Count)):" -ForegroundColor Red
    foreach ($item in $errors) {
        Write-Host "  • $item" -ForegroundColor White
    }
    Write-Host ""
}

# Final status
Write-Host "=========================================" -ForegroundColor Cyan
if ($errors.Count -eq 0) {
    if ($warnings.Count -eq 0) {
        Write-Host "Status: ✓ READY TO BUILD" -ForegroundColor Green
        Write-Host ""
        Write-Host "Next steps:" -ForegroundColor Yellow
        Write-Host "  • Build APK: .\scripts\build_apk.ps1" -ForegroundColor White
        Write-Host "  • Build AAB: .\scripts\build_aab.ps1" -ForegroundColor White
    } else {
        Write-Host "Status: ⚠ READY (with warnings)" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "You can build, but consider fixing warnings:" -ForegroundColor Yellow
        if ($warnings -match "key.properties") {
            Write-Host "  • Set up signing: .\scripts\generate_keystore.ps1" -ForegroundColor White
        }
    }
} else {
    Write-Host "Status: ✗ NOT READY - Fix errors first" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please fix the errors above before building." -ForegroundColor Yellow
    exit 1
}

Write-Host ""