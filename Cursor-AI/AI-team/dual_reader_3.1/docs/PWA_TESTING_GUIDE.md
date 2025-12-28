# PWA Testing and Installation Guide

Complete guide for testing Progressive Web App (PWA) features and verifying offline functionality.

## Table of Contents

1. [PWA Installation](#pwa-installation)
2. [Testing Offline Functionality](#testing-offline-functionality)
3. [Service Worker Testing](#service-worker-testing)
4. [Lighthouse Audit](#lighthouse-audit)
5. [Cross-Browser Testing](#cross-browser-testing)
6. [Troubleshooting](#troubleshooting)

## PWA Installation

### Chrome/Edge (Desktop)

1. **Build and serve the app**:
   ```powershell
   .\scripts\build_web.ps1
   cd build\web
   python -m http.server 8000
   ```

2. **Open in browser**: http://localhost:8000

3. **Look for install icon**:
   - Install icon appears in address bar (right side)
   - Or click menu (⋮) > "Install Dual Reader"

4. **Install prompt**:
   - Click "Install" button
   - App opens in standalone window
   - App icon appears in taskbar/dock

### Chrome/Edge (Mobile)

1. **Open app** in mobile browser
2. **Look for install banner** at bottom of screen
3. **Tap "Install"** or "Add to Home Screen"
4. **App icon** appears on home screen
5. **Tap icon** to open in standalone mode

### Safari (iOS)

1. **Open app** in Safari
2. **Tap Share button** (square with arrow)
3. **Select "Add to Home Screen"**
4. **Customize name** (optional)
5. **Tap "Add"**
6. **App icon** appears on home screen

### Firefox (Desktop)

1. **Open app** in Firefox
2. **Look for install icon** in address bar
3. **Click to install**
4. **App opens** in standalone window

## Testing Offline Functionality

### Method 1: DevTools Offline Mode

1. **Open DevTools** (F12)
2. **Go to Network tab**
3. **Check "Offline" checkbox**
4. **Reload page** (Ctrl+R / Cmd+R)
5. **Verify**:
   - ✅ App loads from cache
   - ✅ UI is functional
   - ✅ Cached content displays
   - ✅ No network errors

### Method 2: Disconnect Network

1. **Disconnect WiFi/Ethernet**
2. **Reload page**
3. **Verify**:
   - ✅ App loads from cache
   - ✅ Offline indicator shows (if implemented)
   - ✅ Cached books are accessible
   - ✅ Settings persist

### Method 3: Service Worker Cache

1. **Open DevTools** > Application tab
2. **Go to Cache Storage**
3. **Verify caches exist**:
   - `flutter_service_worker.js` cache
   - App assets cached
   - Icons cached
4. **Disconnect network**
5. **Reload page**
6. **Verify** cached content loads

## Service Worker Testing

### Check Registration

1. **Open DevTools** > Application tab
2. **Click "Service Workers"** (left sidebar)
3. **Verify**:
   - ✅ Service worker is registered
   - ✅ Status: "activated and is running"
   - ✅ Scope: `/` (root)

### Test Update

1. **Make changes** to app
2. **Rebuild**:
   ```powershell
   .\scripts\build_web.ps1
   ```
3. **Reload page** (hard refresh: Ctrl+Shift+R)
4. **Check Service Workers**:
   - New service worker should appear
   - Status: "waiting to activate"
5. **Click "skipWaiting"** or reload again
6. **Verify** new version loads

### Test Cache

1. **Open DevTools** > Application tab
2. **Click "Cache Storage"**
3. **Expand caches**:
   - `flutter_service_worker.js` cache
   - Check cached files
4. **Verify**:
   - ✅ App files cached
   - ✅ Assets cached
   - ✅ Icons cached

### Test Offline Fallback

1. **Go offline** (DevTools > Network > Offline)
2. **Navigate to non-cached route**
3. **Verify**:
   - ✅ Offline page shows (if implemented)
   - ✅ Or app handles gracefully
   - ✅ No blank page

## Lighthouse Audit

### Run Audit

1. **Open DevTools** (F12)
2. **Go to Lighthouse tab**
3. **Select**:
   - ✅ Progressive Web App
   - ✅ Performance
   - ✅ Best Practices
   - ✅ Accessibility
   - ✅ SEO
4. **Select device**: Desktop or Mobile
5. **Click "Analyze page load"**

### PWA Score Targets

- **PWA**: 90+ (all checks passing)
- **Performance**: 80+
- **Best Practices**: 90+
- **Accessibility**: 90+
- **SEO**: 90+

### PWA Checklist (Lighthouse)

Lighthouse checks for:

- ✅ **Manifest**: Valid manifest.json
- ✅ **Service Worker**: Registered and active
- ✅ **HTTPS**: Secure context
- ✅ **Icons**: 192x192 and 512x512 icons
- ✅ **Offline**: Works offline
- ✅ **Start URL**: Valid start_url
- ✅ **Display**: Standalone or fullscreen
- ✅ **Theme Color**: Set in manifest
- ✅ **Viewport**: Proper viewport meta tag

### Fixing Issues

#### Missing Manifest

- Verify `manifest.json` exists in `build/web/`
- Check `index.html` links to manifest
- Ensure manifest is valid JSON

#### Service Worker Not Registered

- Check `flutter_service_worker.js` exists
- Verify HTTPS (or localhost)
- Check browser console for errors
- Ensure service worker scope matches

#### Missing Icons

- Verify `icons/icon-192x192.png` exists
- Verify `icons/icon-512x512.png` exists
- Check manifest references icons correctly

#### Not Installable

- Verify HTTPS (required)
- Check all PWA requirements met
- Test in Chrome/Edge (best support)
- Check manifest is valid

## Cross-Browser Testing

### Chrome/Edge (Chromium)

- ✅ **Best PWA support**
- ✅ **Install prompt**
- ✅ **Service worker**
- ✅ **Offline support**
- ✅ **All PWA features**

### Firefox

- ✅ **Good PWA support**
- ✅ **Install prompt** (desktop)
- ✅ **Service worker**
- ✅ **Offline support**
- ⚠️ **Limited mobile support**

### Safari (macOS)

- ✅ **Good PWA support**
- ✅ **Install via menu**
- ✅ **Service worker**
- ✅ **Offline support**
- ⚠️ **Limited features** (no install prompt)

### Safari (iOS)

- ✅ **PWA support**
- ✅ **Add to Home Screen**
- ✅ **Service worker**
- ✅ **Offline support**
- ⚠️ **Limited features** (no install prompt)

## Troubleshooting

### Install Prompt Not Appearing

**Possible causes**:
1. Not on HTTPS (or localhost)
2. Manifest invalid
3. Service worker not registered
4. Missing required icons
5. Already installed

**Solutions**:
- Verify HTTPS
- Check manifest.json is valid
- Verify service worker is active
- Check icons exist (192x192, 512x512)
- Uninstall and reinstall

### App Not Working Offline

**Possible causes**:
1. Service worker not caching assets
2. Assets not included in cache
3. Service worker not active
4. Cache cleared

**Solutions**:
- Check service worker is active
- Verify assets are cached
- Check Cache Storage in DevTools
- Rebuild and redeploy

### Service Worker Not Updating

**Possible causes**:
1. Service worker cached
2. Browser cache
3. Update not triggered

**Solutions**:
- Hard refresh (Ctrl+Shift+R)
- Clear cache and reload
- Unregister service worker
- Rebuild and redeploy

### Icons Not Showing

**Possible causes**:
1. Icons not in build output
2. Manifest paths incorrect
3. Icons not optimized

**Solutions**:
- Verify icons in `build/web/icons/`
- Check manifest icon paths
- Ensure icons are PNG format
- Optimize icon sizes

## Testing Checklist

### Before Deployment

- [ ] Build completed successfully
- [ ] Manifest.json is valid
- [ ] Service worker registered
- [ ] Icons present (all sizes)
- [ ] App installs successfully
- [ ] App works offline
- [ ] Service worker updates work
- [ ] Lighthouse PWA score 90+
- [ ] Tested on Chrome/Edge
- [ ] Tested on Firefox
- [ ] Tested on Safari (if applicable)
- [ ] Tested on mobile browsers

### After Deployment

- [ ] App accessible via HTTPS
- [ ] Install prompt appears
- [ ] App installs successfully
- [ ] App works offline
- [ ] Service worker active
- [ ] Icons display correctly
- [ ] Performance is good
- [ ] No console errors

## Best Practices

1. **Always test on HTTPS** (or localhost)
2. **Test offline functionality** before deploying
3. **Verify service worker** is active
4. **Check Lighthouse score** regularly
5. **Test on multiple browsers**
6. **Test on mobile devices**
7. **Monitor service worker updates**
8. **Handle offline gracefully**

## Additional Resources

- [PWA Checklist](https://web.dev/pwa-checklist/)
- [Service Worker API](https://developer.mozilla.org/en-US/docs/Web/API/Service_Worker_API)
- [Web App Manifest](https://developer.mozilla.org/en-US/docs/Web/Manifest)
- [Lighthouse Documentation](https://developers.google.com/web/tools/lighthouse)
