import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dual_reader/src/presentation/providers/language_model_notifier.dart';

void main() {
  group('LanguageModelNotifier Tests', () {
    test('should start with notStarted status and showNotification false', () {
      final notifier = LanguageModelNotifier();
      expect(notifier.state.status, ModelDownloadStatus.notStarted);
      expect(notifier.state.progressMessage, isNull);
      expect(notifier.state.errorMessage, isNull);
      expect(notifier.state.showNotification, isFalse);
      expect(notifier.state.languageCode, 'en'); // Default language
    });

    test('should update state to inProgress when starting download', () {
      final notifier = LanguageModelNotifier();

      // Simulate state change that would happen during download
      notifier.state = const LanguageModelState(
        status: ModelDownloadStatus.inProgress,
        progressMessage: 'Starting download...',
        showNotification: false,
        languageCode: 'es',
      );

      expect(notifier.state.status, ModelDownloadStatus.inProgress);
      expect(notifier.state.progressMessage, 'Starting download...');
      expect(notifier.state.showNotification, isFalse);
      expect(notifier.state.languageCode, 'es');
    });

    test('should update state to completed with showNotification true after successful download', () {
      final notifier = LanguageModelNotifier();

      notifier.state = const LanguageModelState(
        status: ModelDownloadStatus.completed,
        progressMessage: 'Download completed successfully!',
        showNotification: true, // Should show notification after download
        languageCode: 'es',
      );

      expect(notifier.state.status, ModelDownloadStatus.completed);
      expect(notifier.state.progressMessage, 'Download completed successfully!');
      expect(notifier.state.errorMessage, isNull);
      expect(notifier.state.showNotification, isTrue);
      expect(notifier.state.languageCode, 'es');
    });

    test('should update state to completed without showNotification when model already exists', () {
      final notifier = LanguageModelNotifier();

      // Model already available - set status but don't show notification
      notifier.state = const LanguageModelState(
        status: ModelDownloadStatus.completed,
        showNotification: false, // Don't notify on app startup
        languageCode: 'bg',
      );

      expect(notifier.state.status, ModelDownloadStatus.completed);
      expect(notifier.state.showNotification, isFalse);
      expect(notifier.state.languageCode, 'bg');
    });

    test('should update state to failed with showNotification true on download error', () {
      final notifier = LanguageModelNotifier();

      const errorMessage = 'Network timeout';

      notifier.state = const LanguageModelState(
        status: ModelDownloadStatus.failed,
        errorMessage: errorMessage,
        showNotification: true, // Show notification for errors
        languageCode: 'fr',
      );

      expect(notifier.state.status, ModelDownloadStatus.failed);
      expect(notifier.state.errorMessage, errorMessage);
      expect(notifier.state.progressMessage, isNull);
      expect(notifier.state.showNotification, isTrue);
      expect(notifier.state.languageCode, 'fr');
    });

    test('should reset to notStarted state', () {
      final notifier = LanguageModelNotifier();

      // Set to completed state
      notifier.state = const LanguageModelState(
        status: ModelDownloadStatus.completed,
        showNotification: true,
        languageCode: 'es',
      );

      expect(notifier.state.status, ModelDownloadStatus.completed);
      expect(notifier.state.showNotification, isTrue);

      // Reset
      notifier.reset();

      expect(notifier.state.status, ModelDownloadStatus.notStarted);
      expect(notifier.state.progressMessage, isNull);
      expect(notifier.state.errorMessage, isNull);
      expect(notifier.state.showNotification, isFalse);
    });

    test('should dismiss notification while keeping completed status', () {
      final notifier = LanguageModelNotifier();

      // Set to completed with notification
      notifier.state = const LanguageModelState(
        status: ModelDownloadStatus.completed,
        progressMessage: 'Download completed successfully!',
        showNotification: true,
        languageCode: 'es',
      );

      expect(notifier.state.showNotification, isTrue);

      // Dismiss notification
      notifier.dismissNotification();

      // Status should remain completed but notification should be hidden
      expect(notifier.state.status, ModelDownloadStatus.completed);
      expect(notifier.state.showNotification, isFalse);
      expect(notifier.state.progressMessage, 'Download completed successfully!');
      expect(notifier.state.languageCode, 'es');
    });

    test('should copy state correctly with copyWith method', () {
      const initialState = LanguageModelState(
        status: ModelDownloadStatus.inProgress,
        progressMessage: 'Downloading...',
        showNotification: false,
        languageCode: 'bg',
      );

      final newState = initialState.copyWith(
        progressMessage: 'Almost done...',
      );

      expect(newState.status, ModelDownloadStatus.inProgress);
      expect(newState.progressMessage, 'Almost done...');
      expect(newState.showNotification, isFalse);
      expect(newState.languageCode, 'bg');
    });

    test('should handle multiple state transitions', () {
      final notifier = LanguageModelNotifier();

      // notStarted -> inProgress
      notifier.state = const LanguageModelState(
        status: ModelDownloadStatus.inProgress,
        progressMessage: 'Starting...',
        showNotification: false,
        languageCode: 'es',
      );
      expect(notifier.state.status, ModelDownloadStatus.inProgress);
      expect(notifier.state.showNotification, isFalse);

      // inProgress -> completed (with notification)
      notifier.state = const LanguageModelState(
        status: ModelDownloadStatus.completed,
        progressMessage: 'Done!',
        showNotification: true,
        languageCode: 'es',
      );
      expect(notifier.state.status, ModelDownloadStatus.completed);
      expect(notifier.state.showNotification, isTrue);
    });

    test('should preserve progress message during error state', () {
      final notifier = LanguageModelNotifier();

      notifier.state = const LanguageModelState(
        status: ModelDownloadStatus.failed,
        errorMessage: 'Connection failed',
        progressMessage: 'Was downloading...',
        showNotification: true,
        languageCode: 'de',
      );

      expect(notifier.state.status, ModelDownloadStatus.failed);
      expect(notifier.state.errorMessage, 'Connection failed');
      expect(notifier.state.progressMessage, 'Was downloading...');
      expect(notifier.state.showNotification, isTrue);
      expect(notifier.state.languageCode, 'de');
    });

    test('should handle copyWith with showNotification parameter', () {
      const initialState = LanguageModelState(
        status: ModelDownloadStatus.completed,
        showNotification: true,
        languageCode: 'es',
      );

      final newState = initialState.copyWith(showNotification: false);

      expect(newState.status, ModelDownloadStatus.completed);
      expect(newState.showNotification, isFalse);
      expect(newState.languageCode, 'es');
    });

    test('should track different language codes', () {
      final notifier = LanguageModelNotifier();

      // Spanish
      notifier.state = const LanguageModelState(
        status: ModelDownloadStatus.inProgress,
        languageCode: 'es',
      );
      expect(notifier.state.languageCode, 'es');

      // Bulgarian
      notifier.state = const LanguageModelState(
        status: ModelDownloadStatus.completed,
        languageCode: 'bg',
      );
      expect(notifier.state.languageCode, 'bg');

      // French
      notifier.state = const LanguageModelState(
        status: ModelDownloadStatus.failed,
        languageCode: 'fr',
      );
      expect(notifier.state.languageCode, 'fr');
    });
  });

  group('ModelDownloadStatus Enum Tests', () {
    test('should have correct number of states', () {
      expect(ModelDownloadStatus.values.length, 4);
    });

    test('should contain all required states', () {
      expect(ModelDownloadStatus.values, contains(ModelDownloadStatus.notStarted));
      expect(ModelDownloadStatus.values, contains(ModelDownloadStatus.inProgress));
      expect(ModelDownloadStatus.values, contains(ModelDownloadStatus.completed));
      expect(ModelDownloadStatus.values, contains(ModelDownloadStatus.failed));
    });
  });

  group('LanguageModelState Tests', () {
    test('should create state with all fields', () {
      const state = LanguageModelState(
        status: ModelDownloadStatus.inProgress,
        progressMessage: 'Downloading model...',
        errorMessage: null,
        showNotification: false,
        languageCode: 'es',
      );

      expect(state.status, ModelDownloadStatus.inProgress);
      expect(state.progressMessage, 'Downloading model...');
      expect(state.errorMessage, isNull);
      expect(state.showNotification, isFalse);
      expect(state.languageCode, 'es');
    });

    test('should create state with error message and notification', () {
      const state = LanguageModelState(
        status: ModelDownloadStatus.failed,
        errorMessage: 'Download failed',
        showNotification: true,
        languageCode: 'bg',
      );

      expect(state.status, ModelDownloadStatus.failed);
      expect(state.errorMessage, 'Download failed');
      expect(state.showNotification, isTrue);
      expect(state.languageCode, 'bg');
    });

    test('should copy state preserving null fields', () {
      const initialState = LanguageModelState(
        status: ModelDownloadStatus.notStarted,
        showNotification: false,
        languageCode: 'es',
      );

      final newState = initialState.copyWith(
        status: ModelDownloadStatus.completed,
      );

      expect(newState.status, ModelDownloadStatus.completed);
      expect(newState.progressMessage, isNull);
      expect(newState.errorMessage, isNull);
      expect(newState.showNotification, isFalse);
      expect(newState.languageCode, 'es');
    });

    test('should handle copyWith with all parameters', () {
      const initialState = LanguageModelState(
        status: ModelDownloadStatus.inProgress,
        progressMessage: 'Initial message',
        errorMessage: 'Initial error',
        showNotification: false,
        languageCode: 'es',
      );

      final newState = initialState.copyWith(
        status: ModelDownloadStatus.completed,
        progressMessage: 'New message',
        errorMessage: 'New error',
        showNotification: true,
        languageCode: 'bg',
      );

      expect(newState.status, ModelDownloadStatus.completed);
      expect(newState.progressMessage, 'New message');
      expect(newState.errorMessage, 'New error');
      expect(newState.showNotification, isTrue);
      expect(newState.languageCode, 'bg');
    });

    test('should handle copyWith with partial parameters', () {
      const initialState = LanguageModelState(
        status: ModelDownloadStatus.inProgress,
        progressMessage: 'Downloading...',
        errorMessage: null,
        showNotification: false,
        languageCode: 'es',
      );

      final newState = initialState.copyWith(
        progressMessage: 'Almost done...',
      );

      expect(newState.status, ModelDownloadStatus.inProgress);
      expect(newState.progressMessage, 'Almost done...');
      expect(newState.errorMessage, isNull);
      expect(newState.showNotification, isFalse);
      expect(newState.languageCode, 'es');
    });

    test('should be immutable with copyWith', () {
      const state1 = LanguageModelState(
        status: ModelDownloadStatus.notStarted,
        showNotification: false,
        languageCode: 'es',
      );

      final state2 = state1.copyWith(
        status: ModelDownloadStatus.completed,
        showNotification: true,
        languageCode: 'bg',
      );

      // Original state should be unchanged
      expect(state1.status, ModelDownloadStatus.notStarted);
      expect(state1.showNotification, isFalse);
      expect(state1.languageCode, 'es');
      // New state should have new value
      expect(state2.status, ModelDownloadStatus.completed);
      expect(state2.showNotification, isTrue);
      expect(state2.languageCode, 'bg');
    });

    test('showNotification should default to false', () {
      const state = LanguageModelState(
        status: ModelDownloadStatus.notStarted,
      );

      expect(state.showNotification, isFalse);
    });

    test('languageCode should default to en', () {
      const state = LanguageModelState(
        status: ModelDownloadStatus.notStarted,
      );

      expect(state.languageCode, 'en');
    });
  });

  group('showNotification Behavior Tests', () {
    test('should not show notification when model is already ready on startup', () {
      final notifier = LanguageModelNotifier();

      // Simulating app startup where model is already downloaded
      notifier.state = const LanguageModelState(
        status: ModelDownloadStatus.completed,
        showNotification: false, // No notification on startup
        languageCode: 'es',
      );

      expect(notifier.state.status, ModelDownloadStatus.completed);
      expect(notifier.state.showNotification, isFalse);
    });

    test('should show notification after successful download', () {
      final notifier = LanguageModelNotifier();

      // Simulating successful download
      notifier.state = const LanguageModelState(
        status: ModelDownloadStatus.completed,
        progressMessage: 'Spanish model downloaded successfully!',
        showNotification: true, // Show notification after download
        languageCode: 'es',
      );

      expect(notifier.state.status, ModelDownloadStatus.completed);
      expect(notifier.state.showNotification, isTrue);
    });

    test('should allow dismissing notification', () {
      final notifier = LanguageModelNotifier();

      // Start with notification shown
      notifier.state = const LanguageModelState(
        status: ModelDownloadStatus.completed,
        showNotification: true,
        languageCode: 'bg',
      );

      expect(notifier.state.showNotification, isTrue);

      // User dismisses
      notifier.dismissNotification();

      expect(notifier.state.showNotification, isFalse);
      expect(notifier.state.status, ModelDownloadStatus.completed);
    });

    test('should not show notification during download', () {
      final notifier = LanguageModelNotifier();

      notifier.state = const LanguageModelState(
        status: ModelDownloadStatus.inProgress,
        progressMessage: 'Downloading...',
        showNotification: false, // Don't show while downloading
        languageCode: 'es',
      );

      expect(notifier.state.status, ModelDownloadStatus.inProgress);
      expect(notifier.state.showNotification, isFalse);
    });

    test('should not show notification on API-based service', () {
      final notifier = LanguageModelNotifier();

      // API-based service (no model download needed)
      notifier.state = const LanguageModelState(
        status: ModelDownloadStatus.completed,
        progressMessage: 'Using API-based translation',
        showNotification: false, // Don't show for API-based
        languageCode: 'en',
      );

      expect(notifier.state.status, ModelDownloadStatus.completed);
      expect(notifier.state.showNotification, isFalse);
    });
  });
}
