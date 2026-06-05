import 'package:flutter_test/flutter_test.dart';
import 'package:dual_reader/src/domain/entities/book_entity.dart';
import 'package:dual_reader/src/presentation/providers/pagination_progress_notifier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PaginationProgressState Tests', () {
    test('should create state with required fields', () {
      const state = PaginationProgressState(
        bookId: 'book-1',
        status: PaginationStatus.inProgress,
        progress: 0.5,
      );

      expect(state.bookId, 'book-1');
      expect(state.status, PaginationStatus.inProgress);
      expect(state.progress, 0.5);
      expect(state.errorMessage, isNull);
      expect(state.totalPages, isNull);
    });

    test('should create state with all fields', () {
      const state = PaginationProgressState(
        bookId: 'book-1',
        status: PaginationStatus.failed,
        progress: 0.3,
        errorMessage: 'Some error',
        totalPages: 200,
      );

      expect(state.bookId, 'book-1');
      expect(state.status, PaginationStatus.failed);
      expect(state.progress, 0.3);
      expect(state.errorMessage, 'Some error');
      expect(state.totalPages, 200);
    });

    test('should create state with default values', () {
      const state = PaginationProgressState(
        bookId: 'book-1',
        status: PaginationStatus.notStarted,
      );

      expect(state.progress, 0.0);
      expect(state.errorMessage, isNull);
      expect(state.totalPages, isNull);
    });

    test('should create notPaginated state via factory', () {
      final state = PaginationProgressState.notPaginated('book-1');

      expect(state.bookId, 'book-1');
      expect(state.status, PaginationStatus.notStarted);
      expect(state.progress, 0.0);
      expect(state.errorMessage, isNull);
      expect(state.totalPages, isNull);
    });

    test('should create inProgress state via factory', () {
      final state = PaginationProgressState.inProgress('book-2', 0.75);

      expect(state.bookId, 'book-2');
      expect(state.status, PaginationStatus.inProgress);
      expect(state.progress, 0.75);
    });

    test('should create completed state via factory', () {
      final state = PaginationProgressState.completed('book-3', 150);

      expect(state.bookId, 'book-3');
      expect(state.status, PaginationStatus.completed);
      expect(state.progress, 1.0);
      expect(state.totalPages, 150);
    });

    test('should create failed state via factory', () {
      final state = PaginationProgressState.failed('book-4', 'Network error');

      expect(state.bookId, 'book-4');
      expect(state.status, PaginationStatus.failed);
      expect(state.errorMessage, 'Network error');
    });

    test('copyWith should update only specified fields', () {
      const state = PaginationProgressState(
        bookId: 'book-1',
        status: PaginationStatus.inProgress,
        progress: 0.5,
        totalPages: 100,
      );

      final copied = state.copyWith(progress: 0.8);

      expect(copied.bookId, 'book-1');
      expect(copied.status, PaginationStatus.inProgress);
      expect(copied.progress, 0.8);
      expect(copied.totalPages, 100);
      expect(copied.errorMessage, isNull);
    });

    test('copyWith should update all fields', () {
      const state = PaginationProgressState(
        bookId: 'book-1',
        status: PaginationStatus.notStarted,
      );

      final copied = state.copyWith(
        bookId: 'book-2',
        status: PaginationStatus.completed,
        progress: 1.0,
        errorMessage: null,
        totalPages: 250,
      );

      expect(copied.bookId, 'book-2');
      expect(copied.status, PaginationStatus.completed);
      expect(copied.progress, 1.0);
      expect(copied.totalPages, 250);
    });

    test('copyWith preserves original immutability', () {
      const state = PaginationProgressState(
        bookId: 'book-1',
        status: PaginationStatus.inProgress,
        progress: 0.5,
      );

      final copied = state.copyWith(progress: 0.9);

      expect(state.progress, 0.5);
      expect(copied.progress, 0.9);
    });
  });

  group('PaginationProgressNotifier Tests', () {
    late PaginationProgressNotifier notifier;

    setUp(() {
      notifier = PaginationProgressNotifier();
    });

    test('should start with empty state map', () {
      expect(notifier.state, isEmpty);
    });

    test('should start pagination for a book', () {
      notifier.startPagination('book-1');

      expect(notifier.state, isNotEmpty);
      expect(notifier.state['book-1'], isNotNull);
      expect(notifier.state['book-1']!.status, PaginationStatus.inProgress);
      expect(notifier.state['book-1']!.progress, 0.0);
      expect(notifier.state['book-1']!.bookId, 'book-1');
    });

    test('should update progress for a book that is in progress', () {
      notifier.startPagination('book-1');
      notifier.updateProgress('book-1', 0.5);

      expect(notifier.state['book-1']!.progress, 0.5);
      expect(notifier.state['book-1']!.status, PaginationStatus.inProgress);
    });

    test('should not update progress for a book that is not in progress', () {
      notifier.startPagination('book-1');
      // Complete the pagination
      notifier.completePagination('book-1', 100);

      // Try to update progress on completed book - should be ignored
      notifier.updateProgress('book-1', 0.7);

      // State should remain completed
      expect(notifier.state['book-1']!.status, PaginationStatus.completed);
      expect(notifier.state['book-1']!.progress, 1.0);
    });

    test('should not update progress for a book that does not exist', () {
      notifier.updateProgress('non-existent', 0.5);

      expect(notifier.state, isEmpty);
    });

    test('should clamp progress values between 0.0 and 1.0', () {
      notifier.startPagination('book-1');

      notifier.updateProgress('book-1', 1.5);
      expect(notifier.state['book-1']!.progress, 1.0);

      notifier.updateProgress('book-1', -0.5);
      expect(notifier.state['book-1']!.progress, 0.0);
    });

    test('should complete pagination for a book', () {
      notifier.startPagination('book-1');
      notifier.updateProgress('book-1', 0.8);
      notifier.completePagination('book-1', 250);

      final progress = notifier.state['book-1']!;
      expect(progress.status, PaginationStatus.completed);
      expect(progress.progress, 1.0);
      expect(progress.totalPages, 250);
      expect(progress.bookId, 'book-1');
    });

    test('should fail pagination for a book', () {
      notifier.startPagination('book-1');
      notifier.failPagination('book-1', 'Parsing failed');

      final progress = notifier.state['book-1']!;
      expect(progress.status, PaginationStatus.failed);
      expect(progress.errorMessage, 'Parsing failed');
      expect(progress.bookId, 'book-1');
    });

    test('should remove a book from tracking', () {
      notifier.startPagination('book-1');
      notifier.startPagination('book-2');

      expect(notifier.state.length, 2);

      notifier.removeBook('book-1');

      expect(notifier.state.length, 1);
      expect(notifier.state.containsKey('book-1'), isFalse);
      expect(notifier.state.containsKey('book-2'), isTrue);
    });

    test('should remove a non-existent book without error', () {
      notifier.startPagination('book-1');
      notifier.removeBook('non-existent');

      expect(notifier.state.length, 1);
      expect(notifier.state.containsKey('book-1'), isTrue);
    });

    test('getBookProgress should return progress for tracked book', () {
      notifier.startPagination('book-1');

      final progress = notifier.getBookProgress('book-1');
      expect(progress, isNotNull);
      expect(progress!.status, PaginationStatus.inProgress);
    });

    test('getBookProgress should return null for untracked book', () {
      final progress = notifier.getBookProgress('non-existent');
      expect(progress, isNull);
    });

    test('isPaginating should return true for in-progress book', () {
      notifier.startPagination('book-1');

      expect(notifier.isPaginating('book-1'), isTrue);
    });

    test('isPaginating should return false for completed book', () {
      notifier.startPagination('book-1');
      notifier.completePagination('book-1', 100);

      expect(notifier.isPaginating('book-1'), isFalse);
    });

    test('isPaginating should return false for untracked book', () {
      expect(notifier.isPaginating('non-existent'), isFalse);
    });

    test('isCompleted should return true for completed book', () {
      notifier.startPagination('book-1');
      notifier.completePagination('book-1', 50);

      expect(notifier.isCompleted('book-1'), isTrue);
    });

    test('isCompleted should return false for in-progress book', () {
      notifier.startPagination('book-1');

      expect(notifier.isCompleted('book-1'), isFalse);
    });

    test('hasFailed should return true for failed book', () {
      notifier.startPagination('book-1');
      notifier.failPagination('book-1', 'Error');

      expect(notifier.hasFailed('book-1'), isTrue);
    });

    test('hasFailed should return false for in-progress book', () {
      notifier.startPagination('book-1');

      expect(notifier.hasFailed('book-1'), isFalse);
    });

    test('hasFailed should return false for untracked book', () {
      expect(notifier.hasFailed('non-existent'), isFalse);
    });

    test('should clear all progress tracking', () {
      notifier.startPagination('book-1');
      notifier.startPagination('book-2');
      notifier.startPagination('book-3');

      expect(notifier.state.length, 3);

      notifier.clear();

      expect(notifier.state, isEmpty);
      expect(notifier.getBookProgress('book-1'), isNull);
      expect(notifier.getBookProgress('book-2'), isNull);
      expect(notifier.getBookProgress('book-3'), isNull);
    });

    test('should handle multiple books independently', () {
      notifier.startPagination('book-1');
      notifier.startPagination('book-2');

      notifier.updateProgress('book-1', 0.3);
      notifier.updateProgress('book-2', 0.7);

      notifier.completePagination('book-1', 100);
      notifier.failPagination('book-2', 'Failed');

      expect(notifier.state['book-1']!.status, PaginationStatus.completed);
      expect(notifier.state['book-1']!.totalPages, 100);
      expect(notifier.state['book-2']!.status, PaginationStatus.failed);
      expect(notifier.state['book-2']!.errorMessage, 'Failed');
    });

    test('should handle full lifecycle: start -> update -> complete', () {
      notifier.startPagination('book-1');
      expect(notifier.isPaginating('book-1'), isTrue);

      notifier.updateProgress('book-1', 0.25);
      expect(notifier.getBookProgress('book-1')!.progress, 0.25);

      notifier.updateProgress('book-1', 0.75);
      expect(notifier.getBookProgress('book-1')!.progress, 0.75);

      notifier.completePagination('book-1', 300);
      expect(notifier.isCompleted('book-1'), isTrue);
      expect(notifier.isPaginating('book-1'), isFalse);
      expect(notifier.getBookProgress('book-1')!.progress, 1.0);
      expect(notifier.getBookProgress('book-1')!.totalPages, 300);
    });

    test('should handle full lifecycle: start -> update -> fail', () {
      notifier.startPagination('book-1');
      notifier.updateProgress('book-1', 0.5);

      notifier.failPagination('book-1', 'Out of memory');

      expect(notifier.hasFailed('book-1'), isTrue);
      expect(notifier.getBookProgress('book-1')!.errorMessage, 'Out of memory');
    });

    test('should allow restarting pagination after completion', () {
      notifier.startPagination('book-1');
      notifier.completePagination('book-1', 100);
      expect(notifier.isCompleted('book-1'), isTrue);

      // Restart
      notifier.startPagination('book-1');
      expect(notifier.isPaginating('book-1'), isTrue);
      expect(notifier.getBookProgress('book-1')!.progress, 0.0);
    });

    test('should allow restarting pagination after failure', () {
      notifier.startPagination('book-1');
      notifier.failPagination('book-1', 'Error');
      expect(notifier.hasFailed('book-1'), isTrue);

      // Restart
      notifier.startPagination('book-1');
      expect(notifier.isPaginating('book-1'), isTrue);
      expect(notifier.getBookProgress('book-1')!.errorMessage, isNull);
    });
  });

  group('PaginationStatus Enum Tests', () {
    test('should have correct number of statuses', () {
      expect(PaginationStatus.values.length, 4);
    });

    test('should contain all required statuses', () {
      expect(PaginationStatus.values, contains(PaginationStatus.notStarted));
      expect(PaginationStatus.values, contains(PaginationStatus.inProgress));
      expect(PaginationStatus.values, contains(PaginationStatus.completed));
      expect(PaginationStatus.values, contains(PaginationStatus.failed));
    });

    test('should have correct index values', () {
      expect(PaginationStatus.notStarted.index, 0);
      expect(PaginationStatus.inProgress.index, 1);
      expect(PaginationStatus.completed.index, 2);
      expect(PaginationStatus.failed.index, 3);
    });
  });
}
