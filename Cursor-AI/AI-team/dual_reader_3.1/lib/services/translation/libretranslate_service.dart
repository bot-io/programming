import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'base_translation_service.dart';
import '../translation_service.dart' show SupportedLanguages;

/// LibreTranslate API service
/// 
/// Free, open-source translation service
/// Can use public instance or self-hosted
class LibreTranslateService extends BaseTranslationService {
  /// Default LibreTranslate public instance URL
  static const String _defaultBaseUrl = 'https://libretranslate.com';

  /// Base URL for the LibreTranslate instance
  final String _baseUrl;

  /// HTTP client instance
  late final Dio _dioInstance;

  /// Maximum text length per request (LibreTranslate limit)
  static const int _maxTextLength = 5000;

  /// Request timeout duration
  static const Duration _requestTimeout = Duration(seconds: 30);

  /// Maximum retry attempts
  static const int _maxRetries = 3;

  /// Cache for detected languages
  final Map<String, String> _detectedLanguages = {};

  /// Create a new LibreTranslateService instance
  /// 
  /// [baseUrl] - Optional custom LibreTranslate instance URL
  ///             If not provided, uses the default public instance
  /// [dio] - Optional Dio instance for dependency injection
  LibreTranslateService({String? baseUrl, Dio? dio})
      : _baseUrl = baseUrl ?? _defaultBaseUrl {
    _dioInstance = dio ?? Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: _requestTimeout,
        receiveTimeout: _requestTimeout,
        sendTimeout: _requestTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Add interceptors for error handling
    _dioInstance.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) {
          if (error.type == DioExceptionType.connectionTimeout ||
              error.type == DioExceptionType.receiveTimeout ||
              error.type == DioExceptionType.sendTimeout) {
            handler.reject(
              DioException(
                requestOptions: error.requestOptions,
                error: TranslationException(
                  'Request timeout. Please check your internet connection.',
                  originalError: error,
                  serviceName: serviceName,
                ),
              ),
            );
          } else if (error.type == DioExceptionType.connectionError) {
            handler.reject(
              DioException(
                requestOptions: error.requestOptions,
                error: TranslationException(
                  'Network error. Please check your internet connection.',
                  originalError: error,
                  serviceName: serviceName,
                ),
              ),
            );
          } else {
            handler.next(error);
          }
        },
      ),
    );
  }

  @override
  String get serviceName => 'LibreTranslate';

  @override
  Dio get dio => _dioInstance;

  @override
  int get maxTextLength => _maxTextLength;

  @override
  Duration get requestTimeout => _requestTimeout;

  @override
  int get maxRetries => _maxRetries;

  @override
  bool get isAvailable => true; // Public instance is always available

  @override
  Future<String> translate({
    required String text,
    required String targetLanguage,
    String? sourceLanguage,
  }) async {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) {
      return text;
    }

    // Validate languages
    if (!SupportedLanguages.isSupported(targetLanguage)) {
      throw TranslationException(
        'Target language "$targetLanguage" is not supported.',
        serviceName: serviceName,
      );
    }

    if (sourceLanguage != null &&
        sourceLanguage != 'auto' &&
        !SupportedLanguages.isSupported(sourceLanguage)) {
      throw TranslationException(
        'Source language "$sourceLanguage" is not supported.',
        serviceName: serviceName,
      );
    }

    int attempt = 0;
    DioException? lastException;

    while (attempt <= maxRetries) {
      try {
        final response = await _dioInstance.post(
          '/translate',
          data: {
            'q': trimmedText,
            'source': sourceLanguage ?? 'auto',
            'target': targetLanguage,
            'format': 'text',
          },
        );

        if (response.statusCode == 200 && response.data != null) {
          final translatedText = response.data['translatedText'] as String?;
          if (translatedText != null && translatedText.isNotEmpty) {
            return translatedText;
          }
        }

        throw TranslationException(
          'Invalid response from LibreTranslate API',
          statusCode: response.statusCode,
          serviceName: serviceName,
        );
      } on DioException catch (e) {
        if (e.error is TranslationException) {
          rethrow;
        }

        final statusCode = e.response?.statusCode;
        lastException = e;

        // Check if we should retry
        final shouldRetry = _shouldRetry(statusCode, e.type, attempt);

        if (!shouldRetry) {
          String message;
          switch (statusCode) {
            case 400:
              message = 'Invalid request. Please check your input.';
              break;
            case 403:
              message = 'Access forbidden. The API may require authentication.';
              break;
            case 429:
              message = 'Rate limit exceeded. Please try again later.';
              break;
            case 500:
            case 502:
            case 503:
              message = 'Server error. Please try again later.';
              break;
            default:
              message = 'Network error: ${e.message ?? "Unknown error"}';
          }

          throw TranslationException(
            message,
            statusCode: statusCode,
            originalError: e,
            serviceName: serviceName,
          );
        }

        // Retry with exponential backoff
        attempt++;
        if (attempt <= maxRetries) {
          final delaySeconds = 1 * (1 << (attempt - 1));
          debugPrint('LibreTranslate request failed (attempt $attempt/$maxRetries). Retrying in ${delaySeconds}s...');
          await Future.delayed(Duration(seconds: delaySeconds));
        }
      } catch (e) {
        if (e is TranslationException) {
          rethrow;
        }
        throw TranslationException(
          'Translation failed: ${e.toString()}',
          originalError: e,
          serviceName: serviceName,
        );
      }
    }

    throw TranslationException(
      'Translation failed after $maxRetries retries: ${lastException?.message ?? "Unknown error"}',
      statusCode: lastException?.response?.statusCode,
      originalError: lastException,
      serviceName: serviceName,
    );
  }

  @override
  Future<String> detectLanguage(String text) async {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) {
      return 'en';
    }

    // Check cache first
    final cacheKey = 'lang_detect_${_generateHash(trimmedText)}';
    final cached = _detectedLanguages[cacheKey];
    if (cached != null) {
      return cached;
    }

    // Try simple pattern-based detection first (faster, works offline)
    final patternDetected = _detectLanguageByPattern(trimmedText);
    if (patternDetected != null) {
      _detectedLanguages[cacheKey] = patternDetected;
      return patternDetected;
    }

    // Use API for detection
    try {
      final detectedLang = await _detectLanguageWithAPI(trimmedText);
      _detectedLanguages[cacheKey] = detectedLang;
      return detectedLang;
    } catch (e) {
      // Fallback to pattern-based detection if API fails
      debugPrint('Language detection API failed, using fallback: $e');
      final fallback = _detectLanguageByPattern(trimmedText) ?? 'en';
      _detectedLanguages[cacheKey] = fallback;
      return fallback;
    }
  }

  /// Detect language using LibreTranslate API with retry logic
  Future<String> _detectLanguageWithAPI(String text) async {
    int attempt = 0;
    DioException? lastException;

    while (attempt <= maxRetries) {
      try {
        final response = await _dioInstance.post(
          '/detect',
          data: {
            'q': text,
          },
        );

        if (response.statusCode == 200 && response.data != null) {
          final detected = response.data[0];
          if (detected != null && detected['language'] != null) {
            final langCode = detected['language'] as String;
            if (SupportedLanguages.isSupported(langCode)) {
              return langCode;
            }
          }
        }

        throw LanguageDetectionException(
          'Invalid response from language detection API',
          serviceName: serviceName,
        );
      } on DioException catch (e) {
        lastException = e;
        final statusCode = e.response?.statusCode;

        final shouldRetry = _shouldRetry(statusCode, e.type, attempt);

        if (!shouldRetry) {
          throw LanguageDetectionException(
            'Language detection failed: ${e.message ?? "Unknown error"}',
            originalError: e,
            serviceName: serviceName,
          );
        }

        attempt++;
        if (attempt <= maxRetries) {
          final delaySeconds = 1 * (1 << (attempt - 1));
          debugPrint('Language detection request failed (attempt $attempt/$maxRetries). Retrying in ${delaySeconds}s...');
          await Future.delayed(Duration(seconds: delaySeconds));
        }
      } catch (e) {
        if (e is LanguageDetectionException) {
          rethrow;
        }
        throw LanguageDetectionException(
          'Language detection failed: ${e.toString()}',
          originalError: e,
          serviceName: serviceName,
        );
      }
    }

    throw LanguageDetectionException(
      'Language detection failed after $maxRetries retries: ${lastException?.message ?? "Unknown error"}',
      originalError: lastException,
      serviceName: serviceName,
    );
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
    
    return null;
  }

  /// Generate hash for cache key
  String _generateHash(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Determine if a request should be retried
  bool _shouldRetry(int? statusCode, DioExceptionType? errorType, int attempt) {
    if (attempt >= maxRetries) {
      return false;
    }

    if (statusCode != null) {
      if (statusCode == 429) {
        return true;
      }
      if (statusCode >= 500 && statusCode < 600) {
        return true;
      }
    }

    if (errorType == DioExceptionType.connectionTimeout ||
        errorType == DioExceptionType.receiveTimeout ||
        errorType == DioExceptionType.sendTimeout ||
        errorType == DioExceptionType.connectionError) {
      return true;
    }

    return false;
  }
}
