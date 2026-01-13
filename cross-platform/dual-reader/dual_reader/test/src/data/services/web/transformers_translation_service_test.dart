@TestOn('browser')
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dual_reader/src/data/services/web/transformers_interop.dart';

/// Integration test for Transformers.js web translation
/// This test runs actual translation without mocks - it requires a browser environment
///
/// Run with: flutter test test/src/data/services/web/transformers_translation_service_test.dart --platform chrome
///
/// Note: This test will download the Helsinki-NLP/opus-mt-en-es model (~270MB) on first run.
/// Subsequent runs will use the cached model.
void main() {
  // Skip on non-web platforms since dart:js is not available
  if (!kIsWeb) {
    print('Skipping Transformers.js tests - only available on web platform');
    print('Run with: flutter test test/src/data/services/web/transformers_translation_service_test.dart --platform chrome');
    return;
  }

  print('=== Starting Transformers.js Integration Tests ===');

  group('Transformers.js Translation Integration Tests', () {
    late TransformersJsService service;

    setUp(() {
      print('Setting up test...');
      service = transformersJsService;
      print('Service created: ${service.runtimeType}');
    });

    test('Service should be available on web platform', () {
      print('Testing service availability...');
      // The service should always return true for isAvailable on web
      // since the JavaScript module loads asynchronously
      expect(service.isAvailable, isTrue);
      print('Service is available: ${service.isAvailable}');
    });

    test('Translate simple English text to Spanish', () async {
      // This is a real integration test - no mocks!
      // It will actually call Transformers.js in the browser

      const testText = 'Hello world';

      print('--- Starting real translation test ---');
      print('Input text: "$testText"');
      print('Text length: ${testText.length} characters');

      try {
        print('Calling service.translate...');
        final result = await service.translate(testText, 'es');

        print('Translation result: "$result"');

        // Verify we got a non-empty result
        expect(result, isNotEmpty);
        expect(result, isNot(equals(testText)));

        // Should contain Spanish translation
        // 'Hello world' in Spanish is 'Hola mundo' or similar
        print('Translation successful!');
      } catch (e) {
        print('Translation failed with error: $e');
        rethrow; // Re-throw to see the full stack trace
      }
    }, timeout: const Timeout(Duration(minutes: 5))); // Give it time to download/load the model

    test('Only Spanish is supported', () async {
      // French should not be supported with the embedded model
      expect(
        () => service.translate('Hello', 'fr'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('only English→Spanish'),
        )),
      );
    });
  });
}
