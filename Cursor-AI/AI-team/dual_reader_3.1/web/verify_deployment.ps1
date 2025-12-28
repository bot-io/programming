# Deployment Verification Script for Dual Reader 3.1
# This script verifies that the web build is ready for deployment

param(
    [string]$BuildDir = "build/web",
    [switch]$CheckPWA = $true,
    [switch]$CheckSecurity = $true,
    [switch]$CheckPerformance = $true
)

Write-Host "🔍 Verifying Dual Reader 3.1 Web Build..." -ForegroundColor Cyan
Write-Host ""

$allChecksPassed = $true

# Check if build directory exists
if (-not (Test-Path $BuildDir)) {
    Write-Host "❌ Build directory not found: $BuildDir" -ForegroundColor Red
    Write-Host "   Run 'flutter build web --release' first" -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ Build directory found: $BuildDir" -ForegroundColor Green
Write-Host ""

# Check required files
Write-Host "📋 Checking required files..." -ForegroundColor Cyan
$requiredFiles = @(
    @{ File = "index.html"; Required = $true; Description = "Main HTML file" },
    @{ File = "main.dart.js"; Required = $true; Description = "Compiled Dart code" },
    @{ File = "flutter.js"; Required = $true; Description = "Flutter web engine" },
    @{ File = "manifest.json"; Required = $CheckPWA; Description = "PWA manifest" },
    @{ File = "flutter_service_worker.js"; Required = $CheckPWA; Description = "Service worker" }
)

foreach ($fileInfo in $requiredFiles) {
    $filePath = Join-Path $BuildDir $fileInfo.File
    if (Test-Path $filePath) {
        $fileSize = (Get-Item $filePath).Length
        $fileSizeKB = [math]::Round($fileSize / 1KB, 2)
        Write-Host "   ✅ $($fileInfo.File) ($fileSizeKB KB)" -ForegroundColor Green
    } elseif ($fileInfo.Required) {
        Write-Host "   ❌ $($fileInfo.File) - MISSING ($($fileInfo.Description))" -ForegroundColor Red
        $allChecksPassed = $false
    } else {
        Write-Host "   ⚠️  $($fileInfo.File) - MISSING (optional)" -ForegroundColor Yellow
    }
}

Write-Host ""

# Check PWA configuration
if ($CheckPWA) {
    Write-Host "📱 Checking PWA configuration..." -ForegroundColor Cyan
    
    # Check manifest.json
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
                    if ($check.Count -gt 0) {
                        Write-Host "   ✅ $($check.Field): $($check.Count) icons" -ForegroundColor Green
                    } else {
                        Write-Host "   ❌ $($check.Field): No icons found" -ForegroundColor Red
                        $allChecksPassed = $false
                    }
                } elseif ($check.Value) {
                    Write-Host "   ✅ $($check.Field): $($check.Value)" -ForegroundColor Green
                } else {
                    Write-Host "   ❌ $($check.Field): Missing" -ForegroundColor Red
                    $allChecksPassed = $false
                }
            }
            
            # Check for required icon sizes
            $requiredIconSizes = @(192, 512)
            $iconSizes = $manifest.icons | ForEach-Object { 
                if ($_.sizes) {
                    [int]($_.sizes -split 'x')[0]
                }
            }
            
            foreach ($size in $requiredIconSizes) {
                if ($iconSizes -contains $size) {
                    Write-Host "   ✅ Icon size $size`x$size found" -ForegroundColor Green
                } else {
                    Write-Host "   ⚠️  Icon size $size`x$size not found (recommended)" -ForegroundColor Yellow
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
    
    # Check service worker
    $swPath = Join-Path $BuildDir "flutter_service_worker.js"
    if (Test-Path $swPath) {
        Write-Host "   ✅ Service worker found" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️  Service worker not found (may be generated at runtime)" -ForegroundColor Yellow
    }
    
    # Check icons directory
    $iconsDir = Join-Path $BuildDir "icons"
    if (Test-Path $iconsDir) {
        $iconCount = (Get-ChildItem -Path $iconsDir -Filter "*.png").Count
        Write-Host "   ✅ Icons directory found ($iconCount icons)" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️  Icons directory not found" -ForegroundColor Yellow
    }
    
    Write-Host ""
}

# Check security headers in index.html
if ($CheckSecurity) {
    Write-Host "🔒 Checking security configuration..." -ForegroundColor Cyan
    
    $indexPath = Join-Path $BuildDir "index.html"
    if (Test-Path $indexPath) {
        $indexContent = Get-Content $indexPath -Raw
        
        $securityChecks = @(
            @{ Check = "X-Content-Type-Options"; Pattern = "nosniff"; Required = $false },
            @{ Check = "X-Frame-Options"; Pattern = "SAMEORIGIN"; Required = $false },
            @{ Check = "HTTPS"; Pattern = "https"; Required = $false }
        )
        
        foreach ($check in $securityChecks) {
            if ($indexContent -match $check.Pattern) {
                Write-Host "   ✅ $($check.Check) configured" -ForegroundColor Green
            } else {
                Write-Host "   ⚠️  $($check.Check) not found (may be configured on server)" -ForegroundColor Yellow
            }
        }
    }
    
    Write-Host ""
}

# Check build size
if ($CheckPerformance) {
    Write-Host "📊 Checking build size..." -ForegroundColor Cyan
    
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
            Write-Host "   ⚠️  Large bundle size detected. Consider code splitting." -ForegroundColor Yellow
        } elseif ($mainJsSizeMB -lt 2) {
            Write-Host "   ✅ Bundle size is reasonable" -ForegroundColor Green
        }
    }
    
    # Check for source maps (should be removed in production)
    $sourceMaps = Get-ChildItem -Path $BuildDir -Filter "*.js.map" -Recurse
    if ($sourceMaps.Count -gt 0) {
        Write-Host "   ⚠️  Source maps found ($($sourceMaps.Count) files). Consider removing for production." -ForegroundColor Yellow
    } else {
        Write-Host "   ✅ No source maps found (good for production)" -ForegroundColor Green
    }
    
    Write-Host ""
}

# Summary
Write-Host "📝 Verification Summary:" -ForegroundColor Cyan
if ($allChecksPassed) {
    Write-Host "   ✅ All critical checks passed!" -ForegroundColor Green
    Write-Host ""
    Write-Host "✨ Build is ready for deployment!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "   ❌ Some checks failed. Please fix issues before deploying." -ForegroundColor Red
    Write-Host ""
    Write-Host "⚠️  Build may not be ready for deployment." -ForegroundColor Yellow
    exit 1
}
