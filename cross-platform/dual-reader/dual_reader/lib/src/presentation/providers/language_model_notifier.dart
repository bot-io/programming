import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dual_reader/src/core/di/injection_container.dart';
import 'package:dual_reader/src/domain/services/translation_service.dart';
import 'package:dual_reader/src/data/services/client_side_translation_service.dart';

/// State for language ML Kit model download
enum ModelDownloadStatus {
  notStarted,
  inProgress,
  completed,
  failed,
}

/// State for language model download operations
class LanguageModelState {
  final ModelDownloadStatus status;
  final String? progressMessage;
  final String? errorMessage;
  final bool showNotification;
  final String languageCode;

  const LanguageModelState({
    required this.status,
    this.progressMessage,
    this.errorMessage,
    this.showNotification = false,
    this.languageCode = 'en',
  });

  LanguageModelState copyWith({
    ModelDownloadStatus? status,
    String? progressMessage,
    String? errorMessage,
    bool? showNotification,
    String? languageCode,
  }) {
    return LanguageModelState(
      status: status ?? this.status,
      progressMessage: progressMessage ?? this.progressMessage,
      errorMessage: errorMessage ?? this.errorMessage,
      showNotification: showNotification ?? this.showNotification,
      languageCode: languageCode ?? this.languageCode,
    );
  }
}

/// Notifier for managing language model download operations
///
/// This notifier handles the download of on-device translation models
/// for client-side translation services (e.g., Google ML Kit).
class LanguageModelNotifier extends StateNotifier<LanguageModelState> {
  LanguageModelNotifier() : super(const LanguageModelState(status: ModelDownloadStatus.notStarted));

  /// Checks if the model is ready and downloads if necessary
  ///
  /// This method should be called instead of [downloadLanguageModel] to ensure
  /// the model readiness check happens BEFORE triggering any download UI.
  ///
  /// Returns true if the model was already ready (no download needed),
  /// false if a download was initiated.
  Future<bool> checkAndDownloadRequiredModel(String targetLanguage) async {
    debugPrint('[LanguageModel] checkAndDownloadRequiredModel() called for language: $targetLanguage - current status: ${state.status}');

    try {
      // Get the translation service
      final translationService = sl<TranslationService>();
      debugPrint('[LanguageModel] Translation service type: ${translationService.runtimeType}');

      // If this is not a client-side service, no download needed
      if (translationService is! ClientSideTranslationService) {
        debugPrint('[LanguageModel] Translation service does not support model download (API-based)');
        state = LanguageModelState(
          status: ModelDownloadStatus.completed,
          progressMessage: 'Using API-based translation',
          showNotification: false,
          languageCode: targetLanguage,
        );
        return true; // Model "ready" (no model needed)
      }

      // Check if model is already ready BEFORE triggering download
      debugPrint('[LanguageModel] Checking if $targetLanguage model is already ready...');
      final isReady = await translationService.isLanguageModelReady(targetLanguage);
      debugPrint('[LanguageModel] Model ready check result: $isReady');

      if (isReady) {
        // Model already available - set status but don't show notification
        state = LanguageModelState(
          status: ModelDownloadStatus.completed,
          showNotification: false,
          languageCode: targetLanguage,
        );
        debugPrint('[LanguageModel] $targetLanguage model already available');
        return true; // Model ready
      }

      // Model not ready, proceed with download
      debugPrint('[LanguageModel] $targetLanguage model not ready, starting download...');
      await downloadLanguageModel(targetLanguage);
      return false; // Download initiated
    } catch (e) {
      debugPrint('[LanguageModel] Error checking model readiness: $e');
      // Try to proceed with download anyway
      await downloadLanguageModel(targetLanguage);
      return false;
    }
  }

  /// Start downloading the language model in the background
  Future<void> downloadLanguageModel(String languageCode) async {
    debugPrint('[LanguageModel] downloadLanguageModel() called for $languageCode - current status: ${state.status}');

    if (state.status == ModelDownloadStatus.completed && state.languageCode == languageCode) {
      debugPrint('[LanguageModel] Model for $languageCode already downloaded, skipping');
      return;
    }

    if (state.status == ModelDownloadStatus.inProgress) {
      debugPrint('[LanguageModel] Download already in progress');
      return;
    }

    try {
      final translationService = sl<TranslationService>();
      debugPrint('[LanguageModel] Translation service type: ${translationService.runtimeType}');

      // Only proceed if this is a ClientSideTranslationService with model download support
      if (translationService is! ClientSideTranslationService) {
        debugPrint('[LanguageModel] Translation service does not support model download (API-based)');
        state = LanguageModelState(
          status: ModelDownloadStatus.completed,
          progressMessage: 'Using API-based translation',
          showNotification: false,
          languageCode: languageCode,
        );
        return;
      }

      debugPrint('[LanguageModel] Starting $languageCode model download...');
      state = LanguageModelState(
        status: ModelDownloadStatus.inProgress,
        progressMessage: 'Starting model download...',
        showNotification: false,
        languageCode: languageCode,
      );

      final success = await translationService.downloadLanguageModel(
        languageCode,
        onProgress: (message) {
          debugPrint('[LanguageModel] Progress: $message');
          state = LanguageModelState(
            status: ModelDownloadStatus.inProgress,
            progressMessage: message,
            showNotification: false,
            languageCode: languageCode,
          );
        },
      );

      if (success) {
        // Only show notification after successful download
        state = LanguageModelState(
          status: ModelDownloadStatus.completed,
          progressMessage: 'Model downloaded successfully!',
          showNotification: true,
          languageCode: languageCode,
        );
        debugPrint('[LanguageModel] Download completed successfully for $languageCode');
      } else {
        state = LanguageModelState(
          status: ModelDownloadStatus.failed,
          errorMessage: 'Download failed. Please try again later.',
          showNotification: true,
          languageCode: languageCode,
        );
        debugPrint('[LanguageModel] Download failed for $languageCode');
      }
    } catch (e) {
      debugPrint('[LanguageModel] Download error for $languageCode: $e');
      state = LanguageModelState(
        status: ModelDownloadStatus.failed,
        errorMessage: 'Download failed: $e',
        showNotification: true,
        languageCode: languageCode,
      );
    }
  }

  /// Reset the download status (for retry)
  void reset() {
    state = const LanguageModelState(status: ModelDownloadStatus.notStarted);
  }

  /// Dismiss the notification banner (keeps status as completed but hides banner)
  void dismissNotification() {
    state = state.copyWith(showNotification: false);
  }
}

/// Provider for language model download state
final languageModelProvider = StateNotifierProvider<LanguageModelNotifier, LanguageModelState>((ref) {
  return LanguageModelNotifier();
});
