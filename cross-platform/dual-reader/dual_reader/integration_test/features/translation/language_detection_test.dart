/// E2E Tests for Language Detection
///
/// Tests automatic language detection:
/// - Auto-detect source language
/// - Translate to first alternative when source = target
/// - Handle mixed language text
/// - Language detection caching
/// - Edge cases (short text, special characters, numbers)

library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dual_reader/main.dart' as app;
import 'package:dual_reader/src/data/services/client_side_translation_service_mobile.dart';
import 'package:dual_reader/src/data/services/client_side_translation_service_web.dart';
import '../../../test_integration/helpers/test_helpers.dart';
import '../../../test_integration/config/test_config.dart';
import '../../../test_integration/helpers/test_logger.dart';

void main() {
  TestHelpers.initTests();
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Language Detection E2E Tests', () {
    late TestLogger logger;
    late ClientSideTranslationDelegateImpl? mobileService;
    late ClientSideTranslationDelegateImpl? webService;

    setUpAll(() async {
      logger = TestLogger();

      if (TestConfig.isAndroid || TestConfig.isIOS) {
        mobileService = ClientSideTranslationDelegateImpl();
      }
      if (TestConfig.isWeb) {
        webService = ClientSideTranslationDelegateImpl();
      }
    });

    tearDownAll(() async {
      await mobileService?.close();
      await webService?.close();
      await logger.dispose();
    });

    setUp(() {
      logger.logTestSetup('Language Detection');
    });

    tearDown(() {
      logger.logTestTeardown('Language Detection');
    });

    group('Mobile Language Detection', () {
      testWidgets('Detect English language', (WidgetTester tester) async {
        if (!TestConfig.isAndroid && !TestConfig.isIOS) {
          logger.info('Skipped - mobile only', category: 'language_detection');
          return;
        }

        logger.info('Testing English detection', category: 'language_detection');

        // Arrange
        const englishText = 'Hello world, how are you today?';

        // Act
        final detected = await mobileService!.detectLanguage(englishText);

        // Assert
        expect(detected, equals('en'), reason: 'Should detect English');
        logger.info('Detected: $detected', category: 'language_detection');

        logger.info('English detection test completed', category: 'language_detection');
      });

      testWidgets('Detect Spanish language', (WidgetTester tester) async {
        if (!TestConfig.isAndroid && !TestConfig.isIOS) {
          logger.info('Skipped - mobile only', category: 'language_detection');
          return;
        }

        logger.info('Testing Spanish detection', category: 'language_detection');

        // Arrange
        const spanishText = 'Hola mundo, ¿cómo estás hoy?';

        // Act
        final detected = await mobileService!.detectLanguage(spanishText);

        // Assert
        expect(detected, equals('es'), reason: 'Should detect Spanish');
        logger.info('Detected: $detected', category: 'language_detection');

        logger.info('Spanish detection test completed', category: 'language_detection');
      });

      testWidgets('Detect Bulgarian language (Cyrillic)', (WidgetTester tester) async {
        if (!TestConfig.isAndroid && !TestConfig.isIOS) {
          logger.info('Skipped - mobile only', category: 'language_detection');
          return;
        }

        logger.info('Testing Bulgarian detection', category: 'language_detection');

        // Arrange
        const bulgarianText = 'Здравей свят, как си днес?';

        // Act
        final detected = await mobileService!.detectLanguage(bulgarianText);

        // Assert
        expect(detected, equals('bg'), reason: 'Should detect Bulgarian');
        logger.info('Detected: $detected', category: 'language_detection');

        logger.info('Bulgarian detection test completed', category: 'language_detection');
      });

      testWidgets('Detect French language', (WidgetTester tester) async {
        if (!TestConfig.isAndroid && !TestConfig.isIOS) {
          logger.info('Skipped - mobile only', category: 'language_detection');
          return;
        }

        logger.info('Testing French detection', category: 'language_detection');

        // Arrange
        const frenchText = 'Bonjour le monde, comment allez-vous aujourd\'hui?';

        // Act
        final detected = await mobileService!.detectLanguage(frenchText);

        // Assert
        expect(detected, equals('fr'), reason: 'Should detect French');
        logger.info('Detected: $detected', category: 'language_detection');

        logger.info('French detection test completed', category: 'language_detection');
      });

      testWidgets('Detect German language', (WidgetTester tester) async {
        if (!TestConfig.isAndroid && !TestConfig.isIOS) {
          logger.info('Skipped - mobile only', category: 'language_detection');
          return;
        }

        logger.info('Testing German detection', category: 'language_detection');

        // Arrange
        const germanText = 'Hallo Welt, wie geht es dir heute?';

        // Act
        final detected = await mobileService!.detectLanguage(germanText);

        // Assert
        expect(detected, equals('de'), reason: 'Should detect German');
        logger.info('Detected: $detected', category: 'language_detection');

        logger.info('German detection test completed', category: 'language_detection');
      });

      testWidgets('Detect Russian language (Cyrillic)', (WidgetTester tester) async {
        if (!TestConfig.isAndroid && !TestConfig.isIOS) {
          logger.info('Skipped - mobile only', category: 'language_detection');
          return;
        }

        logger.info('Testing Russian detection', category: 'language_detection');

        // Arrange
        const russianText = 'Привет мир, как у тебя дела сегодня?';

        // Act
        final detected = await mobileService!.detectLanguage(russianText);

        // Assert
        expect(detected, equals('ru'), reason: 'Should detect Russian');
        logger.info('Detected: $detected', category: 'language_detection');

        logger.info('Russian detection test completed', category: 'language_detection');
      });

      testWidgets('Detect Chinese language', (WidgetTester tester) async {
        if (!TestConfig.isAndroid && !TestConfig.isIOS) {
          logger.info('Skipped - mobile only', category: 'language_detection');
          return;
        }

        logger.info('Testing Chinese detection', category: 'language_detection');

        // Arrange
        const chineseText = '你好世界，你好吗？';

        // Act
        final detected = await mobileService!.detectLanguage(chineseText);

        // Assert
        expect(detected, equals('zh'), reason: 'Should detect Chinese');
        logger.info('Detected: $detected', category: 'language_detection');

        logger.info('Chinese detection test completed', category: 'language_detection');
      });

      testWidgets('Detect Japanese language', (WidgetTester tester) async {
        if (!TestConfig.isAndroid && !TestConfig.isIOS) {
          logger.info('Skipped - mobile only', category: 'language_detection');
          return;
        }

        logger.info('Testing Japanese detection', category: 'language_detection');

        // Arrange
        const japaneseText = 'こんにちは世界、元気ですか？';

        // Act
        final detected = await mobileService!.detectLanguage(japaneseText);

        // Assert
        expect(detected, equals('ja'), reason: 'Should detect Japanese');
        logger.info('Detected: $detected', category: 'language_detection');

        logger.info('Japanese detection test completed', category: 'language_detection');
      });

      testWidgets('Detect Korean language', (WidgetTester tester) async {
        if (!TestConfig.isAndroid && !TestConfig.isIOS) {
          logger.info('Skipped - mobile only', category: 'language_detection');
          return;
        }

        logger.info('Testing Korean detection', category: 'language_detection');

        // Arrange
        const koreanText = '안녕하세요 세계, 어떻게 지내세요?';

        // Act
        final detected = await mobileService!.detectLanguage(koreanText);

        // Assert
        expect(detected, equals('ko'), reason: 'Should detect Korean');
        logger.info('Detected: $detected', category: 'language_detection');

        logger.info('Korean detection test completed', category: 'language_detection');
      });

      testWidgets('Detect Arabic language', (WidgetTester tester) async {
        if (!TestConfig.isAndroid && !TestConfig.isIOS) {
          logger.info('Skipped - mobile only', category: 'language_detection');
          return;
        }

        logger.info('Testing Arabic detection', category: 'language_detection');

        // Arrange
        const arabicText = 'مرحبا بالعالم، كيف حالك اليوم؟';

        // Act
        final detected = await mobileService!.detectLanguage(arabicText);

        // Assert
        expect(detected, equals('ar'), reason: 'Should detect Arabic');
        logger.info('Detected: $detected', category: 'language_detection');

        logger.info('Arabic detection test completed', category: 'language_detection');
      });
    });

    group('Web Language Detection', () {
      testWidgets('Detect English on web', (WidgetTester tester) async {
        if (!TestConfig.isWeb) {
          logger.info('Skipped - web only', category: 'language_detection');
          return;
        }

        logger.info('Testing web English detection', category: 'language_detection');

        // Arrange
        const englishText = 'Hello world';

        // Act
        final detected = await webService!.detectLanguage(englishText);

        // Assert
        expect(detected, equals('en'), reason: 'Should detect English');
        logger.info('Detected: $detected', category: 'language_detection');

        logger.info('Web English detection completed', category: 'language_detection');
      });

      testWidgets('Detect Spanish on web', (WidgetTester tester) async {
        if (!TestConfig.isWeb) {
          logger.info('Skipped - web only', category: 'language_detection');
          return;
        }

        logger.info('Testing web Spanish detection', category: 'language_detection');

        // Arrange
        const spanishText = 'Hola el mundo';

        // Act
        final detected = await webService!.detectLanguage(spanishText);

        // Assert
        expect(detected, equals('es'), reason: 'Should detect Spanish');
        logger.info('Detected: $detected', category: 'language_detection');

        logger.info('Web Spanish detection completed', category: 'language_detection');
      });
    });

    group('Edge Cases', () {
      testWidgets('Handle very short text', (WidgetTester tester) async {
        logger.info('Testing short text detection', category: 'language_detection');

        final service = TestConfig.isAndroid || TestConfig.isIOS
            ? mobileService!
            : webService!;

        if (service == null) {
          logger.info('No service available - skipping', category: 'language_detection');
          return;
        }

        // Arrange
        const shortText = 'Hi';

        // Act
        final detected = await service.detectLanguage(shortText);

        // Assert
        expect(detected, isNotEmpty, reason: 'Should detect language even for short text');
        logger.info('Detected: $detected for "$shortText"', category: 'language_detection');

        logger.info('Short text detection completed', category: 'language_detection');
      });

      testWidgets('Handle text with numbers', (WidgetTester tester) async {
        logger.info('Testing numeric text detection', category: 'language_detection');

        final service = TestConfig.isAndroid || TestConfig.isIOS
            ? mobileService!
            : webService!;

        if (service == null) {
          logger.info('No service available - skipping', category: 'language_detection');
          return;
        }

        // Arrange
        const numericText = 'I have 123 apples and 456 oranges.';

        // Act
        final detected = await service.detectLanguage(numericText);

        // Assert
        expect(detected, equals('en'), reason: 'Should detect English despite numbers');
        logger.info('Detected: $detected', category: 'language_detection');

        logger.info('Numeric text detection completed', category: 'language_detection');
      });

      testWidgets('Handle text with special characters', (WidgetTester tester) async {
        logger.info('Testing special character handling', category: 'language_detection');

        final service = TestConfig.isAndroid || TestConfig.isIOS
            ? mobileService!
            : webService!;

        if (service == null) {
          logger.info('No service available - skipping', category: 'language_detection');
          return;
        }

        // Arrange
        const specialText = 'Hello! @user #hashtag \$100';

        // Act
        final detected = await service.detectLanguage(specialText);

        // Assert
        expect(detected, equals('en'), reason: 'Should detect English');
        logger.info('Detected: $detected', category: 'language_detection');

        logger.info('Special character handling completed', category: 'language_detection');
      });

      testWidgets('Handle empty text', (WidgetTester tester) async {
        logger.info('Testing empty text detection', category: 'language_detection');

        final service = TestConfig.isAndroid || TestConfig.isIOS
            ? mobileService!
            : webService!;

        if (service == null) {
          logger.info('No service available - skipping', category: 'language_detection');
          return;
        }

        // Arrange
        const emptyText = '';

        // Act
        final detected = await service.detectLanguage(emptyText);

        // Assert
        expect(detected, isNotEmpty, reason: 'Should return default for empty text');
        logger.info('Detected: $detected for empty text', category: 'language_detection');

        logger.info('Empty text detection completed', category: 'language_detection');
      });

      testWidgets('Handle mixed language text', (WidgetTester tester) async {
        logger.info('Testing mixed language detection', category: 'language_detection');

        final service = TestConfig.isAndroid || TestConfig.isIOS
            ? mobileService!
            : webService!;

        if (service == null) {
          logger.info('No service available - skipping', category: 'language_detection');
          return;
        }

        // Arrange - Text with mixed English and Spanish
        const mixedText = 'Hello! ¿Cómo estás? I am fine, gracias.';

        // Act
        final detected = await service.detectLanguage(mixedText);

        // Assert
        expect(detected, isNotEmpty);
        logger.info('Detected: $detected for mixed text', category: 'language_detection');
        logger.info('Note: Mixed text may detect dominant language', category: 'language_detection');

        logger.info('Mixed language detection completed', category: 'language_detection');
      });
    });

    group('Translation with Auto-Detection', () {
      testWidgets('Translate with auto-detected source', (WidgetTester tester) async {
        if (!TestConfig.isAndroid && !TestConfig.isIOS) {
          logger.info('Skipped - mobile only', category: 'language_detection');
          return;
        }

        logger.info('Testing translation with auto-detection', category: 'language_detection');

        // Arrange
        const englishText = 'Hello world';
        const targetLang = 'es';

        // Act - Translate without specifying source (auto-detect)
        final result = await mobileService!.translate(
          text: englishText,
          targetLanguage: targetLang,
          // sourceLanguage omitted for auto-detection
        );

        // Assert
        expect(result, isNotEmpty);
        logger.info('Auto-detected translation: "$result"', category: 'language_detection');

        logger.info('Auto-detection translation completed', category: 'language_detection');
      }, timeout: const Timeout(Duration(minutes: 2)));

      testWidgets('Handle source equals target language', (WidgetTester tester) async {
        if (!TestConfig.isAndroid && !TestConfig.isIOS) {
          logger.info('Skipped - mobile only', category: 'language_detection');
          return;
        }

        logger.info('Testing source = target handling', category: 'language_detection');

        // Arrange
        const spanishText = 'Hola mundo';
        const sameLang = 'es';

        // Act - Try to translate Spanish to Spanish
        final result = await mobileService!.translate(
          text: spanishText,
          targetLanguage: sameLang,
          sourceLanguage: sameLang,
        );

        // Assert
        expect(result, isNotEmpty);
        logger.info('Same-language translation result: "$result"',
            category: 'language_detection');

        logger.info('Source = target handling completed', category: 'language_detection');
      }, timeout: const Timeout(Duration(minutes: 2)));
    });
  });
}
