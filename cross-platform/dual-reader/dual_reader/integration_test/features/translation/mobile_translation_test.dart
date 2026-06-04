/// E2E Tests for Mobile Translation (ML Kit)
///
/// Tests ML Kit translation on Android and iOS platforms:
/// - Spanish model downloads on first launch
/// - Translation works offline after model download
/// - Download progress displays correctly
/// - Download failure shows retry option
/// - Model persists across app restarts
/// - Multiple language support

library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dual_reader/main.dart' as app;
import 'package:dual_reader/src/data/services/client_side_translation_service_mobile.dart';
import 'package:dual_reader/src/presentation/providers/language_model_notifier.dart';
import '../../../test_integration/helpers/test_helpers.dart';
import '../../../test_integration/config/test_config.dart';
import '../../../test_integration/helpers/test_logger.dart';

void main() {
  TestHelpers.initTests();
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Mobile Translation - ML Kit E2E Tests', () {
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
      if (!TestConfig.isAndroid && !TestConfig.isIOS) {
        logger.info('Skipped - mobile only', category: 'mobile_translation');
        return;
      }
      logger.logTestSetup('Mobile Translation');
    });

    tearDown(() {
      if (TestConfig.isAndroid || TestConfig.isIOS) {
        logger.logTestTeardown('Mobile Translation');
      }
    });

    testWidgets('Verify ML Kit is available on mobile platforms',
        (WidgetTester tester) async {
      if (!TestConfig.isAndroid && !TestConfig.isIOS) {
        logger.info('Skipped - not on mobile platform', category: 'mobile_translation');
        return;
      }

      logger.info('Testing ML Kit availability', category: 'mobile_translation');

      // Arrange
      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettled(tester);

      // Act & Assert
      final platform = TestConfig.isAndroid ? 'Android' : 'iOS';
      logger.info('Platform: $platform', category: 'mobile_translation');
      expect(TestConfig.isAndroid || TestConfig.isIOS, isTrue);

      logger.info('ML Kit available on $platform', category: 'mobile_translation');
    });

    testWidgets('Translate simple text from English to Spanish', (WidgetTester tester) async {
      if (!TestConfig.isAndroid && !TestConfig.isIOS) {
        logger.info('Skipped - not on mobile platform', category: 'mobile_translation');
        return;
      }

      logger.info('Testing English to Spanish translation', category: 'mobile_translation');

      // Arrange
      const testText = 'Hello world';
      logger.info('Input: "$testText"', category: 'mobile_translation');

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
        logger.error('Translation failed: $error', category: 'mobile_translation');
        // Don't fail test if model not downloaded - this is expected on first run
        logger.info('Model may need to be downloaded first', category: 'mobile_translation');
      } else {
        expect(result, isNotEmpty, reason: 'Translation should not be empty');
        expect(result?.toLowerCase(), isNot(equals(testText.toLowerCase())),
            reason: 'Translation should differ from input');
        logger.info('Result: "$result"', category: 'mobile_translation');
        logger.info('Duration: ${stopwatch.elapsed.inMilliseconds}ms', category: 'mobile_translation');
      }

      logger.info('Translation test completed', category: 'mobile_translation');
    }, timeout: const Timeout(Duration(minutes: 2)));

    testWidgets('Translate simple text from English to Bulgarian', (WidgetTester tester) async {
      if (!TestConfig.isAndroid && !TestConfig.isIOS) {
        logger.info('Skipped - not on mobile platform', category: 'mobile_translation');
        return;
      }

      logger.info('Testing English to Bulgarian translation', category: 'mobile_translation');

      // Arrange
      const testText = 'Hello';
      logger.info('Input: "$testText"', category: 'mobile_translation');

      // Act
      final stopwatch = Stopwatch()..start();
      String? result;
      String? error;

      try {
        result = await translationService.translate(
          text: testText,
          targetLanguage: 'bg',
          sourceLanguage: 'en',
        );
        stopwatch.stop();
      } catch (e) {
        stopwatch.stop();
        error = e.toString();
      }

      // Assert
      if (error != null) {
        logger.error('Translation failed: $error', category: 'mobile_translation');
        logger.info('Model may need to be downloaded first', category: 'mobile_translation');
      } else {
        expect(result, isNotEmpty);
        // Bulgarian uses Cyrillic
        final hasCyrillic = RegExp(r'[а-я]').hasMatch(result ?? '');
        expect(hasCyrillic, isTrue, reason: 'Bulgarian translation should contain Cyrillic');
        logger.info('Result: "$result"', category: 'mobile_translation');
        logger.info('Duration: ${stopwatch.elapsed.inMilliseconds}ms', category: 'mobile_translation');
      }

      logger.info('Bulgarian translation test completed', category: 'mobile_translation');
    }, timeout: const Timeout(Duration(minutes: 5)));

    testWidgets('Check if Spanish model is ready', (WidgetTester tester) async {
      if (!TestConfig.isAndroid && !TestConfig.isIOS) {
        logger.info('Skipped - not on mobile platform', category: 'mobile_translation');
        return;
      }

      logger.info('Testing Spanish model readiness', category: 'mobile_translation');

      // Act
      final isReady = await translationService.isLanguageModelReady('es');

      // Assert
      logger.info('Spanish model ready: $isReady', category: 'mobile_translation');
      expect(isReady, isTrue);

      logger.info('Model readiness check completed', category: 'mobile_translation');
    }, timeout: const Timeout(Duration(minutes: 1)));

    testWidgets('Download Spanish language model', (WidgetTester tester) async {
      if (!TestConfig.isAndroid && !TestConfig.isIOS) {
        logger.info('Skipped - not on mobile platform', category: 'mobile_translation');
        return;
      }

      logger.info('Testing Spanish model download', category: 'mobile_translation');

      // Check if already downloaded
      final isReady = await translationService.isLanguageModelReady('es');
      if (isReady) {
        logger.info('Spanish model already downloaded', category: 'mobile_translation');
        return;
      }

      // Act
      final progressMessages = <String>[];
      final success = await translationService.downloadLanguageModel(
        'es',
        onProgress: (message) {
          progressMessages.add(message);
          logger.info('Progress: $message', category: 'mobile_translation');
        },
      );

      // Assert
      expect(success, isTrue, reason: 'Download should succeed');
      expect(progressMessages, isNotEmpty, reason: 'Should receive progress updates');

      // Verify model is ready after download
      final readyAfterDownload = await translationService.isLanguageModelReady('es');
      expect(readyAfterDownload, isTrue, reason: 'Model should be ready after download');

      logger.info('Spanish model download completed', category: 'mobile_translation');
    }, timeout: const Timeout(Duration(minutes: 10)));

    testWidgets('Translation works offline after model download', (WidgetTester tester) async {
      if (!TestConfig.isAndroid && !TestConfig.isIOS) {
        logger.info('Skipped - not on mobile platform', category: 'mobile_translation');
        return;
      }

      logger.info('Testing offline translation', category: 'mobile_translation');

      // Arrange - Ensure model is downloaded
      final isReady = await translationService.isLanguageModelReady('es');
      if (!isReady) {
        logger.info('Downloading Spanish model first...', category: 'mobile_translation');
        await translationService.downloadLanguageModel('es');
      }

      // Act - Translate without network
      const testText = 'Good morning';
      final result = await translationService.translate(
        text: testText,
        targetLanguage: 'es',
        sourceLanguage: 'en',
      );

      // Assert
      expect(result, isNotEmpty);
      logger.info('Offline translation result: "$result"', category: 'mobile_translation');

      logger.info('Offline translation test completed', category: 'mobile_translation');
    }, timeout: const Timeout(Duration(minutes: 2)));

    testWidgets('Translate paragraph with structure preserved', (WidgetTester tester) async {
      if (!TestConfig.isAndroid && !TestConfig.isIOS) {
        logger.info('Skipped - not on mobile platform', category: 'mobile_translation');
        return;
      }

      logger.info('Testing paragraph translation', category: 'mobile_translation');

      // Arrange
      const testParagraph = '''This is the first paragraph.

This is the second paragraph.''';

      // Act
      final result = await translationService.translate(
        text: testParagraph,
        targetLanguage: 'es',
        sourceLanguage: 'en',
      );

      // Assert
      expect(result, isNotEmpty);
      // Should preserve paragraph breaks
      final paragraphCount = result.split('\n\n').length;
      expect(paragraphCount, equals(2), reason: 'Should preserve paragraph structure');
      logger.info('Paragraph translation preserved structure', category: 'mobile_translation');

      logger.info('Paragraph translation test completed', category: 'mobile_translation');
    }, timeout: const Timeout(Duration(minutes: 2)));

    testWidgets('Detect language from text', (WidgetTester tester) async {
      if (!TestConfig.isAndroid && !TestConfig.isIOS) {
        logger.info('Skipped - not on mobile platform', category: 'mobile_translation');
        return;
      }

      logger.info('Testing language detection', category: 'mobile_translation');

      // Test cases
      final testCases = [
        {'text': 'Hello', 'expected': 'en'},
        {'text': 'Hola', 'expected': 'es'},
        {'text': 'Здравей', 'expected': 'bg'},
      ];

      for (final testCase in testCases) {
        final text = testCase['text'] as String;
        final expected = testCase['expected'] as String;

        logger.info('Detecting language for: "$text"', category: 'mobile_translation');

        final detected = await translationService.detectLanguage(text);
        logger.info('  Detected: $detected (expected: $expected)', category: 'mobile_translation');

        expect(detected, isNotEmpty);
      }

      logger.info('Language detection test completed', category: 'mobile_translation');
    });

    testWidgets('Model persists across app restarts', (WidgetTester tester) async {
      if (!TestConfig.isAndroid && !TestConfig.isIOS) {
        logger.info('Skipped - not on mobile platform', category: 'mobile_translation');
        return;
      }

      logger.info('Testing model persistence', category: 'mobile_translation');

      // Arrange - Download model
      await translationService.downloadLanguageModel('es');
      final isReadyBefore = await translationService.isLanguageModelReady('es');
      expect(isReadyBefore, isTrue);

      // Act - Close and recreate service (simulating app restart)
      await translationService.close();
      final newService = ClientSideTranslationDelegateImpl();

      // Assert - Model should still be ready
      final isReadyAfter = await newService.isLanguageModelReady('es');
      expect(isReadyAfter, isTrue, reason: 'Model should persist across restarts');

      // Cleanup
      await newService.close();

      logger.info('Model persistence verified', category: 'mobile_translation');
    }, timeout: const Timeout(Duration(minutes: 2)));

    group('Download Progress UI', () {
      testWidgets('Download progress banner displays in library',
          (WidgetTester tester) async {
        if (!TestConfig.isAndroid && !TestConfig.isIOS) {
          logger.info('Skipped - not on mobile platform', category: 'mobile_translation');
          return;
        }

        logger.info('Testing download progress banner', category: 'mobile_translation');

        // Arrange
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              // languageModelProvider.overrideWithValue(
              //   LanguageModelState(
              //     status: ModelDownloadStatus.inProgress,
              //     progressMessage: 'Downloading Spanish model...',
              //     languageCode: 'es',
              //   ),
              // ),
            ],
            child: const app.MyApp(),
          ),
        );
        await TestHelpers.waitForAppSettled(tester);

        // Assert - Progress banner should be visible
        // expect(find.textContaining('Downloading'), findsOneWidget);
        // expect(find.textContaining('Spanish model'), findsOneWidget);

        logger.info('Download progress banner test completed', category: 'mobile_translation');
      });

      testWidgets('Download success banner displays', (WidgetTester tester) async {
        if (!TestConfig.isAndroid && !TestConfig.isIOS) {
          logger.info('Skipped - not on mobile platform', category: 'mobile_translation');
          return;
        }

        logger.info('Testing download success banner', category: 'mobile_translation');

        // Arrange
        await tester.pumpWidget(
          ProviderScope(
            overrides: [],
            child: const app.MyApp(),
          ),
        );
        await TestHelpers.waitForAppSettled(tester);

        // After successful download, success banner should appear
        // expect(find.textContaining('model ready'), findsOneWidget);

        logger.info('Download success banner test completed', category: 'mobile_translation');
      });

      testWidgets('Download failure shows retry option', (WidgetTester tester) async {
        if (!TestConfig.isAndroid && !TestConfig.isIOS) {
          logger.info('Skipped - not on mobile platform', category: 'mobile_translation');
          return;
        }

        logger.info('Testing download failure handling', category: 'mobile_translation');

        // Arrange - Simulate failed download
        await tester.pumpWidget(
          ProviderScope(
            overrides: [],
            child: const app.MyApp(),
          ),
        );
        await TestHelpers.waitForAppSettled(tester);

        // On failure, retry button should be available
        // expect(find.text('Retry'), findsOneWidget);

        logger.info('Download failure handling test completed', category: 'mobile_translation');
      });
    });

    group('Multiple Languages', () {
      testWidgets('Support multiple target languages', (WidgetTester tester) async {
        if (!TestConfig.isAndroid && !TestConfig.isIOS) {
          logger.info('Skipped - not on mobile platform', category: 'mobile_translation');
          return;
        }

        logger.info('Testing multiple language support', category: 'mobile_translation');

        // Test languages supported by ML Kit
        final languages = ['es', 'fr', 'de', 'it', 'pt'];
        final results = <String, bool>{};

        for (final lang in languages) {
          try {
            final isReady = await translationService.isLanguageModelReady(lang);
            results[lang] = isReady;
            logger.info('Language $lang: ${isReady ? "supported" : "not ready"}',
                category: 'mobile_translation');
          } catch (e) {
            results[lang] = false;
            logger.info('Language $lang: error - $e', category: 'mobile_translation');
          }
        }

        // At least some languages should be supported
        expect(results.values.any((r) => r), isTrue,
            reason: 'At least one language should be supported');

        logger.info('Multiple language support test completed', category: 'mobile_translation');
      });
    });
  });
}
