# Web Build and Deployment - Complete Guide

## Overview

This guide provides complete instructions for building and deploying Dual Reader 3.1 as a Progressive Web App (PWA) to multiple hosting platforms.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Build Configuration](#build-configuration)
3. [PWA Configuration](#pwa-configuration)
4. [Service Worker](#service-worker)
5. [Deployment Platforms](#deployment-platforms)
   - [GitHub Pages](#github-pages)
   - [Netlify](#netlify)
   - [Vercel](#vercel)
6. [Build Verification](#build-verification)
7. [Troubleshooting](#troubleshooting)
8. [Best Practices](#best-practices)

## Prerequisites

### Required Tools

- **Flutter SDK** (latest stable version)
  - Verify: `flutter --version`
  - Install: [Flutter Installation Guide](https://docs.flutter.dev/get-started/install)
  
- **Git** (for deployment)
  - Verify: `git --version`
  
- **Node.js and npm** (for Netlify/Vercel CLI, optional)
  - Verify: `node --version` and `npm --version`
  - Install: [Node.js Download](https://nodejs.org/)

### Platform-Specific Requirements

- **GitHub Pages:** GitHub account and repository
- **Netlify:** Netlify account (free tier available)
- **Vercel:** Vercel account (free tier available)

## Build Configuration

### Optimized Build Command

The production build uses optimized flags for performance and size:

```bash
flutter build web --release \
  --base-href / \
  --tree-shake-icons \
  --web-renderer canvaskit
```

**Build Flags Explained:**

- `--release`: Creates optimized production build with minification
- `--base-href /`: Sets the base URL path (adjust for subdirectory deployments)
- `--tree-shake-icons`: Removes unused Material icons to reduce bundle size (~200KB savings)
- `--web-renderer canvaskit`: Uses CanvasKit renderer for better performance and smaller bundle

### Using Build Scripts

**Windows (PowerShell):**
```powershell
# Production build
.\scripts\build_web.ps1 -Mode Release -BaseHref "/"

# With analysis
.\scripts\build_web.ps1 -Mode Release -Analyze

# Custom base href for subdirectory
.\scripts\build_web.ps1 -Mode Release -BaseHref "/dual_reader_3.1/"
```

**Linux/macOS:**
```bash
# Production build
./scripts/build_web.sh --release --base-href "/"

# With analysis
./scripts/build_web.sh --release --analyze

# Custom base href for subdirectory
./scripts/build_web.sh --release --base-href "/dual_reader_3.1/"
```

### Build Output Structure

After building, the `build/web` directory contains:

```
build/web/
├── index.html              # Main HTML file
├── main.dart.js           # Compiled Dart code (minified)
├── flutter.js             # Flutter web engine
├── flutter_service_worker.js  # Service worker (auto-generated)
├── manifest.json          # PWA manifest
├── favicon.ico            # Favicon
├── icons/                 # PWA icons (various sizes)
│   ├── icon-16x16.png
│   ├── icon-192x192.png
│   └── icon-512x512.png
├── assets/                # App assets
└── canvaskit/             # CanvasKit renderer files
```

### Build Size Optimization

**Expected Build Sizes:**

- **Initial JavaScript bundle:** ~2-3 MB (gzipped: ~800KB-1.2MB)
- **Total build directory:** ~5-8 MB
- **First load (gzipped):** ~1-1.5 MB

**Optimization Techniques Used:**

1. **Tree-shaking:** Removes unused code and icons
2. **Minification:** Compressed JavaScript and CSS
3. **Code splitting:** Lazy loading of resources
4. **Asset optimization:** Compressed images and fonts
5. **CanvasKit CDN:** Uses CDN-hosted CanvasKit for smaller initial bundle

## PWA Configuration

### Manifest File

The PWA manifest (`web/manifest.json`) is fully configured with:

- ✅ **App metadata:** Name, short name, description
- ✅ **Display mode:** Standalone for app-like experience
- ✅ **Theme colors:** Dark theme support (#121212 background, #1976D2 theme)
- ✅ **Icons:** Complete icon set (16x16 to 512x512)
- ✅ **Shortcuts:** Quick actions (Library, Continue Reading)
- ✅ **Share target:** Accept EPUB/MOBI files via share
- ✅ **Protocol handlers:** Handle `web+epub://` links
- ✅ **Screenshots:** App screenshots for app stores

### Manifest Verification

**Online Validator:**
- [Web Manifest Validator](https://manifest-validator.appspot.com/)
- [PWA Builder](https://www.pwabuilder.com/)

**Browser DevTools:**
1. Open Chrome DevTools (F12)
2. Go to Application > Manifest
3. Verify all fields are valid
4. Check for any warnings

**Required Icons:**

Ensure these icon sizes exist in `web/icons/`:
- 16x16, 32x32, 72x72, 96x96, 128x128
- 144x144, 152x152, 192x192, 384x384, 512x512

### PWA Installability

The app is installable as a PWA when all these conditions are met:

- ✅ Served over HTTPS (or localhost for development)
- ✅ Valid `manifest.json` present
- ✅ Service worker registered and active
- ✅ Icons provided (at least 192x192 and 512x512)
- ✅ Start URL is accessible

**Testing Installability:**

1. Open app in Chrome/Edge
2. Look for install icon in address bar
3. Or check DevTools > Application > Manifest > "Add to homescreen"

## Service Worker

### Flutter Service Worker

Flutter automatically generates `flutter_service_worker.js` during build. This handles:

- **Asset caching:** Caches Flutter assets for offline use
- **Version management:** Handles updates automatically
- **Offline support:** Serves cached content when offline
- **Update detection:** Checks for updates periodically

### Service Worker Features

**Automatic Registration:**
- Registered in `index.html` during Flutter build
- No manual registration needed

**Caching Strategy:**
- **App shell:** Cache-first (instant load)
- **Assets:** Stale-while-revalidate (fast with updates)
- **Dynamic content:** Network-first (always fresh)

**Update Process:**
1. New version detected on page load
2. Service worker downloads in background
3. User sees update notification
4. Reload to activate new version

### Service Worker Verification

**Check Registration:**
1. Open Chrome DevTools (F12)
2. Go to Application > Service Workers
3. Verify service worker is registered and active
4. Check "Update on reload" for testing

**Test Offline Mode:**
1. Open DevTools > Network
2. Enable "Offline" checkbox
3. Reload page
4. App should load from cache

## Deployment Platforms

### GitHub Pages

#### Prerequisites

- GitHub repository
- GitHub Pages enabled in repository settings
- Git configured with credentials

#### Deployment Method 1: Automated Script (Recommended)

**Windows:**
```powershell
.\scripts\deploy_github_pages.ps1 -BaseHref "/your-repo-name/"
```

**Linux/macOS:**
```bash
./scripts/deploy_github_pages.sh --base-href "/your-repo-name/"
```

**What the script does:**
1. Builds the web app with correct base-href
2. Creates `.nojekyll` file (required for GitHub Pages)
3. Creates `404.html` for SPA routing
4. Deploys to `gh-pages` branch
5. Returns to original branch

#### Deployment Method 2: GitHub Actions (Automated)

The workflow (`.github/workflows/deploy-web.yml`) automatically deploys on push to `master`/`main` branch.

**Setup:**
1. Push code to GitHub
2. Go to repository Settings > Pages
3. Select source: "GitHub Actions"
4. Push to trigger deployment

**Manual Trigger:**
1. Go to Actions tab
2. Select "Deploy Web App" workflow
3. Click "Run workflow"
4. Select platform: "github-pages"

#### Configuration

**Base Href:**
- Root domain: `/`
- Subdirectory: `/repository-name/`

**Custom Domain:**
1. Add `CNAME` file in `build/web`:
   ```
   yourdomain.com
   ```
2. Configure DNS (CNAME record)
3. Enable HTTPS in GitHub Pages settings

**HTTPS:**
- Automatically enabled by GitHub Pages
- Required for PWA functionality

#### Post-Deployment

1. Wait 1-5 minutes for GitHub Pages to update
2. Visit: `https://username.github.io/repository-name/`
3. Verify PWA installability
4. Test offline functionality

### Netlify

#### Prerequisites

- Netlify account ([Sign up](https://app.netlify.com/signup))
- Netlify CLI (optional): `npm install -g netlify-cli`

#### Deployment Method 1: Git Integration (Recommended)

**Setup:**
1. Log in to [Netlify](https://app.netlify.com)
2. Click "Add new site" > "Import an existing project"
3. Connect GitHub/GitLab/Bitbucket repository
4. Configure build settings:
   - **Build command:** `flutter build web --release --base-href / --tree-shake-icons --web-renderer canvaskit`
   - **Publish directory:** `build/web`
   - **Environment variables:**
     - `FLUTTER_VERSION=stable`
     - `FLUTTER_WEB_USE_SKIA=true`
5. Click "Deploy site"

**Automatic Deployments:**
- Deploys automatically on push to main branch
- Creates preview deployments for pull requests

#### Deployment Method 2: Netlify CLI

**Windows:**
```powershell
.\scripts\deploy_netlify.ps1 -Production
```

**Linux/macOS:**
```bash
./scripts/deploy_netlify.sh --production
```

**Manual CLI Deployment:**
```bash
# Build first
flutter build web --release --base-href / --tree-shake-icons --web-renderer canvaskit

# Deploy
netlify deploy --dir=build/web --prod
```

#### Configuration File

`netlify.toml` is pre-configured with:
- Build command and publish directory
- Redirects for SPA routing
- Headers for service worker and manifest
- Security headers
- Cache policies

**Custom Configuration:**
Edit `netlify.toml` in project root to customize:
- Build settings
- Redirects
- Headers
- Environment variables

#### Post-Deployment

1. Visit your Netlify site URL
2. Verify HTTPS is enabled (automatic)
3. Test PWA installability
4. Check build logs in Netlify dashboard

### Vercel

#### Prerequisites

- Vercel account ([Sign up](https://vercel.com/signup))
- Vercel CLI (optional): `npm install -g vercel`

#### Deployment Method 1: Git Integration (Recommended)

**Setup:**
1. Log in to [Vercel](https://vercel.com)
2. Click "Add New Project"
3. Import GitHub/GitLab/Bitbucket repository
4. Configure build settings:
   - **Framework Preset:** Other
   - **Build Command:** `flutter build web --release --base-href / --tree-shake-icons --web-renderer canvaskit`
   - **Output Directory:** `build/web`
   - **Install Command:** (leave empty)
5. Add environment variables:
   - `FLUTTER_VERSION=stable`
6. Click "Deploy"

**Automatic Deployments:**
- Deploys automatically on push to main branch
- Creates preview deployments for pull requests

#### Deployment Method 2: Vercel CLI

**Windows:**
```powershell
.\scripts\deploy_vercel.ps1 -Production
```

**Linux/macOS:**
```bash
./scripts/deploy_vercel.sh --production
```

**Manual CLI Deployment:**
```bash
# Build first
flutter build web --release --base-href / --tree-shake-icons --web-renderer canvaskit

# Deploy
cd build/web
vercel --prod
```

#### Configuration File

`web/vercel.json` is pre-configured with:
- Build command and output directory
- Headers for service worker and manifest
- Security headers
- Rewrites for SPA routing

**Custom Configuration:**
Edit `web/vercel.json` to customize:
- Build settings
- Headers
- Rewrites
- Redirects

#### Post-Deployment

1. Visit your Vercel deployment URL
2. Verify HTTPS is enabled (automatic)
3. Test PWA installability
4. Check build logs in Vercel dashboard

## Build Verification

### Verification Checklist

After building, verify:

- [ ] Build completed without errors
- [ ] `build/web` directory exists
- [ ] `index.html` is present and valid
- [ ] `manifest.json` is present and valid
- [ ] `flutter_service_worker.js` is generated
- [ ] Icons are present in `icons/` directory
- [ ] App loads in browser
- [ ] PWA install prompt appears (if conditions met)
- [ ] Service worker registers successfully
- [ ] Offline functionality works

### Verification Script

**Windows:**
```powershell
.\scripts\verify_web_build.ps1
```

**Linux/macOS:**
```bash
./scripts/verify_web_build.sh
```

The script checks:
- Build output directory exists
- Essential files are present
- File sizes are reasonable
- Manifest is valid JSON
- Service worker is present

### Manual Testing

**Local Testing:**
```bash
# Navigate to build directory
cd build/web

# Start local server
# Python 3
python3 -m http.server 8000

# Python 2
python -m SimpleHTTPServer 8000

# Node.js (with http-server)
npx http-server -p 8000

# Open in browser
# http://localhost:8000
```

**PWA Testing:**
1. Open Chrome DevTools (F12)
2. Go to Application tab
3. Check:
   - **Manifest:** All fields valid, icons present
   - **Service Workers:** Registered and active
   - **Cache Storage:** Assets cached
4. Test offline:
   - DevTools > Network > Offline
   - Reload page
   - App should load from cache

**Lighthouse Audit:**
1. Open Chrome DevTools (F12)
2. Go to Lighthouse tab
3. Select:
   - ✅ Performance
   - ✅ Accessibility
   - ✅ Best Practices
   - ✅ SEO
   - ✅ Progressive Web App
4. Click "Generate report"
5. Target scores:
   - PWA: 90+
   - Performance: 80+
   - Accessibility: 90+

## Troubleshooting

### Build Issues

**Problem: Build fails with "No pubspec.yaml found"**
- **Solution:** Ensure you're in the project root directory
- **Check:** `pwd` (Linux/Mac) or `Get-Location` (Windows)

**Problem: Build size is too large**
- **Solution:** Use `--tree-shake-icons` flag and ensure `--release` mode
- **Check:** Compare build sizes before/after optimization

**Problem: Icons missing after build**
- **Solution:** Ensure icons exist in `web/icons/` before building
- **Check:** List files in `web/icons/` directory

**Problem: CanvasKit not loading**
- **Solution:** Check internet connection (CDN required for first load)
- **Alternative:** Use HTML renderer: `--web-renderer html` (larger bundle)

### Deployment Issues

**Problem: GitHub Pages shows 404**
- **Solution:** Ensure base-href matches repository name and `404.html` exists
- **Check:** Verify `.nojekyll` file is present

**Problem: Service worker not updating**
- **Solution:** Clear browser cache and ensure service worker headers are correct
- **Check:** DevTools > Application > Service Workers > "Update on reload"

**Problem: PWA not installable**
- **Solution:** Verify HTTPS is enabled and manifest is valid
- **Check:** DevTools > Application > Manifest for errors

**Problem: Routes return 404**
- **Solution:** Ensure redirects/rewrites are configured for SPA routing
- **Check:** Platform-specific configuration files

### Performance Issues

**Problem: Slow initial load**
- **Solution:** Enable compression on hosting platform and use CDN
- **Check:** Network tab in DevTools for large files

**Problem: Large bundle size**
- **Solution:** Use `--tree-shake-icons` and consider code splitting
- **Check:** Analyze bundle with `flutter build web --release --analyze-size`

**Problem: Offline mode not working**
- **Solution:** Verify service worker is registered and caching assets
- **Check:** DevTools > Application > Cache Storage

## Best Practices

### Build Best Practices

1. **Always build in release mode** for production deployments
2. **Use tree-shaking** to reduce bundle size
3. **Test locally** before deploying
4. **Monitor build sizes** to catch regressions
5. **Use consistent base-href** across environments

### Deployment Best Practices

1. **Use automated deployments** (GitHub Actions, Netlify, Vercel)
2. **Test on staging** before production
3. **Verify PWA functionality** after deployment
4. **Monitor deployment logs** for errors
5. **Set up custom domains** with HTTPS

### PWA Best Practices

1. **Always use HTTPS** (required for PWA)
2. **Provide complete icon set** (all sizes)
3. **Test offline functionality** regularly
4. **Handle service worker updates** gracefully
5. **Monitor PWA install rates** and user feedback

### Security Best Practices

1. **Enable security headers** (configured in platform files)
2. **Use HTTPS** for all deployments
3. **Validate user inputs** in the app
4. **Keep dependencies updated** (`flutter pub upgrade`)
5. **Review build output** before deployment

## Additional Resources

- [Flutter Web Documentation](https://docs.flutter.dev/platform-integration/web)
- [PWA Documentation](https://web.dev/progressive-web-apps/)
- [Service Worker API](https://developer.mozilla.org/en-US/docs/Web/API/Service_Worker_API)
- [Web Manifest Specification](https://www.w3.org/TR/appmanifest/)
- [GitHub Pages Documentation](https://docs.github.com/en/pages)
- [Netlify Documentation](https://docs.netlify.com/)
- [Vercel Documentation](https://vercel.com/docs)

## Quick Reference

### Build Commands

```bash
# Production build
flutter build web --release --base-href / --tree-shake-icons --web-renderer canvaskit

# Debug build
flutter build web --debug

# With analysis
flutter build web --release --analyze-size
```

### Deployment Commands

```bash
# GitHub Pages
./scripts/deploy_github_pages.sh --base-href "/repo-name/"

# Netlify
./scripts/deploy_netlify.sh --production

# Vercel
./scripts/deploy_vercel.sh --production
```

### Verification Commands

```bash
# Verify build
./scripts/verify_web_build.sh

# Test locally
cd build/web && python3 -m http.server 8000
```

---

**Last Updated:** 2024
**Version:** 3.1.0
