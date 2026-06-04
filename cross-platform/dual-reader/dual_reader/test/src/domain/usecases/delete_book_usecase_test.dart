import 'package:flutter_test/flutter_test.dart';
import 'package:dual_reader/src/domain/entities/book_entity.dart';
import 'package:dual_reader/src/domain/repositories/book_repository.dart';
import 'package:dual_reader/src/domain/usecases/delete_book_usecase.dart';

/// Fake implementation of [BookRepository] for testing
class FakeBookRepository implements BookRepository {
  final Map<String, BookEntity> _books;
  bool _shouldThrow = false;
  String _errorMessage = 'Repository error';

  FakeBookRepository({List<BookEntity>? books})
      : _books = {
          for (final b in books ?? <BookEntity>[]) b.id: b,
        };

  void setError(bool shouldThrow, [String message = 'Repository error']) {
    _shouldThrow = shouldThrow;
    _errorMessage = message;
  }

  /// Track deleted book IDs
  final List<String> deletedBookIds = [];

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
    _books[book.id] = book;
  }

  @override
  Future<void> deleteBook(String id) async {
    if (_shouldThrow) {
      throw Exception(_errorMessage);
    }
    deletedBookIds.add(id);
    _books.remove(id);
  }

  @override
  Future<void> saveBookBytes(String id, List<int> bytes) async {}

  @override
  Future<List<int>?> getBookBytes(String id) async => null;
}

void main() {
  group('DeleteBookUseCase', () {
    late FakeBookRepository fakeBookRepository;
    late DeleteBookUseCase useCase;

    final testBooks = [
      BookEntity(
        id: 'book-1',
        title: 'Book One',
        author: 'Author One',
        coverPath: '/covers/1.jpg',
        filePath: '/books/1.epub',
        importedDate: DateTime(2024, 1, 1),
      ),
      BookEntity(
        id: 'book-2',
        title: 'Book Two',
        author: 'Author Two',
        coverPath: '/covers/2.jpg',
        filePath: '/books/2.epub',
        importedDate: DateTime(2024, 1, 2),
      ),
    ];

    setUp(() {
      fakeBookRepository = FakeBookRepository(books: testBooks);
      useCase = DeleteBookUseCase(fakeBookRepository);
    });

    test('should delete a book by ID', () async {
      // Act
      await useCase('book-1');

      // Assert
      expect(fakeBookRepository.deletedBookIds, contains('book-1'));
      final remainingBooks = await fakeBookRepository.getAllBooks();
      expect(remainingBooks.length, equals(1));
      expect(remainingBooks[0].id, equals('book-2'));
    });

    test('should complete without error when deleting a non-existent book', () async {
      // Act & Assert - should not throw
      await useCase('non-existent-id');

      expect(fakeBookRepository.deletedBookIds, contains('non-existent-id'));
    });

    test('should delete the correct book from a collection', () async {
      // Act
      await useCase('book-2');

      // Assert
      final remainingBooks = await fakeBookRepository.getAllBooks();
      expect(remainingBooks.length, equals(1));
      expect(remainingBooks[0].id, equals('book-1'));
      expect(remainingBooks[0].title, equals('Book One'));
    });

    test('should propagate exception when repository throws', () async {
      // Arrange
      fakeBookRepository.setError(true, 'Delete failed');

      // Act & Assert
      expect(
        () => useCase('book-1'),
        throwsA(isA<Exception>()),
      );
    });

    test('should handle empty string ID', () async {
      // Act & Assert - should not throw
      await useCase('');
      expect(fakeBookRepository.deletedBookIds, contains(''));
    });

    test('should allow deleting all books sequentially', () async {
      // Act
      await useCase('book-1');
      await useCase('book-2');

      // Assert
      final remainingBooks = await fakeBookRepository.getAllBooks();
      expect(remainingBooks, isEmpty);
      expect(fakeBookRepository.deletedBookIds.length, equals(2));
    });

    test('should complete without error when repository is empty', () async {
      // Arrange
      fakeBookRepository = FakeBookRepository(books: []);
      useCase = DeleteBookUseCase(fakeBookRepository);

      // Act & Assert
      await useCase('any-id');
      expect(fakeBookRepository.deletedBookIds, contains('any-id'));
    });
  });
}
