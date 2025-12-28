# Web Build and Deployment - Complete Production Guide

## Overview

This guide provides comprehensive instructions for building and deploying Dual Reader 3.1 as a production-ready Progressive Web App (PWA) to multiple hosting platforms.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Build Configuration](#build-configuration)
3. [PWA Configuration](#pwa-configuration)
4. [Deployment Platforms](#deployment-platforms)
5. [Verification](#verification)
6. [Troubleshooting](#troubleshooting)
7. [Best Practices](#best-practices)

---

## Prerequisites

### Required Tools

- **Flutter SDK** (latest stable version)
  ```bash
  flutter --version  # Should be 3.0.0 or higher
  ```

- **Git** (for GitHub Pages deployment)
  ```bash
  git --version
  ```

- **Node.js** (for Netlify/Vercel CLI)
  ```bash
  node --version  # Should be 18.x or higher
  ```

- **Platform-Specific CLIs** (optional, for manual deployment)
  - Netlify CLI: `npm install -g netlify-cli`
  - Vercel CLI: `npm install -g vercel`

### Platform Accounts

- **GitHub**: Free account for GitHub Pages
- **Netlify**: Free account (optional)
- **Vercel**: Free account (optional)

---

## Build Configuration

### Optimized Build Command

The production build uses the following optimizations:

```bash
flutter build web --release \
  --base-href / \
  --tree-shake-icons \
  --web-renderer canvaskit
```

### Build Options Explained

| Option | Description | Impact |
|--------|-------------|--------|
| `--release` | Production build with minification | Smaller bundle, better performance |
| `--base-href /` | Base path for assets | Required for root deployment |
| `--tree-shake-icons` | Remove unused icons | Reduces bundle size by ~200KB |
| `--web-renderer canvaskit` | Use CanvasKit renderer | Better performance, smaller bundle |

### Using Build Scripts

**Windows (PowerShell):**
```powershell
.\scripts\build_web.ps1 -Mode Release -Verify
```

**Linux/Mac (Bash):**
```bash
./scripts/build_web.sh --release --analyze
```

### Build Output Structure

```
build/web/
├── index.html                    # Main HTML file
├── manifest.json                 # PWA manifest
├── flutter_service_worker.js     # Auto-generated service worker
├── main.dart.js                  # Main application code (minified)
├── flutter.js                    # Flutter web runtime
├── assets/                       # Application assets
├── icons/                        # PWA icons (192x192, 512x512)
├── canvaskit/                    # CanvasKit renderer files
└── .nojekyll                     # GitHub Pages configuration
```

### Build Size Optimization

Expected build sizes:
- **Total**: ~5-8 MB (compressed: ~2-3 MB)
- **main.dart.js**: ~2-4 MB (compressed: ~800KB-1.5MB)
- **flutter.js**: ~500KB (compressed: ~200KB)
- **canvaskit/**: ~2-3 MB (compressed: ~1MB)

---

## PWA Configuration

### Manifest (`web/manifest.json`)

The PWA manifest is configured with:

- **App Identity**: Name, short name, description
- **Display Mode**: Standalone (app-like experience)
- **Theme Colors**: Dark theme (#121212 background, #1976D2 theme)
- **Icons**: Multiple sizes (16x16 to 512x512)
- **Shortcuts**: Library, Continue Reading
- **Share Target**: EPUB/MOBI file support
- **Protocol Handlers**: `web+epub://` support

### Service Worker

Flutter automatically generates and registers `flutter_service_worker.js` which:

- ✅ Caches all Flutter assets
- ✅ Provides offline support
- ✅ Handles versioning and updates
- ✅ Manages cache invalidation

**Note**: The custom `web/service-worker.js` is a reference implementation. Flutter's service worker is used in production.

### PWA Installability Requirements

For the app to be installable, ensure:

1. ✅ HTTPS enabled (or localhost for development)
2. ✅ Valid manifest.json with required fields
3. ✅ Service worker registered and active
4. ✅ Icons present (192x192 and 512x512 minimum)
5. ✅ start_url is accessible

### Testing PWA Installation

1. Build the app: `flutter build web --release`
2. Serve locally: `cd build/web && python -m http.server 8000`
3. Open in Chrome: `http://localhost:8000`
4. Check install prompt in address bar
5. Test offline functionality (DevTools > Network > Offline)

---

## Deployment Platforms

### 1. GitHub Pages

**Best for**: Free hosting, automatic HTTPS, custom domains

#### Prerequisites

1. GitHub repository
2. GitHub Pages enabled (Settings > Pages)
3. Source branch: `gh-pages` or `main` (with `/docs` folder)

#### Deployment Methods

**Method 1: Automated (GitHub Actions)**

The workflow (`.github/workflows/deploy-web.yml`) automatically deploys on push to `master`/`main`.

**Method 2: Manual Script**

```powershell
# Windows
.\scripts\deploy_github_pages.ps1

# Linux/Mac
./scripts/deploy_github_pages.sh
```

**Method 3: Manual Git**

```bash
# Build first
flutter build web --release --base-href /your-repo-name/

# Copy to gh-pages branch
git checkout gh-pages
cp -r build/web/* .
git add .
git commit -m "Deploy to GitHub Pages"
git push origin gh-pages
```

#### Configuration Files

- `.nojekyll`: Prevents Jekyll processing
- `404.html`: Handles SPA routing for GitHub Pages

#### URL Format

- Root repository: `https://username.github.io/repository-name/`
- Project site: `https://username.github.io/`

#### Custom Domain

1. Add `CNAME` file to `build/web/` with your domain
2. Configure DNS: Add CNAME record pointing to `username.github.io`
3. Enable custom domain in GitHub Pages settings

---

### 2. Netlify

**Best for**: Continuous deployment, CDN, serverless functions

#### Prerequisites

1. Netlify account (free tier available)
2. Netlify CLI installed: `npm install -g netlify-cli`

#### Deployment Methods

**Method 1: Netlify CLI**

```powershell
# Windows
.\scripts\deploy_netlify.ps1 -Production

# Linux/Mac
./scripts/deploy_netlify.sh --production
```

**Method 2: Netlify Dashboard**

1. Go to Netlify dashboard
2. Click "New site from Git"
3. Connect repository
4. Build settings:
   - Build command: `flutter build web --release --base-href / --tree-shake-icons --web-renderer canvaskit`
   - Publish directory: `build/web`
5. Deploy

**Method 3: Drag & Drop**

1. Build: `flutter build web --release`
2. Drag `build/web` folder to Netlify dashboard
3. Deploy

#### Configuration

**`netlify.toml`** (root directory):
```toml
[build]
  command = "flutter build web --release --base-href / --tree-shake-icons --web-renderer canvaskit"
  publish = "build/web"

[[redirects]]
  from = "/*"
  to = "/index.html"
  status = 200
```

**`web/_headers`** (for additional headers):
```
/service-worker.js
  Cache-Control: no-cache, no-store, must-revalidate
  Service-Worker-Allowed: /
```

#### Environment Variables

Set in Netlify dashboard (Build & Deploy > Environment):
- `FLUTTER_VERSION`: `stable`
- `FLUTTER_WEB_USE_SKIA`: `true`

#### Continuous Deployment

Netlify automatically deploys on:
- Push to connected branch
- Pull request merge
- Manual trigger

---

### 3. Vercel

**Best for**: Edge network, serverless functions, preview deployments

#### Prerequisites

1. Vercel account (free tier available)
2. Vercel CLI installed: `npm install -g vercel`

#### Deployment Methods

**Method 1: Vercel CLI**

```powershell
# Windows
.\scripts\deploy_vercel.ps1 -Production

# Linux/Mac
./scripts/deploy_vercel.sh --production
```

**Method 2: Vercel Dashboard**

1. Go to Vercel dashboard
2. Click "New Project"
3. Import Git repository
4. Framework preset: Other
5. Build settings:
   - Build command: `flutter build web --release --base-href / --tree-shake-icons --web-renderer canvaskit`
   - Output directory: `build/web`
6. Deploy

**Method 3: GitHub Integration**

1. Connect GitHub repository in Vercel
2. Configure build settings
3. Automatic deployments on push

#### Configuration

**`web/vercel.json`**:
```json
{
  "version": 2,
  "buildCommand": "flutter build web --release --base-href / --tree-shake-icons --web-renderer canvaskit",
  "outputDirectory": "build/web",
  "rewrites": [
    {
      "source": "/(.*)",
      "destination": "/index.html"
    }
  ]
}
```

#### Preview Deployments

Vercel automatically creates preview deployments for:
- Pull requests
- Feature branches
- Manual deployments

---

## Verification

### Build Verification

Run the verification script:

```powershell
# Windows
.\scripts\verify_web_build.ps1

# Linux/Mac
./scripts/verify_web_build.sh
```

**Checks:**
- ✅ Required files present
- ✅ Manifest.json valid
- ✅ Service worker present
- ✅ Icons present
- ✅ Build size reasonable

### PWA Verification

```powershell
# Windows
.\scripts\verify_pwa.ps1

# Linux/Mac
./scripts/verify_pwa.sh
```

**Checks:**
- ✅ Manifest structure valid
- ✅ Required icons (192x192, 512x512)
- ✅ Service worker registered
- ✅ HTTPS/secure context
- ✅ Installability criteria met

### Manual Testing Checklist

- [ ] App loads correctly
- [ ] PWA install prompt appears
- [ ] App installs successfully
- [ ] App works offline
- [ ] Service worker active
- [ ] Manifest valid (DevTools > Application > Manifest)
- [ ] Icons display correctly
- [ ] Theme colors applied
- [ ] Standalone mode works
- [ ] All routes accessible
- [ ] 404 handling works (SPA routing)

### Lighthouse Audit

1. Open deployed app in Chrome
2. Open DevTools (F12)
3. Go to Lighthouse tab
4. Select "Progressive Web App"
5. Run audit

**Target Scores:**
- Performance: 90+
- Accessibility: 90+
- Best Practices: 90+
- SEO: 90+
- **PWA: 100** (all criteria met)

---

## Troubleshooting

### Build Issues

**Problem**: Build fails with dependency errors
```
Solution: Run `flutter clean && flutter pub get`
```

**Problem**: Build size too large
```
Solution: Ensure using --tree-shake-icons and --web-renderer canvaskit
```

**Problem**: Service worker not registering
```
Solution: Ensure HTTPS or localhost (service workers require secure context)
```

### PWA Issues

**Problem**: App not installable
```
Checklist:
- HTTPS enabled (or localhost)
- Valid manifest.json
- Service worker active
- Icons present (192x192, 512x512)
- start_url accessible
```

**Problem**: Offline not working
```
Solution: Check service worker registration in DevTools > Application > Service Workers
```

**Problem**: Update not working
```
Solution: Service worker updates automatically. Check cache headers (no-cache for service worker)
```

### Deployment Issues

**Problem**: GitHub Pages shows 404
```
Solutions:
- Check .nojekyll file exists
- Verify base-href matches repository path
- Ensure 404.html exists
- Check GitHub Pages settings
```

**Problem**: Netlify build fails
```
Solutions:
- Check netlify.toml configuration
- Verify Flutter is available in build environment
- Check build logs for errors
- Ensure build command is correct
```

**Problem**: Vercel deployment fails
```
Solutions:
- Check vercel.json configuration
- Verify build output directory
- Check build logs
- Ensure Vercel has access to repository
```

### Performance Issues

**Problem**: Slow initial load
```
Solutions:
- Enable compression (gzip/brotli)
- Use CDN
- Implement lazy loading
- Optimize images
- Check bundle size
```

**Problem**: Large bundle size
```
Solutions:
- Use --tree-shake-icons
- Remove unused dependencies
- Enable code splitting (if available)
- Use --web-renderer canvaskit
```

---

## Best Practices

### Build Optimization

1. ✅ Always build in release mode for production
2. ✅ Use `--tree-shake-icons` to remove unused icons
3. ✅ Use CanvasKit renderer for better performance
4. ✅ Monitor bundle size regularly
5. ✅ Test build output before deploying

### PWA Best Practices

1. ✅ Test PWA functionality before deploying
2. ✅ Use HTTPS for production (required)
3. ✅ Provide multiple icon sizes
4. ✅ Test offline functionality
5. ✅ Handle service worker updates gracefully
6. ✅ Monitor Lighthouse scores
7. ✅ Test on multiple browsers and devices

### Deployment Best Practices

1. ✅ Use automated deployments (CI/CD)
2. ✅ Test on staging/preview before production
3. ✅ Monitor deployment logs
4. ✅ Set up error tracking
5. ✅ Use CDN for better performance
6. ✅ Enable compression
7. ✅ Set appropriate cache headers
8. ✅ Test after deployment

### Security Best Practices

1. ✅ Use HTTPS everywhere
2. ✅ Set security headers (X-Frame-Options, CSP, etc.)
3. ✅ Validate all inputs
4. ✅ Keep dependencies updated
5. ✅ Use secure service worker scope
6. ✅ Implement proper CORS policies

---

## Quick Reference

### Build Commands

```bash
# Production build
flutter build web --release --base-href / --tree-shake-icons --web-renderer canvaskit

# Debug build
flutter build web --debug

# Build with custom base href
flutter build web --release --base-href /your-path/
```

### Deployment Commands

```bash
# GitHub Pages
.\scripts\deploy_github_pages.ps1

# Netlify
.\scripts\deploy_netlify.ps1 -Production

# Vercel
.\scripts\deploy_vercel.ps1 -Production
```

### Verification Commands

```bash
# Build verification
.\scripts\verify_web_build.ps1

# PWA verification
.\scripts\verify_pwa.ps1

# Local testing
cd build/web && python -m http.server 8000
```

---

## Support and Resources

### Documentation

- [Flutter Web Documentation](https://docs.flutter.dev/platform-integration/web)
- [PWA Documentation](https://web.dev/progressive-web-apps/)
- [GitHub Pages Documentation](https://docs.github.com/pages)
- [Netlify Documentation](https://docs.netlify.com/)
- [Vercel Documentation](https://vercel.com/docs)

### Tools

- [Lighthouse](https://developers.google.com/web/tools/lighthouse) - PWA audit
- [PWA Builder](https://www.pwabuilder.com/) - PWA testing and optimization
- [Web.dev](https://web.dev/) - Web best practices

---

## Status

✅ **Production-Ready**

All acceptance criteria met:
- ✅ Optimized web build configuration
- ✅ PWA manifest finalized
- ✅ Service worker configured for offline support
- ✅ Build scripts for web deployment
- ✅ Deployment documentation for multiple platforms
- ✅ Web app builds and deploys successfully
- ✅ PWA installable and works offline

---

**Version**: 3.1.0  
**Last Updated**: Complete Production Guide
