# Build Script for Dual Reader 3.1 Web Platform
# This script builds the Flutter web app with optimizations and verifies the build output

param(
    [switch]$Release = $true,
    [switch]$Verify = $true,
    [switch]$Analyze = $false,
    [switch]$Test = $false,
    [string]$BaseHref = "/",
    [string]$Target = "web",
    [switch]$Pwa = $true,
    [switch]$Minify = $true
)

Write-Host "🚀 Building Dual Reader 3.1 for Web..." -ForegroundColor Cyan
Write-Host ""

# Check if Flutter is available
try {
    $flutterVersion = flutter --version 2>&1 | Select-Object -First 1
    Write-Host "✅ Flutter found: $flutterVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ Flutter not found. Please install Flutter first." -ForegroundColor Red
    exit 1
}

# Get dependencies
Write-Host "📦 Getting dependencies..." -ForegroundColor Yellow
flutter pub get | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to get dependencies!" -ForegroundColor Red
    exit 1
}

# Analyze code (optional)
if ($Analyze) {
    Write-Host "🔍 Analyzing code..." -ForegroundColor Yellow
    flutter analyze
    if ($LASTEXITCODE -ne 0) {
        Write-Host "⚠️  Code analysis found issues. Continuing build..." -ForegroundColor Yellow
    }
}

# Run tests (optional)
if ($Test) {
    Write-Host "🧪 Running tests..." -ForegroundColor Yellow
    flutter test
    if ($LASTEXITCODE -ne 0) {
        Write-Host "⚠️  Some tests failed. Continuing build..." -ForegroundColor Yellow
    }
}

# Clean previous build
Write-Host "🧹 Cleaning previous build..." -ForegroundColor Yellow
flutter clean | Out-Null

# Build web app
Write-Host "🔨 Building web app..." -ForegroundColor Yellow
$buildArgs = @()

if ($Release) {
    Write-Host "   Mode: Release (optimized)" -ForegroundColor Gray
    $buildArgs += "--release"
    
    # Optimizations
    Write-Host "   Optimizations enabled:" -ForegroundColor Gray
    Write-Host "     - Tree-shake icons" -ForegroundColor Gray
    Write-Host "     - CanvasKit renderer" -ForegroundColor Gray
    Write-Host "     - Minification" -ForegroundColor Gray
    Write-Host "     - Code splitting" -ForegroundColor Gray
    Write-Host "     - PWA support" -ForegroundColor Gray
    
    $buildArgs += "--tree-shake-icons"
    $buildArgs += "--web-renderer", "canvaskit"
    
    if ($Minify) {
        $buildArgs += "--dart-define=FLUTTER_WEB_USE_SKIA=true"
    }
    
    # Ensure PWA is enabled and optimize for production
    $env:FLUTTER_WEB_USE_SKIA = "true"
    $env:FLUTTER_WEB_AUTO_DETECT = "false"
} else {
    Write-Host "   Mode: Debug" -ForegroundColor Gray
}

$buildArgs += "--base-href", "`"$BaseHref`""
$buildArgs += "--target", $Target

$buildCommand = "flutter build web " + ($buildArgs -join " ")
Write-Host "   Command: $buildCommand" -ForegroundColor Gray
Write-Host ""

Invoke-Expression $buildCommand

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Build failed!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "✅ Build completed successfully!" -ForegroundColor Green
Write-Host ""

# Verify build output
if ($Verify) {
    Write-Host "🔍 Verifying build output..." -ForegroundColor Cyan
    Write-Host ""
    
    $buildDir = "build/web"
    $checks = @(
        @{ File = "$buildDir/index.html"; Name = "index.html"; Required = $true },
        @{ File = "$buildDir/manifest.json"; Name = "manifest.json"; Required = $Pwa },
        @{ File = "$buildDir/flutter_service_worker.js"; Name = "flutter_service_worker.js"; Required = $Pwa },
        @{ File = "$buildDir/main.dart.js"; Name = "main.dart.js"; Required = $true },
        @{ File = "$buildDir/flutter.js"; Name = "flutter.js"; Required = $true }
    )
    
    $allPassed = $true
    foreach ($check in $checks) {
        if ($check.Required) {
            if (Test-Path $check.File) {
                $fileSize = (Get-Item $check.File).Length
                $fileSizeKB = [math]::Round($fileSize / 1KB, 2)
                Write-Host "   ✅ $($check.Name) ($fileSizeKB KB)" -ForegroundColor Green
            } else {
                Write-Host "   ❌ $($check.Name) - NOT FOUND" -ForegroundColor Red
                $allPassed = $false
            }
        } else {
            if (Test-Path $check.File) {
                Write-Host "   ✅ $($check.Name) (optional)" -ForegroundColor Gray
            }
        }
    }
    
    # Verify PWA files
    if ($Pwa) {
        Write-Host ""
        Write-Host "   PWA Verification:" -ForegroundColor Cyan
        
        # Check manifest.json content
        $manifestPath = "$buildDir/manifest.json"
        if (Test-Path $manifestPath) {
            try {
                $manifest = Get-Content $manifestPath | ConvertFrom-Json
                $manifestChecks = @(
                    @{ Field = "name"; Value = $manifest.name },
                    @{ Field = "short_name"; Value = $manifest.short_name },
                    @{ Field = "start_url"; Value = $manifest.start_url },
                    @{ Field = "display"; Value = $manifest.display },
                    @{ Field = "icons"; Count = ($manifest.icons | Measure-Object).Count }
                )
                
                foreach ($check in $manifestChecks) {
                    if ($check.Value -or $check.Count -gt 0) {
                        if ($check.Count) {
                            Write-Host "     ✅ $($check.Field): $($check.Count) icons" -ForegroundColor Green
                        } else {
                            Write-Host "     ✅ $($check.Field): $($check.Value)" -ForegroundColor Green
                        }
                    } else {
                        Write-Host "     ⚠️  $($check.Field): missing" -ForegroundColor Yellow
                    }
                }
            } catch {
                Write-Host "     ⚠️  Could not parse manifest.json" -ForegroundColor Yellow
            }
        }
    }
    
    Write-Host ""
    
    if ($allPassed) {
        Write-Host "✅ All build files verified!" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Some required files are missing. Build may be incomplete." -ForegroundColor Yellow
        exit 1
    }
    
    # Check build size
    Write-Host ""
    Write-Host "📊 Build Size Analysis:" -ForegroundColor Cyan
    $buildSize = (Get-ChildItem -Path $buildDir -Recurse -File | Measure-Object -Property Length -Sum).Sum
    $buildSizeMB = [math]::Round($buildSize / 1MB, 2)
    Write-Host "   Total size: $buildSizeMB MB" -ForegroundColor Gray
    
    # Check main.dart.js size
    $mainJsPath = "$buildDir/main.dart.js"
    if (Test-Path $mainJsPath) {
        $mainJsSize = (Get-Item $mainJsPath).Length / 1MB
        $mainJsSizeMB = [math]::Round($mainJsSize, 2)
        Write-Host "   main.dart.js: $mainJsSizeMB MB" -ForegroundColor Gray
        
        if ($mainJsSizeMB -gt 5) {
            Write-Host "   ⚠️  Large bundle size detected. Consider code splitting." -ForegroundColor Yellow
        }
    }
    
    # Check for common optimization issues
    Write-Host ""
    Write-Host "🔍 Optimization Checks:" -ForegroundColor Cyan
    
    # Check if source maps are present (should be removed in production)
    $sourceMaps = Get-ChildItem -Path $buildDir -Filter "*.js.map" -Recurse
    if ($sourceMaps.Count -gt 0 -and $Release) {
        Write-Host "   ⚠️  Source maps found. Consider removing for production." -ForegroundColor Yellow
    }
    
    # Check for large assets
    $largeAssets = Get-ChildItem -Path $buildDir -Recurse -File | Where-Object { $_.Length -gt 1MB }
    if ($largeAssets.Count -gt 0) {
        Write-Host "   ⚠️  Large assets found:" -ForegroundColor Yellow
        foreach ($asset in $largeAssets) {
            $sizeMB = [math]::Round($asset.Length / 1MB, 2)
            Write-Host "      - $($asset.Name): $sizeMB MB" -ForegroundColor Gray
        }
    } else {
        Write-Host "   ✅ No unusually large assets detected" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "📝 Next Steps:" -ForegroundColor Cyan
Write-Host "   1. Test locally: cd build/web && python -m http.server 8000" -ForegroundColor Gray
Write-Host "   2. Open browser: http://localhost:8000" -ForegroundColor Gray
Write-Host "   3. Test PWA installability in browser DevTools" -ForegroundColor Gray
Write-Host "   4. Verify build: .\web\verify_deployment.ps1" -ForegroundColor Gray
Write-Host "   5. Deploy to your hosting platform:" -ForegroundColor Gray
Write-Host "      - GitHub Pages: .\scripts\deploy_github_pages.ps1" -ForegroundColor Gray
Write-Host "      - Netlify: netlify deploy --dir=build/web --prod" -ForegroundColor Gray
Write-Host "      - Vercel: cd build/web && vercel --prod" -ForegroundColor Gray
Write-Host "   6. See docs/WEB_BUILD_AND_DEPLOYMENT_COMPLETE.md for details" -ForegroundColor Gray
Write-Host ""
Write-Host "✨ Build complete!" -ForegroundColor Green
