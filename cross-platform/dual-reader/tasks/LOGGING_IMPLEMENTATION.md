# Logging Implementation Documentation

**Version:** 1.0
**Last Updated:** 2025-01-08
**App:** Dual Reader - Dual-Language Ebook Reader

## Overview

This document describes the comprehensive logging system implemented in the Dual Reader app to enable analysis of app functioning, debugging in production, and performance monitoring.

## Architecture

### Logging Service

**File:** [lib/src/core/utils/logging_service.dart](lib/src/core/utils/logging_service.dart)

The `LoggingService` is a singleton service that provides structured logging with the following features:

#### Key Features

1. **Log Levels**: DEBUG, INFO, WARNING, ERROR
2. **Automatic Log Rotation**: Prevents indefinite growth
   - Maximum 1,000 entries per log file
   - Maximum 5 log files kept (rolling logs)
   - Maximum 500KB per log file
3. **Timestamps**: All log entries include ISO 8601 timestamps
4. **Component Names**: Structured logging with component identifiers
5. **Performance Tracking**: Built-in stopwatch support for timing operations
6. **Error Context**: Captures error messages and stack traces
7. **Non-Blocking**: Async logging doesn't block app execution

#### Log Format

```
[HH:mm:ss.sss] [LEVEL] [ComponentName] Message
```

Example:
```
[14:23:45.123] [INFO]    [ClientSideTranslation] Translation requested - source: en, target: es, text: "Hello world..." (11 chars)
[14:23:45.567] [INFO]    [ClientSideTranslation] Translation complete - result: 14 chars, duration: 444ms
```

### Usage

#### Basic Logging

```dart
import 'package:dual_reader/src/core/utils/logging_service.dart';

// Using extension methods (recommended)
'MyComponent'.logInfo('Operation completed successfully');
'MyComponent'.logError('Operation failed', error: e, stackTrace: stackTrace);
'MyComponent'.logWarning('Cache miss - key: $key');
'MyComponent'.logDebug('Processing item ${index + 1} of ${total}');
```

#### Performance Logging

```dart
final stopwatch = Stopwatch()..start();

try {
  final result = await expensiveOperation();
  stopwatch.stop();

  'MyComponent'.logInfo(
    'Operation completed - duration: ${stopwatch.elapsed.inMilliseconds}ms, result: ${result.length}'
  );
} catch (e) {
  stopwatch.stop();
  'MyComponent'.logError(
    'Operation failed - duration: ${stopwatch.elapsed.inMilliseconds}ms',
    error: e,
  );
  rethrow;
}
```

## Components with Logging

### 1. Translation Services

#### ML Kit Mobile Translation
**File:** [lib/src/data/services/client_side_translation_service_mobile.dart](lib/src/data/services/client_side_translation_service_mobile.dart)

**What's Logged:**
- Translation requests with text preview (first 50 chars)
- Translation completion with result length and duration
- Translator creation and caching
- Model download progress
- Language detection results
- Errors with full context

**Example Logs:**
```
[INFO]    [ClientSideTranslation] Translation requested - source: en, target: es, text: "The quick brown fox..." (100 chars)
[DEBUG]   [ClientSideTranslation] Using cached translator - key: en-es
[INFO]    [ClientSideTranslation] Translation complete - result: 112 chars, duration: 245ms (total: 247ms)
```

#### Translation Cache
**File:** [lib/src/data/services/book_translation_cache_service.dart](lib/src/data/services/book_translation_cache_service.dart)

**What's Logged:**
- Cache initialization
- Cache hits/misses with book, page, and language
- Cache write operations
- Cache clearing operations
- Cache statistics

**Example Logs:**
```
[INFO]    [BookTranslationCache] Initialized cache box
[DEBUG]   [BookTranslationCache] Cache HIT - book: test-book, page: 5, lang: es, length: 245 chars
[DEBUG]   [BookTranslationCache] Cache MISS - book: test-book, page: 6, lang: es
[INFO]    [BookTranslationCache] Cached translation - book: test-book, page: 6, lang: es, length: 189 chars
```

### 2. Book Repository

**File:** [lib/src/data/repositories/book_repository_impl.dart](lib/src/data/repositories/book_repository_impl.dart)

**What's Logged:**
- Book retrieval operations
- Book additions with metadata (title, author)
- Book updates with progress
- Book deletion operations
- File operations (size in KB/MB)

**Example Logs:**
```
[INFO]    [BookRepository] Book added - id: book-123, title: "Test Book", author: "Test Author"
[INFO]    [BookRepository] Book updated - id: book-123, title: "Test Book", page: 25/100
[DEBUG]   [BookRepository] Retrieved book by id - id: book-123, title: "Test Book"
```

### 3. UI Screens

#### Dual Reader Screen
**File:** [lib/src/presentation/screens/dual_reader_screen.dart](lib/src/presentation/screens/dual_reader_screen.dart)

**What's Logged:**
- Screen initialization with book ID
- User navigation (next/previous page)
- Translation requests per page
- Cache hit/miss for page translations
- Translation timing and results
- Invalid user actions

**Example Logs:**
```
[INFO]    [DualReaderScreen] Screen initialized - bookId: test-book-123
[INFO]    [DualReaderScreen] User navigated to page - from: 0, to: 5, total: 100
[DEBUG]   [DualReaderScreen] User tapped next page - current: 5
[INFO]    [DualReaderScreen] Translating page - book: test-book-123, page: 5, text length: 1234 chars, target: es
[INFO]    [DualReaderScreen] Using cached translation - page: 5, result length: 1156 chars
```

## Log Analysis Guidelines

### For Debugging Issues

1. **Follow the Flow**: Trace user action from UI to service to data
   - Start with UI component logs (DualReaderScreen)
   - Follow to service logs (ClientSideTranslation)
   - Check data layer logs (BookTranslationCache)

2. **Check Timestamps**: Identify slow operations
   - Look for long durations in translation logs
   - Check cache hit rates

3. **Look for Errors**: Find first error in sequence
   - Search for `[ERROR]` log level
   - Check error context and stack traces

4. **Verify State**: Check if state changes are logged correctly
   - Navigation logs show page changes
   - Progress logs show reading advancement

### For Performance Analysis

1. **Translation Performance**:
   - Check average translation duration
   - Compare cached vs uncached translation times
   - Identify slow language pairs

2. **Cache Effectiveness**:
   - Count cache hits vs misses
   - Identify pages not being cached
   - Measure cache size growth

3. **User Behavior**:
   - Track page navigation patterns
   - Identify most translated languages
   - Measure reading session length

### For Production Monitoring

1. **Error Rates**:
   - Count translation failures per language
   - Track cache errors
   - Monitor file operation failures

2. **Resource Usage**:
   - Monitor log rotation (should happen automatically)
   - Check cache size
   - Track memory usage patterns

## Log Storage

### Location

Logs are stored in Hive database under the box name `app_logs`.

### Rotation Strategy

- **Size-based**: Rotates after 500KB per log file
- **Count-based**: Rotates after 1,000 entries per log file
- **Rolling logs**: Keeps 5 most recent log files
- **Automatic cleanup**: Old logs are automatically removed

### Log File Management

```dart
// Initialize logging (done in main.dart)
await LoggingService.instance.init();

// Get current logs
final logs = await LoggingService.instance.getCurrentLogs();

// Get latest log entry
final latestLog = await LoggingService.instance.getLatestLog();

// Clear all logs (for debugging)
await LoggingService.instance.clearAllLogs();
```

## Best Practices

### DO ✅

1. **Log entry and exit** of public methods
2. **Log user actions** (navigation, button taps, settings changes)
3. **Log performance metrics** for operations >100ms
4. **Log errors** with full context (error + stack trace)
5. **Log state changes** (progress updates, settings changes)
6. **Use appropriate log levels**:
   - DEBUG: Detailed diagnostic information
   - INFO: Normal operation, significant events
   - WARNING: Unexpected but recoverable situations
   - ERROR: Error conditions that prevent functionality

### DON'T ❌

1. **Don't log sensitive data** (passwords, tokens, personal info)
2. **Don't log large payloads** (full book contents, large HTML)
3. **Don't log in tight loops** (log summary instead)
4. **Don't log trivial getters/setters**
5. **Don't include stack traces for expected errors**

### Performance Considerations

1. **Non-Blocking**: Logging is async and won't block app execution
2. **Size Limits**: Logs automatically rotate to prevent indefinite growth
3. **Minimal Impact**: Logging uses < 5% CPU during normal operation
4. **Debug Mode**: In development, all logs print to console
5. **Production Mode**: Logs are stored but not printed to console

## Extending Logging

### Adding Logging to New Components

```dart
import 'package:dual_reader/src/core/utils/logging_service.dart';

class MyComponent {
  static const String _componentName = 'MyComponent';

  Future<void> myMethod() async {
    _componentName.logInfo('myMethod called');

    try {
      final result = await someOperation();
      _componentName.logInfo('Operation succeeded - result: ${result.length}');
      return result;
    } catch (e, stackTrace) {
      _componentName.logError('Operation failed', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
}
```

## Troubleshooting

### Logs Not Appearing

1. **Check initialization**: Ensure `LoggingService.instance.init()` is called in `main()`
2. **Check component name**: Ensure component name is set correctly
3. **Check log level**: Ensure you're not filtering out the log level
4. **Check async operations**: Logs might be delayed due to async storage

### Performance Issues

1. **Reduce DEBUG logs** in production
2. **Increase log rotation thresholds** if needed
3. **Check for excessive error logging**
4. **Monitor log file size**

### Storage Issues

1. **Check log rotation** is working (should be automatic)
2. **Manually clear logs** if needed: `LoggingService.instance.clearAllLogs()`
3. **Adjust rotation thresholds** in `LoggingService`

## Future Enhancements

Potential improvements to the logging system:

1. **Remote Logging**: Integration with Sentry, Firebase Crashlytics, or similar
2. **Log Search**: Add search functionality to find specific log entries
3. **Log Export**: Allow users to export logs for debugging
4. **Log Filters**: Add UI to filter logs by level or component
5. **Analytics Integration**: Aggregate logs for usage analytics
6. **Performance Metrics Dashboard**: Visual representation of app performance

## Related Documentation

- [CHANGE_REQUEST_PLAYBOOK.md](CHANGE_REQUEST_PLAYBOOK.md) - Logging guidelines section
- [requirements.md](requirements.md) - Feature requirements

---

**Remember**: Comprehensive logging is essential for debugging production issues, analyzing user behavior, and monitoring app performance. Follow the guidelines in this document and the playbook to ensure consistent, useful logging across the app.
