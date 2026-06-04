import 'package:flutter_test/flutter_test.dart';
import 'package:dual_reader/src/domain/entities/book_entity.dart';
import 'package:dual_reader/src/domain/repositories/book_repository.dart';
import 'package:dual_reader/src/domain/usecases/update_book_progress_usecase.dart';

/// Fake implementation of [BookRepository] for testing
class FakeBookRepository implements BookRepository {
  final Map<String, BookEntity> _books;
  bool _shouldThrow = false;
  String _errorMessage = 'Repository error';

  /// Track all updateBook calls for verification
  final List<BookEntity> updatedBooks = [];

  FakeBookRepository({List<BookEntity>? books})
      : _books = {
          for (final b in books ?? <BookEntity>[]) b.id: b,
        };

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
    if (_shouldThrow) {
      throw Exception(_errorMessage);
    }
    updatedBooks.add(book);
    _books[book.id] = book;
  }

  @override
  Future<void> deleteBook(String id) async {
    _books.remove(id);
  }

  @override
  Future<void> saveBookBytes(String id, List<int> bytes) async {}

  @override
  Future<List<int>?> getBookBytes(String id) async => null;
}

void main() {
  group('UpdateBookProgressUseCase', () {
    late FakeBookRepository fakeBookRepository;
    late UpdateBookProgressUseCase useCase;

    final testBook = BookEntity(
      id: 'book-1',
      title: 'Test Book',
      author: 'Test Author',
      coverPath: '/covers/1.jpg',
      filePath: '/books/1.epub',
      importedDate: DateTime(2024, 1, 1),
      currentPage: 0,
      totalPages: 0,
    );

    setUp(() {
      fakeBookRepository = FakeBookRepository(books: [testBook]);
      useCase = UpdateBookProgressUseCase(fakeBookRepository);
    });

    test('should update book with new currentPage and totalPages', () async {
      // Act
      await useCase(book: testBook, currentPage: 10, totalPages: 200);

      // Assert
      expect(fakeBookRepository.updatedBooks.length, equals(1));
      final updated = fakeBookRepository.updatedBooks[0];
      expect(updated.currentPage, equals(10));
      expect(updated.totalPages, equals(200));
    });

    test('should preserve other book properties when updating progress', () async {
      // Act
      await useCase(book: testBook, currentPage: 5, totalPages: 100);

      // Assert
      final updated = fakeBookRepository.updatedBooks[0];
      expect(updated.id, equals('book-1'));
      expect(updated.title, equals('Test Book'));
      expect(updated.author, equals('Test Author'));
      expect(updated.filePath, equals('/books/1.epub'));
    });

    test('should handle page 0 (beginning of book)', () async {
      // Act
      await useCase(book: testBook, currentPage: 0, totalPages: 100);

      // Assert
      final updated = fakeBookRepository.updatedBooks[0];
      expect(updated.currentPage, equals(0));
      expect(updated.totalPages, equals(100));
    });

    test('should handle last page of book', () async {
      // Act
      await useCase(book: testBook, currentPage: 100, totalPages: 100);

      // Assert
      final updated = fakeBookRepository.updatedBooks[0];
      expect(updated.currentPage, equals(100));
      expect(updated.totalPages, equals(100));
    });

    test('should update the book in the repository', () async {
      // Act
      await useCase(book: testBook, currentPage: 50, totalPages: 200);

      // Assert
      final storedBook = await fakeBookRepository.getBookById('book-1');
      expect(storedBook, isNotNull);
      expect(storedBook!.currentPage, equals(50));
      expect(storedBook.totalPages, equals(200));
    });

    test('should propagate exception when repository throws', () async {
      // Arrange
      fakeBookRepository.setError(true, 'Update failed');

      // Act & Assert
      expect(
        () => useCase(book: testBook, currentPage: 1, totalPages: 100),
        throwsA(isA<Exception>()),
      );
    });

    test('should handle multiple updates in sequence', () async {
      // Act
      await useCase(book: testBook, currentPage: 1, totalPages: 100);
      final bookAfterFirst = fakeBookRepository.updatedBooks[0];
      await useCase(book: bookAfterFirst, currentPage: 2, totalPages: 100);
      final bookAfterSecond = fakeBookRepository.updatedBooks[1];

      // Assert
      expect(fakeBookRepository.updatedBooks.length, equals(2));
      expect(bookAfterFirst.currentPage, equals(1));
      expect(bookAfterSecond.currentPage, equals(2));
    });

    test('should handle large page numbers', () async {
      // Act
      await useCase(book: testBook, currentPage: 5000, totalPages: 10000);

      // Assert
      final updated = fakeBookRepository.updatedBooks[0];
      expect(updated.currentPage, equals(5000));
      expect(updated.totalPages, equals(10000));
    });

    test('should update a book with existing progress', () async {
      // Arrange
      final bookWithProgress = testBook.copyWith(
        currentPage: 25,
        totalPages: 100,
        paginationStatus: PaginationStatus.completed.index,
      );

      // Act
      await useCase(book: bookWithProgress, currentPage: 30, totalPages: 100);

      // Assert
      final updated = fakeBookRepository.updatedBooks[0];
      expect(updated.currentPage, equals(30));
      expect(updated.totalPages, equals(100));
      // paginationStatus should be preserved from copyWith behavior
      expect(updated.paginationStatus, equals(PaginationStatus.completed.index));
    });
  });
}
