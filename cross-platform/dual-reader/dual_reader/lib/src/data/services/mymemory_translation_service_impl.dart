import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dual_reader/src/domain/services/translation_service.dart';
import 'package:dual_reader/src/data/services/translation_cache_service.dart';
import 'package:flutter/foundation.dart';

/// MyMemory Translation API implementation
/// Free translation API that works on web without CORS issues
/// Website: https://mymemory.translated.net/
class MyMemoryTranslationServiceImpl implements TranslationService {
  final String _baseUrl = 'https://api.mymemory.translated.net/get';
  final TranslationCacheService _cacheService;
  final http.Client _httpClient;

  MyMemoryTranslationServiceImpl(this._cacheService, this._httpClient);

  @override
  Future<String> translate({
    required String text,
    required String targetLanguage,
    String? sourceLanguage,
  }) async {
    // Preserve paragraph structure by translating each paragraph separately
    final paragraphs = text.split(RegExp(r'\n\s*\n'));

    debugPrint('[MyMemory] Preserving structure - ${paragraphs.length} paragraph(s) to translate');

    final translatedParagraphs = <String>[];

    for (int i = 0; i < paragraphs.length; i++) {
      final paragraph = paragraphs[i].trim();

      if (paragraph.isEmpty) {
        // Preserve empty paragraphs
        translatedParagraphs.add('');
        continue;
      }

      // Translate this paragraph
      final translated = await _translateParagraph(paragraph, targetLanguage, sourceLanguage);
      translatedParagraphs.add(translated);
      debugPrint('[MyMemory] Translated paragraph $i/${paragraphs.length}');
    }

    // Reassemble with paragraph breaks (double newlines)
    return translatedParagraphs.join('\n\n');
  }

  /// Translate a single paragraph
  Future<String> _translateParagraph(String text, String targetLanguage, String? sourceLanguage) async {
    // Try cache first
    final cachedTranslation = _cacheService.getCachedTranslation(text, targetLanguage);
    if (cachedTranslation != null) {
      debugPrint('[MyMemory] Cache hit for: "$text" -> "$cachedTranslation"');
      return cachedTranslation;
    }

    try {
      // MyMemory uses "en" for auto-detection if source is not specified
      final source = sourceLanguage ?? 'en';
      final langPair = '$source|$targetLanguage';

      final url = Uri.parse(_baseUrl).replace(queryParameters: {
        'q': text,
        'langpair': langPair,
      });

      debugPrint('[MyMemory] Translating: $text ($langPair)');

      final response = await _httpClient.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['responseStatus'] == 200) {
          final translatedText = data['responseData']['translatedText'];
          debugPrint('[MyMemory] Translation successful: "$translatedText"');

          // Cache the result
          await _cacheService.cacheTranslation(text, targetLanguage, translatedText);
          return translatedText;
        } else {
          // MyMemory returns matches array even if status is not 200
          // Handle both List and String response formats
          final matches = data['matches'];
          if (matches != null) {
            String translatedText;
            if (matches is List && matches.isNotEmpty) {
              translatedText = matches[0]['translation'] as String;
            } else if (matches is String) {
              // Sometimes matches is just a string
              translatedText = matches;
            } else {
              throw Exception('Translation failed: ${data['responseDetails']}');
            }
            debugPrint('[MyMemory] Got translation from matches: "$translatedText"');

            // Cache the result
            await _cacheService.cacheTranslation(text, targetLanguage, translatedText);
            return translatedText;
          }
          throw Exception('Translation failed: ${data['responseDetails']}');
        }
      } else {
        throw Exception('Failed to translate: ${response.statusCode} ${response.body}');
      }
    } catch (e, stack) {
      debugPrint('[MyMemory] Translation error: $e\n$stack');
      rethrow;
    }
  }

  @override
  Future<String> detectLanguage(String text) async {
    // MyMemory doesn't have a separate detect endpoint
    // We'll do a simple heuristic-based detection
    await Future.delayed(const Duration(milliseconds: 50));

    final lowerText = text.toLowerCase();

    // Check for Cyrillic (Bulgarian, Russian, etc.)
    if (RegExp(r'[а-я]').hasMatch(text)) {
      if (RegExp(r'[бгджзклмнптфцчшщъы]').hasMatch(text)) {
        debugPrint('[MyMemory] Detected Bulgarian (Cyrillic)');
        return 'bg';
      }
      debugPrint('[MyMemory] Detected Russian (Cyrillic)');
      return 'ru';
    }

    // Spanish patterns
    if (lowerText.contains(' los ') || lowerText.contains(' las ') || lowerText.contains(' y ')) {
      if (!lowerText.contains(' the ')) {
        debugPrint('[MyMemory] Detected Spanish');
        return 'es';
      }
    }

    // French patterns
    if (lowerText.contains("d'") || lowerText.contains(" l'") ||
        (lowerText.contains(' le ') && lowerText.contains(' les '))) {
      if (!lowerText.contains(' the ')) {
        debugPrint('[MyMemory] Detected French');
        return 'fr';
      }
    }

    // German patterns
    if (lowerText.contains(' der ') || lowerText.contains(' die ') ||
        lowerText.contains(' das ') || lowerText.contains(' und ')) {
      if (!lowerText.contains(' the ')) {
        debugPrint('[MyMemory] Detected German');
        return 'de';
      }
    }

    // Italian patterns
    if (lowerText.contains(' il ') || lowerText.contains(' lo ') ||
        lowerText.contains(' la ') || lowerText.contains(' i ')) {
      if (!lowerText.contains(' the ') && !lowerText.contains(' is ')) {
        debugPrint('[MyMemory] Detected Italian');
        return 'it';
      }
    }

    // Portuguese patterns
    if ((lowerText.contains(' o ') || lowerText.contains(' um ') ||
         lowerText.contains(' uma ')) && !lowerText.contains(' the ')) {
      debugPrint('[MyMemory] Detected Portuguese');
      return 'pt';
    }

    // Chinese characters
    if (RegExp(r'[\u4e00-\u9fff]').hasMatch(text)) {
      debugPrint('[MyMemory] Detected Chinese');
      return 'zh';
    }

    // Japanese characters
    if (RegExp(r'[\u3040-\u309f\u30a0-\u30ff]').hasMatch(text)) {
      debugPrint('[MyMemory] Detected Japanese');
      return 'ja';
    }

    // Default to English
    debugPrint('[MyMemory] Detected English (default)');
    return 'en';
  }

  @override
  Future<bool> isLanguageModelReady(String languageCode) async {
    // API-based service, no model download needed
    return true;
  }

  @override
  Future<bool> downloadLanguageModel(String languageCode, {void Function(String)? onProgress}) async {
    // API-based service, no model download needed
    onProgress?.call('Using API - no download needed');
    return true;
  }
}
