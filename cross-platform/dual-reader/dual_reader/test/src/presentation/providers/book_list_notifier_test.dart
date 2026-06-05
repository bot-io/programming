import 'package:flutter_test/flutter_test.dart';
import 'package:dual_reader/src/domain/entities/book_entity.dart';
import 'package:dual_reader/src/domain/usecases/get_all_books_usecase.dart';
import 'package:dual_reader/src/presentation/providers/book_list_notifier.dart';

/// Fake use case that returns a predefined list of books
class FakeGetAllBooksUseCase implements GetAllBooksUseCase {
  final List<BookEntity> _books;
  int callCount = 0;

  FakeGetAllBooksUseCase(this._books);

  @override
  Future<List<BookEntity>> call() async {
    callCount++;
    return _books;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BookListNotifier Tests', () {
    test('should start with empty list and trigger loadBooks on construction', () async {
      final books = [
        BookEntity(
          id: '1',
          title: 'Book A',
          author: 'Author A',
          coverPath: '/covers/a.png',
          filePath: '/books/a.epub',
          importedDate: DateTime(2024),
        ),
      ];

      final useCase = FakeGetAllBooksUseCase(books);
      final notifier = BookListNotifier(useCase);

      // Wait for async _loadBooks to complete
      await Future.delayed(const Duration(milliseconds: 50));

      expect(notifier.state, equals(books));
      expect(useCase.callCount, 1);
    });

    test('should start with empty list before async load completes', () {
      final useCase = FakeGetAllBooksUseCase([]);
      final notifier = BookListNotifier(useCase);

      // Immediately after construction, state should be empty (super([]))
      expect(notifier.state, isEmpty);
    });

    test('should load empty book list', () async {
      final useCase = FakeGetAllBooksUseCase([]);
      final notifier = BookListNotifier(useCase);

      await Future.delayed(const Duration(milliseconds: 50));

      expect(notifier.state, isEmpty);
      expect(useCase.callCount, 1);
    });

    test('should load multiple books', () async {
      final books = [
        BookEntity(
          id: '1',
          title: 'Book 1',
          author: 'Author 1',
          coverPath: '/covers/1.png',
          filePath: '/books/1.epub',
          importedDate: DateTime(2024, 1),
        ),
        BookEntity(
          id: '2',
          title: 'Book 2',
          author: 'Author 2',
          coverPath: '/covers/2.png',
          filePath: '/books/2.epub',
          importedDate: DateTime(2024, 2),
        ),
        BookEntity(
          id: '3',
          title: 'Book 3',
          author: 'Author 3',
          coverPath: '/covers/3.png',
          filePath: '/books/3.epub',
          importedDate: DateTime(2024, 3),
        ),
      ];

      final useCase = FakeGetAllBooksUseCase(books);
      final notifier = BookListNotifier(useCase);

      await Future.delayed(const Duration(milliseconds: 50));

      expect(notifier.state.length, 3);
      expect(notifier.state[0].title, 'Book 1');
      expect(notifier.state[1].title, 'Book 2');
      expect(notifier.state[2].title, 'Book 3');
    });

    test('should refresh books via refreshBooks method', () async {
      final books = [
        BookEntity(
          id: '1',
          title: 'Book A',
          author: 'Author A',
          coverPath: '/covers/a.png',
          filePath: '/books/a.epub',
          importedDate: DateTime(2024),
        ),
      ];

      final useCase = FakeGetAllBooksUseCase(books);
      final notifier = BookListNotifier(useCase);

      await Future.delayed(const Duration(milliseconds: 50));
      expect(useCase.callCount, 1);

      await notifier.refreshBooks();
      expect(useCase.callCount, 2);
      expect(notifier.state, equals(books));
    });

    test('should reflect updated book list after refresh', () async {
      var books = [
        BookEntity(
          id: '1',
          title: 'Original',
          author: 'Author',
          coverPath: '/covers/1.png',
          filePath: '/books/1.epub',
          importedDate: DateTime(2024),
        ),
      ];

      final useCase = _MutableGetAllBooksUseCase(() => books);
      final notifier = BookListNotifier(useCase);

      await Future.delayed(const Duration(milliseconds: 50));
      expect(notifier.state.length, 1);
      expect(notifier.state.first.title, 'Original');

      // Add a new book to the "repository"
      books = [
        ...books,
        BookEntity(
          id: '2',
          title: 'New Book',
          author: 'Author 2',
          coverPath: '/covers/2.png',
          filePath: '/books/2.epub',
          importedDate: DateTime(2024, 2),
        ),
      ];

      await notifier.refreshBooks();
      expect(notifier.state.length, 2);
      expect(notifier.state[1].title, 'New Book');
    });

    test('should handle books with different pagination statuses', () async {
      final books = [
        BookEntity(
          id: '1',
          title: 'Not Started',
          author: 'Author',
          coverPath: '/covers/1.png',
          filePath: '/books/1.epub',
          importedDate: DateTime(2024),
          paginationStatus: 0,
        ),
        BookEntity(
          id: '2',
          title: 'In Progress',
          author: 'Author',
          coverPath: '/covers/2.png',
          filePath: '/books/2.epub',
          importedDate: DateTime(2024),
          paginationStatus: 1,
        ),
        BookEntity(
          id: '3',
          title: 'Completed',
          author: 'Author',
          coverPath: '/covers/3.png',
          filePath: '/books/3.epub',
          importedDate: DateTime(2024),
          paginationStatus: 2,
          totalPages: 100,
        ),
        BookEntity(
          id: '4',
          title: 'Failed',
          author: 'Author',
          coverPath: '/covers/4.png',
          filePath: '/books/4.epub',
          importedDate: DateTime(2024),
          paginationStatus: 3,
        ),
      ];

      final useCase = FakeGetAllBooksUseCase(books);
      final notifier = BookListNotifier(useCase);

      await Future.delayed(const Duration(milliseconds: 50));

      expect(notifier.state.length, 4);
      expect(notifier.state[0].status, PaginationStatus.notStarted);
      expect(notifier.state[1].status, PaginationStatus.inProgress);
      expect(notifier.state[2].status, PaginationStatus.completed);
      expect(notifier.state[3].status, PaginationStatus.failed);
    });
  });
}

/// Mutable use case that calls a function to get books each time
class _MutableGetAllBooksUseCase implements GetAllBooksUseCase {
  final List<BookEntity> Function() _getBooks;

  _MutableGetAllBooksUseCase(this._getBooks);

  @override
  Future<List<BookEntity>> call() async {
    return _getBooks();
  }
}
