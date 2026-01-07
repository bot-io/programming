import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, debugPrint;
import 'package:shared_preferences/shared_preferences.dart';

// Export exceptions from base class
export 'translation/base_translation_service.dart' show TranslationException, LanguageDetectionException;

// Re-export for backward compatibility
import 'translation/base_translation_service.dart' show TranslationException, LanguageDetectionException;

/// Supported languages for translation
class SupportedLanguages {
  static const Map<String, String> languages = {
    'en': 'English',
    'es': 'Spanish',
    'fr': 'French',
    'de': 'German',
    'it': 'Italian',
    'pt': 'Portuguese',
    'ru': 'Russian',
    'zh': 'Chinese',
    'ja': 'Japanese',
    'ko': 'Korean',
    'ar': 'Arabic',
    'hi': 'Hindi',
    'tr': 'Turkish',
    'pl': 'Polish',
    'nl': 'Dutch',
    'sv': 'Swedish',
    'da': 'Danish',
    'no': 'Norwegian',
    'fi': 'Finnish',
    'cs': 'Czech',
    'ro': 'Romanian',
    'hu': 'Hungarian',
    'el': 'Greek',
    'bg': 'Bulgarian',
    'hr': 'Croatian',
    'sk': 'Slovak',
    'sl': 'Slovenian',
    'et': 'Estonian',
    'lv': 'Latvian',
    'lt': 'Lithuanian',
    'ga': 'Irish',
    'mt': 'Maltese',
    'uk': 'Ukrainian',
    'be': 'Belarusian',
    'mk': 'Macedonian',
    'sq': 'Albanian',
    'sr': 'Serbian',
    'is': 'Icelandic',
    'cy': 'Welsh',
    'ca': 'Catalan',
    'eu': 'Basque',
    'gl': 'Galician',
    'vi': 'Vietnamese',
    'th': 'Thai',
    'id': 'Indonesian',
    'ms': 'Malay',
    'tl': 'Filipino',
    'sw': 'Swahili',
    'af': 'Afrikaans',
    'zu': 'Zulu',
    'he': 'Hebrew',
    'fa': 'Persian',
    'ur': 'Urdu',
    'bn': 'Bengali',
    'ta': 'Tamil',
    'te': 'Telugu',
    'ml': 'Malayalam',
    'kn': 'Kannada',
    'gu': 'Gujarati',
    'pa': 'Punjabi',
    'ne': 'Nepali',
    'si': 'Sinhala',
    'my': 'Myanmar',
    'km': 'Khmer',
    'lo': 'Lao',
    'ka': 'Georgian',
    'am': 'Amharic',
    'az': 'Azerbaijani',
    'kk': 'Kazakh',
    'ky': 'Kyrgyz',
    'uz': 'Uzbek',
    'mn': 'Mongolian',
    'hy': 'Armenian',
  };

  /// Get language name by code
  static String? getLanguageName(String code) {
    return languages[code.toLowerCase()];
  }

  /// Get all supported language codes
  static List<String> getSupportedCodes() {
    return languages.keys.toList()..sort();
  }

  /// Check if a language code is supported
  static bool isSupported(String code) {
    return languages.containsKey(code.toLowerCase());
  }

  /// Get list of language codes and names
  static List<MapEntry<String, String>> getLanguageList() {
    return languages.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
  }
}

import 'translation/translation_service_manager.dart';
import 'translation/libretranslate_service.dart';
import 'translation/google_translate_service.dart';
import 'translation/mymemory_service.dart';

/// Translation service with automatic fallback support
/// 
/// Uses multiple translation services (LibreTranslate, Google Translate, MyMemory)
/// with automatic failover when a service is unavailable.
class TranslationService {
  /// Default LibreTranslate public instance URL
  static const String _defaultLibreTranslateUrl = 'https://libretranslate.com';
  
  /// Translation service manager with failover support
  late final TranslationServiceManager _manager;
  
  /// SharedPreferences for caching
  SharedPreferences? _prefs;
  
  /// In-memory cache for translations
  final Map<String, String> _cache = {};
  
  /// Cache for detected languages
  final Map<String, String> _detectedLanguages = {};
  
  /// Maximum text length per translation request
  static const int maxTextLength = 5000;
  
  /// Request timeout duration
  static const Duration requestTimeout = Duration(seconds: 30);
  
  /// Maximum number of retry attempts for transient failures
  static const int maxRetries = 3;
  
  /// Base delay for exponential backoff (in seconds)
  static const int baseRetryDelaySeconds = 1;
  
  /// Whether the service is initialized
  bool _initialized = false;

  /// Create a new TranslationService instance
  /// 
  /// [baseUrl] - Optional custom LibreTranslate instance URL
  ///             If not provided, uses the default public instance
  /// [googleApiKey] - Optional Google Translate API key
  ///                  If provided, Google Translate will be used as fallback
  /// [dio] - Optional Dio instance for dependency injection (useful for testing)
  ///         If not provided, creates new Dio instances
  TranslationService({
    String? baseUrl,
    String? googleApiKey,
    Dio? dio,
  }) {
    // Create manager with default services
    _manager = TranslationServiceManager.defaultManager(
      libreTranslateUrl: baseUrl ?? _defaultLibreTranslateUrl,
      googleApiKey: googleApiKey,
    );
  }


  /// Initialize the service (load cache, etc.)
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadCache();
      _initialized = true;
    } catch (e) {
      // If SharedPreferences fails, continue without persistent cache
      debugPrint('Warning: Failed to initialize SharedPreferences: $e');
    }
  }

  /// Translate text from source language to target language
  /// 
  /// [text] - Text to translate
  /// [targetLanguage] - Target language code (e.g., 'es', 'fr')
  /// [sourceLanguage] - Source language code (optional, 'auto' for auto-detection)
  /// 
  /// Returns translated text
  /// 
  /// Throws [TranslationException] if translation fails
  Future<String> translate({
    required String text,
    required String targetLanguage,
    String? sourceLanguage,
  }) async {
    // Ensure service is initialized
    if (!_initialized) {
      await initialize();
    }

    // Validate input
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) {
      return text;
    }

    // Validate languages
    if (!SupportedLanguages.isSupported(targetLanguage)) {
      throw TranslationException(
        'Target language "$targetLanguage" is not supported.',
      );
    }

    if (sourceLanguage != null &&
        sourceLanguage != 'auto' &&
        !SupportedLanguages.isSupported(sourceLanguage)) {
      throw TranslationException(
        'Source language "$sourceLanguage" is not supported.',
      );
    }

    // Check cache first
    final cacheKey = _generateCacheKey(
      trimmedText,
      sourceLanguage ?? 'auto',
      targetLanguage,
    );
    
    final cached = _cache[cacheKey];
    if (cached != null) {
      return cached;
    }

    // Try to load from persistent cache
    if (_prefs != null) {
      final cachedTranslation = _prefs!.getString(cacheKey);
      if (cachedTranslation != null) {
        _cache[cacheKey] = cachedTranslation;
        return cachedTranslation;
      }
    }

    // Split text if it's too long
    if (trimmedText.length > maxTextLength) {
      return await _translateLongText(
        text: trimmedText,
        targetLanguage: targetLanguage,
        sourceLanguage: sourceLanguage,
      );
    }

    try {
      // Use manager to translate with automatic failover
      final translatedText = await _manager.translate(
        text: trimmedText,
        targetLanguage: targetLanguage,
        sourceLanguage: sourceLanguage,
      );

      // Cache the translation
      _cache[cacheKey] = translatedText;
      if (_prefs != null) {
        await _prefs!.setString(cacheKey, translatedText);
      }

      return translatedText;
    } on TranslationException {
      rethrow;
    } catch (e) {
      throw TranslationException(
        'Translation failed: ${e.toString()}',
        originalError: e,
      );
    }
  }

  /// Translate long text by splitting it into chunks
  Future<String> _translateLongText({
    required String text,
    required String targetLanguage,
    String? sourceLanguage,
  }) async {
    // Split text at sentence boundaries
    final sentences = _splitIntoSentences(text);
    final translatedSentences = <String>[];

    String currentChunk = '';
    for (final sentence in sentences) {
      if ((currentChunk + sentence).length <= maxTextLength) {
        currentChunk += sentence;
      } else {
        if (currentChunk.isNotEmpty) {
          final translated = await _manager.translate(
            text: currentChunk.trim(),
            targetLanguage: targetLanguage,
            sourceLanguage: sourceLanguage ?? 'auto',
          );
          translatedSentences.add(translated);
        }
        currentChunk = sentence;
      }
    }

    // Translate remaining chunk
    if (currentChunk.isNotEmpty) {
      final translated = await _manager.translate(
        text: currentChunk.trim(),
        targetLanguage: targetLanguage,
        sourceLanguage: sourceLanguage ?? 'auto',
      );
      translatedSentences.add(translated);
    }

    return translatedSentences.join(' ');
  }

  /// Split text into sentences (simple implementation)
  List<String> _splitIntoSentences(String text) {
    // Split by sentence-ending punctuation followed by space or newline
    final pattern = RegExp(r'([.!?])\s+');
    final parts = text.split(pattern);
    final sentences = <String>[];

    for (int i = 0; i < parts.length; i += 2) {
      if (i + 1 < parts.length) {
        sentences.add(parts[i] + parts[i + 1]);
      } else if (parts[i].trim().isNotEmpty) {
        sentences.add(parts[i]);
      }
    }

    // If no sentences found, return the whole text
    return sentences.isEmpty ? [text] : sentences;
  }


  /// Detect the language of the given text using LibreTranslate API
  /// 
  /// [text] - Text to detect language for
  /// 
  /// Returns language code (e.g., 'en', 'es')
  /// 
  /// Throws [LanguageDetectionException] if detection fails
  Future<String> detectLanguage(String text) async {
    // Ensure service is initialized
    if (!_initialized) {
      await initialize();
    }

    final trimmedText = text.trim();
    if (trimmedText.isEmpty) {
      return 'en'; // Default to English for empty text
    }

    // Check cache first
    final cacheKey = 'lang_detect_${_generateHash(trimmedText)}';
    final cached = _detectedLanguages[cacheKey];
    if (cached != null) {
      return cached;
    }

    // Use manager for language detection with automatic failover
    try {
      final detectedLang = await _manager.detectLanguage(trimmedText);
      _detectedLanguages[cacheKey] = detectedLang;
      return detectedLang;
    } catch (e) {
      // Fallback to pattern-based detection if all services fail
      debugPrint('Language detection failed, using pattern fallback: $e');
      final fallback = _detectLanguageByPattern(trimmedText) ?? 'en';
      _detectedLanguages[cacheKey] = fallback;
      return fallback;
    }
  }

  /// Simple pattern-based language detection (fallback)
  String? _detectLanguageByPattern(String text) {
    // Russian/Cyrillic
    if (RegExp(r'[а-яА-ЯёЁ]').hasMatch(text)) return 'ru';
    
    // Chinese
    if (RegExp(r'[\u4e00-\u9fff]').hasMatch(text)) return 'zh';
    
    // Japanese
    if (RegExp(r'[\u3040-\u309f\u30a0-\u30ff]').hasMatch(text)) return 'ja';
    
    // Korean
    if (RegExp(r'[\uac00-\ud7a3]').hasMatch(text)) return 'ko';
    
    // Arabic
    if (RegExp(r'[\u0600-\u06ff]').hasMatch(text)) return 'ar';
    
    // Hebrew
    if (RegExp(r'[\u0590-\u05ff]').hasMatch(text)) return 'he';
    
    // Thai
    if (RegExp(r'[\u0e00-\u0e7f]').hasMatch(text)) return 'th';
    
    // French (common accented characters)
    if (RegExp(r'[àáâãäåæçèéêë]').hasMatch(text) &&
        !RegExp(r'[ñ]').hasMatch(text)) return 'fr';
    
    // German
    if (RegExp(r'[äöüß]').hasMatch(text)) return 'de';
    
    // Spanish
    if (RegExp(r'[ñáéíóúü]').hasMatch(text) &&
        !RegExp(r'[àèìòù]').hasMatch(text)) return 'es';
    
    // Italian
    if (RegExp(r'[àèéìíîòóù]').hasMatch(text)) return 'it';
    
    // Portuguese
    if (RegExp(r'[ãõáéíóúç]').hasMatch(text)) return 'pt';
    
    // Default to null (will use API)
    return null;
  }

  /// Generate cache key for translation
  String _generateCacheKey(
    String text,
    String sourceLanguage,
    String targetLanguage,
  ) {
    final key = '$sourceLanguage|$targetLanguage|$text';
    return 'translation_${_generateHash(key)}';
  }

  /// Generate hash for cache key
  String _generateHash(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Load cache from SharedPreferences
  Future<void> _loadCache() async {
    if (_prefs == null) return;

    final keys = _prefs!.getKeys().where((key) => key.startsWith('translation_'));
    for (final key in keys) {
      final value = _prefs!.getString(key);
      if (value != null) {
        _cache[key] = value;
      }
    }
  }

  /// Clear all cached translations
  Future<void> clearCache() async {
    _cache.clear();
    _detectedLanguages.clear();

    if (_prefs != null) {
      final keys = _prefs!.getKeys().where((key) => key.startsWith('translation_'));
      for (final key in keys) {
        await _prefs!.remove(key);
      }
    }
  }

  /// Get supported languages
  List<String> getSupportedLanguages() {
    return _manager.getSupportedLanguages();
  }

  /// Check if a language is supported
  bool isLanguageSupported(String code) {
    return _manager.isLanguageSupported(code);
  }

  /// Get language name by code
  String? getLanguageName(String code) {
    return SupportedLanguages.getLanguageName(code);
  }

  /// Get list of available translation services
  List<String> getAvailableServices() {
    return _manager.getAvailableServices();
  }

  /// Get the currently active service name
  String? getActiveServiceName() {
    return _manager.getActiveServiceName();
  }
}

