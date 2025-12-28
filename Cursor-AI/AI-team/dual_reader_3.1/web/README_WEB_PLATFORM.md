# Web Platform Configuration - Dual Reader 3.1

This document describes the web platform configuration for Dual Reader 3.1, including PWA setup, service worker configuration, and deployment instructions.

## Overview

The web platform is fully configured as a Progressive Web App (PWA) with:
- ✅ PWA manifest.json with complete app metadata
- ✅ Service worker for offline support (Flutter auto-generates `flutter_service_worker.js`)
- ✅ Responsive meta tags for optimal mobile/desktop experience
- ✅ PWA install prompt integration
- ✅ Offline functionality

## Files Structure

```
web/
├── index.html              # Main HTML file with meta tags and PWA setup
├── manifest.json           # PWA manifest with app metadata and icons
├── service-worker.js       # Custom service worker (optional, Flutter uses its own)
├── browserconfig.xml       # Windows tile configuration
├── flutter_build_config.json  # Build configuration reference
└── icons/                  # App icons in various sizes
```

## PWA Manifest

The `manifest.json` file includes:
- App name and description
- Icons in multiple sizes (16x16 to 512x512)
- Display mode: standalone
- Theme colors
- Shortcuts for quick actions
- Share target for file sharing
- Protocol handlers for EPUB files

## Service Worker

Flutter automatically generates and registers `flutter_service_worker.js` during build. This service worker:
- Caches app assets for offline access
- Enables offline functionality
- Handles updates automatically

The custom `service-worker.js` file is provided as a reference but Flutter's service worker takes precedence.

## Responsive Meta Tags

The `index.html` includes comprehensive meta tags for:
- Mobile optimization
- iOS Safari (apple-mobile-web-app-*)
- Android Chrome
- Windows tiles
- PWA installability
- SEO and social sharing

## Building for Web

### Development
```bash
flutter run -d chrome
```

### Production Build
```bash
flutter build web --release
```

The build output will be in `build/web/` directory.

### Build Options
```bash
# With base href for subdirectory deployment
flutter build web --release --base-href /dual-reader/

# With custom renderer
flutter build web --release --web-renderer canvaskit
```

## Deployment

### Requirements
- HTTPS enabled (required for PWA)
- Service worker support
- Proper MIME types for .js, .wasm, .json files

### GitHub Pages
1. Build the app: `flutter build web --release`
2. Copy `build/web/*` to your repository's `docs/` folder or `gh-pages` branch
3. Enable GitHub Pages in repository settings

### Netlify
1. Build the app: `flutter build web --release`
2. Deploy `build/web/` folder
3. Add `_redirects` file with: `/* /index.html 200`

### Vercel
1. Build the app: `flutter build web --release`
2. Deploy `build/web/` folder
3. Vercel automatically handles routing

### Firebase Hosting
1. Build the app: `flutter build web --release`
2. Initialize Firebase: `firebase init hosting`
3. Set public directory to `build/web`
4. Deploy: `firebase deploy --only hosting`

## PWA Installation

Users can install the app:
1. **Chrome/Edge**: Click the install icon in the address bar
2. **Mobile**: "Add to Home Screen" option in browser menu
3. **Programmatic**: Use the install banner widget in the app

## Testing PWA Features

### Chrome DevTools
1. Open DevTools (F12)
2. Go to "Application" tab
3. Check "Manifest" section
4. Check "Service Workers" section
5. Test "Offline" mode

### Lighthouse
Run Lighthouse audit:
1. Open Chrome DevTools
2. Go to "Lighthouse" tab
3. Select "Progressive Web App"
4. Run audit

Expected scores:
- PWA: 90+
- Performance: 80+
- Accessibility: 90+
- Best Practices: 90+
- SEO: 90+

## Troubleshooting

### Service Worker Not Registering
- Ensure HTTPS is enabled (or use localhost)
- Check browser console for errors
- Verify `flutter_service_worker.js` exists in build output

### Manifest Not Loading
- Verify `manifest.json` is accessible
- Check for JSON syntax errors
- Ensure proper MIME type (application/manifest+json)

### Icons Not Showing
- Verify icon files exist in `web/icons/` directory
- Check icon paths in manifest.json
- Ensure icons are in PNG format

### Install Prompt Not Showing
- App must meet PWA criteria (manifest, service worker, HTTPS)
- User must visit site multiple times
- Check browser console for install prompt events

## Additional Resources

- [Flutter Web Documentation](https://docs.flutter.dev/platform-integration/web)
- [PWA Documentation](https://web.dev/progressive-web-apps/)
- [Web App Manifest](https://web.dev/add-manifest/)
- [Service Workers](https://web.dev/service-worker-caching-and-http-caching/)
