import 'dart:js' as js;
import 'dart:async';
import 'package:flutter/foundation.dart';

/// JS Interop layer for Transformers.js v3
/// This allows Flutter Web to call Transformers.js for client-side translation
/// Documentation: https://huggingface.co/docs/transformers.js
///
/// Using Helsinki-NLP/opus-mt-en-es model (~270MB) for English→Spanish translation
///
/// WORKAROUND: Using dart:js (legacy) instead of dart:js_interop
/// due to parameter passing issues with the newer package.

/// Service class for managing Transformers.js translation pipelines
class TransformersJsService {
  // Using Helsinki-NLP English→Spanish model (~270MB)
  static const String _model = 'Helsinki-NLP/opus-mt-en-es';

  /// Check if Transformers.js is available
  bool get isAvailable {
    try {
      final hasTransformers = js.context.hasProperty('transformersTranslate');
      debugPrint('[Transformers.js] isAvailable: $hasTransformers');
      return hasTransformers;
    } catch (e) {
      debugPrint('[Transformers.js] isAvailable check failed: $e');
      return false;
    }
  }

  /// Translate text using Transformers.js
  /// targetLanguage should be a BCP 47 language code (e.g., 'es')
  Future<String> translate(String text, String targetLanguage) async {
    try {
      // For now, only support English→Spanish with the embedded model
      if (targetLanguage != 'es') {
        throw Exception('Currently only English→Spanish translation is supported with the embedded model.');
      }

      debugPrint('[Transformers.js] Translating to $targetLanguage');
      debugPrint('[Transformers.js] Text length: ${text.length} characters');
      debugPrint('[Transformers.js] Text preview: "${text.substring(0, text.length > 50 ? 50 : text.length)}..."');

      // WORKAROUND: Try multiple approaches to pass the text

      // Approach 1: Call the setText function
      if (js.context.hasProperty('setText')) {
        debugPrint('[Transformers.js] Calling setText...');
        js.context.callMethod('setText', [text]);
        debugPrint('[Transformers.js] setText called');
      }

      // Approach 2: Set global variable directly
      js.context['transformersText'] = text;
      debugPrint('[Transformers.js] Set global text variable');

      // Verify by calling getText
      if (js.context.hasProperty('getText')) {
        final retrieved = js.context.callMethod('getText', []);
        debugPrint('[Transformers.js] Retrieved text from getText: "$retrieved"');
        debugPrint('[Transformers.js] Retrieved text length: ${retrieved?.toString().length ?? 0}');
      }

      // Check if the function exists
      if (!js.context.hasProperty('transformersTranslate')) {
        throw Exception('transformersTranslate function not found on window object');
      }

      debugPrint('[Transformers.js] Calling transformersTranslate...');
      final promise = js.context.callMethod('transformersTranslate', []);

      // Convert the promise to a Future
      final result = await _promiseToFuture(promise);

      if (result != null && result.toString().isNotEmpty) {
        debugPrint('[Transformers.js] Translation successful!');
        debugPrint('[Transformers.js] Result preview: "${result.toString().substring(0, result.toString().length > 50 ? 50 : result.toString().length)}..."');
        return result.toString();
      }

      debugPrint('[Transformers.js] Result is null or empty');
      throw Exception('Translation result is empty');
    } catch (e, stackTrace) {
      debugPrint('[Transformers.js] Translation error: $e');
      debugPrint('[Transformers.js] Stack trace: $stackTrace');
      throw Exception('Transformers.js translation failed: $e');
    }
  }

  /// Convert JavaScript Promise to Dart Future
  Future<dynamic> _promiseToFuture(dynamic promise) {
    if (promise == null) {
      return Future.value(null);
    }

    final completer = Completer<dynamic>();

    // Use the promise's then method
    final then = js.context['Promise']['prototype']['then'];
    final thenCall = then.callMethod('call', [promise, (result) {
      completer.complete(result);
      return null;
    }]);

    final catchMethod = js.context['Promise']['prototype']['catch'];
    catchMethod.callMethod('call', [promise, (error) {
      completer.completeError(error);
      return null;
    }]);

    return completer.future;
  }
}

// Global instance
final transformersJsService = TransformersJsService();
