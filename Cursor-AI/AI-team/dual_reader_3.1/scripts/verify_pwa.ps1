# PWA Verification Script
# Verifies that the PWA is properly configured and installable
#
# Usage:
#   .\verify_pwa.ps1                    # Verify PWA in build/web
#   .\verify_pwa.ps1 -Path "custom/path" # Verify custom path
#   .\verify_pwa.ps1 -Url "https://..."  # Verify deployed URL

param(
    [Parameter(Mandatory=$false)]
    [string]$Path = "build/web",
    
    [Parameter(Mandatory=$false)]
    [string]$Url = "",
    
    [switch]$Detailed,
    [switch]$CheckOffline,
    [switch]$CheckInstall
)

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "PWA Verification" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Navigate to project root
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptPath
Set-Location $projectRoot

$allChecksPassed = $true
$warnings = @()

# If URL is provided, verify deployed PWA
if ($Url) {
    Write-Host "🌐 Verifying deployed PWA at: $Url" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "⚠️  Note: Full PWA verification requires browser testing" -ForegroundColor Yellow
    Write-Host "   Use Chrome DevTools → Application → Manifest for detailed checks" -ForegroundColor Yellow
    Write-Host ""
    
    # Check if URL is accessible
    try {
        $response = Invoke-WebRequest -Uri $Url -Method Head -UseBasicParsing -TimeoutSec 10
        Write-Host "✅ URL is accessible (Status: $($response.StatusCode))" -ForegroundColor Green
        
        # Check HTTPS
        if ($Url.StartsWith("https://")) {
            Write-Host "✅ HTTPS enabled (required for PWA)" -ForegroundColor Green
        } else {
            Write-Host "⚠️  HTTPS not detected (required for PWA installation)" -ForegroundColor Yellow
            $warnings += "HTTPS not enabled"
        }
    } catch {
        Write-Host "❌ URL is not accessible: $_" -ForegroundColor Red
        $allChecksPassed = $false
    }
    
    Write-Host ""
    Write-Host "📋 Manual Verification Steps:" -ForegroundColor Yellow
    Write-Host "   1. Open $Url in Chrome/Edge" -ForegroundColor White
    Write-Host "   2. Open DevTools (F12) → Application → Manifest" -ForegroundColor White
    Write-Host "   3. Check for install prompt in address bar" -ForegroundColor White
    Write-Host "   4. Test offline functionality (DevTools → Network → Offline)" -ForegroundColor White
    Write-Host ""
    
    exit 0
}

# Verify local build
$buildPath = Join-Path $projectRoot $Path

if (-not (Test-Path $buildPath)) {
    Write-Host "❌ Build directory not found: $buildPath" -ForegroundColor Red
    Write-Host "   Run: .\scripts\build_web.ps1 first" -ForegroundColor Yellow
    exit 1
}

Write-Host "📁 Verifying PWA in: $buildPath" -ForegroundColor Cyan
Write-Host ""

# 1. Manifest.json Check
Write-Host "📱 Manifest.json Check" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────────" -ForegroundColor Gray

$manifestPath = Join-Path $buildPath "manifest.json"
if (Test-Path $manifestPath) {
    Write-Host "   ✅ manifest.json found" -ForegroundColor Green
    
    try {
        $manifestContent = Get-Content $manifestPath -Raw
        $manifest = $manifestContent | ConvertFrom-Json
        
        # Required fields
        $requiredFields = @(
            @{ Field = "name"; Required = $true; Description = "App name" },
            @{ Field = "short_name"; Required = $true; Description = "Short app name" },
            @{ Field = "start_url"; Required = $true; Description = "Start URL" },
            @{ Field = "display"; Required = $true; Description = "Display mode" },
            @{ Field = "icons"; Required = $true; Description = "App icons" }
        )
        
        foreach ($field in $requiredFields) {
            if ($manifest.$($field.Field)) {
                $value = $manifest.$($field.Field)
                if ($field.Field -eq "icons") {
                    $iconCount = ($manifest.icons | Measure-Object).Count
                    Write-Host "      ✅ $($field.Field): $iconCount icons" -ForegroundColor Green
                } else {
                    Write-Host "      ✅ $($field.Field): $value" -ForegroundColor Green
                }
            } else {
                Write-Host "      ❌ $($field.Field) - MISSING (Required)" -ForegroundColor Red
                $allChecksPassed = $false
            }
        }
        
        # Optional but recommended fields
        $optionalFields = @(
            @{ Field = "theme_color"; Description = "Theme color" },
            @{ Field = "background_color"; Description = "Background color" },
            @{ Field = "description"; Description = "App description" },
            @{ Field = "categories"; Description = "App categories" }
        )
        
        foreach ($field in $optionalFields) {
            if ($manifest.$($field.Field)) {
                Write-Host "      ✅ $($field.Field): $($manifest.$($field.Field))" -ForegroundColor Green
            } else {
                Write-Host "      ⚠️  $($field.Field) - Missing (Optional)" -ForegroundColor Yellow
            }
        }
        
        # Validate display mode
        $validDisplayModes = @("standalone", "fullscreen", "minimal-ui", "browser")
        if ($manifest.display -in $validDisplayModes) {
            Write-Host "      ✅ display mode is valid: $($manifest.display)" -ForegroundColor Green
        } else {
            Write-Host "      ⚠️  display mode may be invalid: $($manifest.display)" -ForegroundColor Yellow
        }
        
        # Check icons
        if ($manifest.icons -and $manifest.icons.Count -gt 0) {
            $requiredIconSizes = @(192, 512)
            $foundSizes = @()
            
            foreach ($icon in $manifest.icons) {
                if ($icon.sizes) {
                    $sizes = $icon.sizes -split 'x' | ForEach-Object { [int]$_ }
                    foreach ($size in $sizes) {
                        if ($requiredIconSizes -contains $size) {
                            $foundSizes += $size
                        }
                    }
                }
            }
            
            Write-Host ""
            Write-Host "   🖼️  Icon Sizes Check" -ForegroundColor Cyan
            foreach ($requiredSize in $requiredIconSizes) {
                if ($foundSizes -contains $requiredSize) {
                    Write-Host "      ✅ Icon $requiredSize" -ForegroundColor Green
                } else {
                    Write-Host "      ❌ Icon $requiredSize - MISSING (Required for PWA)" -ForegroundColor Red
                    $allChecksPassed = $false
                }
            }
        } else {
            Write-Host "      ❌ No icons defined in manifest" -ForegroundColor Red
            $allChecksPassed = $false
        }
        
    } catch {
        Write-Host "   ❌ manifest.json is invalid JSON: $_" -ForegroundColor Red
        $allChecksPassed = $false
    }
} else {
    Write-Host "   ❌ manifest.json - MISSING" -ForegroundColor Red
    $allChecksPassed = $false
}

Write-Host ""

# 2. Service Worker Check
Write-Host "⚙️  Service Worker Check" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────────" -ForegroundColor Gray

$swPath = Join-Path $buildPath "flutter_service_worker.js"
if (Test-Path $swPath) {
    $swSize = (Get-Item $swPath).Length / 1KB
    $swSizeKB = [math]::Round($swSize, 2)
    Write-Host "   ✅ flutter_service_worker.js found ($swSizeKB KB)" -ForegroundColor Green
    
    # Check if service worker is referenced in index.html
    $indexPath = Join-Path $buildPath "index.html"
    if (Test-Path $indexPath) {
        $indexContent = Get-Content $indexPath -Raw
        if ($indexContent -match "flutter_service_worker|service.*worker") {
            Write-Host "   ✅ Service worker referenced in index.html" -ForegroundColor Green
        } else {
            Write-Host "   ⚠️  Service worker may not be registered in index.html" -ForegroundColor Yellow
            $warnings += "Service worker registration check needed"
        }
    }
} else {
    Write-Host "   ❌ flutter_service_worker.js - MISSING" -ForegroundColor Red
    $allChecksPassed = $false
}

Write-Host ""

# 3. Icon Files Check
Write-Host "🖼️  Icon Files Check" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────────" -ForegroundColor Gray

$iconPath = Join-Path $buildPath "icons"
if (Test-Path $iconPath) {
    Write-Host "   ✅ icons/ directory found" -ForegroundColor Green
    
    $requiredIcons = @(
        @{ Size = 192; Required = $true },
        @{ Size = 512; Required = $true },
        @{ Size = 16; Required = $false },
        @{ Size = 32; Required = $false },
        @{ Size = 72; Required = $false },
        @{ Size = 96; Required = $false },
        @{ Size = 128; Required = $false },
        @{ Size = 144; Required = $false },
        @{ Size = 152; Required = $false }
    )
    
    foreach ($icon in $requiredIcons) {
        $iconFile = Join-Path $iconPath "icon-$($icon.Size)x$($icon.Size).png"
        if (Test-Path $iconFile) {
            $fileSize = (Get-Item $iconFile).Length / 1KB
            $fileSizeKB = [math]::Round($fileSize, 2)
            $status = if ($icon.Required) { "✅" } else { "✅" }
            Write-Host "      $status icon-$($icon.Size)x$($icon.Size).png ($fileSizeKB KB)" -ForegroundColor Green
        } else {
            if ($icon.Required) {
                Write-Host "      ❌ icon-$($icon.Size)x$($icon.Size).png - MISSING (Required)" -ForegroundColor Red
                $allChecksPassed = $false
            } else {
                Write-Host "      ⚠️  icon-$($icon.Size)x$($icon.Size).png - Missing (Optional)" -ForegroundColor Yellow
            }
        }
    }
} else {
    Write-Host "   ❌ icons/ directory - MISSING" -ForegroundColor Red
    $allChecksPassed = $false
}

Write-Host ""

# 4. Index.html PWA Configuration Check
Write-Host "📄 Index.html PWA Configuration" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────────" -ForegroundColor Gray

$indexPath = Join-Path $buildPath "index.html"
if (Test-Path $indexPath) {
    $indexContent = Get-Content $indexPath -Raw
    
    $pwaChecks = @(
        @{ Pattern = "manifest\.json"; Description = "Manifest link" },
        @{ Pattern = "theme-color"; Description = "Theme color meta tag" },
        @{ Pattern = "apple-touch-icon"; Description = "Apple touch icon" },
        @{ Pattern = "viewport"; Description = "Viewport meta tag" }
    )
    
    foreach ($check in $pwaChecks) {
        if ($indexContent -match $check.Pattern) {
            Write-Host "   ✅ $($check.Description)" -ForegroundColor Green
        } else {
            Write-Host "   ⚠️  $($check.Description) - Missing" -ForegroundColor Yellow
            $warnings += "$($check.Description) missing"
        }
    }
} else {
    Write-Host "   ❌ index.html - MISSING" -ForegroundColor Red
    $allChecksPassed = $false
}

Write-Host ""

# 5. HTTPS Check (for deployment)
Write-Host "🔒 Security Check" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────────" -ForegroundColor Gray

Write-Host "   ℹ️  HTTPS is required for PWA installation" -ForegroundColor Cyan
Write-Host "   ℹ️  Service workers require secure context" -ForegroundColor Cyan
Write-Host "   ℹ️  Test on HTTPS or localhost" -ForegroundColor Cyan

Write-Host ""

# Summary
Write-Host "=========================================" -ForegroundColor Cyan
if ($allChecksPassed) {
    Write-Host "✅ PWA Verification PASSED" -ForegroundColor Green
    Write-Host "   PWA is properly configured!" -ForegroundColor Green
    
    if ($warnings.Count -gt 0) {
        Write-Host ""
        Write-Host "⚠️  Warnings:" -ForegroundColor Yellow
        foreach ($warning in $warnings) {
            Write-Host "   - $warning" -ForegroundColor Yellow
        }
    }
    
    Write-Host ""
    Write-Host "📋 Next Steps:" -ForegroundColor Yellow
    Write-Host "   1. Test locally: cd build\web && python -m http.server 8000" -ForegroundColor White
    Write-Host "   2. Open http://localhost:8000 in Chrome/Edge" -ForegroundColor White
    Write-Host "   3. Check DevTools → Application → Manifest" -ForegroundColor White
    Write-Host "   4. Test install prompt" -ForegroundColor White
    Write-Host "   5. Test offline functionality" -ForegroundColor White
    Write-Host "   6. Deploy to hosting platform" -ForegroundColor White
    
    exit 0
} else {
    Write-Host "❌ PWA Verification FAILED" -ForegroundColor Red
    Write-Host "   Please fix the issues above before deploying" -ForegroundColor Red
    
    if ($warnings.Count -gt 0) {
        Write-Host ""
        Write-Host "⚠️  Warnings:" -ForegroundColor Yellow
        foreach ($warning in $warnings) {
            Write-Host "   - $warning" -ForegroundColor Yellow
        }
    }
    
    exit 1
}
