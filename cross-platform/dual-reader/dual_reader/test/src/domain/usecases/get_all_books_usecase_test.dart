import 'package:flutter_test/flutter_test.dart';
import 'package:dual_reader/src/domain/entities/book_entity.dart';
import 'package:dual_reader/src/domain/repositories/book_repository.dart';
import 'package:dual_reader/src/domain/usecases/get_all_books_usecase.dart';

/// Fake implementation of [BookRepository] for testing
class FakeBookRepository implements BookRepository {
  final List<BookEntity> _books;
  bool _shouldThrow = false;
  String _errorMessage = 'Repository error';

  FakeBookRepository({List<BookEntity>? books}) : _books = books ?? [];

  /// Configure the fake to throw on the next call
  void setError(bool shouldThrow, [String message = 'Repository error']) {
    _shouldThrow = shouldThrow;
    _errorMessage = message;
  }

  @override
  Future<List<BookEntity>> getAllBooks() async {
    if (_shouldThrow) {
      throw Exception(_errorMessage);
    }
    return List.from(_books);
  }

  @override
  Future<BookEntity?> getBookById(String id) async => null;

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
  group('GetAllBooksUseCase', () {
    late FakeBookRepository fakeBookRepository;
    late GetAllBooksUseCase useCase;

    final testBooks = [
      BookEntity(
        id: '1',
        title: 'Book 1',
        author: 'Author 1',
        coverPath: '/covers/1.jpg',
        filePath: '/books/1.epub',
        importedDate: DateTime(2024, 1, 1),
      ),
      BookEntity(
        id: '2',
        title: 'Book 2',
        author: 'Author 2',
        coverPath: '/covers/2.jpg',
        filePath: '/books/2.epub',
        importedDate: DateTime(2024, 1, 2),
      ),
    ];

    setUp(() {
      fakeBookRepository = FakeBookRepository();
      useCase = GetAllBooksUseCase(fakeBookRepository);
    });

    test('should return a list of books from the repository', () async {
      // Arrange
      fakeBookRepository = FakeBookRepository(books: testBooks);
      useCase = GetAllBooksUseCase(fakeBookRepository);

      // Act
      final result = await useCase();

      // Assert
      expect(result, isA<List<BookEntity>>());
      expect(result.length, equals(2));
      expect(result[0].id, equals('1'));
      expect(result[1].id, equals('2'));
    });

    test('should return an empty list when no books exist', () async {
      // Arrange - default FakeBookRepository has no books
      // Act
      final result = await useCase();

      // Assert
      expect(result, isA<List<BookEntity>>());
      expect(result, isEmpty);
    });

    test('should return a single book when repository has one book', () async {
      // Arrange
      fakeBookRepository = FakeBookRepository(books: [testBooks[0]]);
      useCase = GetAllBooksUseCase(fakeBookRepository);

      // Act
      final result = await useCase();

      // Assert
      expect(result.length, equals(1));
      expect(result[0].title, equals('Book 1'));
    });

    test('should propagate exception when repository throws', () async {
      // Arrange
      fakeBookRepository = FakeBookRepository(books: testBooks);
      fakeBookRepository.setError(true, 'Database connection failed');
      useCase = GetAllBooksUseCase(fakeBookRepository);

      // Act & Assert
      expect(
        () => useCase(),
        throwsA(isA<Exception>()),
      );
    });

    test('should return a new list instance (not the same reference)', () async {
      // Arrange
      fakeBookRepository = FakeBookRepository(books: testBooks);
      useCase = GetAllBooksUseCase(fakeBookRepository);

      // Act
      final result1 = await useCase();
      final result2 = await useCase();

      // Assert
      expect(identical(result1, result2), isFalse);
      expect(result1.length, equals(result2.length));
    });

    test('should return books with correct properties', () async {
      // Arrange
      final bookWithDetails = BookEntity(
        id: 'detailed-book',
        title: 'Detailed Book',
        author: 'Detailed Author',
        coverPath: '/covers/detailed.jpg',
        filePath: '/books/detailed.epub',
        importedDate: DateTime(2024, 6, 15),
        currentPage: 10,
        totalPages: 200,
        paginationStatus: PaginationStatus.completed.index,
        paginationProgress: 0.5,
      );
      fakeBookRepository = FakeBookRepository(books: [bookWithDetails]);
      useCase = GetAllBooksUseCase(fakeBookRepository);

      // Act
      final result = await useCase();

      // Assert
      expect(result.length, equals(1));
      final book = result[0];
      expect(book.id, equals('detailed-book'));
      expect(book.title, equals('Detailed Book'));
      expect(book.author, equals('Detailed Author'));
      expect(book.currentPage, equals(10));
      expect(book.totalPages, equals(200));
      expect(book.paginationStatus, equals(PaginationStatus.completed.index));
      expect(book.paginationProgress, equals(0.5));
    });

    test('should return books with nullable optional fields', () async {
      // Arrange
      final bookWithNulls = BookEntity(
        id: 'nulls-book',
        title: 'Book with nulls',
        author: 'Author',
        coverPath: '',
        filePath: '',
        importedDate: DateTime(2024, 1, 1),
        detectedLanguage: null,
        languageDetectionConfidence: null,
        languageDetectionDate: null,
      );
      fakeBookRepository = FakeBookRepository(books: [bookWithNulls]);
      useCase = GetAllBooksUseCase(fakeBookRepository);

      // Act
      final result = await useCase();

      // Assert
      expect(result.length, equals(1));
      expect(result[0].detectedLanguage, isNull);
      expect(result[0].languageDetectionConfidence, isNull);
      expect(result[0].languageDetectionDate, isNull);
    });
  });
}
