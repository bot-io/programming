import 'dart:io' show Platform;
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:dual_reader/src/data/services/client_side_translation_service.dart';
import 'package:dual_reader/src/data/services/libretranslate_service_impl.dart';
import 'package:dual_reader/src/data/services/language_detection_service.dart';
import 'package:dual_reader/src/core/utils/page_markers.dart';
import 'package:dual_reader/src/core/utils/sentence_splitter.dart';
import 'package:dual_reader/src/core/utils/text_processing_utils.dart';
import 'package:http/http.dart' as http;

/// Hybrid mobile implementation with ML Kit primary and LibreTranslate fallback
/// - Primary: Google ML Kit On-Device Translation (offline, free)
/// - Fallback: LibreTranslate API (online, free) when ML Kit fails
/// - Enhanced with sentence-based translation for better quality
class ClientSideTranslationDelegateImpl implements ClientSideTranslationDelegate {
  static const String _componentName = 'ClientSideTranslation';

  // Lazy-loaded translators keyed by language code
  final Map<String, OnDeviceTranslator> _translators = {};

  // Fallback API service
  LibreTranslateServiceImpl? _fallbackService;
  bool _useFallback = false;

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

    // Log translation request
    final textPreview = text.length > 50 ? '${text.substring(0, 50)}...' : text;
    _componentName.logInfo(
      'Translation requested - source: $source, target: $targetLanguage, text: "$textPreview" (${text.length} chars)'
    );

    try {
      // Try ML Kit first
      final translated = await _translateWithMlKit(text, source, targetLanguage);

      stopwatch.stop();
      _componentName.logInfo(
        'ML Kit translation complete - ${translated.length} chars, duration: ${stopwatch.elapsed.inMilliseconds}ms'
      );

      return translated;
    } catch (e, stackTrace) {
      stopwatch.stop();
      _componentName.logWarning(
        'ML Kit translation failed, trying LibreTranslate fallback - error: $e'
      );

      // Try fallback
      try {
        final fallbackTranslated = await _translateWithFallback(text, source, targetLanguage);
        stopwatch.stop();
        _componentName.logInfo(
          'Fallback translation complete - ${fallbackTranslated.length} chars, total duration: ${stopwatch.elapsed.inMilliseconds}ms'
        );
        return fallbackTranslated;
      } catch (fallbackError) {
        _componentName.logError(
          'All translation methods failed - ML Kit: $e, Fallback: $fallbackError',
          error: e,
          stackTrace: stackTrace,
        );
        throw Exception('Translation failed: ML Kit error: $e, Fallback error: $fallbackError');
      }
    }
  }

  /// Translate using ML Kit (primary method)
  Future<String> _translateWithMlKit(String text, String sourceLanguage, String targetLanguage) async {
    debugPrint('[MLKitTranslation] Attempting translation with ML Kit');

    final translator = await _getTranslator(sourceLanguage, targetLanguage).timeout(
      const Duration(minutes: 5),
      onTimeout: () {
        debugPrint('[MLKitTranslation] Translator creation timed out');
        throw TimeoutException('ML Kit translator creation timeout (5 minutes)');
      },
    );

    return await _translatePreservingStructure(translator, text, targetLanguage);
  }

  /// Translate using LibreTranslate API (fallback method)
  Future<String> _translateWithFallback(String text, String sourceLanguage, String targetLanguage) async {
    debugPrint('[FallbackTranslation] Using LibreTranslate API');

    _fallbackService ??= LibreTranslateServiceImpl(http.Client());

    return await _fallbackService!.translate(
      text: text,
      targetLanguage: targetLanguage,
      sourceLanguage: sourceLanguage,
    );
  }

  /// Translate text while preserving paragraph structure and page markers
  /// Now uses sentence-based translation for improved quality
  Future<String> _translatePreservingStructure(OnDeviceTranslator translator, String text, String targetLanguage) {
    // Extract all page indices to know which pages exist
    final pageIndices = PageMarkers.extractPageIndices(text);
    debugPrint('[MLKitTranslation] Found ${pageIndices.length} pages with markers to preserve');

    if (pageIndices.isEmpty) {
      return _translateWithSentenceSplitting(translator, text);
    }

    return _translateWithMarkers(translator, text, pageIndices);
  }

  /// Translate text with page markers preserved
  Future<String> _translateWithMarkers(
    OnDeviceTranslator translator,
    String text,
    List<int> pageIndices,
  ) async {
    final translatedPages = <String>[];

    for (final pageIndex in pageIndices) {
      final pageText = PageMarkers.extractPage(text, pageIndex);

      if (pageText.isEmpty) {
        translatedPages.add(PageMarkers.insertMarkers('', pageIndex));
        continue;
      }

      // Use sentence-based translation for each page
      final translated = await _translateWithSentenceSplitting(translator, pageText);
      translatedPages.add(PageMarkers.insertMarkers(translated, pageIndex));
      debugPrint('[MLKitTranslation] Translated page $pageIndex');
    }

    return translatedPages.join('\n\n');
  }

  /// Translate text using paragraph-level context for better quality
  /// Handles abbreviations, decimals, URLs, and other edge cases
  /// Groups sentences intelligently for context preservation
  Future<String> _translateWithSentenceSplitting(OnDeviceTranslator translator, String text) async {
    // Create contextual translation units
    final units = TextProcessingUtils.createTranslationUnits(text);
    debugPrint('[MLKitTranslation] Created ${units.length} translation units');

    final translations = <String>[];

    for (int i = 0; i < units.length; i++) {
      final unit = units[i];

      debugPrint('[MLKitTranslation] Translating unit $i/${units.length} (${unit.sentenceCount} sentences, ${unit.length} chars)${unit.isDialogue ? " [dialogue]" : ""}');

      try {
        // Translate the entire unit (preserves context)
        final translated = await translator.translateText(unit.text).timeout(
          const Duration(minutes: 5),
          onTimeout: () {
            throw TimeoutException('Unit translation timeout (5 minutes)');
          },
        );

        translations.add(translated);
        debugPrint('[MLKitTranslation] Unit $i translated successfully');
      } catch (e) {
        debugPrint('[MLKitTranslation] Unit $i translation failed: $e');
        // Fallback: translate sentence by sentence
        translations.add(await _fallbackToSentenceBySentence(translator, unit));
      }
    }

    // Reassemble and post-process
    final reassembled = TextProcessingUtils.reassembleTranslatedUnits(units, translations, 'en');

    // Calculate quality score
    final qualityScore = TextProcessingUtils.calculateQualityScore(text, reassembled, 'en');
    debugPrint('[MLKitTranslation] Translation quality score: $qualityScore/100');

    return reassembled;
  }

  /// Fallback to sentence-by-sentence translation when unit translation fails.
  Future<String> _fallbackToSentenceBySentence(OnDeviceTranslator translator, ContextualTranslationUnit unit) async {
    final translatedSentences = <String>[];

    for (final sentence in unit.sentences) {
      if (sentence.trim().length < 2) {
        translatedSentences.add(sentence);
        continue;
      }

      try {
        final translated = await translator.translateText(sentence).timeout(
          const Duration(minutes: 5),
          onTimeout: () {
            throw TimeoutException('Sentence translation timeout (5 minutes)');
          },
        );
        translatedSentences.add(translated);
      } catch (e) {
        debugPrint('[MLKitTranslation] Sentence translation failed: $e');
        translatedSentences.add(sentence);
      }
    }

    return translatedSentences.join(' ');
  }

  /// Reconstruct a paragraph from translated sentences
  /// Preserves original spacing and punctuation
  String _reconstructParagraph(List<String> translatedSentences, SentenceGroup originalGroup) {
    if (translatedSentences.isEmpty) return '';

    // Join sentences with proper spacing
    // The translated sentences already have their ending punctuation
    final buffer = StringBuffer();

    for (int i = 0; i < translatedSentences.length; i++) {
      final sentence = translatedSentences[i].trim();

      if (sentence.isEmpty) continue;

      buffer.write(sentence);

      // Add space between sentences if next one starts with lowercase
      // (some translations might not preserve sentence boundaries perfectly)
      if (i < translatedSentences.length - 1) {
        final nextSentence = translatedSentences[i + 1].trim();
        if (nextSentence.isNotEmpty && !_startsWithCapitalLetter(nextSentence)) {
          buffer.write(' ');
        } else {
          buffer.write(' ');
        }
      }
    }

    return buffer.toString().trim();
  }

  /// Check if a string starts with a capital letter
  bool _startsWithCapitalLetter(String text) {
    if (text.isEmpty) return false;
    return RegExp(r'^[A-Z\u00C0-\u00DE]').hasMatch(text[0]);
  }

  /// Get or create ML Kit translator for source and target languages
  Future<OnDeviceTranslator> _getTranslator(String sourceLanguage, String targetLanguage) async {
    final key = '$sourceLanguage-$targetLanguage';

    if (_translators.containsKey(key)) {
      debugPrint('[MLKitTranslation] Using cached ML Kit translator for $key');
      return _translators[key]!;
    }

    debugPrint('[MLKitTranslation] Creating ML Kit translator: $sourceLanguage -> $targetLanguage');

    final sourceLang = _toTranslateLanguage(sourceLanguage);
    final targetLang = _toTranslateLanguage(targetLanguage);

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
    final detectionService = LanguageDetectionService.instance;

    // Initialize if needed
    if (!detectionService.isInitialized) {
      await detectionService.init();
    }

    // Use enhanced detection service
    final result = await detectionService.detectWithConfidence(text);
    _componentName.logInfo('Language detected: ${result.languageCode} with ${result.confidence}% confidence');

    return result.languageCode;
  }

  @override
  Future<bool> isLanguageModelReady(String languageCode) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return false;
    }

    final key = 'en-$languageCode';
    if (_translators.containsKey(key)) {
      debugPrint('[MLKitTranslation] Model already cached for $languageCode');
      return true;
    }

    try {
      final sourceLang = _toTranslateLanguage('en');
      final targetLang = _toTranslateLanguage(languageCode);

      debugPrint('[MLKitTranslation] Checking if model is available on disk for $languageCode...');

      final tempTranslator = OnDeviceTranslator(
        sourceLanguage: sourceLang,
        targetLanguage: targetLang,
      );

      final result = await tempTranslator.translateText('Hello').timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('[MLKitTranslation] Model check timeout - model likely needs downloading');
          throw TimeoutException('Model check timeout');
        },
      );

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

  @override
  Future<bool> downloadLanguageModel(String languageCode, {void Function(String)? onProgress}) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      throw UnsupportedError('ML Kit translation is only supported on Android and iOS');
    }

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

      final result = await translator.translateText('Hello').timeout(
        const Duration(minutes: 10),
        onTimeout: () {
          stopwatch.stop();
          onProgress?.call('Download timeout');
          debugPrint('[MLKitTranslation] Model download timeout');
          throw TimeoutException('Model download timeout (10 minutes)');
        },
      );

      stopwatch.stop();
      debugPrint('[MLKitTranslation] Test translation result: $result (took ${stopwatch.elapsed.inSeconds} seconds)');
      onProgress?.call('Model downloaded successfully!');

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

    // Close fallback service
    _fallbackService?.close();

    _componentName.logInfo('Service closed - translators closed: $closedCount, errors: $errorCount');
  }
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);
  @override
  String toString() => message;
}
