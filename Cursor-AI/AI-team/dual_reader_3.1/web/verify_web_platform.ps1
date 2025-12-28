# Web Platform Configuration Verification Script
# Verifies PWA manifest, service worker, and responsive meta tags

param(
    [string]$WebRoot = "."
)

$ErrorActionPreference = "Stop"
$webRoot = Resolve-Path $WebRoot

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Web Platform Configuration Verification" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$errors = @()
$warnings = @()
$success = @()

# Check 1: Verify manifest.json
Write-Host "[1/5] Checking manifest.json..." -ForegroundColor Yellow
$manifestPath = Join-Path $webRoot "manifest.json"
if (Test-Path $manifestPath) {
    try {
        $manifestContent = Get-Content $manifestPath -Raw
        $manifest = $manifestContent | ConvertFrom-Json
        
        # Required fields for PWA installability
        $requiredFields = @('name', 'short_name', 'icons', 'start_url', 'display')
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
        
        # Check icons
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
        
        # Check display mode
        $installableDisplays = @('standalone', 'fullscreen', 'minimal-ui')
        if ($manifest.display -in $installableDisplays) {
            $success += "manifest.json has installable display mode: $($manifest.display)"
        } else {
            $warnings += "manifest.json display mode '$($manifest.display)' may not be installable"
        }
        
        # Check start_url
        if ($manifest.start_url) {
            $success += "manifest.json has start_url: $($manifest.start_url)"
        } else {
            $errors += "manifest.json missing start_url"
        }
        
        # Check theme_color
        if ($manifest.theme_color) {
            $success += "manifest.json has theme_color: $($manifest.theme_color)"
        } else {
            $warnings += "manifest.json missing theme_color (recommended)"
        }
        
        # Check background_color
        if ($manifest.background_color) {
            $success += "manifest.json has background_color: $($manifest.background_color)"
        } else {
            $warnings += "manifest.json missing background_color (recommended)"
        }
        
        Write-Host "  ✓ manifest.json is valid JSON" -ForegroundColor Green
    } catch {
        $errors += "manifest.json is not valid JSON: $_"
        Write-Host "  ✗ manifest.json is not valid JSON" -ForegroundColor Red
    }
} else {
    $errors += "manifest.json not found at $manifestPath"
    Write-Host "  ✗ manifest.json not found" -ForegroundColor Red
}

# Check 2: Verify service-worker.js
Write-Host "`n[2/5] Checking service-worker.js..." -ForegroundColor Yellow
$swPath = Join-Path $webRoot "service-worker.js"
if (Test-Path $swPath) {
    $swContent = Get-Content $swPath -Raw
    
    # Check for essential service worker features
    $features = @(
        @{ Feature = "install"; Pattern = "addEventListener\s*\(\s*['\`"]install['\`"]" },
        @{ Feature = "activate"; Pattern = "addEventListener\s*\(\s*['\`"]activate['\`"]" },
        @{ Feature = "fetch"; Pattern = "addEventListener\s*\(\s*['\`"]fetch['\`"]" }
    )
    
    foreach ($feature in $features) {
        if ($swContent -match $feature.Pattern) {
            $success += "service-worker.js has $($feature.Feature) handler"
        } else {
            $warnings += "service-worker.js may be missing $($feature.Feature) handler"
        }
    }
    
    # Check for caching
    if ($swContent -match "caches\.(open|match|put|addAll|delete)") {
        $success += "service-worker.js implements caching"
    } else {
        $warnings += "service-worker.js may not implement caching"
    }
    
    Write-Host "  ✓ service-worker.js exists" -ForegroundColor Green
} else {
    $errors += "service-worker.js not found at $swPath"
    Write-Host "  ✗ service-worker.js not found" -ForegroundColor Red
}

# Check 3: Verify index.html
Write-Host "`n[3/5] Checking index.html..." -ForegroundColor Yellow
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
    if ($indexContent -match '<meta\s+name\s*=\s*["'']viewport["'']') {
        $success += "index.html has viewport meta tag"
    } else {
        $errors += "index.html missing viewport meta tag (required for responsive design)"
    }
    
    # Check theme-color meta tag
    if ($indexContent -match '<meta\s+name\s*=\s*["'']theme-color["'']') {
        $success += "index.html has theme-color meta tag"
    } else {
        $warnings += "index.html missing theme-color meta tag (recommended)"
    }
    
    # Check responsive meta tags
    $responsiveTags = @(
        @{ Name = "HandheldFriendly"; Pattern = '<meta\s+name\s*=\s*["'']HandheldFriendly["'']' },
        @{ Name = "MobileOptimized"; Pattern = '<meta\s+name\s*=\s*["'']MobileOptimized["'']' },
        @{ Name = "apple-mobile-web-app-capable"; Pattern = '<meta\s+name\s*=\s*["'']apple-mobile-web-app-capable["'']' }
    )
    
    foreach ($tag in $responsiveTags) {
        if ($indexContent -match $tag.Pattern) {
            $success += "index.html has $($tag.Name) meta tag"
        } else {
            $warnings += "index.html missing $($tag.Name) meta tag (recommended for mobile)"
        }
    }
    
    Write-Host "  ✓ index.html exists" -ForegroundColor Green
} else {
    $errors += "index.html not found at $indexPath"
    Write-Host "  ✗ index.html not found" -ForegroundColor Red
}

# Check 4: Verify browserconfig.xml (optional)
Write-Host "`n[4/5] Checking browserconfig.xml..." -ForegroundColor Yellow
$browserConfigPath = Join-Path $webRoot "browserconfig.xml"
if (Test-Path $browserConfigPath) {
    $success += "browserconfig.xml exists (Windows tile configuration)"
    Write-Host "  ✓ browserconfig.xml exists" -ForegroundColor Green
} else {
    $warnings += "browserconfig.xml not found (optional for Windows tiles)"
    Write-Host "  ⚠ browserconfig.xml not found (optional)" -ForegroundColor Yellow
}

# Check 5: Verify icons directory
Write-Host "`n[5/5] Checking icons..." -ForegroundColor Yellow
$iconsPath = Join-Path $webRoot "icons"
if (Test-Path $iconsPath) {
    $iconFiles = Get-ChildItem -Path $iconsPath -Filter "*.png" -ErrorAction SilentlyContinue
    if ($iconFiles) {
        $success += "Icons directory exists with $($iconFiles.Count) PNG files"
        Write-Host "  ✓ Icons directory exists with $($iconFiles.Count) PNG files" -ForegroundColor Green
    } else {
        $warnings += "Icons directory exists but no PNG files found (icons may need to be generated)"
        Write-Host "  ⚠ Icons directory exists but no PNG files found" -ForegroundColor Yellow
    }
} else {
    $warnings += "Icons directory not found (icons may need to be generated)"
    Write-Host "  ⚠ Icons directory not found" -ForegroundColor Yellow
}

# Summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Verification Summary" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

if ($success.Count -gt 0) {
    Write-Host "✓ Success ($($success.Count)):" -ForegroundColor Green
    foreach ($msg in $success) {
        Write-Host "  • $msg" -ForegroundColor Green
    }
    Write-Host ""
}

if ($warnings.Count -gt 0) {
    Write-Host "⚠ Warnings ($($warnings.Count)):" -ForegroundColor Yellow
    foreach ($msg in $warnings) {
        Write-Host "  • $msg" -ForegroundColor Yellow
    }
    Write-Host ""
}

if ($errors.Count -gt 0) {
    Write-Host "✗ Errors ($($errors.Count)):" -ForegroundColor Red
    foreach ($msg in $errors) {
        Write-Host "  • $msg" -ForegroundColor Red
    }
    Write-Host ""
    exit 1
}

# PWA Installability Check
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "PWA Installability Requirements" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$installabilityChecks = @(
    @{ Check = "Manifest with required fields"; Status = ($manifest -and $manifest.name -and $manifest.short_name -and $manifest.icons -and $manifest.start_url -and $manifest.display) },
    @{ Check = "192x192 icon in manifest"; Status = ($manifest.icons | Where-Object { $_.sizes -eq "192x192" }) },
    @{ Check = "512x512 icon in manifest"; Status = ($manifest.icons | Where-Object { $_.sizes -eq "512x512" }) },
    @{ Check = "Installable display mode (standalone/fullscreen/minimal-ui)"; Status = ($manifest.display -in @('standalone', 'fullscreen', 'minimal-ui')) },
    @{ Check = "Service worker with fetch handler"; Status = ($swContent -match "addEventListener\s*\(\s*['\`"]fetch['\`"]") },
    @{ Check = "Manifest linked in index.html"; Status = ($indexContent -match 'rel\s*=\s*["'']manifest["'']') },
    @{ Check = "Service worker registered in index.html"; Status = ($indexContent -match "serviceWorker\.register" -or $indexContent -match "service-worker") }
)

$allInstallable = $true
foreach ($check in $installabilityChecks) {
    if ($check.Status) {
        Write-Host "  ✓ $($check.Check)" -ForegroundColor Green
    } else {
        Write-Host "  ✗ $($check.Check)" -ForegroundColor Red
        $allInstallable = $false
    }
}

Write-Host ""
if ($allInstallable) {
    Write-Host "✓ PWA is installable!" -ForegroundColor Green
    Write-Host "`nTo test installation:" -ForegroundColor Cyan
    Write-Host "  1. Build the web app: flutter build web" -ForegroundColor White
    Write-Host "  2. Serve it: flutter run -d chrome --web-port=8080" -ForegroundColor White
    Write-Host "  3. Open Chrome DevTools > Application > Manifest" -ForegroundColor White
    Write-Host "  4. Check 'Add to homescreen' button or install prompt" -ForegroundColor White
} else {
    Write-Host "✗ PWA may not be installable. Please fix the errors above." -ForegroundColor Red
    exit 1
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Verification Complete" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan
