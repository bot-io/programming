# Translation Service Fallbacks

This directory contains the translation service fallback implementation with automatic failover support.

## Overview

The translation system supports multiple translation services with automatic failover. When one service fails, the system automatically tries the next available service in priority order.

## Architecture

### Base Class

- **`BaseTranslationService`**: Abstract base class that all translation services extend
  - Defines common interface for translation and language detection
  - Provides fallback decision logic (`shouldFallback()`)
  - Exports `TranslationException` and `LanguageDetectionException`

### Service Implementations

1. **`LibreTranslateService`**: Primary service (free, open-source)
   - Public instance: `https://libretranslate.com`
   - Supports self-hosted instances
   - Max text length: 5,000 characters
   - No API key required

2. **`GoogleTranslateService`**: Secondary service (free tier)
   - Requires Google Cloud API key
   - Free tier: 500,000 characters/month
   - Max text length: 5,000 characters
   - Only available when API key is provided

3. **`MyMemoryService`**: Tertiary service (free tier)
   - Free tier: 10,000 words/day
   - Max text length: 500 characters
   - No API key required
   - Always available

### Manager

- **`TranslationServiceManager`**: Manages multiple services with failover
  - Tries services in priority order
  - Automatically falls back on failures
  - Tracks active service (last successful)
  - Provides unified interface

## Service Priority

Default priority order (configured in `TranslationServiceManager.defaultManager`):
1. **Google Translate** (primary, if API key provided)
   - Free tier: 500,000 characters/month
   - Requires API key (free to obtain from Google Cloud Console)
2. **MyMemory** (fallback, free tier)
   - Free tier: 10,000 words/day
   - No API key required
   - Always available
3. **LibreTranslate** (optional fallback)
   - Free, open-source
   - No API key required
   - Public instance or self-hosted

## Failover Logic

### When Fallback Occurs

The system falls back to the next service when:
- **Server errors** (5xx status codes)
- **Rate limits** (429 status code)
- **Network errors** (timeouts, connection errors)
- **Service unavailable**

### When Fallback Does NOT Occur

The system does NOT fallback on:
- **Client errors** (4xx except 429) - Invalid requests, authentication failures
- **Configuration errors** - Missing API keys, invalid settings

## Usage

### Basic Usage

```dart
import 'package:dual_reader/services/translation_service.dart';

// Create service with default fallback configuration
final translationService = TranslationService();

// Optional: Provide Google Translate API key for additional fallback
final translationService = TranslationService(
  googleApiKey: 'your-api-key',
);

await translationService.initialize();

// Translate text (automatic failover if primary service fails)
final translated = await translationService.translate(
  text: 'Hello world',
  targetLanguage: 'es',
);
```

### Custom Configuration

```dart
import 'package:dual_reader/services/translation/translation_service_manager.dart';
import 'package:dual_reader/services/translation/libretranslate_service.dart';
import 'package:dual_reader/services/translation/google_translate_service.dart';
import 'package:dual_reader/services/translation/mymemory_service.dart';

// Create custom manager with specific services
final manager = TranslationServiceManager([
  LibreTranslateService(baseUrl: 'https://your-instance.com'),
  GoogleTranslateService(apiKey: 'your-key'),
  MyMemoryService(),
]);

final translated = await manager.translate(
  text: 'Hello',
  targetLanguage: 'es',
);
```

### Checking Active Service

```dart
// Get currently active service name
final activeService = translationService.getActiveServiceName();
print('Using: $activeService');

// Get list of all available services
final availableServices = translationService.getAvailableServices();
print('Available: $availableServices');
```

## Error Handling

All services throw `TranslationException` or `LanguageDetectionException` with:
- `message`: Human-readable error message
- `statusCode`: HTTP status code (if applicable)
- `originalError`: Original exception
- `serviceName`: Name of the service that failed

```dart
try {
  final translated = await translationService.translate(
    text: 'Hello',
    targetLanguage: 'es',
  );
} on TranslationException catch (e) {
  print('Translation failed: ${e.message}');
  print('Service: ${e.serviceName}');
  print('Status: ${e.statusCode}');
}
```

## Caching

The main `TranslationService` class maintains:
- **In-memory cache**: Fast access for recent translations
- **Persistent cache**: Stored in SharedPreferences for offline access

Cache keys are generated using SHA-256 hash of:
- Source language
- Target language  
- Text content

## Testing

See `test/services/translation_fallback_test.dart` for comprehensive test coverage including:
- Successful translation with primary service
- Automatic failover on failures
- Multiple service failover
- Error handling
- Edge cases

## Configuration

### Google Translate API Key

To use Google Translate as a fallback:

1. Get API key from [Google Cloud Console](https://console.cloud.google.com/)
2. Enable "Cloud Translation API"
3. Pass API key to `TranslationService` constructor:

```dart
final service = TranslationService(
  googleApiKey: 'your-api-key-here',
);
```

### Custom LibreTranslate Instance

To use a self-hosted LibreTranslate instance:

```dart
final service = TranslationService(
  baseUrl: 'https://your-libretranslate-instance.com',
);
```

## Best Practices

1. **Always initialize**: Call `initialize()` before first use
2. **Handle errors**: Wrap translation calls in try-catch
3. **Check availability**: Use `getAvailableServices()` to see configured services
4. **Monitor active service**: Use `getActiveServiceName()` for debugging
5. **Cache translations**: The service automatically caches, but you can clear with `clearCache()`

## Limitations

- **MyMemory**: Limited to 500 characters per request (smallest limit)
- **Google Translate**: Requires API key and has monthly limits
- **LibreTranslate**: Public instance may have rate limits
- **Network dependency**: All services require internet connection (except cached translations)

## Future Enhancements

- Service health monitoring
- Automatic service priority adjustment based on success rates
- Configurable retry strategies per service
- Offline translation support using local models
