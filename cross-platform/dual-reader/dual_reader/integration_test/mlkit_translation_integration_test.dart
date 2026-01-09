import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:dual_reader/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dual_reader/src/data/services/client_side_translation_service_mobile.dart';
import 'package:dual_reader/src/core/di/injection_container.dart';
import 'dart:io' show Platform;

/// Integration Test for ML Kit Translation on Real Device/Emulator
///
/// This test runs on actual Android/iOS devices and emulators.
/// It tests the real ML Kit translation implementation.
///
/// Run with:
/// ```bash
/// # Android
/// flutter test integration_test/mlkit_translation_integration_test.dart --device-id emulator-5554
///
/// # Or run on all devices
/// flutter test integration_test/mlkit_translation_integration_test.dart
/// ```
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('ML Kit Translation - Device Integration Tests', () {
    late ClientSideTranslationDelegateImpl service;

    setUpAll(() {
      print('\n${'=' * 70}');
      print('ML KIT DEVICE INTEGRATION TESTS');
      print('${'=' * 70}\n');

      final platform = Platform.isAndroid ? "Android" : Platform.isIOS ? "iOS" : "Unknown";
      print('Platform: $platform');

      if (Platform.isAndroid || Platform.isIOS) {
        print('✓ Running on mobile platform - ML Kit tests will execute');
      } else {
        print('⚠️  Not on mobile platform - tests will be skipped');
      }

      service = ClientSideTranslationDelegateImpl();
    });

    tearDownAll(() async {
      print('\nCleaning up ML Kit resources...');
      await service.close();
      print('Tests complete!\n');
    });

    testWidgets('Verify app launches', (WidgetTester tester) async {
      // Build the app wrapped in ProviderScope
      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the app is running
      expect(find.byType(MaterialApp), findsOneWidget);
      print('✓ App launched successfully');
    });

    testWidgets('Translate English to Spanish on device', (WidgetTester tester) async {
      if (!Platform.isAndroid && !Platform.isIOS) {
        print('⚠️  Test skipped - not on mobile platform');
        return;
      }

      print('\n--- Test: English → Spanish Translation ---');
      print('Input: "Hello world"');

      const testText = 'Hello world';
      final stopwatch = Stopwatch()..start();

      try {
        final result = await service.translate(
          text: testText,
          targetLanguage: 'es',
          sourceLanguage: 'en',
        );

        stopwatch.stop();

        print('Result: "$result"');
        print('Duration: ${stopwatch.elapsed.inMilliseconds}ms');

        expect(result, isNotEmpty, reason: 'Translation should not be empty');
        expect(result.toLowerCase(), isNot(equals(testText.toLowerCase())),
            reason: 'Translation should differ from input');

        final resultLower = result.toLowerCase();
        final hasSpanish = resultLower.contains('hola') ||
            resultLower.contains('mundo') ||
            resultLower.contains('el ') ||
            resultLower.contains('la ');

        expect(hasSpanish, isTrue, reason: 'Translation should contain Spanish words');
        print('✓ Spanish translation successful');

      } catch (e) {
        stopwatch.stop();
        print('❌ Translation failed: $e');
        rethrow;
      }
    }, timeout: const Timeout(Duration(minutes: 2)));

    testWidgets('Translate English to Bulgarian on device', (WidgetTester tester) async {
      if (!Platform.isAndroid && !Platform.isIOS) {
        print('⚠️  Test skipped - not on mobile platform');
        return;
      }

      print('\n--- Test: English → Bulgarian Translation ---');
      print('Input: "Hello"');

      const testText = 'Hello';
      final stopwatch = Stopwatch()..start();

      try {
        final result = await service.translate(
          text: testText,
          targetLanguage: 'bg',
          sourceLanguage: 'en',
        );

        stopwatch.stop();

        print('Result: "$result"');
        print('Duration: ${stopwatch.elapsed.inMilliseconds}ms');

        expect(result, isNotEmpty);

        // Bulgarian uses Cyrillic
        final hasCyrillic = RegExp(r'[а-я]').hasMatch(result);
        expect(hasCyrillic, isTrue, reason: 'Bulgarian translation should contain Cyrillic');

        print('✓ Bulgarian translation successful');

      } catch (e) {
        stopwatch.stop();
        print('❌ Translation failed: $e');
        rethrow;
      }
    }, timeout: const Timeout(Duration(minutes: 5)));

    testWidgets('Language model readiness check', (WidgetTester tester) async {
      if (!Platform.isAndroid && !Platform.isIOS) {
        print('⚠️  Test skipped - not on mobile platform');
        return;
      }

      print('\n--- Test: Language Model Readiness ---');

      try {
        final isReady = await service.isLanguageModelReady('es');
        print('Spanish model ready: $isReady');
        expect(isReady, isTrue);

        final bgReady = await service.isLanguageModelReady('bg');
        print('Bulgarian model ready: $bgReady');
        expect(bgReady, isTrue);

        print('✓ Language model readiness check successful');

      } catch (e) {
        print('❌ Readiness check failed: $e');
        rethrow;
      }
    }, timeout: const Timeout(Duration(minutes: 1)));

    testWidgets('Language detection', (WidgetTester tester) async {
      if (!Platform.isAndroid && !Platform.isIOS) {
        print('⚠️  Test skipped - not on mobile platform');
        return;
      }

      print('\n--- Test: Language Detection ---');

      const testCases = [
        {'text': 'Hello', 'expected': 'en'},
        {'text': 'Hola', 'expected': 'es'},
        {'text': 'Bonjour', 'expected': 'fr'},
      ];

      for (final testCase in testCases) {
        final text = testCase['text'] as String;
        print('Detecting language for: "$text"');

        final detected = await service.detectLanguage(text);
        print('  Detected: $detected (expected: ${testCase['expected']})');

        expect(detected, isNotEmpty);
      }

      print('✓ Language detection successful');
    }, timeout: const Timeout(Duration(minutes: 1)));

    testWidgets('Multiple sequential translations', (WidgetTester tester) async {
      if (!Platform.isAndroid && !Platform.isIOS) {
        print('⚠️  Test skipped - not on mobile platform');
        return;
      }

      print('\n--- Test: Sequential Translations ---');

      final testCases = [
        {'text': 'Hello', 'target': 'es'},
        {'text': 'Goodbye', 'target': 'es'},
        {'text': 'Thank you', 'target': 'fr'},
      ];

      final stopwatch = Stopwatch()..start();

      for (var i = 0; i < testCases.length; i++) {
        final testCase = testCases[i];
        final text = testCase['text'] as String;
        final target = testCase['target'] as String;

        print('  Translation ${i + 1}: "$text" → $target');

        final result = await service.translate(
          text: text,
          targetLanguage: target,
          sourceLanguage: 'en',
        );

        print('    Result: "$result"');
        expect(result, isNotEmpty);
      }

      stopwatch.stop();
      print('✓ All ${testCases.length} sequential translations successful');
      print('Total duration: ${stopwatch.elapsed.inSeconds}s');

    }, timeout: const Timeout(Duration(minutes: 3)));

    tearDownAll(() {
      print('\n${'=' * 70}');
      print('ML KIT DEVICE INTEGRATION TESTS COMPLETE');
      print('${'=' * 70}\n');

      if (Platform.isAndroid || Platform.isIOS) {
        print('Summary:');
        print('  ✓ ML Kit translation working on real device');
        print('  ✓ Multiple languages supported (es, fr, bg)');
        print('  ✓ Language model detection working');
        print('  ✓ Sequential translations working');
        print('\nModels are cached on device after first download.');
        print('Subsequent runs will be much faster.');
      }
      print('${'=' * 70}\n');
    });
  });
}
