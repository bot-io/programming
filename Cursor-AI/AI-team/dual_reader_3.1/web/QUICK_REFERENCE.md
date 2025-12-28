# Web Platform Settings - Quick Reference

## ✅ Configuration Status

All web platform settings are configured and ready for production.

## Key Files

| File | Purpose | Status |
|------|---------|--------|
| `manifest.json` | PWA manifest with app metadata | ✅ Complete |
| `index.html` | HTML with responsive meta tags | ✅ Complete |
| `service-worker.js` | Reference service worker | ✅ Complete |
| `browserconfig.xml` | Windows tile configuration | ✅ Complete |
| `flutter_build_config.json` | Flutter build configuration | ✅ Complete |

## Build Commands

```bash
# Development
flutter run -d chrome

# Production build
flutter build web --release

# Production build with base href (for subdirectory deployment)
flutter build web --release --base-href /your-path/
```

## Verification

```bash
# Run verification script
dart web/verify_web_platform_complete.dart
```

## PWA Features

- ✅ Installable as PWA
- ✅ Offline support via service worker
- ✅ Responsive design
- ✅ App shortcuts
- ✅ Share target for EPUB/MOBI files
- ✅ Standalone display mode

## Browser Testing

1. **Chrome/Edge**: Full PWA support
2. **Firefox**: Full PWA support  
3. **Safari (iOS)**: PWA support (iOS 11.3+)
4. **Safari (macOS)**: Limited PWA features

## Deployment Checklist

- [ ] Build app: `flutter build web --release`
- [ ] Deploy `build/web/` to hosting provider
- [ ] Verify HTTPS is enabled
- [ ] Test manifest.json: `https://your-domain.com/manifest.json`
- [ ] Test service worker registration
- [ ] Test install prompt
- [ ] Test offline functionality

## Troubleshooting

**Service worker not registering?**
- Check HTTPS is enabled
- Check browser console for errors
- Verify `flutter_service_worker.js` exists in build output

**Install prompt not appearing?**
- Verify manifest.json is valid
- Ensure service worker is registered
- Check installability criteria are met

**Icons not displaying?**
- Verify icon files exist in `web/icons/`
- Check manifest.json icon paths
- Ensure proper PNG format

## Support

For detailed documentation, see:
- `WEB_PLATFORM_SETTINGS_VERIFICATION_COMPLETE.md` - Full documentation
- `verify_web_platform_complete.dart` - Verification script
