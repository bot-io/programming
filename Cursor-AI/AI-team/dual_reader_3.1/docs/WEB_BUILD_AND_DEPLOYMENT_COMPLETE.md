# Web Build and Deployment - Complete Guide

## Overview

This guide provides complete instructions for building and deploying Dual Reader 3.1 as a Progressive Web App (PWA) to various static hosting platforms.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Building the Web App](#building-the-web-app)
3. [Deployment Platforms](#deployment-platforms)
   - [GitHub Pages](#github-pages)
   - [Netlify](#netlify)
   - [Vercel](#vercel)
4. [PWA Configuration](#pwa-configuration)
5. [Verification](#verification)
6. [Troubleshooting](#troubleshooting)

## Prerequisites

- Flutter SDK (latest stable version)
- Git
- Account on your chosen hosting platform (GitHub, Netlify, or Vercel)
- Basic knowledge of command line

## Building the Web App

### Quick Build

**Windows (PowerShell):**
```powershell
.\web\build_web.ps1
```

**Linux/macOS:**
```bash
bash web/build_web.sh
```

### Manual Build

```bash
flutter pub get
flutter build web --release --base-href / --tree-shake-icons --web-renderer canvaskit
```

### Build Options

- `--release`: Build optimized production version
- `--base-href /`: Set base path (use `/your-repo-name/` for GitHub Pages subdirectory)
- `--tree-shake-icons`: Remove unused icons to reduce bundle size
- `--web-renderer canvaskit`: Use CanvasKit renderer for better performance

### Build Output

The build output is located in `build/web/` directory and includes:
- `index.html` - Main HTML file
- `main.dart.js` - Compiled Dart code
- `flutter.js` - Flutter web engine
- `flutter_service_worker.js` - Service worker for offline support
- `manifest.json` - PWA manifest
- `icons/` - PWA icons
- `assets/` - App assets
- `canvaskit/` - CanvasKit renderer files

## Deployment Platforms

### GitHub Pages

#### Option 1: GitHub Actions (Recommended)

1. Create `.github/workflows/deploy.yml`:

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
      
      - name: Build web
        run: flutter build web --release --base-href /dual_reader_3.1/ --tree-shake-icons --web-renderer canvaskit
      
      - name: Setup Pages
        uses: actions/configure-pages@v4
      
      - name: Upload artifact
        uses: actions/upload-pages-artifact@v3
        with:
          path: build/web

  deploy:
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    runs-on: ubuntu-latest
    needs: build
    steps:
      - name: Deploy to GitHub Pages
        id: deployment
        uses: actions/deploy-pages@v4
```

2. Configure GitHub Pages:
   - Go to repository Settings → Pages
   - Source: GitHub Actions
   - Save

#### Option 2: Manual Deployment

1. Build the app:
```bash
flutter build web --release --base-href /your-repo-name/ --tree-shake-icons --web-renderer canvaskit
```

2. Copy `build/web` contents to `gh-pages` branch or `docs` folder

3. Push to GitHub:
```bash
git subtree push --prefix build/web origin gh-pages
```

#### Option 3: Using Script

Use the provided deployment script:

**Windows:**
```powershell
.\scripts\deploy_github_pages.ps1
```

**Linux/macOS:**
```bash
bash scripts/deploy_github_pages.sh
```

### Netlify

#### Option 1: Netlify CLI

1. Install Netlify CLI:
```bash
npm install -g netlify-cli
```

2. Build and deploy:
```bash
flutter build web --release --base-href / --tree-shake-icons --web-renderer canvaskit
netlify deploy --prod --dir=build/web
```

#### Option 2: Git Integration (Recommended)

1. Connect repository to Netlify:
   - Go to [Netlify Dashboard](https://app.netlify.com)
   - Click "New site from Git"
   - Select your repository
   - Configure build settings:
     - Build command: `flutter build web --release --base-href / --tree-shake-icons --web-renderer canvaskit`
     - Publish directory: `build/web`
   - Click "Deploy site"

2. Netlify will automatically detect `netlify.toml` configuration

3. For custom domain:
   - Go to Site settings → Domain management
   - Add your custom domain
   - Configure DNS as instructed

#### Option 3: Drag and Drop

1. Build the app:
```bash
flutter build web --release --base-href / --tree-shake-icons --web-renderer canvaskit
```

2. Go to [Netlify Drop](https://app.netlify.com/drop)
3. Drag and drop the `build/web` folder
4. Your site will be live immediately

### Vercel

#### Option 1: Vercel CLI

1. Install Vercel CLI:
```bash
npm install -g vercel
```

2. Build and deploy:
```bash
flutter build web --release --base-href / --tree-shake-icons --web-renderer canvaskit
vercel --prod
```

#### Option 2: Git Integration (Recommended)

1. Connect repository to Vercel:
   - Go to [Vercel Dashboard](https://vercel.com/dashboard)
   - Click "New Project"
   - Import your repository
   - Configure build settings:
     - Framework Preset: Other
     - Build Command: `flutter build web --release --base-href / --tree-shake-icons --web-renderer canvaskit`
     - Output Directory: `build/web`
   - Click "Deploy"

2. Vercel will automatically detect `vercel.json` configuration

3. For custom domain:
   - Go to Project Settings → Domains
   - Add your custom domain
   - Configure DNS as instructed

## PWA Configuration

### Manifest File

The PWA manifest is located at `web/manifest.json` and includes:
- App name and description
- Icons in multiple sizes
- Display mode (standalone)
- Theme colors
- Start URL
- Shortcuts
- Share target configuration

### Service Worker

Flutter automatically generates `flutter_service_worker.js` during build, which:
- Caches app assets for offline access
- Handles updates automatically
- Provides offline functionality

### Testing PWA Features

1. **Installability:**
   - Open Chrome DevTools → Application → Manifest
   - Check for installability issues
   - Test install prompt

2. **Offline Support:**
   - Open Chrome DevTools → Application → Service Workers
   - Check service worker registration
   - Go offline (Network tab → Offline)
   - Test app functionality

3. **Lighthouse Audit:**
   - Open Chrome DevTools → Lighthouse
   - Run PWA audit
   - Ensure all checks pass

## Verification

### Pre-Deployment Checklist

- [ ] Build completes without errors
- [ ] `build/web/index.html` exists
- [ ] `build/web/manifest.json` exists and is valid
- [ ] `build/web/flutter_service_worker.js` exists
- [ ] All icons are present in `build/web/icons/`
- [ ] App loads correctly locally (`python -m http.server 8000`)

### Post-Deployment Verification

1. **Accessibility:**
   - Visit deployed URL
   - Verify app loads correctly
   - Test navigation

2. **PWA Features:**
   - Check install prompt appears (if supported)
   - Test offline functionality
   - Verify service worker registration

3. **Performance:**
   - Run Lighthouse audit
   - Check load times
   - Verify caching works

4. **Cross-Browser:**
   - Test in Chrome, Firefox, Safari, Edge
   - Verify PWA features work across browsers

### Verification Scripts

**Windows:**
```powershell
.\web\verify_deployment.ps1
```

**Linux/macOS:**
```bash
bash web/verify_deployment.sh
```

## Troubleshooting

### Build Issues

**Problem:** Build fails with dependency errors
**Solution:** Run `flutter pub get` and ensure all dependencies are resolved

**Problem:** Large bundle size
**Solution:** 
- Enable tree-shaking: `--tree-shake-icons`
- Check for unused assets
- Consider code splitting

### Deployment Issues

**Problem:** 404 errors on routes
**Solution:** Ensure redirect rules are configured (all routes → index.html)

**Problem:** Service worker not updating
**Solution:** Clear browser cache and ensure service worker headers are set correctly

**Problem:** PWA not installable
**Solution:**
- Verify HTTPS is enabled
- Check manifest.json is valid
- Ensure icons are present
- Verify service worker is registered

### Performance Issues

**Problem:** Slow initial load
**Solution:**
- Enable compression (gzip/brotli)
- Optimize images
- Use CDN for assets
- Implement lazy loading

**Problem:** Large CanvasKit bundle
**Solution:**
- Consider using HTML renderer for smaller bundle
- Implement code splitting
- Use CDN for CanvasKit

## Additional Resources

- [Flutter Web Documentation](https://docs.flutter.dev/platform-integration/web)
- [PWA Documentation](https://web.dev/progressive-web-apps/)
- [GitHub Pages Documentation](https://docs.github.com/en/pages)
- [Netlify Documentation](https://docs.netlify.com/)
- [Vercel Documentation](https://vercel.com/docs)

## Support

For issues or questions:
1. Check the troubleshooting section
2. Review platform-specific documentation
3. Open an issue on GitHub
