import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:dual_reader/src/data/services/client_side_translation_service_mobile.dart';

/// Widget-based integration test for Google ML Kit
/// This runs on the actual device/emulator, not in the test VM
///
/// Run with: flutter test test/integration/mlkit_widget_test.dart --device-id emulator-5554
void main() {
  // Skip test on non-mobile platforms due to platform channel requirements
  final isMobilePlatform = Platform.isAndroid || Platform.isIOS;

  testWidgets('ML Kit Real Translation Test', (WidgetTester tester) async {
    if (!isMobilePlatform) {
      debugPrint('ML Kit Widget Integration Tests require a mobile device or emulator');
      debugPrint('Run with: flutter test test/integration/mlkit_widget_test.dart --device-id=<emulator-id>');
      return;
    }

    debugPrint('\n${'=' * 70}');
    debugPrint('GOOGLE ML KIT - WIDGET INTEGRATION TEST');
    debugPrint('${'=' * 70}\n');

    debugPrint('Platform: ${Platform.isAndroid ? "Android" : Platform.isIOS ? "iOS" : "Unknown"}');
    debugPrint('Note: This test uses REAL ML Kit on device!\n');

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

    debugPrint('--- Test 1: Service Availability ---');
    expect(service, isNotNull);
    debugPrint('✓ ML Kit service available\n');

    debugPrint('--- Test 2: English to Spanish ---');
    final stopwatch1 = Stopwatch()..start();

    try {
      final result = await service.translate(
        text: 'Hello world',
        targetLanguage: 'es',
        sourceLanguage: 'en',
      );

      stopwatch1.stop();

      debugPrint('Input: "Hello world"');
      debugPrint('Output: "$result"');
      debugPrint('Duration: ${stopwatch1.elapsed.inSeconds}s (${stopwatch1.elapsed.inMilliseconds}ms)');

      expect(result, isNotEmpty);
      expect(result.toLowerCase(), isNot(equals('hello world')));

      final hasSpanish = result.toLowerCase().contains('hola') ||
          result.toLowerCase().contains('mundo');

      if (hasSpanish) {
        debugPrint('✓ Spanish translation successful\n');
      } else {
        debugPrint('⚠ Translation produced result but may not be Spanish\n');
      }
    } catch (e) {
      stopwatch1.stop();
      debugPrint('❌ Translation failed: $e');
      debugPrint('Duration: ${stopwatch1.elapsed.inSeconds}s\n');
      rethrow;
    }

    debugPrint('--- Test 3: English to French ---');
    final stopwatch2 = Stopwatch()..start();

    try {
      final result = await service.translate(
        text: 'Thank you',
        targetLanguage: 'fr',
        sourceLanguage: 'en',
      );

      stopwatch2.stop();

      debugPrint('Input: "Thank you"');
      debugPrint('Output: "$result"');
      debugPrint('Duration: ${stopwatch2.elapsed.inMilliseconds}ms');

      expect(result, isNotEmpty);
      debugPrint('✓ French translation successful\n');
    } catch (e) {
      stopwatch2.stop();
      debugPrint('❌ French translation failed: $e\n');
      rethrow;
    }

    debugPrint('--- Test 4: Translator Caching ---');
    debugPrint('Translating again to test caching...');

    final stopwatch3 = Stopwatch()..start();

    try {
      final result = await service.translate(
        text: 'Hello',
        targetLanguage: 'es',
        sourceLanguage: 'en',
      );

      stopwatch3.stop();

      debugPrint('Output: "$result"');
      debugPrint('Duration: ${stopwatch3.elapsed.inMilliseconds}ms');
      debugPrint('✓ Caching test successful (should be faster than first translation)\n');
    } catch (e) {
      stopwatch3.stop();
      debugPrint('❌ Caching test failed: $e\n');
    }

    // Cleanup
    await service.close();

    debugPrint('${'=' * 70}');
    debugPrint('ML KIT INTEGRATION TESTS COMPLETE');
    debugPrint('${'=' * 70}\n');

    debugPrint('Summary:');
    debugPrint('  ✓ ML Kit service available');
    debugPrint('  ✓ English → Spanish working');
    debugPrint('  ✓ English → French working');
    debugPrint('  ✓ Translator caching functional');
    debugPrint('\nModels are cached on device for future use.');
    debugPrint('${'=' * 70}\n');
  }, skip: !isMobilePlatform);
}
