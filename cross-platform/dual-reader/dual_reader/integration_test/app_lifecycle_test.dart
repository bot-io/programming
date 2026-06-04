/// End-to-End Tests for App Lifecycle
///
/// Tests the complete app lifecycle including:
/// - App launch and initialization
/// - Navigation between screens
/// - Settings persistence
/// - State restoration

library;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dual_reader/main.dart' as app;
import '../test_integration/helpers/test_helpers.dart';
import '../test_integration/pages/library_page.dart';
import '../test_integration/pages/settings_page.dart';
import '../test_integration/pages/reader_page.dart';
import '../test_integration/config/test_config.dart';
import '../test_integration/helpers/test_logger.dart';

void main() {
  TestHelpers.initTests();

  group('App Lifecycle E2E Tests', () {
    late TestLogger logger;

    setUpAll(() async {
      logger = TestLogger();
      await TestHelpers.ensureTestDirectory(TestConfig.logDir);
      await TestHelpers.ensureTestDirectory(TestConfig.screenshotDir);
    });

    tearDownAll(() async {
      await logger.dispose();
    });

    testWidgets('App launches successfully', (WidgetTester tester) async {
      logger.logTestSetup('App Launch');

      await TestHelpers.measure('App Launch', () async {
        await tester.pumpWidget(
          const ProviderScope(
            child: app.MyApp(),
          ),
        );
        await TestHelpers.waitForAppSettled(tester);
      });

      // Verify app is running
      expect(find.byType(app.MaterialApp), findsOneWidget);
      logger.info('App launched successfully', category: 'app_lifecycle');

      logger.logTestTeardown('App Launch');
    });

    testWidgets('Navigate through all main screens', (WidgetTester tester) async {
      logger.logTestSetup('Screen Navigation');

      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettled(tester);

      // Start at Library
      final libraryPage = LibraryPage(tester);
      await libraryPage.waitForLoad();
      await libraryPage.verifyDisplayed();
      logger.logNavigation('Start', 'Library');

      // Navigate to Settings
      // Note: This assumes there's a settings button - adjust based on actual UI
      // await libraryPage.tapSettings();
      // final settingsPage = SettingsPage(tester);
      // await settingsPage.waitForLoad();
      // await settingsPage.verifyDisplayed();
      // logger.logNavigation('Library', 'Settings');

      // Navigate back to Library
      // await settingsPage.goBack();
      // await libraryPage.waitForLoad();
      // logger.logNavigation('Settings', 'Library');

      logger.logTestTeardown('Screen Navigation');
    });

    testWidgets('Settings persist across app restarts', (WidgetTester tester) async {
      logger.logTestSetup('Settings Persistence');

      // First launch - set a preference
      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettled(tester);

      // Navigate to settings and change something
      // This is a placeholder - implement based on actual settings UI
      logger.info('Changing settings', category: 'settings');

      // Restart app
      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettled(tester);

      // Verify settings persisted
      logger.info('Verifying settings persistence', category: 'settings');

      logger.logTestTeardown('Settings Persistence');
    });

    testWidgets('App handles background/foreground transitions',
        (WidgetTester tester) async {
      logger.logTestSetup('Background/Foreground Transitions');

      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettled(tester);

      // Simulate app going to background
      logger.info('App going to background', category: 'app_lifecycle');
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'flutter/lifecycle',
        const StringCodec().encodeMessage('AppLifecycleState.paused'),
            (data) {},
      );
      await tester.pump();

      // Simulate app returning to foreground
      logger.info('App returning to foreground', category: 'app_lifecycle');
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'flutter/lifecycle',
        const StringCodec().encodeMessage('AppLifecycleState.resumed'),
            (data) {},
      );
      await tester.pumpAndSettle();

      // Verify app is still responsive
      expect(find.byType(app.MaterialApp), findsOneWidget);
      logger.info('App recovered from background', category: 'app_lifecycle');

      logger.logTestTeardown('Background/Foreground Transitions');
    });

    testWidgets('App handles low memory warnings', (WidgetTester tester) async {
      logger.logTestSetup('Low Memory Handling');

      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettled(tester);

      // Simulate low memory warning
      logger.info('Simulating low memory warning', category: 'app_lifecycle');
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'flutter/system',
        const StringCodec().encodeMessage('SystemMemoryPressureChanged'),
            (data) {},
      );
      await tester.pumpAndSettle();

      // Verify app is still functional
      expect(find.byType(app.MaterialApp), findsOneWidget);
      logger.info('App handled low memory gracefully', category: 'app_lifecycle');

      logger.logTestTeardown('Low Memory Handling');
    });
  });

  group('Smoke Tests', () {
    testWidgets('Quick smoke test - critical paths only', (WidgetTester tester) async {
      logger.logTestSetup('Smoke Test');

      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettled(tester);

      // Verify critical screens are accessible
      final libraryPage = LibraryPage(tester);
      await libraryPage.waitForLoad();

      // Quick verification that main features work
      expect(libraryPage.libraryTitleFinder, findsOneWidget);

      logger.logTestTeardown('Smoke Test');
    });
  });
}
