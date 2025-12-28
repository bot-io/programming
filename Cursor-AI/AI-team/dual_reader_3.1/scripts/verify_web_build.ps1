# Web Build Verification Script for Windows (PowerShell)
# Verifies that the web build is production-ready with all PWA requirements
#
# Usage:
#   .\verify_web_build.ps1                    # Verify build/web directory
#   .\verify_web_build.ps1 -Path "build/web"  # Verify custom path
#   .\verify_web_build.ps1 -Strict            # Fail on warnings

param(
    [Parameter(Mandatory=$false)]
    [string]$Path = "build/web",
    
    [switch]$Strict,
    [switch]$Verbose
)

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Web Build Verification" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

$errors = @()
$warnings = @()
$successes = @()

# Check if build directory exists
if (-not (Test-Path $Path)) {
    Write-Host "❌ Build directory not found: $Path" -ForegroundColor Red
    Write-Host "   Run 'flutter build web --release' first" -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ Build directory found: $Path" -ForegroundColor Green
Write-Host ""

# Required files
$requiredFiles = @(
    @{ File = "index.html"; Required = $true; Description = "Main HTML file" },
    @{ File = "manifest.json"; Required = $true; Description = "PWA manifest" },
    @{ File = "flutter_service_worker.js"; Required = $true; Description = "Service worker (auto-generated)" },
    @{ File = "main.dart.js"; Required = $true; Description = "Main Dart JavaScript bundle" },
    @{ File = "flutter.js"; Required = $true; Description = "Flutter web runtime" }
)

Write-Host "📋 Checking Required Files:" -ForegroundColor Cyan
foreach ($file in $requiredFiles) {
    $filePath = Join-Path $Path $file.File
    if (Test-Path $filePath) {
        $size = (Get-Item $filePath).Length
        $sizeKB = [math]::Round($size / 1KB, 2)
        Write-Host "   ✅ $($file.File) ($sizeKB KB)" -ForegroundColor Green
        $successes += "$($file.File) exists"
    } else {
        if ($file.Required) {
            Write-Host "   ❌ $($file.File) - MISSING (Required)" -ForegroundColor Red
            $errors += "$($file.File) is missing (required)"
        } else {
            Write-Host "   ⚠️  $($file.File) - MISSING (Optional)" -ForegroundColor Yellow
            $warnings += "$($file.File) is missing (optional)"
        }
    }
}
Write-Host ""

# Verify manifest.json
Write-Host "📋 Verifying PWA Manifest:" -ForegroundColor Cyan
$manifestPath = Join-Path $Path "manifest.json"
if (Test-Path $manifestPath) {
    try {
        $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
        
        $requiredFields = @(
            @{ Field = "name"; Required = $true },
            @{ Field = "short_name"; Required = $true },
            @{ Field = "start_url"; Required = $true },
            @{ Field = "display"; Required = $true },
            @{ Field = "icons"; Required = $true }
        )
        
        foreach ($field in $requiredFields) {
            if ($manifest.$($field.Field)) {
                Write-Host "   ✅ $($field.Field)" -ForegroundColor Green
                $successes += "manifest.$($field.Field) present"
            } else {
                if ($field.Required) {
                    Write-Host "   ❌ $($field.Field) - MISSING (Required)" -ForegroundColor Red
                    $errors += "manifest.$($field.Field) is missing (required)"
                } else {
                    Write-Host "   ⚠️  $($field.Field) - MISSING (Optional)" -ForegroundColor Yellow
                    $warnings += "manifest.$($field.Field) is missing (optional)"
                }
            }
        }
        
        # Check icons
        if ($manifest.icons) {
            $iconCount = $manifest.icons.Count
            Write-Host "   ✅ icons: $iconCount icons defined" -ForegroundColor Green
            
            # Check if icon files exist
            $iconsDir = Join-Path $Path "icons"
            if (Test-Path $iconsDir) {
                $iconFiles = Get-ChildItem -Path $iconsDir -Filter "*.png"
                Write-Host "   ✅ icons directory: $($iconFiles.Count) icon files found" -ForegroundColor Green
            } else {
                Write-Host "   ⚠️  icons directory not found" -ForegroundColor Yellow
                $warnings += "icons directory not found"
            }
        }
        
        Write-Host "   ✅ manifest.json is valid JSON" -ForegroundColor Green
        $successes += "manifest.json is valid"
    } catch {
        Write-Host "   ❌ manifest.json is invalid JSON: $_" -ForegroundColor Red
        $errors += "manifest.json is invalid JSON"
    }
} else {
    Write-Host "   ❌ manifest.json not found" -ForegroundColor Red
    $errors += "manifest.json not found"
}
Write-Host ""

# Check service worker
Write-Host "📋 Verifying Service Worker:" -ForegroundColor Cyan
$swPath = Join-Path $Path "flutter_service_worker.js"
if (Test-Path $swPath) {
    $swSize = (Get-Item $swPath).Length
    $swSizeKB = [math]::Round($swSize / 1KB, 2)
    Write-Host "   ✅ flutter_service_worker.js exists ($swSizeKB KB)" -ForegroundColor Green
    $successes += "service worker exists"
    
    # Check if service worker is referenced in index.html
    $indexPath = Join-Path $Path "index.html"
    if (Test-Path $indexPath) {
        $indexContent = Get-Content $indexPath -Raw
        if ($indexContent -match "flutter_service_worker|serviceWorker") {
            Write-Host "   ✅ Service worker referenced in index.html" -ForegroundColor Green
            $successes += "service worker referenced in index.html"
        } else {
            Write-Host "   ⚠️  Service worker not referenced in index.html" -ForegroundColor Yellow
            $warnings += "service worker not referenced in index.html"
        }
    }
} else {
    Write-Host "   ❌ flutter_service_worker.js not found" -ForegroundColor Red
    $errors += "flutter_service_worker.js not found"
}
Write-Host ""

# Check build size
Write-Host "📊 Build Size Analysis:" -ForegroundColor Cyan
$buildSize = (Get-ChildItem -Path $Path -Recurse -File | Measure-Object -Property Length -Sum).Sum
$buildSizeMB = [math]::Round($buildSize / 1MB, 2)
Write-Host "   Total size: $buildSizeMB MB" -ForegroundColor Cyan

# Check main.dart.js size
$mainJsPath = Join-Path $Path "main.dart.js"
if (Test-Path $mainJsPath) {
    $mainJsSize = (Get-Item $mainJsPath).Length / 1MB
    $mainJsSizeMB = [math]::Round($mainJsSize, 2)
    Write-Host "   main.dart.js: $mainJsSizeMB MB" -ForegroundColor Cyan
    
    if ($mainJsSizeMB -gt 5) {
        Write-Host "   ⚠️  main.dart.js is large (>5MB). Consider code splitting." -ForegroundColor Yellow
        $warnings += "main.dart.js is large ($mainJsSizeMB MB)"
    } else {
        Write-Host "   ✅ main.dart.js size is reasonable" -ForegroundColor Green
        $successes += "main.dart.js size is reasonable"
    }
}
Write-Host ""

# Check for source maps (should be removed in production)
Write-Host "🔍 Optimization Checks:" -ForegroundColor Cyan
$sourceMaps = Get-ChildItem -Path $Path -Recurse -Filter "*.js.map" -ErrorAction SilentlyContinue
if ($sourceMaps.Count -gt 0) {
    Write-Host "   ⚠️  Source maps found ($($sourceMaps.Count) files). Consider removing for production." -ForegroundColor Yellow
    $warnings += "Source maps found in production build"
} else {
    Write-Host "   ✅ No source maps found (good for production)" -ForegroundColor Green
    $successes += "No source maps in production build"
}

# Check for large assets
$largeAssets = Get-ChildItem -Path $Path -Recurse -File | Where-Object { $_.Length -gt 1MB }
if ($largeAssets.Count -gt 0) {
    Write-Host "   ⚠️  Large assets found:" -ForegroundColor Yellow
    foreach ($asset in $largeAssets) {
        $sizeMB = [math]::Round($asset.Length / 1MB, 2)
        $relativePath = $asset.FullName.Replace((Resolve-Path $Path).Path + "\", "")
        Write-Host "      - $relativePath ($sizeMB MB)" -ForegroundColor Yellow
    }
    $warnings += "Large assets found ($($largeAssets.Count) files)"
} else {
    Write-Host "   ✅ No unusually large assets detected" -ForegroundColor Green
    $successes += "No large assets detected"
}
Write-Host ""

# Summary
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Verification Summary" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "✅ Successes: $($successes.Count)" -ForegroundColor Green
Write-Host "⚠️  Warnings: $($warnings.Count)" -ForegroundColor Yellow
Write-Host "❌ Errors: $($errors.Count)" -ForegroundColor Red
Write-Host ""

if ($errors.Count -gt 0) {
    Write-Host "Errors found:" -ForegroundColor Red
    foreach ($error in $errors) {
        Write-Host "   ❌ $error" -ForegroundColor Red
    }
    Write-Host ""
}

if ($warnings.Count -gt 0) {
    Write-Host "Warnings:" -ForegroundColor Yellow
    foreach ($warning in $warnings) {
        Write-Host "   ⚠️  $warning" -ForegroundColor Yellow
    }
    Write-Host ""
}

# Exit code
if ($errors.Count -gt 0) {
    Write-Host "❌ Verification FAILED - Fix errors before deploying" -ForegroundColor Red
    exit 1
} elseif ($Strict -and $warnings.Count -gt 0) {
    Write-Host "⚠️  Verification PASSED with warnings (Strict mode)" -ForegroundColor Yellow
    exit 1
} elseif ($warnings.Count -gt 0) {
    Write-Host "✅ Verification PASSED with warnings" -ForegroundColor Yellow
    Write-Host "   Consider fixing warnings before production deployment" -ForegroundColor Yellow
    exit 0
} else {
    Write-Host "✅ Verification PASSED - Build is production-ready!" -ForegroundColor Green
    exit 0
}
