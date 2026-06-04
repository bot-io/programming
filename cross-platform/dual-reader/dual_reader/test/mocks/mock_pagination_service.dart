/// Mock Pagination Service
///
/// Provides predictable pagination output for testing.
/// Simulates various pagination scenarios and boundary conditions.

library;

import 'package:dual_reader/src/domain/entities/pagination_result.dart';
import 'package:dual_reader/src/domain/entities/chapter.dart';

/// Mock pagination configuration
class MockPaginationConfig {
  /// Delay before paginating
  final Duration delay;

  /// Pages per chapter (0 = calculate from content)
  final int pagesPerChapter;

  /// Words per page
  final int wordsPerPage;

  /// Whether to simulate errors
  final bool simulateErrors;

  /// Progress callback interval
  final Duration progressInterval;

  const MockPaginationConfig({
    this.delay = Duration.zero,
    this.pagesPerChapter = 0,
    this.wordsPerPage = 250,
    this.simulateErrors = false,
    this.progressInterval = const Duration(milliseconds: 100),
  });

  /// Config for instant pagination
  const MockPaginationConfig.instant() : delay = Duration.zero;

  /// Config for slow pagination (testing timeout)
  const MockPaginationConfig.slow([
    Duration delay = const Duration(seconds: 5),
  ]) : delay = delay;

  /// Config for error simulation
  const MockPaginationConfig.withErrors() : simulateErrors = true;
}

/// Mock pagination service for testing
class MockPaginationService {
  final MockPaginationConfig config;
  int _paginationCount = 0;
  final List<PaginationCall> _calls = [];
  final List<double> _progressUpdates = [];

  MockPaginationService([this.config = const MockPaginationConfig()]);

  /// Get number of paginations performed
  int get paginationCount => _paginationCount;

  /// Get all pagination calls
  List<PaginationCall> get calls => List.unmodifiable(_calls);

  /// Get all progress updates
  List<double> get progressUpdates => List.unmodifiable(_progressUpdates);

  /// Clear call history
  void clearCalls() {
    _calls.clear();
    _paginationCount = 0;
    _progressUpdates.clear();
  }

  /// Paginate a book's content
  Future<PaginationResult> paginateBook({
    required String bookId,
    required List<Chapter> chapters,
    required String content,
    OnProgressCallback? onProgress,
  }) async {
    _paginationCount++;
    final call = PaginationCall(
      bookId: bookId,
      chapterCount: chapters.length,
      timestamp: DateTime.now(),
    );
    _calls.add(call);

    // Simulate delay
    if (config.delay > Duration.zero) {
      final totalDuration = config.delay;
      final steps = (totalDuration.inMilliseconds / config.progressInterval.inMilliseconds).ceil();

      for (int i = 0; i < steps; i++) {
        await Future.delayed(config.progressInterval);
        final progress = (i + 1) / steps;
        _progressUpdates.add(progress);
        onProgress?.call(progress);
      }
    }

    // Check for errors
    if (config.simulateErrors && bookId == 'error-book') {
      throw MockPaginationException('Simulated pagination error for: $bookId');
    }

    // Generate pagination result
    return _generatePaginationResult(bookId, chapters, content);
  }

  /// Repaginate with settings change
  Future<PaginationResult> repaginate({
    required String bookId,
    required List<Chapter> chapters,
    required String content,
    required Map<String, dynamic> settings,
    OnProgressCallback? onProgress,
  }) async {
    _paginationCount++;

    // Simulate repagination (typically faster)
    final delay = Duration(
      microseconds: config.delay.inMicroseconds ~/ 2,
    );

    if (delay > Duration.zero) {
      await Future.delayed(delay);
    }

    return _generatePaginationResult(bookId, chapters, content);
  }

  /// Calculate pages for content
  int calculatePages(String content, {double fontSize = 16.0, double lineHeight = 1.5}) {
    final words = content.split(RegExp(r'\s+'));
    final wordsPerPage = (config.wordsPerPage * (16 / fontSize) * (1.5 / lineHeight)).round();
    return (words.length / wordsPerPage).ceil();
  }

  /// Generate predictable pagination result
  PaginationResult _generatePaginationResult(
    String bookId,
    List<Chapter> chapters,
    String content,
  ) {
    final pages = <PageInfo>[];

    for (int i = 0; i < chapters.length; i++) {
      final chapter = chapters[i];
      final pagesInChapter = config.pagesPerChapter > 0
          ? config.pagesPerChapter
          : 10; // Default

      for (int j = 0; j < pagesInChapter; j++) {
        pages.add(PageInfo(
          chapterIndex: i,
          pageIndex: j,
          globalIndex: pages.length,
          contentOffset: j * 1000,
          contentLength: 1000,
          wordCount: config.wordsPerPage,
        ));
      }
    }

    return PaginationResult(
      bookId: bookId,
      totalPages: pages.length,
      pages: pages,
      metadata: PaginationMetadata(
        bookId: bookId,
        totalPages: pages.length,
        totalChapters: chapters.length,
        averageWordsPerPage: config.wordsPerPage,
        generatedAt: DateTime.now(),
      ),
    );
  }
}

/// Record of a pagination call
class PaginationCall {
  final String bookId;
  final int chapterCount;
  final DateTime timestamp;

  PaginationCall({
    required this.bookId,
    required this.chapterCount,
    required this.timestamp,
  });

  @override
  String toString =>
      'PaginationCall(book: $bookId, chapters: $chapterCount, at: $timestamp)';
}

/// Exception for mock pagination
class MockPaginationException implements Exception {
  final String message;
  MockPaginationException(this.message);

  @override
  String toString() => 'MockPaginationException: $message';
}

/// Progress callback type
typedef OnProgressCallback = void Function(double progress);

/// Factory for creating configured mock pagination services
class MockPaginationServiceFactory {
  /// Create a mock with instant pagination
  static MockPaginationService createInstant() {
    return MockPaginationService(const MockPaginationConfig.instant());
  }

  /// Create a mock with slow pagination
  static MockPaginationService createSlow([Duration delay = const Duration(seconds: 5)]) {
    return MockPaginationService(MockPaginationConfig.slow(delay));
  }

  /// Create a mock that throws errors
  static MockPaginationService createWithErrors() {
    return MockPaginationService(const MockPaginationConfig.withErrors());
  }

  /// Create a mock with custom configuration
  static MockPaginationService createWithConfig(MockPaginationConfig config) {
    return MockPaginationService(config);
  }

  /// Create a mock with specific page count
  static MockPaginationService withPageCount(int pagesPerChapter) {
    return MockPaginationService(MockPaginationConfig(
      pagesPerChapter: pagesPerChapter,
    ));
  }
}
