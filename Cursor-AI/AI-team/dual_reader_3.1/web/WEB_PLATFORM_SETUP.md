# Web Platform Setup Guide - Dual Reader 3.1

This document provides a comprehensive guide for setting up and verifying the web platform configuration for Dual Reader 3.1.

## Overview

The web platform is configured as a Progressive Web App (PWA) with:
- ✅ PWA manifest.json with complete app metadata
- ✅ Service worker for offline support
- ✅ Responsive meta tags for optimal mobile/desktop experience
- ✅ Installable as PWA on supported browsers
- ✅ Cross-platform compatibility (Chrome, Firefox, Safari, Edge)

## File Structure

```
web/
├── index.html              # Main HTML file with meta tags and PWA setup
├── manifest.json           # PWA manifest with app metadata
├── service-worker.js       # Service worker for offline support
├── browserconfig.xml       # Windows tile configuration
├── icons/                  # PWA icons (must be generated)
│   ├── icon-16x16.png
│   ├── icon-32x32.png
│   ├── icon-72x72.png
│   ├── icon-96x96.png
│   ├── icon-128x128.png
│   ├── icon-144x144.png
│   ├── icon-152x152.png
│   ├── icon-192x192.png
│   ├── icon-384x384.png
│   └── icon-512x512.png
└── generate_icons_*.ps1    # Icon generation scripts
```

## Setup Steps

### 1. Generate Icons

Icons are required for PWA installability. Choose one of the following methods:

#### Option A: Using PowerShell (Windows)
```powershell
cd web
.\generate_icons_simple.ps1
```

#### Option B: Using Python
```bash
cd web
python generate_icons_simple.py
```

**Note:** For production, replace placeholder icons with actual app icons. Create a 512x512 icon and resize to all required sizes.

### 2. Build Web App

```bash
flutter build web --release
```

The built files will be in `build/web/`.

### 3. Verify Setup

Run the verification script:

```powershell
cd web
.\verify_pwa_setup.ps1
```

Or manually verify:
- ✅ All icon files exist in `web/icons/`
- ✅ `manifest.json` is valid JSON
- ✅ `index.html` includes manifest link
- ✅ Service worker is registered in `index.html`

### 4. Test Locally

```bash
cd build/web
python -m http.server 8000
# or
python3 -m http.server 8000
```

Then open: `http://localhost:8000`

### 5. Test PWA Installability

1. Open Chrome DevTools (F12)
2. Go to **Application** tab
3. Check **Manifest** section:
   - Should show app name, icons, and display mode
   - Should not show any errors
4. Check **Service Workers** section:
   - Should show registered service worker
   - Status should be "activated and is running"
5. Check **Installability**:
   - Look for install prompt in address bar
   - Or use DevTools > Application > Manifest > "Add to homescreen"

## PWA Features

### Manifest.json Features

- **App Metadata**: Name, short name, description
- **Display Mode**: Standalone (app-like experience)
- **Icons**: Multiple sizes for different devices
- **Shortcuts**: Quick actions (Library, Continue Reading)
- **Share Target**: Accept EPUB/MOBI files via share
- **Protocol Handlers**: Handle `web+epub://` URLs
- **Launch Handler**: Navigate existing windows

### Service Worker Features

- **Offline Support**: Cache app shell and assets
- **Cache Strategies**:
  - Cache-first for app shell
  - Network-first for dynamic content
  - Stale-while-revalidate for assets
- **Update Handling**: Automatic updates with user notification
- **Offline Fallback**: Shows offline page when network unavailable

### Responsive Meta Tags

- **Viewport**: Optimized for mobile and desktop
- **Theme Color**: Matches app theme (#1976D2)
- **iOS Support**: Apple touch icons and meta tags
- **Windows Support**: Tile configuration
- **Mobile Optimization**: Handheld-friendly, mobile-optimized

## Browser Compatibility

| Browser | PWA Support | Installable | Offline Support |
|---------|-------------|-------------|-----------------|
| Chrome  | ✅ Full     | ✅ Yes      | ✅ Yes          |
| Edge    | ✅ Full     | ✅ Yes      | ✅ Yes          |
| Firefox | ✅ Full     | ✅ Yes      | ✅ Yes          |
| Safari  | ⚠️ Partial  | ✅ Yes      | ✅ Yes          |
| Opera   | ✅ Full     | ✅ Yes      | ✅ Yes          |

**Note:** Safari has limited PWA features on iOS (no standalone mode, limited service worker support).

## Deployment

### Static Hosting

The web app can be deployed to any static hosting service:

- **GitHub Pages**: Free, easy setup
- **Netlify**: Free tier, automatic deployments
- **Vercel**: Free tier, excellent performance
- **Firebase Hosting**: Free tier, CDN included
- **AWS S3 + CloudFront**: Pay-as-you-go

### Deployment Checklist

- [ ] Icons generated and present
- [ ] Build completed successfully (`flutter build web --release`)
- [ ] Tested locally
- [ ] PWA installability verified
- [ ] Service worker working
- [ ] HTTPS enabled (required for PWA)
- [ ] Domain configured (if using custom domain)

### HTTPS Requirement

PWAs require HTTPS (except for localhost). Ensure your hosting provider supports HTTPS:
- Most modern hosting services provide free SSL certificates
- Let's Encrypt provides free SSL certificates

## Troubleshooting

### Icons Not Showing

1. Verify icons exist in `web/icons/` directory
2. Check file names match manifest.json exactly
3. Ensure icons are valid PNG files
4. Clear browser cache and reload

### Service Worker Not Registering

1. Check browser console for errors
2. Verify `service-worker.js` exists and is valid JavaScript
3. Ensure HTTPS (or localhost) is used
4. Check service worker scope matches app scope

### PWA Not Installable

1. Verify manifest.json is valid JSON
2. Check all required fields are present:
   - name
   - short_name
   - start_url
   - display
   - icons (at least 192x192 and 512x512)
3. Ensure HTTPS is enabled
4. Check browser DevTools > Application > Manifest for errors

### Offline Not Working

1. Verify service worker is registered and active
2. Check service worker cache strategies
3. Test in offline mode (DevTools > Network > Offline)
4. Verify assets are being cached

## Additional Resources

- [PWA Documentation](https://web.dev/progressive-web-apps/)
- [Web App Manifest](https://web.dev/add-manifest/)
- [Service Workers](https://web.dev/service-worker-caching-and-http-caching/)
- [Flutter Web](https://docs.flutter.dev/deployment/web)

## Support

For issues or questions:
1. Check browser console for errors
2. Verify setup using `verify_pwa_setup.ps1`
3. Review this documentation
4. Check Flutter web documentation
