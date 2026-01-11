import 'package:dual_reader/src/domain/services/translation_service.dart';
import 'package:dual_reader/src/data/services/translation_cache_service.dart';
import 'package:flutter/foundation.dart';
import 'client_side_translation_service_mobile_hybrid.dart'
    if (dart.library.html) 'client_side_translation_service_web.dart';

/// Client-side translation service that uses:
/// - Google ML Kit on mobile (offline, free)
/// - Transformers.js on web (runs in browser)
/// This provides fast translation with offline capability after models download.
class ClientSideTranslationService implements TranslationService {
  final TranslationCacheService _cacheService;
  final ClientSideTranslationDelegate _delegate;

  ClientSideTranslationService(this._cacheService)
      : _delegate = createClientSideDelegate();

  @override
  Future<String> translate({
    required String text,
    required String targetLanguage,
    String? sourceLanguage,
  }) async {
    // Try cache first
    final cachedTranslation = _cacheService.getCachedTranslation(text, targetLanguage);
    if (cachedTranslation != null) {
      debugPrint('[ClientSideTranslation] Cache hit for: "$text"');
      return cachedTranslation;
    }

    try {
      debugPrint('[ClientSideTranslation] Translating to $targetLanguage: "${text.substring(0, text.length > 50 ? 50 : text.length)}..."');

      final translated = await _delegate.translate(
        text: text,
        targetLanguage: targetLanguage,
        sourceLanguage: sourceLanguage,
      );

      debugPrint('[ClientSideTranslation] Translation complete');

      // Cache the result
      await _cacheService.cacheTranslation(text, targetLanguage, translated);

      return translated;
    } catch (e, stack) {
      debugPrint('[ClientSideTranslation] Translation error: $e\n$stack');
      rethrow;
    }
  }

  @override
  Future<String> detectLanguage(String text) async {
    return _delegate.detectLanguage(text);
  }

  /// Close and clean up translators
  Future<void> close() async {
    await _delegate.close();
  }

  /// Check if a language model is downloaded and ready
  Future<bool> isLanguageModelReady(String languageCode) async {
    return _delegate.isLanguageModelReady(languageCode);
  }

  /// Download and prepare a language model
  Future<bool> downloadLanguageModel(String languageCode, {void Function(String)? onProgress}) async {
    return _delegate.downloadLanguageModel(languageCode, onProgress: onProgress);
  }
}

/// Public interface for platform-specific implementations
abstract class ClientSideTranslationDelegate {
  Future<String> translate({
    required String text,
    required String targetLanguage,
    String? sourceLanguage,
  });

  Future<String> detectLanguage(String text);

  Future<void> close();

  /// Check if a language model is downloaded and ready
  Future<bool> isLanguageModelReady(String languageCode);

  /// Download and prepare a language model
  Future<bool> downloadLanguageModel(String languageCode, {void Function(String)? onProgress});
}

/// Factory function to create platform-specific delegate
ClientSideTranslationDelegate createClientSideDelegate() {
  return ClientSideTranslationDelegateImpl();
}
