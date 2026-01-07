import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'base_translation_service.dart';
import 'libretranslate_service.dart';
import 'google_translate_service.dart';
import 'mymemory_service.dart';

/// Manages multiple translation services with automatic failover
/// 
/// Tries services in priority order and automatically falls back to the next
/// service if the current one fails
class TranslationServiceManager extends BaseTranslationService {
  /// List of translation services in priority order
  final List<BaseTranslationService> _services;

  /// Currently active service (last successful service)
  BaseTranslationService? _activeService;

  /// Create a new TranslationServiceManager
  /// 
  /// [services] - List of translation services in priority order
  ///              First service will be tried first, then fallback to others
  TranslationServiceManager(List<BaseTranslationService> services)
      : _services = List.unmodifiable(services) {
    if (_services.isEmpty) {
      throw ArgumentError('At least one translation service must be provided');
    }
    
    // Filter out unavailable services
    final availableServices = _services.where((s) => s.isAvailable).toList();
    if (availableServices.isEmpty) {
      throw ArgumentError('At least one available translation service must be provided');
    }
    
    // Set initial active service to first available one
    _activeService = availableServices.first;
  }

  /// Create a default manager with standard services
  /// 
  /// Priority order:
  /// 1. Google Translate (primary, if API key provided)
  /// 2. MyMemory (fallback, free tier, no API key required)
  /// 3. LibreTranslate (optional fallback, free, no API key required)
  /// 
  /// [libreTranslateUrl] - Optional custom LibreTranslate URL
  /// [googleApiKey] - Optional Google Translate API key (recommended for primary service)
  /// [dio] - Optional Dio instance for dependency injection
  factory TranslationServiceManager.defaultManager({
    String? libreTranslateUrl,
    String? googleApiKey,
  }) {
    final services = <BaseTranslationService>[
      // Primary: Google Translate (free tier: 500,000 characters/month)
      // Requires API key (free to obtain from Google Cloud Console)
      if (googleApiKey != null && googleApiKey.isNotEmpty)
        GoogleTranslateService(apiKey: googleApiKey),
      
      // Fallback: MyMemory (free tier: 10,000 words/day, no API key required)
      MyMemoryService(),
      
      // Optional fallback: LibreTranslate (free, no API key required)
      LibreTranslateService(baseUrl: libreTranslateUrl),
    ];

    return TranslationServiceManager(services);
  }

  @override
  String get serviceName => 'TranslationServiceManager';

  @override
  Dio get dio => _activeService?.dio ?? _services.first.dio;

  @override
  int get maxTextLength {
    // Return the maximum text length supported by any service
    return _services.map((s) => s.maxTextLength).reduce((a, b) => a > b ? a : b);
  }

  @override
  Duration get requestTimeout => _services.first.requestTimeout;

  @override
  int get maxRetries => _services.first.maxRetries;

  @override
  bool get isAvailable => _services.any((s) => s.isAvailable);

  /// Get list of available services
  List<String> getAvailableServices() {
    return _services
        .where((s) => s.isAvailable)
        .map((s) => s.serviceName)
        .toList();
  }

  /// Get the currently active service name
  String? getActiveServiceName() {
    return _activeService?.serviceName;
  }

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

    // Try active service first (if available)
    if (_activeService != null && _activeService!.isAvailable) {
      try {
        final result = await _activeService!.translate(
          text: trimmedText,
          targetLanguage: targetLanguage,
          sourceLanguage: sourceLanguage,
        );
        debugPrint('Translation successful using ${_activeService!.serviceName}');
        return result;
      } on TranslationException catch (e) {
        // Check if we should try another service
        if (!_activeService!.shouldFallback(e)) {
          // Don't fallback on client errors (4xx except 429)
          rethrow;
        }
        debugPrint('${_activeService!.serviceName} failed: ${e.message}. Trying fallback...');
      } catch (e) {
        debugPrint('${_activeService!.serviceName} failed with unexpected error: $e. Trying fallback...');
      }
    }

    // Try other services in order (fallback chain)
    final triedServices = <String>[];
    TranslationException? lastException;
    
    for (final service in _services) {
      // Skip if already tried or not available
      if (service == _activeService || !service.isAvailable) {
        continue;
      }

      triedServices.add(service.serviceName);

      try {
        final result = await service.translate(
          text: trimmedText,
          targetLanguage: targetLanguage,
          sourceLanguage: sourceLanguage,
        );
        
        // Update active service on success
        _activeService = service;
        debugPrint('Translation successful using ${service.serviceName} (fallback)');
        return result;
      } on TranslationException catch (e) {
        lastException = e;
        // Check if we should try next service
        if (!service.shouldFallback(e)) {
          // Don't fallback on client errors (4xx except 429)
          // But continue to next service in fallback chain if we haven't exhausted all options
          debugPrint('${service.serviceName} failed with non-retryable error: ${e.message}');
          // Continue to next service anyway since we're in fallback mode
        } else {
          debugPrint('${service.serviceName} failed: ${e.message}. Trying next service...');
        }
      } catch (e) {
        // Wrap unexpected errors in TranslationException for consistent handling
        lastException = TranslationException(
          'Unexpected error: ${e.toString()}',
          originalError: e,
          serviceName: service.serviceName,
        );
        debugPrint('${service.serviceName} failed with unexpected error: $e. Trying next service...');
      }
    }

    // All services failed
    final errorMessage = triedServices.isEmpty
        ? 'No available translation services'
        : 'All translation services failed. Tried: ${triedServices.join(", ")}';
    
    throw TranslationException(
      errorMessage,
      statusCode: lastException?.statusCode,
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

    // Try active service first (if available)
    if (_activeService != null && _activeService!.isAvailable) {
      try {
        final result = await _activeService!.detectLanguage(trimmedText);
        debugPrint('Language detection successful using ${_activeService!.serviceName}');
        return result;
      } on LanguageDetectionException catch (e) {
        if (!_activeService!.shouldFallbackDetection(e)) {
          rethrow;
        }
        debugPrint('${_activeService!.serviceName} detection failed: ${e.message}. Trying fallback...');
      } catch (e) {
        debugPrint('${_activeService!.serviceName} detection failed with unexpected error: $e. Trying fallback...');
      }
    }

    // Try other services in order (fallback chain)
    final triedServices = <String>[];
    LanguageDetectionException? lastException;
    
    for (final service in _services) {
      if (service == _activeService || !service.isAvailable) {
        continue;
      }

      triedServices.add(service.serviceName);

      try {
        final result = await service.detectLanguage(trimmedText);
        _activeService = service;
        debugPrint('Language detection successful using ${service.serviceName} (fallback)');
        return result;
      } on LanguageDetectionException catch (e) {
        lastException = e;
        if (!service.shouldFallbackDetection(e)) {
          debugPrint('${service.serviceName} detection failed with non-retryable error: ${e.message}');
        } else {
          debugPrint('${service.serviceName} detection failed: ${e.message}. Trying next service...');
        }
      } catch (e) {
        // Wrap unexpected errors in LanguageDetectionException
        lastException = LanguageDetectionException(
          'Unexpected error: ${e.toString()}',
          originalError: e,
          serviceName: service.serviceName,
        );
        debugPrint('${service.serviceName} detection failed with unexpected error: $e. Trying next service...');
      }
    }

    // All services failed - use pattern-based fallback from LibreTranslate if available
    final libreService = _services.whereType<LibreTranslateService>().firstOrNull;
    if (libreService != null) {
      try {
        // LibreTranslate has pattern-based detection fallback
        return await libreService.detectLanguage(trimmedText);
      } catch (e) {
        debugPrint('Pattern-based detection also failed: $e');
      }
    }

    final errorMessage = triedServices.isEmpty
        ? 'No available language detection services'
        : 'All language detection services failed. Tried: ${triedServices.join(", ")}';
    
    throw LanguageDetectionException(
      errorMessage,
      originalError: lastException,
      serviceName: serviceName,
    );
  }

  @override
  bool isLanguageSupported(String code) {
    // Check if any service supports the language
    return _services.any((s) => s.isLanguageSupported(code));
  }

  @override
  List<String> getSupportedLanguages() {
    // Return union of all supported languages
    final allLanguages = <String>{};
    for (final service in _services) {
      allLanguages.addAll(service.getSupportedLanguages());
    }
    return allLanguages.toList()..sort();
  }

  /// Reset the active service to the first available service
  void resetActiveService() {
    _activeService = _services.where((s) => s.isAvailable).firstOrNull;
  }

  /// Set a specific service as active (for testing or manual selection)
  void setActiveService(BaseTranslationService service) {
    if (!_services.contains(service)) {
      throw ArgumentError('Service is not in the managed services list');
    }
    if (!service.isAvailable) {
      throw ArgumentError('Service is not available');
    }
    _activeService = service;
  }
}
