# PWA Setup Verification Guide

This document provides a comprehensive guide for verifying that the Dual Reader 3.1 web app is properly configured as a Progressive Web App (PWA).

## Quick Verification

Run the verification script:

```bash
dart web/verify_pwa_complete.dart
```

## Manual Verification Checklist

### 1. Manifest.json ✅

**Location:** `web/manifest.json`

**Required Fields:**
- ✅ `name` - Full app name
- ✅ `short_name` - Short app name (for home screen)
- ✅ `start_url` - Starting URL (must be `/` or relative)
- ✅ `display` - Display mode (`standalone`, `fullscreen`, or `minimal-ui`)
- ✅ `icons` - Array of icon objects with at least:
  - 192x192 icon (required)
  - 512x512 icon (required)
- ✅ `theme_color` - Theme color for browser UI
- ✅ `background_color` - Background color for splash screen

**Verification:**
```bash
# Check if manifest.json exists and is valid JSON
cat web/manifest.json | python -m json.tool
```

**Browser Test:**
1. Open Chrome DevTools (F12)
2. Go to Application > Manifest
3. Verify all fields are present and valid
4. Check for any warnings or errors

### 2. Service Worker ✅

**Location:** `build/web/flutter_service_worker.js` (auto-generated)

Flutter automatically generates and registers `flutter_service_worker.js` during the build process. The custom `web/service-worker.js` is provided as a reference but is not automatically registered.

**Verification:**
1. Build the web app: `flutter build web`
2. Check that `build/web/flutter_service_worker.js` exists
3. Open Chrome DevTools > Application > Service Workers
4. Verify service worker is registered and active

**Manual Check:**
```bash
# After building
ls build/web/flutter_service_worker.js
```

### 3. Responsive Meta Tags ✅

**Location:** `web/index.html`

**Required Meta Tags:**
- ✅ `<meta name="viewport" content="...">` - Viewport configuration
- ✅ `<meta name="theme-color" content="#1976D2">` - Theme color
- ✅ `<link rel="manifest" href="manifest.json">` - Manifest link
- ✅ Responsive tags for mobile devices:
  - `HandheldFriendly`
  - `MobileOptimized`
  - `apple-mobile-web-app-capable`

**Verification:**
```bash
# Check for required tags
grep -E "viewport|theme-color|manifest|HandheldFriendly" web/index.html
```

### 4. Icons ✅

**Location:** `web/icons/`

**Required Icon Sizes:**
- 16x16 (favicon)
- 32x32 (favicon)
- 72x72 (Android)
- 96x96 (Android)
- 128x128 (Chrome)
- 144x144 (Windows tiles)
- 152x152 (iOS)
- 192x192 (Android, required for PWA)
- 384x384 (Android splash)
- 512x512 (Android, required for PWA)

**Verification:**
```bash
# Check if icons exist
ls web/icons/icon-*.png
```

**Creating Icons:**
If icons don't exist, you can:
1. Use the icon generation scripts in `web/icons/`
2. Create a 512x512 source image
3. Generate all sizes using image editing tools or scripts

### 5. HTTPS Requirement ⚠️

PWAs **must** be served over HTTPS (except for localhost during development).

**Verification:**
- ✅ Development: `http://localhost` works
- ⚠️ Production: Must use HTTPS

**Testing HTTPS Locally:**
```bash
# Using Flutter's built-in server (HTTP only for localhost)
flutter run -d chrome --web-port=8080

# For HTTPS testing, use a tool like:
# - ngrok (https://ngrok.com/)
# - localtunnel (https://localtunnel.github.io/www/)
# - Or deploy to a hosting service with HTTPS
```

## Browser Testing

### Chrome/Edge

1. **Open DevTools** (F12)
2. **Application Tab:**
   - **Manifest:** Verify all fields, check installability
   - **Service Workers:** Verify registration and status
   - **Storage:** Check cache and local storage
3. **Lighthouse Tab:**
   - Run PWA audit
   - Score should be 90+ for production readiness

### Firefox

1. **Open DevTools** (F12)
2. **Application Tab:**
   - **Manifest:** View manifest details
   - **Service Workers:** Check registration

### Safari (iOS/macOS)

1. **Open Web Inspector**
2. **Storage Tab:**
   - Check manifest and service worker
3. **Note:** Safari has limited PWA support compared to Chrome

## PWA Installability Test

### Chrome/Edge Desktop

1. Open the app in Chrome/Edge
2. Look for install icon in address bar (or menu)
3. Click "Install" to test installation
4. Verify app opens in standalone window
5. Check that service worker works offline

### Chrome Android

1. Open the app in Chrome
2. Tap menu (3 dots) > "Add to Home screen"
3. Verify app icon appears on home screen
4. Launch app from home screen
5. Verify it opens in standalone mode (no browser UI)

### iOS Safari

1. Open the app in Safari
2. Tap Share button
3. Select "Add to Home Screen"
4. Verify app icon appears
5. Launch app and verify standalone mode

## Common Issues and Solutions

### Issue: "Manifest not installable"

**Possible Causes:**
- Missing required icon sizes (192x192, 512x512)
- Invalid manifest.json (syntax errors)
- Not served over HTTPS (production)
- Missing service worker registration

**Solution:**
1. Run verification script: `dart web/verify_pwa_complete.dart`
2. Check Chrome DevTools > Application > Manifest for errors
3. Ensure all required fields are present
4. Verify icons exist and are accessible

### Issue: Service Worker Not Registering

**Possible Causes:**
- Build not completed (`flutter build web` not run)
- Service worker file not generated
- HTTPS not configured (production)

**Solution:**
1. Run `flutter build web`
2. Verify `build/web/flutter_service_worker.js` exists
3. Check browser console for errors
4. Verify HTTPS is enabled (production)

### Issue: App Not Installing

**Possible Causes:**
- Missing installable display mode in manifest
- Icons not accessible
- Service worker not active
- Already installed

**Solution:**
1. Check manifest.json `display` field (should be `standalone`, `fullscreen`, or `minimal-ui`)
2. Verify icons are accessible (check network tab)
3. Ensure service worker is active
4. Uninstall existing installation and try again

## Production Deployment Checklist

Before deploying to production:

- [ ] Run verification script: `dart web/verify_pwa_complete.dart`
- [ ] Build web app: `flutter build web --release`
- [ ] Verify `build/web/flutter_service_worker.js` exists
- [ ] Test on HTTPS (not just localhost)
- [ ] Test PWA installation in Chrome DevTools
- [ ] Run Lighthouse PWA audit (score 90+)
- [ ] Test offline functionality
- [ ] Verify all icons load correctly
- [ ] Test on mobile devices (Android/iOS)
- [ ] Verify manifest.json is accessible at `/manifest.json`

## Additional Resources

- [Web App Manifest Specification](https://www.w3.org/TR/appmanifest/)
- [Service Worker API](https://developer.mozilla.org/en-US/docs/Web/API/Service_Worker_API)
- [PWA Checklist](https://web.dev/pwa-checklist/)
- [Flutter Web Deployment](https://docs.flutter.dev/deployment/web)

## Support

If you encounter issues:
1. Check browser console for errors
2. Run the verification script
3. Review Chrome DevTools > Application tab
4. Check Flutter build output for warnings
