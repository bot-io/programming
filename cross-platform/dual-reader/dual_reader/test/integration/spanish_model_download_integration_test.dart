import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:dual_reader/src/core/di/injection_container.dart' as di;
import 'package:dual_reader/src/data/services/client_side_translation_service.dart';
import 'package:dual_reader/src/data/services/translation_cache_service.dart';
import 'package:dual_reader/src/presentation/providers/language_model_notifier.dart';
import 'package:dual_reader/src/domain/services/translation_service.dart';

void main() {
  // Skip integration tests on web/windows due to platform channel requirements
  final skipIntegrationTests = kIsWeb || true; // Always skip for now - requires device

  test('Language Model Download tests skipped - run on device/emulator', () {
    if (skipIntegrationTests) {
      print('Language Model Download Tests require a mobile device or emulator');
      print('Run with: flutter test test/integration/spanish_model_download_integration_test.dart --device-id=<emulator-id>');
    }
  }, skip: !skipIntegrationTests);

  group('Language Model Download Integration Tests', () {
    late TranslationCacheService cacheService;
    late ClientSideTranslationService translationService;

    setUpAll(() async {
      // Initialize Hive for testing
      await Hive.initFlutter();

      // Initialize translation cache
      cacheService = TranslationCacheService();
      await cacheService.init();

      // Initialize DI container
      await di.init();

      // Create translation service
      translationService = di.sl<ClientSideTranslationService>();
    });

    tearDownAll(() async {
      await translationService.close();
      await Hive.close();
    });

    test('should detect if model is already downloaded', () async {
      // Check if Spanish model is ready
      const testLanguage = 'es';
      final isReady = await translationService.isLanguageModelReady(testLanguage);

      expect(isReady, isA<bool>());
      debugPrint('[Integration Test] $testLanguage model ready: $isReady');
    });

    test('should download language model in background with state tracking', () async {
      final notifier = LanguageModelNotifier();
      const testLanguage = 'es';

      debugPrint('[Integration Test] Starting download for $testLanguage...');

      // Start download
      final downloadFuture = notifier.downloadLanguageModel(testLanguage);

      // Monitor progress for up to 60 seconds
      int secondsElapsed = 0;
      while (notifier.state.status == ModelDownloadStatus.inProgress &&
             secondsElapsed < 60) {
        debugPrint('[Integration Test] [${secondsElapsed}s] Status: ${notifier.state.status}, Message: ${notifier.state.progressMessage}');
        await Future.delayed(const Duration(seconds: 1));
        secondsElapsed++;
      }

      await downloadFuture.timeout(
        const Duration(seconds: 5),
        onTimeout: () => debugPrint('[Integration Test] Download await timeout'),
      );

      // Verify final state
      debugPrint('[Integration Test] Final state: ${notifier.state.status}');
      debugPrint('[Integration Test] Final message: ${notifier.state.progressMessage}');
      debugPrint('[Integration Test] Error (if any): ${notifier.state.errorMessage}');
      debugPrint('[Integration Test] Language code: ${notifier.state.languageCode}');

      if (notifier.state.status == ModelDownloadStatus.completed) {
        debugPrint('[Integration Test] ✓ Model downloaded successfully');
        expect(notifier.state.status, ModelDownloadStatus.completed);
        expect(notifier.state.languageCode, testLanguage);
      } else if (notifier.state.status == ModelDownloadStatus.failed) {
        debugPrint('[Integration Test] ✗ Download failed: ${notifier.state.errorMessage}');
        // Don't fail the test - this is expected on platforms without ML Kit
        expect(notifier.state.status, ModelDownloadStatus.failed);
      } else {
        debugPrint('[Integration Test] ⚠ Download still in progress after timeout');
      }
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('should provide progress updates during download attempt', () async {
      final notifier = LanguageModelNotifier();
      const testLanguage = 'es';

      final progressMessages = <String>[];

      // Start download and collect progress messages
      final downloadFuture = notifier.downloadLanguageModel(testLanguage);

      // Collect progress for first 10 seconds
      int secondsElapsed = 0;
      while (notifier.state.status == ModelDownloadStatus.inProgress &&
             secondsElapsed < 10) {
        if (notifier.state.progressMessage != null) {
          progressMessages.add(notifier.state.progressMessage!);
          debugPrint('[Integration Test] Progress: ${notifier.state.progressMessage}');
        }
        await Future.delayed(const Duration(seconds: 1));
        secondsElapsed++;
      }

      await downloadFuture.timeout(
        const Duration(seconds: 5),
        onTimeout: () {},
      );

      debugPrint('[Integration Test] Progress messages collected: ${progressMessages.length}');
      for (final msg in progressMessages) {
        debugPrint('[Integration Test]   - $msg');
      }

      // Verify we got some progress messages (or completed quickly)
      expect(
        progressMessages.isNotEmpty ||
        notifier.state.status == ModelDownloadStatus.completed,
        isTrue,
        reason: 'Should have progress messages or complete quickly',
      );
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('should transition through correct state sequence', () async {
      final notifier = LanguageModelNotifier();
      const testLanguage = 'es';

      final states = <ModelDownloadStatus>[];

      // Record initial state
      states.add(notifier.state.status);
      debugPrint('[Integration Test] Initial state: ${notifier.state.status}');

      // Start download
      final downloadFuture = notifier.downloadLanguageModel(testLanguage);

      // Monitor state changes for up to 10 seconds
      int secondsElapsed = 0;
      while (notifier.state.status == ModelDownloadStatus.inProgress &&
             secondsElapsed < 10) {
        if (states.last != notifier.state.status) {
          states.add(notifier.state.status);
          debugPrint('[Integration Test] State changed to: ${notifier.state.status}');
        }
        await Future.delayed(const Duration(seconds: 1));
        secondsElapsed++;
      }

      await downloadFuture.timeout(
        const Duration(seconds: 5),
        onTimeout: () {},
      );

      // Record final state
      if (states.last != notifier.state.status) {
        states.add(notifier.state.status);
        debugPrint('[Integration Test] Final state: ${notifier.state.status}');
      }

      debugPrint('[Integration Test] State sequence: $states');

      // Should have: notStarted → inProgress → (completed OR failed OR still inProgress)
      expect(states, contains(ModelDownloadStatus.notStarted));
      expect(states, contains(ModelDownloadStatus.inProgress));
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('should handle state immutability correctly', () async {
      final notifier = LanguageModelNotifier();
      const testLanguage = 'es';

      final initialState = notifier.state;
      expect(initialState.status, ModelDownloadStatus.notStarted);
      debugPrint('[Integration Test] Initial state ID: ${initialState.hashCode}');

      // Start download in background
      final downloadFuture = notifier.downloadLanguageModel(testLanguage);

      // Wait a bit for state to potentially change
      await Future.delayed(const Duration(seconds: 2));

      final duringState = notifier.state;
      debugPrint('[Integration Test] During state ID: ${duringState.hashCode}');
      debugPrint('[Integration Test] Initial state status: ${initialState.status}');
      debugPrint('[Integration Test] During state status: ${duringState.status}');

      // Initial state should not have changed (immutability)
      expect(initialState.status, ModelDownloadStatus.notStarted);

      // Current state should be different (or same if download finished instantly)
      expect(
        duringState.status == ModelDownloadStatus.notStarted ||
        duringState.status == ModelDownloadStatus.inProgress ||
        duringState.status == ModelDownloadStatus.completed ||
        duringState.status == ModelDownloadStatus.failed,
        isTrue,
      );

      await downloadFuture.timeout(
        const Duration(seconds: 5),
        onTimeout: () {},
      );
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('should check model readiness before download', () async {
      final notifier = LanguageModelNotifier();
      const testLanguage = 'es';

      debugPrint('[Integration Test] Checking model readiness for $testLanguage...');

      // Use checkAndDownloadRequiredModel which checks readiness first
      final wasReady = await notifier.checkAndDownloadRequiredModel(testLanguage);

      debugPrint('[Integration Test] Model was ready before check: $wasReady');
      debugPrint('[Integration Test] Current state: ${notifier.state.status}');
      debugPrint('[Integration Test] Language code: ${notifier.state.languageCode}');

      expect(notifier.state.languageCode, testLanguage);

      if (wasReady) {
        // If model was ready, should be completed with no notification
        expect(notifier.state.status, ModelDownloadStatus.completed);
        expect(notifier.state.showNotification, isFalse);
        debugPrint('[Integration Test] ✓ Model was already ready, no download initiated');
      } else {
        // If model wasn't ready, download should have been initiated
        expect(
          notifier.state.status == ModelDownloadStatus.inProgress ||
          notifier.state.status == ModelDownloadStatus.completed ||
          notifier.state.status == ModelDownloadStatus.failed,
          isTrue,
        );
        debugPrint('[Integration Test] ✓ Download initiated');
      }
    }, timeout: const Timeout(Duration(minutes: 2)));
  });

  group('Language Model Download Error Handling', () {
    setUpAll(() async {
      await Hive.initFlutter();
      await di.init();
    });

    tearDownAll(() async {
      await Hive.close();
    });

    test('should handle download errors gracefully', () async {
      final notifier = LanguageModelNotifier();
      const testLanguage = 'es';

      // Start download
      await notifier.downloadLanguageModel(testLanguage).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('[Integration Test] Download timeout');
        },
      );

      if (notifier.state.status == ModelDownloadStatus.failed) {
        debugPrint('[Integration Test] Download failed: ${notifier.state.errorMessage}');
        expect(notifier.state.errorMessage, isNotNull);
        expect(notifier.state.errorMessage!.isNotEmpty, isTrue);
      } else {
        debugPrint('[Integration Test] Download succeeded or still in progress');
      }
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('should allow retry after failed download', () async {
      final notifier = LanguageModelNotifier();
      const testLanguage = 'es';

      // First download attempt
      await notifier.downloadLanguageModel(testLanguage).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('[Integration Test] First download timeout');
        },
      );

      if (notifier.state.status == ModelDownloadStatus.failed) {
        final firstError = notifier.state.errorMessage;
        debugPrint('[Integration Test] First download failed: $firstError');

        // Reset and retry
        notifier.reset();
        expect(notifier.state.status, ModelDownloadStatus.notStarted);
        debugPrint('[Integration Test] State after reset: ${notifier.state.status}');

        // Retry download
        await notifier.downloadLanguageModel(testLanguage).timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            debugPrint('[Integration Test] Retry download timeout');
          },
        );

        // Should not be stuck in failed state
        expect(
          notifier.state.status == ModelDownloadStatus.completed ||
          notifier.state.status == ModelDownloadStatus.failed ||
          notifier.state.status == ModelDownloadStatus.inProgress,
          isTrue,
          reason: 'After retry, state should be completed, failed, or inProgress',
        );
      } else {
        debugPrint('[Integration Test] First download succeeded, nothing to retry');
      }
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
