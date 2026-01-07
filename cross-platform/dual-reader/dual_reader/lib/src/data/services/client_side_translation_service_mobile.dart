import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:dual_reader/src/data/services/client_side_translation_service.dart';

// Platform-specific implementation for mobile (Android/iOS)
class ClientSideTranslationDelegateImpl implements ClientSideTranslationDelegate {
  // Lazy-loaded translators keyed by language code
  final Map<String, OnDeviceTranslator> _translators = {};

  @override
  Future<String> translate({
    required String text,
    required String targetLanguage,
    String? sourceLanguage,
  }) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      throw UnsupportedError('ML Kit translation is only supported on Android and iOS');
    }

    debugPrint('[ClientSideTranslation] Using ML Kit on mobile');

    // Get or create translator for target language
    final translator = await _getTranslator(
      sourceLanguage ?? 'en',
      targetLanguage,
    );

    try {
      // Translate the text
      final translated = await translator.translateText(text);
      return translated;
    } catch (e) {
      debugPrint('[ClientSideTranslation] ML Kit translation error: $e');
      rethrow;
    }
  }

  /// Get or create ML Kit translator for source and target languages
  /// Uses a composite key to cache translators for different language pairs
  Future<OnDeviceTranslator> _getTranslator(String sourceLanguage, String targetLanguage) async {
    // Create a composite key for the language pair
    final key = '$sourceLanguage-$targetLanguage';

    // Check if translator already exists
    if (_translators.containsKey(key)) {
      return _translators[key]!;
    }

    debugPrint('[ClientSideTranslation] Creating ML Kit translator: $sourceLanguage -> $targetLanguage');

    try {
      // Convert language codes to TranslateLanguage enum values
      final sourceLang = _toTranslateLanguage(sourceLanguage);
      final targetLang = _toTranslateLanguage(targetLanguage);

      // Create the translator using the new API
      final translator = OnDeviceTranslator(
        sourceLanguage: sourceLang,
        targetLanguage: targetLang,
      );

      // Download the translation model if needed (this is required for ML Kit to work)
      debugPrint('[ClientSideTranslation] Downloading translation model for $key...');
      // Note: The model download happens automatically on first translation in newer ML Kit versions

      _translators[key] = translator;
      debugPrint('[ClientSideTranslation] ML Kit translator created for $key');
      return translator;
    } catch (e) {
      debugPrint('[ClientSideTranslation] Error creating translator: $e');
      throw UnsupportedError('Failed to create translator for $sourceLanguage -> $targetLanguage: $e');
    }
  }

  /// Convert language code to TranslateLanguage enum
  /// Maps common language codes to ML Kit TranslateLanguage enum values
  TranslateLanguage _toTranslateLanguage(String languageCode) {
    // Map common language codes to TranslateLanguage enum values
    const langMap = {
      'zh': TranslateLanguage.chinese,
      'zh-cn': TranslateLanguage.chinese,
      'zh-tw': TranslateLanguage.chinese,
      'es': TranslateLanguage.spanish,
      'fr': TranslateLanguage.french,
      'de': TranslateLanguage.german,
      'it': TranslateLanguage.italian,
      'pt': TranslateLanguage.portuguese,
      'ru': TranslateLanguage.russian,
      'bg': TranslateLanguage.bulgarian,
      'ja': TranslateLanguage.japanese,
      'ko': TranslateLanguage.korean,
      'ar': TranslateLanguage.arabic,
      'hi': TranslateLanguage.hindi,
      'th': TranslateLanguage.thai,
      'vi': TranslateLanguage.vietnamese,
      'tr': TranslateLanguage.turkish,
      'nl': TranslateLanguage.dutch,
      'pl': TranslateLanguage.polish,
      'sv': TranslateLanguage.swedish,
      'da': TranslateLanguage.danish,
      'fi': TranslateLanguage.finnish,
      'no': TranslateLanguage.norwegian,
      'uk': TranslateLanguage.ukrainian,
      'cs': TranslateLanguage.czech,
      'el': TranslateLanguage.greek,
      'he': TranslateLanguage.hebrew,
      'id': TranslateLanguage.indonesian,
      'ms': TranslateLanguage.malay,
      'ro': TranslateLanguage.romanian,
      'sk': TranslateLanguage.slovak,
      'bn': TranslateLanguage.bengali,
      'ca': TranslateLanguage.catalan,
      'fa': TranslateLanguage.persian,
      'fil': TranslateLanguage.tagalog,
      'tl': TranslateLanguage.tagalog,
      'hr': TranslateLanguage.croatian,
      'mt': TranslateLanguage.maltese,
      'sl': TranslateLanguage.slovenian,
      'en': TranslateLanguage.english,
      'af': TranslateLanguage.afrikaans,
      'sq': TranslateLanguage.albanian,
      'be': TranslateLanguage.belarusian,
      'et': TranslateLanguage.estonian,
      'ga': TranslateLanguage.irish,
      'gl': TranslateLanguage.galician,
      'ka': TranslateLanguage.georgian,
      'gu': TranslateLanguage.gujarati,
      'ht': TranslateLanguage.haitian,
      'hu': TranslateLanguage.hungarian,
      'is': TranslateLanguage.icelandic,
      'kn': TranslateLanguage.kannada,
      'lv': TranslateLanguage.latvian,
      'lt': TranslateLanguage.lithuanian,
      'mk': TranslateLanguage.macedonian,
      'mr': TranslateLanguage.marathi,
      'sw': TranslateLanguage.swahili,
      'ta': TranslateLanguage.tamil,
      'te': TranslateLanguage.telugu,
      'ur': TranslateLanguage.urdu,
      'cy': TranslateLanguage.welsh,
    };

    return langMap[languageCode.toLowerCase()] ?? TranslateLanguage.english;
  }

  @override
  Future<String> detectLanguage(String text) async {
    // Simple heuristic-based language detection
    final lowerText = text.toLowerCase();

    // Check for Cyrillic
    if (RegExp(r'[а-я]').hasMatch(text)) {
      if (RegExp(r'[бгджзклмнптфцчшщъы]').hasMatch(text)) {
        return 'bg';
      }
      return 'ru';
    }

    // Check for Chinese
    if (RegExp(r'[\u4e00-\u9fff]').hasMatch(text)) {
      return 'zh';
    }

    // Check for Japanese
    if (RegExp(r'[\u3040-\u309f\u30a0-\u30ff]').hasMatch(text)) {
      return 'ja';
    }

    // Check for Korean
    if (RegExp(r'[\uac00-\ud7af]').hasMatch(text)) {
      return 'ko';
    }

    // Check for Arabic
    if (RegExp(r'[\u0600-\u06ff]').hasMatch(text)) {
      return 'ar';
    }

    // European languages (simple heuristic)
    if (lowerText.contains(' el ') || lowerText.contains(' la ') || lowerText.contains(' los ')) {
      return 'es';
    }
    if (lowerText.contains(' le ') || lowerText.contains(' les ') || lowerText.contains(" d'")) {
      return 'fr';
    }
    if (lowerText.contains(' der ') || lowerText.contains(' die ') || lowerText.contains(' das ')) {
      return 'de';
    }
    if (lowerText.contains(' il ') || lowerText.contains(' lo ') || lowerText.contains(' la ')) {
      return 'it';
    }
    if (lowerText.contains(' o ') || lowerText.contains(' um ') || lowerText.contains(' uma ')) {
      return 'pt';
    }

    // Default to English
    return 'en';
  }

  @override
  Future<void> close() async {
    for (final translator in _translators.values) {
      try {
        translator.close();
      } catch (e) {
        debugPrint('[ClientSideTranslation] Error closing translator: $e');
      }
    }
    _translators.clear();
  }
}
