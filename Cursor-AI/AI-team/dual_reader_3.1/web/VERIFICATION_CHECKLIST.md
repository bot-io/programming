# Web Platform Configuration Verification Checklist

Use this checklist to verify that the web platform is properly configured.

## Pre-Build Verification

- [ ] All required files exist:
  - [ ] `web/index.html`
  - [ ] `web/manifest.json`
  - [ ] `web/service-worker.js`

- [ ] Icons directory exists:
  - [ ] `web/icons/` directory exists
  - [ ] Icons are present (at minimum: 192x192 and 512x512)

## Build Verification

1. **Build the web app:**
   ```bash
   flutter build web
   ```

2. **Verify build output:**
   - [ ] `build/web/index.html` exists
   - [ ] `build/web/manifest.json` exists
   - [ ] `build/web/service-worker.js` exists
   - [ ] `build/web/flutter.js` exists
   - [ ] `build/web/main.dart.js` exists

## Runtime Verification

1. **Start local server:**
   ```bash
   cd build/web
   python -m http.server 8000
   # or
   npx serve
   ```

2. **Open in browser:**
   - Navigate to `http://localhost:8000`

3. **Check browser console:**
   - [ ] No critical errors
   - [ ] Service worker registered successfully
   - [ ] App loads without errors

## PWA Verification

### Manifest Check
- [ ] Open DevTools > Application > Manifest
- [ ] Manifest is valid (no errors)
- [ ] All icons are listed
- [ ] Theme color matches (#1976D2)
- [ ] Display mode is "standalone"

### Service Worker Check
- [ ] Open DevTools > Application > Service Workers
- [ ] Service worker is registered and active
- [ ] Scope is "/"
- [ ] Status is "activated and is running"

### Installability Check
- [ ] Open DevTools > Application > Manifest
- [ ] "Add to homescreen" or install prompt appears (if criteria met)
- [ ] App can be installed as PWA
- [ ] Installed app opens in standalone mode

### Offline Check
1. **Enable offline mode:**
   - Open DevTools > Network
   - Check "Offline" checkbox

2. **Reload page:**
   - [ ] App loads (from cache)
   - [ ] Offline fallback page shows if needed
   - [ ] No network errors in console

3. **Disable offline mode:**
   - [ ] App continues to work normally

## Responsive Design Verification

### Desktop (1920x1080)
- [ ] App displays correctly
- [ ] Layout is responsive
- [ ] Text is readable

### Tablet (768x1024)
- [ ] App displays correctly
- [ ] Layout adapts to screen
- [ ] Touch targets are appropriate

### Mobile (375x667)
- [ ] App displays correctly
- [ ] Viewport meta tag works
- [ ] No horizontal scrolling
- [ ] Touch interactions work

## Meta Tags Verification

Open page source and verify:
- [ ] Viewport meta tag present
- [ ] Theme color meta tag present
- [ ] Description meta tag present
- [ ] Open Graph tags present (for social sharing)
- [ ] Apple mobile web app tags present
- [ ] Microsoft tile tags present

## Performance Verification

1. **Lighthouse Audit:**
   - Open DevTools > Lighthouse
   - Run audit for PWA
   - [ ] PWA score > 90
   - [ ] Performance score > 80
   - [ ] Accessibility score > 90
   - [ ] Best Practices score > 90
   - [ ] SEO score > 90

2. **Network Tab:**
   - [ ] Assets are cached after first load
   - [ ] Service worker intercepts requests
   - [ ] Cache is populated

## Browser Compatibility

Test in multiple browsers:
- [ ] Chrome/Edge (latest)
- [ ] Firefox (latest)
- [ ] Safari (latest)
- [ ] Opera (latest)

## Deployment Verification

After deploying to hosting service:

1. **HTTPS Check:**
   - [ ] App is served over HTTPS
   - [ ] No mixed content warnings

2. **PWA Install:**
   - [ ] Install prompt appears (if criteria met)
   - [ ] App installs successfully
   - [ ] Installed app works offline

3. **Service Worker:**
   - [ ] Service worker registers on production
   - [ ] Cache works correctly
   - [ ] Updates propagate correctly

## Common Issues and Solutions

### Service Worker Not Registering
- **Solution:** Ensure app is served over HTTPS (or localhost)
- **Solution:** Check service-worker.js path is correct
- **Solution:** Clear browser cache and service workers

### PWA Not Installable
- **Solution:** Verify manifest.json is valid JSON
- **Solution:** Ensure icons exist and are accessible
- **Solution:** Check all PWA installability criteria are met

### Offline Not Working
- **Solution:** Check service worker is registered
- **Solution:** Verify cache is being populated
- **Solution:** Check browser DevTools for errors

### Build Errors
- **Solution:** Run `flutter clean` then rebuild
- **Solution:** Check Flutter version compatibility
- **Solution:** Verify all dependencies are compatible with web

## Success Criteria

All acceptance criteria should be met:
- ✅ PWA manifest.json created with app metadata
- ✅ Service worker configured for offline support
- ✅ Web app builds and runs in browser
- ✅ Responsive meta tags configured
- ✅ App is installable as PWA
