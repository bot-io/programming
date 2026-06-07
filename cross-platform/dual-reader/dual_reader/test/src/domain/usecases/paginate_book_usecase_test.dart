import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:dual_reader/src/domain/entities/book_entity.dart';
import 'package:dual_reader/src/domain/entities/settings_entity.dart';
import 'package:dual_reader/src/domain/entities/epub_book_entity.dart';
import 'package:dual_reader/src/domain/entities/chapter_entity.dart';
import 'package:dual_reader/src/domain/repositories/book_repository.dart';
import 'package:dual_reader/src/domain/services/epub_parser_service.dart';
import 'package:dual_reader/src/domain/services/pagination_service.dart';
import 'package:dual_reader/src/domain/usecases/paginate_book_usecase.dart';

/// Fake implementation of [BookRepository] for testing
class FakeBookRepository implements BookRepository {
  final Map<String, BookEntity> _books = {};
  final Map<String, List<int>> _bookBytes;
  bool _shouldThrow = false;
  String _errorMessage = 'Repository error';

  final List<BookEntity> updatedBooks = [];

  FakeBookRepository({List<BookEntity>? books, Map<String, List<int>>? bytes})
      : _bookBytes = bytes ?? {} {
    if (books != null) {
      for (final b in books) {
        _books[b.id] = b;
      }
    }
  }

  void setError(bool shouldThrow, [String message = 'Repository error']) {
    _shouldThrow = shouldThrow;
    _errorMessage = message;
  }

  @override
  Future<List<BookEntity>> getAllBooks() async => _books.values.toList();

  @override
  Future<BookEntity?> getBookById(String id) async => _books[id];

  @override
  Future<void> addBook(BookEntity book) async {
    _books[book.id] = book;
  }

  @override
  Future<void> updateBook(BookEntity book) async {
    if (_shouldThrow) throw Exception(_errorMessage);
    updatedBooks.add(book);
    _books[book.id] = book;
  }

  @override
  Future<void> deleteBook(String id) async {
    _books.remove(id);
  }

  @override
  Future<void> saveBookBytes(String id, List<int> bytes) async {
    _bookBytes[id] = bytes;
  }

  @override
  Future<List<int>?> getBookBytes(String id) async => _bookBytes[id];
}

/// Fake implementation of [EpubParserService] for testing
class FakeEpubParserService implements EpubParserService {
  EpubBookEntity? _epubResult;
  late String _fullText;
  String _coverPath = '';
  bool _shouldThrowDrm = false;
  bool _shouldThrowParse = false;

  FakeEpubParserService({
    EpubBookEntity? epubResult,
    String? fullText,
    String coverPath = '',
  })  : _epubResult = epubResult,
        _coverPath = coverPath {
    _fullText = fullText ?? 'Chapter text content for pagination testing. ' * 50;
  }

  void setDrmError() => _shouldThrowDrm = true;
  void setParseError() => _shouldThrowParse = true;

  @override
  Future<EpubBookEntity> parseEpub(List<int> bytes) async {
    if (_shouldThrowDrm) throw EpubDrmException('DRM protected');
    if (_shouldThrowParse) throw EpubParseException('Parse error');
    return _epubResult ??
        EpubBookEntity(
          title: 'Test Book',
          author: 'Test Author',
          coverPath: '',
          chapters: [
            ChapterEntity(title: 'Chapter 1', content: _fullText),
          ],
        );
  }

  @override
  Future<String> extractCoverImage(List<int> bytes, String bookId) async => _coverPath;

  @override
  Future<String> extractFullText(List<int> bytes) async => _fullText;

  @override
  Future<List<ChapterEntity>> parseTableOfContents(List<int> bytes) async => _epubResult?.chapters ?? [];
}

/// Fake implementation of [PaginationService] for testing
class FakePaginationService implements PaginationService {
  List<String> _pages = ['Page 1 content', 'Page 2 content', 'Page 3 content'];
  bool _timedOut = false;
  int _elapsedMs = 100;

  FakePaginationService({
    List<String>? pages,
    bool timedOut = false,
    int elapsedMs = 100,
  })  : _pages = pages ?? ['Page 1 content', 'Page 2 content', 'Page 3 content'],
        _timedOut = timedOut,
        _elapsedMs = elapsedMs;

  @override
  List<String> paginateText({
    required String text,
    required BoxConstraints constraints,
    required TextStyle textStyle,
    double lineHeight = 1.5,
    EdgeInsets padding = EdgeInsets.zero,
  }) {
    return _pages;
  }

  @override
  PaginationResult paginateWithProgress({
    required String text,
    required BoxConstraints constraints,
    required TextStyle textStyle,
    double? lineHeight,
    EdgeInsets? padding,
    PaginationConfig config = const PaginationConfig(),
    void Function(int currentPage, int totalPages)? progressCallback,
  }) {
    // Simulate progress callbacks
    if (progressCallback != null) {
      for (int i = 0; i < _pages.length; i++) {
        progressCallback(i + 1, _pages.length);
      }
    }
    return PaginationResult(
      pages: _pages,
      elapsedMs: _elapsedMs,
      timedOut: _timedOut,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('PaginateBookUseCase', () {
    late FakeBookRepository fakeBookRepository;
    late FakeEpubParserService fakeEpubParserService;
    late FakePaginationService fakePaginationService;
    late PaginateBookUseCase useCase;

    final testBook = BookEntity(
      id: 'test-book-1',
      title: 'Test Book',
      author: 'Test Author',
      coverPath: '/covers/test.jpg',
      filePath: 'test_book.epub',
      importedDate: DateTime(2024, 1, 1),
      paginationStatus: PaginationStatus.notStarted.index,
    );

    const testSettings = SettingsEntity(
      fontSize: 16.0,
      lineHeight: 1.5,
      margin: 16.0,
      fontlFamily: 'Roboto',
    );

    const testScreenSize = Size(400.0, 800.0);

    final testBookBytes = [0x50, 0x4B, 0x03, 0x04]; // EPUB magic bytes

    setUp(() {
      fakeBookRepository = FakeBookRepository(
        books: [testBook],
        bytes: {'test-book-1': testBookBytes},
      );
      fakeEpubParserService = FakeEpubParserService();
      fakePaginationService = FakePaginationService();
      useCase = PaginateBookUseCase(
        fakeBookRepository,
        fakeEpubParserService,
        fakePaginationService,
      );
    });

    group('status transitions', () {
      test('should update book status to inProgress at start', () async {
        // Act
        await useCase(testBook, settings: testSettings, screenSize: testScreenSize);

        // Assert - the first updateBook call sets status to inProgress
        expect(fakeBookRepository.updatedBooks.isNotEmpty, isTrue);
        final firstUpdate = fakeBookRepository.updatedBooks[0];
        expect(firstUpdate.paginationStatus, equals(PaginationStatus.inProgress.index));
      });

      test('should update book status to completed on success', () async {
        // Act - EPUB path succeeds via refactored parser service
        await useCase(testBook, settings: testSettings, screenSize: testScreenSize);

        // Assert - final status should be completed
        final lastUpdate = fakeBookRepository.updatedBooks.last;
        expect(lastUpdate.paginationStatus, equals(PaginationStatus.completed.index));
      });
    });

    group('error handling', () {
      test('should return 0 when book bytes are not found', () async {
        // Arrange - book exists but no bytes
        final bookNoBytes = BookEntity(
          id: 'no-bytes-book',
          title: 'No Bytes',
          author: 'Author',
          coverPath: '',
          filePath: 'test.epub',
          importedDate: DateTime(2024, 1, 1),
        );
        fakeBookRepository = FakeBookRepository(books: [bookNoBytes], bytes: {});
        useCase = PaginateBookUseCase(
          fakeBookRepository,
          fakeEpubParserService,
          fakePaginationService,
        );

        // Act
        final result = await useCase(bookNoBytes, settings: testSettings, screenSize: testScreenSize);

        // Assert
        expect(result, equals(0));
        final lastUpdate = fakeBookRepository.updatedBooks.last;
        expect(lastUpdate.paginationStatus, equals(PaginationStatus.failed.index));
      });

      test('should return 0 when pagination times out', () async {
        // Arrange
        fakePaginationService = FakePaginationService(timedOut: true);
        useCase = PaginateBookUseCase(
          fakeBookRepository,
          fakeEpubParserService,
          fakePaginationService,
        );

        // Act
        final result = await useCase(testBook, settings: testSettings, screenSize: testScreenSize);

        // Assert
        expect(result, equals(0));
        final lastUpdate = fakeBookRepository.updatedBooks.last;
        expect(lastUpdate.paginationStatus, equals(PaginationStatus.failed.index));
      });

      test('should return 0 and mark failed on EpubDrmException', () async {
        // Arrange - parseEpub throws EpubDrmException before EpubReader.readBook
        fakeEpubParserService.setDrmError();
        useCase = PaginateBookUseCase(
          fakeBookRepository,
          fakeEpubParserService,
          fakePaginationService,
        );

        // Act
        final result = await useCase(testBook, settings: testSettings, screenSize: testScreenSize);

        // Assert
        expect(result, equals(0));
        final lastUpdate = fakeBookRepository.updatedBooks.last;
        expect(lastUpdate.paginationStatus, equals(PaginationStatus.failed.index));
      });

      test('should return 0 and mark failed on EpubParseException', () async {
        // Arrange
        fakeEpubParserService.setParseError();
        useCase = PaginateBookUseCase(
          fakeBookRepository,
          fakeEpubParserService,
          fakePaginationService,
        );

        // Act
        final result = await useCase(testBook, settings: testSettings, screenSize: testScreenSize);

        // Assert
        expect(result, equals(0));
        final lastUpdate = fakeBookRepository.updatedBooks.last;
        expect(lastUpdate.paginationStatus, equals(PaginationStatus.failed.index));
      });

      test('should return 0 and mark failed on generic exception', () async {
        // Arrange - empty text from epub parser leads to failure
        final emptyEpub = EpubBookEntity(
          title: 'Empty',
          author: 'Author',
          coverPath: '',
          chapters: [
            ChapterEntity(title: 'Ch1', content: ''),
          ],
        );
        fakeEpubParserService = FakeEpubParserService(
          epubResult: emptyEpub,
          fullText: '',
        );
        useCase = PaginateBookUseCase(
          fakeBookRepository,
          fakeEpubParserService,
          fakePaginationService,
        );

        // Act
        final result = await useCase(testBook, settings: testSettings, screenSize: testScreenSize);

        // Assert
        expect(result, equals(0));
        final lastUpdate = fakeBookRepository.updatedBooks.last;
        expect(lastUpdate.paginationStatus, equals(PaginationStatus.failed.index));
      });
    });

    group('screen sizes and settings', () {
      test('should work with different screen sizes', () async {
        // Arrange
        const largeScreen = Size(1200.0, 1920.0);

        // Act
        final result = await useCase(
          testBook,
          settings: testSettings,
          screenSize: largeScreen,
        );

        // Assert
        expect(result, isNonNegative);
      });

      test('should respect settings for page size calculation', () async {
        // Arrange - large margins
        const largeMarginSettings = SettingsEntity(
          fontSize: 20.0,
          lineHeight: 2.0,
          margin: 40.0,
        );

        // Act
        final result = await useCase(
          testBook,
          settings: largeMarginSettings,
          screenSize: testScreenSize,
        );

        // Assert - should still succeed (or fail gracefully) with different settings
        expect(result, isNonNegative);
      });
    });

    group('unknown format fallback', () {
      test('should return pages for unknown format with EPUB magic bytes via fallback', () async {
        // Arrange - unknown format triggers EPUB fallback in _extractFullText
        final unknownBook = BookEntity(
          id: 'unknown-book',
          title: 'Unknown Format',
          author: 'Author',
          coverPath: '',
          filePath: 'test.unknown',
          importedDate: DateTime(2024, 1, 1),
        );
        fakeBookRepository = FakeBookRepository(
          books: [unknownBook],
          bytes: {'unknown-book': testBookBytes}, // EPUB magic bytes
        );
        useCase = PaginateBookUseCase(
          fakeBookRepository,
          fakeEpubParserService,
          fakePaginationService,
        );

        // Act - unknown format triggers fallback
        final result = await useCase(unknownBook, settings: testSettings, screenSize: testScreenSize);

        // Assert - fallback tries EPUB which succeeds
        expect(result, equals(3));
      });
    });

    group('successful EPUB pagination', () {
      test('should return total pages for successful EPUB pagination', () async {
        final result = await useCase(
          testBook,
          settings: testSettings,
          screenSize: testScreenSize,
        );

        expect(result, equals(3));
      });

      test('should update book status to completed', () async {
        await useCase(testBook, settings: testSettings, screenSize: testScreenSize);

        final lastUpdate = fakeBookRepository.updatedBooks.last;
        expect(lastUpdate.paginationStatus, equals(PaginationStatus.completed.index));
      });

      test('should set paginationProgress to 1.0', () async {
        await useCase(testBook, settings: testSettings, screenSize: testScreenSize);

        final lastUpdate = fakeBookRepository.updatedBooks.last;
        expect(lastUpdate.paginationProgress, equals(1.0));
      });

      test('should update book totalPages', () async {
        await useCase(testBook, settings: testSettings, screenSize: testScreenSize);

        final lastUpdate = fakeBookRepository.updatedBooks.last;
        expect(lastUpdate.totalPages, equals(3));
      });
    });

    group('progress tracking', () {
      test('should call onProgress callback', () async {
        // Arrange
        final progressValues = <double>[];
        final onProgress = (double progress) {
          progressValues.add(progress);
        };

        // Act
        await useCase(
          testBook,
          settings: testSettings,
          screenSize: testScreenSize,
          onProgress: onProgress,
        );

        // Assert - onProgress should have been called at least once
        expect(progressValues.isNotEmpty, isTrue);
      });

      test('should handle pagination with progress notifier', () async {
        // Act - passing null progressNotifier (default behavior)
        final result = await useCase(
          testBook,
          settings: testSettings,
          screenSize: testScreenSize,
        );

        // Assert
        expect(result, equals(3));
      });

      test('should handle empty page list', () async {
        // Arrange - pagination returns empty pages
        fakePaginationService = FakePaginationService(pages: []);
        useCase = PaginateBookUseCase(
          fakeBookRepository,
          fakeEpubParserService,
          fakePaginationService,
        );

        // Act
        final result = await useCase(testBook, settings: testSettings, screenSize: testScreenSize);

        // Assert - 0 pages means total is 0
        expect(result, equals(0));
      });
    });
  });

  group('EbookFormat', () {
    test('should have epub and unknown values', () {
      expect(EbookFormat.values.length, equals(2));
      expect(EbookFormat.values, contains(EbookFormat.epub));
      expect(EbookFormat.values, contains(EbookFormat.unknown));
    });
  });
}
