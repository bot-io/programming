# Simple icon generator for Dual Reader 3.1 PWA
# Creates placeholder icons using .NET Graphics

$ErrorActionPreference = "Stop"

# Icon sizes required for PWA
$iconSizes = @(16, 32, 72, 96, 128, 144, 152, 192, 384, 512)

# Colors (Material Blue #1976D2 = RGB(25, 118, 210))
$backgroundColor = [System.Drawing.Color]::FromArgb(25, 118, 210)
$textColor = [System.Drawing.Color]::White

# Get directories
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$iconsDir = Join-Path $scriptDir "icons"

Write-Host "Generating PWA icons for Dual Reader 3.1..." -ForegroundColor Cyan
Write-Host "Output directory: $iconsDir" -ForegroundColor Gray
Write-Host ""

# Ensure icons directory exists
if (-not (Test-Path $iconsDir)) {
    New-Item -ItemType Directory -Path $iconsDir -Force | Out-Null
}

# Load System.Drawing assembly
Add-Type -AssemblyName System.Drawing

# Function to create an icon
function Create-Icon {
    param(
        [int]$Size,
        [string]$OutputPath
    )
    
    try {
        # Create bitmap
        $bitmap = New-Object System.Drawing.Bitmap($Size, $Size)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAlias
        
        # Fill background
        $bgBrush = New-Object System.Drawing.SolidBrush($backgroundColor)
        $graphics.FillRectangle($bgBrush, 0, 0, $Size, $Size)
        
        # Draw text "DR"
        $fontSize = [math]::Max(8, [int]($Size * 0.35))
        $font = New-Object System.Drawing.Font("Arial", $fontSize, [System.Drawing.FontStyle]::Bold)
        $textBrush = New-Object System.Drawing.SolidBrush($textColor)
        
        $text = "DR"
        $textSize = $graphics.MeasureString($text, $font)
        $x = ($Size - $textSize.Width) / 2
        $y = ($Size - $textSize.Height) / 2
        
        $graphics.DrawString($text, $font, $textBrush, $x, $y)
        
        # Save as PNG
        $bitmap.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
        
        # Cleanup
        $graphics.Dispose()
        $bitmap.Dispose()
        
        Write-Host "  ✓ Created: icon-$($Size)x$($Size).png" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "  ✗ Failed to create icon-$($Size)x$($Size).png: $_" -ForegroundColor Red
        return $false
    }
}

# Generate all icon sizes
$successCount = 0
foreach ($size in $iconSizes) {
    $outputPath = Join-Path $iconsDir "icon-${size}x${size}.png"
    if (Create-Icon -Size $size -OutputPath $outputPath) {
        $successCount++
    }
}

# Create favicon.png in web root
$faviconPath = Join-Path $scriptDir "favicon.png"
if (Create-Icon -Size 32 -OutputPath $faviconPath) {
    $successCount++
}

Write-Host ""
if ($successCount -eq ($iconSizes.Count + 1)) {
    Write-Host "✓ All icons created successfully! ($successCount files)" -ForegroundColor Green
} else {
    Write-Host "⚠ Some icons failed to create ($successCount / $($iconSizes.Count + 1))" -ForegroundColor Yellow
}
Write-Host ""
Write-Host "Note: These are placeholder icons. Replace with your final designs for production." -ForegroundColor Yellow
Write-Host ""
