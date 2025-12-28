# Quick Start Guide - Web Platform

## Building for Web

### Development Build
```bash
flutter run -d chrome --web-port=8080
```

### Production Build
```bash
flutter build web --release
```

The output will be in `build/web/` directory.

## PWA Configuration

### Manifest.json
The PWA manifest is located at `web/manifest.json` and includes:
- App metadata (name, description, icons)
- Display settings (standalone mode)
- App shortcuts
- Share target configuration
- Protocol handlers

### Service Worker
Flutter automatically generates `flutter_service_worker.js` during build. The service worker:
- Caches app assets for offline use
- Handles updates automatically
- Provides offline functionality

### Responsive Meta Tags
All responsive meta tags are configured in `web/index.html`:
- Viewport settings
- Mobile optimization
- iOS-specific tags
- Android/Chrome tags
- Windows/Edge tags

## Testing PWA Installation

1. Build the app: `flutter build web --release`
2. Serve locally: `cd build/web && python -m http.server 8000`
3. Open in Chrome: `http://localhost:8000`
4. Open DevTools > Application > Manifest
5. Verify installability criteria are met
6. Click "Install" button or use browser install prompt

## Deployment

### Netlify
1. Connect repository to Netlify
2. Build command: `flutter build web --release`
3. Publish directory: `build/web`
4. Headers configured via `_headers` file

### Vercel
1. Connect repository to Vercel
2. Configuration in `vercel.json`
3. Build command: `flutter build web --release`
4. Output directory: `build/web`

### Apache
1. Upload `build/web/` contents to server
2. Ensure `.htaccess` file is included
3. Enable mod_rewrite, mod_headers, mod_expires
4. Configure HTTPS (required for PWA)

### GitHub Pages
1. Build: `flutter build web --release --base-href /repository-name/`
2. Copy `build/web/` contents to `docs/` folder
3. Enable GitHub Pages in repository settings
4. Note: GitHub Pages doesn't support service workers on free tier

## Icon Generation

Icons are required for PWA installation. Generate icons using scripts in `web/icons/`:
- Minimum required: 192x192 and 512x512
- Recommended: All sizes from 16x16 to 512x512
- Include maskable icons for Android

## Verification Checklist

- [ ] Manifest.json loads without errors
- [ ] Service worker registers successfully
- [ ] App works offline
- [ ] Install prompt appears
- [ ] App installs successfully
- [ ] Responsive design works on mobile
- [ ] All icons load correctly
- [ ] App shortcuts work
- [ ] Share target works (if implemented)

## Troubleshooting

### Service Worker Not Registering
- Ensure HTTPS (or localhost)
- Check browser console for errors
- Verify service worker file exists
- Clear browser cache

### Install Prompt Not Appearing
- Check manifest.json validity
- Verify service worker is registered
- Ensure icons are accessible
- Check Lighthouse PWA audit

### Offline Not Working
- Verify service worker is active
- Check cache in DevTools > Application > Cache Storage
- Ensure assets are being cached
- Test with network throttling

## Additional Resources

- [PWA Documentation](https://web.dev/progressive-web-apps/)
- [Flutter Web Documentation](https://docs.flutter.dev/platform-integration/web)
- [Manifest Specification](https://www.w3.org/TR/appmanifest/)
- [Service Worker API](https://developer.mozilla.org/en-US/docs/Web/API/Service_Worker_API)
