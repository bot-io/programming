# Icon Generator for Dual Reader 3.1 using .NET
# This script generates placeholder PWA icons using .NET System.Drawing
# Works on Windows without requiring ImageMagick or PIL

$ErrorActionPreference = "Stop"

$IconsDir = Join-Path $PSScriptRoot "icons"
$Sizes = @(16, 32, 72, 96, 128, 144, 152, 192, 384, 512)

# Create icons directory if it doesn't exist
if (-not (Test-Path $IconsDir)) {
    New-Item -ItemType Directory -Path $IconsDir -Force | Out-Null
    Write-Host "Created icons directory: $IconsDir" -ForegroundColor Green
}

Write-Host "Generating PWA icons for Dual Reader 3.1..." -ForegroundColor Cyan
Write-Host ""

# Load System.Drawing assembly
try {
    Add-Type -AssemblyName System.Drawing
    $UseDotNet = $true
} catch {
    Write-Host "System.Drawing not available. Creating HTML-based generator..." -ForegroundColor Yellow
    $UseDotNet = $false
}

if ($UseDotNet) {
    # Generate icons using .NET System.Drawing
    foreach ($Size in $Sizes) {
        $OutputPath = Join-Path $IconsDir "icon-${Size}x${Size}.png"
        
        try {
            # Create bitmap
            $bitmap = New-Object System.Drawing.Bitmap($Size, $Size)
            $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
            
            # Set high quality rendering
            $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
            $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAlias
            
            # Fill background
            $bgBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(25, 118, 210))
            $graphics.FillRectangle($bgBrush, 0, 0, $Size, $Size)
            
            # Draw text
            $fontSize = [Math]::Max(12, [Math]::Floor($Size * 0.4))
            $font = New-Object System.Drawing.Font("Arial", $fontSize, [System.Drawing.FontStyle]::Bold)
            $textBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
            
            # Measure text
            $text = "DR"
            $textSize = $graphics.MeasureString($text, $font)
            $x = ($Size - $textSize.Width) / 2
            $y = ($Size - $textSize.Height) / 2
            
            # Draw text
            $graphics.DrawString($text, $font, $textBrush, $x, $y)
            
            # Save
            $bitmap.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
            
            # Cleanup
            $graphics.Dispose()
            $bitmap.Dispose()
            $bgBrush.Dispose()
            $textBrush.Dispose()
            $font.Dispose()
            
            Write-Host "  ✓ Generated icon-${Size}x${Size}.png" -ForegroundColor Green
        } catch {
            Write-Host "  ✗ Failed to generate icon-${Size}x${Size}.png: $_" -ForegroundColor Red
        }
    }
    
    # Create favicon.png in web root
    try {
        $faviconPath = Join-Path $PSScriptRoot "favicon.png"
        $bitmap = New-Object System.Drawing.Bitmap(32, 32)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        
        $bgBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(25, 118, 210))
        $graphics.FillRectangle($bgBrush, 0, 0, 32, 32)
        
        $font = New-Object System.Drawing.Font("Arial", 12, [System.Drawing.FontStyle]::Bold)
        $textBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
        $textSize = $graphics.MeasureString("DR", $font)
        $x = (32 - $textSize.Width) / 2
        $y = (32 - $textSize.Height) / 2
        $graphics.DrawString("DR", $font, $textBrush, $x, $y)
        
        $bitmap.Save($faviconPath, [System.Drawing.Imaging.ImageFormat]::Png)
        
        $graphics.Dispose()
        $bitmap.Dispose()
        $bgBrush.Dispose()
        $textBrush.Dispose()
        $font.Dispose()
        
        Write-Host "  ✓ Generated favicon.png" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ Failed to generate favicon.png: $_" -ForegroundColor Red
    }
} else {
    # Fallback: Create HTML generator
    $HtmlContent = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Icon Generator - Dual Reader</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 900px;
            margin: 20px auto;
            padding: 20px;
            background: #121212;
            color: #fff;
        }
        .container {
            background: #1e1e1e;
            padding: 30px;
            border-radius: 8px;
        }
        button {
            background: #1976D2;
            color: white;
            border: none;
            padding: 12px 24px;
            font-size: 16px;
            border-radius: 4px;
            cursor: pointer;
            margin: 10px 5px;
        }
        button:hover {
            background: #1565C0;
        }
        .icon-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(150px, 1fr));
            gap: 20px;
            margin-top: 20px;
        }
        .icon-item {
            text-align: center;
            padding: 10px;
            background: #2a2a2a;
            border-radius: 4px;
        }
        canvas {
            border: 1px solid #444;
            margin: 5px auto;
            display: block;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Dual Reader 3.1 - Icon Generator</h1>
        <p>Click the button below to generate all required PWA icons. Then right-click each icon and save it to the <code>web/icons/</code> directory.</p>
        <button onclick="generateAllIcons()">Generate All Icons</button>
        <button onclick="downloadAllIcons()">Download All Icons</button>
        <div id="icons" class="icon-grid"></div>
    </div>

    <script>
        const sizes = [16, 32, 72, 96, 128, 144, 152, 192, 384, 512];
        
        function generateIcon(size) {
            const canvas = document.createElement('canvas');
            canvas.width = size;
            canvas.height = size;
            const ctx = canvas.getContext('2d');
            
            // Background
            ctx.fillStyle = '#1976D2';
            ctx.fillRect(0, 0, size, size);
            
            // Text
            ctx.fillStyle = '#FFFFFF';
            ctx.font = `bold ${Math.floor(size * 0.4)}px Arial`;
            ctx.textAlign = 'center';
            ctx.textBaseline = 'middle';
            ctx.fillText('DR', size / 2, size / 2);
            
            return canvas;
        }
        
        function generateAllIcons() {
            const container = document.getElementById('icons');
            container.innerHTML = '';
            
            sizes.forEach(size => {
                const canvas = generateIcon(size);
                const div = document.createElement('div');
                div.className = 'icon-item';
                
                const label = document.createElement('div');
                label.textContent = `icon-${size}x${size}.png`;
                label.style.marginBottom = '5px';
                label.style.fontWeight = 'bold';
                
                const downloadBtn = document.createElement('button');
                downloadBtn.textContent = 'Download';
                downloadBtn.style.fontSize = '12px';
                downloadBtn.style.padding = '6px 12px';
                downloadBtn.onclick = () => {
                    canvas.toBlob(blob => {
                        const url = URL.createObjectURL(blob);
                        const a = document.createElement('a');
                        a.href = url;
                        a.download = `icon-${size}x${size}.png`;
                        a.click();
                        URL.revokeObjectURL(url);
                    });
                };
                
                div.appendChild(label);
                div.appendChild(canvas);
                div.appendChild(document.createElement('br'));
                div.appendChild(downloadBtn);
                container.appendChild(div);
            });
        }
        
        function downloadAllIcons() {
            sizes.forEach((size, index) => {
                setTimeout(() => {
                    const canvas = generateIcon(size);
                    canvas.toBlob(blob => {
                        const url = URL.createObjectURL(blob);
                        const a = document.createElement('a');
                        a.href = url;
                        a.download = `icon-${size}x${size}.png`;
                        a.click();
                        URL.revokeObjectURL(url);
                    });
                }, index * 200);
            });
        }
        
        // Auto-generate on load
        window.addEventListener('load', generateAllIcons);
    </script>
</body>
</html>
"@
    
    $HtmlPath = Join-Path $IconsDir "generate_icons_browser.html"
    $HtmlContent | Out-File -FilePath $HtmlPath -Encoding UTF8
    Write-Host "  ✓ Created HTML icon generator: generate_icons_browser.html" -ForegroundColor Green
    Write-Host ""
    Write-Host "To generate icons:" -ForegroundColor Cyan
    Write-Host "  1. Open $HtmlPath in your browser" -ForegroundColor White
    Write-Host "  2. Click 'Generate All Icons' or 'Download All Icons'" -ForegroundColor White
    Write-Host "  3. Save icons to the icons/ directory" -ForegroundColor White
}

Write-Host ""
Write-Host "Icon generation complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Note: These are placeholder icons. Replace them with your final" -ForegroundColor Yellow
Write-Host "      icon designs for production use." -ForegroundColor Yellow
