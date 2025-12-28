# Web Build and Deployment - Quick Reference

Quick reference guide for building and deploying Dual Reader 3.1 web app.

## Build Commands

### Production Build

**Windows (PowerShell):**
```powershell
.\scripts\build_web.ps1 -Mode Release -Verify
```

**Linux/macOS (Bash):**
```bash
bash web/build_web.sh
```

**Manual:**
```bash
flutter build web --release --base-href / --tree-shake-icons --web-renderer canvaskit
```

### Debug Build

**Windows:**
```powershell
.\scripts\build_web.ps1 -Mode Debug
```

**Linux/macOS:**
```bash
bash web/build_web.sh --debug
```

### Custom Base Href (for subdirectory deployment)

**Windows:**
```powershell
.\scripts\build_web.ps1 -BaseHref "/repo-name/"
```

**Linux/macOS:**
```bash
bash web/build_web.sh --base-href "/repo-name/"
```

## Deployment Commands

### GitHub Pages

**Using Script:**
```powershell
.\scripts\deploy_github_pages.ps1
```

**Manual:**
```bash
# Build first
flutter build web --release --base-href /repo-name/

# Deploy
git checkout --orphan gh-pages
git rm -rf .
cp -r build/web/* .
touch .nojekyll
git add -A
git commit -m "Deploy to GitHub Pages"
git push origin gh-pages --force
```

### Netlify

**Using Script:**
```powershell
.\scripts\deploy_netlify.ps1
```

**Using CLI:**
```bash
netlify deploy --dir=build/web --prod
```

**Using Dashboard:**
1. Go to [Netlify Dashboard](https://app.netlify.com)
2. Import repository
3. Build command: `flutter build web --release --base-href / --tree-shake-icons --web-renderer canvaskit`
4. Publish directory: `build/web`

### Vercel

**Using Script:**
```powershell
.\scripts\deploy_vercel.ps1
```

**Using CLI:**
```bash
cd build/web
vercel --prod
```

**Using Dashboard:**
1. Go to [Vercel Dashboard](https://vercel.com/dashboard)
2. Import repository
3. Build command: `flutter build web --release --base-href / --tree-shake-icons --web-renderer canvaskit`
4. Output directory: `build/web`

## Verification Commands

### Full Verification
```powershell
.\scripts\verify_web_build_deployment.ps1
```

### Build Only
```powershell
.\scripts\verify_web_build_deployment.ps1 -BuildOnly
```

### Deployment Config Only
```powershell
.\scripts\verify_web_build_deployment.ps1 -DeployOnly
```

## Testing Commands

### Local Test Server

**Python 3:**
```bash
cd build/web
python3 -m http.server 8000
```

**Python 2:**
```bash
cd build/web
python -m SimpleHTTPServer 8000
```

**Node.js:**
```bash
cd build/web
npx http-server -p 8000
```

**Open Browser:**
```
http://localhost:8000
```

## PWA Testing

### Installability Test
1. Open app in Chrome/Edge
2. Look for install prompt
3. Click "Install"
4. Verify standalone mode

### Offline Test
1. Open DevTools (F12)
2. Application → Service Workers
3. Network → Enable "Offline"
4. Refresh page

### Lighthouse Test
1. DevTools → Lighthouse
2. Select "Progressive Web App"
3. Generate report

## File Locations

### Configuration Files
- `web/manifest.json` - PWA manifest
- `web/service-worker.js` - Custom service worker (optional)
- `web/index.html` - Main HTML file
- `web/vercel.json` - Vercel configuration
- `netlify.toml` - Netlify configuration
- `.github/workflows/deploy-web.yml` - GitHub Actions workflow

### Build Output
- `build/web/` - Build output directory
- `build/web/index.html` - Main HTML
- `build/web/main.dart.js` - Compiled Dart
- `build/web/flutter_service_worker.js` - Service worker (auto-generated)
- `build/web/manifest.json` - PWA manifest

### Icons
- `web/icons/` - PWA icons directory
- `web/icons/icon-192x192.png` - Required (Android)
- `web/icons/icon-512x512.png` - Required (PWA)

## Common Issues

### Build Fails
```bash
# Enable Flutter web
flutter config --enable-web

# Clean and rebuild
flutter clean
flutter pub get
flutter build web --release
```

### PWA Not Installable
- Check HTTPS is enabled
- Verify manifest.json is valid
- Check icons exist (192x192, 512x512)
- Verify service worker is registered

### 404 Errors on Routes
- Ensure redirect rules configured (all routes → index.html)
- Check base href matches deployment path
- Verify 404.html exists (GitHub Pages)

### Service Worker Not Updating
- Clear browser cache
- Unregister service worker in DevTools
- Hard refresh (Ctrl+Shift+R)

## Environment Variables

### Netlify
- `FLUTTER_VERSION`: `stable`
- `FLUTTER_WEB_USE_SKIA`: `true`

### GitHub Actions
- `GITHUB_TOKEN`: Auto-provided
- Configure in repository Settings → Secrets

### Vercel
- `VERCEL_TOKEN`: From Vercel dashboard
- `VERCEL_ORG_ID`: From team settings
- `VERCEL_PROJECT_ID`: From project settings

## Build Flags Reference

| Flag | Description |
|------|-------------|
| `--release` | Production-optimized build |
| `--base-href /` | Base path for assets |
| `--tree-shake-icons` | Remove unused icons |
| `--web-renderer canvaskit` | Use CanvasKit renderer |
| `--dart-define=FLUTTER_WEB_USE_SKIA=true` | Enable Skia optimizations |

## Platform-Specific Notes

### GitHub Pages
- Base href: `/repo-name/` for subdirectory
- Requires `.nojekyll` file
- Requires `404.html` for SPA routing
- Free for public repositories

### Netlify
- Base href: `/` for root domain
- Automatic HTTPS
- Free tier: 100GB bandwidth/month
- Custom domain support

### Vercel
- Base href: `/` for root domain
- Automatic HTTPS
- Free tier: Unlimited bandwidth
- Edge Network (CDN)

## Quick Checklist

### Before Deployment
- [ ] Build succeeds without errors
- [ ] PWA manifest is valid
- [ ] Service worker is registered
- [ ] Icons are present (192x192, 512x512)
- [ ] Local testing passes
- [ ] Lighthouse PWA score > 90

### After Deployment
- [ ] App loads correctly
- [ ] PWA is installable
- [ ] Offline mode works
- [ ] Routes work (no 404 errors)
- [ ] Service worker updates correctly
- [ ] Performance is acceptable

## Support

- **Documentation**: `docs/WEB_BUILD_AND_DEPLOYMENT_COMPLETE.md`
- **Troubleshooting**: See troubleshooting section in complete guide
- **Issues**: Open an issue on GitHub

---

**Version**: 3.1.0  
**Last Updated**: 2024
