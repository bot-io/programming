# PowerShell script to generate placeholder PWA icons for Dual Reader 3.1
# This creates simple placeholder icons so the PWA can be tested

$ErrorActionPreference = "Stop"

# Icon sizes required for PWA
$iconSizes = @(16, 32, 72, 96, 128, 144, 152, 192, 384, 512)

# Colors (Material Blue #1976D2)
$backgroundColor = "#1976D2"
$textColor = "#FFFFFF"

# Get script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$iconsDir = Join-Path $scriptDir "icons"
$webDir = $scriptDir

Write-Host "Creating placeholder PWA icons for Dual Reader 3.1..." -ForegroundColor Cyan
Write-Host "Output directory: $iconsDir" -ForegroundColor Gray
Write-Host ""

# Create icons directory if it doesn't exist
if (-not (Test-Path $iconsDir)) {
    New-Item -ItemType Directory -Path $iconsDir | Out-Null
}

# Check if ImageMagick is available
$hasImageMagick = $false
try {
    $magickVersion = & magick -version 2>&1
    if ($LASTEXITCODE -eq 0) {
        $hasImageMagick = $true
        Write-Host "Using ImageMagick for icon generation" -ForegroundColor Green
    }
} catch {
    $hasImageMagick = $false
}

if (-not $hasImageMagick) {
    Write-Host "ImageMagick not found. Creating simple SVG-based icons..." -ForegroundColor Yellow
    Write-Host ""
    
    # Create SVG icons (will be converted to PNG if possible)
    foreach ($size in $iconSizes) {
        $iconPath = Join-Path $iconsDir "icon-${size}x${size}.png"
        
        # Create a simple SVG
        $svgContent = @"
<svg width="$size" height="$size" xmlns="http://www.w3.org/2000/svg">
  <rect width="$size" height="$size" fill="$backgroundColor"/>
  <text x="50%" y="50%" font-family="Arial, sans-serif" font-size="$($size * 0.4)" font-weight="bold" fill="$textColor" text-anchor="middle" dominant-baseline="central">DR</text>
</svg>
"@
        
        $svgPath = Join-Path $iconsDir "icon-${size}x${size}.svg"
        $svgContent | Out-File -FilePath $svgPath -Encoding UTF8
        
        # Try to convert SVG to PNG using PowerShell (basic approach)
        # For production, use ImageMagick or another tool
        Write-Host "Created: icon-${size}x${size}.svg (convert to PNG manually or install ImageMagick)" -ForegroundColor Yellow
        
        # If ImageMagick is available later, convert SVG to PNG
        if ($hasImageMagick) {
            & magick convert $svgPath -background none $iconPath 2>&1 | Out-Null
            if (Test-Path $iconPath) {
                Remove-Item $svgPath
                Write-Host "Created: icon-${size}x${size}.png" -ForegroundColor Green
            }
        }
    }
    
    Write-Host ""
    Write-Host "Note: SVG files were created. To convert to PNG:" -ForegroundColor Yellow
    Write-Host "  1. Install ImageMagick: https://imagemagick.org/script/download.php" -ForegroundColor Yellow
    Write-Host "  2. Run: magick convert icon-192x192.svg icon-192x192.png" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Or use the Python script: python web/icons/create_placeholder_icons.py" -ForegroundColor Cyan
} else {
    # Use ImageMagick to create PNG icons directly
    foreach ($size in $iconSizes) {
        $iconPath = Join-Path $iconsDir "icon-${size}x${size}.png"
        
        # Create icon using ImageMagick
        $magickCmd = "magick -size ${size}x${size} xc:`"$backgroundColor`" -gravity center -pointsize $($size * 0.4) -font Arial-Bold -fill `"$textColor`" -annotate +0+0 `"DR`" `"$iconPath`""
        
        try {
            Invoke-Expression $magickCmd
            if (Test-Path $iconPath) {
                Write-Host "Created: icon-${size}x${size}.png" -ForegroundColor Green
            }
        } catch {
            Write-Host "Failed to create icon-${size}x${size}.png: $_" -ForegroundColor Red
        }
    }
}

# Create favicon.png in web root
$faviconPath = Join-Path $webDir "favicon.png"
if ($hasImageMagick) {
    $magickCmd = "magick -size 32x32 xc:`"$backgroundColor`" -gravity center -pointsize 12 -font Arial-Bold -fill `"$textColor`" -annotate +0+0 `"DR`" `"$faviconPath`""
    try {
        Invoke-Expression $magickCmd
        Write-Host "Created: favicon.png" -ForegroundColor Green
    } catch {
        Write-Host "Failed to create favicon.png: $_" -ForegroundColor Red
    }
} else {
    Write-Host "Create favicon.png manually or install ImageMagick" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "✓ Icon generation complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Note: These are placeholder icons. Replace them with your final" -ForegroundColor Yellow
Write-Host "      icon designs for production use." -ForegroundColor Yellow
Write-Host ""
Write-Host "To replace icons:" -ForegroundColor Cyan
Write-Host "  1. Design your icon at 512x512 pixels" -ForegroundColor Cyan
Write-Host "  2. Use generate_icons.py with your design:" -ForegroundColor Cyan
Write-Host "     python web/icons/generate_icons.py your-icon-512x512.png" -ForegroundColor Cyan
