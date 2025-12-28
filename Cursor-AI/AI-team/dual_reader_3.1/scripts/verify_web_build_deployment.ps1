# Web Build and Deployment Acceptance Criteria Verification Script
# Verifies all acceptance criteria for web build and deployment configuration
#
# Usage:
#   .\verify_web_build_deployment.ps1                    # Verify all criteria
#   .\verify_web_build_deployment.ps1 -BuildOnly        # Verify build only
#   .\verify_web_build_deployment.ps1 -DeployOnly        # Verify deployment config only

param(
    [switch]$BuildOnly,
    [switch]$DeployOnly,
    [switch]$Verbose
)

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Web Build & Deployment Verification" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptPath
Set-Location $projectRoot

$allPassed = $true
$issues = @()

# ============================================
# 1. Optimized Web Build Configuration
# ============================================
if (-not $DeployOnly) {
    Write-Host "1. Optimized Web Build Configuration" -ForegroundColor Yellow
    Write-Host "   Checking build scripts and configuration..." -ForegroundColor Gray
    
    # Check build scripts exist
    $buildScripts = @(
        @{ Path = "scripts\build_web.ps1"; Name = "Windows Build Script"; Required = $true },
        @{ Path = "web\build_web.sh"; Name = "Linux/Mac Build Script"; Required = $true },
        @{ Path = "web\build_web.ps1"; Name = "Web Build Script"; Required = $false }
    )
    
    foreach ($script in $buildScripts) {
        $scriptPath = Join-Path $projectRoot $script.Path
        if (Test-Path $scriptPath) {
            Write-Host "   ✅ $($script.Name) found" -ForegroundColor Green
            
            # Check for optimization flags
            $content = Get-Content $scriptPath -Raw
            $hasTreeShake = $content -match "tree-shake-icons|tree_shake"
            $hasCanvasKit = $content -match "canvaskit|web-renderer"
            $hasRelease = $content -match "--release|Release"
            
            if ($hasTreeShake -and $hasCanvasKit -and $hasRelease) {
                Write-Host "      ✅ Optimization flags present" -ForegroundColor Green
            } else {
                Write-Host "      ⚠️  Missing optimization flags" -ForegroundColor Yellow
                $issues += "$($script.Name): Missing optimization flags"
            }
        } else {
            if ($script.Required) {
                Write-Host "   ❌ $($script.Name) NOT FOUND" -ForegroundColor Red
                $allPassed = $false
                $issues += "$($script.Name): Missing"
            }
        }
    }
    
    # Check pubspec.yaml for web support
    $pubspecPath = Join-Path $projectRoot "pubspec.yaml"
    if (Test-Path $pubspecPath) {
        Write-Host "   ✅ pubspec.yaml found" -ForegroundColor Green
    } else {
        Write-Host "   ❌ pubspec.yaml NOT FOUND" -ForegroundColor Red
        $allPassed = $false
        $issues += "pubspec.yaml: Missing"
    }
    
    Write-Host ""
}

# ============================================
# 2. PWA Manifest Finalized
# ============================================
if (-not $DeployOnly) {
    Write-Host "2. PWA Manifest Finalized" -ForegroundColor Yellow
    Write-Host "   Checking manifest.json..." -ForegroundColor Gray
    
    $manifestPath = Join-Path $projectRoot "web\manifest.json"
    if (Test-Path $manifestPath) {
        Write-Host "   ✅ manifest.json found" -ForegroundColor Green
        
        try {
            $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
            
            # Check required fields
            $requiredFields = @(
                @{ Field = "name"; Value = $manifest.name },
                @{ Field = "short_name"; Value = $manifest.short_name },
                @{ Field = "start_url"; Value = $manifest.start_url },
                @{ Field = "display"; Value = $manifest.display },
                @{ Field = "icons"; Value = $manifest.icons }
            )
            
            foreach ($field in $requiredFields) {
                if ($field.Value) {
                    Write-Host "      ✅ $($field.Field): Present" -ForegroundColor Green
                } else {
                    Write-Host "      ❌ $($field.Field): MISSING" -ForegroundColor Red
                    $allPassed = $false
                    $issues += "manifest.json: Missing field '$($field.Field)'"
                }
            }
            
            # Check icons
            if ($manifest.icons -and $manifest.icons.Count -gt 0) {
                $iconSizes = @()
                foreach ($icon in $manifest.icons) {
                    if ($icon.sizes) {
                        $sizes = $icon.sizes -split 'x' | ForEach-Object { [int]$_ }
                        $iconSizes += $sizes
                    }
                }
                
                $has192 = $iconSizes -contains 192
                $has512 = $iconSizes -contains 512
                
                if ($has192 -and $has512) {
                    Write-Host "      ✅ Required icon sizes present (192x192, 512x512)" -ForegroundColor Green
                } else {
                    Write-Host "      ❌ Missing required icon sizes" -ForegroundColor Red
                    if (-not $has192) { $issues += "manifest.json: Missing 192x192 icon" }
                    if (-not $has512) { $issues += "manifest.json: Missing 512x512 icon" }
                    $allPassed = $false
                }
            } else {
                Write-Host "      ❌ No icons defined" -ForegroundColor Red
                $allPassed = $false
                $issues += "manifest.json: No icons defined"
            }
            
            # Check display mode
            $validDisplayModes = @("standalone", "fullscreen", "minimal-ui", "browser")
            if ($manifest.display -in $validDisplayModes) {
                Write-Host "      ✅ Display mode valid: $($manifest.display)" -ForegroundColor Green
            } else {
                Write-Host "      ⚠️  Display mode may be invalid: $($manifest.display)" -ForegroundColor Yellow
            }
            
        } catch {
            Write-Host "      ❌ manifest.json is invalid JSON: $_" -ForegroundColor Red
            $allPassed = $false
            $issues += "manifest.json: Invalid JSON"
        }
    } else {
        Write-Host "   ❌ manifest.json NOT FOUND" -ForegroundColor Red
        $allPassed = $false
        $issues += "manifest.json: Missing"
    }
    
    Write-Host ""
}

# ============================================
# 3. Service Worker Configured
# ============================================
if (-not $DeployOnly) {
    Write-Host "3. Service Worker Configured" -ForegroundColor Yellow
    Write-Host "   Checking service worker configuration..." -ForegroundColor Gray
    
    # Check service worker file
    $swPath = Join-Path $projectRoot "web\service-worker.js"
    if (Test-Path $swPath) {
        Write-Host "   ✅ service-worker.js found" -ForegroundColor Green
        
        $swContent = Get-Content $swPath -Raw
        $hasInstall = $swContent -match "install|addEventListener.*install"
        $hasActivate = $swContent -match "activate|addEventListener.*activate"
        $hasFetch = $swContent -match "fetch|addEventListener.*fetch"
        
        if ($hasInstall -and $hasActivate -and $hasFetch) {
            Write-Host "      ✅ Service worker events configured" -ForegroundColor Green
        } else {
            Write-Host "      ⚠️  Some service worker events may be missing" -ForegroundColor Yellow
        }
    } else {
        Write-Host "   ⚠️  service-worker.js not found (Flutter generates its own)" -ForegroundColor Yellow
    }
    
    # Check index.html for service worker registration
    $indexPath = Join-Path $projectRoot "web\index.html"
    if (Test-Path $indexPath) {
        $indexContent = Get-Content $indexPath -Raw
        if ($indexContent -match "service.*worker|flutter_service_worker") {
            Write-Host "   ✅ Service worker referenced in index.html" -ForegroundColor Green
        } else {
            Write-Host "   ⚠️  Service worker may not be registered in index.html" -ForegroundColor Yellow
        }
    }
    
    Write-Host ""
}

# ============================================
# 4. Build Scripts for Web Deployment
# ============================================
if (-not $DeployOnly) {
    Write-Host "4. Build Scripts for Web Deployment" -ForegroundColor Yellow
    Write-Host "   Checking deployment scripts..." -ForegroundColor Gray
    
    $deployScripts = @(
        @{ Path = "scripts\deploy_github_pages.ps1"; Name = "GitHub Pages Deployment"; Required = $true },
        @{ Path = "scripts\deploy_netlify.ps1"; Name = "Netlify Deployment"; Required = $true },
        @{ Path = "scripts\deploy_vercel.ps1"; Name = "Vercel Deployment"; Required = $true }
    )
    
    foreach ($script in $deployScripts) {
        $scriptPath = Join-Path $projectRoot $script.Path
        if (Test-Path $scriptPath) {
            Write-Host "   ✅ $($script.Name) script found" -ForegroundColor Green
        } else {
            if ($script.Required) {
                Write-Host "   ❌ $($script.Name) script NOT FOUND" -ForegroundColor Red
                $allPassed = $false
                $issues += "$($script.Name): Missing"
            }
        }
    }
    
    Write-Host ""
}

# ============================================
# 5. Deployment Documentation
# ============================================
if (-not $BuildOnly) {
    Write-Host "5. Deployment Documentation" -ForegroundColor Yellow
    Write-Host "   Checking deployment documentation..." -ForegroundColor Gray
    
    $docs = @(
        @{ Path = "docs\WEB_DEPLOYMENT_GUIDE.md"; Name = "Web Deployment Guide"; Required = $true },
        @{ Path = "docs\WEB_BUILD_AND_DEPLOYMENT.md"; Name = "Build and Deployment Guide"; Required = $true },
        @{ Path = "web\README.md"; Name = "Web README"; Required = $false }
    )
    
    foreach ($doc in $docs) {
        $docPath = Join-Path $projectRoot $doc.Path
        if (Test-Path $docPath) {
            Write-Host "   ✅ $($doc.Name) found" -ForegroundColor Green
            
            # Check for key sections
            $content = Get-Content $docPath -Raw
            $hasGitHubPages = $content -match "GitHub Pages|github.*pages"
            $hasNetlify = $content -match "Netlify|netlify"
            $hasVercel = $content -match "Vercel|vercel"
            
            if ($hasGitHubPages -and $hasNetlify -and $hasVercel) {
                Write-Host "      ✅ All deployment platforms documented" -ForegroundColor Green
            } else {
                Write-Host "      ⚠️  Some deployment platforms may be missing" -ForegroundColor Yellow
            }
        } else {
            if ($doc.Required) {
                Write-Host "   ❌ $($doc.Name) NOT FOUND" -ForegroundColor Red
                $allPassed = $false
                $issues += "$($doc.Name): Missing"
            }
        }
    }
    
    Write-Host ""
}

# ============================================
# 6. Platform Configuration Files
# ============================================
if (-not $BuildOnly) {
    Write-Host "6. Platform Configuration Files" -ForegroundColor Yellow
    Write-Host "   Checking platform-specific configurations..." -ForegroundColor Gray
    
    # GitHub Pages
    $noJekyllPath = Join-Path $projectRoot "web\.nojekyll"
    $custom404Path = Join-Path $projectRoot "web\404.html"
    if (Test-Path $noJekyllPath) {
        Write-Host "   ✅ .nojekyll file found (GitHub Pages)" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️  .nojekyll file not found" -ForegroundColor Yellow
    }
    if (Test-Path $custom404Path) {
        Write-Host "   ✅ 404.html found (GitHub Pages)" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️  404.html not found" -ForegroundColor Yellow
    }
    
    # Netlify
    $netlifyTomlPath = Join-Path $projectRoot "netlify.toml"
    if (Test-Path $netlifyTomlPath) {
        Write-Host "   ✅ netlify.toml found" -ForegroundColor Green
        
        $netlifyContent = Get-Content $netlifyTomlPath -Raw
        $hasBuildCommand = $netlifyContent -match "build.*command|command\s*="
        $hasPublishDir = $netlifyContent -match "publish\s*="
        $hasRedirects = $netlifyContent -match "redirects|\[\[redirects\]\]"
        
        if ($hasBuildCommand -and $hasPublishDir -and $hasRedirects) {
            Write-Host "      ✅ Netlify configuration complete" -ForegroundColor Green
        } else {
            Write-Host "      ⚠️  Netlify configuration may be incomplete" -ForegroundColor Yellow
        }
    } else {
        Write-Host "   ⚠️  netlify.toml not found" -ForegroundColor Yellow
    }
    
    # Vercel
    $vercelJsonPath = Join-Path $projectRoot "web\vercel.json"
    if (Test-Path $vercelJsonPath) {
        Write-Host "   ✅ vercel.json found" -ForegroundColor Green
        
        try {
            $vercelConfig = Get-Content $vercelJsonPath -Raw | ConvertFrom-Json
            $hasBuildCommand = $vercelConfig.buildCommand -or $vercelConfig.build
            $hasOutputDir = $vercelConfig.outputDirectory -or $vercelConfig.output
            $hasHeaders = $vercelConfig.headers
            
            if ($hasBuildCommand -or $hasOutputDir) {
                Write-Host "      ✅ Vercel configuration present" -ForegroundColor Green
            } else {
                Write-Host "      ⚠️  Vercel configuration may be incomplete" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "      ⚠️  vercel.json may be invalid" -ForegroundColor Yellow
        }
    } else {
        Write-Host "   ⚠️  vercel.json not found" -ForegroundColor Yellow
    }
    
    # GitHub Actions
    $githubWorkflowPath = Join-Path $projectRoot ".github\workflows\deploy-web.yml"
    if (Test-Path $githubWorkflowPath) {
        Write-Host "   ✅ GitHub Actions workflow found" -ForegroundColor Green
        
        $workflowContent = Get-Content $githubWorkflowPath -Raw
        $hasBuild = $workflowContent -match "build|Build"
        $hasDeploy = $workflowContent -match "deploy|Deploy"
        
        if ($hasBuild -and $hasDeploy) {
            Write-Host "      ✅ GitHub Actions workflow configured" -ForegroundColor Green
        }
    } else {
        Write-Host "   ⚠️  GitHub Actions workflow not found" -ForegroundColor Yellow
    }
    
    Write-Host ""
}

# ============================================
# 7. PWA Icons
# ============================================
if (-not $DeployOnly) {
    Write-Host "7. PWA Icons" -ForegroundColor Yellow
    Write-Host "   Checking PWA icons..." -ForegroundColor Gray
    
    $iconsDir = Join-Path $projectRoot "web\icons"
    if (Test-Path $iconsDir) {
        Write-Host "   ✅ Icons directory found" -ForegroundColor Green
        
        $requiredIcons = @("icon-192x192.png", "icon-512x512.png")
        foreach ($icon in $requiredIcons) {
            $iconPath = Join-Path $iconsDir $icon
            if (Test-Path $iconPath) {
                Write-Host "      ✅ $icon found" -ForegroundColor Green
            } else {
                Write-Host "      ❌ $icon NOT FOUND" -ForegroundColor Red
                $allPassed = $false
                $issues += "PWA Icons: Missing $icon"
            }
        }
    } else {
        Write-Host "   ❌ Icons directory NOT FOUND" -ForegroundColor Red
        $allPassed = $false
        $issues += "PWA Icons: Directory missing"
    }
    
    Write-Host ""
}

# ============================================
# 8. Security Headers
# ============================================
if (-not $BuildOnly) {
    Write-Host "8. Security Headers Configuration" -ForegroundColor Yellow
    Write-Host "   Checking security headers..." -ForegroundColor Gray
    
    # Check _headers file (Netlify)
    $headersPath = Join-Path $projectRoot "web\_headers"
    if (Test-Path $headersPath) {
        Write-Host "   ✅ _headers file found (Netlify)" -ForegroundColor Green
        
        $headersContent = Get-Content $headersPath -Raw
        $hasSecurityHeaders = $headersContent -match "X-Content-Type-Options|X-XSS-Protection|X-Frame-Options"
        if ($hasSecurityHeaders) {
            Write-Host "      ✅ Security headers configured" -ForegroundColor Green
        }
    }
    
    # Check .htaccess (Apache)
    $htaccessPath = Join-Path $projectRoot "web\.htaccess"
    if (Test-Path $htaccessPath) {
        Write-Host "   ✅ .htaccess file found (Apache)" -ForegroundColor Green
    }
    
    Write-Host ""
}

# ============================================
# Summary
# ============================================
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Verification Summary" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

if ($allPassed -and $issues.Count -eq 0) {
    Write-Host "✅ All acceptance criteria verified!" -ForegroundColor Green
    Write-Host ""
    Write-Host "The web build and deployment configuration is complete and ready for production." -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "1. Run build: .\scripts\build_web.ps1 -Verify" -ForegroundColor White
    Write-Host "2. Test locally: cd build\web && python -m http.server 8000" -ForegroundColor White
    Write-Host "3. Deploy to your chosen platform:" -ForegroundColor White
    Write-Host "   - GitHub Pages: .\scripts\deploy_github_pages.ps1" -ForegroundColor White
    Write-Host "   - Netlify: .\scripts\deploy_netlify.ps1" -ForegroundColor White
    Write-Host "   - Vercel: .\scripts\deploy_vercel.ps1" -ForegroundColor White
    exit 0
} else {
    Write-Host "⚠️  Some issues found:" -ForegroundColor Yellow
    Write-Host ""
    foreach ($issue in $issues) {
        Write-Host "  - $issue" -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host "Please fix these issues before deployment." -ForegroundColor Red
    exit 1
}
