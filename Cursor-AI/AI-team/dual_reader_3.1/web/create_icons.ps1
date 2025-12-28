# Create PWA Icons for Dual Reader 3.1
# This script creates all required icon sizes for PWA

$ErrorActionPreference = "Continue"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$iconsDir = Join-Path $scriptDir "icons"
$sizes = @(16, 32, 72, 96, 128, 144, 152, 192, 384, 512)

Write-Host "Creating PWA icons for Dual Reader 3.1..." -ForegroundColor Cyan
Write-Host "Icons directory: $iconsDir" -ForegroundColor Gray
Write-Host ""

# Ensure icons directory exists
if (-not (Test-Path $iconsDir)) {
    New-Item -ItemType Directory -Path $iconsDir -Force | Out-Null
    Write-Host "Created icons directory" -ForegroundColor Green
}

try {
    Add-Type -AssemblyName System.Drawing
    
    foreach ($size in $sizes) {
        $outputPath = Join-Path $iconsDir "icon-${size}x${size}.png"
        
        try {
            # Create bitmap
            $bitmap = New-Object System.Drawing.Bitmap($size, $size)
            $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
            
            # Set high quality rendering
            $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
            $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAlias
            
            # Fill background with Material Blue (#1976D2)
            $bgColor = [System.Drawing.Color]::FromArgb(25, 118, 210)
            $bgBrush = New-Object System.Drawing.SolidBrush($bgColor)
            $graphics.FillRectangle($bgBrush, 0, 0, $size, $size)
            
            # Draw text "DR"
            $fontSize = [math]::Max(8, [int]($size * 0.35))
            $font = New-Object System.Drawing.Font("Arial", $fontSize, [System.Drawing.FontStyle]::Bold)
            $textBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
            
            $text = "DR"
            $textSize = $graphics.MeasureString($text, $font)
            $x = ($size - $textSize.Width) / 2
            $y = ($size - $textSize.Height) / 2
            
            $graphics.DrawString($text, $font, $textBrush, $x, $y)
            
            # Save
            $bitmap.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)
            
            # Cleanup
            $graphics.Dispose()
            $bitmap.Dispose()
            $bgBrush.Dispose()
            $textBrush.Dispose()
            $font.Dispose()
            
            Write-Host "  ✓ Created icon-${size}x${size}.png" -ForegroundColor Green
        } catch {
            Write-Host "  ✗ Failed to create icon-${size}x${size}.png : $_" -ForegroundColor Red
        }
    }
    
    # Create favicon.png in web root
    $faviconPath = Join-Path $scriptDir "favicon.png"
    try {
        $bitmap = New-Object System.Drawing.Bitmap(32, 32)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAlias
        
        $bgColor = [System.Drawing.Color]::FromArgb(25, 118, 210)
        $bgBrush = New-Object System.Drawing.SolidBrush($bgColor)
        $graphics.FillRectangle($bgBrush, 0, 0, 32, 32)
        
        $font = New-Object System.Drawing.Font("Arial", 10, [System.Drawing.FontStyle]::Bold)
        $textBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
        
        $text = "DR"
        $textSize = $graphics.MeasureString($text, $font)
        $x = (32 - $textSize.Width) / 2
        $y = (32 - $textSize.Height) / 2
        
        $graphics.DrawString($text, $font, $textBrush, $x, $y)
        $bitmap.Save($faviconPath, [System.Drawing.Imaging.ImageFormat]::Png)
        
        $graphics.Dispose()
        $bitmap.Dispose()
        $bgBrush.Dispose()
        $textBrush.Dispose()
        $font.Dispose()
        
        Write-Host "  ✓ Created favicon.png" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ Failed to create favicon.png : $_" -ForegroundColor Red
    }
    
    Write-Host ""
    Write-Host "✓ Icon generation complete!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Note: These are placeholder icons. Replace with your final designs for production." -ForegroundColor Yellow
    
} catch {
    Write-Host ""
    Write-Host "Error: System.Drawing assembly not available." -ForegroundColor Red
    Write-Host "Please ensure you're running on Windows with .NET Framework available." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Alternative: Use the HTML icon generator:" -ForegroundColor Cyan
    Write-Host "  1. Open web/icons/generate_icons_simple.html in your browser" -ForegroundColor White
    Write-Host "  2. Generate and download icons" -ForegroundColor White
    exit 1
}
