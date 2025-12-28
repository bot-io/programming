# Icon Generation Guide

## Overview

Dual Reader 3.1 requires PWA icons in multiple sizes for proper installation and display across different platforms. This guide explains how to generate the required icons.

## Required Icon Sizes

The following icon sizes are required for PWA functionality:

- **16x16** - Favicon (small browser tab icon)
- **32x32** - Favicon (standard browser tab icon)
- **72x72** - Android home screen (small)
- **96x96** - Android home screen
- **128x128** - Chrome Web Store
- **144x144** - Windows tiles
- **152x152** - iOS home screen (iPad)
- **192x192** - Android home screen (required, maskable)
- **384x384** - Windows tiles
- **512x512** - PWA splash screen (required, maskable)

## Icon Requirements

### Maskable Icons (192x192 and 512x512)

Maskable icons should follow the [Safe Zone guidelines](https://web.dev/maskable-icon/):
- Important content should be within the inner 80% of the icon (safe zone)
- Background can extend to the edges
- Icons will be cropped to various shapes (circle, rounded square, etc.)

### Design Guidelines

1. **Use a simple, recognizable design** that works at small sizes
2. **Ensure good contrast** for visibility on light and dark backgrounds
3. **Test at different sizes** to ensure readability
4. **Use consistent branding** across all sizes

## Generation Methods

### Method 1: Using Online Tools

1. **PWA Asset Generator** (Recommended)
   - Visit: https://www.pwabuilder.com/imageGenerator
   - Upload a 512x512 source image
   - Download generated icons
   - Place in `web/icons/` directory

2. **RealFaviconGenerator**
   - Visit: https://realfavicongenerator.net/
   - Upload source image
   - Configure settings
   - Download and extract to `web/icons/`

### Method 2: Using Scripts (Included)

Scripts are provided in `web/icons/` directory:

#### PowerShell (Windows)
```powershell
.\generate_icons.ps1 -SourceImage "path/to/source.png" -OutputDir "web/icons"
```

#### Python (Cross-platform)
```bash
python generate_icons.py --source "path/to/source.png" --output "web/icons"
```

#### Bash (Linux/Mac)
```bash
chmod +x generate_icons.sh
./generate_icons.sh path/to/source.png web/icons
```

### Method 3: Manual Generation

1. Create a source image at 512x512 pixels (PNG format, transparent background recommended)
2. Use image editing software (GIMP, Photoshop, Figma, etc.) to resize:
   - Export at each required size
   - Name files: `icon-{size}x{size}.png` (e.g., `icon-192x192.png`)
3. Place all icons in `web/icons/` directory

## Favicon Generation

In addition to the icons, you need a `favicon.png` file in the `web/` directory:

1. Create a 32x32 or 64x64 PNG image
2. Save as `web/favicon.png`
3. Optionally create additional favicon formats:
   - `favicon.ico` (multi-resolution ICO file)
   - `favicon-16x16.png`
   - `favicon-32x32.png`

## Verification

After generating icons, verify:

1. **All files exist** in `web/icons/`:
   ```bash
   ls web/icons/icon-*.png
   ```

2. **Favicon exists**:
   ```bash
   ls web/favicon.png
   ```

3. **Build and test**:
   ```bash
   flutter build web
   cd build/web
   python -m http.server 8000
   ```

4. **Check in browser DevTools**:
   - Application > Manifest > Icons should list all icons
   - No 404 errors for missing icons

## Quick Start

If you have a source image ready:

1. **Using PWA Builder** (easiest):
   - Go to https://www.pwabuilder.com/imageGenerator
   - Upload your 512x512 source image
   - Download the generated package
   - Extract icons to `web/icons/`
   - Extract favicon to `web/`

2. **Using included Python script**:
   ```bash
   cd web/icons
   python generate_icons.py --source "../../assets/images/app-icon.png" --output "."
   ```

## Notes

- Icons are referenced in `manifest.json` and `index.html`
- Missing icons will cause PWA installation to fail
- Icons should be optimized PNG files (use tools like TinyPNG)
- Keep file sizes small for faster loading
