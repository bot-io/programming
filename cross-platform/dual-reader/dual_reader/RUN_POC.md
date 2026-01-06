# Translation POC - Quick Start Guide

## POC Overview

This POC demonstrates **client-side translation using Transformers.js** running entirely in the browser via WebAssembly. The model is cached locally in IndexedDB - no API calls required.

## Key Features

✅ **No API calls** - Everything runs locally in the browser
✅ **Offline capable** - Model cached in browser storage
✅ **Fast** - Translations complete in ~500ms-2s
✅ **Small footprint** - ~270MB model (English→Spanish only)

## Quick Start

### Method 1: HTML POC (Fastest - No Flutter Required)

Simply open the HTML file in your browser:

```bash
# Windows
start test/integration/translation_poc.html

# Mac/Linux
open test/integration/translation_poc.html
```

Or navigate to: `file:///path/to/dual_reader/test/integration/translation_poc.html`

This will:
1. Load Transformers.js from CDN
2. Download the model (~270MB, first time only)
3. Cache it in browser IndexedDB
4. Allow you to test translations immediately

### Method 2: Flutter App

```bash
flutter run -d chrome
```

Then:
1. Open a book in the app
2. Translation happens automatically
3. Check browser console for detailed logs

### Method 3: Integration Tests

```bash
flutter test test/integration/translation_poc_test.dart --platform chrome
```

## What You'll See

### HTML POC
- Clean web interface
- Model loading progress
- Multiple test cases
- Real-time translation results
- Performance metrics

### Flutter App
- Automatic translation when reading books
- Original text on left, Spanish on right
- Console logs showing progress

## Verification Checklist

Run through these to verify everything works:

- [ ] HTML POC opens in browser
- [ ] Model downloads (first time: ~30-60s)
- [ ] Model loads from cache (subsequent times: ~5-10s)
- [ ] "Hello" translates to Spanish containing "hola"
- [ ] Longer text translates successfully
- [ ] Translation time is reasonable (<5s)
- [ ] Model is cached (check IndexedDB in DevTools)

## Checking IndexedDB Storage

1. Open browser DevTools (F12)
2. Go to Application tab
3. Expand IndexedDB
4. Look for transformers.js cache
5. Verify ~270MB model is stored

## Files Created

```
test/integration/translation_poc.html    # Standalone HTML POC
test/integration/translation_poc_test.dart  # Flutter integration tests
tool/run_translation_poc.dart            # CLI test runner
TRANSLATION_POC.md                       # Full documentation
```

## Troubleshooting

### Model won't load
- Check browser console for errors
- Verify internet connection (first download requires network)
- Try clearing IndexedDB and reloading

### Translation returns empty
- Check that text was entered
- Verify model finished loading
- Look for JavaScript errors in console

### Performance issues
- First load is slow (downloading ~270MB)
- Subsequent loads use cache (much faster)
- Translation speed depends on text length

## Technical Details

**Model:** Xenova/opus-mt-en-es (converted from Helsinki-NLP)
**Framework:** Transformers.js v2.17.2
**Runtime:** WebAssembly (WASM)
**Storage:** IndexedDB (browser cache)
**Direction:** English → Spanish
**Size:** ~270MB (quantized)

## Next Steps

Once verified:
1. ✓ Model is cached locally
2. ✓ Translation works without API
3. ✓ Performance is acceptable
4. Consider adding more languages (optional)
5. Integrate into production app
