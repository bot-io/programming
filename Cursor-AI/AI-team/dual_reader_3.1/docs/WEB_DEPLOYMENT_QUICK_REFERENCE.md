# Web Deployment Quick Reference

Quick reference guide for deploying Dual Reader 3.1 web app.

## Quick Build

```bash
# Windows
.\web\build_web.ps1

# Linux/macOS
bash web/build_web.sh
```

## Manual Build

```bash
flutter build web --release --base-href / --tree-shake-icons --web-renderer canvaskit
```

## Deployment Platforms

### GitHub Pages

**Option 1: GitHub Actions (Automatic)**
- Push to `master` or `main` branch
- Go to Settings → Pages → Source: GitHub Actions
- Site deploys automatically

**Option 2: Manual Script**
```bash
# Windows
.\scripts\deploy_github_pages.ps1

# Linux/macOS
bash scripts/deploy_github_pages.sh
```

**Option 3: Manual**
```bash
flutter build web --release --base-href /repo-name/
git subtree push --prefix build/web origin gh-pages
```

### Netlify

**Option 1: Git Integration**
1. Connect repo at [Netlify Dashboard](https://app.netlify.com)
2. Build command: `flutter build web --release --base-href / --tree-shake-icons --web-renderer canvaskit`
3. Publish directory: `build/web`

**Option 2: CLI**
```bash
flutter build web --release --base-href /
netlify deploy --dir=build/web --prod
```

**Option 3: Drag & Drop**
1. Build the app
2. Drag `build/web` folder to [Netlify Drop](https://app.netlify.com/drop)

### Vercel

**Option 1: Git Integration**
1. Connect repo at [Vercel Dashboard](https://vercel.com/dashboard)
2. Build command: `flutter build web --release --base-href / --tree-shake-icons --web-renderer canvaskit`
3. Output directory: `build/web`

**Option 2: CLI**
```bash
flutter build web --release --base-href /
cd build/web
vercel --prod
```

## Verification

```bash
# Windows
.\web\verify_deployment.ps1

# Linux/macOS
bash web/verify_deployment.sh
```

## Local Testing

```bash
cd build/web
python -m http.server 8000
# Open http://localhost:8000
```

## PWA Testing

1. Open Chrome DevTools (F12)
2. Application → Manifest (check installability)
3. Application → Service Workers (check registration)
4. Network → Offline (test offline mode)

## Build Flags

- `--release`: Production build
- `--base-href /`: Base path (use `/repo-name/` for subdirectory)
- `--tree-shake-icons`: Remove unused icons
- `--web-renderer canvaskit`: Use CanvasKit renderer

## Configuration Files

- `web/manifest.json` - PWA manifest
- `web/netlify.toml` - Netlify configuration
- `web/vercel.json` - Vercel configuration
- `web/_headers` - Netlify headers
- `.github/workflows/deploy-web.yml` - GitHub Actions workflow

## Troubleshooting

**404 errors:** Ensure redirect rules (all routes → index.html)

**Assets not loading:** Check `base-href` matches deployment path

**PWA not installable:** Verify HTTPS, manifest.json, and service worker

**Service worker not updating:** Clear cache, check headers

## Support

See [WEB_BUILD_AND_DEPLOYMENT_COMPLETE.md](./WEB_BUILD_AND_DEPLOYMENT_COMPLETE.md) for detailed documentation.
