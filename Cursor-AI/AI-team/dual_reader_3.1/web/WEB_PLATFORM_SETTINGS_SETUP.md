# Web Platform Settings - Setup Guide

This guide explains how to set up and verify the web platform settings for Dual Reader 3.1, including PWA support, responsive design, and optimal web deployment.

## Overview

The web platform settings include:
- ✅ PWA manifest.json with app metadata
- ✅ Service worker configuration for offline support
- ✅ Responsive meta tags for optimal mobile/desktop experience
- ✅ PWA icons for installability
- ✅ Deployment configurations (Vercel, Netlify)

## Quick Start

### 1. Install Dependencies

```bash
flutter pub get
```

### 2. Generate PWA Icons

Generate placeholder icons (required for PWA installability):

```bash
# Using Dart (recommended)
dart run web/icons/create_placeholder_icons.dart

# OR using PowerShell (Windows)
powershell web/icons/create_placeholder_icons.ps1

# OR using Python (requires Pillow)
python web/icons/create_placeholder_icons.py
```

This creates all required icon sizes in `web/icons/` and `web/favicon.png`.

### 3. Verify Configuration

Run the verification script to check all settings:

```bash
dart run web/verify_web_platform_settings.dart
```

### 4. Build Web App

```bash
flutter build web --release
```

This generates:
- `build/web/flutter_service_worker.js` - Auto-generated service worker
- `build/web/manifest.json` - PWA manifest
- `build/web/index.html` - Main HTML file
- `build/web/icons/` - Icon files

### 5. Test Locally

```bash
flutter run -d chrome --web-port=8080
```

Or serve the build output:

```bash
cd build/web
python -m http.server 8080
# OR
npx serve .
```

Then open `http://localhost:8080` in your browser.

## Configuration Files

### Core Files

1. **`web/manifest.json`** - PWA manifest with app metadata
   - App name, description, icons
   - Display mode, theme colors
   - Start URL, scope
   - Shortcuts, share target

2. **`web/index.html`** - Main HTML file
   - Responsive meta tags
   - PWA manifest link
   - Service worker registration
   - Flutter initialization

3. **`web/flutter_build_config.json`** - Flutter build configuration
   - PWA settings
   - CanvasKit configuration
   - Build options

4. **`web/service-worker.js`** - Reference service worker
   - Note: Flutter auto-generates `flutter_service_worker.js` during build
   - This file is for reference only

### Deployment Files

- **`web/vercel.json`** - Vercel deployment configuration
- **`web/_headers`** - Netlify headers configuration
- **`web/robots.txt`** - Search engine crawler configuration

## PWA Features

### Installability

The app is installable as a PWA when:
- ✅ HTTPS is enabled (required for service workers)
- ✅ manifest.json is valid and accessible
- ✅ Service worker is registered
- ✅ Icons are present (at least 192x192 and 512x512)

### Offline Support

Flutter's auto-generated service worker provides:
- Automatic caching of Flutter assets
- Offline functionality for the app shell
- Version management and updates

### Responsive Design

Meta tags ensure:
- Proper viewport scaling on mobile devices
- Touch-friendly interface
- Support for both portrait and landscape orientations
- Optimal display on tablets and desktops

## Icon Requirements

Required icon sizes for full PWA support:
- 16x16, 32x32 - Favicons
- 72x72, 96x96, 128x128 - Android/Chrome
- 144x144 - Windows tiles
- 152x152 - iOS
- 192x192 - Android/Chrome (required, maskable)
- 384x384 - Android splash
- 512x512 - PWA (required, maskable)

All icons should be:
- PNG format with transparency
- Square aspect ratio
- Optimized for file size
- Designed with safe zones (10% padding) for maskable icons

## Deployment

### GitHub Pages

1. Build: `flutter build web --release --base-href "/your-repo-name/"`
2. Deploy `build/web/` to `gh-pages` branch
3. Enable GitHub Pages in repository settings

### Netlify

1. Connect repository
2. Build command: `flutter build web --release`
3. Publish directory: `build/web`
4. Headers are configured in `web/_headers`

### Vercel

1. Connect repository
2. Build command: `flutter build web --release`
3. Output directory: `build/web`
4. Configuration in `web/vercel.json`

### Firebase Hosting

1. Install Firebase CLI: `npm install -g firebase-tools`
2. Initialize: `firebase init hosting`
3. Build: `flutter build web --release`
4. Deploy: `firebase deploy --only hosting`

## Verification Checklist

- [ ] All icon sizes exist in `web/icons/`
- [ ] `web/favicon.png` exists
- [ ] `web/manifest.json` is valid JSON
- [ ] `web/index.html` includes manifest link
- [ ] `web/index.html` includes responsive meta tags
- [ ] `flutter build web --release` completes successfully
- [ ] `build/web/flutter_service_worker.js` exists after build
- [ ] App loads in browser without errors
- [ ] PWA install prompt appears (in supported browsers)
- [ ] App works offline (after first load)

## Troubleshooting

### Icons Not Found

If icons are missing:
1. Run icon generation script
2. Verify files exist in `web/icons/`
3. Check `manifest.json` icon paths are correct

### Service Worker Not Working

1. Ensure HTTPS is enabled (required for service workers)
2. Check browser console for errors
3. Verify `flutter_service_worker.js` exists in build output
4. Clear browser cache and reload

### PWA Not Installable

1. Verify HTTPS is enabled
2. Check manifest.json is valid
3. Ensure icons exist (especially 192x192 and 512x512)
4. Check browser DevTools > Application > Manifest

### Build Errors

1. Run `flutter clean`
2. Run `flutter pub get`
3. Run `flutter build web --release` again
4. Check Flutter version: `flutter --version`

## Additional Resources

- [Flutter Web Documentation](https://docs.flutter.dev/platform-integration/web)
- [PWA Manifest Guide](https://web.dev/add-manifest/)
- [Service Worker Guide](https://web.dev/service-worker-cache-storage/)
- [Web App Manifest](https://developer.mozilla.org/en-US/docs/Web/Manifest)

## Support

For issues or questions:
1. Check verification script output: `dart run web/verify_web_platform_settings.dart`
2. Review browser console for errors
3. Check Flutter web documentation
4. Review deployment provider documentation
