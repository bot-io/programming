import 'package:flutter/foundation.dart';
import 'package:dual_reader/src/data/services/client_side_translation_service.dart';
import 'package:dual_reader/src/data/services/web/transformers_interop.dart';
import 'package:dual_reader/src/data/services/language_detection_service.dart';
import 'package:dual_reader/src/core/utils/sentence_splitter.dart';
import 'package:dual_reader/src/core/utils/text_processing_utils.dart';

/// Web-specific implementation using Transformers.js v3 with NLLB-200
/// Provides true client-side translation running entirely in the browser
/// Uses facebook/nllb-200-distilled-600M model for 200+ language support
/// No API calls needed - fully offline after model download
/// Enhanced with sentence-based translation for better quality
class ClientSideTranslationDelegateImpl implements ClientSideTranslationDelegate {
  final TransformersJsService _jsService;

  ClientSideTranslationDelegateImpl() : _jsService = transformersJsService {
    debugPrint('[WebTranslation] Initialized with Transformers.js NLLB-200');
  }

  @override
  Future<String> translate({
    required String text,
    required String targetLanguage,
    String? sourceLanguage,
  }) async {
    try {
      final source = sourceLanguage ?? 'en';

      debugPrint('[WebTranslation] Translating to $targetLanguage using NLLB-200');
      debugPrint('[WebTranslation] Source: $source, Target: $targetLanguage');

      // Check if service is available
      if (!_jsService.isAvailable) {
        throw Exception('Transformers.js NLLB-200 is not available. Please check if the script loaded correctly.');
      }

      // Use sentence-based translation for better quality
      final result = await _translateWithSentenceSplitting(text, source, targetLanguage);

      debugPrint('[WebTranslation] Translation complete');
      return result;
    } catch (e) {
      debugPrint('[WebTranslation] Error: $e');
      rethrow;
    }
  }

  /// Translate using paragraph-level context for better quality
  Future<String> _translateWithSentenceSplitting(String text, String sourceLanguage, String targetLanguage) async {
    // Create contextual translation units
    final units = TextProcessingUtils.createTranslationUnits(text);
    debugPrint('[WebTranslation] Created ${units.length} translation units');

    if (units.isEmpty) {
      // Fallback to direct translation for empty or very short text
      return await _jsService.translate(text, targetLanguage, sourceLanguage);
    }

    final translations = <String>[];

    for (int i = 0; i < units.length; i++) {
      final unit = units[i];

      debugPrint('[WebTranslation] Translating unit $i/${units.length} (${unit.sentenceCount} sentences, ${unit.length} chars)${unit.isDialogue ? " [dialogue]" : ""}');

      try {
        // Translate the entire unit (preserves context)
        final translated = await _jsService.translate(unit.text, targetLanguage, sourceLanguage);

        translations.add(translated);
        debugPrint('[WebTranslation] Unit $i translated successfully');
      } catch (e) {
        debugPrint('[WebTranslation] Unit $i translation failed: $e');
        // Fallback: translate sentence by sentence
        translations.add(await _fallbackToSentenceBySentence(unit, sourceLanguage, targetLanguage));
      }
    }

    // Reassemble and post-process
    final reassembled = TextProcessingUtils.reassembleTranslatedUnits(units, translations, targetLanguage);

    // Calculate quality score
    final qualityScore = TextProcessingUtils.calculateQualityScore(text, reassembled, targetLanguage);
    debugPrint('[WebTranslation] Translation quality score: $qualityScore/100');

    return reassembled;
  }

  /// Fallback to sentence-by-sentence translation when unit translation fails.
  Future<String> _fallbackToSentenceBySentence(ContextualTranslationUnit unit, String sourceLanguage, String targetLanguage) async {
    final translatedSentences = <String>[];

    for (final sentence in unit.sentences) {
      if (sentence.trim().length < 2) {
        translatedSentences.add(sentence);
        continue;
      }

      try {
        final translated = await _jsService.translate(sentence, targetLanguage, sourceLanguage);
        translatedSentences.add(translated);
      } catch (e) {
        debugPrint('[WebTranslation] Sentence translation failed: $e');
        translatedSentences.add(sentence);
      }
    }

    return translatedSentences.join(' ');
  }

  @override
  Future<String> detectLanguage(String text) async {
    // Use enhanced language detection service
    final detectionService = LanguageDetectionService.instance;

    // Initialize if needed
    if (!detectionService.isInitialized) {
      await detectionService.init();
    }

    // Use enhanced detection service
    final result = await detectionService.detectWithConfidence(text);
    debugPrint('[WebTranslation] Language detected: ${result.languageCode} with ${result.confidence}% confidence');

    return result.languageCode;
  }

  @override
  Future<void> close() async {
    // No cleanup needed - Transformers.js handles its own lifecycle
    debugPrint('[WebTranslation] Web service closed');
  }

  @override
  Future<bool> isLanguageModelReady(String languageCode) async {
    // Check if the model is loaded for English -> targetLanguage
    return _jsService.isModelReady('en', languageCode);
  }

  @override
  Future<bool> downloadLanguageModel(String languageCode, {void Function(String)? onProgress}) async {
    try {
      onProgress?.call('Loading model for $languageCode...');
      debugPrint('[WebTranslation] Loading model for $languageCode');

      // Pre-load the model
      final success = await _jsService.loadModel('en', languageCode);

      if (success) {
        onProgress?.call('Model loaded successfully');
        debugPrint('[WebTranslation] Model loaded successfully');
      } else {
        onProgress?.call('Model load failed');
        debugPrint('[WebTranslation] Model load failed');
      }

      return success;
    } catch (e) {
      debugPrint('[WebTranslation] Model download error: $e');
      onProgress?.call('Error: $e');
      return false;
    }
  }
}
