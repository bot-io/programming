import 'package:flutter/foundation.dart';
import 'package:dual_reader/src/data/services/client_side_translation_service.dart';
import 'package:dual_reader/src/data/services/libretranslate_service_impl.dart';
import 'package:http/http.dart' as http;

/// Web-specific implementation using LibreTranslate free API
/// Uses the free Argos Open Tech API for client-side translation
/// API: https://translate.argosopentech.com
/// Supports 20+ languages with no API key required
class ClientSideTranslationDelegateImpl implements ClientSideTranslationDelegate {

  final LibreTranslateServiceImpl _apiService;

  ClientSideTranslationDelegateImpl() : _apiService = LibreTranslateServiceImpl(
    const NoOpCacheService(),
    http.Client(),
  );

  @override
  Future<String> translate({
    required String text,
    required String targetLanguage,
    String? sourceLanguage,
  }) async {
    try {
      debugPrint('[WebTranslation] Using LibreTranslate API');
      debugPrint('[WebTranslation] Translating to $targetLanguage');

      // LibreTranslate supports auto-detection with "auto" as source
      final result = await _apiService.translate(
        text: text,
        targetLanguage: targetLanguage,
        sourceLanguage: sourceLanguage ?? 'auto',
      );

      debugPrint('[WebTranslation] Translation complete');
      return result;
    } catch (e) {
      debugPrint('[WebTranslation] Error: $e');
      rethrow;
    }
  }

  @override
  Future<String> detectLanguage(String text) async {
    // For web, we'll rely on LibreTranslate's auto-detection
    // The /detect endpoint sometimes has CORS issues, so we return 'en' as default
    // and let the API handle auto-detection during translation
    return 'en';
  }

  @override
  Future<void> close() async {
    // No cleanup needed - API is stateless
    debugPrint('[WebTranslation] Web service closed');
  }

  @override
  Future<bool> isLanguageModelReady(String languageCode) async {
    // Web uses API, no model download needed
    return true;
  }

  @override
  Future<bool> downloadLanguageModel(String languageCode, {void Function(String)? onProgress}) async {
    // Web uses API, no model download needed
    onProgress?.call('Using web API - no download needed');
    return true;
  }
}

/// No-op cache service for API calls (caching handled by LibreTranslateServiceImpl)
class NoOpCacheService {
  const NoOpCacheService();
  String? getCachedTranslation(String text, String targetLanguage) => null;
  Future<void> cacheTranslation(String text, String targetLanguage, String translation) async {}
}
