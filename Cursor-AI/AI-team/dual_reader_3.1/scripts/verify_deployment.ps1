# Deployment Verification Script for Windows (PowerShell)
# Verifies that the web build is ready for deployment
# Checks build output, PWA configuration, and deployment readiness
#
# Usage:
#   .\verify_deployment.ps1                    # Verify build output
#   .\verify_deployment.ps1 -Platform "netlify" # Verify for specific platform
#   .\verify_deployment.ps1 -Detailed          # Show detailed information

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("github-pages", "netlify", "vercel", "all")]
    [string]$Platform = "all",
    
    [switch]$Detailed,
    [switch]$FixIssues
)

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Deployment Verification" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# Navigate to project root
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptPath
Set-Location $projectRoot

$buildOutput = Join-Path $projectRoot "build\web"
$issues = @()
$warnings = @()

# Check if build output exists
if (-not (Test-Path $buildOutput)) {
    Write-Host "`n❌ Build output not found: $buildOutput" -ForegroundColor Red
    Write-Host "   Run 'flutter build web --release' first" -ForegroundColor Yellow
    exit 1
}

Write-Host "`nBuild Output: $buildOutput" -ForegroundColor Cyan
Write-Host ""

# 1. Check Essential Files
Write-Host "1. Checking Essential Files..." -ForegroundColor Yellow
$essentialFiles = @(
    @{ File = "index.html"; Required = $true; Description = "Main HTML file" },
    @{ File = "manifest.json"; Required = $true; Description = "PWA manifest" },
    @{ File = "flutter.js"; Required = $true; Description = "Flutter runtime" },
    @{ File = "main.dart.js"; Required = $true; Description = "Main application code" },
    @{ File = "flutter_service_worker.js"; Required = $true; Description = "Service worker" }
)

foreach ($file in $essentialFiles) {
    $filePath = Join-Path $buildOutput $file.File
    if (Test-Path $filePath) {
        $size = (Get-Item $filePath).Length
        $sizeKB = [math]::Round($size / 1KB, 2)
        Write-Host "   ✅ $($file.File) ($sizeKB KB)" -ForegroundColor Green
        if ($Detailed) {
            Write-Host "      $($file.Description)" -ForegroundColor Gray
        }
    } else {
        if ($file.Required) {
            Write-Host "   ❌ $($file.File) - MISSING (Required)" -ForegroundColor Red
            $issues += "Missing required file: $($file.File)"
        } else {
            Write-Host "   ⚠️  $($file.File) - MISSING (Optional)" -ForegroundColor Yellow
            $warnings += "Missing optional file: $($file.File)"
        }
    }
}

# 2. Verify PWA Manifest
Write-Host "`n2. Verifying PWA Manifest..." -ForegroundColor Yellow
$manifestPath = Join-Path $buildOutput "manifest.json"
if (Test-Path $manifestPath) {
    try {
        $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
        
        # Check required fields
        $requiredFields = @(
            @{ Field = "name"; Required = $true },
            @{ Field = "short_name"; Required = $true },
            @{ Field = "start_url"; Required = $true },
            @{ Field = "display"; Required = $true },
            @{ Field = "icons"; Required = $true },
            @{ Field = "theme_color"; Required = $true },
            @{ Field = "background_color"; Required = $true }
        )
        
        foreach ($field in $requiredFields) {
            if ($manifest.PSObject.Properties.Name -contains $field.Field) {
                $value = $manifest.$($field.Field)
                if ($field.Field -eq "icons") {
                    Write-Host "   ✅ $($field.Field): $($value.Count) icons" -ForegroundColor Green
                } else {
                    Write-Host "   ✅ $($field.Field): $value" -ForegroundColor Green
                }
            } else {
                Write-Host "   ❌ Missing field: $($field.Field)" -ForegroundColor Red
                $issues += "manifest.json missing field: $($field.Field)"
            }
        }
        
        # Verify icon sizes
        if ($manifest.icons) {
            $iconSizes = @()
            foreach ($icon in $manifest.icons) {
                if ($icon.sizes) {
                    $sizes = $icon.sizes -split 'x' | ForEach-Object { [int]$_ }
                    $iconSizes += $sizes
                }
            }
            
            $requiredSizes = @(192, 512)
            foreach ($size in $requiredSizes) {
                if ($iconSizes -contains $size) {
                    Write-Host "   ✅ Icon size $size`x$size present" -ForegroundColor Green
                } else {
                    Write-Host "   ❌ Missing required icon size: $size`x$size" -ForegroundColor Red
                    $issues += "manifest.json missing icon size: $size`x$size"
                }
            }
        }
        
        # Verify display mode
        $validDisplayModes = @("standalone", "fullscreen", "minimal-ui", "browser")
        if ($manifest.display -in $validDisplayModes) {
            Write-Host "   ✅ Display mode: $($manifest.display)" -ForegroundColor Green
        } else {
            Write-Host "   ⚠️  Invalid display mode: $($manifest.display)" -ForegroundColor Yellow
            $warnings += "manifest.json has invalid display mode"
        }
        
    } catch {
        Write-Host "   ❌ manifest.json is invalid JSON: $_" -ForegroundColor Red
        $issues += "manifest.json is invalid JSON"
    }
} else {
    Write-Host "   ❌ manifest.json not found" -ForegroundColor Red
    $issues += "manifest.json not found"
}

# 3. Verify Icons
Write-Host "`n3. Verifying PWA Icons..." -ForegroundColor Yellow
$iconDir = Join-Path $buildOutput "icons"
if (Test-Path $iconDir) {
    $requiredIcons = @("icon-192x192.png", "icon-512x512.png")
    foreach ($icon in $requiredIcons) {
        $iconPath = Join-Path $iconDir $icon
        if (Test-Path $iconPath) {
            $size = (Get-Item $iconPath).Length
            $sizeKB = [math]::Round($size / 1KB, 2)
            Write-Host "   ✅ $icon ($sizeKB KB)" -ForegroundColor Green
        } else {
            Write-Host "   ❌ $icon - MISSING" -ForegroundColor Red
            $issues += "Missing icon: $icon"
        }
    }
} else {
    Write-Host "   ❌ Icons directory not found" -ForegroundColor Red
    $issues += "Icons directory not found"
}

# 4. Verify Service Worker
Write-Host "`n4. Verifying Service Worker..." -ForegroundColor Yellow
$swPath = Join-Path $buildOutput "flutter_service_worker.js"
if (Test-Path $swPath) {
    $swContent = Get-Content $swPath -Raw
    if ($swContent -match "serviceWorkerVersion|RESOURCES|CACHE_NAME") {
        Write-Host "   ✅ Service worker structure valid" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️  Service worker may be incomplete" -ForegroundColor Yellow
        $warnings += "Service worker structure may be incomplete"
    }
    
    # Check index.html for service worker registration
    $indexPath = Join-Path $buildOutput "index.html"
    if (Test-Path $indexPath) {
        $indexContent = Get-Content $indexPath -Raw
        if ($indexContent -match "flutter_service_worker|service.*worker") {
            Write-Host "   ✅ Service worker referenced in index.html" -ForegroundColor Green
        } else {
            Write-Host "   ⚠️  Service worker may not be registered" -ForegroundColor Yellow
            $warnings += "Service worker may not be registered in index.html"
        }
    }
} else {
    Write-Host "   ❌ Service worker not found" -ForegroundColor Red
    $issues += "Service worker not found"
}

# 5. Check Build Size
Write-Host "`n5. Checking Build Size..." -ForegroundColor Yellow
$buildSize = (Get-ChildItem -Path $buildOutput -Recurse -File | Measure-Object -Property Length -Sum).Sum
$buildSizeMB = [math]::Round($buildSize / 1MB, 2)
Write-Host "   Total build size: $buildSizeMB MB" -ForegroundColor Cyan

$mainJsPath = Join-Path $buildOutput "main.dart.js"
if (Test-Path $mainJsPath) {
    $mainJsSize = (Get-Item $mainJsPath).Length / 1MB
    $mainJsSizeMB = [math]::Round($mainJsSize, 2)
    Write-Host "   main.dart.js: $mainJsSizeMB MB" -ForegroundColor Cyan
    
    if ($mainJsSizeMB -gt 5) {
        Write-Host "   ⚠️  main.dart.js is large (>5MB)" -ForegroundColor Yellow
        $warnings += "main.dart.js is large ($mainJsSizeMB MB)"
    } else {
        Write-Host "   ✅ main.dart.js size is reasonable" -ForegroundColor Green
    }
}

# 6. Platform-Specific Checks
Write-Host "`n6. Platform-Specific Checks..." -ForegroundColor Yellow

if ($Platform -eq "all" -or $Platform -eq "github-pages") {
    Write-Host "   GitHub Pages:" -ForegroundColor Cyan
    $noJekyllPath = Join-Path $buildOutput ".nojekyll"
    if (Test-Path $noJekyllPath) {
        Write-Host "      ✅ .nojekyll present" -ForegroundColor Green
    } else {
        Write-Host "      ⚠️  .nojekyll missing (recommended)" -ForegroundColor Yellow
        if ($FixIssues) {
            "" | Out-File -FilePath $noJekyllPath -Encoding ASCII
            Write-Host "      ✅ Created .nojekyll" -ForegroundColor Green
        } else {
            $warnings += "GitHub Pages: .nojekyll missing"
        }
    }
    
    $custom404Path = Join-Path $buildOutput "404.html"
    if (Test-Path $custom404Path) {
        Write-Host "      ✅ 404.html present" -ForegroundColor Green
    } else {
        Write-Host "      ⚠️  404.html missing (recommended)" -ForegroundColor Yellow
        if ($FixIssues) {
            $indexPath = Join-Path $buildOutput "index.html"
            if (Test-Path $indexPath) {
                Copy-Item $indexPath $custom404Path -Force
                Write-Host "      ✅ Created 404.html from index.html" -ForegroundColor Green
            }
        } else {
            $warnings += "GitHub Pages: 404.html missing"
        }
    }
}

if ($Platform -eq "all" -or $Platform -eq "netlify") {
    Write-Host "   Netlify:" -ForegroundColor Cyan
    $netlifyToml = Join-Path $projectRoot "netlify.toml"
    if (Test-Path $netlifyToml) {
        Write-Host "      ✅ netlify.toml present" -ForegroundColor Green
    } else {
        Write-Host "      ⚠️  netlify.toml missing (recommended)" -ForegroundColor Yellow
        $warnings += "Netlify: netlify.toml missing"
    }
    
    $headersFile = Join-Path $projectRoot "web\_headers"
    if (Test-Path $headersFile) {
        Write-Host "      ✅ _headers file present" -ForegroundColor Green
    } else {
        Write-Host "      ⚠️  _headers file missing (optional)" -ForegroundColor Yellow
    }
}

if ($Platform -eq "all" -or $Platform -eq "vercel") {
    Write-Host "   Vercel:" -ForegroundColor Cyan
    $vercelJsonWeb = Join-Path $projectRoot "web\vercel.json"
    $vercelJsonRoot = Join-Path $projectRoot "vercel.json"
    if (Test-Path $vercelJsonWeb) {
        Write-Host "      ✅ vercel.json present (web/)" -ForegroundColor Green
    } elseif (Test-Path $vercelJsonRoot) {
        Write-Host "      ✅ vercel.json present (root)" -ForegroundColor Green
    } else {
        Write-Host "      ⚠️  vercel.json missing (recommended)" -ForegroundColor Yellow
        $warnings += "Vercel: vercel.json missing"
    }
}

# 7. Security Checks
Write-Host "`n7. Security Checks..." -ForegroundColor Yellow
$indexPath = Join-Path $buildOutput "index.html"
if (Test-Path $indexPath) {
    $indexContent = Get-Content $indexPath -Raw
    
    # Check for HTTPS in manifest start_url
    if ($manifest.start_url -match "^https://|^/") {
        Write-Host "   ✅ start_url is secure" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️  start_url may not be secure" -ForegroundColor Yellow
        $warnings += "start_url may not be secure"
    }
    
    # Check for service worker scope
    if ($indexContent -match "service.*worker.*scope") {
        Write-Host "   ✅ Service worker scope configured" -ForegroundColor Green
    }
}

# Summary
Write-Host "`n=========================================" -ForegroundColor Cyan
Write-Host "Verification Summary" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

if ($issues.Count -eq 0 -and $warnings.Count -eq 0) {
    Write-Host "`n✅ All checks passed! Build is ready for deployment." -ForegroundColor Green
    exit 0
} else {
    if ($issues.Count -gt 0) {
        Write-Host "`n❌ Issues found ($($issues.Count)):" -ForegroundColor Red
        foreach ($issue in $issues) {
            Write-Host "   - $issue" -ForegroundColor Red
        }
    }
    
    if ($warnings.Count -gt 0) {
        Write-Host "`n⚠️  Warnings ($($warnings.Count)):" -ForegroundColor Yellow
        foreach ($warning in $warnings) {
            Write-Host "   - $warning" -ForegroundColor Yellow
        }
    }
    
    if ($issues.Count -gt 0) {
        Write-Host "`n❌ Build is NOT ready for deployment. Fix issues above." -ForegroundColor Red
        exit 1
    } else {
        Write-Host "`n⚠️  Build has warnings but may be deployable." -ForegroundColor Yellow
        exit 0
    }
}
