# Translation POC - Proof of Concept

## Overview

This POC demonstrates client-side translation using Transformers.js running entirely in the browser via WebAssembly. No API calls are made, and the model is cached locally using IndexedDB.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Flutter Web App                          │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────────┐         ┌──────────────────────┐     │
│  │   Dart Code      │────────▶│   JavaScript          │     │
│  │                  │  JS     │  (Transformers.js)    │     │
│  │ transformers_    │ Interop │                      │     │
│  │ interop.dart     │         │  - Helsinki-NLP       │     │
│  │                  │         │    opus-mt-en-es      │     │
│  │ Uses dart:js     │         │  - WebAssembly        │     │
│  │ package          │         │  - IndexedDB Cache    │     │
│  └──────────────────┘         └──────────────────────┘     │
│         ▲                                                   │
│         │                                                   │
│         │ Workaround                                        │
│         │                                                   │
│  ┌──────┴──────────────────────────────────────────────┐   │
│  │  Text Passing Issue: Parameters arrive as undefined  │   │
│  │  Solution: Set global variable, read from closure    │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

## Model Storage

**Model:** Helsinki-NLP/opus-mt-en-es
- **Size:** ~270MB (quantized)
- **Location:** Browser IndexedDB (automatic caching)
- **Format:** ONNX + Quantized (int8) for WebAssembly
- **Loading:** Pre-loads on page load, cached after first download

### Storage Details

The model is stored in the browser's IndexedDB:
- Chrome: `~/.config/google-chrome/Default/IndexedDB/`
- Firefox: `~/.mozilla/firefox/*/storage/default/`
- Edge: Similar to Chrome

After the first download, the model is cached indefinitely and works offline.

## Running the POC Tests

### Option 1: Flutter Test (Recommended)

```bash
flutter test test/integration/translation_poc_test.dart --platform chrome
```

This runs comprehensive integration tests including:
- JavaScript function availability
- Text passing workaround verification
- Model loading confirmation
- Actual translation tests
- Language constraint validation

### Option 2: Standalone Runner

```bash
dart run tool/run_translation_poc.dart
```

This runs a simplified test suite with clear pass/fail output.

### Option 3: Run the App

```bash
flutter run -d chrome
```

Then open a book and trigger translation to see it in action.

## Test Coverage

The POC tests verify:

1. **JavaScript Integration** - Required functions are available
2. **Text Passing Workaround** - Global variable storage works
3. **Model Loading** - Model loads and caches in IndexedDB
4. **Simple Translations** - Basic word translations work
5. **Extended Text** - Longer text translations work
6. **Language Constraints** - Only English→Spanish supported
7. **Performance** - Translation completes in reasonable time

## Known Issues

### Text Passing Bug

**Problem:** When calling JavaScript functions from Dart with parameters, the parameters arrive as `undefined` in JavaScript.

**Impact:** Cannot pass text directly to `transformersTranslate(text)` function.

**Workaround:**
1. Dart sets global variable: `js.context['transformersText'] = text`
2. JavaScript reads from global variable in `setText()` function
3. Text stored in closure variable for `transformersTranslate()` to use

**Affected Code:**
- `lib/src/data/services/web/transformers_interop.dart`
- `web/index.html` (closure-based text storage)

### Potential Root Cause

This appears to be a Flutter Web issue with the `dart:js` package where string parameters are not properly converted to JavaScript strings. May need to be reported to the Flutter team if no better workaround is found.

## Performance

- **First Load:** ~30-60 seconds (model download + WASM compilation)
- **Subsequent Loads:** ~5-10 seconds (load from cache)
- **Translation Speed:** ~500ms-2s per sentence (depends on length)
- **Model Size:** ~270MB (quantized to int8)

## Supported Languages

Currently supports **English → Spanish** only:
- Model: Helsinki-NLP/opus-mt-en-es
- Direction: English (en) → Spanish (es)

This is the minimal required translation pair as specified. Additional languages can be added by:
1. Adding models to `web/index.html`
2. Updating language constraints in `transformers_interop.dart`
3. Each model adds ~270MB to the application size

## Files Modified

- `lib/src/data/services/web/transformers_interop.dart` - JS interop layer
- `web/index.html` - Transformers.js integration and workaround
- `test/integration/translation_poc_test.dart` - Comprehensive POC tests
- `tool/run_translation_poc.dart` - Standalone test runner

## Next Steps

1. ✓ Verify translation works with POC tests
2. ✓ Confirm model is cached locally
3. ✓ Document text passing workaround
4. Consider adding support for French and Bulgarian (optional)
5. Report text passing bug to Flutter team if needed

## References

- [Transformers.js Documentation](https://huggingface.co/docs/transformers.js)
- [Helsinki-NLP opus-mt-en-es Model](https://huggingface.co/Helsinki-NLP/opus-mt-en-es)
- [Flutter Web JS Interop](https://dart.dev/guides/libraries/create-library-packages#organizing-a-package)
- [IndexedDB API](https://developer.mozilla.org/en-US/docs/Web/API/IndexedDB_API)
