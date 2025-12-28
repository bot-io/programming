# Verification Script for Web Platform Settings - Dual Reader 3.1
# This script verifies that all PWA and web platform settings are correctly configured

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Web Platform Settings Verification" -ForegroundColor Cyan
Write-Host "Dual Reader 3.1" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$errors = 0
$warnings = 0

# Check manifest.json
Write-Host "Checking manifest.json..." -ForegroundColor Yellow
if (Test-Path "web\manifest.json") {
    $manifest = Get-Content "web\manifest.json" -Raw | ConvertFrom-Json
    if ($manifest.name -and $manifest.short_name -and $manifest.icons) {
        Write-Host "  ✓ manifest.json exists and is valid" -ForegroundColor Green
        Write-Host "    - Name: $($manifest.name)" -ForegroundColor Gray
        Write-Host "    - Short Name: $($manifest.short_name)" -ForegroundColor Gray
        Write-Host "    - Icons: $($manifest.icons.Count) icon definitions" -ForegroundColor Gray
        Write-Host "    - Display: $($manifest.display)" -ForegroundColor Gray
    } else {
        Write-Host "  ✗ manifest.json is missing required fields" -ForegroundColor Red
        $errors++
    }
} else {
    Write-Host "  ✗ manifest.json not found" -ForegroundColor Red
    $errors++
}

# Check service worker
Write-Host ""
Write-Host "Checking service worker..." -ForegroundColor Yellow
if (Test-Path "web\service-worker.js") {
    Write-Host "  ✓ service-worker.js exists" -ForegroundColor Green
    Write-Host "    Note: Flutter automatically generates flutter_service_worker.js during build" -ForegroundColor Gray
} else {
    Write-Host "  ⚠ service-worker.js not found (optional, Flutter generates its own)" -ForegroundColor Yellow
    $warnings++
}

# Check index.html
Write-Host ""
Write-Host "Checking index.html..." -ForegroundColor Yellow
if (Test-Path "web\index.html") {
    $indexHtml = Get-Content "web\index.html" -Raw
    $checks = @{
        "manifest link" = $indexHtml -match 'rel="manifest"'
        "viewport meta" = $indexHtml -match 'name="viewport"'
        "theme-color meta" = $indexHtml -match 'name="theme-color"'
        "PWA install script" = $indexHtml -match 'beforeinstallprompt'
        "service worker script" = $indexHtml -match 'serviceWorker'
    }
    
    $allPassed = $true
    foreach ($check in $checks.GetEnumerator()) {
        if ($check.Value) {
            Write-Host "  ✓ $($check.Key) found" -ForegroundColor Green
        } else {
            Write-Host "  ✗ $($check.Key) missing" -ForegroundColor Red
            $allPassed = $false
            $errors++
        }
    }
    
    if ($allPassed) {
        Write-Host "  ✓ index.html has all required PWA configurations" -ForegroundColor Green
    }
} else {
    Write-Host "  ✗ index.html not found" -ForegroundColor Red
    $errors++
}

# Check icons
Write-Host ""
Write-Host "Checking PWA icons..." -ForegroundColor Yellow
$requiredIcons = @(16, 32, 72, 96, 128, 144, 152, 192, 384, 512)
$missingIcons = @()

foreach ($size in $requiredIcons) {
    $iconPath = "web\icons\icon-${size}x${size}.png"
    if (Test-Path $iconPath) {
        Write-Host "  ✓ icon-${size}x${size}.png exists" -ForegroundColor Green
    } else {
        Write-Host "  ✗ icon-${size}x${size}.png missing" -ForegroundColor Red
        $missingIcons += $size
        $errors++
    }
}

if ($missingIcons.Count -eq 0) {
    Write-Host "  ✓ All required icons are present" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "  ⚠ Missing icons. Generate them using:" -ForegroundColor Yellow
    Write-Host "    1. Open web\icons\generate_icons_now.html in a browser" -ForegroundColor Gray
    Write-Host "    2. Click 'Generate & Download All Icons'" -ForegroundColor Gray
    Write-Host "    3. Save downloaded files to web\icons\" -ForegroundColor Gray
}

# Check favicon
Write-Host ""
Write-Host "Checking favicon..." -ForegroundColor Yellow
if (Test-Path "web\favicon.png") {
    Write-Host "  ✓ favicon.png exists" -ForegroundColor Green
} else {
    Write-Host "  ⚠ favicon.png missing (optional)" -ForegroundColor Yellow
    $warnings++
}

# Check browserconfig.xml
Write-Host ""
Write-Host "Checking browserconfig.xml..." -ForegroundColor Yellow
if (Test-Path "web\browserconfig.xml") {
    Write-Host "  ✓ browserconfig.xml exists" -ForegroundColor Green
} else {
    Write-Host "  ⚠ browserconfig.xml missing (optional for Windows tiles)" -ForegroundColor Yellow
    $warnings++
}

# Check deployment configs
Write-Host ""
Write-Host "Checking deployment configurations..." -ForegroundColor Yellow
$deploymentFiles = @{
    "vercel.json" = "Vercel deployment"
    "_headers" = "Netlify headers"
    ".htaccess" = "Apache configuration"
}

foreach ($file in $deploymentFiles.GetEnumerator()) {
    if (Test-Path "web\$($file.Key)") {
        Write-Host "  ✓ $($file.Key) exists ($($file.Value))" -ForegroundColor Green
    } else {
        Write-Host "  ⚠ $($file.Key) missing ($($file.Value))" -ForegroundColor Yellow
        $warnings++
    }
}

# Summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Verification Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ($errors -eq 0 -and $warnings -eq 0) {
    Write-Host "✓ All checks passed! Web platform is fully configured." -ForegroundColor Green
    exit 0
} elseif ($errors -eq 0) {
    Write-Host "✓ All critical checks passed!" -ForegroundColor Green
    Write-Host "⚠ $warnings warning(s) - optional configurations missing" -ForegroundColor Yellow
    exit 0
} else {
    Write-Host "✗ $errors error(s) found - please fix before deployment" -ForegroundColor Red
    if ($warnings -gt 0) {
        Write-Host "⚠ $warnings warning(s) - optional configurations missing" -ForegroundColor Yellow
    }
    exit 1
}
