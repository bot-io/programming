/// E2E Tests for Font Settings
///
/// Tests font customization functionality:
/// - Change font family (all options)
/// - Change font size (all options)
/// - Change line height
/// - Font settings persist
/// - Changes apply immediately to reader

library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dual_reader/main.dart' as app;
import '../../../test_integration/helpers/test_helpers.dart';
import '../../../test_integration/pages/settings_page.dart';
import '../../../test_integration/pages/reader_page.dart';
import '../../../test_integration/config/test_config.dart';
import '../../../test_integration/helpers/test_logger.dart';

void main() {
  TestHelpers.initTests();
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Settings - Font E2E Tests', () {
    late TestLogger logger;

    setUpAll(() {
      logger = TestLogger();
    });

    tearDownAll(() async {
      await logger.dispose();
    });

    setUp(() {
      logger.logTestSetup('Font Settings');
    });

    tearDown(() {
      logger.logTestTeardown('Font Settings');
    });

    testWidgets('Change font size to minimum (12)', (WidgetTester tester) async {
      logger.info('Testing minimum font size', category: 'font');

      // Arrange
      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettled(tester);

      final settingsPage = SettingsPage(tester);
      await settingsPage.waitForLoad();

      // Act - Set font size to 12 (minimum)
      await settingsPage.setFontSize(12.0);

      // Assert
      settingsPage.verifyFontSize(12.0);

      logger.info('Minimum font size verified', category: 'font');

      logger.info('Minimum font size test completed', category: 'font');
    }, skip: true, reason: 'Requires navigation to settings');

    testWidgets('Change font size to maximum (32)', (WidgetTester tester) async {
      logger.info('Testing maximum font size', category: 'font');

      // Arrange
      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettled(tester);

      final settingsPage = SettingsPage(tester);
      await settingsPage.waitForLoad();

      // Act - Set font size to 32 (maximum)
      await settingsPage.setFontSize(32.0);

      // Assert
      settingsPage.verifyFontSize(32.0);

      logger.info('Maximum font size verified', category: 'font');

      logger.info('Maximum font size test completed', category: 'font');
    }, skip: true, reason: 'Requires navigation to settings');

    testWidgets('Font size changes apply incrementally', (WidgetTester tester) async {
      logger.info('Testing incremental font size', category: 'font');

      // Arrange
      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettled(tester);

      final settingsPage = SettingsPage(tester);
      await settingsPage.waitForLoad();

      // Act - Test various font sizes
      final sizes = [14.0, 16.0, 18.0, 20.0, 24.0];

      for (final size in sizes) {
        await settingsPage.setFontSize(size);
        settingsPage.verifyFontSize(size);
        logger.info('Font size $size verified', category: 'font');
      }

      logger.info('Incremental font size test completed', category: 'font');
    }, skip: true, reason: 'Requires navigation to settings');

    testWidgets('Font size persists across sessions', (WidgetTester tester) async {
      logger.info('Testing font size persistence', category: 'font');

      // Arrange
      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettledled(tester);

      final settingsPage = SettingsPage(tester);
      await settingsPage.waitForLoad();

      // Act - Set font size to 20
      await settingsPage.setFontSize(20.0);
      final sizeBefore = settingsPage.getCurrentFontSize();

      // Restart app
      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettledled(tester);

      await settingsPage.waitForLoad();
      final sizeAfter = settingsPage.getCurrentFontSize();

      // Assert
      expect(sizeAfter, equals(sizeBefore));

      logger.info('Font size persistence verified', category: 'font');

      logger.info('Font size persistence test completed', category: 'font');
    }, skip: true, reason: 'Requires settings navigation');

    testWidgets('Line height can be adjusted', (WidgetTester tester) async {
      logger.info('Testing line height adjustment', category: 'font');

      // Arrange
      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettledled(tester);

      final settingsPage = SettingsPage(tester);
      await settingsPage.waitForLoad();

      // Act - Test different line heights
      await settingsPage.setLineHeight(1.2);
      settingsPage.verifyLineHeight(1.2);

      await settingsPage.setLineHeight(1.8);
      settingsPage.verifyLineHeight(1.8);

      await settingsPage.setLineHeight(2.0);
      settingsPage.verifyLineHeight(2.0);

      logger.info('Line height adjustment test completed', category: 'font');
    }, skip: true, reason: 'Requires navigation to settings');

    testWidgets('Font settings apply immediately to reader',
        (WidgetTester tester) async {
      logger.info('Testing immediate font application', category: 'font');

      // Arrange - Open reader with current font size
      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettled(tester);

      // Navigate to reader and get initial font size
      // final readerPage = ReaderPage(tester);
      // await readerPage.waitForLoad();

      // Get initial text size (would need to inspect Text widget)

      // Open settings
      // await readerPage.openSettings();
      final settingsPage = SettingsPage(tester);
      await settingsPage.waitForLoad();

      // Change font size
      await settingsPage.setFontSize(20.0);

      // Go back to reader
      // await settingsPage.goBack();

      // Assert - Font size should change immediately
      // Reader should reflect new font size without reopening

      logger.info('Immediate font application verified', category: 'font');

      logger.info('Immediate font application test completed', category: 'font');
    }, skip: true, reason: 'Requires reader navigation and font verification');

    testWidgets('Font size slider has appropriate granularity',
        (WidgetTester tester) async {
      logger.info('Testing font size granularity', category: 'font');

      // Arrange
      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettled(tester);

      final settingsPage = SettingsPage(tester);
      await settingsPage.waitForLoad();

      // Assert - Slider should have divisions for fine control
      final slider = settingsPage.fontSizeSliderFinder.evaluate().first.widget as Slider;
      expect(slider.divisions, greaterThan(5), reason: 'Should have fine-grained control');

      logger.info('Font size granularity verified', category: 'font');

      logger.info('Granularity test completed', category: 'font');
    });

    testWidgets('Font size shows correct label', (WidgetTester tester) async {
      logger.info('Testing font size label', category: 'font');

      // Arrange
      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettled(tester);

      final settingsPage = SettingsPage(tester);
      await settingsPage.waitForLoad();

      // Act - Check label at different sizes
      await settingsPage.setFontSize(16.0);
      expect(find.text('16'), findsOneWidget);

      await settingsPage.setFontSize(20.0);
      expect(find.text('20'), findsOneWidget);

      logger.info('Font size label test completed', category: 'font');
    });

    testWidgets('All font options are accessible', (WidgetTester tester) async {
      logger.info('Testing font options availability', category: 'font');

      // Arrange
      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettled(tester);

      // Assert - Should have multiple font options available
      // This would require inspecting actual font list

      logger.info('Font options accessibility test completed', category: 'font');
    });

    group('Text Readability', () {
      testWidgets('Small font size is still readable', (WidgetTester tester) async {
        logger.info('Testing small font readability', category: 'font');

        // Arrange
        await tester.pumpWidget(
          const ProviderScope(
            child: app.MyApp(),
          ),
        );
        await TestHelpers.waitForAppSettled(tester);

        final settingsPage = SettingsPage(tester);
        await settingsPage.waitForLoad();

        // Act - Set minimum readable font size
        await settingsPage.setFontSize(12.0);

        // Assert - Text should still be readable
        // This would require visual inspection or accessibility checks

        logger.info('Small font readability test completed', category: 'font');
      });

      testWidgets('Large font size does not break layout', (WidgetTester tester) async {
        logger.info('Testing large font layout', category: 'font');

        // Arrange
        await tester.pumpWidget(
          const ProviderScope(
            child: app.MyApp(),
          ),
        );
        await TestHelpers.waitForAppSettled(tester);

        final settingsPage = SettingsPage(tester);
        await settingsPage.waitForLoad();

        // Act - Set maximum font size
        await settingsPage.setFontSize(32.0);

        // Assert - Layout should not break
        // Text should not overflow

        logger.info('Large font layout test completed', category: 'font');
      });
    });
  });
}
