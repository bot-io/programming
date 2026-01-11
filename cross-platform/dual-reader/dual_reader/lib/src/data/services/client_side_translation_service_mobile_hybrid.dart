import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:dual_reader/src/data/services/client_side_translation_service.dart';
import 'package:dual_reader/src/core/utils/page_markers.dart';

// ML Kit-only implementation for mobile (offline translation)
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

    debugPrint('[MLKitTranslation] Translating to $targetLanguage using ML Kit');

    // Use ML Kit with longer timeout for model download
    debugPrint('[MLKitTranslation] Step 1: Creating/Loading ML Kit translator...');
    debugPrint('[MLKitTranslation] Note: First-time translation for a language requires downloading ML Kit models (can take 3-5 minutes on emulator, 30-60 seconds on device). Please be patient...');
    final translator = await _getTranslator(
      sourceLanguage ?? 'en',
      targetLanguage,
    ).timeout(
      const Duration(minutes: 5), // Increased from 3 to 5 minutes for emulator
      onTimeout: () {
        debugPrint('[MLKitTranslation] ML Kit translator creation timed out after 5 minutes');
        throw TimeoutException('ML Kit translator creation timeout (5 minutes). The language model may still be downloading in the background. Please try again in a minute.');
      },
    );

    debugPrint('[MLKitTranslation] Step 2: Translating text with ML Kit...');

    // Preserve paragraph structure by translating each paragraph separately
    final translated = await _translatePreservingStructure(translator, text, targetLanguage);

    debugPrint('[MLKitTranslation] ML Kit translation successful!');
    return translated;
  }

  /// Translate text while preserving paragraph structure and page markers
  ///
  /// This method:
  /// 1. Extracts page markers before translation (ML Kit doesn't preserve PUA characters)
  /// 2. Splits text into paragraphs, tracking which page each belongs to
  /// 3. Translates each paragraph separately
  /// 4. Reinserts page markers and reassembles with paragraph breaks
  Future<String> _translatePreservingStructure(OnDeviceTranslator translator, String text, String targetLanguage) async {
    // Extract all page indices to know which pages exist
    final pageIndices = PageMarkers.extractPageIndices(text);
    debugPrint('[MLKitTranslation] Found ${pageIndices.length} pages with markers to preserve');

    if (pageIndices.isEmpty) {
      // No markers, fall back to simple paragraph-based translation
      return await _translateParagraphsOnly(translator, text);
    }

    // For each page, split into paragraphs and translate
    final translatedPages = <String>[];

    for (final pageIndex in pageIndices) {
      // Extract the page text (without markers)
      final pageText = PageMarkers.extractPage(text, pageIndex);

      if (pageText.isEmpty) {
        // Preserve empty pages
        translatedPages.add(PageMarkers.insertMarkers('', pageIndex));
        continue;
      }

      // Split this page into paragraphs (double newlines)
      final paragraphs = pageText.split(RegExp(r'\n\s*\n'));
      final translatedParagraphs = <String>[];

      for (int i = 0; i < paragraphs.length; i++) {
        final paragraph = paragraphs[i].trim();

        if (paragraph.isEmpty) {
          // Preserve empty paragraphs
          translatedParagraphs.add('');
          continue;
        }

        debugPrint('[MLKitTranslation] Translating page $pageIndex, paragraph $i (${paragraph.length} chars)');

        // Translate this paragraph with timeout
        final translated = await translator.translateText(paragraph).timeout(
          const Duration(minutes: 5),
          onTimeout: () {
            debugPrint('[MLKitTranslation] Page $pageIndex, paragraph $i translation timed out');
            throw TimeoutException('Paragraph translation timeout (5 minutes)');
          },
        );

        translatedParagraphs.add(translated);
      }

      // Reassemble paragraphs within this page with double newlines
      final translatedPageText = translatedParagraphs.join('\n\n');

      // Reinsert the page markers around the translated page text
      translatedPages.add(PageMarkers.insertMarkers(translatedPageText, pageIndex));
      debugPrint('[MLKitTranslation] Translated page $pageIndex (${paragraphs.length} paragraphs)');
    }

    // Reassemble pages with paragraph breaks (double newlines)
    final result = translatedPages.join('\n\n');
    debugPrint('[MLKitTranslation] Reassembled ${translatedPages.length} pages into ${result.length} chars');
    return result;
  }

  /// Simple paragraph-based translation (used when no page markers present)
  Future<String> _translateParagraphsOnly(OnDeviceTranslator translator, String text) async {
    // Split into paragraphs (double newlines indicate paragraph breaks)
    final paragraphs = text.split(RegExp(r'\n\s*\n'));

    debugPrint('[MLKitTranslation] No markers - translating ${paragraphs.length} paragraph(s)');

    final translatedParagraphs = <String>[];

    for (int i = 0; i < paragraphs.length; i++) {
      final paragraph = paragraphs[i].trim();

      if (paragraph.isEmpty) {
        translatedParagraphs.add('');
        continue;
      }

      final translated = await translator.translateText(paragraph).timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          throw TimeoutException('Paragraph translation timeout (5 minutes)');
        },
      );

      translatedParagraphs.add(translated);
    }

    return translatedParagraphs.join('\n\n');
  }

  /// Get or create ML Kit translator for source and target languages
  Future<OnDeviceTranslator> _getTranslator(String sourceLanguage, String targetLanguage) async {
    // Create a composite key for the language pair
    final key = '$sourceLanguage-$targetLanguage';

    // Check if translator already exists
    if (_translators.containsKey(key)) {
      debugPrint('[MLKitTranslation] Using cached ML Kit translator for $key');
      return _translators[key]!;
    }

    debugPrint('[MLKitTranslation] Creating ML Kit translator: $sourceLanguage -> $targetLanguage');

    // Convert language codes to TranslateLanguage enum values
    final sourceLang = _toTranslateLanguage(sourceLanguage);
    final targetLang = _toTranslateLanguage(targetLanguage);

    // Create the translator using the new API
    final translator = OnDeviceTranslator(
      sourceLanguage: sourceLang,
      targetLanguage: targetLang,
    );

    _translators[key] = translator;
    debugPrint('[MLKitTranslation] ML Kit translator created for $key');
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
  /// Returns true if the model is already cached in memory or available on disk, false otherwise
  Future<bool> isLanguageModelReady(String languageCode) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return false;
    }

    final key = 'en-$languageCode';
    if (_translators.containsKey(key)) {
      debugPrint('[MLKitTranslation] Model already cached for $languageCode');
      return true;
    }

    // Try to create a translator quickly to check if the model is available on disk
    // If the model is already downloaded by ML Kit, creating the translator will be fast
    try {
      final sourceLang = _toTranslateLanguage('en');
      final targetLang = _toTranslateLanguage(languageCode);

      debugPrint('[MLKitTranslation] Checking if model is available on disk for $languageCode...');

      // Create a temporary translator to check model availability
      final tempTranslator = OnDeviceTranslator(
        sourceLanguage: sourceLang,
        targetLanguage: targetLang,
      );

      // Try a quick test translation to verify the model is ready
      // Use a short timeout - if the model is already downloaded, this will be fast
      // If the model needs to be downloaded, it will timeout
      final result = await tempTranslator.translateText('Hello').timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          // Timeout means the model is not ready (needs download)
          debugPrint('[MLKitTranslation] Model check timeout - model likely needs downloading');
          throw TimeoutException('Model check timeout');
        },
      );

      // If we got here, the model is ready! Cache it for future use
      _translators[key] = tempTranslator;
      debugPrint('[MLKitTranslation] Model is available on disk for $languageCode (test translation: $result)');
      return true;
    } on TimeoutException {
      debugPrint('[MLKitTranslation] Model not available for $languageCode (timeout)');
      return false;
    } catch (e) {
      debugPrint('[MLKitTranslation] Model not available for $languageCode: $e');
      return false;
    }
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
      debugPrint('[MLKitTranslation] Model already available for $languageCode');
      return true;
    }

    try {
      onProgress?.call('Starting model download...');
      debugPrint('[MLKitTranslation] Downloading model for $languageCode');

      final sourceLang = _toTranslateLanguage('en');
      final targetLang = _toTranslateLanguage(languageCode);

      onProgress?.call('Initializing translator...');

      final translator = OnDeviceTranslator(
        sourceLanguage: sourceLang,
        targetLanguage: targetLang,
      );

      onProgress?.call('Downloading language model...');

      debugPrint('[MLKitTranslation] Starting model download test translation...');
      final stopwatch = Stopwatch()..start();

      // Translate a test phrase to trigger model download
      final result = await translator.translateText('Hello').timeout(
        const Duration(minutes: 10),
        onTimeout: () {
          stopwatch.stop();
          onProgress?.call('Download timeout');
          debugPrint('[MLKitTranslation] Model download timeout after ${stopwatch.elapsed.inMinutes}:${stopwatch.elapsed.inSeconds % 60}');
          throw TimeoutException('Model download timeout (10 minutes)');
        },
      );

      stopwatch.stop();
      debugPrint('[MLKitTranslation] Test translation result: $result (took ${stopwatch.elapsed.inSeconds} seconds)');
      onProgress?.call('Model downloaded successfully!');

      // Cache the translator (keep it open for future use)
      _translators[key] = translator;

      debugPrint('[MLKitTranslation] Model downloaded and cached for $languageCode');
      return true;
    } catch (e) {
      debugPrint('[MLKitTranslation] Model download failed for $languageCode: $e');
      onProgress?.call('Download failed: $e');
      return false;
    }
  }

  @override
  Future<void> close() async {
    for (final translator in _translators.values) {
      try {
        translator.close();
      } catch (e) {
        debugPrint('[MLKitTranslation] Error closing translator: $e');
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
