import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'base_translation_service.dart';
import '../translation_service.dart' show SupportedLanguages;

/// Google Translate API service (free tier)
/// 
/// Free tier: 500,000 characters/month
/// Requires API key (free to obtain from Google Cloud Console)
class GoogleTranslateService extends BaseTranslationService {
  /// Google Translate API base URL
  static const String _baseUrl = 'https://translation.googleapis.com/language/translate/v2';

  /// API key (optional, can be set via constructor)
  final String? _apiKey;

  /// HTTP client instance
  late final Dio _dioInstance;

  /// Maximum text length per request (Google Translate limit)
  static const int _maxTextLength = 5000;

  /// Request timeout duration
  static const Duration _requestTimeout = Duration(seconds: 30);

  /// Maximum retry attempts
  static const int _maxRetries = 3;

  /// Create a new GoogleTranslateService instance
  /// 
  /// [apiKey] - Optional Google Cloud API key
  ///            If not provided, service will not be available
  /// [dio] - Optional Dio instance for dependency injection
  GoogleTranslateService({String? apiKey, Dio? dio}) : _apiKey = apiKey {
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
  String get serviceName => 'Google Translate';

  @override
  Dio get dio => _dioInstance;

  @override
  int get maxTextLength => _maxTextLength;

  @override
  Duration get requestTimeout => _requestTimeout;

  @override
  int get maxRetries => _maxRetries;

  @override
  bool get isAvailable => _apiKey != null && _apiKey!.isNotEmpty;

  @override
  Future<String> translate({
    required String text,
    required String targetLanguage,
    String? sourceLanguage,
  }) async {
    if (!isAvailable) {
      throw TranslationException(
        'Google Translate API key not configured',
        serviceName: serviceName,
      );
    }

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

    // Google Translate uses different language codes for some languages
    final googleTargetLang = _convertToGoogleLanguageCode(targetLanguage);
    final googleSourceLang = sourceLanguage == 'auto' || sourceLanguage == null
        ? null
        : _convertToGoogleLanguageCode(sourceLanguage);

    int attempt = 0;
    DioException? lastException;

    while (attempt <= maxRetries) {
      try {
        final queryParams = <String, dynamic>{
          'key': _apiKey,
          'q': trimmedText,
          'target': googleTargetLang,
        };

        if (googleSourceLang != null) {
          queryParams['source'] = googleSourceLang;
        }

        final response = await _dioInstance.get(
          '',
          queryParameters: queryParams,
        );

        if (response.statusCode == 200 && response.data != null) {
          final data = response.data['data'];
          if (data != null && data['translations'] != null) {
            final translations = data['translations'] as List;
            if (translations.isNotEmpty) {
              final translatedText = translations[0]['translatedText'] as String?;
              if (translatedText != null && translatedText.isNotEmpty) {
                return translatedText;
              }
            }
          }
        }

        throw TranslationException(
          'Invalid response from Google Translate API',
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
              message = 'Invalid request. Please check your input and API key.';
              break;
            case 403:
              message = 'Access forbidden. Please check your API key and billing status.';
              break;
            case 429:
              message = 'Rate limit exceeded. Please try again later.';
              break;
            case 500:
            case 502:
            case 503:
              message = 'Google Translate service error. Please try again later.';
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
          debugPrint('Google Translate request failed (attempt $attempt/$maxRetries). Retrying in ${delaySeconds}s...');
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
    if (!isAvailable) {
      throw LanguageDetectionException(
        'Google Translate API key not configured',
        serviceName: serviceName,
      );
    }

    final trimmedText = text.trim();
    if (trimmedText.isEmpty) {
      return 'en';
    }

    int attempt = 0;
    DioException? lastException;

    while (attempt <= maxRetries) {
      try {
        final response = await _dioInstance.get(
          '/detect',
          queryParameters: {
            'key': _apiKey,
            'q': trimmedText,
          },
        );

        if (response.statusCode == 200 && response.data != null) {
          final data = response.data['data'];
          if (data != null && data['detections'] != null) {
            final detections = data['detections'] as List;
            if (detections.isNotEmpty && detections[0].isNotEmpty) {
              final detection = detections[0][0];
              final langCode = detection['language'] as String;
              // Convert Google language code to our format
              final convertedCode = _convertFromGoogleLanguageCode(langCode);
              if (SupportedLanguages.isSupported(convertedCode)) {
                return convertedCode;
              }
            }
          }
        }

        throw LanguageDetectionException(
          'Invalid response from Google Translate detection API',
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
          debugPrint('Google Translate detection failed (attempt $attempt/$maxRetries). Retrying in ${delaySeconds}s...');
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

  @override
  bool isLanguageSupported(String code) {
    return SupportedLanguages.isSupported(code);
  }

  @override
  List<String> getSupportedLanguages() {
    return SupportedLanguages.getSupportedCodes();
  }

  /// Convert our language code to Google Translate language code
  /// Google Translate uses some different codes (e.g., 'zh-CN' instead of 'zh')
  String _convertToGoogleLanguageCode(String code) {
    // Google Translate uses specific variants for some languages
    final googleCodes = {
      'zh': 'zh-CN', // Chinese Simplified
      'pt': 'pt-BR', // Portuguese Brazil (most common)
    };
    return googleCodes[code.toLowerCase()] ?? code.toLowerCase();
  }

  /// Convert Google Translate language code to our format
  String _convertFromGoogleLanguageCode(String googleCode) {
    // Convert Google-specific codes back to our format
    if (googleCode.startsWith('zh')) return 'zh';
    if (googleCode.startsWith('pt')) return 'pt';
    return googleCode.split('-')[0].toLowerCase();
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
