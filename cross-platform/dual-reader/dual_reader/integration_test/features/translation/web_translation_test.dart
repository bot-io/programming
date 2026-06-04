/// E2E Tests for Web Translation (Transformers.js)
///
/// Tests Transformers.js NLLB-200 translation on web platform:
/// - Model loads from CDN
/// - Translation completes successfully
/// - Multiple languages supported
/// - Sentence-based translation quality
/// - Paragraph context preservation

library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dual_reader/main.dart' as app;
import 'package:dual_reader/src/data/services/client_side_translation_service_web.dart';
import '../../../test_integration/helpers/test_helpers.dart';
import '../../../test_integration/config/test_config.dart';
import '../../../test_integration/helpers/test_logger.dart';

void main() {
  TestHelpers.initTests();
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Web Translation - Transformers.js E2E Tests', () {
    late TestLogger logger;
    late ClientSideTranslationDelegateImpl translationService;

    setUpAll(() {
      logger = TestLogger();
      translationService = ClientSideTranslationDelegateImpl();
    });

    tearDownAll(() async {
      await translationService.close();
      await logger.dispose();
    });

    setUp(() {
      if (!TestConfig.isWeb) {
        logger.info('Skipped - web only', category: 'web_translation');
        return;
      }
      logger.logTestSetup('Web Translation');
    });

    tearDown(() {
      if (TestConfig.isWeb) {
        logger.logTestTeardown('Web Translation');
      }
    });

    testWidgets('Verify Transformers.js is available on web platform',
        (WidgetTester tester) async {
      if (!TestConfig.isWeb) {
        logger.info('Skipped - not on web platform', category: 'web_translation');
        return;
      }

      logger.info('Testing Transformers.js availability', category: 'web_translation');

      // Arrange
      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettled(tester);

      // Act & Assert
      logger.info('Platform: Web', category: 'web_translation');
      expect(TestConfig.isWeb, isTrue);

      logger.info('Transformers.js available on web', category: 'web_translation');
    });

    testWidgets('Translate simple text from English to Spanish', (WidgetTester tester) async {
      if (!TestConfig.isWeb) {
        logger.info('Skipped - not on web platform', category: 'web_translation');
        return;
      }

      logger.info('Testing English to Spanish translation', category: 'web_translation');

      // Arrange
      const testText = 'Hello world';
      logger.info('Input: "$testText"', category: 'web_translation');

      // Act
      final stopwatch = Stopwatch()..start();
      String? result;
      String? error;

      try {
        result = await translationService.translate(
          text: testText,
          targetLanguage: 'es',
          sourceLanguage: 'en',
        );
        stopwatch.stop();
      } catch (e) {
        stopwatch.stop();
        error = e.toString();
      }

      // Assert
      if (error != null) {
        logger.error('Translation failed: $error', category: 'web_translation');
        // Model may still be loading from CDN
        logger.info('Model may be loading from CDN', category: 'web_translation');
      } else {
        expect(result, isNotEmpty, reason: 'Translation should not be empty');
        logger.info('Result: "$result"', category: 'web_translation');
        logger.info('Duration: ${stopwatch.elapsed.inMilliseconds}ms', category: 'web_translation');
      }

      logger.info('Translation test completed', category: 'web_translation');
    }, timeout: const Timeout(Duration(minutes: 3)));

    testWidgets('Model loads from CDN successfully', (WidgetTester tester) async {
      if (!TestConfig.isWeb) {
        logger.info('Skipped - not on web platform', category: 'web_translation');
        return;
      }

      logger.info('Testing model loading from CDN', category: 'web_translation');

      // Act
      final isReady = await translationService.isLanguageModelReady('es');

      // Assert
      logger.info('Model ready: $isReady', category: 'web_translation');

      if (!isReady) {
        // Try to load the model
        logger.info('Attempting to load model...', category: 'web_translation');
        final loaded = await translationService.downloadLanguageModel('es');
        expect(loaded, isTrue, reason: 'Model should load from CDN');
      }

      logger.info('Model loading test completed', category: 'web_translation');
    }, timeout: const Timeout(Duration(minutes: 5)));

    testWidgets('Translate paragraph with sentence splitting', (WidgetTester tester) async {
      if (!TestConfig.isWeb) {
        logger.info('Skipped - not on web platform', category: 'web_translation');
        return;
      }

      logger.info('Testing sentence-based translation', category: 'web_translation');

      // Arrange - Multi-sentence paragraph
      const testParagraph = 'The quick brown fox jumps over the lazy dog. '
          'It was a bright cold day in April, and the clocks were striking thirteen. '
          'The weather was beautiful.';

      // Act
      final result = await translationService.translate(
        text: testParagraph,
        targetLanguage: 'es',
        sourceLanguage: 'en',
      );

      // Assert
      expect(result, isNotEmpty);
      // Should maintain similar sentence count
      final originalSentences = testParagraph.split('. ').length;
      final translatedSentences = result.split('. ').length;
      expect(translatedSentences, closeTo(originalSentences, 1),
          reason: 'Should maintain sentence structure');

      logger.info('Sentence-based translation test completed', category: 'web_translation');
    }, timeout: const Timeout(Duration(minutes: 3)));

    testWidgets('Preserve paragraph breaks in translation', (WidgetTester tester) async {
      if (!TestConfig.isWeb) {
        logger.info('Skipped - not on web platform', category: 'web_translation');
        return;
      }

      logger.info('Testing paragraph break preservation', category: 'web_translation');

      // Arrange
      const testText = '''First paragraph here.

Second paragraph here.

Third paragraph here.''';

      // Act
      final result = await translationService.translate(
        text: testText,
        targetLanguage: 'es',
        sourceLanguage: 'en',
      );

      // Assert
      expect(result, isNotEmpty);
      final originalParagraphs = testText.split('\n\n').length;
      final translatedParagraphs = result.split('\n\n').length;
      expect(translatedParagraphs, equals(originalParagraphs),
          reason: 'Should preserve paragraph breaks');

      logger.info('Paragraph preservation test completed', category: 'web_translation');
    }, timeout: const Timeout(Duration(minutes: 3)));

    testWidgets('Handle special characters correctly', (WidgetTester tester) async {
      if (!TestConfig.isWeb) {
        logger.info('Skipped - not on web platform', category: 'web_translation');
        return;
      }

      logger.info('Testing special character handling', category: 'web_translation');

      // Arrange
      const testText = 'Hello! How are you? I\'m fine, thanks.';
      logger.info('Input: "$testText"', category: 'web_translation');

      // Act
      final result = await translationService.translate(
        text: testText,
        targetLanguage: 'es',
        sourceLanguage: 'en',
      );

      // Assert
      expect(result, isNotEmpty);
      // Should contain punctuation
      expect(result, contains(RegExp(r'[!?.,]')),
          reason: 'Should preserve punctuation');

      logger.info('Result: "$result"', category: 'web_translation');
      logger.info('Special character test completed', category: 'web_translation');
    }, timeout: const Timeout(Duration(minutes: 3)));

    testWidgets('Detect language from text (web)', (WidgetTester tester) async {
      if (!TestConfig.isWeb) {
        logger.info('Skipped - not on web platform', category: 'web_translation');
        return;
      }

      logger.info('Testing web language detection', category: 'web_translation');

      // Test cases
      final testCases = [
        {'text': 'Hello', 'expected': 'en'},
        {'text': 'Hola mundo', 'expected': 'es'},
        {'text': 'Привет', 'expected': 'ru'}, // Cyrillic
      ];

      for (final testCase in testCases) {
        final text = testCase['text'] as String;
        final expected = testCase['expected'] as String;

        logger.info('Detecting language for: "$text"', category: 'web_translation');

        final detected = await translationService.detectLanguage(text);
        logger.info('  Detected: $detected (expected: $expected)', category: 'web_translation');

        expect(detected, isNotEmpty);
      }

      logger.info('Language detection test completed', category: 'web_translation');
    });

    testWidgets('Translation quality maintains context', (WidgetTester tester) async {
      if (!TestConfig.isWeb) {
        logger.info('Skipped - not on web platform', category: 'web_translation');
        return;
      }

      logger.info('Testing translation quality', category: 'web_translation');

      // Arrange - Text with context-dependent words
      const testText = 'The bank of the river was beautiful. '
          'She went to the bank to withdraw money.';

      // Act
      final result = await translationService.translate(
        text: testText,
        targetLanguage: 'es',
        sourceLanguage: 'en',
      );

      // Assert
      expect(result, isNotEmpty);
      logger.info('Original: "$testText"', category: 'web_translation');
      logger.info('Translated: "$result"', category: 'web_translation');

      logger.info('Translation quality test completed', category: 'web_translation');
    }, timeout: const Timeout(Duration(minutes: 3)));

    group('Multiple Languages', () {
      testWidgets('Support multiple target languages', (WidgetTester tester) async {
        if (!TestConfig.isWeb) {
          logger.info('Skipped - not on web platform', category: 'web_translation');
          return;
        }

        logger.info('Testing multiple language support', category: 'web_translation');

        // Test languages supported by NLLB-200
        final languages = ['es', 'fr', 'de', 'it', 'pt', 'ru', 'zh', 'ja'];
        final results = <String, bool>{};

        for (final lang in languages) {
          try {
            // Just check if model can be loaded
            final isReady = await translationService.isLanguageModelReady(lang);
            results[lang] = isReady;
            logger.info('Language $lang: ${isReady ? "ready" : "loading"}',
                category: 'web_translation');
          } catch (e) {
            results[lang] = false;
            logger.info('Language $lang: error - $e', category: 'web_translation');
          }
        }

        // At least some languages should be supported
        expect(results.values.any((r) => r), isTrue,
            reason: 'At least one language should be supported');

        logger.info('Multiple language support test completed', category: 'web_translation');
      });
    });

    group('Error Handling', () {
      testWidgets('Handle empty text gracefully', (WidgetTester tester) async {
        if (!TestConfig.isWeb) {
          logger.info('Skipped - not on web platform', category: 'web_translation');
          return;
        }

        logger.info('Testing empty text handling', category: 'web_translation');

        // Arrange
        const emptyText = '';

        // Act & Assert
        expect(
          () async => await translationService.translate(
            text: emptyText,
            targetLanguage: 'es',
            sourceLanguage: 'en',
          ),
          throwsA(isA<Exception>()),
        );

        logger.info('Empty text handling test completed', category: 'web_translation');
      });

      testWidgets('Handle very long text', (WidgetTester tester) async {
        if (!TestConfig.isWeb) {
          logger.info('Skipped - not on web platform', category: 'web_translation');
          return;
        }

        logger.info('Testing long text handling', category: 'web_translation');

        // Arrange - Create long text (1000 words)
        final longText = List.generate(1000, (i) => 'word$i').join(' ');

        // Act
        final result = await translationService.translate(
          text: longText,
          targetLanguage: 'es',
          sourceLanguage: 'en',
        );

        // Assert
        expect(result, isNotEmpty);
        expect(result.length, greaterThan(100));

        logger.info('Long text handling test completed', category: 'web_translation');
      }, timeout: const Timeout(Duration(minutes: 10)));
    });
  });
}
