# PowerShell script to verify PWA configuration for Dual Reader 3.1
# This script checks all PWA requirements are met

$ErrorActionPreference = "Continue"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$webDir = $scriptDir
$iconsDir = Join-Path $webDir "icons"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "PWA Configuration Verification" -ForegroundColor Cyan
Write-Host "Dual Reader 3.1" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$errors = @()
$warnings = @()
$success = @()

# Check 1: manifest.json exists
Write-Host "[1/7] Checking manifest.json..." -ForegroundColor Yellow
$manifestPath = Join-Path $webDir "manifest.json"
if (Test-Path $manifestPath) {
    $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
    $success += "✓ manifest.json exists"
    
    # Verify required fields
    $requiredFields = @("name", "short_name", "start_url", "display", "icons")
    foreach ($field in $requiredFields) {
        if ($manifest.PSObject.Properties.Name -contains $field) {
            $success += "  ✓ Contains required field: $field"
        } else {
            $errors += "  ✗ Missing required field: $field"
        }
    }
    
    # Check icons array
    if ($manifest.icons -and $manifest.icons.Count -gt 0) {
        $success += "  ✓ Icons array configured ($($manifest.icons.Count) icons)"
    } else {
        $errors += "  ✗ Icons array is empty or missing"
    }
} else {
    $errors += "✗ manifest.json not found"
}

# Check 2: index.html exists with proper meta tags
Write-Host "[2/7] Checking index.html..." -ForegroundColor Yellow
$indexPath = Join-Path $webDir "index.html"
if (Test-Path $indexPath) {
    $indexContent = Get-Content $indexPath -Raw
    $success += "✓ index.html exists"
    
    # Check for manifest link
    if ($indexContent -match 'rel="manifest"') {
        $success += "  ✓ Manifest link found"
    } else {
        $errors += "  ✗ Manifest link not found in index.html"
    }
    
    # Check for viewport meta tag
    if ($indexContent -match 'name="viewport"') {
        $success += "  ✓ Viewport meta tag found"
    } else {
        $errors += "  ✗ Viewport meta tag not found"
    }
    
    # Check for theme-color
    if ($indexContent -match 'name="theme-color"') {
        $success += "  ✓ Theme color meta tag found"
    } else {
        $warnings += "  ⚠ Theme color meta tag not found"
    }
    
    # Check for apple-mobile-web-app-capable
    if ($indexContent -match 'apple-mobile-web-app-capable') {
        $success += "  ✓ Apple mobile web app meta tags found"
    } else {
        $warnings += "  ⚠ Apple mobile web app meta tags not found"
    }
} else {
    $errors += "✗ index.html not found"
}

# Check 3: Service worker configuration
Write-Host "[3/7] Checking service worker configuration..." -ForegroundColor Yellow
$swPath = Join-Path $webDir "service-worker.js"
if (Test-Path $swPath) {
    $success += "✓ service-worker.js exists (custom)"
} else {
    $warnings += "⚠ service-worker.js not found (Flutter will generate flutter_service_worker.js automatically)"
}

if ($indexContent -match 'flutter_service_worker|serviceWorker') {
    $success += "  ✓ Service worker registration code found in index.html"
} else {
    $warnings += "  ⚠ Service worker registration not explicitly found (Flutter handles this automatically)"
}

# Check 4: Icons exist
Write-Host "[4/7] Checking PWA icons..." -ForegroundColor Yellow
$requiredIconSizes = @(16, 32, 72, 96, 128, 144, 152, 192, 384, 512)
$missingIcons = @()
$foundIcons = 0

foreach ($size in $requiredIconSizes) {
    $iconPath = Join-Path $iconsDir "icon-${size}x${size}.png"
    if (Test-Path $iconPath) {
        $foundIcons++
    } else {
        $missingIcons += $size
    }
}

if ($foundIcons -eq $requiredIconSizes.Count) {
    $success += "✓ All required icons exist ($foundIcons/$($requiredIconSizes.Count))"
} elseif ($foundIcons -gt 0) {
    $warnings += "⚠ Some icons missing ($foundIcons/$($requiredIconSizes.Count) found)"
    $warnings += "  Missing sizes: $($missingIcons -join ', ')"
    $warnings += "  Run: .\icons\create_placeholder_icons.ps1 to generate placeholder icons"
} else {
    $errors += "✗ No icons found in icons directory"
    $errors += "  Run: .\icons\create_placeholder_icons.ps1 to generate placeholder icons"
}

# Check 5: browserconfig.xml for Windows tiles
Write-Host "[5/7] Checking browserconfig.xml..." -ForegroundColor Yellow
$browserConfigPath = Join-Path $webDir "browserconfig.xml"
if (Test-Path $browserConfigPath) {
    $success += "✓ browserconfig.xml exists"
} else {
    $warnings += "⚠ browserconfig.xml not found (optional for Windows tiles)"
}

# Check 6: Flutter build configuration
Write-Host "[6/7] Checking Flutter build configuration..." -ForegroundColor Yellow
$buildConfigPath = Join-Path $webDir "flutter_build_config.json"
if (Test-Path $buildConfigPath) {
    $buildConfig = Get-Content $buildConfigPath -Raw | ConvertFrom-Json
    $success += "✓ flutter_build_config.json exists"
    
    if ($buildConfig.pwa.enabled -eq $true) {
        $success += "  ✓ PWA enabled in build config"
    } else {
        $warnings += "  ⚠ PWA not explicitly enabled in build config"
    }
} else {
    $warnings += "⚠ flutter_build_config.json not found (optional)"
}

# Check 7: PWA service integration
Write-Host "[7/7] Checking PWA service integration..." -ForegroundColor Yellow
$pwaServicePath = Join-Path (Split-Path -Parent $webDir) "lib\services\pwa_service.dart"
if (Test-Path $pwaServicePath) {
    $success += "✓ PWA service exists"
    
    $pwaServiceContent = Get-Content $pwaServicePath -Raw
    if ($pwaServiceContent -match 'isStandalone|canInstall|showInstallPrompt') {
        $success += "  ✓ PWA service has required methods"
    }
} else {
    $warnings += "⚠ PWA service not found in lib/services/"
}

# Summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Verification Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ($success.Count -gt 0) {
    Write-Host "✓ Success ($($success.Count) checks passed):" -ForegroundColor Green
    foreach ($item in $success) {
        Write-Host "  $item" -ForegroundColor Green
    }
    Write-Host ""
}

if ($warnings.Count -gt 0) {
    Write-Host "⚠ Warnings ($($warnings.Count)):" -ForegroundColor Yellow
    foreach ($item in $warnings) {
        Write-Host "  $item" -ForegroundColor Yellow
    }
    Write-Host ""
}

if ($errors.Count -gt 0) {
    Write-Host "✗ Errors ($($errors.Count)):" -ForegroundColor Red
    foreach ($item in $errors) {
        Write-Host "  $item" -ForegroundColor Red
    }
    Write-Host ""
}

# Final status
Write-Host "========================================" -ForegroundColor Cyan
if ($errors.Count -eq 0) {
    Write-Host "Status: PWA Configuration Complete ✓" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "  1. Build the web app: flutter build web" -ForegroundColor White
    Write-Host "  2. Test locally: flutter run -d chrome" -ForegroundColor White
    Write-Host "  3. Deploy to hosting service (GitHub Pages, Netlify, etc.)" -ForegroundColor White
    Write-Host "  4. Test PWA installation in browser" -ForegroundColor White
} else {
    Write-Host "Status: Configuration Incomplete ✗" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please fix the errors above before deploying." -ForegroundColor Yellow
}
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

exit $errors.Count
