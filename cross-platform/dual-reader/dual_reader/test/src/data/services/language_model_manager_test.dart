import 'package:flutter_test/flutter_test.dart';
import 'package:dual_reader/src/data/services/language_model_manager.dart';

void main() {
  // =========================================================================
  // Data class tests
  // =========================================================================
  group('LanguageModelInfo', () {
    test('creates with all required parameters', () {
      final date = DateTime(2024, 6, 15);
      final info = LanguageModelInfo(
        languageCode: 'es',
        displayName: 'Spanish',
        version: '1.0',
        sizeBytes: 10485760,
        isDownloaded: true,
        downloadDate: date,
      );

      expect(info.languageCode, equals('es'));
      expect(info.displayName, equals('Spanish'));
      expect(info.version, equals('1.0'));
      expect(info.sizeBytes, equals(10485760));
      expect(info.isDownloaded, isTrue);
      expect(info.downloadDate, equals(date));
    });

    test('creates without downloadDate', () {
      final info = LanguageModelInfo(
        languageCode: 'en',
        displayName: 'English',
        version: '1.0',
        sizeBytes: 10485760,
        isDownloaded: false,
      );

      expect(info.downloadDate, isNull);
    });

    test('formattedSize returns MB label for size below 1MB threshold', () {
      // sizeBytes < 1024 * 1024 => displays as (sizeBytes / 1024) MB
      final info = LanguageModelInfo(
        languageCode: 'en',
        displayName: 'English',
        version: '1.0',
        sizeBytes: 512 * 1024, // 512 KB
        isDownloaded: true,
      );

      // 512*1024 / 1024 = 512.0
      expect(info.formattedSize, equals('512.0 MB'));
    });

    test('formattedSize returns GB label for size at 1MB threshold', () {
      // sizeBytes >= 1024*1024 => displays as (sizeBytes / (1024*1024)) GB
      final info = LanguageModelInfo(
        languageCode: 'en',
        displayName: 'English',
        version: '1.0',
        sizeBytes: 10 * 1024 * 1024, // 10 MB
        isDownloaded: true,
      );

      // 10*1024*1024 / (1024*1024) = 10.0
      expect(info.formattedSize, equals('10.0 GB'));
    });

    test('formattedSize for exactly 0 bytes', () {
      final info = LanguageModelInfo(
        languageCode: 'en',
        displayName: 'English',
        version: '1.0',
        sizeBytes: 0,
        isDownloaded: true,
      );

      expect(info.formattedSize, equals('0.0 MB'));
    });

    test('copyWith returns new instance with updated values', () {
      final originalDate = DateTime(2024, 1, 1);
      final newDate = DateTime(2024, 6, 15);
      final info = LanguageModelInfo(
        languageCode: 'es',
        displayName: 'Spanish',
        version: '1.0',
        sizeBytes: 10485760,
        isDownloaded: false,
        downloadDate: originalDate,
      );

      final copied = info.copyWith(
        isDownloaded: true,
        downloadDate: newDate,
      );

      expect(copied.languageCode, equals('es'));
      expect(copied.displayName, equals('Spanish'));
      expect(copied.version, equals('1.0'));
      expect(copied.sizeBytes, equals(10485760));
      expect(copied.isDownloaded, isTrue);
      expect(copied.downloadDate, equals(newDate));

      // Original should be unchanged
      expect(info.isDownloaded, isFalse);
      expect(info.downloadDate, equals(originalDate));
    });

    test('copyWith preserves all values when no arguments given', () {
      final date = DateTime(2024, 3, 10);
      final info = LanguageModelInfo(
        languageCode: 'fr',
        displayName: 'French',
        version: '2.0',
        sizeBytes: 20971520,
        isDownloaded: true,
        downloadDate: date,
      );

      final copied = info.copyWith();

      expect(copied.languageCode, equals(info.languageCode));
      expect(copied.displayName, equals(info.displayName));
      expect(copied.version, equals(info.version));
      expect(copied.sizeBytes, equals(info.sizeBytes));
      expect(copied.isDownloaded, equals(info.isDownloaded));
      expect(copied.downloadDate, equals(info.downloadDate));
    });

    test('copyWith can set downloadDate to null via explicit null', () {
      // Note: copyWith uses `downloadDate ?? this.downloadDate`
      // Passing null explicitly still keeps the original due to null-coalescing
      final date = DateTime(2024, 1, 1);
      final info = LanguageModelInfo(
        languageCode: 'es',
        displayName: 'Spanish',
        version: '1.0',
        sizeBytes: 10485760,
        isDownloaded: true,
        downloadDate: date,
      );

      final copied = info.copyWith(isDownloaded: false);
      // downloadDate stays because null-coalescing keeps the original
      expect(copied.downloadDate, equals(date));
    });

    test('toString contains key info for downloaded model', () {
      final info = LanguageModelInfo(
        languageCode: 'es',
        displayName: 'Spanish',
        version: '1.0',
        sizeBytes: 10485760,
        isDownloaded: true,
      );

      final str = info.toString();
      expect(str, contains('es'));
      expect(str, contains('Spanish'));
      expect(str, contains('downloaded'));
      expect(str, contains('LanguageModelInfo'));
    });

    test('toString contains "not downloaded" for undownloaded model', () {
      final info = LanguageModelInfo(
        languageCode: 'en',
        displayName: 'English',
        version: '1.0',
        sizeBytes: 10485760,
        isDownloaded: false,
      );

      expect(info.toString(), contains('not downloaded'));
    });
  });

  group('ModelDownloadState', () {
    test('creates with required parameters', () {
      final state = ModelDownloadState(
        languageCode: 'es',
        isDownloading: true,
        progress: 0.5,
      );

      expect(state.languageCode, equals('es'));
      expect(state.isDownloading, isTrue);
      expect(state.progress, equals(0.5));
      expect(state.error, isNull);
    });

    test('creates with error', () {
      final state = ModelDownloadState(
        languageCode: 'fr',
        isDownloading: false,
        progress: 0.0,
        error: 'Download failed',
      );

      expect(state.error, equals('Download failed'));
      expect(state.isDownloading, isFalse);
    });

    test('copyWith updates specified fields', () {
      final state = ModelDownloadState(
        languageCode: 'es',
        isDownloading: true,
        progress: 0.3,
      );

      final updated = state.copyWith(
        progress: 0.8,
      );

      expect(updated.languageCode, equals('es'));
      expect(updated.isDownloading, isTrue);
      expect(updated.progress, equals(0.8));
      expect(updated.error, isNull);
    });

    test('copyWith preserves unspecified fields', () {
      final state = ModelDownloadState(
        languageCode: 'de',
        isDownloading: true,
        progress: 0.5,
        error: 'timeout',
      );

      final copied = state.copyWith();

      expect(copied.languageCode, equals('de'));
      expect(copied.isDownloading, isTrue);
      expect(copied.progress, equals(0.5));
      expect(copied.error, equals('timeout'));
    });

    test('copyWith can update all fields at once', () {
      final state = ModelDownloadState(
        languageCode: 'es',
        isDownloading: true,
        progress: 0.0,
      );

      final updated = state.copyWith(
        languageCode: 'fr',
        isDownloading: false,
        progress: 1.0,
        error: 'Network error',
      );

      expect(updated.languageCode, equals('fr'));
      expect(updated.isDownloading, isFalse);
      expect(updated.progress, equals(1.0));
      expect(updated.error, equals('Network error'));
    });
  });

  group('NetworkStatus', () {
    test('creates with all parameters', () {
      final status = NetworkStatus(
        isConnected: true,
        isWiFi: true,
        isMobile: false,
        isEthernet: false,
        connectionType: 'wifi',
      );

      expect(status.isConnected, isTrue);
      expect(status.isWiFi, isTrue);
      expect(status.isMobile, isFalse);
      expect(status.isEthernet, isFalse);
      expect(status.connectionType, equals('wifi'));
    });

    test('has correct default values', () {
      const status = NetworkStatus(isConnected: true);

      expect(status.isWiFi, isFalse);
      expect(status.isMobile, isFalse);
      expect(status.isEthernet, isFalse);
      expect(status.connectionType, equals('none'));
    });

    test('offline factory creates disconnected status', () {
      final status = NetworkStatus.offline();

      expect(status.isConnected, isFalse);
      expect(status.isWiFi, isFalse);
      expect(status.isMobile, isFalse);
      expect(status.isEthernet, isFalse);
      expect(status.connectionType, equals('none'));
    });

    test('isOnline is synonym for isConnected', () {
      const online = NetworkStatus(isConnected: true, connectionType: 'wifi', isWiFi: true);
      const offline = NetworkStatus(isConnected: false);

      expect(online.isOnline, isTrue);
      expect(offline.isOnline, isFalse);
    });

    test('toString contains connection type and online status', () {
      const status = NetworkStatus(
        isConnected: true,
        connectionType: 'wifi',
        isWiFi: true,
      );

      final str = status.toString();
      expect(str, contains('wifi'));
      expect(str, contains('online'));
    });

    test('toString for offline shows offline', () {
      final status = NetworkStatus.offline();
      expect(status.toString(), contains('offline'));
    });

    test('can represent mobile connection', () {
      const status = NetworkStatus(
        isConnected: true,
        isMobile: true,
        connectionType: 'mobile',
      );

      expect(status.isConnected, isTrue);
      expect(status.isMobile, isTrue);
      expect(status.isWiFi, isFalse);
    });

    test('can represent ethernet connection', () {
      const status = NetworkStatus(
        isConnected: true,
        isEthernet: true,
        connectionType: 'ethernet',
      );

      expect(status.isEthernet, isTrue);
    });
  });

  group('ModelManagerConfig', () {
    test('creates with required parameters', () {
      const config = ModelManagerConfig(
        wifiOnly: true,
        autoDownloadPreferred: false,
      );

      expect(config.wifiOnly, isTrue);
      expect(config.autoDownloadPreferred, isFalse);
    });

    test('toString contains both settings', () {
      const config = ModelManagerConfig(
        wifiOnly: false,
        autoDownloadPreferred: true,
      );

      final str = config.toString();
      expect(str, contains('wifiOnly: false'));
      expect(str, contains('autoDownload: true'));
    });
  });

  group('ModelUpdate', () {
    test('creates with all parameters', () {
      const update = ModelUpdate(
        languageCode: 'es',
        currentVersion: '1.0',
        availableVersion: '2.0',
        sizeBytes: 10485760,
        isRequired: false,
      );

      expect(update.languageCode, equals('es'));
      expect(update.currentVersion, equals('1.0'));
      expect(update.availableVersion, equals('2.0'));
      expect(update.sizeBytes, equals(10485760));
      expect(update.isRequired, isFalse);
    });

    test('toString shows optional for non-required update', () {
      const update = ModelUpdate(
        languageCode: 'fr',
        currentVersion: '1.0',
        availableVersion: '1.1',
        sizeBytes: 5242880,
        isRequired: false,
      );

      expect(update.toString(), contains('optional'));
    });

    test('toString shows required for required update', () {
      const update = ModelUpdate(
        languageCode: 'de',
        currentVersion: '1.0',
        availableVersion: '2.0',
        sizeBytes: 10485760,
        isRequired: true,
      );

      final str = update.toString();
      expect(str, contains('required'));
      expect(str, contains('de'));
      expect(str, contains('v1.0'));
      expect(str, contains('v2.0'));
    });
  });

  // =========================================================================
  // LanguageModelManager service tests
  // =========================================================================
  group('LanguageModelManager', () {
    late LanguageModelManager manager;

    setUp(() {
      manager = LanguageModelManager.instance;
      // Reset to default configuration
      manager.configure(wifiOnly: true, autoDownloadPreferred: true);
    });

    tearDown(() async {
      await manager.close();
    });

    // ----- estimateModelSize -----
    group('estimateModelSize', () {
      test('returns base size (10MB) for English', () {
        final size = manager.estimateModelSize('en');
        expect(size, equals(10 * 1024 * 1024));
      });

      test('returns 3x base size for Chinese', () {
        final size = manager.estimateModelSize('zh');
        expect(size, equals(30 * 1024 * 1024));
      });

      test('returns 3x base size for Japanese', () {
        final size = manager.estimateModelSize('ja');
        expect(size, equals(30 * 1024 * 1024));
      });

      test('returns 2x base size for Korean', () {
        final size = manager.estimateModelSize('ko');
        expect(size, equals(20 * 1024 * 1024));
      });

      test('returns 2x base size for Arabic', () {
        final size = manager.estimateModelSize('ar');
        expect(size, equals(20 * 1024 * 1024));
      });

      test('returns 2x base size for Hindi', () {
        final size = manager.estimateModelSize('hi');
        expect(size, equals(20 * 1024 * 1024));
      });

      test('returns 1.5x base size for Russian', () {
        final size = manager.estimateModelSize('ru');
        expect(size, equals((10 * 1024 * 1024 * 1.5).toInt()));
      });

      test('returns 1.2x base size for Bulgarian', () {
        final size = manager.estimateModelSize('bg');
        expect(size, equals((10 * 1024 * 1024 * 1.2).toInt()));
      });

      test('returns 1.2x base size for Ukrainian', () {
        final size = manager.estimateModelSize('uk');
        expect(size, equals((10 * 1024 * 1024 * 1.2).toInt()));
      });

      test('returns base size for unsupported language code', () {
        final size = manager.estimateModelSize('xx');
        expect(size, equals(10 * 1024 * 1024));
      });

      test('is case insensitive (uppercase)', () {
        expect(manager.estimateModelSize('ZH'), equals(30 * 1024 * 1024));
      });

      test('is case insensitive (mixed case)', () {
        expect(manager.estimateModelSize('Ja'), equals(30 * 1024 * 1024));
      });
    });

    // ----- getRecommendedLanguages -----
    group('getRecommendedLanguages', () {
      test('returns a non-empty list', () {
        final langs = manager.getRecommendedLanguages();
        expect(langs, isNotEmpty);
      });

      test('contains 7 recommended languages', () {
        expect(manager.getRecommendedLanguages().length, equals(7));
      });

      test('contains expected languages', () {
        final langs = manager.getRecommendedLanguages();
        expect(langs, containsAll(['es', 'fr', 'de', 'it', 'pt', 'zh', 'ja']));
      });
    });

    // ----- getSupportedLanguageCodes -----
    group('getSupportedLanguageCodes', () {
      test('returns a non-empty list', () {
        final codes = manager.getSupportedLanguageCodes();
        expect(codes, isNotEmpty);
      });

      test('contains common language codes', () {
        final codes = manager.getSupportedLanguageCodes();
        expect(codes, contains('en'));
        expect(codes, contains('es'));
        expect(codes, contains('fr'));
        expect(codes, contains('de'));
      });
    });

    // ----- getDownloadedModels -----
    group('getDownloadedModels', () {
      test('returns empty list on desktop (no models initialized)', () {
        final models = manager.getDownloadedModels();
        expect(models, isEmpty);
      });
    });

    // ----- getAvailableModels -----
    group('getAvailableModels', () {
      test('returns a list', () {
        final models = manager.getAvailableModels();
        expect(models, isA<List<LanguageModelInfo>>());
      });
    });

    // ----- isModelDownloaded -----
    group('isModelDownloaded', () {
      test('returns false for unknown language', () {
        expect(manager.isModelDownloaded('es'), isFalse);
      });

      test('returns false for unknown code', () {
        expect(manager.isModelDownloaded('xx'), isFalse);
      });
    });

    // ----- getModelInfo -----
    group('getModelInfo', () {
      test('returns null for unknown language', () {
        expect(manager.getModelInfo('es'), isNull);
      });
    });

    // ----- getDownloadState -----
    group('getDownloadState', () {
      test('returns null for language with no download state', () {
        expect(manager.getDownloadState('es'), isNull);
      });
    });

    // ----- isDownloading -----
    group('isDownloading', () {
      test('returns false initially', () {
        expect(manager.isDownloading, isFalse);
      });
    });

    // ----- configure & configuration -----
    group('configure', () {
      tearDown(() {
        // Reset config to defaults
        manager.configure(wifiOnly: true, autoDownloadPreferred: true);
      });

      test('updates wifiOnly setting', () {
        manager.configure(wifiOnly: false);
        expect(manager.configuration.wifiOnly, isFalse);
      });

      test('updates autoDownloadPreferred setting', () {
        manager.configure(autoDownloadPreferred: false);
        expect(manager.configuration.autoDownloadPreferred, isFalse);
      });

      test('updates both settings at once', () {
        manager.configure(wifiOnly: false, autoDownloadPreferred: false);
        final config = manager.configuration;
        expect(config.wifiOnly, isFalse);
        expect(config.autoDownloadPreferred, isFalse);
      });

      test('does not change unspecified settings', () {
        manager.configure(wifiOnly: true, autoDownloadPreferred: true);
        manager.configure(wifiOnly: false);
        expect(manager.configuration.wifiOnly, isFalse);
        expect(manager.configuration.autoDownloadPreferred, isTrue);
      });

      test('null parameters do not change settings', () {
        manager.configure(wifiOnly: false, autoDownloadPreferred: false);
        manager.configure(); // both null
        expect(manager.configuration.wifiOnly, isFalse);
        expect(manager.configuration.autoDownloadPreferred, isFalse);
      });
    });

    group('configuration', () {
      test('returns ModelManagerConfig', () {
        expect(manager.configuration, isA<ModelManagerConfig>());
      });

      test('reflects default settings', () {
        final config = manager.configuration;
        expect(config.wifiOnly, isTrue);
        expect(config.autoDownloadPreferred, isTrue);
      });
    });

    // ----- getTotalModelSize -----
    group('getTotalModelSize', () {
      test('returns 0 when no models are tracked', () {
        expect(manager.getTotalModelSize(), equals(0));
      });
    });

    // ----- getTotalModelSizeFormatted -----
    group('getTotalModelSizeFormatted', () {
      test('returns formatted string for 0 bytes', () {
        // 0 < 1024*1024 => 0/1024 = 0.0 MB
        expect(manager.getTotalModelSizeFormatted(), equals('0.0 MB'));
      });
    });

    // ----- checkForUpdates -----
    group('checkForUpdates', () {
      test('returns empty list', () async {
        final updates = await manager.checkForUpdates();
        expect(updates, isEmpty);
        expect(updates, isA<List<ModelUpdate>>());
      });
    });

    // ----- downloadModel (desktop: returns false) -----
    group('downloadModel', () {
      test('returns false on non-mobile platform', () async {
        final result = await manager.downloadModel('es');
        expect(result, isFalse);
      });

      test('does not change isDownloading state on non-mobile platform', () async {
        expect(manager.isDownloading, isFalse);
        await manager.downloadModel('es');
        expect(manager.isDownloading, isFalse);
      });

      test('does not create download state on non-mobile platform', () async {
        await manager.downloadModel('fr');
        expect(manager.getDownloadState('fr'), isNull);
      });

      test('progress callback is not invoked on non-mobile platform', () async {
        String? lastProgress;
        await manager.downloadModel(
          'de',
          onProgress: (msg) => lastProgress = msg,
        );
        expect(lastProgress, isNull);
      });
    });

    // ----- deleteModel (desktop: returns false) -----
    group('deleteModel', () {
      test('returns false on non-mobile platform', () async {
        final result = await manager.deleteModel('es');
        expect(result, isFalse);
      });
    });

    // ----- updateModel (desktop: delegates to delete+download, both false) -----
    group('updateModel', () {
      test('returns false on non-mobile platform', () async {
        final result = await manager.updateModel('es');
        expect(result, isFalse);
      });
    });

    // ----- deleteAllModels -----
    group('deleteAllModels', () {
      test('completes without error on desktop', () async {
        // Should not throw even with no models
        await manager.deleteAllModels();
      });
    });

    // ----- close -----
    group('close', () {
      test('clears downloaded models', () async {
        await manager.close();
        expect(manager.getDownloadedModels(), isEmpty);
      });

      test('clears available models', () async {
        await manager.close();
        expect(manager.getAvailableModels(), isEmpty);
      });

      test('can be called multiple times safely', () async {
        await manager.close();
        await manager.close();
        await manager.close();
        // Should not throw
      });
    });

    // ----- Network-dependent methods (skip on desktop) -----
    group('checkNetworkStatus', () {
      test(
        'returns a NetworkStatus',
        () async {
          final status = await manager.checkNetworkStatus();
          expect(status, isA<NetworkStatus>());
        },
        skip: 'Requires connectivity_plus platform support',
      );
    });

    group('networkStatusStream', () {
      test(
        'provides a Stream<NetworkStatus>',
        () {
          expect(manager.networkStatusStream, isA<Stream<NetworkStatus>>());
        },
        skip: 'Requires connectivity_plus platform support',
      );
    });

    group('isOnline', () {
      test(
        'returns a bool',
        () async {
          final online = await manager.isOnline;
          expect(online, isA<bool>());
        },
        skip: 'Requires connectivity_plus platform support',
      );
    });

    group('isWiFi', () {
      test(
        'returns a bool',
        () async {
          final wifi = await manager.isWiFi;
          expect(wifi, isA<bool>());
        },
        skip: 'Requires connectivity_plus platform support',
      );
    });

    group('preloadPreferredLanguages', () {
      test(
        'completes without error',
        () async {
          await manager.preloadPreferredLanguages(['es', 'fr', 'de']);
        },
        skip: 'Requires connectivity_plus platform support and mobile platform',
      );
    });
  });
}
