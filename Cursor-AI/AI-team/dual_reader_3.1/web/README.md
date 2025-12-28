# Dual Reader 3.1 - Web Platform Configuration

This directory contains all web-specific configuration files for the Dual Reader 3.1 PWA.

## Quick Start

1. **Generate Icons** (Required for PWA):
   ```powershell
   # Windows
   .\generate_icons.ps1
   
   # Or open in browser
   # Open icons/create_icons_browser.html in your browser
   ```

2. **Verify Setup**:
   ```powershell
   .\verify_pwa_setup.ps1
   ```

3. **Build Web App**:
   ```bash
   flutter build web
   ```

4. **Test Locally**:
   ```bash
   cd build/web
   python -m http.server 8000
   # Open http://localhost:8000
   ```

## Files Overview

### Core Files
- **`index.html`** - Main HTML file with meta tags, service worker registration, and PWA install handling
- **`manifest.json`** - PWA manifest with app metadata, icons, and shortcuts
- **`service-worker.js`** - Service worker for offline support and caching
- **`browserconfig.xml`** - Windows tile configuration

### Icon Generation
- **`generate_icons.ps1`** - PowerShell script to generate all required icons (Windows)
- **`icons/create_icons_browser.html`** - Browser-based icon generator (cross-platform)
- **`icons/create_placeholder_icons.py`** - Python script to generate icons (requires Pillow)

### Verification
- **`verify_pwa_setup.ps1`** - Script to verify all PWA configuration is correct

## Icon Requirements

For PWA installability, you need these icons in `icons/`:
- 16x16, 32x32, 72x72, 96x96, 128x128, 144x144, 152x152, 192x192, 384x384, 512x512

And `favicon.png` in the web root.

## Features

### PWA Support
- ✅ Installable as Progressive Web App
- ✅ Offline functionality via service worker
- ✅ App shortcuts (Library, Continue Reading)
- ✅ Share target for EPUB/MOBI files
- ✅ Protocol handlers for web+epub links

### Responsive Design
- ✅ Viewport meta tags configured
- ✅ Responsive breakpoints
- ✅ Touch-friendly interface
- ✅ Mobile, tablet, and desktop support

### Performance
- ✅ Service worker caching strategies
- ✅ Preload critical resources
- ✅ Optimized asset loading
- ✅ Offline fallback page

## Browser Support

- Chrome/Edge (latest) - Full PWA support
- Firefox (latest) - Full PWA support  
- Safari (latest) - PWA support (iOS 11.3+)
- Opera (latest) - Full PWA support

## Deployment

1. Build: `flutter build web --release`
2. Deploy `build/web/` to hosting service
3. Ensure HTTPS is enabled (required for PWA)
4. Test PWA installability

See `SETUP_COMPLETE.md` for detailed setup and deployment instructions.
