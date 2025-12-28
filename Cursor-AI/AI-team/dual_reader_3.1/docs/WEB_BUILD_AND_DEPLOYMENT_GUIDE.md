# Web Build and Deployment Guide - Dual Reader 3.1

## Overview

This comprehensive guide covers building and deploying Dual Reader 3.1 as a production-ready Progressive Web App (PWA) to static hosting platforms including GitHub Pages, Netlify, and Vercel.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Build Configuration](#build-configuration)
3. [PWA Configuration](#pwa-configuration)
4. [Building the Web App](#building-the-web-app)
5. [Deployment Platforms](#deployment-platforms)
6. [Verification](#verification)
7. [Troubleshooting](#troubleshooting)
8. [Performance Optimization](#performance-optimization)

## Prerequisites

### Required Tools

- **Flutter SDK** (latest stable version)
  - Verify: `flutter --version`
  - Install: https://flutter.dev/docs/get-started/install

- **Git** (for GitHub Pages deployment)
  - Verify: `git --version`
  - Install: https://git-scm.com/downloads

- **Node.js** (for Netlify/Vercel CLI)
  - Verify: `node --version`
  - Install: https://nodejs.org/

### Platform-Specific Requirements

#### GitHub Pages
- GitHub account
- Repository with push access

#### Netlify
- Netlify account (free tier available)
- Netlify CLI: `npm install -g netlify-cli`

#### Vercel
- Vercel account (free tier available)
- Vercel CLI: `npm install -g vercel`

## Build Configuration

### Optimized Build Settings

The web build uses the following optimizations:

- **Tree-shaking**: Removes unused code and icons
- **CanvasKit Renderer**: Better performance and consistency
- **Minification**: Reduces bundle size
- **Code Splitting**: Lazy loads components
- **PWA Support**: Service worker for offline functionality

### Build Command

```bash
flutter build web \
  --release \
  --base-href / \
  --tree-shake-icons \
  --web-renderer canvaskit \
  --dart-define=FLUTTER_WEB_USE_SKIA=true
```

### Build Scripts

**Windows (PowerShell):**
```powershell
.\web\build_web.ps1
```

**Linux/macOS:**
```bash
bash web/build_web.sh
```

**Options:**
- `--debug`: Build in debug mode
- `--no-verify`: Skip build verification
- `--analyze`: Run code analysis before building
- `--test`: Run tests before building
- `--base-href PATH`: Set custom base path

## PWA Configuration

### Manifest File

The PWA manifest (`web/manifest.json`) includes:

- **App Identity**: Name, short name, description
- **Display Mode**: Standalone for app-like experience
- **Icons**: Multiple sizes (16x16 to 512x512)
- **Theme Colors**: Dark theme (#121212 background, #1976D2 theme)
- **Start URL**: `/` (root)
- **Shortcuts**: Quick access to Library and Continue Reading
- **Share Target**: Accept EPUB/MOBI files via share
- **Protocol Handlers**: Handle `web+epub://` URLs

### Service Worker

Flutter automatically generates `flutter_service_worker.js` during build, which:

- Caches app shell and assets
- Enables offline functionality
- Handles updates automatically
- Manages cache versioning

### Icons

Required PWA icons (all sizes in `web/icons/`):

- 16x16, 32x32 (favicons)
- 72x72, 96x96, 128x128, 144x144, 152x152 (mobile)
- 192x192, 384x384, 512x512 (PWA standard)

Generate icons using:
```powershell
.\web\create_icons.ps1
```

## Building the Web App

### Quick Build

**Windows:**
```powershell
.\web\build_web.ps1
```

**Linux/macOS:**
```bash
bash web/build_web.sh
```

### Manual Build

1. **Get dependencies:**
   ```bash
   flutter pub get
   ```

2. **Build web app:**
   ```bash
   flutter build web --release --base-href / --tree-shake-icons --web-renderer canvaskit
   ```

3. **Verify build output:**
   ```bash
   ls build/web/
   ```

### Build Output Structure

```
build/web/
├── index.html                 # Main HTML file
├── main.dart.js              # Compiled Dart code
├── flutter.js                # Flutter web engine
├── flutter_service_worker.js # Service worker (auto-generated)
├── manifest.json             # PWA manifest
├── favicon.ico               # Favicon
├── icons/                    # PWA icons
│   ├── icon-16x16.png
│   ├── icon-192x192.png
│   └── icon-512x512.png
├── assets/                   # App assets
└── canvaskit/                # CanvasKit renderer
```

### Testing Locally

1. **Start local server:**
   ```bash
   cd build/web
   python -m http.server 8000
   # or
   python3 -m http.server 8000
   ```

2. **Open in browser:**
   ```
   http://localhost:8000
   ```

3. **Test PWA:**
   - Open Chrome DevTools → Application → Manifest
   - Check "Add to Home Screen" prompt
   - Test offline functionality

## Deployment Platforms

### GitHub Pages

#### Option 1: Automated Deployment Script

**Windows:**
```powershell
.\scripts\deploy_github_pages.ps1
```

**Linux/macOS:**
```bash
bash scripts/deploy_github_pages.sh
```

**Options:**
- `-RepoName NAME`: Repository name (default: dual_reader_3.1)
- `-Branch BRANCH`: Deployment branch (default: gh-pages)
- `-DryRun`: Preview without deploying
- `-BuildOnly`: Build without deploying

#### Option 2: GitHub Actions (Recommended)

Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy to GitHub Pages

on:
  push:
    branches: [ master, main ]
  workflow_dispatch:

permissions:
  contents: read
  pages: write
  id-token: write

concurrency:
  group: "pages"
  cancel-in-progress: false

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: 'stable'
          channel: 'stable'
      
      - name: Get dependencies
        run: flutter pub get
      
      - name: Build web app
        run: |
          flutter build web \
            --release \
            --base-href /dual_reader_3.1/ \
            --tree-shake-icons \
            --web-renderer canvaskit
      
      - name: Deploy to GitHub Pages
        uses: peaceiris/actions-gh-pages@v3
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          publish_dir: ./build/web
```

#### Option 3: Manual Deployment

1. **Build for GitHub Pages:**
   ```bash
   flutter build web --release --base-href /your-repo-name/ --tree-shake-icons --web-renderer canvaskit
   ```

2. **Enable GitHub Pages:**
   - Go to repository Settings → Pages
   - Source: Deploy from branch
   - Branch: `gh-pages` (or `main`/`master`)
   - Folder: `/ (root)`

3. **Access your site:**
   ```
   https://[username].github.io/[repo-name]/
   ```

### Netlify

#### Option 1: Netlify CLI

**Windows:**
```powershell
.\scripts\deploy_netlify.ps1 -Production
```

**Linux/macOS:**
```bash
bash scripts/deploy_netlify.sh --production
```

**First-time setup:**
```bash
netlify login
netlify init
```

#### Option 2: Netlify Dashboard

1. **Connect repository:**
   - Go to https://app.netlify.com
   - Click "New site from Git"
   - Select your repository

2. **Configure build:**
   - Build command: `flutter build web --release --base-href / --tree-shake-icons --web-renderer canvaskit`
   - Publish directory: `build/web`

3. **Environment variables:**
   - `FLUTTER_VERSION`: `stable`
   - `FLUTTER_WEB_USE_SKIA`: `true`

4. **Deploy:**
   - Netlify will automatically build and deploy on push

#### Configuration File

The `web/netlify.toml` file is automatically used:

```toml
[build]
  command = "flutter build web --release --base-href / --tree-shake-icons --web-renderer canvaskit"
  publish = "build/web"

[build.environment]
  FLUTTER_VERSION = "stable"
  FLUTTER_WEB_USE_SKIA = "true"
```

### Vercel

#### Option 1: Vercel CLI

**Windows:**
```powershell
.\scripts\deploy_vercel.ps1 -Production
```

**Linux/macOS:**
```bash
bash scripts/deploy_vercel.sh --production
```

**First-time setup:**
```bash
vercel login
vercel
```

#### Option 2: Vercel Dashboard

1. **Import project:**
   - Go to https://vercel.com
   - Click "New Project"
   - Import your repository

2. **Configure build:**
   - Framework Preset: Other
   - Build Command: `flutter build web --release --base-href / --tree-shake-icons --web-renderer canvaskit`
   - Output Directory: `build/web`

3. **Deploy:**
   - Vercel will automatically build and deploy on push

#### Configuration File

The `web/vercel.json` file is automatically used:

```json
{
  "version": 2,
  "buildCommand": "flutter build web --release --base-href / --tree-shake-icons --web-renderer canvaskit",
  "outputDirectory": "build/web"
}
```

## Verification

### Build Verification

**Windows:**
```powershell
.\web\verify_deployment.ps1
```

**Linux/macOS:**
```bash
bash web/verify_deployment.sh
```

### PWA Verification Checklist

- [ ] Manifest file is valid JSON
- [ ] All required icons are present
- [ ] Service worker is registered
- [ ] App is installable (Chrome DevTools → Application → Manifest)
- [ ] Offline functionality works
- [ ] Theme colors match design
- [ ] Start URL is correct
- [ ] Display mode is "standalone"

### Browser Testing

1. **Chrome DevTools:**
   - Application → Manifest: Check installability
   - Application → Service Workers: Verify registration
   - Application → Storage: Check cache
   - Lighthouse: Run PWA audit

2. **Test offline:**
   - Open DevTools → Network → Offline
   - Reload page
   - App should work offline

3. **Test installation:**
   - Look for install prompt
   - Install as PWA
   - Verify standalone mode

### Performance Testing

**Lighthouse Audit:**
- Open Chrome DevTools → Lighthouse
- Run audit for:
  - Performance (target: 90+)
  - Accessibility (target: 90+)
  - Best Practices (target: 90+)
  - SEO (target: 90+)
  - PWA (target: 100)

## Troubleshooting

### Build Issues

**Problem: Build fails with "web renderer not found"**
- Solution: Ensure CanvasKit is downloaded: `flutter precache --web`

**Problem: Large bundle size**
- Solution: Enable tree-shaking: `--tree-shake-icons`
- Check for unused dependencies
- Use code splitting

**Problem: Icons missing**
- Solution: Generate icons: `.\web\create_icons.ps1`
- Verify icons exist in `web/icons/`

### PWA Issues

**Problem: App not installable**
- Check manifest.json is valid
- Verify icons are present (192x192 and 512x512 required)
- Ensure HTTPS (required for PWA)
- Check service worker is registered

**Problem: Service worker not working**
- Verify `flutter_service_worker.js` exists in build output
- Check browser console for errors
- Ensure service worker is not blocked by browser

**Problem: Offline mode not working**
- Verify service worker is active
- Check cache storage in DevTools
- Ensure assets are being cached

### Deployment Issues

**Problem: GitHub Pages shows 404**
- Check base-href matches repository name
- Verify `index.html` exists
- Ensure `.nojekyll` file is present

**Problem: Netlify build fails**
- Check `netlify.toml` configuration
- Verify Flutter is available in build environment
- Check build logs for errors

**Problem: Vercel deployment fails**
- Verify `vercel.json` configuration
- Check build command is correct
- Ensure output directory exists

## Performance Optimization

### Build Optimizations

1. **Tree-shaking:**
   ```bash
   --tree-shake-icons
   ```

2. **Code splitting:**
   - Use lazy loading for routes
   - Split large components

3. **Asset optimization:**
   - Compress images
   - Use WebP format
   - Minimize asset sizes

4. **Caching:**
   - Service worker caches app shell
   - Static assets cached long-term
   - Dynamic content cached short-term

### Runtime Optimizations

1. **Lazy loading:**
   - Load pages on demand
   - Defer non-critical resources

2. **Image optimization:**
   - Use appropriate formats
   - Implement responsive images
   - Lazy load images

3. **Font optimization:**
   - Use system fonts when possible
   - Preload critical fonts
   - Use font-display: swap

### Monitoring

- Use Lighthouse for performance audits
- Monitor Core Web Vitals
- Track PWA install rates
- Monitor service worker errors

## Best Practices

1. **Always test locally before deploying**
2. **Use HTTPS for production (required for PWA)**
3. **Keep dependencies up to date**
4. **Monitor bundle size**
5. **Test on multiple browsers**
6. **Verify offline functionality**
7. **Test installation flow**
8. **Monitor performance metrics**

## Additional Resources

- [Flutter Web Documentation](https://flutter.dev/web)
- [PWA Documentation](https://web.dev/progressive-web-apps/)
- [GitHub Pages Documentation](https://docs.github.com/pages)
- [Netlify Documentation](https://docs.netlify.com/)
- [Vercel Documentation](https://vercel.com/docs)

## Support

For issues or questions:
1. Check troubleshooting section
2. Review build logs
3. Check browser console for errors
4. Verify configuration files
5. Test in different browsers

---

**Last Updated:** 2024
**Version:** 3.1.0
