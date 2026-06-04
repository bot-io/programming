/// Mock Book Repository
///
/// Provides test books on demand for testing.
/// Simulates various book formats and error conditions.

library;

import 'package:dual_reader/src/domain/entities/book.dart';
import 'package:dual_reader/src/domain/entities/chapter.dart';
import 'package:dual_reader/src/domain/entities/book_content.dart';

/// Mock book configuration
class MockBookConfig {
  /// Whether to simulate errors
  final bool simulateErrors;

  /// Delay before returning books
  final Duration loadDelay;

  /// Available test books
  final List<MockBookDefinition> availableBooks;

  const MockBookConfig({
    this.simulateErrors = false,
    this.loadDelay = Duration.zero,
    this.availableBooks = const [],
  });

  /// Config with all test books
  const MockBookConfig.withTestBooks()
      : availableBooks = MockBookFactory.getAllBooks(),
        loadDelay = const Duration(milliseconds: 100);
}

/// Definition of a mock book
class MockBookDefinition {
  final String id;
  final String title;
  final String author;
  final String format;
  final int totalPages;
  final int chapterCount;
  final bool hasImages;
  final String language;

  const MockBookDefinition({
    required this.id,
    required this.title,
    required this.author,
    required this.format,
    this.totalPages = 100,
    this.chapterCount = 10,
    this.hasImages = false,
    this.language = 'en',
  });
}

/// Mock book repository for testing
class MockBookRepository {
  final MockBookConfig config;
  final List<Book> _books = [];
  int _loadCount = 0;

  MockBookRepository([this.config = const MockBookConfig.withTestBooks()]) {
    _initializeBooks();
  }

  void _initializeBooks() {
    for (final bookDef in config.availableBooks) {
      _books.add(_createBook(bookDef));
    }
  }

  /// Get all books
  Future<List<Book>> getAllBooks() async {
    _loadCount++;
    await Future.delayed(config.loadDelay);
    return List.from(_books);
  }

  /// Get book by ID
  Future<Book?> getBookById(String id) async {
    await Future.delayed(config.loadDelay);

    if (config.simulateErrors && id == 'error-book') {
      throw MockBookException('Simulated error for book: $id');
    }

    try {
      return _books.firstWhere((book) => book.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Import book from file
  Future<Book?> importBook(String filePath) async {
    await Future.delayed(config.loadDelay);

    if (config.simulateErrors && filePath.contains('error')) {
      throw MockBookException('Failed to import book: $filePath');
    }

    if (filePath.contains('empty')) {
      return null;
    }

    // Create a book from the file path
    final fileName = filePath.split('/').last.replaceAll('.epub', '').replaceAll('.mobi', '');
    return _createBook(MockBookDefinition(
      id: 'imported-${DateTime.now().millisecondsSinceEpoch}',
      title: _formatTitle(fileName),
      author: 'Imported Author',
      format: filePath.endsWith('.mobi') ? 'MOBI' : 'EPUB',
    ));
  }

  /// Get chapters for a book
  Future<List<Chapter>> getChapters(String bookId) async {
    await Future.delayed(config.loadDelay);

    final book = await getBookById(bookId);
    if (book == null) return [];

    final bookDef = _findBookDefinition(bookId);
    if (bookDef == null) return [];

    return List.generate(
      bookDef.chapterCount,
      (index) => Chapter(
        id: '$bookId-chapter-$index',
        bookId: bookId,
        title: 'Chapter ${index + 1}',
        index: index,
        contentOffset: index * 10000,
        contentLength: 10000,
      ),
    );
  }

  /// Get content for a chapter
  Future<BookContent> getChapterContent(String bookId, int chapterIndex) async {
    await Future.delayed(config.loadDelay);

    final bookDef = _findBookDefinition(bookId);
    if (bookDef == null) {
      throw MockBookException('Book not found: $bookId');
    }

    return _generateChapterContent(bookId, chapterIndex, bookDef);
  }

  /// Delete a book
  Future<bool> deleteBook(String bookId) async {
    await Future.delayed(config.loadDelay);

    if (config.simulateErrors && bookId == 'delete-error') {
      return false;
    }

    _books.removeWhere((book) => book.id == bookId);
    return true;
  }

  /// Update book progress
  Future<void> updateProgress(String bookId, int pageNumber, double progress) async {
    await Future.delayed(const Duration(milliseconds: 50));
    // Simulate progress update
  }

  /// Get load count
  int get loadCount => _loadCount;

  // Helper methods

  Book _createBook(MockBookDefinition def) {
    return Book(
      id: def.id,
      title: def.title,
      author: def.author,
      format: def.format,
      filePath: '/mock/books/${def.id}.${def.format.toLowerCase()}',
      coverPath: def.hasImages ? '/mock/books/${def.id}/cover.jpg' : null,
      totalPages: def.totalPages,
      currentPage: 0,
      progress: 0.0,
      language: def.language,
      addedAt: DateTime.now(),
      lastReadAt: null,
    );
  }

  String _formatTitle(String fileName) {
    return fileName
        .split('-')
        .map((word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  MockBookDefinition? _findBookDefinition(String bookId) {
    try {
      return config.availableBooks.firstWhere((def) => def.id == bookId);
    } catch (e) {
      return null;
    }
  }

  BookContent _generateChapterContent(String bookId, int chapterIndex, MockBookDefinition def) {
    // Generate predictable chapter content
    final paragraphs = <String>[];
    final wordsPerParagraph = 50;

    for (int i = 0; i < 20; i++) {
      final paragraphNumber = chapterIndex * 20 + i;
      paragraphs.add(
        'This is paragraph $paragraphNumber in chapter ${chapterIndex + 1}. ' +
        _generateWords(wordsPerParagraph),
      );
    }

    return BookContent(
      bookId: bookId,
      chapterIndex: chapterIndex,
      title: 'Chapter ${chapterIndex + 1}',
      content: paragraphs.join('\n\n'),
      htmlContent: _generateHtmlContent(paragraphs),
    );
  }

  String _generateWords(int count) {
    final words = <String>[];
    for (int i = 0; i < count; i++) {
      words.add('word${i}_${chapterIndex ?? 0}');
    }
    return words.join(' ') + '.';
  }

  String _generateHtmlContent(List<String> paragraphs) {
    final htmlParagraphs = paragraphs.map((p) => '<p>$p</p>').join('\n');
    return '<div class="chapter-content">\n$htmlParagraphs\n</div>';
  }
}

/// Exception for mock book operations
class MockBookException implements Exception {
  final String message;
  MockBookException(this.message);

  @override
  String toString() => 'MockBookException: $message';
}

/// Factory for creating test books
class MockBookFactory {
  /// Get all available test books
  static const List<MockBookDefinition> getAllBooks() => [
        smallBook,
        mediumBook,
        largeBook,
        singlePageBook,
        multiChapterBook,
        bookWithImages,
        spanishBook,
        chineseBook,
        rtlBook,
        complexFormattingBook,
      ];

  /// Small book (50 pages)
  static const smallBook = MockBookDefinition(
    id: 'small-book',
    title: 'Small Test Book',
    author: 'Test Author',
    format: 'EPUB',
    totalPages: 50,
    chapterCount: 5,
    hasImages: false,
  );

  /// Medium book (100 pages)
  static const mediumBook = MockBookDefinition(
    id: 'medium-book',
    title: 'Medium Test Book',
    author: 'Test Author',
    format: 'EPUB',
    totalPages: 100,
    chapterCount: 10,
    hasImages: false,
  );

  /// Large book (500 pages)
  static const largeBook = MockBookDefinition(
    id: 'large-book',
    title: 'Large Test Book',
    author: 'Test Author',
    format: 'EPUB',
    totalPages: 500,
    chapterCount: 50,
    hasImages: false,
  );

  /// Single page book
  static const singlePageBook = MockBookDefinition(
    id: 'single-page-book',
    title: 'Single Page Book',
    author: 'Test Author',
    format: 'EPUB',
    totalPages: 1,
    chapterCount: 1,
    hasImages: false,
  );

  /// Multi-chapter book
  static const multiChapterBook = MockBookDefinition(
    id: 'multi-chapter-book',
    title: 'Multi Chapter Book',
    author: 'Test Author',
    format: 'EPUB',
    totalPages: 200,
    chapterCount: 20,
    hasImages: false,
  );

  /// Book with images
  static const bookWithImages = MockBookDefinition(
    id: 'book-with-images',
    title: 'Book With Images',
    author: 'Test Author',
    format: 'EPUB',
    totalPages: 30,
    chapterCount: 3,
    hasImages: true,
  );

  /// Spanish book
  static const spanishBook = MockBookDefinition(
    id: 'spanish-book',
    title: 'Libro de Prueba',
    author: 'Autor de Prueba',
    format: 'EPUB',
    totalPages: 100,
    chapterCount: 10,
    hasImages: false,
    language: 'es',
  );

  /// Chinese book
  static const chineseBook = MockBookDefinition(
    id: 'chinese-book',
    title: '测试书籍',
    author: '测试作者',
    format: 'EPUB',
    totalPages: 100,
    chapterCount: 10,
    hasImages: false,
    language: 'zh',
  );

  /// RTL book (Arabic)
  static const rtlBook = MockBookDefinition(
    id: 'rtl-book',
    title: 'كتاب التجريب',
    author: 'مؤلف التجريب',
    format: 'EPUB',
    totalPages: 100,
    chapterCount: 10,
    hasImages: false,
    language: 'ar',
  );

  /// Book with complex formatting
  static const complexFormattingBook = MockBookDefinition(
    id: 'complex-formatting-book',
    title: 'Complex Formatting Book',
    author: 'Test Author',
    format: 'EPUB',
    totalPages: 80,
    chapterCount: 8,
    hasImages: true,
  );

  /// MOBI book
  static const mobiBook = MockBookDefinition(
    id: 'mobi-book',
    title: 'MOBI Test Book',
    author: 'Test Author',
    format: 'MOBI',
    totalPages: 100,
    chapterCount: 10,
    hasImages: false,
  );

  /// Empty book (for error testing)
  static const emptyBook = MockBookDefinition(
    id: 'empty-book',
    title: 'Empty Book',
    author: 'Test Author',
    format: 'EPUB',
    totalPages: 0,
    chapterCount: 0,
    hasImages: false,
  );

  /// Create a custom book
  static MockBookDefinition createCustom({
    required String id,
    required String title,
    required String author,
    String format = 'EPUB',
    int totalPages = 100,
    int chapterCount = 10,
    bool hasImages = false,
    String language = 'en',
  }) {
    return MockBookDefinition(
      id: id,
      title: title,
      author: author,
      format: format,
      totalPages: totalPages,
      chapterCount: chapterCount,
      hasImages: hasImages,
      language: language,
    );
  }

  /// Create a book with specific characteristics
  static MockBookDefinition createWithPages(int pageCount) {
    return MockBookDefinition(
      id: 'book-$pageCount-pages',
      title: 'Book with $pageCount Pages',
      author: 'Test Author',
      format: 'EPUB',
      totalPages: pageCount,
      chapterCount: pageCount ~/ 10,
    );
  }

  /// Create a book with specific chapter count
  static MockBookDefinition createWithChapters(int chapterCount) {
    return MockBookDefinition(
      id: 'book-$chapterCount-chapters',
      title: 'Book with $chapterCount Chapters',
      author: 'Test Author',
      format: 'EPUB',
      totalPages: chapterCount * 10,
      chapterCount: chapterCount,
    );
  }
}
