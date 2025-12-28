# Web Build and Deployment - Quick Reference

## Quick Commands

### Build

**Windows:**
```powershell
.\web\build_web.ps1
```

**Linux/macOS:**
```bash
bash web/build_web.sh
```

### Verify PWA

**Windows:**
```powershell
.\web\verify_pwa_complete.ps1
```

**Linux/macOS:**
```bash
bash web/verify_pwa_complete.sh
```

### Deploy

**GitHub Pages:**
```powershell
.\scripts\deploy_github_pages.ps1
```

**Netlify:**
```powershell
.\scripts\deploy_netlify.ps1 -Production
```

**Vercel:**
```powershell
.\scripts\deploy_vercel.ps1 -Production
```

## Build Options

| Option | Description | Default |
|--------|-------------|---------|
| `--debug` | Build in debug mode | Release |
| `--no-verify` | Skip build verification | Verify |
| `--analyze` | Run code analysis | No |
| `--test` | Run tests | No |
| `--base-href PATH` | Set base path | `/` |

## Build Output

Location: `build/web/`

Key files:
- `index.html` - Main HTML
- `main.dart.js` - Compiled code
- `flutter_service_worker.js` - Service worker
- `manifest.json` - PWA manifest
- `icons/` - PWA icons

## PWA Checklist

- [ ] Manifest.json exists and is valid
- [ ] Service worker is registered
- [ ] Icons (192x192, 512x512) are present
- [ ] Theme colors are set
- [ ] App is installable
- [ ] Offline functionality works

## Testing Locally

```bash
cd build/web
python -m http.server 8000
# Open http://localhost:8000
```

## Deployment URLs

After deployment, your app will be available at:

- **GitHub Pages**: `https://[username].github.io/[repo-name]/`
- **Netlify**: `https://[site-name].netlify.app`
- **Vercel**: `https://[project-name].vercel.app`

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Build fails | Run `flutter clean` then rebuild |
| PWA not installable | Check manifest.json and icons |
| Service worker not working | Verify HTTPS (required) |
| 404 errors | Check base-href matches deployment path |

## Performance Targets

- **Lighthouse Performance**: 90+
- **Lighthouse PWA**: 100
- **Bundle Size**: < 5MB (main.dart.js)
- **First Contentful Paint**: < 2s

## Support

See [WEB_BUILD_AND_DEPLOYMENT_GUIDE.md](./WEB_BUILD_AND_DEPLOYMENT_GUIDE.md) for detailed documentation.
