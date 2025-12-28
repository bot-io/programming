# Web Build Script for Windows (PowerShell)
# Builds optimized Flutter web app with PWA support
# Includes all optimizations: tree-shaking, CanvasKit renderer, PWA manifest, service worker
#
# Usage:
#   .\build_web.ps1                    # Build for production (optimized)
#   .\build_web.ps1 -Release           # Build release (default)
#   .\build_web.ps1 -Debug              # Build debug
#   .\build_web.ps1 -BaseHref "/app/"  # Build with custom base href
#   .\build_web.ps1 -Analyze            # Run analyzer before build
#   .\build_web.ps1 -Verify             # Verify build output after build

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("Release", "Debug")]
    [string]$Mode = "Release",
    
    [Parameter(Mandatory=$false)]
    [string]$BaseHref = "/",
    
    [switch]$Analyze,
    [switch]$Verify,
    [switch]$NoTreeShake,
    [switch]$Verbose
)

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Web Build Script" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# Check if Flutter is installed
$flutterCheck = flutter --version 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Flutter is not installed or not in PATH" -ForegroundColor Red
    exit 1
}

# Navigate to project root
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptPath
Set-Location $projectRoot

# Get version info
$pubspecContent = Get-Content "pubspec.yaml" -Raw
if ($pubspecContent -match "version:\s*(\d+\.\d+\.\d+)\+(\d+)") {
    $versionName = $matches[1]
    $versionCode = $matches[2]
    Write-Host "Version: $versionName (Build: $versionCode)" -ForegroundColor Cyan
    Write-Host ""
}

# Validate base href format
if (-not $BaseHref.EndsWith("/")) {
    $BaseHref = $BaseHref + "/"
}
if (-not $BaseHref.StartsWith("/")) {
    $BaseHref = "/" + $BaseHref
}

Write-Host "Build Mode: $Mode" -ForegroundColor Yellow
Write-Host "Base Href: $BaseHref" -ForegroundColor Yellow
Write-Host ""

# Clean previous builds
Write-Host "Cleaning previous builds..." -ForegroundColor Yellow
flutter clean
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Failed to clean build" -ForegroundColor Red
    exit 1
}

# Get dependencies
Write-Host "`nGetting dependencies..." -ForegroundColor Yellow
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Failed to get dependencies" -ForegroundColor Red
    exit 1
}

# Run analyzer if requested
if ($Analyze) {
    Write-Host "`nRunning Flutter analyzer..." -ForegroundColor Yellow
    flutter analyze
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Warning: Analyzer found issues" -ForegroundColor Yellow
    }
}

# Build web app
Write-Host "`n=========================================" -ForegroundColor Cyan
Write-Host "Building Web App" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

$buildArgs = @("build", "web")

if ($Mode -eq "Release") {
    $buildArgs += "--release"
} else {
    $buildArgs += "--debug"
}

$buildArgs += "--base-href", $BaseHref

if ($Mode -eq "Release") {
    if (-not $NoTreeShake) {
        $buildArgs += "--tree-shake-icons"
    }
    # Use CanvasKit renderer for better performance and smaller bundle size
    $buildArgs += "--web-renderer", "canvaskit"
    # Enable additional optimizations
    $buildArgs += "--dart-define=FLUTTER_WEB_USE_SKIA=true"
    # Enable code splitting for better performance
    $env:FLUTTER_WEB_USE_SKIA = "true"
}

if ($Verbose) {
    $buildArgs += "--verbose"
}

Write-Host "Running: flutter $($buildArgs -join ' ')" -ForegroundColor Yellow
flutter $buildArgs

if ($LASTEXITCODE -ne 0) {
    Write-Host "`n=========================================" -ForegroundColor Red
    Write-Host "Build Failed!" -ForegroundColor Red
    Write-Host "=========================================" -ForegroundColor Red
    exit 1
}

# Verify build output
$buildOutput = Join-Path $projectRoot "build\web"
if (-not (Test-Path $buildOutput)) {
    Write-Host "Error: Build output directory not found" -ForegroundColor Red
    exit 1
}

# Copy deployment files for GitHub Pages
Write-Host "`nPreparing deployment files..." -ForegroundColor Yellow

# Create .nojekyll file for GitHub Pages
$noJekyllPath = Join-Path $buildOutput ".nojekyll"
if (-not (Test-Path $noJekyllPath)) {
    "" | Out-File -FilePath $noJekyllPath -Encoding ASCII
    Write-Host "   Created .nojekyll for GitHub Pages" -ForegroundColor Green
}

# Copy 404.html if it exists in web directory, otherwise create from index.html
$web404Path = Join-Path $projectRoot "web\404.html"
$build404Path = Join-Path $buildOutput "404.html"
if (Test-Path $web404Path) {
    Copy-Item $web404Path $build404Path -Force
    Write-Host "   Copied 404.html for GitHub Pages" -ForegroundColor Green
} elseif (-not (Test-Path $build404Path)) {
    $indexPath = Join-Path $buildOutput "index.html"
    if (Test-Path $indexPath) {
        Copy-Item $indexPath $build404Path -Force
        Write-Host "   Created 404.html from index.html" -ForegroundColor Green
    }
}

# Copy vercel.json to build output if it exists (for Vercel deployment)
$vercelJsonWeb = Join-Path $projectRoot "web\vercel.json"
$vercelJsonRoot = Join-Path $projectRoot "vercel.json"
$vercelJsonBuild = Join-Path $buildOutput "vercel.json"
if (Test-Path $vercelJsonWeb) {
    Copy-Item $vercelJsonWeb $vercelJsonBuild -Force
    Write-Host "   Copied vercel.json for Vercel deployment" -ForegroundColor Green
} elseif (Test-Path $vercelJsonRoot) {
    Copy-Item $vercelJsonRoot $vercelJsonBuild -Force
    Write-Host "   Copied vercel.json for Vercel deployment" -ForegroundColor Green
}

# Check for essential files
$essentialFiles = @(
    "index.html",
    "manifest.json",
    "flutter.js",
    "main.dart.js"
)

$missingFiles = @()
foreach ($file in $essentialFiles) {
    $filePath = Join-Path $buildOutput $file
    if (-not (Test-Path $filePath)) {
        $missingFiles += $file
    }
}

if ($missingFiles.Count -gt 0) {
    Write-Host "`nWarning: Missing essential files:" -ForegroundColor Yellow
    foreach ($file in $missingFiles) {
        Write-Host "  - $file" -ForegroundColor Yellow
    }
}

# Verify PWA files
if ($Verify -or $Mode -eq "Release") {
    Write-Host "`nVerifying PWA configuration..." -ForegroundColor Cyan
    
    $pwaFiles = @(
        @{ File = "manifest.json"; Required = $true },
        @{ File = "flutter_service_worker.js"; Required = $true },
        @{ File = "icons/icon-192x192.png"; Required = $true },
        @{ File = "icons/icon-512x512.png"; Required = $true }
    )
    
    $pwaIssues = @()
    foreach ($pwaFile in $pwaFiles) {
        $filePath = Join-Path $buildOutput $pwaFile.File
        if (Test-Path $filePath) {
            Write-Host "   ✅ $($pwaFile.File)" -ForegroundColor Green
        } else {
            if ($pwaFile.Required) {
                Write-Host "   ❌ $($pwaFile.File) - MISSING (Required)" -ForegroundColor Red
                $pwaIssues += $pwaFile.File
            } else {
                Write-Host "   ⚠️  $($pwaFile.File) - MISSING (Optional)" -ForegroundColor Yellow
            }
        }
    }
    
    # Verify manifest.json content
    $manifestPath = Join-Path $buildOutput "manifest.json"
    if (Test-Path $manifestPath) {
        try {
            $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
            $requiredFields = @("name", "short_name", "start_url", "display", "icons")
            foreach ($field in $requiredFields) {
                if (-not $manifest.$field) {
                    Write-Host "   ⚠️  manifest.json missing field: $field" -ForegroundColor Yellow
                    $pwaIssues += "manifest.json (missing $field)"
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
                if ($iconSizes -contains 192 -and $iconSizes -contains 512) {
                    Write-Host "   ✅ Required icon sizes present (192x192, 512x512)" -ForegroundColor Green
                } else {
                    Write-Host "   ⚠️  Missing required icon sizes" -ForegroundColor Yellow
                    if ($iconSizes -notcontains 192) { $pwaIssues += "manifest.json (missing 192x192 icon)" }
                    if ($iconSizes -notcontains 512) { $pwaIssues += "manifest.json (missing 512x512 icon)" }
                }
            }
            
            # Verify display mode
            $validDisplayModes = @("standalone", "fullscreen", "minimal-ui", "browser")
            if ($manifest.display -in $validDisplayModes) {
                Write-Host "   ✅ Display mode is valid: $($manifest.display)" -ForegroundColor Green
            } else {
                Write-Host "   ⚠️  Display mode may be invalid: $($manifest.display)" -ForegroundColor Yellow
            }
            
            if ($pwaIssues.Count -eq 0) {
                Write-Host "   ✅ manifest.json structure valid" -ForegroundColor Green
            }
        } catch {
            Write-Host "   ❌ manifest.json is invalid JSON: $_" -ForegroundColor Red
            $pwaIssues += "manifest.json (invalid JSON)"
        }
    }
    
    # Verify service worker registration in index.html
    $indexPath = Join-Path $buildOutput "index.html"
    if (Test-Path $indexPath) {
        $indexContent = Get-Content $indexPath -Raw
        if ($indexContent -match "flutter_service_worker|service.*worker") {
            Write-Host "   ✅ Service worker referenced in index.html" -ForegroundColor Green
        } else {
            Write-Host "   ⚠️  Service worker may not be registered" -ForegroundColor Yellow
            $pwaIssues += "index.html (service worker not found)"
        }
    }
    
    if ($pwaIssues.Count -gt 0) {
        Write-Host "`n⚠️  PWA configuration issues found. App may not be installable." -ForegroundColor Yellow
        Write-Host "   Issues: $($pwaIssues -join ', ')" -ForegroundColor Yellow
    } else {
        Write-Host "`n✅ PWA configuration verified!" -ForegroundColor Green
        Write-Host "   App is ready for deployment as PWA" -ForegroundColor Green
    }
}

# Display build info
Write-Host "`n=========================================" -ForegroundColor Green
Write-Host "Build Complete!" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host "Build output: $buildOutput" -ForegroundColor Green
Write-Host ""

# Calculate build size
$buildSize = (Get-ChildItem -Path $buildOutput -Recurse -File | Measure-Object -Property Length -Sum).Sum
$buildSizeMB = [math]::Round($buildSize / 1MB, 2)
Write-Host "Build size: $buildSizeMB MB" -ForegroundColor Cyan

# List main files with sizes
Write-Host "`nMain files:" -ForegroundColor Cyan
$mainFiles = Get-ChildItem -Path $buildOutput -File | Where-Object { 
    $_.Name -match "\.(js|html|json|png|ico)$" 
} | Select-Object Name, @{Name="Size (KB)";Expression={[math]::Round($_.Length/1KB, 2)}} | Sort-Object "Size (KB)" -Descending
$mainFiles | Format-Table -AutoSize

# Check main.dart.js size (should be optimized)
$mainJsPath = Join-Path $buildOutput "main.dart.js"
if (Test-Path $mainJsPath) {
    $mainJsSize = (Get-Item $mainJsPath).Length / 1MB
    $mainJsSizeMB = [math]::Round($mainJsSize, 2)
    Write-Host "main.dart.js size: $mainJsSizeMB MB" -ForegroundColor Cyan
    if ($mainJsSizeMB -gt 5) {
        Write-Host "⚠️  Warning: main.dart.js is large. Consider code splitting." -ForegroundColor Yellow
    }
}

Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "1. Test locally: cd build\web && python -m http.server 8000" -ForegroundColor White
Write-Host "2. Open browser: http://localhost:8000" -ForegroundColor White
Write-Host "3. Test PWA: Open DevTools > Application > Service Workers" -ForegroundColor White
Write-Host "4. Deploy to hosting:" -ForegroundColor White
Write-Host "   - GitHub Pages: scripts\deploy_github_pages.ps1" -ForegroundColor White
Write-Host "   - Netlify: scripts\deploy_netlify.ps1" -ForegroundColor White
Write-Host "   - Vercel: scripts\deploy_vercel.ps1" -ForegroundColor White
