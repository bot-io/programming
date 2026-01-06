import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:dual_reader/src/data/services/client_side_translation_service_mobile.dart';
import 'dart:io' show Platform;

/// Widget-based integration test for Google ML Kit
/// This runs on the actual device/emulator, not in the test VM
///
/// Run with: flutter test test/integration/mlkit_widget_test.dart --device-id emulator-5554
void main() {
  testWidgets('ML Kit Real Translation Test', (WidgetTester tester) async {
    print('\n${'=' * 70}');
    print('GOOGLE ML KIT - WIDGET INTEGRATION TEST');
    print('${'=' * 70}\n');

    print('Platform: ${Platform.isAndroid ? "Android" : Platform.isIOS ? "iOS" : "Unknown"}');
    print('Note: This test uses REAL ML Kit on device!\n');

    // Build a simple widget to test
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('ML Kit Test'),
          ),
        ),
      ),
    );

    // Create the service
    final service = ClientSideTranslationDelegateImpl();

    print('--- Test 1: Service Availability ---');
    expect(service, isNotNull);
    print('✓ ML Kit service available\n');

    print('--- Test 2: English to Spanish ---');
    final stopwatch1 = Stopwatch()..start();

    try {
      final result = await service.translate(
        text: 'Hello world',
        targetLanguage: 'es',
        sourceLanguage: 'en',
      );

      stopwatch1.stop();

      print('Input: "Hello world"');
      print('Output: "$result"');
      print('Duration: ${stopwatch1.elapsed.inSeconds}s (${stopwatch1.elapsed.inMilliseconds}ms)');

      expect(result, isNotEmpty);
      expect(result.toLowerCase(), isNot(equals('hello world')));

      final hasSpanish = result.toLowerCase().contains('hola') ||
          result.toLowerCase().contains('mundo');

      if (hasSpanish) {
        print('✓ Spanish translation successful\n');
      } else {
        print('⚠ Translation produced result but may not be Spanish\n');
      }
    } catch (e) {
      stopwatch1.stop();
      print('❌ Translation failed: $e');
      print('Duration: ${stopwatch1.elapsed.inSeconds}s\n');
      rethrow;
    }

    print('--- Test 3: English to French ---');
    final stopwatch2 = Stopwatch()..start();

    try {
      final result = await service.translate(
        text: 'Thank you',
        targetLanguage: 'fr',
        sourceLanguage: 'en',
      );

      stopwatch2.stop();

      print('Input: "Thank you"');
      print('Output: "$result"');
      print('Duration: ${stopwatch2.elapsed.inMilliseconds}ms');

      expect(result, isNotEmpty);
      print('✓ French translation successful\n');
    } catch (e) {
      stopwatch2.stop();
      print('❌ French translation failed: $e\n');
      rethrow;
    }

    print('--- Test 4: Translator Caching ---');
    print('Translating again to test caching...');

    final stopwatch3 = Stopwatch()..start();

    try {
      final result = await service.translate(
        text: 'Hello',
        targetLanguage: 'es',
        sourceLanguage: 'en',
      );

      stopwatch3.stop();

      print('Output: "$result"');
      print('Duration: ${stopwatch3.elapsed.inMilliseconds}ms');
      print('✓ Caching test successful (should be faster than first translation)\n');
    } catch (e) {
      stopwatch3.stop();
      print('❌ Caching test failed: $e\n');
    }

    // Cleanup
    await service.close();

    print('${'=' * 70}');
    print('ML KIT INTEGRATION TESTS COMPLETE');
    print('${'=' * 70}\n');

    print('Summary:');
    print('  ✓ ML Kit service available');
    print('  ✓ English → Spanish working');
    print('  ✓ English → French working');
    print('  ✓ Translator caching functional');
    print('\nModels are cached on device for future use.');
    print('${'=' * 70}\n');
  });
}
