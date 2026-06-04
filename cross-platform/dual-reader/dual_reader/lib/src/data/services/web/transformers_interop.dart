import 'dart:js' as js;
import 'dart:async';
import 'package:flutter/foundation.dart';

/// JS Interop layer for Transformers.js v3 with NLLB-200
/// This allows Flutter Web to call Transformers.js for client-side translation
/// Documentation: https://huggingface.co/docs/transformers.js
///
/// Using facebook/nllb-200-distilled-600M model for 200+ language support
/// FLORES-200 language codes: https://github.com/facebookresearch/flores/blob/main/flores200/README.md
///
/// WORKAROUND: Using dart:js (legacy) instead of dart:js_interop
/// due to parameter passing issues with the newer package.

/// Service class for managing Transformers.js NLLB-200 translation
class TransformersJsService {
  /// Check if Transformers.js NLLB-200 is available
  bool get isAvailable {
    try {
      final hasTransformers = js.context.hasProperty('transformersTranslate');
      final hasAPI = js.context['transformersAPI'];
      debugPrint('[Transformers.js] isAvailable: $hasTransformers, API: $hasAPI');
      return hasTransformers && hasAPI == 'nllb-200';
    } catch (e) {
      debugPrint('[Transformers.js] isAvailable check failed: $e');
      return false;
    }
  }

  /// Translate text using Transformers.js NLLB-200
  /// targetLanguage and sourceLanguage should be BCP 47 codes (e.g., 'es', 'en')
  Future<String> translate(
    String text,
    String targetLanguage, [
    String sourceLanguage = 'en',
  ]) async {
    try {
      debugPrint('[Transformers.js] Translating: $sourceLanguage -> $targetLanguage');
      debugPrint('[Transformers.js] Text length: ${text.length} characters');
      debugPrint('[Transformers.js] Text preview: "${text.substring(0, text.length > 50 ? 50 : text.length)}..."');

      // Set text using multiple approaches for compatibility
      if (js.context.hasProperty('setText')) {
        js.context.callMethod('setText', [text]);
      }
      js.context['transformersText'] = text;

      // Check if the translation function exists
      if (!js.context.hasProperty('transformersTranslate')) {
        throw Exception('transformersTranslate function not found on window object');
      }

      debugPrint('[Transformers.js] Calling transformersTranslate...');
      // Call with source and target language parameters
      final promise = js.context.callMethod('transformersTranslate', [
        null, // textParam (use global variable)
        targetLanguage,
        sourceLanguage,
      ]);

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

  /// Check if a model is ready for a language pair
  bool isModelReady([String sourceLanguage = 'en', String targetLanguage = 'es']) {
    try {
      if (js.context.hasProperty('transformersIsModelReady')) {
        final result = js.context.callMethod('transformersIsModelReady', [sourceLanguage, targetLanguage]);
        debugPrint('[Transformers.js] Model ready for $sourceLanguage->$targetLanguage: $result');
        return result == true;
      }
      return false;
    } catch (e) {
      debugPrint('[Transformers.js] isModelReady check failed: $e');
      return false;
    }
  }

  /// Pre-load a model for a language pair
  Future<bool> loadModel(String sourceLanguage, String targetLanguage) async {
    try {
      if (js.context.hasProperty('transformersLoadModel')) {
        debugPrint('[Transformers.js] Loading model for $sourceLanguage->$targetLanguage');
        final promise = js.context.callMethod('transformersLoadModel', [sourceLanguage, targetLanguage]);
        await _promiseToFuture(promise);
        debugPrint('[Transformers.js] Model loaded successfully');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[Transformers.js] loadModel failed: $e');
      return false;
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
    then.callMethod('call', [promise, (result) {
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
