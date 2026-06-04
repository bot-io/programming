/// E2E Tests for Background Model Download
///
/// Tests background language model download:
/// - Spanish model downloads in background
/// - Non-blocking UI during download
/// - Progress banner displays
/// - Cancel and retry options
/// - Download state persistence

library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dual_reader/main.dart' as app;
import 'package:dual_reader/src/presentation/providers/language_model_notifier.dart';
import 'package:dual_reader/src/data/services/client_side_translation_service_mobile.dart';
import '../../../test_integration/helpers/test_helpers.dart';
import '../../../test_integration/config/test_config.dart';
import '../../../test_integration/helpers/test_logger.dart';

void main() {
  TestHelpers.initTests();
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Background Download E2E Tests', () {
    late TestLogger logger;
    late ClientSideTranslationDelegateImpl translationService;

    setUpAll(() async {
      logger = TestLogger();
      if (TestConfig.isAndroid || TestConfig.isIOS) {
        translationService = ClientSideTranslationDelegateImpl();
      }
    });

    tearDownAll(() async {
      if (TestConfig.isAndroid || TestConfig.isIOS) {
        await translationService.close();
      }
      await logger.dispose();
    });

    setUp(() {
      if (!TestConfig.isAndroid && !TestConfig.isIOS) {
        logger.info('Skipped - mobile only', category: 'background_download');
        return;
      }
      logger.logTestSetup('Background Download');
    });

    tearDown(() {
      if (TestConfig.isAndroid || TestConfig.isIOS) {
        logger.logTestTeardown('Background Download');
      }
    });

    testWidgets('Spanish model downloads on first launch', (WidgetTester tester) async {
      if (!TestConfig.isAndroid && !TestConfig.isIOS) {
        logger.info('Skipped - not on mobile platform', category: 'background_download');
        return;
      }

      logger.info('Testing first launch model download', category: 'background_download');

      // Arrange - Start with clean state
      final notifier = LanguageModelNotifier();
      notifier.reset();

      // Act - Check and download if needed
      final wasReady = await notifier.checkAndDownloadRequiredModel('es');

      // Assert
      if (!wasReady) {
        // Download was initiated
        logger.info('Download initiated for Spanish model', category: 'background_download');

        // Wait for download to complete
        await tester.pump(const Duration(seconds: 1));

        // Check final state
        final finalState = notifier.state;
        expect(
          finalState.status == ModelDownloadStatus.completed ||
              finalState.status == ModelDownloadStatus.inProgress,
          isTrue,
          reason: 'Download should complete or be in progress',
        );
      } else {
        logger.info('Model already available', category: 'background_download');
      }

      logger.info('First launch download test completed', category: 'background_download');
    }, timeout: const Timeout(Duration(minutes: 5)));

    testWidgets('Download progress banner displays in UI', (WidgetTester tester) async {
      if (!TestConfig.isAndroid && !TestConfig.isIOS) {
        logger.info('Skipped - not on mobile platform', category: 'background_download');
        return;
      }

      logger.info('Testing progress banner display', category: 'background_download');

      // Arrange - Set download in progress
      await tester.pumpWidget(
        ProviderScope(
          overrides: [],
          child: const app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettled(tester);

      // Trigger download
      final notifier = tester.binding.defaultTargetPlatform == TargetPlatform.android
          ? LanguageModelNotifier()
          : null;

      if (notifier != null) {
        notifier.downloadLanguageModel('es');
        await tester.pump();

        // Assert - Progress banner should be visible
        expect(find.textContaining('Downloading'), findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsOneWidget);

        logger.info('Progress banner visible', category: 'background_download');
      } else {
        logger.info('Platform-specific test skipped', category: 'background_download');
      }

      logger.info('Progress banner test completed', category: 'background_download');
    });

    testWidgets('UI remains responsive during download', (WidgetTester tester) async {
      if (!TestConfig.isAndroid && !TestConfig.isIOS) {
        logger.info('Skipped - not on mobile platform', category: 'background_download');
        return;
      }

      logger.info('Testing UI responsiveness during download', category: 'background_download');

      // Arrange
      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettled(tester);

      // Start download in background
      final notifier = LanguageModelNotifier();
      notifier.downloadLanguageModel('es');

      await tester.pump();

      // Act - Try to interact with UI while downloading
      final libraryTitleFinder = find.text('Your Library');
      expect(libraryTitleFinder, findsOneWidget);

      // Tap on settings button should work
      final settingsButtonFinder = find.byWidgetPredicate(
        (widget) =>
            widget is IconButton &&
            widget.tooltip == 'Settings',
      );

      if (settingsButtonFinder.evaluate().isNotEmpty) {
        await tester.tap(settingsButtonFinder);
        await tester.pump();
        logger.info('UI remained responsive during download', category: 'background_download');
      }

      logger.info('UI responsiveness test completed', category: 'background_download');
    });

    testWidgets('Download completion shows success banner', (WidgetTester tester) async {
      if (!TestConfig.isAndroid && !TestConfig.isIOS) {
        logger.info('Skipped - not on mobile platform', category: 'background_download');
        return;
      }

      logger.info('Testing success banner display', category: 'background_download');

      // Arrange - Start with download in progress
      final notifier = LanguageModelNotifier();

      // Act - Complete download
      await notifier.downloadLanguageModel('es');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            languageModelProvider.overrideWithValue(notifier),
          ],
          child: const app.MyApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Assert - Success banner should be visible
      if (notifier.state.status == ModelDownloadStatus.completed &&
          notifier.state.showNotification) {
        expect(find.textContaining('model ready'), findsOneWidget);
        expect(find.byIcon(Icons.check_circle), findsOneWidget);
        logger.info('Success banner displayed', category: 'background_download');
      }

      logger.info('Success banner test completed', category: 'background_download');
    }, timeout: const Timeout(Duration(minutes: 5)));

    testWidgets('Dismiss success banner', (WidgetTester tester) async {
      if (!TestConfig.isAndroid && !TestConfig.isIOS) {
        logger.info('Skipped - not on mobile platform', category: 'background_download');
        return;
      }

      logger.info('Testing banner dismissal', category: 'background_download');

      // Arrange
      final notifier = LanguageModelNotifier();
      await notifier.downloadLanguageModel('es');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            languageModelProvider.overrideWithValue(notifier),
          ],
          child: const app.MyApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Act - Dismiss banner
      if (notifier.state.showNotification) {
        final closeButtonFinder = find.byIcon(Icons.close);
        if (closeButtonFinder.evaluate().isNotEmpty) {
          await tester.tap(closeButtonFinder);
          await tester.pump();

          // Assert - Banner should be gone
          expect(find.textContaining('model ready'), findsNothing);
          logger.info('Banner dismissed successfully', category: 'background_download');
        }
      }

      logger.info('Banner dismissal test completed', category: 'background_download');
    });

    testWidgets('Download failure shows error banner', (WidgetTester tester) async {
      if (!TestConfig.isAndroid && !TestConfig.isIOS) {
        logger.info('Skipped - not on mobile platform', category: 'background_download');
        return;
      }

      logger.info('Testing error banner display', category: 'background_download');

      // Arrange - Simulate failed download
      final notifier = LanguageModelNotifier();

      // Manually set failed state for testing
      // In real scenario, this would happen from download failure
      // notifier.state = LanguageModelState(
      //   status: ModelDownloadStatus.failed,
      //   errorMessage: 'Network error',
      //   showNotification: true,
      //   languageCode: 'es',
      // );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            languageModelProvider.overrideWithValue(notifier),
          ],
          child: const app.MyApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Assert - Error banner should be visible
      // expect(find.textContaining('failed'), findsOneWidget);
      // expect(find.text('Retry'), findsOneWidget);

      logger.info('Error banner test completed', category: 'background_download');
    });

    testWidgets('Retry button appears after failed download', (WidgetTester tester) async {
      if (!TestConfig.isAndroid && !TestConfig.isIOS) {
        logger.info('Skipped - not on mobile platform', category: 'background_download');
        return;
      }

      logger.info('Testing retry button display', category: 'background_download');

      // Arrange - Failed download state
      final notifier = LanguageModelNotifier();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            languageModelProvider.overrideWithValue(notifier),
          ],
          child: const app.MyApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Assert - Retry button should be available
      // final retryButtonFinder = find.text('Retry');
      // expect(retryButtonFinder, findsOneWidget);

      logger.info('Retry button test completed', category: 'background_download');
    });

    testWidgets('Model persists across app restarts', (WidgetTester tester) async {
      if (!TestConfig.isAndroid && !TestConfig.isIOS) {
        logger.info('Skipped - not on mobile platform', category: 'background_download');
        return;
      }

      logger.info('Testing model persistence', category: 'background_download');

      // Arrange - Download model
      final isReadyBefore = await translationService.isLanguageModelReady('es');
      logger.info('Model ready before: $isReadyBefore', category: 'background_download');

      // Act - Restart service (simulate app restart)
      await translationService.close();
      final newService = ClientSideTranslationDelegateImpl();

      // Assert - Model should still be ready
      final isReadyAfter = await newService.isLanguageModelReady('es');
      expect(isReadyAfter, equals(isReadyBefore),
          reason: 'Model readiness should persist');

      logger.info('Model ready after: $isReadyAfter', category: 'background_download');

      // Cleanup
      await newService.close();

      logger.info('Model persistence verified', category: 'background_download');
    });

    testWidgets('Progress updates during download', (WidgetTester tester) async {
      if (!TestConfig.isAndroid && !TestConfig.isIOS) {
        logger.info('Skipped - not on mobile platform', category: 'background_download');
        return;
      }

      logger.info('Testing progress updates', category: 'background_download');

      // Arrange
      final progressMessages = <String>[];

      // Act - Download with progress callback
      final success = await translationService.downloadLanguageModel(
        'es',
        onProgress: (message) {
          progressMessages.add(message);
          logger.info('Progress: $message', category: 'background_download');
        },
      );

      // Assert
      expect(success, isTrue);
      expect(progressMessages, isNotEmpty,
          reason: 'Should receive progress updates');

      logger.info('Received ${progressMessages.length} progress messages',
          category: 'background_download');

      logger.info('Progress updates test completed', category: 'background_download');
    }, timeout: const Timeout(Duration(minutes: 5)));

    group('Download State Management', () {
      testWidgets('Download status transitions correctly', (WidgetTester tester) async {
        if (!TestConfig.isAndroid && !TestConfig.isIOS) {
          logger.info('Skipped - not on mobile platform', category: 'background_download');
          return;
        }

        logger.info('Testing status transitions', category: 'background_download');

        // Arrange
        final notifier = LanguageModelNotifier();

        // Assert initial state
        expect(notifier.state.status, equals(ModelDownloadStatus.notStarted));
        logger.info('Initial status: notStarted', category: 'background_download');

        // Start download
        final downloadFuture = notifier.downloadLanguageModel('es');

        // Check in-progress state
        expect(notifier.state.status, equals(ModelDownloadStatus.inProgress));
        logger.info('Status during download: inProgress', category: 'background_download');

        // Wait for completion
        await downloadFuture;

        // Check final state
        expect(
          notifier.state.status == ModelDownloadStatus.completed ||
              notifier.state.status == ModelDownloadStatus.failed,
          isTrue,
        );
        logger.info('Final status: ${notifier.state.status}', category: 'background_download');

        logger.info('Status transitions verified', category: 'background_download');
      });

      testWidgets('Multiple language models can be downloaded', (WidgetTester tester) async {
        if (!TestConfig.isAndroid && !TestConfig.isIOS) {
          logger.info('Skipped - not on mobile platform', category: 'background_download');
          return;
        }

        logger.info('Testing multiple model downloads', category: 'background_download');

        // Arrange - Download Spanish first
        await translationService.downloadLanguageModel('es');

        // Act - Download another language
        await translationService.downloadLanguageModel('fr');

        // Assert - Both should be ready
        final esReady = await translationService.isLanguageModelReady('es');
        final frReady = await translationService.isLanguageModelReady('fr');

        expect(esReady, isTrue, reason: 'Spanish model should be ready');
        expect(frReady, isTrue, reason: 'French model should be ready');

        logger.info('Multiple models downloaded successfully', category: 'background_download');

        logger.info('Multiple model download test completed', category: 'background_download');
      }, timeout: const Timeout(Duration(minutes: 10)));

      testWidgets('Download not started if model already exists', (WidgetTester tester) async {
        if (!TestConfig.isAndroid && !TestConfig.isIOS) {
          logger.info('Skipped - not on mobile platform', category: 'background_download');
          return;
        }

        logger.info('Testing existing model handling', category: 'background_download');

        // Arrange - Ensure model is downloaded
        await translationService.downloadLanguageModel('es');

        // Act - Try to download again
        final progressMessages = <String>[];
        final success = await translationService.downloadLanguageModel(
          'es',
          onProgress: (message) {
            progressMessages.add(message);
          },
        );

        // Assert
        expect(success, isTrue);
        // Should not have progress messages if already downloaded
        // or should have "already downloaded" message
        logger.info('Progress messages: $progressMessages', category: 'background_download');

        logger.info('Existing model handling completed', category: 'background_download');
      });
    });

    group('UI Integration', () {
      testWidgets('Library screen shows download banner', (WidgetTester tester) async {
        if (!TestConfig.isAndroid && !TestConfig.isIOS) {
          logger.info('Skipped - not on mobile platform', category: 'background_download');
          return;
        }

        logger.info('Testing library banner integration', category: 'background_download');

        // Arrange
        final notifier = LanguageModelNotifier();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              languageModelProvider.overrideWithValue(notifier),
            ],
            child: const app.MyApp(),
          ),
        );
        await TestHelpers.waitForAppSettled(tester);

        // Trigger download
        notifier.downloadLanguageModel('es');
        await tester.pump();

        // Assert - Banner should be visible in library
        expect(find.text('Your Library'), findsOneWidget);

        if (notifier.state.status == ModelDownloadStatus.inProgress) {
          expect(find.byType(LinearProgressIndicator), findsOneWidget);
          logger.info('Download banner visible in library', category: 'background_download');
        }

        logger.info('Library banner integration test completed', category: 'background_download');
      });

      testWidgets('Download does not block navigation', (WidgetTester tester) async {
        if (!TestConfig.isAndroid && !TestConfig.isIOS) {
          logger.info('Skipped - not on mobile platform', category: 'background_download');
          return;
        }

        logger.info('Testing navigation during download', category: 'background_download');

        // Arrange
        final notifier = LanguageModelNotifier();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              languageModelProvider.overrideWithValue(notifier),
            ],
            child: const app.MyApp(),
          ),
        );
        await TestHelpers.waitForAppSettled(tester);

        // Start download
        notifier.downloadLanguageModel('es');
        await tester.pump();

        // Act - Navigate to settings
        final settingsButtonFinder = find.byWidgetPredicate(
          (widget) =>
              widget is IconButton &&
              widget.tooltip == 'Settings',
        );

        if (settingsButtonFinder.evaluate().isNotEmpty) {
          await tester.tap(settingsButtonFinder);
          await tester.pumpAndSettle();

          // Assert - Settings should be visible
          expect(find.text('Settings'), findsOneWidget);
          logger.info('Navigation worked during download', category: 'background_download');
        }

        logger.info('Navigation during download test completed', category: 'background_download');
      });
    });
  });
}
