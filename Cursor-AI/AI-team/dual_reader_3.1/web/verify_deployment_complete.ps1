# Deployment Verification Script for Dual Reader 3.1 Web App
# This script verifies that the web build is ready for deployment

param(
    [string]$BuildDir = "build/web",
    [switch]$CheckPWA = $true,
    [switch]$CheckFiles = $true,
    [switch]$CheckManifest = $true,
    [switch]$CheckServiceWorker = $true,
    [switch]$CheckIcons = $true,
    [switch]$CheckSize = $true
)

$ErrorActionPreference = "Stop"
$allChecksPassed = $true

Write-Host "🔍 Verifying Web Build for Deployment..." -ForegroundColor Cyan
Write-Host ""

# Check if build directory exists
if (-not (Test-Path $BuildDir)) {
    Write-Host "❌ Build directory not found: $BuildDir" -ForegroundColor Red
    Write-Host "   Run 'flutter build web --release' first" -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ Build directory found: $BuildDir" -ForegroundColor Green
Write-Host ""

# Check required files
if ($CheckFiles) {
    Write-Host "📄 Checking Required Files..." -ForegroundColor Cyan
    
    $requiredFiles = @(
        @{ Path = "index.html"; Name = "index.html"; Required = $true },
        @{ Path = "main.dart.js"; Name = "main.dart.js"; Required = $true },
        @{ Path = "flutter.js"; Name = "flutter.js"; Required = $true },
        @{ Path = "manifest.json"; Name = "manifest.json"; Required = $CheckPWA },
        @{ Path = "flutter_service_worker.js"; Name = "flutter_service_worker.js"; Required = $CheckPWA }
    )
    
    foreach ($file in $requiredFiles) {
        $filePath = Join-Path $BuildDir $file.Path
        if ($file.Required) {
            if (Test-Path $filePath) {
                $fileSize = (Get-Item $filePath).Length
                $fileSizeKB = [math]::Round($fileSize / 1KB, 2)
                Write-Host "   ✅ $($file.Name) ($fileSizeKB KB)" -ForegroundColor Green
            } else {
                Write-Host "   ❌ $($file.Name) - NOT FOUND" -ForegroundColor Red
                $allChecksPassed = $false
            }
        } else {
            if (Test-Path $filePath) {
                Write-Host "   ✅ $($file.Name) (optional)" -ForegroundColor Gray
            }
        }
    }
    
    Write-Host ""
}

# Check PWA manifest
if ($CheckManifest -and $CheckPWA) {
    Write-Host "📱 Checking PWA Manifest..." -ForegroundColor Cyan
    
    $manifestPath = Join-Path $BuildDir "manifest.json"
    if (Test-Path $manifestPath) {
        try {
            $manifest = Get-Content $manifestPath | ConvertFrom-Json
            
            $manifestChecks = @(
                @{ Field = "name"; Value = $manifest.name; Required = $true },
                @{ Field = "short_name"; Value = $manifest.short_name; Required = $true },
                @{ Field = "start_url"; Value = $manifest.start_url; Required = $true },
                @{ Field = "display"; Value = $manifest.display; Required = $true },
                @{ Field = "icons"; Count = ($manifest.icons | Measure-Object).Count; Required = $true }
            )
            
            foreach ($check in $manifestChecks) {
                if ($check.Count) {
                    if ($check.Count -ge 2) {
                        Write-Host "   ✅ $($check.Field): $($check.Count) icons" -ForegroundColor Green
                    } else {
                        Write-Host "   ⚠️  $($check.Field): Only $($check.Count) icon(s) (minimum 2 recommended)" -ForegroundColor Yellow
                    }
                } else {
                    if ($check.Required -and [string]::IsNullOrWhiteSpace($check.Value)) {
                        Write-Host "   ❌ $($check.Field): Missing" -ForegroundColor Red
                        $allChecksPassed = $false
                    } elseif (-not [string]::IsNullOrWhiteSpace($check.Value)) {
                        Write-Host "   ✅ $($check.Field): $($check.Value)" -ForegroundColor Green
                    }
                }
            }
            
            # Check for required icon sizes
            $requiredIconSizes = @(192, 512)
            $iconSizes = $manifest.icons | ForEach-Object { 
                $sizeStr = $_.sizes
                if ($sizeStr -match '(\d+)x\d+') {
                    [int]$matches[1]
                }
            }
            
            foreach ($size in $requiredIconSizes) {
                if ($iconSizes -contains $size) {
                    Write-Host "   ✅ Icon size $size" + "x$size" + " found" -ForegroundColor Green
                } else {
                    Write-Host "   ⚠️  Icon size $size" + "x$size" + " missing (recommended)" -ForegroundColor Yellow
                }
            }
            
        } catch {
            Write-Host "   ❌ Failed to parse manifest.json: $_" -ForegroundColor Red
            $allChecksPassed = $false
        }
    } else {
        Write-Host "   ❌ manifest.json not found" -ForegroundColor Red
        $allChecksPassed = $false
    }
    
    Write-Host ""
}

# Check service worker
if ($CheckServiceWorker -and $CheckPWA) {
    Write-Host "⚙️  Checking Service Worker..." -ForegroundColor Cyan
    
    $swPath = Join-Path $BuildDir "flutter_service_worker.js"
    if (Test-Path $swPath) {
        $swContent = Get-Content $swPath -Raw
        
        # Check for service worker registration in index.html
        $indexPath = Join-Path $BuildDir "index.html"
        if (Test-Path $indexPath) {
            $indexContent = Get-Content $indexPath -Raw
            
            if ($indexContent -match 'flutter_service_worker\.js' -or $indexContent -match 'serviceWorker\.register') {
                Write-Host "   ✅ Service worker registration found in index.html" -ForegroundColor Green
            } else {
                Write-Host "   ⚠️  Service worker registration not found in index.html" -ForegroundColor Yellow
            }
        }
        
        $swSize = (Get-Item $swPath).Length
        $swSizeKB = [math]::Round($swSize / 1KB, 2)
        Write-Host "   ✅ flutter_service_worker.js found ($swSizeKB KB)" -ForegroundColor Green
        
        # Check for service worker version
        if ($swContent -match 'CACHE_VERSION|version') {
            Write-Host "   ✅ Service worker versioning detected" -ForegroundColor Green
        }
    } else {
        Write-Host "   ⚠️  flutter_service_worker.js not found (may be generated during build)" -ForegroundColor Yellow
    }
    
    Write-Host ""
}

# Check icons
if ($CheckIcons -and $CheckPWA) {
    Write-Host "🖼️  Checking PWA Icons..." -ForegroundColor Cyan
    
    $iconsDir = Join-Path $BuildDir "icons"
    if (Test-Path $iconsDir) {
        $iconFiles = Get-ChildItem -Path $iconsDir -Filter "icon-*.png"
        
        if ($iconFiles.Count -gt 0) {
            Write-Host "   ✅ Found $($iconFiles.Count) icon file(s)" -ForegroundColor Green
            
            $requiredSizes = @(192, 512)
            foreach ($size in $requiredSizes) {
                $iconFile = $iconFiles | Where-Object { $_.Name -match "icon-$size" + "x$size" }
                if ($iconFile) {
                    Write-Host "   ✅ Icon $size" + "x$size" + " found" -ForegroundColor Green
                } else {
                    Write-Host "   ⚠️  Icon $size" + "x$size" + " missing (recommended)" -ForegroundColor Yellow
                }
            }
        } else {
            Write-Host "   ⚠️  No icons found in icons/ directory" -ForegroundColor Yellow
        }
    } else {
        Write-Host "   ⚠️  Icons directory not found" -ForegroundColor Yellow
    }
    
    Write-Host ""
}

# Check build size
if ($CheckSize) {
    Write-Host "📊 Build Size Analysis..." -ForegroundColor Cyan
    
    $buildSize = (Get-ChildItem -Path $BuildDir -Recurse -File | Measure-Object -Property Length -Sum).Sum
    $buildSizeMB = [math]::Round($buildSize / 1MB, 2)
    Write-Host "   Total size: $buildSizeMB MB" -ForegroundColor Gray
    
    # Check main.dart.js size
    $mainJsPath = Join-Path $BuildDir "main.dart.js"
    if (Test-Path $mainJsPath) {
        $mainJsSize = (Get-Item $mainJsPath).Length / 1MB
        $mainJsSizeMB = [math]::Round($mainJsSize, 2)
        Write-Host "   main.dart.js: $mainJsSizeMB MB" -ForegroundColor Gray
        
        if ($mainJsSizeMB -gt 5) {
            Write-Host "   ⚠️  Large bundle size detected (>5MB). Consider optimization." -ForegroundColor Yellow
        } elseif ($mainJsSizeMB -gt 3) {
            Write-Host "   ⚠️  Bundle size is moderate (3-5MB). Monitor performance." -ForegroundColor Yellow
        } else {
            Write-Host "   ✅ Bundle size is reasonable (<3MB)" -ForegroundColor Green
        }
    }
    
    # Check for large assets
    $largeAssets = Get-ChildItem -Path $BuildDir -Recurse -File | Where-Object { $_.Length -gt 1MB }
    if ($largeAssets.Count -gt 0) {
        Write-Host "   ⚠️  Large assets found:" -ForegroundColor Yellow
        foreach ($asset in $largeAssets | Select-Object -First 5) {
            $sizeMB = [math]::Round($asset.Length / 1MB, 2)
            $relativePath = $asset.FullName.Replace((Resolve-Path $BuildDir).Path + "\", "")
            Write-Host "      - $relativePath : $sizeMB MB" -ForegroundColor Gray
        }
    } else {
        Write-Host "   ✅ No unusually large assets detected" -ForegroundColor Green
    }
    
    Write-Host ""
}

# Check for common issues
Write-Host "🔍 Checking for Common Issues..." -ForegroundColor Cyan

# Check for source maps in release build
$sourceMaps = Get-ChildItem -Path $BuildDir -Filter "*.js.map" -Recurse
if ($sourceMaps.Count -gt 0) {
    Write-Host "   ⚠️  Source maps found. Consider removing for production." -ForegroundColor Yellow
} else {
    Write-Host "   ✅ No source maps found (good for production)" -ForegroundColor Green
}

# Check for .nojekyll (GitHub Pages)
$nojekyllPath = Join-Path $BuildDir ".nojekyll"
if (Test-Path $nojekyllPath) {
    Write-Host "   ✅ .nojekyll file found (GitHub Pages ready)" -ForegroundColor Green
} else {
    Write-Host "   ⚠️  .nojekyll file not found (needed for GitHub Pages)" -ForegroundColor Yellow
}

# Check for 404.html (GitHub Pages)
$404Path = Join-Path $BuildDir "404.html"
if (Test-Path $404Path) {
    Write-Host "   ✅ 404.html found (GitHub Pages SPA routing)" -ForegroundColor Green
} else {
    Write-Host "   ⚠️  404.html not found (needed for GitHub Pages SPA routing)" -ForegroundColor Yellow
}

Write-Host ""

# Summary
Write-Host "📋 Verification Summary" -ForegroundColor Cyan
Write-Host ""

if ($allChecksPassed) {
    Write-Host "✅ All critical checks passed!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📝 Next Steps:" -ForegroundColor Cyan
    Write-Host "   1. Test locally: cd $BuildDir && python -m http.server 8000" -ForegroundColor Gray
    Write-Host "   2. Verify PWA in Chrome DevTools (Application tab)" -ForegroundColor Gray
    Write-Host "   3. Deploy to your hosting platform" -ForegroundColor Gray
    Write-Host ""
    Write-Host "✨ Build is ready for deployment!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "❌ Some checks failed. Please fix the issues above before deploying." -ForegroundColor Red
    exit 1
}
