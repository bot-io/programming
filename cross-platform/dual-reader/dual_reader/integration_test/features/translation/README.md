# Translation Feature E2E Tests

Comprehensive end-to-end tests for all translation features in the Dual Reader application.

## Test Files

### `mobile_translation_test.dart`
Tests for ML Kit translation on Android and iOS:
- ✅ ML Kit availability verification
- ✅ English to Spanish translation
- ✅ English to Bulgarian translation (Cyrillic)
- ✅ Model readiness checking
- ✅ Spanish model download
- ✅ Offline translation after model download
- ✅ Paragraph translation with structure preservation
- ✅ Language detection (English, Spanish, Bulgarian)
- ✅ Model persistence across app restarts
- ✅ Download progress UI (progress banner, success banner, retry)
- ✅ Multiple language support

**Status**: 12 test cases, requires mobile device/emulator

### `web_translation_test.dart`
Tests for Transformers.js NLLB-200 translation on Web:
- ✅ Transformers.js availability verification
- ✅ English to Spanish translation
- ✅ Model loading from CDN
- ✅ Sentence-based translation
- ✅ Paragraph break preservation
- ✅ Special character handling
- ✅ Language detection (web)
- ✅ Translation quality with context
- ✅ Multiple language support
- ✅ Empty text and long text handling

**Status**: 11 test cases, requires web browser

### `translation_cache_test.dart`
Tests for translation caching functionality:
- ✅ First translation cache miss
- ✅ Translation caching after API call
- ✅ Cache retrieval on subsequent calls
- ✅ Cache key uniqueness (text + language)
- ✅ Long text caching with hash keys
- ✅ Clear cache functionality
- ✅ Cache persistence across service restarts
- ✅ Special character handling
- ✅ Empty text handling
- ✅ Mobile translation with cache
- ✅ Web translation with cache
- ✅ Cache performance (retrieval speed)
- ✅ Concurrent cache access

**Status**: 14 test cases, runs on all platforms

### `language_detection_test.dart`
Tests for automatic language detection:
- ✅ English detection
- ✅ Spanish detection
- ✅ Bulgarian detection (Cyrillic)
- ✅ French detection
- ✅ German detection
- ✅ Russian detection (Cyrillic)
- ✅ Chinese detection
- ✅ Japanese detection
- ✅ Korean detection
- ✅ Arabic detection
- ✅ Short text handling
- ✅ Numeric text handling
- ✅ Special character handling
- ✅ Empty text handling
- ✅ Mixed language text
- ✅ Translation with auto-detection
- ✅ Source = target language handling

**Status**: 17 test cases, platform-specific tests

### `background_download_test.dart`
Tests for background language model download:
- ✅ Spanish model download on first launch
- ✅ Download progress banner display
- ✅ UI responsiveness during download
- ✅ Success banner display
- ✅ Banner dismissal
- ✅ Error banner display
- ✅ Retry button appearance
- ✅ Model persistence across app restarts
- ✅ Progress updates during download
- ✅ Status transitions (notStarted → inProgress → completed)
- ✅ Multiple language model downloads
- ✅ Existing model handling
- ✅ Library banner integration
- ✅ Navigation during download

**Status**: 14 test cases, mobile only

## Test Coverage Summary

| Feature | Mobile | Web | Total |
|---------|--------|-----|-------|
| Basic Translation | ✅ | ✅ | 4 |
| Language Detection | ✅ | ✅ | 17 |
| Model Download | ✅ | ❌ | 14 |
| Translation Cache | ✅ | ✅ | 14 |
| Background Download | ✅ | ❌ | 14 |
| **Total** | **38** | **25** | **68** |

## Running the Tests

### All Translation Tests
```bash
# Run all translation tests
flutter test integration_test/features/translation

# With verbose logging
VERBOSE_LOGGING=true flutter test integration_test/features/translation
```

### Platform-Specific

#### Android
```bash
# Start emulator first
./test_integration/scripts/android_setup.sh

# Run tests
flutter test integration_test/features/translation/mobile_translation_test.dart \
  --device-id=<emulator-id>
```

#### iOS
```bash
# Start simulator first
./test_integration/scripts/ios_setup.sh

# Run tests
flutter test integration_test/features/translation/mobile_translation_test.dart \
  --device-id=<simulator-id>
```

#### Web
```bash
# Run web tests
flutter test integration_test/features/translation/web_translation_test.dart \
  --platform chrome
```

### Specific Test Files
```bash
# Mobile translation tests
flutter test integration_test/features/translation/mobile_translation_test.dart

# Web translation tests
flutter test integration_test/features/translation/web_translation_test.dart

# Cache tests
flutter test integration_test/features/translation/translation_cache_test.dart

# Language detection tests
flutter test integration_test/features/translation/language_detection_test.dart

# Background download tests
flutter test integration_test/features/translation/background_download_test.dart
```

## Test Categories

### 1. Basic Translation
Tests fundamental translation functionality:
- Simple phrase translation
- Paragraph translation
- Multi-language support
- Structure preservation

### 2. Language Detection
Tests automatic language identification:
- European languages (English, Spanish, French, German)
- Cyrillic languages (Bulgarian, Russian)
- Asian languages (Chinese, Japanese, Korean)
- Arabic (RTL)
- Edge cases (short text, mixed text, special characters)

### 3. Model Download (Mobile Only)
Tests ML Kit model management:
- Initial download on first launch
- Progress tracking and UI updates
- Success/failure handling
- Retry functionality
- Persistence across app restarts

### 4. Translation Caching
Tests cache functionality:
- Cache hit/miss behavior
- Cache key generation
- Long text handling with hash keys
- Cache persistence
- Performance optimization

### 5. Background Download (Mobile Only)
Tests background download UI and behavior:
- Non-blocking UI during download
- Progress banner display
- User interactions (dismiss, retry)
- Navigation during download
- State management

## Platform Considerations

### Mobile (Android/iOS)
- Uses Google ML Kit for on-device translation
- Requires model download (first time only)
- Works offline after model download
- Faster translation (no network needed)
- Limited to supported languages

### Web
- Uses Transformers.js NLLB-200 model
- Model loads from CDN
- Requires internet for initial model load
- Supports 200+ languages
- Larger model size
- Client-side only (no API calls)

## Known Limitations

1. **Model Download Time**: First download can take several minutes
2. **Network Dependency**: Web requires CDN access
3. **Language Support**: Some languages may not be available on all platforms
4. **Testing Environment**: Real devices needed for complete ML Kit testing

## Test Data

### Sample Translations
| Source | Target | Text | Expected |
|--------|--------|------|----------|
| en | es | Hello world | Hola mundo |
| en | bg | Hello | Здравей |
| en | fr | Hello | Bonjour |

### Language Detection Samples
| Language | Sample Text |
|----------|-------------|
| English | Hello world |
| Spanish | Hola mundo |
| Bulgarian | Здравей свят |
| French | Bonjour le monde |
| German | Hallo Welt |
| Chinese | 你好世界 |
| Japanese | こんにちは世界 |
| Korean | 안녕하세요 세계 |
| Arabic | مرحبا بالعالم |

## Debugging

### Enable Verbose Logging
```bash
VERBOSE_LOGGING=true flutter test integration_test/features/translation
```

### Export Logs on Failure
Logs are automatically exported to `test_integration/logs/`

### Monitor Progress
During model download tests, monitor progress:
```bash
# Check download progress
adb logcat | grep "LanguageModel"
```

## CI/CD Integration

These tests are included in the E2E test workflow:
- Android: Runs on emulator
- iOS: Runs on simulator (macOS only)
- Web: Runs on Chrome

### Test Timeouts
- Basic translation: 2 minutes
- Model download: 10 minutes
- Long text translation: 10 minutes

## Next Steps

1. **Add More Languages**: Expand language coverage
2. **Performance Tests**: Add translation speed benchmarks
3. **Quality Tests**: Add translation quality metrics
4. **Error Scenarios**: Add more error handling tests
5. **Accessibility**: Add screen reader tests for translation UI

## Related Files

- `lib/src/data/services/client_side_translation_service_mobile.dart` - ML Kit implementation
- `lib/src/data/services/client_side_translation_service_web.dart` - Transformers.js implementation
- `lib/src/data/services/translation_cache_service.dart` - Cache implementation
- `lib/src/presentation/providers/language_model_notifier.dart` - Download state management
- `integration_test/mlkit_translation_integration_test.dart` - Original ML Kit tests

## Notes

- All tests use comprehensive logging for debugging
- Tests are organized by feature for maintainability
- Platform-specific tests properly skip when not applicable
- Translation services are properly closed in teardown
- Cache is cleaned up after tests
