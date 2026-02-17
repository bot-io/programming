import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dual_reader/src/domain/entities/book_entity.dart';

/// State for book pagination progress
class PaginationProgressState {
  final String bookId;
  final PaginationStatus status;
  final double progress; // 0.0 to 1.0
  final String? errorMessage;
  final int? totalPages;

  const PaginationProgressState({
    required this.bookId,
    required this.status,
    this.progress = 0.0,
    this.errorMessage,
    this.totalPages,
  });

  PaginationProgressState copyWith({
    String? bookId,
    PaginationStatus? status,
    double? progress,
    String? errorMessage,
    int? totalPages,
  }) {
    return PaginationProgressState(
      bookId: bookId ?? this.bookId,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      errorMessage: errorMessage ?? this.errorMessage,
      totalPages: totalPages ?? this.totalPages,
    );
  }

  /// Creates a state for a book that's not being paginated
  factory PaginationProgressState.notPaginated(String bookId) {
    return PaginationProgressState(
      bookId: bookId,
      status: PaginationStatus.notStarted,
    );
  }

  /// Creates a state for pagination in progress
  factory PaginationProgressState.inProgress(String bookId, double progress) {
    return PaginationProgressState(
      bookId: bookId,
      status: PaginationStatus.inProgress,
      progress: progress,
    );
  }

  /// Creates a completed state
  factory PaginationProgressState.completed(String bookId, int totalPages) {
    return PaginationProgressState(
      bookId: bookId,
      status: PaginationStatus.completed,
      progress: 1.0,
      totalPages: totalPages,
    );
  }

  /// Creates a failed state
  factory PaginationProgressState.failed(String bookId, String error) {
    return PaginationProgressState(
      bookId: bookId,
      status: PaginationStatus.failed,
      errorMessage: error,
    );
  }
}

/// Notifier for managing book pagination progress
///
/// Tracks pagination status for all books in the library.
/// Each book can be in one of these states:
/// - notStarted: Book imported but not yet paginated
/// - inProgress: Book is currently being paginated
/// - completed: Book pagination finished successfully
/// - failed: Book pagination failed
class PaginationProgressNotifier extends StateNotifier<Map<String, PaginationProgressState>> {
  PaginationProgressNotifier() : super({});

  /// Start pagination for a book
  void startPagination(String bookId) {
    state = {
      ...state,
      bookId: PaginationProgressState.inProgress(bookId, 0.0),
    };
    debugPrint('[PaginationProgress] Started pagination for book: $bookId');
  }

  /// Update pagination progress for a book
  void updateProgress(String bookId, double progress) {
    final current = state[bookId];
    if (current != null && current.status == PaginationStatus.inProgress) {
      state = {
        ...state,
        bookId: current.copyWith(progress: progress.clamp(0.0, 1.0)),
      };
      debugPrint('[PaginationProgress] Updated progress for $bookId: ${(progress * 100).toStringAsFixed(0)}%');
    }
  }

  /// Mark pagination as completed for a book
  void completePagination(String bookId, int totalPages) {
    state = {
      ...state,
      bookId: PaginationProgressState.completed(bookId, totalPages),
    };
    debugPrint('[PaginationProgress] Completed pagination for $bookId: $totalPages pages');
  }

  /// Mark pagination as failed for a book
  void failPagination(String bookId, String error) {
    state = {
      ...state,
      bookId: PaginationProgressState.failed(bookId, error),
    };
    debugPrint('[PaginationProgress] Failed pagination for $bookId: $error');
  }

  /// Remove a book from tracking (e.g., after deletion)
  void removeBook(String bookId) {
    final newState = Map<String, PaginationProgressState>.from(state);
    newState.remove(bookId);
    state = newState;
    debugPrint('[PaginationProgress] Removed book from tracking: $bookId');
  }

  /// Get progress state for a specific book
  PaginationProgressState? getBookProgress(String bookId) {
    return state[bookId];
  }

  /// Check if a book is currently being paginated
  bool isPaginating(String bookId) {
    return state[bookId]?.status == PaginationStatus.inProgress;
  }

  /// Check if a book pagination has completed successfully
  bool isCompleted(String bookId) {
    return state[bookId]?.status == PaginationStatus.completed;
  }

  /// Check if a book pagination has failed
  bool hasFailed(String bookId) {
    return state[bookId]?.status == PaginationStatus.failed;
  }

  /// Clear all progress tracking (useful for testing)
  void clear() {
    state = {};
    debugPrint('[PaginationProgress] Cleared all progress tracking');
  }
}

/// Provider for pagination progress notifier
final paginationProgressProvider = StateNotifierProvider<PaginationProgressNotifier, Map<String, PaginationProgressState>>((ref) {
  return PaginationProgressNotifier();
});

/// Helper provider to get progress for a specific book
final bookPaginationProgressProvider = Provider.family<PaginationProgressState?, String>((ref, bookId) {
  final progressMap = ref.watch(paginationProgressProvider);
  return progressMap[bookId];
});
