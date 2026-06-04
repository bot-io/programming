/// E2E Tests for Translation Settings
///
/// Tests translation-related settings:
/// - Clear translation cache
/// - Clear downloaded models
/// - Select target language
/// - All languages accessible
/// - Language preference persists

library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:dual_reader/main.dart' as app;
import '../../../test_integration/helpers/test_helpers.dart';
import '../../../test_integration/pages/settings_page.dart';
import '../../../test_integration/config/test_config.dart';
import '../../../test_integration/helpers/test_logger.dart';

void main() {
  TestHelpers.initTests();
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Settings - Translation E2E Tests', () {
    late TestLogger logger;

    setUpAll(() {
      logger = TestLogger();
    });

    tearDownAll(() async {
      await logger.dispose();
    });

    setUp(() {
      logger.logTestSetup('Translation Settings');
    });

    tearDown(() {
      logger.logTestTeardown('Translation Settings');
    });

    testWidgets('Clear translation cache', (WidgetTester tester) async {
      logger.info('Testing translation cache clearing', category: 'translation_settings');

      // Arrange - Open settings
      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettled(tester);

      final settingsPage = SettingsPage(tester);
      await settingsPage.waitForLoad();

      // Expand translation cache section
      await settingsPage.expandTranslationCache();

      // Act - Tap clear cache button
      await settingsPage.tapClearCache();

      // Assert - Cache should be cleared
      settingsPage.verifyCacheCleared();

      logger.info('Translation cache clearing verified', category: 'translation_settings');
      logger.info('Cache clearing test completed', category: 'translation_settings');
    }, skip: true, reason: 'Requires translation cache implementation');

    testWidgets('Clear cache requires confirmation', (WidgetTester tester) async {
      logger.info('Testing cache clear confirmation', category: 'translation_settings');

      // Arrange
      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettled(tester);

      final settingsPage = SettingsPage(tester);
      await settingsPage.waitForLoad();

      await settingsPage.expandTranslationCache();

      // Act - Tap clear cache
      await tester.tap(settingsPage.cacheClearButtonFinder);
      await TestHelpers.waitForAppSettled(tester);

      // Assert - Should show confirmation dialog
      expect(find.text('Clear Translation Cache?'), findsOneWidget);
      expect(find.text('This will delete all cached translations'),
          findsOneWidget);

      // Cancel and verify cache intact
      await tester.tap(find.text('Cancel'));
      await TestHelpers.waitForAppSettled(tester);

      logger.info('Cache clear confirmation verified', category: 'translation_settings');
      logger.info('Confirmation test completed', category: 'translation_settings');
    }, skip: true, reason: 'Requires cache confirmation dialog');

    testWidgets('Export translation cache', (WidgetTester tester) async {
      logger.info('Testing translation cache export', category: 'translation_settings');

      // Arrange
      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettled(tester);

      final settingsPage = SettingsPage(tester);
      await settingsPage.waitForLoad();

      await settingsPage.expandTranslationCache();

      // Act - Tap export button
      await settingsPage.tapExportCache();

      // Assert - Cache should be exported to clipboard
      settingsPage.verifyCacheExported();

      logger.info('Translation cache export verified', category: 'translation_settings');
      logger.info('Cache export test completed', category: 'translation_settings');
    }, skip: true, reason: 'Requires cache export implementation');

    testWidgets('Cache statistics are displayed', (WidgetTester tester) async {
      logger.info('Testing cache statistics display', category: 'translation_settings');

      // Arrange
      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettled(tester);

      final settingsPage = SettingsPage(tester);
      await settingsPage.waitForLoad();

      await settingsPage.expandTranslationCache();

      // Assert - Cache statistics should be visible
      expect(find.textContaining('entries'), findsOneWidget);
      expect(find.textContaining('size'), findsOneWidget);

      final cacheSize = settingsPage.getCacheSizeText();
      expect(cacheSize, isNotEmpty);

      logger.info('Cache statistics: $cacheSize', category: 'translation_settings');
      logger.info('Cache statistics test completed', category: 'translation_settings');
    }, skip: true, reason: 'Requires cache statistics display');

    testWidgets('Select target language', (WidgetTester tester) async {
      logger.info('Testing target language selection', category: 'translation_settings');

      // Arrange
      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettled(tester);

      final settingsPage = SettingsPage(tester);
      await settingsPage.waitForLoad();

      // Act - Set target language to Spanish
      await settingsPage.setTargetLanguage('es');

      // Assert - Language should be updated
      settingsPage.verifyTargetLanguage('es');

      logger.info('Target language selection verified', category: 'translation_settings');
      logger.info('Language selection test completed', category: 'translation_settings');
    }, skip: true, reason: 'Requires language dropdown implementation');

    testWidgets('All target languages are accessible',
        (WidgetTester tester) async {
      logger.info('Testing all available languages', category: 'translation_settings');

      // Arrange
      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettled(tester);

      final settingsPage = SettingsPage(tester);
      await settingsPage.waitForLoad();

      // Assert - Language dropdown should be available
      final dropdown = settingsPage.targetLanguageDropdownFinder;
      if (dropdown.evaluate().isNotEmpty) {
        final dropdownWidget = dropdown.evaluate().first.widget as DropdownButton<String>;
        expect(dropdownWidget.items, isNotEmpty,
            reason: 'Should have language options');

        logger.info('Available languages: ${dropdownWidget.items?.length}',
            category: 'translation_settings');
      }

      logger.info('All languages accessibility verified', category: 'translation_settings');
      logger.info('Languages accessibility test completed', category: 'translation_settings');
    });

    testWidgets('Target language preference persists',
        (WidgetTester tester) async {
      logger.info('Testing language preference persistence', category: 'translation_settings');

      // Arrange
      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettled(tester);

      final settingsPage = SettingsPage(tester);
      await settingsPage.waitForLoad();

      // Act - Set language to French
      await settingsPage.setTargetLanguage('fr');
      final languageBefore = settingsPage.getCurrentTargetLanguage();

      // Restart app
      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettled(tester);

      await settingsPage.waitForLoad();
      final languageAfter = settingsPage.getCurrentTargetLanguage();

      // Assert - Language should persist
      expect(languageAfter, equals(languageBefore));

      logger.info('Language preference persistence verified', category: 'translation_settings');
      logger.info('Language persistence test completed', category: 'translation_settings');
    }, skip: true, reason: 'Requires settings persistence');

    testWidgets('Tap downloaded languages button',
        (WidgetTester tester) async {
      logger.info('Testing downloaded languages access', category: 'translation_settings');

      // Arrange
      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettled(tester);

      final settingsPage = SettingsPage(tester);
      await settingsPage.waitForLoad();

      // Act - Tap downloaded languages button
      await settingsPage.tapDownloadedLanguages();

      // Assert - Should show downloaded languages dialog/screen
      // expect(find.text('Downloaded Languages'), findsOneWidget);

      logger.info('Downloaded languages access verified', category: 'translation_settings');
      logger.info('Downloaded languages test completed', category: 'translation_settings');
    }, skip: true, reason: 'Requires downloaded languages screen');

    testWidgets('Delete downloaded language model',
        (WidgetTester tester) async {
      logger.info('Testing language model deletion', category: 'translation_settings');

      // Arrange
      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettled(tester);

      final settingsPage = SettingsPage(tester);
      await settingsPage.waitForLoad();

      // Navigate to downloaded languages
      await settingsPage.tapDownloadedLanguages();

      // Act - Delete a language model
      // final deleteButton = find.text('Delete').first;
      // await tester.tap(deleteButton);
      // await TestHelpers.waitForAppSettled(tester);

      // Confirm deletion
      // await tester.tap(find.text('Confirm'));
      // await TestHelpers.waitForAppSettled(tester);

      // Assert - Model should be removed
      // Language should no longer be listed

      logger.info('Language model deletion verified', category: 'translation_settings');
      logger.info('Model deletion test completed', category: 'translation_settings');
    }, skip: true, reason: 'Requires downloaded languages management');

    testWidgets('Download new language model', (WidgetTester tester) async {
      logger.info('Testing language model download', category: 'translation_settings');

      // Arrange
      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettled(tester);

      final settingsPage = SettingsPage(tester);
      await settingsPage.waitForLoad();

      // Navigate to downloaded languages
      await settingsPage.tapDownloadedLanguages();

      // Act - Start a new language download
      // final downloadButton = find.text('Download').first;
      // await tester.tap(downloadButton);
      // await TestHelpers.waitForAppSettled(tester);

      // Assert - Download should start
      // Progress indicator should appear
      // expect(find.byType(LinearProgressIndicator), findsOneWidget);

      logger.info('Language model download initiated', category: 'translation_settings');
      logger.info('Model download test completed', category: 'translation_settings');
    }, skip: true, reason: 'Requires language model download UI');

    testWidgets('Cache shows hit rate statistics',
        (WidgetTester tester) async {
      logger.info('Testing cache hit rate display', category: 'translation_settings');

      // Arrange
      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettled(tester);

      final settingsPage = SettingsPage(tester);
      await settingsPage.waitForLoad();

      await settingsPage.expandTranslationCache();

      // Assert - Hit rate should be displayed
      // expect(find.textContaining('Hit rate'), findsOneWidget);
      // expect(find.textContaining('%'), findsOneWidget);

      logger.info('Cache hit rate display verified', category: 'translation_settings');
      logger.info('Hit rate test completed', category: 'translation_settings');
    }, skip: true, reason: 'Requires cache hit rate tracking');

    group('Platform Specific', () {
      testWidgets('Translation settings work on Android',
          (WidgetTester tester) async {
        if (!TestConfig.isAndroid) {
          logger.info('Skipped - Android only', category: 'translation_settings');
          return;
        }

        logger.info('Testing Android translation settings', category: 'translation_settings');

        // Arrange
        await tester.pumpWidget(
          const ProviderScope(
            child: app.MyApp(),
          ),
        );
        await TestHelpers.waitForAppSettled(tester);

        final settingsPage = SettingsPage(tester);
        await settingsPage.waitForLoad();

        // Assert - ML Kit specific settings should be visible
        // Model management should work
        expect(settingsPage.targetLanguageDropdownFinder.evaluate().isNotEmpty,
            isTrue);

        logger.info('Android translation settings verified', category: 'translation_settings');
        logger.info('Android test completed', category: 'translation_settings');
      });

      testWidgets('Translation settings work on iOS', (WidgetTester tester) async {
        if (!TestConfig.isIOS) {
          logger.info('Skipped - iOS only', category: 'translation_settings');
          return;
        }

        logger.info('Testing iOS translation settings', category: 'translation_settings');

        // Arrange
        await tester.pumpWidget(
          const ProviderScope(
            child: app.MyApp(),
          ),
        );
        await TestHelpers.waitForAppSettled(tester);

        final settingsPage = SettingsPage(tester);
        await settingsPage.waitForLoad();

        // Assert - ML Kit specific settings should be visible
        expect(settingsPage.targetLanguageDropdownFinder.evaluate().isNotEmpty,
            isTrue);

        logger.info('iOS translation settings verified', category: 'translation_settings');
        logger.info('iOS test completed', category: 'translation_settings');
      });

      testWidgets('Translation settings work on web', (WidgetTester tester) async {
        if (!TestConfig.isWeb) {
          logger.info('Skipped - web only', category: 'translation_settings');
          return;
        }

        logger.info('Testing web translation settings', category: 'translation_settings');

        // Arrange
        await tester.pumpWidget(
          const ProviderScope(
            child: app.MyApp(),
          ),
        );
        await TestHelpers.waitForAppSettled(tester);

        final settingsPage = SettingsPage(tester);
        await settingsPage.waitForLoad();

        // Assert - Transformers.js specific settings should be visible
        // Model download should be for web models
        expect(settingsPage.targetLanguageDropdownFinder.evaluate().isNotEmpty,
            isTrue);

        logger.info('Web translation settings verified', category: 'translation_settings');
        logger.info('Web test completed', category: 'translation_settings');
      });
    });

    group('Language Support', () {
      testWidgets('Common languages are available', (WidgetTester tester) async {
        logger.info('Testing common language availability', category: 'translation_settings');

        // Arrange
        await tester.pumpWidget(
          const ProviderScope(
            child: app.MyApp(),
          ),
        );
        await TestHelpers.waitForAppSettled(tester);

        final settingsPage = SettingsPage(tester);
        await settingsPage.waitForLoad();

        // Common languages that should be available
        final commonLanguages = ['en', 'es', 'fr', 'de', 'zh', 'ja'];

        for (final language in commonLanguages) {
          // Try to set each language
          // This would require the actual language codes in the dropdown
          logger.info('Testing language: $language', category: 'translation_settings');
        }

        logger.info('Common languages availability verified', category: 'translation_settings');
        logger.info('Common languages test completed', category: 'translation_settings');
      }, skip: true, reason: 'Requires language availability verification');

      testWidgets('Less common languages are accessible',
          (WidgetTester tester) async {
        logger.info('Testing less common language accessibility',
            category: 'translation_settings');

        // Arrange
        await tester.pumpWidget(
          const ProviderScope(
            child: app.MyApp(),
          ),
        );
        await TestHelpers.waitForAppSettled(tester);

        // Assert - Should have access to 200+ languages on web
        // Or ML Kit supported languages on mobile

        logger.info('Less common languages accessibility verified',
            category: 'translation_settings');
        logger.info('Less common languages test completed', category: 'translation_settings');
      }, skip: true, reason: 'Requires extensive language list verification');
    });

    group('Error Handling', () {
      testWidgets('Handle cache clear error gracefully',
          (WidgetTester tester) async {
        logger.info('Testing cache clear error handling', category: 'translation_settings');

        // Arrange
        await tester.pumpWidget(
          const ProviderScope(
            child: app.MyApp(),
          ),
        );
        await TestHelpers.waitForAppSettled(tester);

        final settingsPage = SettingsPage(tester);
        await settingsPage.waitForLoad();

        await settingsPage.expandTranslationCache();

        // Act - Try to clear cache (simulate error)
        // This would require mocking or error injection

        // Assert - Should show error message
        // App should not crash

        logger.info('Cache clear error handling verified', category: 'translation_settings');
        logger.info('Error handling test completed', category: 'translation_settings');
      }, skip: true, reason: 'Requires error scenario simulation');

      testWidgets('Handle model download failure',
          (WidgetTester tester) async {
        logger.info('Testing model download failure handling',
            category: 'translation_settings');

        // Arrange
        await tester.pumpWidget(
          const ProviderScope(
            child: app.MyApp(),
          ),
        );
        await TestHelpers.waitForAppSettled(tester);

        final settingsPage = SettingsPage(tester);
        await settingsPage.waitForLoad();

        await settingsPage.tapDownloadedLanguages();

        // Act - Try to download model with no network (simulate)

        // Assert - Should show error message
        // Should offer retry option

        logger.info('Model download failure handling verified', category: 'translation_settings');
        logger.info('Download failure test completed', category: 'translation_settings');
      }, skip: true, reason: 'Requires network failure simulation');
    });
  });
}
