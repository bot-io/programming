import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

/// LibreTranslate API implementation for fallback translation
/// Uses the free Argos Open Tech API
/// API: https://translate.argosopentech.com
/// Supports 20+ languages with no API key required
class LibreTranslateServiceImpl {
  final http.Client _client;
  final String _baseUrl;

  LibreTranslateServiceImpl(this._client, {String baseUrl = 'https://translate.argosopentech.com/translate'})
      : _baseUrl = baseUrl;

  /// Translate text using LibreTranslate API
  Future<String> translate({
    required String text,
    required String targetLanguage,
    String? sourceLanguage,
  }) async {
    try {
      debugPrint('[LibreTranslate] Translating to $targetLanguage');

      final response = await _client.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: _buildRequestBody(text, targetLanguage, sourceLanguage ?? 'auto'),
      );

      if (response.statusCode == 200) {
        final result = _parseResponse(response.body);
        debugPrint('[LibreTranslate] Translation successful');
        return result;
      } else {
        throw Exception('LibreTranslate API error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[LibreTranslate] Translation failed: $e');
      rethrow;
    }
  }

  String _buildRequestBody(String text, String target, String source) {
    // LibreTranslate expects specific format
    return '{"q":"${_escapeJson(text)}","source":"$source","target":"$target","format":"text"}';
  }

  String _escapeJson(String text) {
    return text
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"')
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r')
        .replaceAll('\t', '\\t');
  }

  String _parseResponse(String responseBody) {
    // Parse JSON response
    // Expected format: {"translatedText":"..."}
    final translatedTextMatch = RegExp(r'"translatedText"\s*:\s*"([^"]*)"').firstMatch(responseBody);
    if (translatedTextMatch != null && translatedTextMatch.group(1) != null) {
      return _unescapeJson(translatedTextMatch.group(1)!);
    }
    throw Exception('Invalid response format from LibreTranslate');
  }

  String _unescapeJson(String text) {
    return text
        .replaceAll('\\"', '"')
        .replaceAll('\\n', '\n')
        .replaceAll('\\r', '\r')
        .replaceAll('\\t', '\t')
        .replaceAll('\\\\', '\\');
  }

  /// Detect language using LibreTranslate API
  Future<String> detectLanguage(String text) async {
    try {
      final response = await _client.post(
        Uri.parse('https://translate.argosopentech.com/detect'),
        headers: {'Content-Type': 'application/json'},
        body: '{"q":"${_escapeJson(text)}"}',
      );

      if (response.statusCode == 200) {
        final langMatch = RegExp(r'"language"\s*:\s*"([^"]*)"').firstMatch(response.body);
        if (langMatch != null && langMatch.group(1) != null) {
          return langMatch.group(1)!;
        }
      }
    } catch (e) {
      debugPrint('[LibreTranslate] Detection failed: $e');
    }
    return 'en'; // Default fallback
  }

  void close() {
    _client.close();
  }
}
