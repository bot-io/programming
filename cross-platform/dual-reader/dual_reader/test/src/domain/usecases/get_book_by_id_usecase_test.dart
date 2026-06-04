import 'package:flutter_test/flutter_test.dart';
import 'package:dual_reader/src/domain/entities/book_entity.dart';
import 'package:dual_reader/src/domain/repositories/book_repository.dart';
import 'package:dual_reader/src/domain/usecases/get_book_by_id_usecase.dart';

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

  @override
  Future<List<BookEntity>> getAllBooks() async => _books.values.toList();

  @override
  Future<BookEntity?> getBookById(String id) async {
    if (_shouldThrow) {
      throw Exception(_errorMessage);
    }
    return _books[id];
  }

  @override
  Future<void> addBook(BookEntity book) async {}

  @override
  Future<void> updateBook(BookEntity book) async {}

  @override
  Future<void> deleteBook(String id) async {}

  @override
  Future<void> saveBookBytes(String id, List<int> bytes) async {}

  @override
  Future<List<int>?> getBookBytes(String id) async => null;
}

void main() {
  group('GetBookByIdUseCase', () {
    late FakeBookRepository fakeBookRepository;
    late GetBookByIdUseCase useCase;

    final testBook = BookEntity(
      id: 'test-book-1',
      title: 'Test Book',
      author: 'Test Author',
      coverPath: '/covers/test.jpg',
      filePath: '/books/test.epub',
      importedDate: DateTime(2024, 1, 1),
      currentPage: 5,
      totalPages: 100,
    );

    setUp(() {
      fakeBookRepository = FakeBookRepository(books: [testBook]);
      useCase = GetBookByIdUseCase(fakeBookRepository);
    });

    test('should return a book when a valid ID is provided', () async {
      // Act
      final result = await useCase('test-book-1');

      // Assert
      expect(result, isNotNull);
      expect(result!.id, equals('test-book-1'));
      expect(result.title, equals('Test Book'));
      expect(result.author, equals('Test Author'));
    });

    test('should return null when book ID does not exist', () async {
      // Act
      final result = await useCase('non-existent-id');

      // Assert
      expect(result, isNull);
    });

    test('should return null for an empty string ID', () async {
      // Act
      final result = await useCase('');

      // Assert
      expect(result, isNull);
    });

    test('should return null when repository has no books', () async {
      // Arrange
      fakeBookRepository = FakeBookRepository(books: []);
      useCase = GetBookByIdUseCase(fakeBookRepository);

      // Act
      final result = await useCase('any-id');

      // Assert
      expect(result, isNull);
    });

    test('should return the correct book from multiple books', () async {
      // Arrange
      final book2 = BookEntity(
        id: 'test-book-2',
        title: 'Second Book',
        author: 'Another Author',
        coverPath: '/covers/2.jpg',
        filePath: '/books/2.epub',
        importedDate: DateTime(2024, 2, 1),
      );
      fakeBookRepository = FakeBookRepository(books: [testBook, book2]);
      useCase = GetBookByIdUseCase(fakeBookRepository);

      // Act
      final result = await useCase('test-book-2');

      // Assert
      expect(result, isNotNull);
      expect(result!.id, equals('test-book-2'));
      expect(result.title, equals('Second Book'));
    });

    test('should propagate exception when repository throws', () async {
      // Arrange
      fakeBookRepository.setError(true, 'Database error');
      useCase = GetBookByIdUseCase(fakeBookRepository);

      // Act & Assert
      expect(
        () => useCase('test-book-1'),
        throwsA(isA<Exception>()),
      );
    });

    test('should return book with all properties intact', () async {
      // Arrange
      final detailedBook = BookEntity(
        id: 'detailed-id',
        title: 'Detailed Book',
        author: 'Detailed Author',
        coverPath: '/covers/detailed.jpg',
        filePath: '/books/detailed.epub',
        importedDate: DateTime(2024, 6, 15),
        currentPage: 42,
        totalPages: 300,
        paginationStatus: PaginationStatus.completed.index,
        paginationProgress: 0.14,
        detectedLanguage: 'en',
        languageDetectionConfidence: 95,
        languageDetectionDate: DateTime(2024, 6, 16),
      );
      fakeBookRepository = FakeBookRepository(books: [detailedBook]);
      useCase = GetBookByIdUseCase(fakeBookRepository);

      // Act
      final result = await useCase('detailed-id');

      // Assert
      expect(result, isNotNull);
      expect(result!.currentPage, equals(42));
      expect(result.totalPages, equals(300));
      expect(result.paginationStatus, equals(PaginationStatus.completed.index));
      expect(result.detectedLanguage, equals('en'));
      expect(result.languageDetectionConfidence, equals(95));
    });

    test('should handle IDs with special characters', () async {
      // Arrange
      final specialBook = BookEntity(
        id: 'book-with-uuid-123e4567-e89b-12d3-a456-426614174000',
        title: 'Special ID Book',
        author: 'Author',
        coverPath: '',
        filePath: '',
        importedDate: DateTime(2024, 1, 1),
      );
      fakeBookRepository = FakeBookRepository(books: [specialBook]);
      useCase = GetBookByIdUseCase(fakeBookRepository);

      // Act
      final result = await useCase('book-with-uuid-123e4567-e89b-12d3-a456-426614174000');

      // Assert
      expect(result, isNotNull);
      expect(result!.title, equals('Special ID Book'));
    });
  });
}
