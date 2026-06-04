/// Test data helpers for book-related E2E tests
///
/// Provides test book fixtures and utilities for testing book import,
/// pagination, and library management.

library;

import 'dart:io';
import 'package:dual_reader/src/domain/entities/book_entity.dart';
import 'package:path/path.dart' as path;

/// Test data helpers for book operations
class BookTestData {
  /// Get path to test EPUB file
  static String getTestEpubPath([String filename = 'test_book.epub']) {
    return path.join(
      'test_integration',
      'test_data',
      'books',
      filename,
    );
  }

  /// Get path to test MOBI file
  static String getTestMobiPath([String filename = 'test_book.mobi']) {
    return path.join(
      'test_integration',
      'test_data',
      'books',
      filename,
    );
  }

  /// Get path to invalid/corrupted test file
  static String getInvalidFilePath([String filename = 'invalid.epub']) {
    return path.join(
      'test_integration',
      'test_data',
      'books',
      filename,
    );
  }

  /// Create a minimal test EPUB file for testing
  /// Returns the file path if successful
  static Future<File?> createMinimalTestEpub({String filename = 'minimal_test.epub'}) async {
    try {
      final dir = Directory(path.join('test_integration', 'test_data', 'books'));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final file = File(path.join(dir.path, filename));

      // Create a minimal valid EPUB structure
      // This is a simplified EPUB for testing purposes
      final content = '''
PK-3-4
''';
      // Note: This is placeholder - actual EPUB creation requires proper ZIP structure
      // In real testing, you would use actual EPUB files

      await file.writeAsString(content);
      return file;
    } catch (e) {
      return null;
    }
  }

  /// Create test book entities for state testing
  static BookEntity createTestBook({
    String? id,
    String? title,
    String? author,
    int currentPage = 0,
    int totalPages = 100,
    PaginationStatus status = PaginationStatus.completed,
    double paginationProgress = 1.0,
  }) {
    return BookEntity(
      id: id ?? 'test-book-${DateTime.now().millisecondsSinceEpoch}',
      title: title ?? 'Test Book',
      author: author ?? 'Test Author',
      coverPath: '',
      filePath: getTestEpubPath(),
      importedDate: DateTime.now(),
      currentPage: currentPage,
      totalPages: totalPages,
      paginationStatus: status.index,
      paginationProgress: paginationProgress,
    );
  }

  /// Create a book that is currently paginating
  static BookEntity createPaginatingBook({
    String? id,
    String? title,
    double progress = 0.5,
  }) {
    return createTestBook(
      id: id,
      title: title ?? 'Paginating Book',
      status: PaginationStatus.inProgress,
      paginationProgress: progress,
    );
  }

  /// Create a book that has not been paginated yet
  static BookEntity createNotPaginatedBook({
    String? id,
    String? title,
  }) {
    return createTestBook(
      id: id,
      title: title ?? 'Not Paginated Book',
      status: PaginationStatus.notStarted,
      paginationProgress: 0.0,
    );
  }

  /// Create multiple test books with various states
  static List<BookEntity> createTestLibrary({
    int completedCount = 2,
    int inProgressCount = 1,
    int notStartedCount = 1,
  }) {
    final books = <BookEntity>[];
    var idCounter = 0;

    // Add completed books
    for (int i = 0; i < completedCount; i++) {
      books.add(createTestBook(
        id: 'completed-$idCounter',
        title: 'Completed Book $i',
        status: PaginationStatus.completed,
      ));
      idCounter++;
    }

    // Add in-progress books
    for (int i = 0; i < inProgressCount; i++) {
      final progress = (i + 1) / (inProgressCount + 1);
      books.add(createTestBook(
        id: 'progress-$idCounter',
        title: 'Paginating Book $i',
        status: PaginationStatus.inProgress,
        paginationProgress: progress,
      ));
      idCounter++;
    }

    // Add not started books
    for (int i = 0; i < notStartedCount; i++) {
      books.add(createTestBook(
        id: 'notstarted-$idCounter',
        title: 'Not Started Book $i',
        status: PaginationStatus.notStarted,
      ));
      idCounter++;
    }

    return books;
  }

  /// Sample book titles for testing
  static const List<String> sampleTitles = [
    'The Great Gatsby',
    'To Kill a Mockingbird',
    '1984',
    'Pride and Prejudice',
    'The Catcher in the Rye',
  ];

  /// Sample author names for testing
  static const List<String> sampleAuthors = [
    'F. Scott Fitzgerald',
    'Harper Lee',
    'George Orwell',
    'Jane Austen',
    'J.D. Salinger',
  ];

  /// Get random book title from samples
  static String getRandomTitle() {
    return sampleTitles[(DateTime.now().millisecondsSinceEpoch) % sampleTitles.length];
  }

  /// Get random author from samples
  static String getRandomAuthor() {
    return sampleAuthors[(DateTime.now().millisecondsSinceEpoch) % sampleAuthors.length];
  }

  /// Create test book with sample data
  static BookEntity createSampleBook({
    int? titleIndex,
    int? authorIndex,
  }) {
    final titleIndex = titleIndex ?? 0;
    final authorIndex = authorIndex ?? 0;

    return createTestBook(
      title: sampleTitles[titleIndex % sampleTitles.length],
      author: sampleAuthors[authorIndex % sampleAuthors.length],
    );
  }

  /// Verify book has expected pagination state
  static bool hasPaginationStatus(
    BookEntity book,
    PaginationStatus expectedStatus,
  ) {
    return book.status == expectedStatus;
  }

  /// Calculate pagination progress percentage
  static int getProgressPercentage(double progress) {
    return (progress * 100).round();
  }

  /// Format page display text
  static String formatPageText(int current, int total) {
    return '$current/$total';
  }

  /// Generate expected progress text for book
  static String getExpectedProgressText(BookEntity book) {
    switch (book.status) {
      case PaginationStatus.notStarted:
        return 'Not started';
      case PaginationStatus.inProgress:
        return '${getProgressPercentage(book.paginationProgress)}%';
      case PaginationStatus.completed:
        return '${book.totalPages} pages';
      case PaginationStatus.failed:
        return 'Failed';
    }
  }
}
