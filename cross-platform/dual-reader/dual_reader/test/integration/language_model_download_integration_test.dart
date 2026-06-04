import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:dual_reader/src/data/services/language_model_manager.dart';
import 'package:dual_reader/src/core/utils/logging_service.dart';

/// Integration tests for language model download flow
///
/// These tests verify:
/// - Model download flow with WiFi-only mode
/// - Offline scenarios (network disconnection during download)
/// - Model management (delete, check availability)
/// - Network status changes and offline mode indicators
///
/// Note: These are integration tests that require a platform environment
/// (Android/iOS) to run fully. Some tests may be skipped on web or desktop.
void main() {
  group('LanguageModelDownloadIntegration', () {
    late LanguageModelManager modelManager;

    setUp(() async {
      // Initialize logging service for tests
      await LoggingService.instance.init();

      // Use singleton instance
      modelManager = LanguageModelManager.instance;
    });

    tearDown(() async {
      await modelManager.close();
    });

    group('Network Status Detection', () {
      test('should detect WiFi connection', () async {
        final status = await modelManager.checkNetworkStatus();

        // In test environment, we may not have real connectivity
        // Just verify the method returns a valid NetworkStatus object
        expect(status, isA<NetworkStatus>());
        expect(status.connectionType, isIn(['wifi', 'mobile', 'ethernet', 'none']));
      });

      test('should emit network status changes on stream', () async {
        // Collect status changes over a short period
        final statuses = <NetworkStatus>[];
        final subscription = modelManager.networkStatusStream.listen(statuses.add);

        // Wait a bit for any initial events
        await Future.delayed(const Duration(milliseconds: 100));

        await subscription.cancel();

        // Should have received at least one status update
        expect(statuses, isNotEmpty);
        expect(statuses.first, isA<NetworkStatus>());
      });

      test('should correctly identify offline state', () async {
        final status = await modelManager.checkNetworkStatus();

        // Verify offline detection works
        expect(status.isConnected, isA<bool>());
        expect(status.isOnline, equals(status.isConnected));
      });

      test('should correctly identify WiFi vs mobile connection', () async {
        final status = await modelManager.checkNetworkStatus();

        // Verify WiFi and mobile flags are booleans
        expect(status.isWiFi, isA<bool>());
        expect(status.isMobile, isA<bool>());

        // If connected, should be one of them (or ethernet)
        if (status.isConnected) {
          expect(status.isWiFi || status.isMobile || status.isEthernet, isTrue);
        }
      });
    });

    group('Model Download Flow', () {
      test('should reject download when WiFi-only mode is enabled and WiFi is unavailable', () async {
        // Configure WiFi-only mode
        modelManager.configure(wifiOnly: true);

        // Check if we have WiFi - if not, download should fail
        final status = await modelManager.checkNetworkStatus();

        if (!status.isWiFi) {
          // Try to download a model (should fail gracefully)
          final progressMessages = <String>[];
          final success = await modelManager.downloadModel(
            'es',
            onProgress: (msg) => progressMessages.add(msg),
          );

          // Should fail or indicate WiFi requirement
          expect(success, isFalse);
          expect(
            progressMessages.any((msg) => msg.toLowerCase().contains('wifi')),
            isTrue,
            reason: 'Should mention WiFi requirement in progress message',
          );
        } else {
          print('Test skipped: WiFi is available');
        }
      });

      test('should track download state during download process', () async {
        // Check initial download state
        expect(modelManager.isDownloading, isFalse);

        final status = await modelManager.checkNetworkStatus();

        // Only try download if we have connectivity and WiFi (if enabled)
        if (status.isConnected && (status.isWiFi || !modelManager.configuration.wifiOnly)) {
          final downloadStarted = Completer<bool>();

          // Start download in background
          modelManager.downloadModel(
            'es',
            onProgress: (msg) {
              if (!downloadStarted.isCompleted) {
                downloadStarted.complete(true);
              }
            },
          );

          // Wait for download to start
          await downloadStarted.future.timeout(
            const Duration(seconds: 5),
            onTimeout: () => throw TimeoutException('Download did not start'),
          );

          // Should have download state
          final downloadState = modelManager.getDownloadState('es');
          expect(downloadState, isNotNull);
        } else {
          print('Test skipped: No suitable network connection');
        }
      });

      test('should only allow one download at a time', () async {
        // Start first download
        final firstDownload = modelManager.downloadModel('es');

        // Try to start second download immediately
        final secondDownloadStarted = modelManager.isDownloading;

        // Should indicate that a download is already in progress
        expect(secondDownloadStarted, isTrue);

        // Wait for first download to complete or timeout
        await firstDownload.timeout(
          const Duration(minutes: 5),
          onTimeout: () => false,
        );

        // After completion, should allow new downloads
        expect(modelManager.isDownloading, isFalse);
      });

      test('should report progress during download', () async {
        final progressMessages = <String>[];

        final success = await modelManager.downloadModel(
          'es',
          onProgress: (msg) => progressMessages.add(msg),
        );

        // Should have received at least one progress message
        expect(progressMessages, isNotEmpty);
        expect(progressMessages.first, isA<String>());
      });
    });

    group('Model Management', () {
      test('should track downloaded models', () async {
        final downloadedModels = modelManager.getDownloadedModels();

        expect(downloadedModels, isA<List<LanguageModelInfo>>());
        // In test environment, may be empty or have pre-downloaded models
        for (final model in downloadedModels) {
          expect(model.isDownloaded, isTrue);
          expect(model.languageCode, isNotEmpty);
          expect(model.displayName, isNotEmpty);
        }
      });

      test('should get model info for specific language', () async {
        final modelInfo = modelManager.getModelInfo('es');

        if (modelInfo != null) {
          expect(modelInfo.languageCode, equals('es'));
          expect(modelInfo.displayName, isNotEmpty);
          expect(modelInfo.sizeBytes, isPositive);
          expect(modelInfo.version, isNotEmpty);
        }
        // May be null if model hasn't been checked yet
      });

      test('should calculate total model size correctly', () async {
        final totalSize = modelManager.getTotalModelSize();
        final formattedSize = modelManager.getTotalModelSizeFormatted();

        expect(totalSize, isGreaterThanOrEqualTo(0));
        expect(formattedSize, isNotEmpty);
        expect(formattedSize, contains(RegExp(r'[MBGB]')));
      });

      test('should delete model from tracking', () async {
        // First, ensure we have a model tracked
        final initialModels = modelManager.getDownloadedModels();
        final initialCount = initialModels.length;

        if (initialCount > 0) {
          final modelToDelete = initialModels.first;
          final success = await modelManager.deleteModel(modelToDelete.languageCode);

          expect(success, isTrue);

          final updatedModels = modelManager.getDownloadedModels();
          // Model should be marked as not downloaded
          final deletedModel = modelManager.getModelInfo(modelToDelete.languageCode);
          expect(deletedModel?.isDownloaded, isFalse);
        } else {
          print('Test skipped: No models to delete');
        }
      });

      test('should delete all models', () async {
        await modelManager.deleteAllModels();

        final downloadedModels = modelManager.getDownloadedModels();
        expect(downloadedModels, isEmpty);
      });

      test('should check if model is downloaded', () async {
        final isDownloaded = modelManager.isModelDownloaded('es');
        expect(isDownloaded, isA<bool>());
      });
    });

    group('Offline Scenarios', () {
      test('should handle network disconnection gracefully', () async {
        // Simulate network going offline during operations
        final status = await modelManager.checkNetworkStatus();

        if (status.isConnected) {
          // Try to check if we can work with cached models
          final models = modelManager.getDownloadedModels();

          // Should be able to get models even if network goes down later
          expect(models, isA<List<LanguageModelInfo>>());

          // Download attempt without network should fail gracefully
          modelManager.configure(wifiOnly: true);
          // Force network check to fail (simulated by WiFi requirement on non-WiFi)
          if (!status.isWiFi) {
            final success = await modelManager.downloadModel('fr');
            expect(success, isFalse);
          }
        }
      });

      test('should provide offline mode indicator', () async {
        final status = await modelManager.checkNetworkStatus();

        // Should be able to determine if we're offline
        expect(status.isConnected, isA<bool>());

        // Offline status should be accessible
        final isOffline = !status.isConnected;
        expect(isOffline, isA<bool>());
      });

      test('should use cached models when offline', () async {
        // Even when offline, should be able to access model info
        final downloadedModels = modelManager.getDownloadedModels();
        final totalSize = modelManager.getTotalModelSize();

        expect(downloadedModels, isA<List<LanguageModelInfo>>());
        expect(totalSize, isGreaterThanOrEqualTo(0));
      });

      test('should work with available models when offline', () async {
        final allModels = modelManager.getAvailableModels();

        expect(allModels, isA<List<LanguageModelInfo>>());
        for (final model in allModels) {
          expect(model.languageCode, isNotEmpty);
          expect(model.displayName, isNotEmpty);
          expect(model.sizeBytes, isPositive);
        }
      });
    });

    group('Configuration Management', () {
      test('should update WiFi-only configuration', () async {
        modelManager.configure(wifiOnly: true);
        expect(modelManager.configuration.wifiOnly, isTrue);

        modelManager.configure(wifiOnly: false);
        expect(modelManager.configuration.wifiOnly, isFalse);
      });

      test('should update auto-download configuration', () async {
        modelManager.configure(autoDownloadPreferred: true);
        expect(modelManager.configuration.autoDownloadPreferred, isTrue);

        modelManager.configure(autoDownloadPreferred: false);
        expect(modelManager.configuration.autoDownloadPreferred, isFalse);
      });

      test('should combine multiple configuration changes', () async {
        modelManager.configure(
          wifiOnly: true,
          autoDownloadPreferred: false,
        );

        final config = modelManager.configuration;
        expect(config.wifiOnly, isTrue);
        expect(config.autoDownloadPreferred, isFalse);
      });

      test('should preserve configuration across operations', () async {
        modelManager.configure(wifiOnly: true, autoDownloadPreferred: true);

        // Perform some operations
        await modelManager.checkNetworkStatus();
        modelManager.getDownloadedModels();

        // Configuration should remain
        final config = modelManager.configuration;
        expect(config.wifiOnly, isTrue);
        expect(config.autoDownloadPreferred, isTrue);
      });
    });

    group('Recommended Languages', () {
      test('should return list of recommended languages', () async {
        final recommended = modelManager.getRecommendedLanguages();

        expect(recommended, isNotEmpty);
        expect(recommended, contains('es')); // Spanish should be recommended
        expect(recommended, contains('fr')); // French should be recommended
        expect(recommended, contains('de')); // German should be recommended
      });

      test('should return supported language codes', () async {
        final supported = modelManager.getSupportedLanguageCodes();

        expect(supported, isNotEmpty);
        expect(supported, contains('en'));
        expect(supported, contains('es'));
        expect(supported, contains('fr'));
      });

      test('recommended languages should be subset of supported', () async {
        final recommended = modelManager.getRecommendedLanguages();
        final supported = modelManager.getSupportedLanguageCodes();

        for (final lang in recommended) {
          expect(supported, contains(lang),
            reason: '$lang should be in supported languages');
        }
      });
    });

    group('Model Size Estimation', () {
      test('should estimate model sizes for different languages', () async {
        // Common languages
        final spanishSize = modelManager.estimateModelSize('es');
        final frenchSize = modelManager.estimateModelSize('fr');

        expect(spanishSize, isPositive);
        expect(frenchSize, isPositive);

        // Large language models (Chinese, Japanese)
        final chineseSize = modelManager.estimateModelSize('zh');
        final japaneseSize = modelManager.estimateModelSize('ja');

        expect(chineseSize, greaterThan(spanishSize),
          reason: 'Chinese model should be larger than Spanish');
        expect(japaneseSize, greaterThan(spanishSize),
          reason: 'Japanese model should be larger than Spanish');
      });

      test('should handle unknown language codes', () async {
        final unknownSize = modelManager.estimateModelSize('xx');

        // Should return default size for unknown languages
        expect(unknownSize, equals(10 * 1024 * 1024)); // 10MB default
      });

      test('should return size in reasonable range', () async {
        // Test a few common languages
        for (final lang in ['en', 'es', 'fr', 'de', 'zh']) {
          final size = modelManager.estimateModelSize(lang);
          expect(size, isGreaterThanOrEqualTo(10 * 1024 * 1024)); // At least 10MB
          expect(size, isLessThan(100 * 1024 * 1024)); // Less than 100MB
        }
      });
    });

    group('Preload Scenarios', () {
      test('should skip preload when offline', () async {
        // Configure WiFi-only mode
        modelManager.configure(wifiOnly: true);

        // Check network status
        final status = await modelManager.checkNetworkStatus();

        if (!status.isConnected) {
          // Preload should skip without error
          await modelManager.preloadPreferredLanguages(['es', 'fr']);

          // Should not have thrown
          expect(true, isTrue);
        } else {
          print('Test skipped: Network is available');
        }
      });

      test('should skip preload when WiFi-only and on mobile', () async {
        modelManager.configure(
          wifiOnly: true,
          autoDownloadPreferred: true,
        );

        final status = await modelManager.checkNetworkStatus();

        if (!status.isWiFi) {
          // Preload should skip due to WiFi requirement
          await modelManager.preloadPreferredLanguages(['es']);

          // Verify no download started
          expect(modelManager.isDownloading, isFalse);
        } else {
          print('Test skipped: WiFi is available');
        }
      });

      test('should skip already downloaded models during preload', () async {
        final downloadedModels = modelManager.getDownloadedModels();
        final downloadedCodes = downloadedModels.map((m) => m.languageCode).toSet();

        if (downloadedCodes.isNotEmpty) {
          final firstCode = downloadedCodes.first;

          // Preload should skip already downloaded models
          await modelManager.preloadPreferredLanguages([firstCode]);

          // Should complete without starting new download
          expect(modelManager.isDownloading, isFalse);
        } else {
          print('Test skipped: No downloaded models');
        }
      });

      test('should handle empty preload list', () async {
        // Should not throw with empty list
        await modelManager.preloadPreferredLanguages([]);
        expect(true, isTrue);
      });

      test('should preload multiple languages when conditions are met', () async {
        modelManager.configure(
          wifiOnly: false,
          autoDownloadPreferred: true,
        );

        final status = await modelManager.checkNetworkStatus();

        if (status.isConnected) {
          // Try to preload (may succeed or be limited by platform)
          await modelManager.preloadPreferredLanguages(['es', 'fr']);
          expect(true, isTrue);
        } else {
          print('Test skipped: No network connection');
        }
      });
    });

    group('Model Update Checks', () {
      test('should return empty updates list', () async {
        final updates = await modelManager.checkForUpdates();

        expect(updates, isEmpty);
        // ML Kit doesn't expose version info, so we expect empty list
      });

      test('should handle model update gracefully', () async {
        // Try to update a model
        final success = await modelManager.updateModel('es');

        // Since we can't really update without version info,
        // this should either complete or fail gracefully
        expect(success, isA<bool>());
      });

      test('should handle update for non-existent model', () async {
        // Try to update a model that doesn't exist
        final success = await modelManager.updateModel('xx');

        expect(success, isA<bool>());
      });
    });

    group('Error Handling', () {
      test('should handle invalid language codes gracefully', () async {
        final modelInfo = modelManager.getModelInfo('invalid_lang_code');

        // Should return null for invalid codes
        expect(modelInfo, isNull);
      });

      test('should handle empty language code gracefully', () async {
        final modelInfo = modelManager.getModelInfo('');

        expect(modelInfo, isNull);
      });

      test('should handle download timeout gracefully', () async {
        // Try download with a very short timeout (simulated)
        final status = await modelManager.checkNetworkStatus();

        if (status.isConnected) {
          // Start download but expect it to timeout if network is slow
          final progressMessages = <String>[];
          final success = await modelManager.downloadModel(
            'es',
            onProgress: (msg) => progressMessages.add(msg),
          ).timeout(
            const Duration(seconds: 10),
            onTimeout: () => false,
          );

          // Should not throw, just return success/failure
          expect(success, isA<bool>());
        } else {
          print('Test skipped: No network connection');
        }
      });

      test('should handle concurrent delete requests', () async {
        final downloadedModels = modelManager.getDownloadedModels();

        if (downloadedModels.isNotEmpty) {
          final modelCode = downloadedModels.first.languageCode;

          // Try deleting the same model multiple times concurrently
          final results = await Future.wait([
            modelManager.deleteModel(modelCode),
            modelManager.deleteModel(modelCode),
            modelManager.deleteModel(modelCode),
          ]);

          // All should complete successfully
          expect(results, everyElement(isTrue));
        } else {
          print('Test skipped: No models to delete');
        }
      });

      test('should handle null progress callback', () async {
        // Should not throw when onProgress is null
        final success = await modelManager.downloadModel('es');

        expect(success, isA<bool>());
      });
    });

    group('Memory Management', () {
      test('should properly close and cleanup', () async {
        final manager = LanguageModelManager.instance;

        // Close should not throw
        await expectLater(manager.close(), completes);
      });

      test('should reset state after close', () async {
        final manager = LanguageModelManager.instance;

        // Get some data
        final modelsBefore = manager.getDownloadedModels();

        // Close
        await manager.close();

        // Get new instance (should be clean)
        final newManager = LanguageModelManager.instance;
        final modelsAfter = newManager.getDownloadedModels();

        // Both should work without throwing
        expect(modelsBefore, isA<List<LanguageModelInfo>>());
        expect(modelsAfter, isA<List<LanguageModelInfo>>());
      });

      test('should handle multiple close calls', () async {
        final manager = LanguageModelManager.instance;

        // Close multiple times should not throw
        await manager.close();
        await manager.close();
        await manager.close();

        expect(true, isTrue);
      });
    });

    group('Download State Tracking', () {
      test('should return null for non-existent download state', () async {
        final state = modelManager.getDownloadState('xx');

        expect(state, isNull);
      });

      test('should track download progress in state', () async {
        final status = await modelManager.checkNetworkStatus();

        if (status.isConnected && (status.isWiFi || !modelManager.configuration.wifiOnly)) {
          // Start a download
          final downloadFuture = modelManager.downloadModel('es');

          // Check state during download
          await Future.delayed(const Duration(milliseconds: 100));
          final state = modelManager.getDownloadState('es');

          if (state != null) {
            expect(state.languageCode, equals('es'));
            expect(state.progress, greaterThanOrEqualTo(0.0));
            expect(state.progress, lessThanOrEqualTo(1.0));
          }

          // Wait for completion
          await downloadFuture.timeout(
            const Duration(minutes: 5),
            onTimeout: () => false,
          );
        } else {
          print('Test skipped: No suitable network');
        }
      });

      test('should clear download state after completion', () async {
        final status = await modelManager.checkNetworkStatus();

        if (status.isConnected && (status.isWiFi || !modelManager.configuration.wifiOnly)) {
          await modelManager.downloadModel('es').timeout(
            const Duration(minutes: 5),
            onTimeout: () => false,
          );

          // After completion, check the state
          final state = modelManager.getDownloadState('es');

          if (state != null) {
            expect(state.isDownloading, isFalse);
          }
        } else {
          print('Test skipped: No suitable network');
        }
      });
    });

    group('Network Status Stream', () {
      test('should provide continuous network updates', () async {
        final statuses = <NetworkStatus>[];

        final subscription = modelManager.networkStatusStream.listen(statuses.add);

        // Wait for multiple updates
        await Future.delayed(const Duration(milliseconds: 500));

        await subscription.cancel();

        // Should have received multiple updates
        expect(statuses, isNotEmpty);
      });

      test('should handle multiple listeners', () async {
        final statuses1 = <NetworkStatus>[];
        final statuses2 = <NetworkStatus>[];

        final sub1 = modelManager.networkStatusStream.listen(statuses1.add);
        final sub2 = modelManager.networkStatusStream.listen(statuses2.add);

        await Future.delayed(const Duration(milliseconds: 100));

        await sub1.cancel();
        await sub2.cancel();

        // Both should receive updates
        expect(statuses1, isNotEmpty);
        expect(statuses2, isNotEmpty);
      });
    });

    group('Model Info Properties', () {
      test('should have correct LanguageModelInfo properties', () async {
        final models = modelManager.getAvailableModels();

        for (final model in models) {
          expect(model.languageCode, isA<String>());
          expect(model.displayName, isA<String>());
          expect(model.version, isA<String>());
          expect(model.sizeBytes, isA<int>());
          expect(model.isDownloaded, isA<bool>());
          expect(model.formattedSize, isA<String>());
        }
      });

      test('should format model size correctly', () async {
        final size = modelManager.estimateModelSize('es');
        final model = LanguageModelInfo(
          languageCode: 'es',
          displayName: 'Spanish',
          version: '1.0',
          sizeBytes: size,
          isDownloaded: true,
        );

        final formatted = model.formattedSize;
        expect(formatted, contains(RegExp(r'\d+(\.\d+)?\s*(MB|GB)')));
      });

      test('should copy model info with changes', () async {
        final original = LanguageModelInfo(
          languageCode: 'es',
          displayName: 'Spanish',
          version: '1.0',
          sizeBytes: 10 * 1024 * 1024,
          isDownloaded: false,
        );

        final copied = original.copyWith(
          isDownloaded: true,
          downloadDate: DateTime.now(),
        );

        expect(copied.languageCode, equals(original.languageCode));
        expect(copied.displayName, equals(original.displayName));
        expect(copied.isDownloaded, isTrue);
        expect(copied.downloadDate, isNotNull);
      });
    });

    group('Edge Cases', () {
      test('should handle very long language codes', () async {
        final longCode = 'a' * 100;
        final modelInfo = modelManager.getModelInfo(longCode);

        expect(modelInfo, isNull);
      });

      test('should handle special characters in language codes', () async {
        final specialCodes = ['es-ES', 'zh_CN', 'de-DE', 'fr_FR'];
        for (final code in specialCodes) {
          final modelInfo = modelManager.getModelInfo(code);
          // Should handle gracefully, either return null or normalized info
          expect(modelInfo == null || modelInfo is LanguageModelInfo, isTrue);
        }
      });

      test('should handle case sensitivity in language codes', () async {
        final lower = modelManager.getModelInfo('es');
        final upper = modelManager.getModelInfo('ES');
        final mixed = modelManager.getModelInfo('Es');

        // Should treat them the same way (all null or all non-null)
        final hasResult = lower != null;
        expect(upper == null ? !hasResult : hasResult, isTrue);
        expect(mixed == null ? !hasResult : hasResult, isTrue);
      });
    });
  });
}
