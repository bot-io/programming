import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dual_reader/src/core/di/injection_container.dart';
import 'package:dual_reader/src/domain/services/translation_service.dart';
import 'package:dual_reader/src/data/services/client_side_translation_service.dart';

/// State for Spanish ML Kit model download
enum ModelDownloadStatus {
  notStarted,
  inProgress,
  completed,
  failed,
}

class SpanishModelState {
  final ModelDownloadStatus status;
  final String? progressMessage;
  final String? errorMessage;

  const SpanishModelState({
    required this.status,
    this.progressMessage,
    this.errorMessage,
  });

  SpanishModelState copyWith({
    ModelDownloadStatus? status,
    String? progressMessage,
    String? errorMessage,
  }) {
    return SpanishModelState(
      status: status ?? this.status,
      progressMessage: progressMessage ?? this.progressMessage,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class SpanishModelNotifier extends StateNotifier<SpanishModelState> {
  SpanishModelNotifier() : super(const SpanishModelState(status: ModelDownloadStatus.notStarted));

  /// Start downloading the Spanish model in the background
  Future<void> downloadSpanishModel() async {
    debugPrint('[SpanishModel] downloadSpanishModel() called - current status: ${state.status}');

    if (state.status == ModelDownloadStatus.completed) {
      debugPrint('[SpanishModel] Model already downloaded, skipping');
      return;
    }

    if (state.status == ModelDownloadStatus.inProgress) {
      debugPrint('[SpanishModel] Download already in progress');
      return;
    }

    try {
      debugPrint('[SpanishModel] Getting translation service from service locator...');
      // Check if model is already ready
      final translationService = sl<TranslationService>();
      debugPrint('[SpanishModel] Translation service type: ${translationService.runtimeType}');

      // Only proceed if this is a ClientSideTranslationService with model download support
      if (translationService is! ClientSideTranslationService) {
        debugPrint('[SpanishModel] Translation service does not support model download (API-based)');
        state = const SpanishModelState(
          status: ModelDownloadStatus.completed,
          progressMessage: 'Using API-based translation',
        );
        return;
      }

      debugPrint('[SpanishModel] Checking if Spanish model is already ready...');
      final isReady = await translationService.isLanguageModelReady('es');
      debugPrint('[SpanishModel] Model ready check result: $isReady');

      if (isReady) {
        state = const SpanishModelState(status: ModelDownloadStatus.completed);
        debugPrint('[SpanishModel] Spanish model already available');
        return;
      }

      debugPrint('[SpanishModel] Starting Spanish model download...');
      state = const SpanishModelState(
        status: ModelDownloadStatus.inProgress,
        progressMessage: 'Starting Spanish model download...',
      );

      final success = await translationService.downloadLanguageModel(
        'es',
        onProgress: (message) {
          debugPrint('[SpanishModel] Progress: $message');
          state = SpanishModelState(
            status: ModelDownloadStatus.inProgress,
            progressMessage: message,
          );
        },
      );

      if (success) {
        state = const SpanishModelState(
          status: ModelDownloadStatus.completed,
          progressMessage: 'Spanish model downloaded successfully!',
        );
        debugPrint('[SpanishModel] Download completed successfully');
      } else {
        state = const SpanishModelState(
          status: ModelDownloadStatus.failed,
          errorMessage: 'Download failed. Please try again later.',
        );
        debugPrint('[SpanishModel] Download failed');
      }
    } catch (e) {
      debugPrint('[SpanishModel] Download error: $e');
      state = SpanishModelState(
        status: ModelDownloadStatus.failed,
        errorMessage: 'Download failed: $e',
      );
    }
  }

  /// Reset the download status (for retry)
  void reset() {
    state = const SpanishModelState(status: ModelDownloadStatus.notStarted);
  }
}

/// Provider for Spanish model download state
final spanishModelProvider = StateNotifierProvider<SpanishModelNotifier, SpanishModelState>((ref) {
  return SpanishModelNotifier();
});
