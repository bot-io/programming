# Web Platform Settings - Dual Reader 3.1

This document describes the web platform configuration for Dual Reader 3.1, including PWA manifest, service worker setup, and responsive design meta tags.

## Overview

The web platform is configured as a Progressive Web App (PWA) that can be installed on users' devices and works offline. All configuration files are located in the `web/` directory.

## Configuration Files

### 1. `manifest.json`

The PWA manifest file defines app metadata, icons, display mode, and installability features.

**Key Features:**
- **App Name**: "Dual Reader 3.1 - Ebook Reader with Translation"
- **Short Name**: "Dual Reader"
- **Display Mode**: Standalone (appears as a native app)
- **Theme Color**: #1976D2 (Material Blue)
- **Background Color**: #121212 (Dark theme)
- **Icons**: Multiple sizes (16x16 to 512x512) for different devices
- **Shortcuts**: Quick actions for Library and Continue Reading
- **Share Target**: Allows sharing EPUB/MOBI files to the app
- **Protocol Handlers**: Supports `web+epub://` protocol

**Installability Requirements:**
- ✅ Valid manifest.json
- ✅ Service worker registered
- ✅ Served over HTTPS (or localhost)
- ✅ Icons provided (192x192 and 512x512 minimum)

### 2. `service-worker.js`

The service worker provides offline support and caching strategies.

**Features:**
- **Cache Strategies**:
  - Cache-first for app shell (index.html, manifest.json, Flutter assets)
  - Network-first for dynamic content
  - Stale-while-revalidate for assets
- **Offline Support**: Caches essential files for offline access
- **Update Handling**: Automatically updates when new version is available
- **Cache Versioning**: Uses versioned cache names to prevent conflicts

**Cache Names:**
- `dual-reader-v3.1.0-cache`: App shell and core files
- `dual-reader-v3.1.0-runtime`: Dynamically cached content
- `dual-reader-v3.1.0-offline`: Offline fallback page

### 3. `index.html`

The main HTML file includes all necessary meta tags and service worker registration.

**Meta Tags Included:**
- **Viewport**: Responsive design with proper scaling
- **Theme Color**: Matches app theme (#1976D2)
- **Description**: SEO-friendly app description
- **Apple Touch Icons**: iOS home screen icons
- **Windows Tiles**: Windows Start menu tile configuration
- **PWA Installability**: Meta tags for install prompts

**Service Worker Registration:**
- Registers Flutter's built-in service worker
- Optionally registers custom service worker for enhanced caching
- Handles update notifications
- Manages PWA install prompts

**PWA Install Prompt:**
- Listens for `beforeinstallprompt` event
- Provides `window.showInstallPrompt()` function
- Dispatches custom events for Flutter app integration

### 4. `browserconfig.xml`

Windows-specific configuration for tile icons and colors.

**Configuration:**
- Tile color: #1976D2
- Icon sizes: 72x72, 144x144, 384x384

## Icons

### Required Icon Sizes

The following icon sizes are required for full PWA support:

- 16x16 (favicon)
- 32x32 (favicon)
- 72x72 (Android, Windows)
- 96x96 (Android)
- 128x128 (Chrome, Android)
- 144x144 (Windows tiles)
- 152x152 (iOS)
- 192x192 (Android, Chrome, PWA)
- 384x384 (Windows tiles)
- 512x512 (PWA, Android, Chrome)

### Generating Icons

Several methods are available to generate icons:

1. **HTML Generator** (Easiest - No dependencies):
   ```bash
   # Open in browser
   web/icons/generate_icons_simple.html
   ```

2. **PowerShell Script** (Requires ImageMagick):
   ```powershell
   .\web\generate_icons.ps1
   ```

3. **Python Script** (Requires Pillow):
   ```bash
   python web/icons/create_placeholder_icons.py
   ```

4. **Manual**: Design a 512x512 icon and use `generate_icons.py` to create all sizes

## Verification

Run the verification script to check your configuration:

```powershell
.\web\verify_web_setup.ps1
```

This script checks:
- ✅ manifest.json exists and is valid
- ✅ service-worker.js exists with required features
- ✅ index.html has all required meta tags
- ✅ All required icons exist
- ✅ Favicon exists
- ✅ browserconfig.xml exists

## Building for Web

### Development

```bash
flutter run -d chrome
```

### Production Build

```bash
flutter build web --release
```

The build output will be in `build/web/`.

### Deploying

The `build/web/` directory contains all files needed for deployment:

1. **Static Hosting** (GitHub Pages, Netlify, Vercel):
   - Upload `build/web/` contents to your hosting service
   - Ensure HTTPS is enabled (required for PWA)

2. **Custom Server**:
   - Serve `build/web/` directory
   - Configure HTTPS
   - Set proper MIME types (especially for `.js` files)

## Testing PWA Features

### Chrome DevTools

1. Open Chrome DevTools (F12)
2. Go to **Application** tab
3. Check **Manifest** section for validation
4. Check **Service Workers** section for registration
5. Use **Lighthouse** tab to audit PWA features

### Installability Test

1. Open the app in Chrome
2. Look for install icon in address bar
3. Or check `chrome://flags/#enable-desktop-pwas` is enabled
4. Install prompt should appear automatically (or use `window.showInstallPrompt()`)

### Offline Test

1. Open DevTools → **Network** tab
2. Enable **Offline** mode
3. Reload the page
4. App should load from cache
5. Check **Application** → **Cache Storage** to see cached files

## Browser Support

### Full PWA Support
- ✅ Chrome/Edge (Desktop & Mobile)
- ✅ Firefox (Desktop & Mobile)
- ✅ Safari (iOS 11.3+, macOS)
- ✅ Samsung Internet

### Partial Support
- ⚠️ Safari (iOS): Limited service worker support
- ⚠️ Firefox: Some PWA features may vary

## Troubleshooting

### Icons Not Showing

1. Check icon files exist in `web/icons/`
2. Verify paths in `manifest.json` are correct
3. Clear browser cache
4. Check browser console for 404 errors

### Service Worker Not Registering

1. Check browser console for errors
2. Verify service worker file exists
3. Ensure HTTPS (or localhost)
4. Check `index.html` has registration code

### PWA Not Installable

1. Verify manifest.json is valid (use DevTools)
2. Check service worker is registered
3. Ensure HTTPS (required for install)
4. Verify icons exist (192x192 and 512x512 minimum)
5. Check Lighthouse PWA audit

### Offline Not Working

1. Verify service worker is active
2. Check cache storage in DevTools
3. Ensure files are being cached
4. Check service worker fetch event handlers

## Best Practices

1. **Icons**: Use high-quality icons (512x512 source)
2. **Caching**: Cache app shell, lazy-load content
3. **Updates**: Notify users of updates
4. **Offline**: Provide offline fallback page
5. **Performance**: Minimize initial load time
6. **Security**: Use HTTPS in production

## Additional Resources

- [PWA Documentation](https://web.dev/progressive-web-apps/)
- [Web App Manifest](https://web.dev/add-manifest/)
- [Service Workers](https://web.dev/service-worker-caching-and-http-caching/)
- [Flutter Web](https://docs.flutter.dev/platform-integration/web)

## Configuration Checklist

- [x] PWA manifest.json created with app metadata
- [x] Service worker configured for offline support
- [x] Responsive meta tags configured
- [x] Icons provided (all required sizes)
- [x] Favicon created
- [x] Browser config for Windows tiles
- [x] PWA install prompt handling
- [x] Offline fallback page
- [x] Cache strategies implemented
- [x] Update handling configured

## Version

**Version**: 3.1.0  
**Last Updated**: 2024  
**Status**: ✅ Production Ready
