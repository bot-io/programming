import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dual_reader/src/domain/services/translation_service.dart';
import 'package:dual_reader/src/data/services/translation_cache_service.dart';
import 'package:flutter/foundation.dart';

/// Google Translate API implementation
/// Requires a Google Cloud API key with Cloud Translation API enabled
/// Website: https://cloud.google.com/translate
class GoogleTranslateServiceImpl implements TranslationService {
  final String _apiKey;
  final String _baseUrl = 'translation.googleapis.com';
  final TranslationCacheService _cacheService;
  final http.Client _httpClient;

  GoogleTranslateServiceImpl(this._cacheService, this._httpClient, {String? apiKey})
      : _apiKey = apiKey ?? const String.fromEnvironment('GOOGLE_TRANSLATE_API_KEY', defaultValue: '');

  @override
  Future<String> translate({
    required String text,
    required String targetLanguage,
    String? sourceLanguage,
  }) async {
    // Try cache first
    final cachedTranslation = _cacheService.getCachedTranslation(text, targetLanguage);
    if (cachedTranslation != null) {
      debugPrint('[GoogleTranslate] Cache hit for: "$text" -> "$cachedTranslation"');
      return cachedTranslation;
    }

    if (_apiKey.isEmpty) {
      throw Exception(
        'Google Translate API key is missing. '
        'Please provide an API key or set GOOGLE_TRANSLATE_API_KEY environment variable. '
        'Get your API key at: https://cloud.google.com/translate'
      );
    }

    try {
      final url = Uri.https(_baseUrl, '/language/translate/v2', {
        'key': _apiKey,
      });

      // Use "auto" for source language detection if not provided
      final source = sourceLanguage ?? 'auto';

      final response = await _httpClient.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'q': [text],
          'source': source,
          'target': targetLanguage,
          'format': 'text',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['error'] != null) {
          final error = data['error'];
          throw Exception('Translation failed (${error['code']}): ${error['message']}');
        }

        final translatedText = data['data']['translations'][0]['translatedText'];
        debugPrint('[GoogleTranslate] Translation successful: "$translatedText"');

        // Cache the result
        await _cacheService.cacheTranslation(text, targetLanguage, translatedText);
        return translatedText;
      } else {
        final body = jsonDecode(response.body);
        final error = body['error'] ?? {};
        throw Exception('Translation failed (${response.statusCode}): ${error['message'] ?? response.body}');
      }
    } catch (e, stack) {
      debugPrint('[GoogleTranslate] Translation error: $e\n$stack');
      rethrow;
    }
  }

  @override
  Future<String> detectLanguage(String text) async {
    if (_apiKey.isEmpty) {
      throw Exception(
        'Google Translate API key is missing. '
        'Please provide an API key or set GOOGLE_TRANSLATE_API_KEY environment variable.'
      );
    }

    try {
      final url = Uri.https(_baseUrl, '/language/translate/v2/detect', {
        'key': _apiKey,
      });

      final response = await _httpClient.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'q': [text],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['error'] != null) {
          final error = data['error'];
          throw Exception('Language detection failed (${error['code']}): ${error['message']}');
        }

        final detections = data['data']['detections'] as List;
        if (detections.isNotEmpty && detections[0].isNotEmpty) {
          final language = detections[0][0]['language'];
          debugPrint('[GoogleTranslate] Detected language: $language');
          return language;
        } else {
          throw Exception('Language detection failed: No detections returned');
        }
      } else {
        final body = jsonDecode(response.body);
        final error = body['error'] ?? {};
        throw Exception('Language detection failed (${response.statusCode}): ${error['message'] ?? response.body}');
      }
    } catch (e, stack) {
      debugPrint('[GoogleTranslate] Detection error: $e\n$stack');
      rethrow;
    }
  }
}
