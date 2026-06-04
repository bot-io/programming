/// Mock Translation Service
///
/// Provides a predictable word-replacement translation service for testing.
/// Simulates various states including success, failure, timeout, and offline behavior.

library;

import 'package:dual_reader/src/domain/services/translation_service.dart';
import 'package:dual_reader/src/domain/entities/translation_result.dart';

/// Mock configuration for translation behavior
class MockTranslationConfig {
  /// Simulated translation delay
  final Duration delay;

  /// Success rate (0.0 to 1.0)
  final double successRate;

  /// Whether to simulate offline mode
  final bool isOffline;

  /// Language to translate to
  final String targetLanguage;

  /// Whether to use word replacement (predictable)
  final bool useWordReplacement;

  /// Custom translation mapping
  final Map<String, String>? customTranslations;

  const MockTranslationConfig({
    this.delay = Duration.zero,
    this.successRate = 1.0,
    this.isOffline = false,
    this.targetLanguage = 'es',
    this.useWordReplacement = true,
    this.customTranslations,
  });

  /// Config for immediate success
  const MockTranslationConfig.immediate({
    String targetLanguage = 'es',
  }) : this(
          delay: Duration.zero,
          targetLanguage: targetLanguage,
        );

  /// Config for delayed success
  const MockTranslationConfig.delayed({
    Duration delay = const Duration(milliseconds: 500),
    String targetLanguage = 'es',
  }) : this(
          delay: delay,
          targetLanguage: targetLanguage,
        );

  /// Config for failure
  const MockTranslationConfig.failure() : this(
          successRate: 0.0,
        );

  /// Config for timeout simulation
  const MockTranslationConfig.timeout() : this(
          delay: const Duration(minutes: 5),
        );

  /// Config for offline mode
  const MockTranslationConfig.offline({
    String targetLanguage = 'es',
  }) : this(
          isOffline: true,
          targetLanguage: targetLanguage,
        );
}

/// Mock translation service for testing
class MockTranslationService implements TranslationService {
  final MockTranslationConfig config;
  int _translationCount = 0;
  final List<TranslationCall> _calls = [];

  MockTranslationService([this.config = const MockTranslationConfig()]);

  /// Get the number of translations performed
  int get translationCount => _translationCount;

  /// Get all translation calls
  List<TranslationCall> get calls => List.unmodifiable(_calls);

  /// Clear call history
  void clearCalls() {
    _calls.clear();
    _translationCount = 0;
  }

  @override
  Future<TranslationResult?> translate({
    required String text,
    required String targetLanguage,
    String? sourceLanguage,
  }) async {
    _translationCount++;
    final call = TranslationCall(
      text: text,
      targetLanguage: targetLanguage,
      sourceLanguage: sourceLanguage,
      timestamp: DateTime.now(),
    );
    _calls.add(call);

    // Simulate delay
    if (config.delay > Duration.zero) {
      await Future.delayed(config.delay);
    }

    // Check if offline and return null
    if (config.isOffline) {
      if (_translationCount % 3 == 0) {
        // Simulate intermittent offline availability
        return null;
      }
    }

    // Check success rate
    if (config.successRate < 1.0) {
      if (_translationCount / 100 > config.successRate) {
        return null;
      }
    }

    // Perform translation
    if (config.useWordReplacement) {
      return _wordReplacementTranslation(text, targetLanguage);
    } else if (config.customTranslations != null) {
      return _customTranslation(text, targetLanguage);
    } else {
      return _defaultTranslation(text, targetLanguage);
    }
  }

  @override
  Future<bool> isLanguageAvailable(String languageCode) async {
    // Simulate checking language availability
    await Future.delayed(const Duration(milliseconds: 10));
    return true;
  }

  @override
  Future<List<String>> getAvailableLanguages() async {
    // Return common languages
    return const [
      'en',
      'es',
      'fr',
      'de',
      'it',
      'pt',
      'ru',
      'zh',
      'ja',
      'ko',
      'ar',
    ];
  }

  @override
  Future<String?> detectLanguage(String text) async {
    // Simple language detection simulation
    await Future.delayed(const Duration(milliseconds: 50));

    if (text.contains(RegExp(r'[\u4e00-\u9fff]'))) {
      return 'zh';
    } else if (text.contains(RegExp(r'[\u3040-\u309f]'))) {
      return 'ja';
    } else if (text.contains(RegExp(r'[\u0600-\u06FF]'))) {
      return 'ar';
    } else if (text.contains('ñ') || text.contains('¿')) {
      return 'es';
    } else if (text.contains('é') || text.contains('è')) {
      return 'fr';
    } else if (text.contains('ü') || text.contains('ß')) {
      return 'de';
    } else {
      return 'en';
    }
  }

  @override
  Future<void> preloadModel(String languageCode) async {
    // Simulate model preloading
    await Future.delayed(const Duration(milliseconds: 100));
  }

  @override
  Future<bool> isModelLoaded(String languageCode) async {
    // Simulate checking if model is loaded
    return true;
  }

  @override
  Future<int> getModelSize(String languageCode) async {
    // Simulate model size in bytes
    return 50 * 1024 * 1024; // 50 MB
  }

  /// Word-replacement translation for predictable testing
  TranslationResult _wordReplacementTranslation(String text, String targetLang) {
    // Simple word replacement: add language code suffix to each word
    final words = text.split(' ');
    final translatedWords = words.map((word) {
      if (word.isEmpty) return word;
      // Remove punctuation, add suffix, restore punctuation
      final cleanWord = word.replaceAll(RegExp(r'[^\w]'), '');
      final punctuation = word.substring(cleanWord.length);
      return '${cleanWord}_$targetLang$punctuation';
    }).join(' ');

    return TranslationResult(
      originalText: text,
      translatedText: translatedWords,
      sourceLanguage: 'en',
      targetLanguage: targetLang,
      confidence: 1.0,
    );
  }

  /// Custom translation from mapping
  TranslationResult _customTranslation(String text, String targetLang) {
    final translation = config.customTranslations![text];
    if (translation != null) {
      return TranslationResult(
        originalText: text,
        translatedText: translation,
        sourceLanguage: 'en',
        targetLanguage: targetLang,
        confidence: 1.0,
      );
    }
    return _defaultTranslation(text, targetLang);
  }

  /// Default translation (just returns text with prefix)
  TranslationResult _defaultTranslation(String text, String targetLang) {
    return TranslationResult(
      originalText: text,
      translatedText: '[$targetLang] $text',
      sourceLanguage: 'en',
      targetLanguage: targetLang,
      confidence: 0.95,
    );
  }
}

/// Record of a translation call
class TranslationCall {
  final String text;
  final String targetLanguage;
  final String? sourceLanguage;
  final DateTime timestamp;

  TranslationCall({
    required this.text,
    required this.targetLanguage,
    this.sourceLanguage,
    required this.timestamp,
  });

  @override
  String toString() =>
      'TranslationCall(text: "$text", to: $targetLanguage, from: $sourceLanguage, at: $timestamp)';
}

/// Mock translation cache for testing
class MockTranslationCache {
  final Map<String, TranslationResult> _cache = {};
  int _hitCount = 0;
  int _missCount = 0;

  /// Get cached translation if available
  TranslationResult? get(String key) {
    final result = _cache[key];
    if (result != null) {
      _hitCount++;
    } else {
      _missCount++;
    }
    return result;
  }

  /// Put translation in cache
  void put(String key, TranslationResult result) {
    _cache[key] = result;
  }

  /// Clear cache
  void clear() {
    _cache.clear();
    _hitCount = 0;
    _missCount = 0;
  }

  /// Get cache statistics
  MockCacheStats get stats => MockCacheStats(
        size: _cache.length,
        hits: _hitCount,
        misses: _missCount,
        hitRate: _hitCount + _missCount > 0
            ? _hitCount / (_hitCount + _missCount)
            : 0.0,
      );

  /// Generate cache key
  static String generateKey(String text, String targetLanguage) {
    return '$text|$targetLanguage';
  }
}

/// Cache statistics
class MockCacheStats {
  final int size;
  final int hits;
  final int misses;
  final double hitRate;

  MockCacheStats({
    required this.size,
    required this.hits,
    required this.misses,
    required this.hitRate,
  });

  @override
  String toString =>
      'CacheStats(size: $size, hits: $hits, misses: $misses, hitRate: ${(hitRate * 100).toStringAsFixed(1)}%)';
}

/// Factory for creating configured mock services
class MockTranslationServiceFactory {
  /// Create a mock with immediate response
  static MockTranslationService createImmediate() {
    return MockTranslationService(const MockTranslationConfig.immediate());
  }

  /// Create a mock with delay
  static MockTranslationService createDelayed([Duration delay = const Duration(milliseconds: 500)]) {
    return MockTranslationService(MockTranslationConfig.delayed(delay: delay));
  }

  /// Create a mock that always fails
  static MockTranslationService createFailing() {
    return MockTranslationService(const MockTranslationConfig.failure());
  }

  /// Create a mock that times out
  static MockTranslationService createTimeout() {
    return MockTranslationService(const MockTranslationConfig.timeout());
  }

  /// Create a mock for offline testing
  static MockTranslationService createOffline() {
    return MockTranslationService(const MockTranslationConfig.offline());
  }

  /// Create a mock with custom translations
  static MockTranslationService createWithCustomTranslations(
    Map<String, String> translations,
  ) {
    return MockTranslationService(MockTranslationConfig(
      customTranslations: translations,
    ));
  }
}
