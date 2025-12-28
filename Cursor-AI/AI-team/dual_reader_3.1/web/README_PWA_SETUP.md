# PWA Setup Guide - Dual Reader 3.1

## Quick Setup

### Step 1: Generate Icons

Choose one of these methods:

**PowerShell (Recommended for Windows):**
```powershell
cd web
.\generate_pwa_icons.ps1
```

**Browser (Cross-platform):**
1. Open `web/icons/generate_icons_simple.html` in your browser
2. Click "Download All Icons"
3. Place all downloaded PNG files in `web/icons/` directory

**Python:**
```bash
cd web/icons
python create_placeholder_icons.py
```

### Step 2: Build Web App

```bash
flutter build web --release
```

### Step 3: Verify Configuration

```bash
dart run web/verify_pwa_config.dart
```

### Step 4: Test Locally

```bash
# Serve with HTTP (for basic testing)
cd build/web
python -m http.server 8080

# Or use Flutter's dev server (for development)
flutter run -d chrome --web-port=8080
```

**Note**: For full PWA testing (including install prompt), you need HTTPS. Use a local HTTPS server or deploy to a hosting platform.

## Configuration Files

All PWA configuration files are already set up:

- ✅ `web/manifest.json` - PWA manifest with app metadata
- ✅ `web/index.html` - HTML with responsive meta tags and PWA setup
- ✅ `web/service-worker.js` - Custom service worker (Flutter auto-generates its own)
- ✅ `web/_headers` - Netlify deployment headers
- ✅ `web/.htaccess` - Apache server configuration
- ✅ `web/vercel.json` - Vercel deployment configuration
- ✅ `web/browserconfig.xml` - Windows tile configuration

## What's Configured

### ✅ PWA Manifest
- App name, short name, description
- Icons (all sizes from 16x16 to 512x512)
- Standalone display mode
- Theme colors
- App shortcuts
- Share target for EPUB/MOBI files
- Protocol handlers

### ✅ Responsive Meta Tags
- Viewport configuration
- Mobile optimization
- iOS-specific tags
- Android/Chrome tags
- Windows/Edge tags
- Theme colors

### ✅ Service Worker
- Flutter automatically generates `flutter_service_worker.js` during build
- Offline support configured
- Caching strategies implemented

### ✅ PWA Installability
- Install prompt handling
- Standalone mode support
- App shortcuts configured

## Testing PWA Features

### 1. Check Manifest
Open Chrome DevTools → Application → Manifest
- Verify all fields are present
- Check icons are loading
- Ensure no errors

### 2. Test Installation
- Look for install button in address bar
- Click install
- Verify app opens in standalone mode
- Test app shortcuts

### 3. Test Offline
- Open app
- Go offline (disable network)
- Verify app still works
- Check cached resources in DevTools → Application → Cache Storage

## Deployment

### Netlify
```bash
flutter build web --release
# Deploy build/web directory
```

### Vercel
```bash
flutter build web --release
# Vercel will auto-detect configuration from vercel.json
```

### GitHub Pages
```bash
flutter build web --release --base-href /your-repo-name/
# Copy build/web/* to docs/ or gh-pages branch
```

## Troubleshooting

**Icons not showing?**
- Generate icons using one of the methods above
- Verify icons are in `web/icons/` directory
- Check paths in `manifest.json` match actual files

**PWA not installable?**
- Must be served over HTTPS (required for PWA)
- Check manifest.json is valid in Chrome DevTools
- Verify service worker is registered
- Check browser console for errors

**Service worker issues?**
- Flutter auto-generates `flutter_service_worker.js` during build
- Verify `build/web/flutter_service_worker.js` exists after build
- Clear browser cache and reload

## Next Steps

1. Generate icons (if not done already)
2. Build web app: `flutter build web --release`
3. Test locally or deploy to hosting platform
4. Test PWA installation on various devices
5. Replace placeholder icons with final designs

## Resources

- [PWA Documentation](https://web.dev/progressive-web-apps/)
- [Flutter Web Deployment](https://docs.flutter.dev/deployment/web)
- [Web App Manifest](https://developer.mozilla.org/en-US/docs/Web/Manifest)

---

**Status**: ✅ Configuration Complete
**Version**: Dual Reader 3.1
