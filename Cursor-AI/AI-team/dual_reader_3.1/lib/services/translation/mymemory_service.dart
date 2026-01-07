import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'base_translation_service.dart';
import '../translation_service.dart' show SupportedLanguages;

/// MyMemory Translation API service (free tier)
/// 
/// Free tier: 10,000 words/day
/// No API key required for basic use
class MyMemoryService extends BaseTranslationService {
  /// MyMemory API base URL
  static const String _baseUrl = 'https://api.mymemory.translated.net';

  /// HTTP client instance
  late final Dio _dioInstance;

  /// Maximum text length per request (MyMemory limit)
  static const int _maxTextLength = 500;

  /// Request timeout duration
  static const Duration _requestTimeout = Duration(seconds: 30);

  /// Maximum retry attempts
  static const int _maxRetries = 3;

  /// Create a new MyMemoryService instance
  /// 
  /// [dio] - Optional Dio instance for dependency injection
  MyMemoryService({Dio? dio}) {
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
  }

  @override
  String get serviceName => 'MyMemory';

  @override
  Dio get dio => _dioInstance;

  @override
  int get maxTextLength => _maxTextLength;

  @override
  Duration get requestTimeout => _requestTimeout;

  @override
  int get maxRetries => _maxRetries;

  @override
  bool get isAvailable => true; // No API key required

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

    // MyMemory uses language pairs format: "en|es"
    final langPair = '${sourceLanguage ?? "auto"}|$targetLanguage';

    int attempt = 0;
    DioException? lastException;

    while (attempt <= maxRetries) {
      try {
        final response = await _dioInstance.get(
          '/get',
          queryParameters: {
            'q': trimmedText,
            'langpair': langPair,
          },
        );

        if (response.statusCode == 200 && response.data != null) {
          final responseData = response.data;
          
          // Check for API errors
          if (responseData['responseStatus'] == 200) {
            final translatedText = responseData['responseData']?['translatedText'] as String?;
            if (translatedText != null && translatedText.isNotEmpty) {
              return translatedText;
            }
          } else {
            // API returned an error
            final errorMessage = responseData['responseData'] as String? ?? 'Unknown error';
            throw TranslationException(
              'MyMemory API error: $errorMessage',
              statusCode: responseData['responseStatus'],
              serviceName: serviceName,
            );
          }
        }

        throw TranslationException(
          'Invalid response from MyMemory API',
          statusCode: response.statusCode,
          serviceName: serviceName,
        );
      } on DioException catch (e) {
        lastException = e;
        final statusCode = e.response?.statusCode;

        // Check if we should retry
        final shouldRetry = _shouldRetry(statusCode, e.type, attempt);

        if (!shouldRetry) {
          String message;
          switch (statusCode) {
            case 400:
              message = 'Invalid request. Please check your input.';
              break;
            case 429:
              message = 'Rate limit exceeded (10,000 words/day free limit). Please try again later.';
              break;
            case 500:
            case 502:
            case 503:
              message = 'MyMemory service error. Please try again later.';
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
          debugPrint('MyMemory request failed (attempt $attempt/$maxRetries). Retrying in ${delaySeconds}s...');
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
    // MyMemory doesn't have a dedicated detection endpoint
    // Use pattern-based detection as fallback
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) {
      return 'en';
    }

    // Use pattern-based detection (similar to LibreTranslate)
    final detected = _detectLanguageByPattern(trimmedText);
    if (detected != null) {
      return detected;
    }

    // If pattern detection fails, throw exception to trigger fallback to another service
    throw LanguageDetectionException(
      'MyMemory does not support language detection. Falling back to another service.',
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

  @override
  bool isLanguageSupported(String code) {
    // MyMemory supports many languages, but we'll use our supported list
    return SupportedLanguages.isSupported(code);
  }

  @override
  List<String> getSupportedLanguages() {
    return SupportedLanguages.getSupportedCodes();
  }

  /// Determine if a request should be retried
  bool _shouldRetry(int? statusCode, DioExceptionType? errorType, int attempt) {
    if (attempt >= maxRetries) {
      return false;
    }

    // Retry on transient server errors
    if (statusCode != null) {
      if (statusCode == 429) {
        return true;
      }
      if (statusCode >= 500 && statusCode < 600) {
        return true;
      }
    }

    // Retry on network/timeout errors
    if (errorType == DioExceptionType.connectionTimeout ||
        errorType == DioExceptionType.receiveTimeout ||
        errorType == DioExceptionType.sendTimeout ||
        errorType == DioExceptionType.connectionError) {
      return true;
    }

    return false;
  }
}
