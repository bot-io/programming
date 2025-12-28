# PowerShell script to generate PWA icons for Dual Reader 3.1
# This script creates simple placeholder icons using .NET graphics

param(
    [string]$OutputDir = "icons"
)

$ErrorActionPreference = "Stop"

# Icon sizes required for PWA
$iconSizes = @(16, 32, 72, 96, 128, 144, 152, 192, 384, 512)

# Colors
$backgroundColor = [System.Drawing.Color]::FromArgb(25, 118, 210)  # #1976D2
$textColor = [System.Drawing.Color]::White

Write-Host "Generating PWA icons for Dual Reader 3.1..." -ForegroundColor Cyan
Write-Host "Output directory: $OutputDir" -ForegroundColor Gray
Write-Host ""

# Ensure output directory exists
$fullOutputPath = Join-Path $PSScriptRoot $OutputDir
if (-not (Test-Path $fullOutputPath)) {
    New-Item -ItemType Directory -Path $fullOutputPath -Force | Out-Null
}

# Load System.Drawing assembly
Add-Type -AssemblyName System.Drawing

$generated = 0
foreach ($size in $iconSizes) {
    try {
        # Create bitmap
        $bitmap = New-Object System.Drawing.Bitmap($size, $size)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        
        # Set high quality rendering
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAlias
        
        # Draw background
        $brush = New-Object System.Drawing.SolidBrush($backgroundColor)
        $graphics.FillRectangle($brush, 0, 0, $size, $size)
        
        # Draw "DR" text
        $fontSize = [Math]::Max(12, [int]($size * 0.4))
        $font = New-Object System.Drawing.Font("Arial", $fontSize, [System.Drawing.FontStyle]::Bold)
        $textBrush = New-Object System.Drawing.SolidBrush($textColor)
        
        # Center text
        $format = New-Object System.Drawing.StringFormat
        $format.Alignment = [System.Drawing.StringAlignment]::Center
        $format.LineAlignment = [System.Drawing.StringAlignment]::Center
        
        $rect = New-Object System.Drawing.RectangleF(0, 0, $size, $size)
        $graphics.DrawString("DR", $font, $textBrush, $rect, $format)
        
        # Save icon
        $outputPath = Join-Path $fullOutputPath "icon-${size}x${size}.png"
        $bitmap.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)
        
        # Cleanup
        $graphics.Dispose()
        $bitmap.Dispose()
        $brush.Dispose()
        $textBrush.Dispose()
        $font.Dispose()
        
        Write-Host "  Created: icon-${size}x${size}.png" -ForegroundColor Green
        $generated++
    }
    catch {
        Write-Host "  Error creating icon-${size}x${size}.png: $_" -ForegroundColor Red
    }
}

# Create favicon.png in web root
try {
    $faviconPath = Join-Path $PSScriptRoot "favicon.png"
    $bitmap = New-Object System.Drawing.Bitmap(32, 32)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAlias
    
    $brush = New-Object System.Drawing.SolidBrush($backgroundColor)
    $graphics.FillRectangle($brush, 0, 0, 32, 32)
    
    $font = New-Object System.Drawing.Font("Arial", 12, [System.Drawing.FontStyle]::Bold)
    $textBrush = New-Object System.Drawing.SolidBrush($textColor)
    $format = New-Object System.Drawing.StringFormat
    $format.Alignment = [System.Drawing.StringAlignment]::Center
    $format.LineAlignment = [System.Drawing.StringAlignment]::Center
    $rect = New-Object System.Drawing.RectangleF(0, 0, 32, 32)
    $graphics.DrawString("DR", $font, $textBrush, $rect, $format)
    
    $bitmap.Save($faviconPath, [System.Drawing.Imaging.ImageFormat]::Png)
    
    $graphics.Dispose()
    $bitmap.Dispose()
    $brush.Dispose()
    $textBrush.Dispose()
    $font.Dispose()
    
    Write-Host "  Created: favicon.png" -ForegroundColor Green
    $generated++
}
catch {
    Write-Host "  Error creating favicon.png: $_" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "✓ Generated $generated icons successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Note: These are placeholder icons. Replace them with your final" -ForegroundColor Yellow
Write-Host "      icon designs for production use." -ForegroundColor Yellow
Write-Host ""
