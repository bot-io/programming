import 'package:dio/dio.dart';

/// Exception thrown when translation fails
class TranslationException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic originalError;
  final String? serviceName;

  TranslationException(
    this.message, {
    this.statusCode,
    this.originalError,
    this.serviceName,
  });

  @override
  String toString() => 'TranslationException${serviceName != null ? " ($serviceName)" : ""}: $message';
}

/// Exception thrown when language detection fails
class LanguageDetectionException implements Exception {
  final String message;
  final dynamic originalError;
  final String? serviceName;

  LanguageDetectionException(
    this.message, {
    this.originalError,
    this.serviceName,
  });

  @override
  String toString() => 'LanguageDetectionException${serviceName != null ? " ($serviceName)" : ""}: $message';
}

/// Abstract base class for translation services
abstract class BaseTranslationService {
  /// Service name for logging and error messages
  String get serviceName;

  /// HTTP client for API calls
  Dio get dio;

  /// Maximum text length per translation request
  int get maxTextLength;

  /// Request timeout duration
  Duration get requestTimeout;

  /// Maximum number of retry attempts
  int get maxRetries;

  /// Check if the service is available/configured
  bool get isAvailable;

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
  });

  /// Detect the language of the given text
  /// 
  /// [text] - Text to detect language for
  /// 
  /// Returns language code (e.g., 'en', 'es')
  /// 
  /// Throws [LanguageDetectionException] if detection fails
  Future<String> detectLanguage(String text);

  /// Check if a language is supported by this service
  bool isLanguageSupported(String code);

  /// Get list of supported language codes
  List<String> getSupportedLanguages();

  /// Determine if an error should trigger a fallback to another service
  /// 
  /// Returns true if the error is transient and another service should be tried
  bool shouldFallback(TranslationException error) {
    // Don't fallback on client errors (4xx except 429)
    if (error.statusCode != null) {
      if (error.statusCode! >= 400 && error.statusCode! < 500 && error.statusCode != 429) {
        return false;
      }
    }
    
    // Fallback on server errors (5xx), rate limits (429), and network errors
    return true;
  }

  /// Determine if a language detection error should trigger a fallback
  bool shouldFallbackDetection(LanguageDetectionException error) {
    // Similar logic to translation fallback
    return true;
  }
}
