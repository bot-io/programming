# Web Deployment Verification Script for Windows (PowerShell)
# Verifies web build and deployment readiness
#
# Usage:
#   .\verify_web_deployment.ps1                    # Verify build output
#   .\verify_web_deployment.ps1 -Url "https://..."  # Verify deployed app
#   .\verify_web_deployment.ps1 -PWA                 # Full PWA verification

param(
    [Parameter(Mandatory=$false)]
    [string]$Url = "",
    
    [switch]$PWA,
    [switch]$BuildOnly,
    [switch]$Verbose
)

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Web Deployment Verification" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Navigate to project root
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptPath
Set-Location $projectRoot

$allChecksPassed = $true
$issues = @()

# Check 1: Build Output
Write-Host "1. Checking Build Output..." -ForegroundColor Cyan
$buildOutput = Join-Path $projectRoot "build\web"

if (-not (Test-Path $buildOutput)) {
    Write-Host "   ❌ Build output not found: $buildOutput" -ForegroundColor Red
    Write-Host "   Run: flutter build web --release" -ForegroundColor Yellow
    $allChecksPassed = $false
    $issues += "Build output missing"
} else {
    Write-Host "   ✅ Build output exists" -ForegroundColor Green
    
    # Check essential files
    $essentialFiles = @(
        @{ File = "index.html"; Required = $true; Description = "Main HTML file" },
        @{ File = "main.dart.js"; Required = $true; Description = "Main Dart JS bundle" },
        @{ File = "flutter.js"; Required = $true; Description = "Flutter runtime" },
        @{ File = "flutter_service_worker.js"; Required = $true; Description = "Service worker" },
        @{ File = "manifest.json"; Required = $true; Description = "PWA manifest" }
    )
    
    foreach ($file in $essentialFiles) {
        $filePath = Join-Path $buildOutput $file.File
        if (Test-Path $filePath) {
            $fileSize = (Get-Item $filePath).Length
            $fileSizeKB = [math]::Round($fileSize / 1KB, 2)
            Write-Host "      ✅ $($file.File) ($fileSizeKB KB)" -ForegroundColor Green
        } else {
            if ($file.Required) {
                Write-Host "      ❌ $($file.File) - MISSING" -ForegroundColor Red
                $allChecksPassed = $false
                $issues += "Missing required file: $($file.File)"
            } else {
                Write-Host "      ⚠️  $($file.File) - MISSING (optional)" -ForegroundColor Yellow
            }
        }
    }
}

# Check 2: PWA Manifest
Write-Host "`n2. Verifying PWA Manifest..." -ForegroundColor Cyan
$manifestPath = Join-Path $buildOutput "manifest.json"

if (Test-Path $manifestPath) {
    try {
        $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
        
        $manifestChecks = @(
            @{ Field = "name"; Required = $true },
            @{ Field = "short_name"; Required = $true },
            @{ Field = "start_url"; Required = $true },
            @{ Field = "display"; Required = $true },
            @{ Field = "icons"; Required = $true }
        )
        
        foreach ($check in $manifestChecks) {
            if ($check.Field -eq "icons") {
                if ($manifest.icons -and $manifest.icons.Count -gt 0) {
                    Write-Host "      ✅ icons: $($manifest.icons.Count) icons defined" -ForegroundColor Green
                    
                    # Check for required icon sizes
                    $iconSizes = @()
                    foreach ($icon in $manifest.icons) {
                        if ($icon.sizes) {
                            $sizes = $icon.sizes -split 'x' | ForEach-Object { [int]$_ }
                            $iconSizes += $sizes
                        }
                    }
                    
                    if ($iconSizes -contains 192 -and $iconSizes -contains 512) {
                        Write-Host "      ✅ Required icon sizes present (192x192, 512x512)" -ForegroundColor Green
                    } else {
                        Write-Host "      ⚠️  Missing required icon sizes" -ForegroundColor Yellow
                        if ($iconSizes -notcontains 192) { $issues += "Missing 192x192 icon" }
                        if ($iconSizes -notcontains 512) { $issues += "Missing 512x512 icon" }
                    }
                } else {
                    Write-Host "      ❌ No icons defined" -ForegroundColor Red
                    $allChecksPassed = $false
                    $issues += "Manifest missing icons"
                }
            } else {
                if ($manifest.$($check.Field)) {
                    Write-Host "      ✅ $($check.Field): $($manifest.$($check.Field))" -ForegroundColor Green
                } else {
                    Write-Host "      ❌ $($check.Field): MISSING" -ForegroundColor Red
                    $allChecksPassed = $false
                    $issues += "Manifest missing field: $($check.Field)"
                }
            }
        }
        
        # Check display mode
        $validDisplayModes = @("standalone", "fullscreen", "minimal-ui", "browser")
        if ($manifest.display -in $validDisplayModes) {
            Write-Host "      ✅ Display mode: $($manifest.display)" -ForegroundColor Green
        } else {
            Write-Host "      ⚠️  Display mode may be invalid: $($manifest.display)" -ForegroundColor Yellow
        }
        
    } catch {
        Write-Host "      ❌ Invalid JSON: $_" -ForegroundColor Red
        $allChecksPassed = $false
        $issues += "Manifest JSON invalid"
    }
} else {
    Write-Host "   ❌ manifest.json not found" -ForegroundColor Red
    $allChecksPassed = $false
    $issues += "Manifest file missing"
}

# Check 3: Service Worker
Write-Host "`n3. Verifying Service Worker..." -ForegroundColor Cyan
$swPath = Join-Path $buildOutput "flutter_service_worker.js"

if (Test-Path $swPath) {
    Write-Host "   ✅ Service worker file exists" -ForegroundColor Green
    
    # Check if service worker is referenced in index.html
    $indexPath = Join-Path $buildOutput "index.html"
    if (Test-Path $indexPath) {
        $indexContent = Get-Content $indexPath -Raw
        if ($indexContent -match "flutter_service_worker|service.*worker") {
            Write-Host "   ✅ Service worker referenced in index.html" -ForegroundColor Green
        } else {
            Write-Host "   ⚠️  Service worker may not be registered" -ForegroundColor Yellow
            $issues += "Service worker not referenced in index.html"
        }
    }
} else {
    Write-Host "   ❌ Service worker not found" -ForegroundColor Red
    $allChecksPassed = $false
    $issues += "Service worker missing"
}

# Check 4: Icons
Write-Host "`n4. Verifying Icons..." -ForegroundColor Cyan
$iconsDir = Join-Path $buildOutput "icons"

if (Test-Path $iconsDir) {
    $requiredIcons = @("icon-192x192.png", "icon-512x512.png")
    $foundIcons = 0
    
    foreach ($icon in $requiredIcons) {
        $iconPath = Join-Path $iconsDir $icon
        if (Test-Path $iconPath) {
            Write-Host "      ✅ $icon" -ForegroundColor Green
            $foundIcons++
        } else {
            Write-Host "      ❌ $icon - MISSING" -ForegroundColor Red
            $issues += "Missing icon: $icon"
        }
    }
    
    if ($foundIcons -eq $requiredIcons.Count) {
        Write-Host "   ✅ Required icons present" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️  Some icons missing" -ForegroundColor Yellow
        $allChecksPassed = $false
    }
} else {
    Write-Host "   ❌ Icons directory not found" -ForegroundColor Red
    $allChecksPassed = $false
    $issues += "Icons directory missing"
}

# Check 5: Build Size
Write-Host "`n5. Analyzing Build Size..." -ForegroundColor Cyan
if (Test-Path $buildOutput) {
    $buildSize = (Get-ChildItem -Path $buildOutput -Recurse -File | Measure-Object -Property Length -Sum).Sum
    $buildSizeMB = [math]::Round($buildSize / 1MB, 2)
    Write-Host "   Total build size: $buildSizeMB MB" -ForegroundColor Cyan
    
    # Check main.dart.js size
    $mainJsPath = Join-Path $buildOutput "main.dart.js"
    if (Test-Path $mainJsPath) {
        $mainJsSize = (Get-Item $mainJsPath).Length / 1MB
        $mainJsSizeMB = [math]::Round($mainJsSize, 2)
        Write-Host "   main.dart.js: $mainJsSizeMB MB" -ForegroundColor Cyan
        
        if ($mainJsSizeMB -gt 5) {
            Write-Host "   ⚠️  Large bundle size detected (>5MB)" -ForegroundColor Yellow
            $issues += "Large bundle size: $mainJsSizeMB MB"
        } else {
            Write-Host "   ✅ Bundle size is reasonable" -ForegroundColor Green
        }
    }
}

# Check 6: Deployment Files
Write-Host "`n6. Checking Deployment Configuration..." -ForegroundColor Cyan

$deploymentFiles = @(
    @{ File = "netlify.toml"; Platform = "Netlify"; Required = $false },
    @{ File = "web\vercel.json"; Platform = "Vercel"; Required = $false },
    @{ File = "web\_headers"; Platform = "Netlify"; Required = $false },
    @{ File = "web\404.html"; Platform = "GitHub Pages"; Required = $false },
    @{ File = "web\.nojekyll"; Platform = "GitHub Pages"; Required = $false }
)

foreach ($file in $deploymentFiles) {
    $filePath = Join-Path $projectRoot $file.File
    if (Test-Path $filePath) {
        Write-Host "      ✅ $($file.File) ($($file.Platform))" -ForegroundColor Green
    } else {
        if ($file.Required) {
            Write-Host "      ❌ $($file.File) - MISSING" -ForegroundColor Red
            $issues += "Missing deployment file: $($file.File)"
        } else {
            Write-Host "      ⚠️  $($file.File) - Not found (optional)" -ForegroundColor Yellow
        }
    }
}

# Check 7: URL Verification (if URL provided)
if ($Url -and -not $BuildOnly) {
    Write-Host "`n7. Verifying Deployed App..." -ForegroundColor Cyan
    Write-Host "   URL: $Url" -ForegroundColor Cyan
    
    try {
        $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 10
        if ($response.StatusCode -eq 200) {
            Write-Host "   ✅ App is accessible" -ForegroundColor Green
            
            # Check for manifest
            try {
                $manifestUrl = $Url.TrimEnd('/') + "/manifest.json"
                $manifestResponse = Invoke-WebRequest -Uri $manifestUrl -UseBasicParsing -TimeoutSec 5
                if ($manifestResponse.StatusCode -eq 200) {
                    Write-Host "   ✅ Manifest is accessible" -ForegroundColor Green
                }
            } catch {
                Write-Host "   ⚠️  Manifest not accessible: $_" -ForegroundColor Yellow
            }
            
            # Check HTTPS
            if ($Url.StartsWith("https://")) {
                Write-Host "   ✅ Served over HTTPS (required for PWA)" -ForegroundColor Green
            } else {
                Write-Host "   ⚠️  Not served over HTTPS (PWA requires HTTPS)" -ForegroundColor Yellow
                $issues += "App not served over HTTPS"
            }
        } else {
            Write-Host "   ❌ App returned status code: $($response.StatusCode)" -ForegroundColor Red
            $allChecksPassed = $false
            $issues += "App returned status code: $($response.StatusCode)"
        }
    } catch {
        Write-Host "   ❌ Failed to access app: $_" -ForegroundColor Red
        $allChecksPassed = $false
        $issues += "Failed to access deployed app"
    }
}

# Summary
Write-Host "`n=========================================" -ForegroundColor Cyan
if ($allChecksPassed) {
    Write-Host "✅ All Checks Passed!" -ForegroundColor Green
    Write-Host "=========================================" -ForegroundColor Green
    Write-Host "`nYour web app is ready for deployment!" -ForegroundColor Green
} else {
    Write-Host "⚠️  Some Issues Found" -ForegroundColor Yellow
    Write-Host "=========================================" -ForegroundColor Yellow
    Write-Host "`nIssues:" -ForegroundColor Yellow
    foreach ($issue in $issues) {
        Write-Host "  - $issue" -ForegroundColor Yellow
    }
    Write-Host "`nPlease fix these issues before deploying." -ForegroundColor Yellow
}

Write-Host "`nNext Steps:" -ForegroundColor Cyan
Write-Host "1. Test locally: cd build\web && python -m http.server 8000" -ForegroundColor White
Write-Host "2. Deploy using:" -ForegroundColor White
Write-Host "   - GitHub Pages: scripts\deploy_github_pages.ps1" -ForegroundColor White
Write-Host "   - Netlify: scripts\deploy_netlify.ps1" -ForegroundColor White
Write-Host "   - Vercel: scripts\deploy_vercel.ps1" -ForegroundColor White
Write-Host "3. Verify PWA functionality after deployment" -ForegroundColor White

if (-not $allChecksPassed) {
    exit 1
}
