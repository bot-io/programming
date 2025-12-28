# Web Platform Settings Verification Script
# Verifies PWA manifest, service worker, responsive meta tags, and installability

Write-Host "🔍 Verifying Web Platform Settings Configuration..." -ForegroundColor Cyan
Write-Host ""

$webDir = "web"
$issues = @()
$warnings = @()
$successes = @()

# 1. Check manifest.json
Write-Host "📋 Checking manifest.json..." -ForegroundColor Yellow
$manifestPath = Join-Path $webDir "manifest.json"
if (Test-Path $manifestPath) {
    $manifestContent = Get-Content $manifestPath -Raw
    
    $requiredFields = @("name", "short_name", "start_url", "display", "icons", "theme_color", "background_color")
    foreach ($field in $requiredFields) {
        if ($manifestContent -match "`"$field`"") {
            $successes += "manifest.json contains $field"
        } else {
            $issues += "manifest.json missing required field: $field"
        }
    }
    
    # Check for PWA installability
    if ($manifestContent -match '"display"\s*:\s*"(standalone|fullscreen|minimal-ui)"') {
        $successes += "manifest.json has installable display mode"
    } else {
        $warnings += "manifest.json display mode may not support PWA installation"
    }
    
    # Check for icons
    if ($manifestContent -match "icon-192x192.png" -and $manifestContent -match "icon-512x512.png") {
        $successes += "manifest.json includes required icon sizes (192x192, 512x512)"
    } else {
        $issues += "manifest.json missing required icon sizes"
    }
    
    Write-Host "  ✅ manifest.json exists and validated" -ForegroundColor Green
} else {
    $issues += "manifest.json not found"
    Write-Host "  ❌ manifest.json not found" -ForegroundColor Red
}

# 2. Check index.html
Write-Host "`n📄 Checking index.html..." -ForegroundColor Yellow
$indexPath = Join-Path $webDir "index.html"
if (Test-Path $indexPath) {
    $indexContent = Get-Content $indexPath -Raw
    
    # Check for manifest link
    if ($indexContent -match 'rel="manifest"' -and $indexContent -match "manifest.json") {
        $successes += "index.html links to manifest.json"
    } else {
        $issues += "index.html missing manifest.json link"
    }
    
    # Check for responsive meta tags
    $responsiveTags = @("viewport", "HandheldFriendly", "MobileOptimized", "apple-mobile-web-app-capable", "theme-color")
    foreach ($tag in $responsiveTags) {
        if ($indexContent -match $tag) {
            $successes += "index.html contains $tag meta tag"
        } else {
            $warnings += "index.html missing $tag meta tag"
        }
    }
    
    # Check for service worker registration
    if ($indexContent -match "serviceWorker|flutter_service_worker|flutter.js") {
        $successes += "index.html includes service worker setup"
    } else {
        $warnings += "index.html may be missing service worker registration"
    }
    
    # Check for PWA install prompt handling
    if ($indexContent -match "beforeinstallprompt|pwa-install") {
        $successes += "index.html includes PWA install prompt handling"
    } else {
        $warnings += "index.html missing PWA install prompt handling"
    }
    
    Write-Host "  ✅ index.html exists and validated" -ForegroundColor Green
} else {
    $issues += "index.html not found"
    Write-Host "  ❌ index.html not found" -ForegroundColor Red
}

# 3. Check service worker
Write-Host "`n⚙️  Checking service worker..." -ForegroundColor Yellow
$swPath = Join-Path $webDir "service-worker.js"
if (Test-Path $swPath) {
    $swContent = Get-Content $swPath -Raw
    
    if ($swContent -match "install" -and $swContent -match "activate") {
        $successes += "service-worker.js includes install and activate events"
    }
    
    if ($swContent -match "fetch") {
        $successes += "service-worker.js includes fetch event handler"
    }
    
    if ($swContent -match "cache|Cache") {
        $successes += "service-worker.js includes caching strategy"
    }
    
    Write-Host "  ✅ service-worker.js exists" -ForegroundColor Green
    Write-Host "  ℹ️  Note: Flutter automatically generates flutter_service_worker.js during build" -ForegroundColor Cyan
} else {
    $warnings += "service-worker.js not found (Flutter will generate its own)"
    Write-Host "  ⚠️  service-worker.js not found (optional - Flutter generates its own)" -ForegroundColor Yellow
}

# 4. Check browserconfig.xml
Write-Host "`n🌐 Checking browserconfig.xml..." -ForegroundColor Yellow
$browserConfigPath = Join-Path $webDir "browserconfig.xml"
if (Test-Path $browserConfigPath) {
    $successes += "browserconfig.xml exists for Windows tiles"
    Write-Host "  ✅ browserconfig.xml exists" -ForegroundColor Green
} else {
    $warnings += "browserconfig.xml not found (optional for Windows)"
    Write-Host "  ⚠️  browserconfig.xml not found (optional)" -ForegroundColor Yellow
}

# 5. Check icons directory
Write-Host "`n🖼️  Checking icons..." -ForegroundColor Yellow
$iconsDir = Join-Path $webDir "icons"
if (Test-Path $iconsDir) {
    $iconFiles = Get-ChildItem -Path $iconsDir -Filter "*.png" -ErrorAction SilentlyContinue
    if ($iconFiles.Count -gt 0) {
        $successes += "Icons directory contains $($iconFiles.Count) icon file(s)"
        Write-Host "  ✅ Found $($iconFiles.Count) icon file(s)" -ForegroundColor Green
    } else {
        $warnings += "Icons directory exists but contains no PNG files"
        Write-Host "  ⚠️  Icons directory exists but no PNG files found" -ForegroundColor Yellow
    }
} else {
    $warnings += "Icons directory not found"
    Write-Host "  ⚠️  Icons directory not found" -ForegroundColor Yellow
}

# 6. Check favicon
Write-Host "`n🔖 Checking favicon..." -ForegroundColor Yellow
$faviconPath = Join-Path $webDir "favicon.png"
if (Test-Path $faviconPath) {
    $successes += "favicon.png exists"
    Write-Host "  ✅ favicon.png exists" -ForegroundColor Green
} else {
    $warnings += "favicon.png not found (recommended but not required)"
    Write-Host "  ⚠️  favicon.png not found (recommended)" -ForegroundColor Yellow
}

# Summary
Write-Host "`n" + ("=" * 60) -ForegroundColor Cyan
Write-Host "📊 Verification Summary" -ForegroundColor Cyan
Write-Host ("=" * 60) -ForegroundColor Cyan

Write-Host "`n✅ Successes ($($successes.Count)):" -ForegroundColor Green
foreach ($success in $successes) {
    Write-Host "   • $success" -ForegroundColor Green
}

if ($warnings.Count -gt 0) {
    Write-Host "`n⚠️  Warnings ($($warnings.Count)):" -ForegroundColor Yellow
    foreach ($warning in $warnings) {
        Write-Host "   • $warning" -ForegroundColor Yellow
    }
}

if ($issues.Count -gt 0) {
    Write-Host "`n❌ Issues ($($issues.Count)):" -ForegroundColor Red
    foreach ($issue in $issues) {
        Write-Host "   • $issue" -ForegroundColor Red
    }
}

Write-Host "`n" + ("=" * 60) -ForegroundColor Cyan

if ($issues.Count -eq 0) {
    Write-Host "✅ Web Platform Settings Configuration: PASSED" -ForegroundColor Green
    Write-Host "`n📝 Next Steps:" -ForegroundColor Cyan
    Write-Host "   1. Run: flutter build web" -ForegroundColor White
    Write-Host "   2. Test PWA installability in Chrome DevTools" -ForegroundColor White
    Write-Host "   3. Verify offline functionality" -ForegroundColor White
    Write-Host "   4. Test responsive design on mobile devices" -ForegroundColor White
    exit 0
} else {
    Write-Host "❌ Web Platform Settings Configuration: FAILED" -ForegroundColor Red
    Write-Host "`n⚠️  Please fix the issues above before deploying." -ForegroundColor Yellow
    exit 1
}
