import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:dual_reader/src/domain/services/translation_service.dart';
import 'package:dual_reader/src/core/utils/logging_service.dart';

/// Service for managing background language model downloads
/// Pre-downloads commonly used models on app startup for better UX
class LanguageModelDownloader {
  static const String _componentName = 'LanguageModelDownloader';
  static LanguageModelDownloader? _instance;

  final TranslationService _translationService;
  bool _isDownloading = false;

  LanguageModelDownloader._(this._translationService);

  factory LanguageModelDownloader.getInstance(TranslationService service) {
    _instance ??= LanguageModelDownloader._(service);
    return _instance!;
  }

  /// Download Spanish model in the background on app startup (mobile only)
  /// Spanish is one of the most commonly translated languages
  Future<void> downloadSpanishModelInBackground() async {
    // Only on mobile platforms
    if (!Platform.isAndroid && !Platform.isIOS) {
      _componentName.logDebug('Not on mobile platform, skipping background download');
      return;
    }

    if (_isDownloading) {
      _componentName.logDebug('Download already in progress');
      return;
    }

    _isDownloading = true;
    _componentName.logInfo('Starting background Spanish model download');

    try {
      // Check if model is already ready
      final isReady = await _translationService.isLanguageModelReady('es');

      if (isReady) {
        _componentName.logInfo('Spanish model already available');
        return;
      }

      // Download in background with progress callbacks
      final success = await _translationService.downloadLanguageModel(
        'es',
        onProgress: (message) {
          _componentName.logDebug('Spanish model download: $message');
        },
      );

      if (success) {
        _componentName.logInfo('Spanish model downloaded successfully in background');
      } else {
        _componentName.logWarning('Spanish model download failed (will retry on demand)');
      }
    } catch (e) {
      _componentName.logError('Background Spanish model download error: $e');
      // Don't throw - this is a background operation
    } finally {
      _isDownloading = false;
    }
  }

  /// Download multiple models in background (optional enhancement)
  /// Downloads Spanish, French, and German models for common use cases
  Future<void> downloadCommonModelsInBackground() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return;
    }

    if (_isDownloading) {
      return;
    }

    _isDownloading = true;
    _componentName.logInfo('Starting background download of common models');

    try {
      final commonLanguages = ['es', 'fr', 'de'];

      for (final lang in commonLanguages) {
        try {
          final isReady = await _translationService.isLanguageModelReady(lang);

          if (!isReady) {
            _componentName.logInfo('Downloading $lang model in background');
            await _translationService.downloadLanguageModel(lang);
            _componentName.logInfo('$lang model downloaded');
          } else {
            _componentName.logDebug('$lang model already available');
          }
        } catch (e) {
          _componentName.logWarning('Failed to download $lang model: $e');
          // Continue with next language
        }
      }

      _componentName.logInfo('Background model downloads complete');
    } finally {
      _isDownloading = false;
    }
  }
}
