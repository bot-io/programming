import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:dual_reader/src/data/services/client_side_translation_service.dart';
import 'package:dual_reader/src/core/utils/logging_service.dart';
import 'dart:async';

// Platform-specific implementation for mobile (Android/iOS)
class ClientSideTranslationDelegateImpl implements ClientSideTranslationDelegate {
  static const String _componentName = 'ClientSideTranslation';

  // Lazy-loaded translators keyed by language code
  final Map<String, OnDeviceTranslator> _translators = {};

  @override
  Future<String> translate({
    required String text,
    required String targetLanguage,
    String? sourceLanguage,
  }) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      _componentName.logError('Translation attempted on unsupported platform');
      throw UnsupportedError('ML Kit translation is only supported on Android and iOS');
    }

    final stopwatch = Stopwatch()..start();
    final source = sourceLanguage ?? 'en';

    // Log translation request with truncated text (first 50 chars)
    final textPreview = text.length > 50 ? '${text.substring(0, 50)}...' : text;
    _componentName.logInfo(
      'Translation requested - source: $source, target: $targetLanguage, text: "$textPreview" (${text.length} chars)'
    );

    try {
      // Get or create translator for target language
      final translator = await _getTranslator(source, targetLanguage);

      // Preserve paragraph structure by translating each paragraph separately
      final stopwatchTranslate = Stopwatch()..start();
      final translated = await _translatePreservingStructure(translator, text);
      stopwatchTranslate.stop();

      stopwatch.stop();

      // Log successful translation with performance metrics
      _componentName.logInfo(
        'Translation complete - result: ${translated.length} chars, duration: ${stopwatchTranslate.elapsed.inMilliseconds}ms (total: ${stopwatch.elapsed.inMilliseconds}ms)'
      );

      return translated;
    } catch (e, stackTrace) {
      stopwatch.stop();
      _componentName.logError(
        'Translation failed - source: $source, target: $targetLanguage, duration: ${stopwatch.elapsed.inMilliseconds}ms',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get or create ML Kit translator for source and target languages
  /// Uses a composite key to cache translators for different language pairs
  Future<OnDeviceTranslator> _getTranslator(String sourceLanguage, String targetLanguage) async {
    // Create a composite key for the language pair
    final key = '$sourceLanguage-$targetLanguage';

    // Check if translator already exists (cache hit)
    if (_translators.containsKey(key)) {
      _componentName.logDebug('Using cached translator - key: $key');
      return _translators[key]!;
    }

    _componentName.logInfo('Creating new ML Kit translator - key: $key');

    final stopwatch = Stopwatch()..start();
    try {
      // Convert language codes to TranslateLanguage enum values
      final sourceLang = _toTranslateLanguage(sourceLanguage);
      final targetLang = _toTranslateLanguage(targetLanguage);

      _componentName.logDebug('Language codes mapped - source: ${sourceLang.name}, target: ${targetLang.name}');

      // Create the translator using the new API
      final translator = OnDeviceTranslator(
        sourceLanguage: sourceLang,
        targetLanguage: targetLang,
      );

      // Download the translation model if needed (this is required for ML Kit to work)
      _componentName.logInfo('Initializing translator (model download may be required) - key: $key');
      // Note: The model download happens automatically on first translation in newer ML Kit versions

      _translators[key] = translator;
      stopwatch.stop();

      _componentName.logInfo('Translator created and cached - key: $key, duration: ${stopwatch.elapsed.inMilliseconds}ms');
      return translator;
    } catch (e, stackTrace) {
      stopwatch.stop();
      _componentName.logError(
        'Failed to create translator - key: $key, duration: ${stopwatch.elapsed.inMilliseconds}ms',
        error: e,
        stackTrace: stackTrace,
      );
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

  /// Translate text while preserving paragraph structure
  /// Splits text into paragraphs, translates each separately, then reassembles
  Future<String> _translatePreservingStructure(OnDeviceTranslator translator, String text) async {
    // Split into paragraphs (double newlines indicate paragraph breaks)
    final paragraphs = text.split(RegExp(r'\n\s*\n'));

    _componentName.logDebug('Preserving structure - ${paragraphs.length} paragraph(s) to translate');

    final translatedParagraphs = <String>[];

    for (int i = 0; i < paragraphs.length; i++) {
      final paragraph = paragraphs[i].trim();

      if (paragraph.isEmpty) {
        // Preserve empty paragraphs
        translatedParagraphs.add('');
        continue;
      }

      // Translate this paragraph
      final translated = await translator.translateText(paragraph);

      translatedParagraphs.add(translated);
      _componentName.logDebug('Translated paragraph $i/${paragraphs.length}');
    }

    // Reassemble with paragraph breaks (double newlines)
    return translatedParagraphs.join('\n\n');
  }

  @override
  Future<String> detectLanguage(String text) async {
    _componentName.logDebug('Language detection requested - text length: ${text.length} chars');

    // Simple heuristic-based language detection
    final lowerText = text.toLowerCase();

    // Check for Cyrillic
    if (RegExp(r'[а-я]').hasMatch(text)) {
      if (RegExp(r'[бгджзклмнптфцчшщъы]').hasMatch(text)) {
        _componentName.logDebug('Detected language: Bulgarian (Cyrillic with BG-specific chars)');
        return 'bg';
      }
      _componentName.logDebug('Detected language: Russian (Cyrillic)');
      return 'ru';
    }

    // Check for Chinese
    if (RegExp(r'[\u4e00-\u9fff]').hasMatch(text)) {
      _componentName.logDebug('Detected language: Chinese');
      return 'zh';
    }

    // Check for Japanese
    if (RegExp(r'[\u3040-\u309f\u30a0-\u30ff]').hasMatch(text)) {
      _componentName.logDebug('Detected language: Japanese');
      return 'ja';
    }

    // Check for Korean
    if (RegExp(r'[\uac00-\ud7af]').hasMatch(text)) {
      _componentName.logDebug('Detected language: Korean');
      return 'ko';
    }

    // Check for Arabic
    if (RegExp(r'[\u0600-\u06ff]').hasMatch(text)) {
      _componentName.logDebug('Detected language: Arabic');
      return 'ar';
    }

    // European languages (simple heuristic)
    if (lowerText.contains(' el ') || lowerText.contains(' la ') || lowerText.contains(' los ')) {
      _componentName.logDebug('Detected language: Spanish');
      return 'es';
    }
    if (lowerText.contains(' le ') || lowerText.contains(' les ') || lowerText.contains(" d'")) {
      _componentName.logDebug('Detected language: French');
      return 'fr';
    }
    if (lowerText.contains(' der ') || lowerText.contains(' die ') || lowerText.contains(' das ')) {
      _componentName.logDebug('Detected language: German');
      return 'de';
    }
    if (lowerText.contains(' il ') || lowerText.contains(' lo ') || lowerText.contains(' la ')) {
      _componentName.logDebug('Detected language: Italian');
      return 'it';
    }
    if (lowerText.contains(' o ') || lowerText.contains(' um ') || lowerText.contains(' uma ')) {
      _componentName.logDebug('Detected language: Portuguese');
      return 'pt';
    }

    // Default to English
    _componentName.logDebug('Detected language: English (default)');
    return 'en';
  }

  @override
  Future<void> close() async {
    _componentName.logInfo('Closing service - translators to close: ${_translators.length}');

    int closedCount = 0;
    int errorCount = 0;

    for (final entry in _translators.entries) {
      try {
        await entry.value.close();
        closedCount++;
      } catch (e) {
        _componentName.logError('Error closing translator - key: ${entry.key}', error: e);
        errorCount++;
      }
    }

    _translators.clear();

    _componentName.logInfo('Service closed - translators closed: $closedCount, errors: $errorCount');
  }

  @override
  Future<bool> isLanguageModelReady(String languageCode) async {
    _componentName.logInfo('Checking language model readiness - language: $languageCode');

    // ML Kit downloads models on-demand, so we check if we can create a translator
    try {
      final key = 'en-$languageCode';
      if (_translators.containsKey(key)) {
        _componentName.logInfo('Model ready (cached) - language: $languageCode');
        return true;
      }

      // Try to create a test translator to check if model is available
      final targetLang = _toTranslateLanguage(languageCode);
      final testTranslator = OnDeviceTranslator(
        sourceLanguage: TranslateLanguage.english,
        targetLanguage: targetLang,
      );

      // If we got here, model is available or will be downloaded
      await testTranslator.close();

      _componentName.logInfo('Model ready (can be created) - language: $languageCode');
      return true;
    } catch (e) {
      _componentName.logWarning('Model not ready - language: $languageCode, error: $e');
      return false;
    }
  }

  @override
  Future<bool> downloadLanguageModel(String languageCode, {void Function(String)? onProgress}) async {
    _componentName.logInfo('Downloading language model - language: $languageCode');

    final stopwatch = Stopwatch()..start();
    try {
      onProgress?.call('Initializing download...');
      final key = 'en-$languageCode';

      // Check if already exists
      if (_translators.containsKey(key)) {
        _componentName.logInfo('Model already downloaded - language: $languageCode');
        onProgress?.call('Model already downloaded');
        return true;
      }

      onProgress?.call('Downloading model for $languageCode...');

      // Create the translator which will download the model
      final targetLang = _toTranslateLanguage(languageCode);
      final translator = OnDeviceTranslator(
        sourceLanguage: TranslateLanguage.english,
        targetLanguage: targetLang,
      );

      // Store it for future use
      _translators[key] = translator;

      stopwatch.stop();

      _componentName.logInfo('Model downloaded successfully - language: $languageCode, duration: ${stopwatch.elapsed.inMilliseconds}ms');
      onProgress?.call('Download complete');
      return true;
    } catch (e, stackTrace) {
      stopwatch.stop();
      _componentName.logError(
        'Model download failed - language: $languageCode, duration: ${stopwatch.elapsed.inMilliseconds}ms',
        error: e,
        stackTrace: stackTrace,
      );
      onProgress?.call('Download failed: $e');
      return false;
    }
  }
}
