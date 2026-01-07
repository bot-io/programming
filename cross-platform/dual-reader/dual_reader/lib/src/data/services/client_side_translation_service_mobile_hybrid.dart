import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:dual_reader/src/data/services/client_side_translation_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Hybrid implementation that uses ML Kit with LibreTranslate fallback
class ClientSideTranslationDelegateImpl implements ClientSideTranslationDelegate {
  // Lazy-loaded translators keyed by language code
  final Map<String, OnDeviceTranslator> _translators = {};
  final http.Client _httpClient = http.Client();

  @override
  Future<String> translate({
    required String text,
    required String targetLanguage,
    String? sourceLanguage,
  }) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      throw UnsupportedError('ML Kit translation is only supported on Android and iOS');
    }

    debugPrint('[HybridTranslation] Translating to $targetLanguage using ML Kit with API fallback');

    // Try ML Kit first with longer timeout for model download
    try {
      debugPrint('[HybridTranslation] Step 1: Creating/Loading ML Kit translator...');
      final translator = await _getTranslator(
        sourceLanguage ?? 'en',
        targetLanguage,
      ).timeout(
        const Duration(minutes: 3),
        onTimeout: () {
          debugPrint('[HybridTranslation] ML Kit translator creation timed out after 3 minutes');
          throw TimeoutException('ML Kit translator creation timeout (3 minutes). The language model may still be downloading in the background. Please try again in a minute.');
        },
      );

      debugPrint('[HybridTranslation] Step 2: Translating text with ML Kit...');
      final translated = await translator.translateText(text).timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          debugPrint('[HybridTranslation] ML Kit translation timed out after 60s');
          throw TimeoutException('ML Kit translation timeout (60s)');
        },
      );

      debugPrint('[HybridTranslation] ML Kit translation successful!');
      return translated;
    } catch (e) {
      debugPrint('[HybridTranslation] ML Kit failed: $e');
      debugPrint('[HybridTranslation] Falling back to LibreTranslate API...');

      // Fallback to LibreTranslate API (may not support all languages)
      try {
        return await _translateWithLibre(text, sourceLanguage ?? 'en', targetLanguage);
      } catch (apiError) {
        debugPrint('[HybridTranslation] API fallback also failed: $apiError');
        throw Exception('Translation failed for language "$targetLanguage".\n\nML Kit error: $e\n\nAPI fallback also failed: $apiError\n\n💡 Tips:\n• First-time translation for a language requires downloading ML Kit models (can take 1-3 minutes on emulator)\n• Try again - the model may still be downloading in the background\n• Some LibreTranslate API endpoints may be temporarily unavailable\n• Check your internet connection if using API fallback');
      }
    }
  }

  /// Fallback translation using LibreTranslate API
  Future<String> _translateWithLibre(String text, String sourceLanguage, String targetLanguage) async {
    const endpoints = [
      'https://translate.argosopentech.com/translate',
      'https://libretranslate.com/translate',
      'https://translate.terraprint.co/translate',
    ];

    final errors = <String>[];

    for (final endpoint in endpoints) {
      try {
        debugPrint('[HybridTranslation] Trying API endpoint: $endpoint for $targetLanguage');
        final response = await _httpClient.post(
          Uri.parse(endpoint),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'q': text,
            'source': sourceLanguage,
            'target': targetLanguage,
            'format': 'text',
          }),
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw TimeoutException('API request timeout');
          },
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data.containsKey('translatedText')) {
            final translatedText = data['translatedText'];
            debugPrint('[HybridTranslation] API translation successful via $endpoint');
            return translatedText;
          } else {
            errors.add('$endpoint: No translatedText in response - language may not be supported');
          }
        } else if (response.statusCode == 400) {
          final data = jsonDecode(response.body);
          errors.add('$endpoint: ${data['error'] ?? 'Bad request - language may not be supported'}');
        } else {
          errors.add('$endpoint: HTTP ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('[HybridTranslation] Endpoint $endpoint failed: $e');
        errors.add('$endpoint: $e');
        continue;
      }
    }

    throw Exception('LibreTranslate API failed for language "$targetLanguage". Errors: ${errors.join('; ')}.\nNote: LibreTranslate may not support all languages. ML Kit models will work after download completes.');
  }

  /// Get or create ML Kit translator for source and target languages
  Future<OnDeviceTranslator> _getTranslator(String sourceLanguage, String targetLanguage) async {
    // Create a composite key for the language pair
    final key = '$sourceLanguage-$targetLanguage';

    // Check if translator already exists
    if (_translators.containsKey(key)) {
      debugPrint('[HybridTranslation] Using cached ML Kit translator for $key');
      return _translators[key]!;
    }

    debugPrint('[HybridTranslation] Creating ML Kit translator: $sourceLanguage -> $targetLanguage');

    // Convert language codes to TranslateLanguage enum values
    final sourceLang = _toTranslateLanguage(sourceLanguage);
    final targetLang = _toTranslateLanguage(targetLanguage);

    // Create the translator using the new API
    final translator = OnDeviceTranslator(
      sourceLanguage: sourceLang,
      targetLanguage: targetLang,
    );

    _translators[key] = translator;
    debugPrint('[HybridTranslation] ML Kit translator created for $key');
    return translator;
  }

  /// Convert language code to TranslateLanguage enum
  TranslateLanguage _toTranslateLanguage(String languageCode) {
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
    final lowerText = text.toLowerCase();

    if (RegExp(r'[а-я]').hasMatch(text)) {
      if (RegExp(r'[бгджзклмнптфцчшщъы]').hasMatch(text)) {
        return 'bg';
      }
      return 'ru';
    }

    if (RegExp(r'[\u4e00-\u9fff]').hasMatch(text)) {
      return 'zh';
    }

    if (RegExp(r'[\u3040-\u309f\u30a0-\u30ff]').hasMatch(text)) {
      return 'ja';
    }

    if (RegExp(r'[\uac00-\ud7af]').hasMatch(text)) {
      return 'ko';
    }

    if (RegExp(r'[\u0600-\u06ff]').hasMatch(text)) {
      return 'ar';
    }

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

    return 'en';
  }

  /// Check if a language model is downloaded and ready
  /// Returns true if the model is already cached, false otherwise
  Future<bool> isLanguageModelReady(String languageCode) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return false;
    }

    final key = 'en-$languageCode';
    if (_translators.containsKey(key)) {
      debugPrint('[HybridTranslation] Model already cached for $languageCode');
      return true;
    }

    // Quick check: just return false if not cached, don't try to download
    // The download will happen when explicitly requested
    debugPrint('[HybridTranslation] Model not cached for $languageCode');
    return false;
  }

  /// Download and prepare a language model
  /// Returns true if successful, false otherwise
  Future<bool> downloadLanguageModel(String languageCode, {void Function(String)? onProgress}) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      throw UnsupportedError('ML Kit translation is only supported on Android and iOS');
    }

    // Check if already cached
    final key = 'en-$languageCode';
    if (_translators.containsKey(key)) {
      onProgress?.call('Model already available');
      debugPrint('[HybridTranslation] Model already available for $languageCode');
      return true;
    }

    try {
      onProgress?.call('Starting model download...');
      debugPrint('[HybridTranslation] Downloading model for $languageCode');

      final sourceLang = _toTranslateLanguage('en');
      final targetLang = _toTranslateLanguage(languageCode);

      onProgress?.call('Initializing translator...');

      final translator = OnDeviceTranslator(
        sourceLanguage: sourceLang,
        targetLanguage: targetLang,
      );

      onProgress?.call('Downloading language model (this may take 1-3 minutes)...');

      // Translate a test phrase to trigger model download
      final result = await translator.translateText('Hello').timeout(
        const Duration(minutes: 3),
        onTimeout: () {
          onProgress?.call('Download timeout - please check your connection');
          throw TimeoutException('Model download timeout (3 minutes)');
        },
      );

      debugPrint('[HybridTranslation] Test translation result: $result');
      onProgress?.call('Model downloaded successfully!');

      // Cache the translator (keep it open for future use)
      _translators[key] = translator;

      debugPrint('[HybridTranslation] Model downloaded and cached for $languageCode');
      return true;
    } catch (e) {
      debugPrint('[HybridTranslation] Model download failed for $languageCode: $e');
      onProgress?.call('Download failed: $e');
      return false;
    }
  }

  @override
  Future<void> close() async {
    _httpClient.close();
    for (final translator in _translators.values) {
      try {
        translator.close();
      } catch (e) {
        debugPrint('[HybridTranslation] Error closing translator: $e');
      }
    }
    _translators.clear();
  }
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);
  @override
  String toString() => message;
}
