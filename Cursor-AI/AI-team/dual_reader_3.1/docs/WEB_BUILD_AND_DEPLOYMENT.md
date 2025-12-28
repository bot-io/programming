# Web Build and Deployment Guide

Complete guide for building and deploying Dual Reader 3.1 as a Progressive Web App (PWA) to various hosting platforms.

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Build Configuration](#build-configuration)
4. [PWA Configuration](#pwa-configuration)
5. [Service Worker](#service-worker)
6. [Building for Web](#building-for-web)
7. [Deployment Platforms](#deployment-platforms)
   - [GitHub Pages](#github-pages)
   - [Netlify](#netlify)
   - [Vercel](#vercel)
8. [Testing PWA](#testing-pwa)
9. [Troubleshooting](#troubleshooting)

## Overview

Dual Reader 3.1 is configured as a Progressive Web App (PWA) with:
- ✅ Optimized web build with CanvasKit renderer
- ✅ PWA manifest for installability
- ✅ Service worker for offline support
- ✅ Responsive design for all devices
- ✅ SEO optimization
- ✅ Security headers

## Prerequisites

### Required Tools

1. **Flutter SDK** (latest stable version)
   ```bash
   flutter --version
   ```

2. **Git** (for GitHub Pages deployment)
   ```bash
   git --version
   ```

3. **Node.js and npm** (for Netlify/Vercel CLI)
   ```bash
   node --version
   npm --version
   ```

### Optional Tools

- **Netlify CLI** (for Netlify deployment)
  ```bash
  npm install -g netlify-cli
  ```

- **Vercel CLI** (for Vercel deployment)
  ```bash
  npm install -g vercel
  ```

## Build Configuration

### Optimized Build Settings

The web build uses the following optimizations:

- **CanvasKit Renderer**: Better performance and smaller bundle size
- **Tree-shaking**: Removes unused code and icons
- **Release Mode**: Optimized for production
- **Base Href**: Configurable for subdirectory deployment

### Build Scripts

#### Linux/Mac (Bash)

```bash
# Production build
./scripts/build_web.sh

# Debug build
./scripts/build_web.sh --debug

# Custom base href (for subdirectory deployment)
./scripts/build_web.sh --base-href "/app/"

# With analyzer
./scripts/build_web.sh --analyze

# Verify PWA configuration
./scripts/build_web.sh --verify
```

#### Windows (PowerShell)

```powershell
# Production build
.\scripts\build_web.ps1

# Debug build
.\scripts\build_web.ps1 -Mode Debug

# Custom base href
.\scripts\build_web.ps1 -BaseHref "/app/"

# With analyzer
.\scripts\build_web.ps1 -Analyze

# Verify PWA configuration
.\scripts\build_web.ps1 -Verify
```

### Manual Build

```bash
flutter build web --release \
  --base-href / \
  --tree-shake-icons \
  --web-renderer canvaskit
```

**Build Output**: `build/web/`

## PWA Configuration

### Manifest File

The PWA manifest (`web/manifest.json`) includes:

- **App Name**: Dual Reader 3.1
- **Display Mode**: Standalone (app-like experience)
- **Icons**: Multiple sizes (16x16 to 512x512)
- **Theme Color**: #1976D2 (Material Blue)
- **Background Color**: #121212 (Dark theme)
- **Start URL**: `/`
- **Shortcuts**: Library and Continue Reading
- **Share Target**: For sharing EPUB/MOBI files
- **Protocol Handlers**: `web+epub://` support

### Required Icons

The app requires the following icon sizes:

- 16x16, 32x32 (favicons)
- 72x72, 96x96, 128x128, 144x144, 152x152 (mobile)
- 192x192 (Android)
- 384x384, 512x512 (PWA)

Icons should be placed in `web/icons/` directory.

### Manifest Validation

The build script automatically validates:
- Required fields (name, short_name, start_url, display, icons)
- Required icon sizes (192x192, 512x512)
- Valid display mode
- JSON structure

## Service Worker

### Flutter Service Worker

Flutter automatically generates `flutter_service_worker.js` during build, which:
- Caches Flutter assets
- Provides offline support
- Handles versioning and updates
- Registers automatically in `index.html`

### Custom Service Worker

A custom service worker (`web/service-worker.js`) is provided for advanced caching strategies:
- Cache-first for app shell
- Network-first for dynamic content
- Stale-while-revalidate for assets
- Offline fallback page

**Note**: Flutter's service worker is used by default. The custom service worker is optional and can be registered manually if needed.

### Service Worker Updates

The app checks for service worker updates:
- On page load
- Every 5 minutes (periodic check)
- On navigation

Users are notified when updates are available.

## Building for Web

### Step 1: Clean Previous Builds

```bash
flutter clean
```

### Step 2: Get Dependencies

```bash
flutter pub get
```

### Step 3: Build Web App

**Using Script (Recommended)**:
```bash
# Linux/Mac
./scripts/build_web.sh

# Windows
.\scripts\build_web.ps1
```

**Manual Build**:
```bash
flutter build web --release \
  --base-href / \
  --tree-shake-icons \
  --web-renderer canvaskit
```

### Step 4: Verify Build

The build script automatically verifies:
- ✅ Essential files (index.html, manifest.json, flutter.js, main.dart.js)
- ✅ PWA files (manifest.json, service worker, icons)
- ✅ Manifest structure and required fields
- ✅ Service worker registration

### Step 5: Test Locally

```bash
# Navigate to build output
cd build/web

# Start local server
# Python 3
python3 -m http.server 8000

# Python 2
python -m SimpleHTTPServer 8000

# Node.js (http-server)
npx http-server -p 8000

# Open in browser
# http://localhost:8000
```

## Deployment Platforms

### GitHub Pages

GitHub Pages is free for public repositories and provides:
- ✅ Free hosting
- ✅ Custom domain support
- ✅ HTTPS by default
- ✅ Automatic deployment via GitHub Actions

#### Prerequisites

1. Repository on GitHub
2. GitHub Pages enabled in repository settings
3. Git configured locally

#### Deployment Steps

**Using Script (Recommended)**:

```bash
# Linux/Mac
./scripts/deploy_github_pages.sh

# Windows
.\scripts\deploy_github_pages.ps1
```

**Manual Deployment**:

1. Build the web app:
   ```bash
   ./scripts/build_web.sh
   ```

2. Create/checkout gh-pages branch:
   ```bash
   git checkout --orphan gh-pages
   git rm -rf .
   ```

3. Copy build files:
   ```bash
   cp -r build/web/* .
   ```

4. Create .nojekyll file:
   ```bash
   touch .nojekyll
   ```

5. Commit and push:
   ```bash
   git add -A
   git commit -m "Deploy to GitHub Pages"
   git push origin gh-pages --force
   ```

#### Configuration

**Base Href**: For repository subdirectory deployment:
```bash
./scripts/deploy_github_pages.sh --base-href "/repository-name/"
```

**Custom Domain**: Add `CNAME` file in `web/` directory:
```
yourdomain.com
```

#### GitHub Actions (Automatic Deployment)

Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy to GitHub Pages

on:
  push:
    branches: [ master ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: 'stable'
          channel: 'stable'
      
      - run: flutter pub get
      - run: flutter build web --release --base-href / --tree-shake-icons --web-renderer canvaskit
      
      - uses: peaceiris/actions-gh-pages@v3
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          publish_dir: ./build/web
```

#### URL Format

- **Repository**: `https://github.com/username/repo`
- **Pages URL**: `https://username.github.io/repo/`

### Netlify

Netlify provides:
- ✅ Free tier with generous limits
- ✅ Automatic deployments from Git
- ✅ Custom domain support
- ✅ HTTPS by default
- ✅ Edge functions and serverless functions

#### Prerequisites

1. Netlify account (free)
2. Netlify CLI installed (optional)
   ```bash
   npm install -g netlify-cli
   ```

#### Configuration File

`netlify.toml` is already configured with:
- Build command
- Publish directory
- Redirects for SPA routing
- Headers for PWA and security
- Cache control

#### Deployment Methods

**Method 1: Netlify CLI**

```bash
# Linux/Mac
./scripts/deploy_netlify.sh

# Windows
.\scripts\deploy_netlify.ps1
```

**Method 2: Netlify Dashboard**

1. Go to [Netlify Dashboard](https://app.netlify.com)
2. Click "New site from Git"
3. Connect your repository
4. Configure build settings:
   - **Build command**: `flutter build web --release --base-href / --tree-shake-icons --web-renderer canvaskit`
   - **Publish directory**: `build/web`
5. Click "Deploy site"

**Method 3: Drag and Drop**

1. Build the web app:
   ```bash
   ./scripts/build_web.sh
   ```
2. Go to [Netlify Drop](https://app.netlify.com/drop)
3. Drag and drop the `build/web` folder

#### Environment Variables

Set in Netlify Dashboard → Site Settings → Environment Variables:

- `FLUTTER_VERSION`: `stable`
- `FLUTTER_WEB_USE_SKIA`: `true`

#### Custom Domain

1. Go to Site Settings → Domain Management
2. Add custom domain
3. Configure DNS as instructed
4. Enable HTTPS (automatic)

### Vercel

Vercel provides:
- ✅ Free tier with excellent performance
- ✅ Automatic deployments from Git
- ✅ Custom domain support
- ✅ HTTPS by default
- ✅ Edge Network (CDN)

#### Prerequisites

1. Vercel account (free)
2. Vercel CLI installed (optional)
   ```bash
   npm install -g vercel
   ```

#### Configuration File

`web/vercel.json` is already configured with:
- Build command
- Output directory
- Headers for PWA and security
- Rewrites for SPA routing

#### Deployment Methods

**Method 1: Vercel CLI**

```bash
# Linux/Mac
./scripts/deploy_vercel.sh

# Windows
.\scripts\deploy_vercel.ps1
```

**Method 2: Vercel Dashboard**

1. Go to [Vercel Dashboard](https://vercel.com/dashboard)
2. Click "Import Project"
3. Connect your repository
4. Configure build settings:
   - **Framework Preset**: Other
   - **Build Command**: `flutter build web --release --base-href / --tree-shake-icons --web-renderer canvaskit`
   - **Output Directory**: `build/web`
5. Click "Deploy"

**Method 3: Vercel CLI (from project root)**

```bash
vercel --prod
```

#### Custom Domain

1. Go to Project Settings → Domains
2. Add custom domain
3. Configure DNS as instructed
4. HTTPS is automatic

## Testing PWA

### Installability Test

1. Open the deployed app in Chrome/Edge
2. Look for install prompt or install icon in address bar
3. Click "Install" to add to home screen
4. Verify app opens in standalone mode

### Offline Test

1. Open DevTools (F12)
2. Go to Application → Service Workers
3. Check service worker is registered and active
4. Go to Network tab
5. Enable "Offline" mode
6. Refresh page - app should still work

### Lighthouse Test

1. Open DevTools → Lighthouse
2. Select "Progressive Web App"
3. Click "Generate report"
4. Verify:
   - ✅ Installable
   - ✅ Offline support
   - ✅ Fast load time
   - ✅ Responsive design

### Manual PWA Checks

- ✅ Manifest file loads correctly
- ✅ Icons display properly
- ✅ App opens in standalone mode
- ✅ Service worker caches assets
- ✅ App works offline
- ✅ Update notifications work

## Troubleshooting

### Build Issues

**Problem**: Build fails with "web renderer not found"
- **Solution**: Ensure Flutter web is enabled: `flutter config --enable-web`

**Problem**: Large bundle size
- **Solution**: Use `--tree-shake-icons` and `--web-renderer canvaskit`

**Problem**: Icons missing
- **Solution**: Generate icons using scripts in `web/icons/` directory

### PWA Issues

**Problem**: App not installable
- **Solution**: 
  - Check manifest.json is valid JSON
  - Verify icons exist (192x192 and 512x512 required)
  - Ensure HTTPS is enabled (required for PWA)
  - Check service worker is registered

**Problem**: Service worker not updating
- **Solution**: 
  - Clear browser cache
  - Unregister old service worker in DevTools
  - Hard refresh (Ctrl+Shift+R)

**Problem**: Offline mode not working
- **Solution**:
  - Check service worker is active
  - Verify assets are cached
  - Check console for errors

### Deployment Issues

**Problem**: GitHub Pages shows 404
- **Solution**: 
  - Ensure `.nojekyll` file exists
  - Check base href matches repository path
  - Verify 404.html exists

**Problem**: Netlify build fails
- **Solution**:
  - Check Flutter version in netlify.toml
  - Verify build command is correct
  - Check build logs in Netlify dashboard

**Problem**: Vercel deployment fails
- **Solution**:
  - Verify vercel.json is valid
  - Check build command in project settings
  - Review build logs in Vercel dashboard

### Performance Issues

**Problem**: Slow initial load
- **Solution**:
  - Enable compression (gzip/brotli)
  - Use CDN for static assets
  - Implement code splitting (if needed)

**Problem**: Large main.dart.js
- **Solution**:
  - Use `--tree-shake-icons`
  - Remove unused dependencies
  - Consider lazy loading

## Best Practices

1. **Always test locally** before deploying
2. **Use HTTPS** (required for PWA)
3. **Optimize images** before adding to assets
4. **Monitor bundle size** (aim for < 5MB)
5. **Test on multiple browsers** (Chrome, Firefox, Safari, Edge)
6. **Test on mobile devices** (iOS and Android)
7. **Keep dependencies updated**
8. **Use semantic versioning** for releases
9. **Document custom configurations**
10. **Monitor performance** with Lighthouse

## Additional Resources

- [Flutter Web Documentation](https://docs.flutter.dev/platform-integration/web)
- [PWA Documentation](https://web.dev/progressive-web-apps/)
- [Service Worker API](https://developer.mozilla.org/en-US/docs/Web/API/Service_Worker_API)
- [Web App Manifest](https://developer.mozilla.org/en-US/docs/Web/Manifest)
- [GitHub Pages Documentation](https://docs.github.com/en/pages)
- [Netlify Documentation](https://docs.netlify.com/)
- [Vercel Documentation](https://vercel.com/docs)

## Support

For issues or questions:
1. Check this documentation
2. Review build/deployment logs
3. Check Flutter web documentation
4. Open an issue on GitHub

---

**Last Updated**: 2024
**Version**: 3.1.0
