/// Configuration for E2E tests
///
/// This file contains shared configuration for all E2E tests including
/// timeouts, test data paths, and platform-specific settings.

library;

import 'dart:io';

/// Test configuration constants
class TestConfig {
  /// Default timeout for tests in milliseconds
  static const Duration defaultTimeout = Duration(minutes: 5);

  /// Extended timeout for model downloads
  static const Duration downloadTimeout = Duration(minutes: 10);

  /// Standard timeout for UI interactions
  static const Duration uiTimeout = Duration(seconds: 30);

  /// Timeout for network operations
  static const Duration networkTimeout = Duration(minutes: 2);

  /// Path to test data directory
  static const String testDataPath = 'test_integration/test_data';

  /// Test ebook files
  static const String testEpubPath = '$testDataPath/books/test_book.epub';
  static const String testMobiPath = '$testDataPath/books/test_book.mobi';

  /// Small test EPUB for quick tests
  static const String smallTestEpub = '$testDataPath/books/small_test.epub';

  /// Translation test phrases
  static const Map<String, Map<String, String>> translationTestPhrases = {
    'en': {
      'simple': 'Hello world',
      'paragraph': 'The quick brown fox jumps over the lazy dog.',
      'multiline': '''This is a test.
It has multiple lines.
Each line should be translated separately.''',
    },
    'es': {
      'simple': 'Hola mundo',
      'paragraph': 'El rápido zorro marrón salta sobre el perro perezoso.',
    },
    'bg': {
      'simple': 'Здравей свят',
      'paragraph': 'Бързата кафява лисица скача над мързеливото куче.',
    },
  };

  /// Supported languages for testing
  static const Map<String, String> supportedLanguages = {
    'en': 'English',
    'es': 'Spanish',
    'bg': 'Bulgarian',
    'fr': 'French',
    'de': 'German',
    'it': 'Italian',
  };

  /// Platform-specific configurations
  static bool get isAndroid => Platform.isAndroid;
  static bool get isIOS => Platform.isIOS;
  static bool get isWeb => Platform.isAndroid == false && Platform.isIOS == false;

  /// Whether we're running on CI
  static bool get isCI =>
      Platform.environment['CI'] != null ||
      Platform.environment['GITHUB_ACTIONS'] != null;

  /// Get emulator/device ID from environment
  static String? get deviceId => Platform.environment['DEVICE_ID'];

  /// Get test run identifier
  static String get testRunId =>
      Platform.environment['TEST_RUN_ID'] ?? DateTime.now().toIso8601String();

  /// Screenshot directory for failed tests
  static String get screenshotDir =>
      isCI ? '/tmp/test_screenshots' : 'test_integration/screenshots';

  /// Log directory for debug output
  static String get logDir => 'test_integration/logs';

  /// Whether to enable verbose logging
  static bool get verboseLogging =>
      Platform.environment['VERBOSE_LOGGING'] == 'true';

  /// Mock translation settings for web testing
  static const bool useMockTranslationOnWeb = true;

  /// Maximum wait time for UI elements
  static const Duration maxWaitTime = Duration(seconds: 10);

  /// Interval between polling attempts
  static const Duration pollingInterval = Duration(milliseconds: 500);
}

/// Test categories for organizing tests
class TestCategory {
  static const String smoke = 'smoke';
  static const String regression = 'regression';
  static const String integration = 'integration';
  static const String performance = 'performance';
  static const String accessibility = 'accessibility';
}

/// Test tags for selective test execution
class TestTag {
  static const String slow = 'slow';
  static const String requiresDevice = 'requires-device';
  static const String requiresNetwork = 'requires-network';
  static const String requiresDownload = 'requires-download';
  static const String webOnly = 'web-only';
  static const String mobileOnly = 'mobile-only';
  static const String androidOnly = 'android-only';
  static const String iosOnly = 'ios-only';
}
