# Web Platform Settings Guide - Dual Reader 3.1

This guide documents the complete web platform configuration for Dual Reader 3.1, including PWA setup, service worker configuration, and deployment options.

## Overview

The web platform settings ensure that Dual Reader 3.1:
- ✅ Works as a Progressive Web App (PWA)
- ✅ Can be installed on devices
- ✅ Works offline with service worker caching
- ✅ Has responsive design for all screen sizes
- ✅ Is optimized for deployment on various hosting platforms

## Configuration Files

### 1. PWA Manifest (`web/manifest.json`)

The manifest file defines how the app appears when installed as a PWA.

**Key Features:**
- App name, short name, and description
- Icons for various screen sizes (16x16 to 512x512)
- Display mode: `standalone` (appears as native app)
- Theme colors: Dark background (#121212) and blue accent (#1976D2)
- App shortcuts for quick access
- Share target for EPUB/MOBI file sharing
- Protocol handlers for `web+epub://` links

**Required Icons:**
- 16x16, 32x32, 72x72, 96x96, 128x128, 144x144, 152x152, 192x192, 384x384, 512x512
- Maskable icons (192x192 and 512x512)

**Verification:**
```bash
# Check manifest.json exists and is valid
cat web/manifest.json | jq .
```

### 2. Service Worker (`web/service-worker.js`)

**Note:** Flutter automatically generates `flutter_service_worker.js` during build. The custom `service-worker.js` is provided as a reference implementation.

**Flutter's Service Worker:**
- Automatically generated during `flutter build web`
- Handles caching of Flutter assets
- Provides offline support
- Manages service worker updates

**Custom Service Worker:**
- Located at `web/service-worker.js`
- Provides additional caching strategies
- Can be used for custom offline functionality
- Not automatically registered (Flutter's service worker takes precedence)

**Verification:**
```bash
# After building, check service worker exists
ls build/web/flutter_service_worker.js
```

### 3. HTML Entry Point (`web/index.html`)

The main HTML file includes:

**Essential Meta Tags:**
- Viewport configuration for responsive design
- Theme color for browser UI
- Apple mobile web app meta tags
- Microsoft tile configuration
- Open Graph and Twitter Card meta tags

**PWA Features:**
- Manifest link: `<link rel="manifest" href="manifest.json">`
- Service worker registration (handled by Flutter)
- Install prompt handling
- Standalone mode detection

**Responsive Design:**
- Viewport meta tag with proper scaling
- Mobile-optimized settings
- Orientation support (portrait/landscape)
- Full-screen support

**Verification:**
```bash
# Check index.html includes manifest link
grep -i "manifest" web/index.html
```

### 4. Browser Configuration (`web/browserconfig.xml`)

Configures Windows tile appearance when pinned to Start menu.

**Features:**
- Tile icons (70x70, 150x150, 310x310)
- Tile color
- Notification settings

### 5. Deployment Configurations

#### Netlify (`web/_headers`)

Headers configuration for Netlify deployment:
- Service worker cache control
- Security headers
- Static asset caching
- SPA routing support

#### Vercel (`web/vercel.json`)

Configuration for Vercel deployment:
- Build command: `flutter build web --release`
- Output directory: `build/web`
- Headers for service worker and manifest
- SPA routing rewrites

#### Apache (`web/.htaccess`)

Apache server configuration:
- MIME types for PWA files
- Caching strategies
- Security headers
- Compression
- SPA routing

## Building the Web App

### Development Build

```bash
# Run in development mode
flutter run -d chrome

# Or build for development
flutter build web
```

### Production Build

```bash
# Build for production (optimized)
flutter build web --release

# Build output will be in build/web/
```

**Build Output:**
```
build/web/
├── index.html
├── manifest.json
├── flutter_service_worker.js (auto-generated)
├── main.dart.js
├── assets/
└── icons/
```

### Build Verification

After building, verify the following:

1. **Service Worker:**
   ```bash
   ls build/web/flutter_service_worker.js
   ```

2. **Manifest:**
   ```bash
   ls build/web/manifest.json
   ```

3. **Icons:**
   ```bash
   ls build/web/icons/*.png
   ```

4. **Run Verification Script:**
   ```bash
   dart run web/verify_web_platform_settings_complete.dart
   ```

## Testing PWA Features

### Local Testing

1. **Build the app:**
   ```bash
   flutter build web --release
   ```

2. **Serve locally:**
   ```bash
   # Using Python
   cd build/web
   python -m http.server 8000
   
   # Or using Node.js
   npx http-server build/web -p 8000
   ```

3. **Test in browser:**
   - Open `http://localhost:8000`
   - Open DevTools → Application → Manifest (verify manifest loads)
   - Check Service Workers (verify service worker registers)
   - Test Install Prompt (should appear in address bar or via custom banner)

### PWA Checklist

- [ ] Manifest loads without errors
- [ ] Service worker registers successfully
- [ ] App can be installed (install prompt appears)
- [ ] App works offline (service worker caches assets)
- [ ] Icons display correctly when installed
- [ ] App opens in standalone mode when installed
- [ ] Responsive design works on mobile/tablet/desktop

## Deployment

### GitHub Pages

1. **Build the app:**
   ```bash
   flutter build web --release --base-href "/dual_reader_3.1/"
   ```

2. **Deploy:**
   ```bash
   # Copy build/web/* to gh-pages branch
   git checkout gh-pages
   cp -r build/web/* .
   git add .
   git commit -m "Deploy web app"
   git push
   ```

### Netlify

1. **Build command:**
   ```
   flutter build web --release
   ```

2. **Publish directory:**
   ```
   build/web
   ```

3. **Headers:** Netlify will use `web/_headers` automatically

### Vercel

1. **Build command:**
   ```
   flutter build web --release
   ```

2. **Output directory:**
   ```
   build/web
   ```

3. **Configuration:** Vercel will use `web/vercel.json` automatically

### Firebase Hosting

1. **Install Firebase CLI:**
   ```bash
   npm install -g firebase-tools
   ```

2. **Initialize Firebase:**
   ```bash
   firebase init hosting
   ```

3. **Configure `firebase.json`:**
   ```json
   {
     "hosting": {
       "public": "build/web",
       "ignore": ["firebase.json", "**/.*", "**/node_modules/**"],
       "rewrites": [
         {
           "source": "**",
           "destination": "/index.html"
         }
       ],
       "headers": [
         {
           "source": "/flutter_service_worker.js",
           "headers": [
             {
               "key": "Cache-Control",
               "value": "no-cache, no-store, must-revalidate"
             },
             {
               "key": "Service-Worker-Allowed",
               "value": "/"
             }
           ]
         },
         {
           "source": "/manifest.json",
           "headers": [
             {
               "key": "Cache-Control",
               "value": "no-cache, no-store, must-revalidate"
             }
           ]
         }
       ]
     }
   }
   ```

4. **Deploy:**
   ```bash
   flutter build web --release
   firebase deploy --only hosting
   ```

## PWA Service Integration

The app includes a PWA service (`lib/services/pwa_service.dart`) that provides:

- **Install Prompt:** Detect and show PWA install prompt
- **Standalone Detection:** Check if app is running as installed PWA
- **Service Worker Updates:** Check for and handle service worker updates
- **Install Events:** Listen for PWA installation events

**Usage in Flutter:**
```dart
final pwaService = PwaService();

// Check if installable
if (pwaService.canInstall) {
  await pwaService.showInstallPrompt();
}

// Check if running as PWA
if (pwaService.isStandalone) {
  // App is installed
}
```

## Troubleshooting

### Service Worker Not Registering

1. **Check HTTPS:** Service workers require HTTPS (or localhost)
2. **Check Build:** Ensure `flutter build web --release` completed successfully
3. **Check Browser Console:** Look for service worker errors
4. **Clear Cache:** Clear browser cache and reload

### Install Prompt Not Appearing

1. **Check Manifest:** Verify `manifest.json` is valid and accessible
2. **Check Icons:** Ensure all required icons exist
3. **Check HTTPS:** PWA install requires HTTPS (or localhost)
4. **Check Criteria:** App must meet PWA installability criteria:
   - Valid manifest
   - Service worker registered
   - Served over HTTPS
   - Icons present

### Icons Not Displaying

1. **Check Paths:** Verify icon paths in `manifest.json` are correct
2. **Check Files:** Ensure icon files exist in `web/icons/`
3. **Generate Icons:** Use `web/icons/generate_icons.html` to create icons
4. **Check Sizes:** Verify all required sizes are present

### Offline Not Working

1. **Check Service Worker:** Verify service worker is registered
2. **Check Cache:** Check Application → Cache Storage in DevTools
3. **Check Network:** Verify service worker intercepts network requests
4. **Test Offline:** Use DevTools → Network → Offline mode

## Best Practices

1. **Always build with `--release` flag** for production
2. **Test on multiple browsers** (Chrome, Firefox, Safari, Edge)
3. **Test on mobile devices** (iOS Safari, Chrome Android)
4. **Verify HTTPS** before deploying (required for PWA)
5. **Monitor service worker updates** and handle them gracefully
6. **Test offline functionality** thoroughly
7. **Optimize icons** (use appropriate sizes, compress images)
8. **Set proper cache headers** for service worker and manifest

## Resources

- [PWA Documentation](https://web.dev/progressive-web-apps/)
- [Flutter Web Documentation](https://docs.flutter.dev/platform-integration/web)
- [Web App Manifest](https://web.dev/add-manifest/)
- [Service Worker API](https://developer.mozilla.org/en-US/docs/Web/API/Service_Worker_API)

## Support

For issues or questions:
1. Check this guide first
2. Run verification script: `dart run web/verify_web_platform_settings_complete.dart`
3. Check browser console for errors
4. Review Flutter web documentation

---

**Last Updated:** 2024
**Version:** 3.1.0
