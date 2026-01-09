import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dual_reader/src/presentation/providers/spanish_model_notifier.dart';

void main() {
  group('SpanishModelNotifier Tests', () {
    test('should start with notStarted status', () {
      final notifier = SpanishModelNotifier();
      expect(notifier.state.status, ModelDownloadStatus.notStarted);
      expect(notifier.state.progressMessage, isNull);
      expect(notifier.state.errorMessage, isNull);
    });

    test('should update state to inProgress when starting download', () {
      final notifier = SpanishModelNotifier();

      // Simulate state change that would happen during download
      notifier.state = const SpanishModelState(
        status: ModelDownloadStatus.inProgress,
        progressMessage: 'Starting download...',
      );

      expect(notifier.state.status, ModelDownloadStatus.inProgress);
      expect(notifier.state.progressMessage, 'Starting download...');
    });

    test('should update state to completed on successful download', () {
      final notifier = SpanishModelNotifier();

      notifier.state = const SpanishModelState(
        status: ModelDownloadStatus.completed,
        progressMessage: 'Download completed successfully!',
      );

      expect(notifier.state.status, ModelDownloadStatus.completed);
      expect(notifier.state.progressMessage, 'Download completed successfully!');
      expect(notifier.state.errorMessage, isNull);
    });

    test('should update state to failed on download error', () {
      final notifier = SpanishModelNotifier();

      const errorMessage = 'Network timeout';

      notifier.state = const SpanishModelState(
        status: ModelDownloadStatus.failed,
        errorMessage: errorMessage,
      );

      expect(notifier.state.status, ModelDownloadStatus.failed);
      expect(notifier.state.errorMessage, errorMessage);
      expect(notifier.state.progressMessage, isNull);
    });

    test('should reset to notStarted state', () {
      final notifier = SpanishModelNotifier();

      // Set to completed state
      notifier.state = const SpanishModelState(
        status: ModelDownloadStatus.completed,
      );

      expect(notifier.state.status, ModelDownloadStatus.completed);

      // Reset
      notifier.reset();

      expect(notifier.state.status, ModelDownloadStatus.notStarted);
      expect(notifier.state.progressMessage, isNull);
      expect(notifier.state.errorMessage, isNull);
    });

    test('should copy state correctly with copyWith method', () {
      const initialState = SpanishModelState(
        status: ModelDownloadStatus.inProgress,
        progressMessage: 'Downloading...',
      );

      final newState = initialState.copyWith(
        progressMessage: 'Almost done...',
      );

      expect(newState.status, ModelDownloadStatus.inProgress);
      expect(newState.progressMessage, 'Almost done...');
    });

    test('should handle multiple state transitions', () {
      final notifier = SpanishModelNotifier();

      // notStarted -> inProgress
      notifier.state = const SpanishModelState(
        status: ModelDownloadStatus.inProgress,
        progressMessage: 'Starting...',
      );
      expect(notifier.state.status, ModelDownloadStatus.inProgress);

      // inProgress -> completed
      notifier.state = const SpanishModelState(
        status: ModelDownloadStatus.completed,
        progressMessage: 'Done!',
      );
      expect(notifier.state.status, ModelDownloadStatus.completed);
    });

    test('should preserve progress message during error state', () {
      final notifier = SpanishModelNotifier();

      notifier.state = const SpanishModelState(
        status: ModelDownloadStatus.failed,
        errorMessage: 'Connection failed',
        progressMessage: 'Was downloading...',
      );

      expect(notifier.state.status, ModelDownloadStatus.failed);
      expect(notifier.state.errorMessage, 'Connection failed');
      expect(notifier.state.progressMessage, 'Was downloading...');
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

  group('SpanishModelState Tests', () {
    test('should create state with all fields', () {
      const state = SpanishModelState(
        status: ModelDownloadStatus.inProgress,
        progressMessage: 'Downloading model...',
        errorMessage: null,
      );

      expect(state.status, ModelDownloadStatus.inProgress);
      expect(state.progressMessage, 'Downloading model...');
      expect(state.errorMessage, isNull);
    });

    test('should create state with error message', () {
      const state = SpanishModelState(
        status: ModelDownloadStatus.failed,
        errorMessage: 'Download failed',
      );

      expect(state.status, ModelDownloadStatus.failed);
      expect(state.errorMessage, 'Download failed');
    });

    test('should copy state preserving null fields', () {
      const initialState = SpanishModelState(
        status: ModelDownloadStatus.notStarted,
      );

      final newState = initialState.copyWith(
        status: ModelDownloadStatus.completed,
      );

      expect(newState.status, ModelDownloadStatus.completed);
      expect(newState.progressMessage, isNull);
      expect(newState.errorMessage, isNull);
    });

    test('should handle copyWith with all parameters', () {
      const initialState = SpanishModelState(
        status: ModelDownloadStatus.inProgress,
        progressMessage: 'Initial message',
        errorMessage: 'Initial error',
      );

      final newState = initialState.copyWith(
        status: ModelDownloadStatus.completed,
        progressMessage: 'New message',
        errorMessage: 'New error',
      );

      expect(newState.status, ModelDownloadStatus.completed);
      expect(newState.progressMessage, 'New message');
      expect(newState.errorMessage, 'New error');
    });

    test('should handle copyWith with partial parameters', () {
      const initialState = SpanishModelState(
        status: ModelDownloadStatus.inProgress,
        progressMessage: 'Downloading...',
        errorMessage: null,
      );

      final newState = initialState.copyWith(
        progressMessage: 'Almost done...',
      );

      expect(newState.status, ModelDownloadStatus.inProgress);
      expect(newState.progressMessage, 'Almost done...');
      expect(newState.errorMessage, isNull);
    });

    test('should be immutable with copyWith', () {
      const state1 = SpanishModelState(
        status: ModelDownloadStatus.notStarted,
      );

      final state2 = state1.copyWith(status: ModelDownloadStatus.completed);

      // Original state should be unchanged
      expect(state1.status, ModelDownloadStatus.notStarted);
      // New state should have new value
      expect(state2.status, ModelDownloadStatus.completed);
    });
  });
}
