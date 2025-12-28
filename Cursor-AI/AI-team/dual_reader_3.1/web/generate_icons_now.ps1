# Generate PWA Icons for Dual Reader 3.1
# This script creates all required icon sizes using .NET System.Drawing

$ErrorActionPreference = "Stop"

Write-Host "Generating PWA icons for Dual Reader 3.1..." -ForegroundColor Cyan

# Icon sizes required for PWA
$iconSizes = @(16, 32, 72, 96, 128, 144, 152, 192, 384, 512)
$backgroundColor = [System.Drawing.Color]::FromArgb(25, 118, 210)  # #1976D2
$textColor = [System.Drawing.Color]::White

# Ensure icons directory exists
$iconsDir = Join-Path $PSScriptRoot "icons"
if (-not (Test-Path $iconsDir)) {
    New-Item -ItemType Directory -Path $iconsDir | Out-Null
}

function Create-Icon {
    param([int]$Size)
    
    try {
        # Create bitmap
        $bitmap = New-Object System.Drawing.Bitmap($Size, $Size)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAlias
        
        # Fill background
        $bgBrush = New-Object System.Drawing.SolidBrush($backgroundColor)
        $graphics.FillRectangle($bgBrush, 0, 0, $Size, $Size)
        
        # Draw "DR" text
        $fontSize = [Math]::Max(12, [int]($Size * 0.4))
        $font = New-Object System.Drawing.Font("Arial", $fontSize, [System.Drawing.FontStyle]::Bold)
        $textBrush = New-Object System.Drawing.SolidBrush($textColor)
        
        $text = "DR"
        $textSize = $graphics.MeasureString($text, $font)
        $x = ($Size - $textSize.Width) / 2
        $y = ($Size - $textSize.Height) / 2
        
        $graphics.DrawString($text, $font, $textBrush, $x, $y)
        
        # Save icon
        $outputPath = Join-Path $iconsDir "icon-${Size}x${Size}.png"
        $bitmap.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)
        
        Write-Host "  ✓ Created icon-${Size}x${Size}.png" -ForegroundColor Green
        
        # Cleanup
        $graphics.Dispose()
        $bitmap.Dispose()
        $bgBrush.Dispose()
        $textBrush.Dispose()
        $font.Dispose()
    }
    catch {
        Write-Host "  ✗ Failed to create icon-${Size}x${Size}.png: $_" -ForegroundColor Red
    }
}

# Generate all icons
foreach ($size in $iconSizes) {
    Create-Icon -Size $size
}

# Create favicon.png (32x32)
try {
    $bitmap = New-Object System.Drawing.Bitmap(32, 32)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    
    $bgBrush = New-Object System.Drawing.SolidBrush($backgroundColor)
    $graphics.FillRectangle($bgBrush, 0, 0, 32, 32)
    
    $font = New-Object System.Drawing.Font("Arial", 12, [System.Drawing.FontStyle]::Bold)
    $textBrush = New-Object System.Drawing.SolidBrush($textColor)
    $textSize = $graphics.MeasureString("DR", $font)
    $x = (32 - $textSize.Width) / 2
    $y = (32 - $textSize.Height) / 2
    $graphics.DrawString("DR", $font, $textBrush, $x, $y)
    
    $faviconPath = Join-Path $PSScriptRoot "favicon.png"
    $bitmap.Save($faviconPath, [System.Drawing.Imaging.ImageFormat]::Png)
    
    Write-Host "  ✓ Created favicon.png" -ForegroundColor Green
    
    # Also create favicon.ico (copy of png for simplicity)
    Copy-Item $faviconPath (Join-Path $PSScriptRoot "favicon.ico") -Force
    Write-Host "  ✓ Created favicon.ico" -ForegroundColor Green
    
    $graphics.Dispose()
    $bitmap.Dispose()
    $bgBrush.Dispose()
    $textBrush.Dispose()
    $font.Dispose()
}
catch {
    Write-Host "  ✗ Failed to create favicon: $_" -ForegroundColor Red
}

Write-Host "`n✅ Icon generation complete!" -ForegroundColor Green
Write-Host "All icons are saved in: $iconsDir" -ForegroundColor Cyan
