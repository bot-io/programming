# Dual Reader 3.1 - Web Build and Deployment Guide

Complete guide for building and deploying Dual Reader 3.1 web app to static hosting platforms.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Build Configuration](#build-configuration)
3. [Local Testing](#local-testing)
4. [Deployment Platforms](#deployment-platforms)
   - [GitHub Pages](#github-pages)
   - [Netlify](#netlify)
   - [Vercel](#vercel)
5. [PWA Configuration](#pwa-configuration)
6. [Troubleshooting](#troubleshooting)
7. [Performance Optimization](#performance-optimization)

## Prerequisites

- Flutter SDK (latest stable version)
- Git
- Node.js (for Netlify/Vercel CLI deployment)
- Account on chosen hosting platform

## Build Configuration

### Optimized Build Command

The web app should be built with the following optimized flags:

```bash
flutter build web --release \
  --base-href / \
  --tree-shake-icons \
  --web-renderer canvaskit
```

**Build Flags Explained:**
- `--release`: Creates optimized production build
- `--base-href /`: Sets base path for assets (use `/your-repo-name/` for GitHub Pages subdirectory)
- `--tree-shake-icons`: Removes unused icons to reduce bundle size
- `--web-renderer canvaskit`: Uses CanvasKit renderer for better performance and consistency

### Using Build Scripts

**Windows (PowerShell):**
```powershell
.\web\build_web.ps1 -Release -Verify
```

**Linux/macOS (Bash):**
```bash
bash web/build_web.sh --release --verify
```

### Build Output

After building, the output will be in `build/web/` directory containing:
- `index.html` - Main HTML file
- `main.dart.js` - Compiled Dart code
- `flutter.js` - Flutter web runtime
- `flutter_service_worker.js` - Service worker for PWA
- `manifest.json` - PWA manifest
- `assets/` - App assets
- `icons/` - PWA icons
- `canvaskit/` - CanvasKit renderer files

## Local Testing

### Quick Test Server

**Python:**
```bash
cd build/web
python -m http.server 8000
# Open http://localhost:8000
```

**Node.js:**
```bash
cd build/web
npx serve -s . -p 8000
# Open http://localhost:8000
```

**PHP:**
```bash
cd build/web
php -S localhost:8000
# Open http://localhost:8000
```

### Testing PWA Features

1. **Open Chrome DevTools** (F12)
2. Go to **Application** tab
3. Check **Manifest** section for PWA installability
4. Check **Service Workers** section for registration
5. Test **Offline** mode using Network throttling

### PWA Installability Checklist

- ✅ HTTPS enabled (required for PWA)
- ✅ Valid `manifest.json` with required fields
- ✅ Service worker registered
- ✅ Icons present (192x192 and 512x512 minimum)
- ✅ `start_url` is accessible
- ✅ `scope` matches app structure

## Deployment Platforms

### GitHub Pages

#### Option 1: GitHub Actions (Recommended)

The repository includes a GitHub Actions workflow (`.github/workflows/deploy-web.yml`) that automatically builds and deploys on push to `master` or `main` branch.

**Setup:**
1. Go to repository **Settings** → **Pages**
2. Select **Source**: `GitHub Actions`
3. Push to `master` or `main` branch
4. Workflow will automatically build and deploy

**Manual Deployment:**
1. Go to **Actions** tab
2. Select **Build and Deploy Web App** workflow
3. Click **Run workflow**
4. Select platform: `github-pages`
5. Click **Run workflow**

#### Option 2: Manual Deployment

1. Build the web app:
   ```bash
   flutter build web --release --base-href /your-repo-name/
   ```

2. Copy `build/web/` contents to `gh-pages` branch or `docs/` folder

3. Push to repository:
   ```bash
   git subtree push --prefix build/web origin gh-pages
   ```

**GitHub Pages Configuration:**
- Base href should be `/` for root domain or `/repo-name/` for subdirectory
- Ensure `.nojekyll` file exists in root (prevents Jekyll processing)
- `404.html` file handles SPA routing

#### GitHub Pages Subdirectory Setup

If deploying to a subdirectory (e.g., `username.github.io/repo-name/`):

1. Update build command:
   ```bash
   flutter build web --release --base-href /repo-name/
   ```

2. Update `manifest.json`:
   ```json
   {
     "start_url": "/repo-name/",
     "scope": "/repo-name/"
   }
   ```

### Netlify

#### Option 1: Netlify CLI

1. Install Netlify CLI:
   ```bash
   npm install -g netlify-cli
   ```

2. Login:
   ```bash
   netlify login
   ```

3. Build and deploy:
   ```bash
   flutter build web --release --base-href /
   netlify deploy --dir=build/web --prod
   ```

#### Option 2: GitHub Integration (Recommended)

1. Connect repository to Netlify:
   - Go to [Netlify Dashboard](https://app.netlify.com)
   - Click **Add new site** → **Import an existing project**
   - Select your GitHub repository

2. Configure build settings:
   - **Build command**: `flutter build web --release --base-href / --tree-shake-icons --web-renderer canvaskit`
   - **Publish directory**: `build/web`
   - **Environment variables**: (optional)
     - `FLUTTER_VERSION`: `stable`
     - `FLUTTER_WEB_USE_SKIA`: `true`

3. Deploy:
   - Netlify will automatically build and deploy on every push
   - Or trigger manual deploy from dashboard

#### Option 3: GitHub Actions

Use the included GitHub Actions workflow:
1. Go to **Actions** tab
2. Select **Build and Deploy Web App** workflow
3. Click **Run workflow**
4. Select platform: `netlify`
5. Configure secrets:
   - `NETLIFY_AUTH_TOKEN`: Get from Netlify dashboard → User settings → Applications
   - `NETLIFY_SITE_ID`: Get from Site settings → General → Site details

**Netlify Configuration File:**

The `netlify.toml` file in the repository root configures:
- Build command and publish directory
- Redirects for SPA routing
- Headers for service worker and security
- Caching strategies

### Vercel

#### Option 1: Vercel CLI

1. Install Vercel CLI:
   ```bash
   npm install -g vercel
   ```

2. Login:
   ```bash
   vercel login
   ```

3. Build and deploy:
   ```bash
   flutter build web --release --base-href /
   cd build/web
   vercel --prod
   ```

#### Option 2: GitHub Integration (Recommended)

1. Connect repository to Vercel:
   - Go to [Vercel Dashboard](https://vercel.com/dashboard)
   - Click **Add New Project**
   - Import your GitHub repository

2. Configure build settings:
   - **Framework Preset**: Other
   - **Build Command**: `flutter build web --release --base-href / --tree-shake-icons --web-renderer canvaskit`
   - **Output Directory**: `build/web`
   - **Install Command**: `flutter pub get`

3. Deploy:
   - Vercel will automatically build and deploy on every push
   - Or trigger manual deploy from dashboard

#### Option 3: GitHub Actions

Use the included GitHub Actions workflow:
1. Go to **Actions** tab
2. Select **Build and Deploy Web App** workflow
3. Click **Run workflow**
4. Select platform: `vercel`
5. Configure secrets:
   - `VERCEL_TOKEN`: Get from Vercel dashboard → Settings → Tokens
   - `VERCEL_ORG_ID`: Get from Team settings
   - `VERCEL_PROJECT_ID`: Get from Project settings

**Vercel Configuration File:**

The `vercel.json` file in `web/` directory configures:
- Build command and output directory
- Headers for service worker and security
- Rewrites for SPA routing

## PWA Configuration

### Manifest.json

The `web/manifest.json` file contains:
- App name and description
- Icons (multiple sizes)
- Display mode (standalone)
- Theme colors
- Start URL and scope
- Shortcuts and share targets

**Required Fields:**
- `name` - Full app name
- `short_name` - Short app name
- `start_url` - Starting URL
- `display` - Display mode (standalone, fullscreen, etc.)
- `icons` - Array of icon objects (minimum 192x192 and 512x512)

### Service Worker

Flutter automatically generates `flutter_service_worker.js` during build. This handles:
- Asset caching
- Offline support
- Update management

**Service Worker Features:**
- Automatic registration in `index.html`
- Version-based caching
- Update notifications
- Offline fallback

### Icons

Required icon sizes (in `web/icons/`):
- 16x16, 32x32 (favicons)
- 72x72, 96x96, 128x128 (Android)
- 144x144, 152x152 (Windows)
- 192x192 (Android, PWA standard)
- 384x384, 512x512 (Splash screens, PWA)

**Generate Icons:**
```powershell
# Windows
.\web\generate_icons.ps1

# Or use browser-based generator
# Open web/icons/create_icons_browser.html
```

## Troubleshooting

### Build Issues

**Issue: Build fails with "No pubspec.yaml found"**
- Solution: Ensure you're running the command from the project root

**Issue: Large bundle size**
- Solution: Use `--tree-shake-icons` flag and check for unused assets

**Issue: Service worker not registering**
- Solution: Ensure HTTPS is enabled (required for service workers)

### Deployment Issues

**Issue: 404 errors on routes**
- Solution: Ensure redirect rules are configured (all routes → index.html)

**Issue: Assets not loading**
- Solution: Check `base-href` matches deployment path

**Issue: PWA not installable**
- Solution: Verify manifest.json is valid and accessible, check HTTPS

**Issue: Service worker not updating**
- Solution: Clear browser cache and check service worker headers

### Performance Issues

**Issue: Slow initial load**
- Solution: Enable compression, use CDN, optimize assets

**Issue: Large JavaScript bundle**
- Solution: Use code splitting, tree-shaking, and lazy loading

## Performance Optimization

### Build Optimizations

1. **Tree-shaking**: Remove unused code
   ```bash
   --tree-shake-icons
   ```

2. **Minification**: Enabled automatically in release builds

3. **Code Splitting**: Flutter web automatically splits code

4. **Asset Optimization**: Compress images, use WebP format

### Runtime Optimizations

1. **Lazy Loading**: Load pages/components on demand

2. **Caching**: Service worker caches assets for offline use

3. **Compression**: Enable gzip/brotli compression on server

4. **CDN**: Use CDN for static assets

### Monitoring

- Use Lighthouse in Chrome DevTools to audit performance
- Monitor Core Web Vitals (LCP, FID, CLS)
- Check bundle size and loading times

## Quick Reference

### Build Commands

```bash
# Development build
flutter build web

# Production build
flutter build web --release --base-href / --tree-shake-icons --web-renderer canvaskit

# Production build for subdirectory
flutter build web --release --base-href /repo-name/ --tree-shake-icons --web-renderer canvaskit
```

### Deployment Commands

```bash
# GitHub Pages (via Actions)
git push origin master

# Netlify (CLI)
netlify deploy --dir=build/web --prod

# Vercel (CLI)
cd build/web && vercel --prod
```

### Verification

```bash
# Check build output
ls -la build/web/

# Test locally
cd build/web && python -m http.server 8000

# Verify PWA
# Open Chrome DevTools → Application → Manifest
```

## Additional Resources

- [Flutter Web Documentation](https://docs.flutter.dev/platform-integration/web)
- [PWA Documentation](https://web.dev/progressive-web-apps/)
- [GitHub Pages Documentation](https://docs.github.com/pages)
- [Netlify Documentation](https://docs.netlify.com/)
- [Vercel Documentation](https://vercel.com/docs)

## Support

For issues or questions:
1. Check [Troubleshooting](#troubleshooting) section
2. Review platform-specific documentation
3. Check GitHub Issues
4. Review build logs for errors
