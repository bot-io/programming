import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dual_reader/src/domain/services/translation_service.dart';
import 'package:dual_reader/src/data/services/translation_cache_service.dart';
import 'package:flutter/foundation.dart';

class LibreTranslateServiceImpl implements TranslationService {
  final String _baseUrl = 'https://translate.argosopentech.com';
  final TranslationCacheService _cacheService;
  final http.Client _httpClient;

  LibreTranslateServiceImpl(this._cacheService, this._httpClient);

  @override
  Future<String> translate({
    required String text,
    required String targetLanguage,
    String? sourceLanguage,
  }) async {
    // Try to get from cache first
    final cachedTranslation = _cacheService.getCachedTranslation(text, targetLanguage);
    if (cachedTranslation != null) {
      debugPrint('Cache hit for translation: "$text" -> "$cachedTranslation"');
      return cachedTranslation;
    }

    try {
      // IMPORTANT (web): /detect often fails due to CORS/network restrictions.
      // LibreTranslate supports "auto" as source for /translate, so prefer that on web.
      final detectedSourceLanguage = sourceLanguage ?? (kIsWeb ? 'auto' : await detectLanguage(text));

      final response = await _httpClient.post(
        Uri.parse('$_baseUrl/translate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'q': text,
          'source': detectedSourceLanguage,
          'target': targetLanguage,
          'format': 'text',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final translatedText = data['translatedText'];
        // Cache the new translation
        await _cacheService.cacheTranslation(text, targetLanguage, translatedText);
        debugPrint('Translation cached: "$text" -> "$translatedText"');
        return translatedText;
      } else {
        throw Exception('Failed to translate text: ${response.statusCode} ${response.body}');
      }
    } catch (e, stack) {
      debugPrint('Translation failed: $e\n$stack');
      rethrow;
    }
  }

  @override
  Future<String> detectLanguage(String text) async {
    final response = await _httpClient.post(
      Uri.parse('$_baseUrl/detect'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'q': text}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data.isNotEmpty && data[0]['language'] != null) {
        return data[0]['language'];
      } else {
        throw Exception('Failed to detect language: No language found');
      }
    } else {
      throw Exception('Failed to detect language: ${response.statusCode} ${response.body}');
    }
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

