# PowerShell script to verify web platform settings for Dual Reader 3.1
# Checks PWA manifest, service worker, meta tags, and icons

$ErrorActionPreference = "Continue"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$webDir = $scriptDir
$iconsDir = Join-Path $webDir "icons"

$errors = @()
$warnings = @()
$success = @()

Write-Host "`n=== Dual Reader 3.1 - Web Platform Verification ===" -ForegroundColor Cyan
Write-Host ""

# Check manifest.json
Write-Host "Checking manifest.json..." -ForegroundColor Yellow
$manifestPath = Join-Path $webDir "manifest.json"
if (Test-Path $manifestPath) {
    try {
        $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
        
        # Check required fields
        $requiredFields = @("name", "short_name", "start_url", "display", "theme_color", "background_color", "icons")
        foreach ($field in $requiredFields) {
            if ($manifest.PSObject.Properties.Name -contains $field) {
                $success += "✓ manifest.json has '$field'"
            } else {
                $errors += "✗ manifest.json missing required field: '$field'"
            }
        }
        
        # Check icons array
        if ($manifest.icons -and $manifest.icons.Count -gt 0) {
            $success += "✓ manifest.json has icons array with $($manifest.icons.Count) entries"
        } else {
            $errors += "✗ manifest.json missing icons array"
        }
        
        # Check display mode
        if ($manifest.display -eq "standalone" -or $manifest.display -eq "fullscreen") {
            $success += "✓ manifest.json has installable display mode: $($manifest.display)"
        } else {
            $warnings += "⚠ manifest.json display mode '$($manifest.display)' may not be optimal for PWA"
        }
        
        Write-Host "  ✓ manifest.json exists and is valid JSON" -ForegroundColor Green
    } catch {
        $errors += "✗ manifest.json is invalid JSON: $_"
        Write-Host "  ✗ manifest.json is invalid" -ForegroundColor Red
    }
} else {
    $errors += "✗ manifest.json not found"
    Write-Host "  ✗ manifest.json not found" -ForegroundColor Red
}

# Check service-worker.js
Write-Host "Checking service-worker.js..." -ForegroundColor Yellow
$swPath = Join-Path $webDir "service-worker.js"
if (Test-Path $swPath) {
    $swContent = Get-Content $swPath -Raw
    
    # Check for required service worker features
    $swChecks = @{
        "install event" = $swContent -match "addEventListener\s*\(\s*['\`"]install"
        "activate event" = $swContent -match "addEventListener\s*\(\s*['\`"]activate"
        "fetch event" = $swContent -match "addEventListener\s*\(\s*['\`"]fetch"
        "cache handling" = $swContent -match "caches\.(open|match|put)"
    }
    
    foreach ($check in $swChecks.GetEnumerator()) {
        if ($check.Value) {
            $success += "✓ service-worker.js has $($check.Key)"
        } else {
            $warnings += "⚠ service-worker.js missing $($check.Key)"
        }
    }
    
    Write-Host "  ✓ service-worker.js exists" -ForegroundColor Green
} else {
    $errors += "✗ service-worker.js not found"
    Write-Host "  ✗ service-worker.js not found" -ForegroundColor Red
}

# Check index.html
Write-Host "Checking index.html..." -ForegroundColor Yellow
$indexPath = Join-Path $webDir "index.html"
if (Test-Path $indexPath) {
    $indexContent = Get-Content $indexPath -Raw
    
    # Check for required meta tags
    $metaChecks = @{
        "viewport meta tag" = $indexContent -match '<meta\s+name=["\']viewport["\']'
        "theme-color meta tag" = $indexContent -match '<meta\s+name=["\']theme-color["\']'
        "manifest link" = $indexContent -match '<link\s+rel=["\']manifest["\']'
        "service worker registration" = $indexContent -match "serviceWorker\.register"
        "PWA install prompt" = $indexContent -match "beforeinstallprompt"
    }
    
    foreach ($check in $metaChecks.GetEnumerator()) {
        if ($check.Value) {
            $success += "✓ index.html has $($check.Key)"
        } else {
            $warnings += "⚠ index.html missing $($check.Key)"
        }
    }
    
    Write-Host "  ✓ index.html exists" -ForegroundColor Green
} else {
    $errors += "✗ index.html not found"
    Write-Host "  ✗ index.html not found" -ForegroundColor Red
}

# Check icons
Write-Host "Checking icons..." -ForegroundColor Yellow
$requiredIconSizes = @(16, 32, 72, 96, 128, 144, 152, 192, 384, 512)
$missingIcons = @()

foreach ($size in $requiredIconSizes) {
    $iconPath = Join-Path $iconsDir "icon-${size}x${size}.png"
    if (Test-Path $iconPath) {
        $success += "✓ icon-${size}x${size}.png exists"
    } else {
        $missingIcons += $size
        $warnings += "⚠ Missing icon: icon-${size}x${size}.png"
    }
}

if ($missingIcons.Count -eq 0) {
    Write-Host "  ✓ All required icons exist" -ForegroundColor Green
} else {
    Write-Host "  ⚠ Missing $($missingIcons.Count) icons" -ForegroundColor Yellow
    Write-Host "    Run: .\generate_icons.ps1 or open web/icons/generate_icons_simple.html" -ForegroundColor Cyan
}

# Check favicon
Write-Host "Checking favicon..." -ForegroundColor Yellow
$faviconPath = Join-Path $webDir "favicon.png"
if (Test-Path $faviconPath) {
    $success += "✓ favicon.png exists"
    Write-Host "  ✓ favicon.png exists" -ForegroundColor Green
} else {
    $warnings += "⚠ Missing favicon.png"
    Write-Host "  ⚠ favicon.png not found" -ForegroundColor Yellow
}

# Check browserconfig.xml
Write-Host "Checking browserconfig.xml..." -ForegroundColor Yellow
$browserConfigPath = Join-Path $webDir "browserconfig.xml"
if (Test-Path $browserConfigPath) {
    $success += "✓ browserconfig.xml exists"
    Write-Host "  ✓ browserconfig.xml exists" -ForegroundColor Green
} else {
    $warnings += "⚠ Missing browserconfig.xml (optional for Windows tiles)"
}

# Summary
Write-Host "`n=== Verification Summary ===" -ForegroundColor Cyan
Write-Host ""

if ($success.Count -gt 0) {
    Write-Host "Successes ($($success.Count)):" -ForegroundColor Green
    foreach ($msg in $success) {
        Write-Host "  $msg" -ForegroundColor Gray
    }
    Write-Host ""
}

if ($warnings.Count -gt 0) {
    Write-Host "Warnings ($($warnings.Count)):" -ForegroundColor Yellow
    foreach ($msg in $warnings) {
        Write-Host "  $msg" -ForegroundColor Yellow
    }
    Write-Host ""
}

if ($errors.Count -gt 0) {
    Write-Host "Errors ($($errors.Count)):" -ForegroundColor Red
    foreach ($msg in $errors) {
        Write-Host "  $msg" -ForegroundColor Red
    }
    Write-Host ""
    Write-Host "✗ Web platform configuration has errors!" -ForegroundColor Red
    exit 1
} else {
    Write-Host "✓ Web platform configuration is valid!" -ForegroundColor Green
    if ($warnings.Count -gt 0) {
        Write-Host "  (Some optional items are missing)" -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "  1. Generate icons if missing: .\generate_icons.ps1" -ForegroundColor White
    Write-Host "  2. Build web app: flutter build web" -ForegroundColor White
    Write-Host "  3. Test PWA installability in Chrome DevTools" -ForegroundColor White
    exit 0
}
