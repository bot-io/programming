# Web Build Quick Start Guide

Quick reference for building and deploying the Dual Reader 3.1 web app.

## Quick Build

### Windows (PowerShell)
```powershell
.\scripts\build_web.ps1
```

### Linux/Mac (Bash)
```bash
./scripts/build_web.sh
```

## Quick Deploy

### GitHub Pages
```powershell
# Windows
.\scripts\deploy_github_pages.ps1

# Linux/Mac
./scripts/deploy_github_pages.sh
```

### Netlify
```powershell
# Windows
.\scripts\deploy_netlify.ps1 -Production

# Linux/Mac
./scripts/deploy_netlify.sh --production
```

### Vercel
```powershell
# Windows
.\scripts\deploy_vercel.ps1 -Production

# Linux/Mac
./scripts/deploy_vercel.sh --production
```

## Test Locally

```bash
cd build/web
python -m http.server 8000
# Open http://localhost:8000
```

## Verify PWA

1. Open DevTools (F12)
2. Application > Service Workers - Should be active
3. Application > Manifest - Should show all details
4. Lighthouse > Run PWA audit - Should score 90+

## Common Commands

```bash
# Clean build
flutter clean

# Get dependencies
flutter pub get

# Build release
flutter build web --release --base-href / --tree-shake-icons --web-renderer canvaskit

# Build with verification
.\scripts\build_web.ps1 -Verify

# Build with analysis
.\scripts\build_web.ps1 -Analyze
```

## Build Output

- Location: `build/web/`
- Essential files: `index.html`, `manifest.json`, `main.dart.js`, `flutter_service_worker.js`
- Icons: `icons/` directory

## Deployment Checklist

- [ ] Build completed successfully
- [ ] All essential files present in `build/web/`
- [ ] PWA manifest valid (check in DevTools)
- [ ] Service worker registered (check in DevTools)
- [ ] Tested locally
- [ ] Deployed to hosting platform
- [ ] Tested PWA installation
- [ ] Tested offline functionality
- [ ] Lighthouse audit passed

## Troubleshooting Quick Fixes

**Build fails**: Run `flutter clean` and `flutter pub get` first

**PWA not installable**: Ensure HTTPS and valid manifest.json

**Service worker not working**: Check DevTools > Application > Service Workers

**404 on GitHub Pages**: Ensure `.nojekyll` exists and base-href is correct

For detailed information, see [WEB_BUILD_AND_DEPLOYMENT.md](./WEB_BUILD_AND_DEPLOYMENT.md)
