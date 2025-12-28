# Verification script for Web Platform Settings
# Checks that all PWA requirements are met

$ErrorActionPreference = "Stop"
$scriptDir = $PSScriptRoot
$webRoot = $scriptDir
$iconsDir = Join-Path $webRoot "icons"

$errors = @()
$warnings = @()
$success = @()

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Web Platform Configuration Verification" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check 1: Verify manifest.json exists and is valid
Write-Host "[1/6] Checking manifest.json..." -ForegroundColor Yellow
$manifestPath = Join-Path $webRoot "manifest.json"
if (Test-Path $manifestPath) {
    try {
        $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
        
        # Check required fields
        $requiredFields = @("name", "short_name", "start_url", "display", "icons")
        foreach ($field in $requiredFields) {
            if (-not $manifest.$field) {
                $errors += "manifest.json missing required field: $field"
            }
        }
        
        # Check icons array
        if ($manifest.icons -and $manifest.icons.Count -gt 0) {
            $success += "manifest.json has $($manifest.icons.Count) icon definitions"
            
            # Check for required icon sizes
            $requiredSizes = @("192x192", "512x512")
            $iconSizes = $manifest.icons | ForEach-Object { $_.sizes }
            foreach ($size in $requiredSizes) {
                if ($iconSizes -notcontains $size) {
                    $warnings += "manifest.json missing recommended icon size: $size"
                }
            }
        } else {
            $errors += "manifest.json has no icons defined"
        }
        
        # Check display mode
        if ($manifest.display -eq "standalone" -or $manifest.display -eq "fullscreen") {
            $success += "manifest.json has installable display mode: $($manifest.display)"
        } else {
            $warnings += "manifest.json display mode '$($manifest.display)' may not be installable"
        }
        
        $success += "manifest.json is valid JSON"
    } catch {
        $errors += "manifest.json is not valid JSON: $_"
    }
} else {
    $errors += "manifest.json not found at $manifestPath"
}

# Check 2: Verify service-worker.js exists
Write-Host "[2/6] Checking service-worker.js..." -ForegroundColor Yellow
$swPath = Join-Path $webRoot "service-worker.js"
if (Test-Path $swPath) {
    $swContent = Get-Content $swPath -Raw
    if ($swContent -match "addEventListener\s*\(\s*['""]install['""]") {
        $success += "service-worker.js has install event handler"
    } else {
        $warnings += "service-worker.js may be missing install event handler"
    }
    if ($swContent -match "addEventListener\s*\(\s*['""]activate['""]") {
        $success += "service-worker.js has activate event handler"
    } else {
        $warnings += "service-worker.js may be missing activate event handler"
    }
    if ($swContent -match "addEventListener\s*\(\s*['""]fetch['""]") {
        $success += "service-worker.js has fetch event handler"
    } else {
        $warnings += "service-worker.js may be missing fetch event handler"
    }
    $success += "service-worker.js exists"
} else {
    $errors += "service-worker.js not found at $swPath"
}

# Check 3: Verify index.html has manifest link
Write-Host "[3/6] Checking index.html..." -ForegroundColor Yellow
$indexPath = Join-Path $webRoot "index.html"
if (Test-Path $indexPath) {
    $indexContent = Get-Content $indexPath -Raw
    
    # Check manifest link
    if ($indexContent -match 'rel\s*=\s*["'']manifest["'']') {
        $success += "index.html has manifest link"
    } else {
        $errors += "index.html missing manifest link"
    }
    
    # Check service worker registration
    if ($indexContent -match "serviceWorker\.register" -or $indexContent -match "service-worker") {
        $success += "index.html has service worker registration"
    } else {
        $warnings += "index.html may be missing service worker registration"
    }
    
    # Check responsive meta tags
    if ($indexContent -match 'name\s*=\s*["'']viewport["'']') {
        $success += "index.html has viewport meta tag"
    } else {
        $errors += "index.html missing viewport meta tag"
    }
    
    if ($indexContent -match 'name\s*=\s*["'']theme-color["'']') {
        $success += "index.html has theme-color meta tag"
    } else {
        $warnings += "index.html missing theme-color meta tag"
    }
    
    $success += "index.html exists"
} else {
    $errors += "index.html not found at $indexPath"
}

# Check 4: Verify icons exist
Write-Host "[4/6] Checking PWA icons..." -ForegroundColor Yellow
if (Test-Path $iconsDir) {
    $requiredIconSizes = @(72, 96, 128, 144, 152, 192, 384, 512)
    $missingIcons = @()
    
    foreach ($size in $requiredIconSizes) {
        $iconPath = Join-Path $iconsDir "icon-${size}x${size}.png"
        if (Test-Path $iconPath) {
            $fileInfo = Get-Item $iconPath
            if ($fileInfo.Length -gt 0) {
                $success += "Icon exists: icon-${size}x${size}.png"
            } else {
                $errors += "Icon is empty: icon-${size}x${size}.png"
            }
        } else {
            $missingIcons += $size
        }
    }
    
    if ($missingIcons.Count -eq 0) {
        $success += "All required icons exist"
    } else {
        $warnings += "Missing icons: $($missingIcons -join ', ')x$($missingIcons -join ', ') - Run generate_icons_simple.ps1 to create placeholders"
    }
} else {
    $errors += "Icons directory not found at $iconsDir"
}

# Check 5: Verify favicon exists
Write-Host "[5/6] Checking favicon..." -ForegroundColor Yellow
$faviconPath = Join-Path $webRoot "favicon.png"
if (Test-Path $faviconPath) {
    $success += "favicon.png exists"
} else {
    $warnings += "favicon.png not found (optional but recommended)"
}

# Check 6: Verify browserconfig.xml exists (for Windows tiles)
Write-Host "[6/6] Checking browserconfig.xml..." -ForegroundColor Yellow
$browserConfigPath = Join-Path $webRoot "browserconfig.xml"
if (Test-Path $browserConfigPath) {
    $success += "browserconfig.xml exists (Windows tile support)"
} else {
    $warnings += "browserconfig.xml not found (optional for Windows tiles)"
}

# Summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Verification Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ($success.Count -gt 0) {
    Write-Host "✓ Successes ($($success.Count)):" -ForegroundColor Green
    foreach ($msg in $success) {
        Write-Host "  ✓ $msg" -ForegroundColor Green
    }
    Write-Host ""
}

if ($warnings.Count -gt 0) {
    Write-Host "⚠ Warnings ($($warnings.Count)):" -ForegroundColor Yellow
    foreach ($msg in $warnings) {
        Write-Host "  ⚠ $msg" -ForegroundColor Yellow
    }
    Write-Host ""
}

if ($errors.Count -gt 0) {
    Write-Host "✗ Errors ($($errors.Count)):" -ForegroundColor Red
    foreach ($msg in $errors) {
        Write-Host "  ✗ $msg" -ForegroundColor Red
    }
    Write-Host ""
    exit 1
} else {
    Write-Host "✓ All critical checks passed!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "  1. Build the Flutter web app: flutter build web" -ForegroundColor White
    Write-Host "  2. Test locally: flutter run -d chrome" -ForegroundColor White
    Write-Host "  3. Check PWA installability in Chrome DevTools > Application > Manifest" -ForegroundColor White
    Write-Host ""
    exit 0
}
