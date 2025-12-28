# PWA Verification Script for Dual Reader 3.1
# This script verifies that the PWA is properly configured and installable

param(
    [string]$BuildDir = "build/web",
    [switch]$Detailed = $false
)

Write-Host "🔍 Verifying PWA Configuration..." -ForegroundColor Cyan
Write-Host ""

$allChecksPassed = $true

# Check if build directory exists
if (-not (Test-Path $BuildDir)) {
    Write-Host "❌ Build directory not found: $BuildDir" -ForegroundColor Red
    Write-Host "   Run build first: .\web\build_web.ps1" -ForegroundColor Yellow
    exit 1
}

Write-Host "📁 Build Directory: $BuildDir" -ForegroundColor Gray
Write-Host ""

# 1. Check manifest.json
Write-Host "1️⃣  Checking manifest.json..." -ForegroundColor Yellow
$manifestPath = Join-Path $BuildDir "manifest.json"
if (Test-Path $manifestPath) {
    try {
        $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
        
        $manifestChecks = @(
            @{ Field = "name"; Required = $true; Value = $manifest.name },
            @{ Field = "short_name"; Required = $true; Value = $manifest.short_name },
            @{ Field = "start_url"; Required = $true; Value = $manifest.start_url },
            @{ Field = "display"; Required = $true; Value = $manifest.display },
            @{ Field = "theme_color"; Required = $true; Value = $manifest.theme_color },
            @{ Field = "background_color"; Required = $true; Value = $manifest.background_color }
        )
        
        foreach ($check in $manifestChecks) {
            if ($check.Required -and [string]::IsNullOrWhiteSpace($check.Value)) {
                Write-Host "   ❌ Missing required field: $($check.Field)" -ForegroundColor Red
                $allChecksPassed = $false
            } else {
                if ($Detailed) {
                    Write-Host "   ✅ $($check.Field): $($check.Value)" -ForegroundColor Green
                }
            }
        }
        
        # Check icons
        if ($manifest.icons -and $manifest.icons.Count -gt 0) {
            $requiredSizes = @(192, 512)
            $foundSizes = @()
            
            foreach ($icon in $manifest.icons) {
                if ($icon.sizes) {
                    $sizes = $icon.sizes -split '\s+' | ForEach-Object { [int]($_ -replace 'x\d+', '') }
                    $foundSizes += $sizes
                }
            }
            
            foreach ($size in $requiredSizes) {
                if ($foundSizes -contains $size) {
                    if ($Detailed) {
                        Write-Host "   ✅ Icon size $size`x$size found" -ForegroundColor Green
                    }
                } else {
                    Write-Host "   ⚠️  Icon size $size`x$size not found (recommended)" -ForegroundColor Yellow
                }
            }
            
            Write-Host "   ✅ Icons: $($manifest.icons.Count) icon(s) defined" -ForegroundColor Green
        } else {
            Write-Host "   ❌ No icons defined in manifest" -ForegroundColor Red
            $allChecksPassed = $false
        }
        
        Write-Host "   ✅ manifest.json is valid" -ForegroundColor Green
    } catch {
        Write-Host "   ❌ Failed to parse manifest.json: $_" -ForegroundColor Red
        $allChecksPassed = $false
    }
} else {
    Write-Host "   ❌ manifest.json not found" -ForegroundColor Red
    $allChecksPassed = $false
}

Write-Host ""

# 2. Check service worker
Write-Host "2️⃣  Checking service worker..." -ForegroundColor Yellow
$swPath = Join-Path $BuildDir "flutter_service_worker.js"
if (Test-Path $swPath) {
    $swSize = (Get-Item $swPath).Length
    Write-Host "   ✅ flutter_service_worker.js found ($([math]::Round($swSize / 1KB, 2)) KB)" -ForegroundColor Green
    
    # Check if service worker is referenced in index.html
    $indexPath = Join-Path $BuildDir "index.html"
    if (Test-Path $indexPath) {
        $indexContent = Get-Content $indexPath -Raw
        if ($indexContent -match "flutter_service_worker" -or $indexContent -match "service.*worker") {
            Write-Host "   ✅ Service worker referenced in index.html" -ForegroundColor Green
        } else {
            Write-Host "   ⚠️  Service worker not referenced in index.html" -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "   ❌ flutter_service_worker.js not found" -ForegroundColor Red
    Write-Host "      Flutter should generate this automatically during build" -ForegroundColor Yellow
    $allChecksPassed = $false
}

Write-Host ""

# 3. Check PWA icons
Write-Host "3️⃣  Checking PWA icons..." -ForegroundColor Yellow
$iconsDir = Join-Path $BuildDir "icons"
$requiredIcons = @(
    @{ Size = "192x192"; File = "icon-192x192.png"; Required = $true },
    @{ Size = "512x512"; File = "icon-512x512.png"; Required = $true },
    @{ Size = "16x16"; File = "icon-16x16.png"; Required = $false },
    @{ Size = "32x32"; File = "icon-32x32.png"; Required = $false }
)

$iconsFound = 0
foreach ($icon in $requiredIcons) {
    $iconPath = Join-Path $iconsDir $icon.File
    if (Test-Path $iconPath) {
        $iconsFound++
        if ($Detailed -or $icon.Required) {
            $iconSize = (Get-Item $iconPath).Length
            Write-Host "   ✅ $($icon.File) ($([math]::Round($iconSize / 1KB, 2)) KB)" -ForegroundColor Green
        }
    } else {
        if ($icon.Required) {
            Write-Host "   ❌ Required icon not found: $($icon.File)" -ForegroundColor Red
            $allChecksPassed = $false
        } else {
            if ($Detailed) {
                Write-Host "   ⚠️  Optional icon not found: $($icon.File)" -ForegroundColor Yellow
            }
        }
    }
}

if ($iconsFound -ge 2) {
    Write-Host "   ✅ Found $iconsFound icon(s)" -ForegroundColor Green
} else {
    Write-Host "   ⚠️  Only $iconsFound icon(s) found (at least 2 recommended)" -ForegroundColor Yellow
}

Write-Host ""

# 4. Check index.html
Write-Host "4️⃣  Checking index.html..." -ForegroundColor Yellow
$indexPath = Join-Path $BuildDir "index.html"
if (Test-Path $indexPath) {
    $indexContent = Get-Content $indexPath -Raw
    
    $htmlChecks = @(
        @{ Check = "manifest.json link"; Pattern = 'rel="manifest"'; Required = $true },
        @{ Check = "theme-color meta"; Pattern = 'name="theme-color"'; Required = $true },
        @{ Check = "viewport meta"; Pattern = 'name="viewport"'; Required = $true },
        @{ Check = "apple-touch-icon"; Pattern = 'rel="apple-touch-icon"'; Required = $false }
    )
    
    foreach ($check in $htmlChecks) {
        if ($indexContent -match $check.Pattern) {
            if ($Detailed -or $check.Required) {
                Write-Host "   ✅ $($check.Check) found" -ForegroundColor Green
            }
        } else {
            if ($check.Required) {
                Write-Host "   ❌ $($check.Check) not found" -ForegroundColor Red
                $allChecksPassed = $false
            } else {
                if ($Detailed) {
                    Write-Host "   ⚠️  $($check.Check) not found (optional)" -ForegroundColor Yellow
                }
            }
        }
    }
    
    Write-Host "   ✅ index.html structure looks good" -ForegroundColor Green
} else {
    Write-Host "   ❌ index.html not found" -ForegroundColor Red
    $allChecksPassed = $false
}

Write-Host ""

# 5. Check HTTPS requirement (informational)
Write-Host "5️⃣  PWA Requirements (Informational)..." -ForegroundColor Yellow
Write-Host "   ℹ️  PWA requires HTTPS in production" -ForegroundColor Gray
Write-Host "   ℹ️  Service worker requires secure context" -ForegroundColor Gray
Write-Host "   ℹ️  Localhost is considered secure for testing" -ForegroundColor Gray

Write-Host ""

# Summary
Write-Host "📊 Verification Summary" -ForegroundColor Cyan
Write-Host ""

if ($allChecksPassed) {
    Write-Host "✅ All critical PWA checks passed!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📝 Next Steps:" -ForegroundColor Cyan
    Write-Host "   1. Test locally: cd $BuildDir && python -m http.server 8000" -ForegroundColor Gray
    Write-Host "   2. Open browser: http://localhost:8000" -ForegroundColor Gray
    Write-Host "   3. Open Chrome DevTools → Application → Manifest" -ForegroundColor Gray
    Write-Host "   4. Check 'Add to Home Screen' prompt" -ForegroundColor Gray
    Write-Host "   5. Test offline functionality" -ForegroundColor Gray
    Write-Host "   6. Deploy to production platform" -ForegroundColor Gray
    exit 0
} else {
    Write-Host "❌ Some PWA checks failed!" -ForegroundColor Red
    Write-Host ""
    Write-Host "💡 Fix the issues above and rebuild:" -ForegroundColor Yellow
    Write-Host "   .\web\build_web.ps1" -ForegroundColor Gray
    exit 1
}
