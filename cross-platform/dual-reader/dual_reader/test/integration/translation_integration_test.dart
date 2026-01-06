import 'package:flutter_test/flutter_test.dart';
import 'package:dual_reader/src/data/services/web/transformers_interop.dart';
import 'package:flutter/foundation.dart';

/// Automated integration test for translation functionality
/// This test runs real translation without mocks - requires browser environment
///
/// Run with: flutter test test/integration/translation_integration_test.dart --platform chrome
void main() {
  group('Automated Translation Integration Tests', () {
    late TransformersJsService service;

    setUpAll(() {
      print('=== Initializing Translation Service ===');
      service = transformersJsService;
    });

    test('Automated test: Translate simple English to Spanish', () async {
      const testText = 'Hello world';

      print('\n========================================');
      print('AUTOMATED TRANSLATION TEST');
      print('========================================');
      print('Input: "$testText"');
      print('Target: Spanish (es)');
      print('Time: ${DateTime.now()}');

      final stopwatch = Stopwatch()..start();

      try {
        final result = await service.translate(testText, 'es');

        stopwatch.stop();

        print('----------------------------------------');
        print('SUCCESS!');
        print('Result: "$result"');
        print('Duration: ${stopwatch.elapsed.inSeconds}s');
        print('----------------------------------------\n');

        // Assertions
        expect(result, isNotEmpty, reason: 'Translation result should not be empty');
        expect(result, isNot(equals(testText)), reason: 'Translation should differ from input');

        // Log success for CI/CD
        print('✓ Translation test PASSED');

      } catch (e, stackTrace) {
        stopwatch.stop();
        print('----------------------------------------');
        print('FAILED!');
        print('Error: $e');
        print('Duration: ${stopwatch.elapsed.inSeconds}s');
        print('Stack trace: $stackTrace');
        print('----------------------------------------\n');

        // Fail the test with clear message
        fail('Translation failed: $e');
      }
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('Automated test: Translate sentence to Spanish', () async {
      const testText = 'The quick brown fox jumps over the lazy dog.';

      print('\n========================================');
      print('AUTOMATED SENTENCE TRANSLATION TEST');
      print('========================================');
      print('Input: "$testText"');
      print('Target: Spanish (es)');

      final stopwatch = Stopwatch()..start();

      try {
        final result = await service.translate(testText, 'es');

        stopwatch.stop();

        print('----------------------------------------');
        print('SUCCESS!');
        print('Result: "$result"');
        print('Duration: ${stopwatch.elapsed.inSeconds}s');
        print('----------------------------------------\n');

        expect(result, isNotEmpty);
        expect(result, isNot(equals(testText)));

        print('✓ Sentence translation test PASSED');

      } catch (e) {
        stopwatch.stop();
        print('----------------------------------------');
        print('FAILED!');
        print('Error: $e');
        print('Duration: ${stopwatch.elapsed.inSeconds}s');
        print('----------------------------------------\n');

        fail('Sentence translation failed: $e');
      }
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('Automated test: Unsupported language should fail', () {
      print('\n========================================');
      print('UNSUPPORTED LANGUAGE TEST');
      print('========================================');

      expect(
        () => service.translate('Hello', 'fr'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('only English→Spanish'),
        )),
      );

      print('✓ Unsupported language test PASSED\n');
    });

    test('Automated test: Service availability', () {
      print('\n========================================');
      print('SERVICE AVAILABILITY TEST');
      print('========================================');

      final available = service.isAvailable;

      print('Service available: $available');
      expect(available, isTrue);

      print('✓ Service availability test PASSED\n');
    });
  });
}
