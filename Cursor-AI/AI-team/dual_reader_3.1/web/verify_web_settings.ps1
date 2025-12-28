# Verification script for Web Platform Settings
# Checks all PWA configuration files and requirements

$ErrorActionPreference = "Continue"
$webRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$errors = @()
$warnings = @()
$success = @()

Write-Host "`n🔍 Verifying Web Platform Settings for Dual Reader 3.1`n" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Gray
Write-Host ""

# Check 1: Verify manifest.json
Write-Host "[1/5] Checking manifest.json..." -ForegroundColor Yellow
$manifestPath = Join-Path $webRoot "manifest.json"
if (Test-Path $manifestPath) {
    try {
        $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
        $requiredFields = @("name", "short_name", "icons", "start_url", "display")
        $missingFields = @()
        
        foreach ($field in $requiredFields) {
            if (-not $manifest.$field) {
                $missingFields += $field
            }
        }
        
        if ($missingFields.Count -eq 0) {
            $success += "manifest.json has all required fields"
        } else {
            $errors += "manifest.json missing required fields: $($missingFields -join ', ')"
        }
        
        if ($manifest.icons -and $manifest.icons.Count -gt 0) {
            $iconSizes = $manifest.icons | ForEach-Object { $_.sizes } | Where-Object { $_ }
            $has192 = $iconSizes | Where-Object { $_ -eq "192x192" }
            $has512 = $iconSizes | Where-Object { $_ -eq "512x512" }
            
            if ($has192 -and $has512) {
                $success += "manifest.json has required icon sizes (192x192, 512x512)"
            } else {
                if (-not $has192) { $warnings += "manifest.json missing 192x192 icon (required for Android)" }
                if (-not $has512) { $warnings += "manifest.json missing 512x512 icon (required for PWA)" }
            }
        } else {
            $errors += "manifest.json has no icons defined"
        }
        
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

# Check 2: Verify service-worker.js
Write-Host "[2/5] Checking service-worker.js..." -ForegroundColor Yellow
$swPath = Join-Path $webRoot "service-worker.js"
if (Test-Path $swPath) {
    $swContent = Get-Content $swPath -Raw
    
    $requiredFeatures = @(
        @{Feature = "install event"; Pattern = "addEventListener\s*\(\s*['\`"]install['\`"]"},
        @{Feature = "activate event"; Pattern = "addEventListener\s*\(\s*['\`"]activate['\`"]"},
        @{Feature = "fetch event"; Pattern = "addEventListener\s*\(\s*['\`"]fetch['\`"]"}
    )
    
    foreach ($feature in $requiredFeatures) {
        if ($swContent -match $feature.Pattern) {
            $success += "service-worker.js has $($feature.Feature) handler"
        } else {
            $warnings += "service-worker.js may be missing $($feature.Feature) handler"
        }
    }
    
    if ($swContent -match "cache|Cache") {
        $success += "service-worker.js implements caching"
    } else {
        $warnings += "service-worker.js may not implement caching"
    }
    
    $success += "service-worker.js exists"
} else {
    $errors += "service-worker.js not found at $swPath"
}

# Check 3: Verify index.html
Write-Host "[3/5] Checking index.html..." -ForegroundColor Yellow
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
    
    # Check viewport meta tag
    if ($indexContent -match 'name\s*=\s*["'']viewport["'']') {
        $success += "index.html has viewport meta tag"
    } else {
        $warnings += "index.html missing viewport meta tag"
    }
    
    # Check theme-color meta tag
    if ($indexContent -match 'name\s*=\s*["'']theme-color["'']') {
        $success += "index.html has theme-color meta tag"
    } else {
        $warnings += "index.html missing theme-color meta tag"
    }
    
    $success += "index.html exists"
} else {
    $errors += "index.html not found at $indexPath"
}

# Check 4: Verify icons
Write-Host "[4/5] Checking icons..." -ForegroundColor Yellow
$iconsDir = Join-Path $webRoot "icons"
$requiredIcons = @(16, 32, 72, 96, 128, 144, 152, 192, 384, 512)
$missingIcons = @()

if (Test-Path $iconsDir) {
    foreach ($size in $requiredIcons) {
        $iconPath = Join-Path $iconsDir "icon-${size}x${size}.png"
        if (-not (Test-Path $iconPath)) {
            $missingIcons += "${size}x${size}"
        }
    }
    
    if ($missingIcons.Count -eq 0) {
        $success += "All required icons exist"
    } else {
        $warnings += "Missing icons: $($missingIcons -join ', ')"
        $warnings += "  Generate icons using: web/icons/generate_icons_canvas.html"
    }
    
    # Check required icons for PWA
    $required192 = Join-Path $iconsDir "icon-192x192.png"
    $required512 = Join-Path $iconsDir "icon-512x512.png"
    
    if (-not (Test-Path $required192)) {
        $errors += "Missing required icon: icon-192x192.png (required for Android PWA)"
    }
    if (-not (Test-Path $required512)) {
        $errors += "Missing required icon: icon-512x512.png (required for PWA installation)"
    }
} else {
    $warnings += "Icons directory not found: $iconsDir"
}

# Check favicon
$faviconPath = Join-Path $webRoot "favicon.png"
if (Test-Path $faviconPath) {
    $success += "favicon.png exists"
} else {
    $warnings += "favicon.png missing (recommended)"
}

# Check 5: Verify browserconfig.xml
Write-Host "[5/5] Checking browserconfig.xml..." -ForegroundColor Yellow
$browserConfigPath = Join-Path $webRoot "browserconfig.xml"
if (Test-Path $browserConfigPath) {
    $success += "browserconfig.xml exists (Windows tiles)"
} else {
    $warnings += "browserconfig.xml missing (optional, for Windows tiles)"
}

# Summary
Write-Host "`n" + ("=" * 60) -ForegroundColor Gray
Write-Host "`n📊 Verification Summary`n" -ForegroundColor Cyan

if ($success.Count -gt 0) {
    Write-Host "✅ Success ($($success.Count)):" -ForegroundColor Green
    foreach ($msg in $success) {
        Write-Host "   ✓ $msg" -ForegroundColor Green
    }
}

if ($warnings.Count -gt 0) {
    Write-Host "`n⚠️  Warnings ($($warnings.Count)):" -ForegroundColor Yellow
    foreach ($msg in $warnings) {
        Write-Host "   ⚠ $msg" -ForegroundColor Yellow
    }
}

if ($errors.Count -gt 0) {
    Write-Host "`n❌ Errors ($($errors.Count)):" -ForegroundColor Red
    foreach ($msg in $errors) {
        Write-Host "   ✗ $msg" -ForegroundColor Red
    }
}

Write-Host "`n" + ("=" * 60) -ForegroundColor Gray

# Final status
if ($errors.Count -eq 0) {
    if ($warnings.Count -eq 0) {
        Write-Host "`n🎉 All checks passed! Web platform is fully configured.`n" -ForegroundColor Green
        exit 0
    } else {
        Write-Host "`n✅ Configuration complete with warnings. Review warnings above.`n" -ForegroundColor Yellow
        Write-Host "💡 Tip: Generate icons using web/icons/generate_icons_canvas.html`n" -ForegroundColor Cyan
        exit 0
    }
} else {
    Write-Host "`n❌ Configuration incomplete. Please fix errors above.`n" -ForegroundColor Red
    exit 1
}
