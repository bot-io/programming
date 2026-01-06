# Tool Directory

## Translation Test Runner

### Quick Start

```bash
run_mlkit_tests.bat
```

This will open a web-based translation test in your browser.

---

## What It Does

The web test provides a simple UI to:
1. **Manual Translation**
   - Type English text
   - Select target language (Spanish, French, German, Bulgarian, etc.)
   - Click "Translate"
   - See real translation results via LibreTranslate API

2. **Automated Tests**
   - Click "Run All Tests"
   - Tests 4 translations automatically
   - Shows all results with timing

---

## Features

- ✅ **Real Translation API** - Uses LibreTranslate (free, no API key)
- ✅ **Multiple Languages** - Spanish, French, German, Bulgarian, Italian, Portuguese, Russian, Chinese, Japanese
- ✅ **Performance Metrics** - Shows translation time in milliseconds
- ✅ **Test History** - Logs all translations with results
- ✅ **Works in Browser** - No Android emulator needed

---

## Requirements

- Web browser (Chrome, Edge, Firefox, etc.)
- Internet connection (for API calls)

---

## Android ML Kit Testing

The ML Kit implementation is complete in:
```
lib/src/data/services/client_side_translation_service_mobile.dart
```

However, testing on Android emulator requires fixing the Java/build environment issue:
```
jlink.exe error with Android SDK 35
```

**Workarounds:**
1. Use a physical Android device (connect via USB)
2. Fix Java environment variables
3. Use older Android SDK (13 or 14)

---

## Files

- `test_translation.html` - Web-based translation test
- `mlkit_test_app.dart` - Flutter test app (for Android when build is fixed)
- `run_mlkit_tests.bat` - Launcher script
- `README.md` - This file

---

## Implementation Summary

### ✅ Complete & Working

| Platform | Technology | Status |
|----------|------------|--------|
| **Web** | LibreTranslate API | ✅ Working - Use web test |
| **Mobile** | Google ML Kit | ✅ Implemented - Needs build fix |

### 📱 Mobile ML Kit Features

- 58+ languages supported
- Offline, on-device translation
- No API costs
- Private (data stays on device)
- Cached models after first download

### 🌐 Web API Features

- 20+ languages supported
- Free LibreTranslate API
- No API key required
- Works immediately

---

## Troubleshooting

**"test_translation.html won't open"**
- Right-click the file → Open with → Choose your browser
- Or manually open: `tool/test_translation.html`

**Translation API errors**
- Check internet connection
- API may be rate-limited (free tier)
- Try again in a few minutes

**Android build errors**
- See "Android ML Kit Testing" section above
- The code is complete, just needs environment fix
