import 'dart:io' show Platform;
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dual_reader/src/core/utils/logging_service.dart';
import 'package:dual_reader/src/core/utils/language_code_mapper.dart';
import 'package:dual_reader/src/core/utils/language_utils.dart';

/// Enhanced language model management service for offline capability.
///
/// Features:
/// - Smart preloading based on user preferences
/// - WiFi-only download option
/// - Model tracking (downloaded, size, version)
/// - Network status detection
/// - Offline mode indicators
/// - Model versioning and updates
class LanguageModelManager {
  static const String _componentName = 'LanguageModelManager';

  // ConnectivityPlus instance (version 5.x doesn't require constructor call)
  final ConnectivityPlus _connectivity = ConnectivityPlus();

  // Model tracking
  final Map<String, LanguageModelInfo> _downloadedModels = {};

  // Download state
  final Map<String, ModelDownloadState> _downloadStates = {};
  bool _isDownloading = false;

  // Configuration
  bool _wifiOnly = true;
  bool _autoDownloadPreferred = true;

  // Singleton instance
  static LanguageModelManager? _instance;
  static LanguageModelManager get instance {
    _instance ??= LanguageModelManager._();
    return _instance!;
  }

  LanguageModelManager._() {
    _initializeModelTracking();
  }

  /// Initialize model tracking from persistent storage
  void _initializeModelTracking() {
    // Load previously downloaded models
    // For ML Kit, we need to check which models are available
    if (Platform.isAndroid || Platform.isIOS) {
      _checkAvailableModels();
    }
    _componentName.logInfo('Model tracking initialized with ${_downloadedModels.length} models');
  }

  /// Check which models are available on device
  Future<void> _checkAvailableModels() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return;
    }

    // Common language codes to check
    final commonLanguages = ['en', 'es', 'fr', 'de', 'it', 'pt', 'zh', 'ja', 'ko', 'ru', 'ar', 'hi'];

    for (final lang in commonLanguages) {
      try {
        // Try to create a translator to check if model is available
        final targetLang = LanguageCodeMapper.toMlKitCode(lang);
        final translator = OnDeviceTranslator(
          sourceLanguage: TranslateLanguage.english,
          targetLanguage: targetLang,
        );

        // If we got here, the model is either downloaded or will be downloaded
        // For a more accurate check, we could try a test translation with timeout
        await translator.close();

        // Assume model is available (ML Kit downloads on-demand)
        _downloadedModels[lang] = LanguageModelInfo(
          languageCode: lang,
          displayName: LanguageUtils.getLanguageName(lang),
          version: '1.0', // ML Kit doesn't expose version info
          sizeBytes: _estimateModelSize(lang),
          isDownloaded: true, // Assume downloaded if we can create it
          downloadDate: DateTime.now(),
        );
      } catch (e) {
        _componentName.logDebug('Model $lang not available: $e');
        _downloadedModels[lang] = LanguageModelInfo(
          languageCode: lang,
          displayName: LanguageUtils.getLanguageName(lang),
          version: '1.0',
          sizeBytes: _estimateModelSize(lang),
          isDownloaded: false,
        );
      }
    }
  }

  /// Estimate model size for a language (in bytes)
  /// Public method for UI components to display estimated sizes
  int estimateModelSize(String languageCode) {
    // Approximate sizes based on ML Kit documentation
    const baseSize = 10 * 1024 * 1024; // 10MB base
    const sizeMultipliers = {
      'zh': 3, // Chinese models are larger
      'ja': 3,
      'ko': 2,
      'ar': 2,
      'hi': 2,
      'ru': 1.5,
      'bg': 1.2,
      'uk': 1.2,
    };

    final multiplier = sizeMultipliers[languageCode.toLowerCase()] ?? 1.0;
    return (baseSize * multiplier).toInt();
  }

  /// Private internal version for use within the class
  int _estimateModelSize(String languageCode) => estimateModelSize(languageCode);

  /// Get list of downloaded models
  List<LanguageModelInfo> getDownloadedModels() {
    return _downloadedModels.values.where((m) => m.isDownloaded).toList();
  }

  /// Get list of available models (downloaded + not downloaded)
  List<LanguageModelInfo> getAvailableModels() {
    return _downloadedModels.values.toList();
  }

  /// Check if a model is downloaded
  bool isModelDownloaded(String languageCode) {
    return _downloadedModels[languageCode]?.isDownloaded ?? false;
  }

  /// Get model info for a language
  LanguageModelInfo? getModelInfo(String languageCode) {
    return _downloadedModels[languageCode];
  }

  /// Download a language model
  Future<bool> downloadModel(
    String languageCode, {
    void Function(String)? onProgress,
    bool forceWiFi = false,
  }) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      _componentName.logError('Model download attempted on unsupported platform');
      return false;
    }

    // Check WiFi requirement
    if (_wifiOnly || forceWiFi) {
      final connectivity = await _connectivity.checkConnectivity();
      final hasWiFi = connectivity.contains(ConnectivityResult.wifi);

      if (!hasWiFi) {
        _componentName.logWarning('WiFi required for model download');
        onProgress?.call('WiFi connection required. Please connect to WiFi and try again.');
        return false;
      }
    }

    // Check if already downloading
    if (_isDownloading) {
      _componentName.logWarning('Download already in progress');
      onProgress?.call('Another download is in progress. Please wait.');
      return false;
    }

    _isDownloading = true;
    _downloadStates[languageCode] = ModelDownloadState(
      languageCode: languageCode,
      isDownloading: true,
      progress: 0.0,
    );

    try {
      onProgress?.call('Starting download for ${LanguageUtils.getLanguageName(languageCode)}...');
      _componentName.logInfo('Downloading model for $languageCode');

      final targetLang = LanguageCodeMapper.toMlKitCode(languageCode);
      final translator = OnDeviceTranslator(
        sourceLanguage: TranslateLanguage.english,
        targetLanguage: targetLang,
      );

      // Trigger model download by translating test phrase
      onProgress?.call('Downloading language data...');
      final stopwatch = Stopwatch()..start();

      final result = await translator.translateText('Hello').timeout(
        const Duration(minutes: 10),
        onTimeout: () {
          throw TimeoutException('Model download timeout (10 minutes)');
        },
      );

      stopwatch.stop();
      _componentName.logInfo('Model downloaded for $languageCode: "$result" (${stopwatch.elapsed.inSeconds}s)');

      // Update model info
      _downloadedModels[languageCode] = LanguageModelInfo(
        languageCode: languageCode,
        displayName: LanguageUtils.getLanguageName(languageCode),
        version: '1.0',
        sizeBytes: _estimateModelSize(languageCode),
        isDownloaded: true,
        downloadDate: DateTime.now(),
      );

      _downloadStates[languageCode] = ModelDownloadState(
        languageCode: languageCode,
        isDownloading: false,
        progress: 1.0,
      );

      onProgress?.call('Download complete!');
      return true;
    } on TimeoutException catch (e) {
      _componentName.logError('Model download timeout: $e');
      onProgress?.call('Download timeout. Please try again.');
      _downloadStates[languageCode] = ModelDownloadState(
        languageCode: languageCode,
        isDownloading: false,
        progress: 0.0,
        error: e.toString(),
      );
      return false;
    } catch (e, stackTrace) {
      _componentName.logError('Model download failed for $languageCode', error: e, stackTrace: stackTrace);
      onProgress?.call('Download failed: $e');
      _downloadStates[languageCode] = ModelDownloadState(
        languageCode: languageCode,
        isDownloading: false,
        progress: 0.0,
        error: e.toString(),
      );
      return false;
    } finally {
      _isDownloading = false;
    }
  }

  /// Delete a language model
  Future<bool> deleteModel(String languageCode) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return false;
    }

    try {
      _componentName.logInfo('Deleting model for $languageCode');

      // Note: ML Kit doesn't provide a direct API to delete models
      // Models are managed by the system and will be removed when:
      // 1. App is uninstalled
      // 2. System clears cache
      // 3. Storage is full

      // We can mark it as not downloaded in our tracking
      if (_downloadedModels.containsKey(languageCode)) {
        final model = _downloadedModels[languageCode]!;
        _downloadedModels[languageCode] = model.copyWith(
          isDownloaded: false,
          downloadDate: null,
        );
      }

      _componentName.logInfo('Model marked for deletion: $languageCode');
      return true;
    } catch (e) {
      _componentName.logError('Failed to delete model for $languageCode: $e');
      return false;
    }
  }

  /// Delete all downloaded models
  Future<void> deleteAllModels() async {
    _componentName.logInfo('Deleting all models');

    for (final lang in _downloadedModels.keys.toList()) {
      await deleteModel(lang);
    }
  }

  /// Get download state for a language
  ModelDownloadState? getDownloadState(String languageCode) {
    return _downloadStates[languageCode];
  }

  /// Check if currently downloading any model
  bool get isDownloading => _isDownloading;

  /// Check network connectivity
  Future<NetworkStatus> checkNetworkStatus() async {
    try {
      final connectivity = await _connectivity.checkConnectivity();

      final hasWiFi = connectivity.contains(ConnectivityResult.wifi);
      final hasMobile = connectivity.contains(ConnectivityResult.mobile);
      final hasEthernet = connectivity.contains(ConnectivityResult.ethernet);

      return NetworkStatus(
        isConnected: hasWiFi || hasMobile || hasEthernet,
        isWiFi: hasWiFi,
        isMobile: hasMobile,
        isEthernet: hasEthernet,
        connectionType: hasWiFi
            ? 'wifi'
            : hasMobile
                ? 'mobile'
                : hasEthernet
                    ? 'ethernet'
                    : 'none',
      );
    } catch (e) {
      _componentName.logError('Failed to check network status: $e');
      return NetworkStatus.offline();
    }
  }

  /// Stream of network status changes
  Stream<NetworkStatus> get networkStatusStream {
    return _connectivity.onConnectivityChanged
        .map((results) => NetworkStatus(
              isConnected: results.any((r) => r != ConnectivityResult.none),
              isWiFi: results.contains(ConnectivityResult.wifi),
              isMobile: results.contains(ConnectivityResult.mobile),
              isEthernet: results.contains(ConnectivityResult.ethernet),
              connectionType: results.contains(ConnectivityResult.wifi)
                  ? 'wifi'
                  : results.contains(ConnectivityResult.mobile)
                      ? 'mobile'
                      : results.contains(ConnectivityResult.ethernet)
                          ? 'ethernet'
                          : 'none',
            ));
  }

  /// Check if currently online
  Future<bool> get isOnline async {
    final status = await checkNetworkStatus();
    return status.isConnected;
  }

  /// Check if WiFi is available
  Future<bool> get isWiFi async {
    final status = await checkNetworkStatus();
    return status.isWiFi;
  }

  /// Configure download settings
  void configure({
    bool? wifiOnly,
    bool? autoDownloadPreferred,
  }) {
    if (wifiOnly != null) {
      _wifiOnly = wifiOnly;
    }
    if (autoDownloadPreferred != null) {
      _autoDownloadPreferred = autoDownloadPreferred;
    }

    _componentName.logInfo('Configuration updated: wifiOnly=$_wifiOnly, autoDownload=$_autoDownloadPreferred');
  }

  /// Get current configuration
  ModelManagerConfig get configuration => ModelManagerConfig(
    wifiOnly: _wifiOnly,
    autoDownloadPreferred: _autoDownloadPreferred,
  );

  /// Preload models for user's preferred languages
  Future<void> preloadPreferredLanguages(List<String> languageCodes) async {
    if (!_autoDownloadPreferred) {
      _componentName.logInfo('Auto-download disabled, skipping preload');
      return;
    }

    // Check network first
    final status = await checkNetworkStatus();
    if (!status.isConnected) {
      _componentName.logInfo('No network connection, skipping preload');
      return;
    }

    if (_wifiOnly && !status.isWiFi) {
      _componentName.logInfo('WiFi-only mode and no WiFi, skipping preload');
      return;
    }

    _componentName.logInfo('Preloading ${languageCodes.length} language models');

    for (final lang in languageCodes) {
      if (_downloadedModels[lang]?.isDownloaded == true) {
        _componentName.logDebug('Model $lang already downloaded, skipping');
        continue;
      }

      // Download in background without blocking
      downloadModel(lang).catchError((e) {
        _componentName.logWarning('Failed to preload model for $lang: $e');
      });

      // Don't wait for one to finish before starting the next
      // They will queue up in the download manager
    }
  }

  /// Calculate total size of downloaded models
  int getTotalModelSize() {
    int total = 0;
    for (final model in _downloadedModels.values) {
      if (model.isDownloaded) {
        total += model.sizeBytes;
      }
    }
    return total;
  }

  /// Get total model size as formatted string
  String getTotalModelSizeFormatted() {
    final bytes = getTotalModelSize();
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Check for model updates
  Future<List<ModelUpdate>> checkForUpdates() async {
    final updates = <ModelUpdate>[];

    // In a real implementation, this would query a server for model versions
    // For now, we'll return empty since ML Kit doesn't expose version info
    _componentName.logInfo('Checking for model updates...');

    return updates;
  }

  /// Update model to latest version
  Future<bool> updateModel(String languageCode) async {
    _componentName.logInfo('Updating model for $languageCode');

    // Delete old version
    await deleteModel(languageCode);

    // Download new version
    return await downloadModel(languageCode);
  }

  /// Get recommended languages to download
  List<String> getRecommendedLanguages() {
    // Based on common usage and download frequency
    return [
      'es', // Spanish
      'fr', // French
      'de', // German
      'it', // Italian
      'pt', // Portuguese
      'zh', // Chinese
      'ja', // Japanese
    ];
  }

  /// Get all supported language codes
  List<String> getSupportedLanguageCodes() {
    return LanguageUtils.getSupportedLanguageCodes();
  }

  /// Close the manager and clean up resources
  Future<void> close() async {
    _downloadedModels.clear();
    _downloadStates.clear();
    _componentName.logInfo('Language model manager closed');
  }
}

/// Information about a language model
class LanguageModelInfo {
  final String languageCode;
  final String displayName;
  final String version;
  final int sizeBytes;
  final bool isDownloaded;
  final DateTime? downloadDate;

  LanguageModelInfo({
    required this.languageCode,
    required this.displayName,
    required this.version,
    required this.sizeBytes,
    required this.isDownloaded,
    this.downloadDate,
  });

  /// Get formatted size string
  String get formattedSize {
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} MB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Copy with different values
  LanguageModelInfo copyWith({
    String? languageCode,
    String? displayName,
    String? version,
    int? sizeBytes,
    bool? isDownloaded,
    DateTime? downloadDate,
  }) {
    return LanguageModelInfo(
      languageCode: languageCode ?? this.languageCode,
      displayName: displayName ?? this.displayName,
      version: version ?? this.version,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      downloadDate: downloadDate ?? this.downloadDate,
    );
  }

  @override
  String toString() {
    return 'LanguageModelInfo($languageCode, $displayName, v$version, ${isDownloaded ? "downloaded" : "not downloaded"}, $formattedSize)';
  }
}

/// State of a model download
class ModelDownloadState {
  final String languageCode;
  final bool isDownloading;
  final double progress; // 0.0 to 1.0
  final String? error;

  ModelDownloadState({
    required this.languageCode,
    required this.isDownloading,
    required this.progress,
    this.error,
  });

  ModelDownloadState copyWith({
    String? languageCode,
    bool? isDownloading,
    double? progress,
    String? error,
  }) {
    return ModelDownloadState(
      languageCode: languageCode ?? this.languageCode,
      isDownloading: isDownloading ?? this.isDownloading,
      progress: progress ?? this.progress,
      error: error ?? this.error,
    );
  }
}

/// Network status information
class NetworkStatus {
  final bool isConnected;
  final bool isWiFi;
  final bool isMobile;
  final bool isEthernet;
  final String connectionType;

  const NetworkStatus({
    required this.isConnected,
    this.isWiFi = false,
    this.isMobile = false,
    this.isEthernet = false,
    this.connectionType = 'none',
  });

  factory NetworkStatus.offline() {
    return const NetworkStatus(
      isConnected: false,
      connectionType: 'none',
    );
  }

  bool get isOnline => isConnected;

  @override
  String toString() {
    return 'NetworkStatus($connectionType, ${isConnected ? "online" : "offline"})';
  }
}

/// Model manager configuration
class ModelManagerConfig {
  final bool wifiOnly;
  final bool autoDownloadPreferred;

  const ModelManagerConfig({
    required this.wifiOnly,
    required this.autoDownloadPreferred,
  });

  @override
  String toString() {
    return 'ModelManagerConfig(wifiOnly: $wifiOnly, autoDownload: $autoDownloadPreferred)';
  }
}

/// Information about a model update
class ModelUpdate {
  final String languageCode;
  final String currentVersion;
  final String availableVersion;
  final int sizeBytes;
  final bool isRequired;

  const ModelUpdate({
    required this.languageCode,
    required this.currentVersion,
    required this.availableVersion,
    required this.sizeBytes,
    required this.isRequired,
  });

  @override
  String toString() {
    return 'ModelUpdate($languageCode: v$currentVersion -> v$availableVersion, ${isRequired ? "required" : "optional"})';
  }
}
