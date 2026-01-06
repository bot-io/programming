import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:dual_reader/src/data/repositories/book_repository_impl.dart';
import 'package:dual_reader/src/domain/entities/book_entity.dart';
import 'package:uuid/uuid.dart';

void main() {
  group('BookRepositoryImpl', () {
    late BookRepositoryImpl repository;

    setUpAll(() async {
      // Initialize Hive for testing
      Hive.init('test_hive');
      Hive.registerAdapter(BookEntityAdapter());
    });

    setUp(() async {
      repository = BookRepositoryImpl();
      // Clear any existing data
      final box = await Hive.openBox<BookEntity>('books');
      await box.clear();
      final bytesBox = await Hive.openBox<List<int>>('book_bytes');
      await bytesBox.clear();
    });

    tearDown(() async {
      // Clear data after each test
      final box = await Hive.openBox<BookEntity>('books');
      await box.clear();
      await box.close();
      final bytesBox = await Hive.openBox<List<int>>('book_bytes');
      await bytesBox.clear();
      await bytesBox.close();
    });

    tearDownAll(() async {
      await Hive.deleteBoxFromDisk('books');
      await Hive.deleteBoxFromDisk('book_bytes');
      await Hive.close();
    });

    group('getAllBooks', () {
      test('should return empty list when no books exist', () async {
        final result = await repository.getAllBooks();

        expect(result, isEmpty);
      });

      test('should return all books when multiple books exist', () async {
        final book1 = BookEntity(
          id: '1',
          title: 'Book 1',
          author: 'Author 1',
          coverPath: '',
          filePath: '',
          importedDate: DateTime.now(),
        );
        final book2 = BookEntity(
          id: '2',
          title: 'Book 2',
          author: 'Author 2',
          coverPath: '',
          filePath: '',
          importedDate: DateTime.now(),
        );

        await repository.addBook(book1);
        await repository.addBook(book2);

        final result = await repository.getAllBooks();

        expect(result.length, 2);
        expect(result, contains(book1));
        expect(result, contains(book2));
      });
    });

    group('getBookById', () {
      test('should return null when book does not exist', () async {
        final result = await repository.getBookById('nonexistent');

        expect(result, isNull);
      });

      test('should return book when it exists', () async {
        final book = BookEntity(
          id: 'test-id',
          title: 'Test Book',
          author: 'Test Author',
          coverPath: '',
          filePath: '',
          importedDate: DateTime.now(),
        );

        await repository.addBook(book);

        final result = await repository.getBookById('test-id');

        expect(result, isNotNull);
        expect(result!.id, equals('test-id'));
        expect(result.title, equals('Test Book'));
        expect(result.author, equals('Test Author'));
      });
    });

    group('addBook', () {
      test('should add book to repository', () async {
        final book = BookEntity(
          id: 'test-id',
          title: 'Test Book',
          author: 'Test Author',
          coverPath: '',
          filePath: '',
          importedDate: DateTime.now(),
        );

        await repository.addBook(book);

        final result = await repository.getBookById('test-id');

        expect(result, isNotNull);
        expect(result!.title, equals('Test Book'));
      });

      test('should replace existing book with same id', () async {
        final book1 = BookEntity(
          id: 'same-id',
          title: 'Original Title',
          author: 'Original Author',
          coverPath: '',
          filePath: '',
          importedDate: DateTime.now(),
        );

        final book2 = BookEntity(
          id: 'same-id',
          title: 'Updated Title',
          author: 'Updated Author',
          coverPath: '',
          filePath: '',
          importedDate: DateTime.now(),
        );

        await repository.addBook(book1);
        await repository.addBook(book2);

        final result = await repository.getBookById('same-id');

        expect(result, isNotNull);
        expect(result!.title, equals('Updated Title'));
        expect(result.author, equals('Updated Author'));
      });
    });

    group('updateBook', () {
      test('should update existing book', () async {
        final book = BookEntity(
          id: 'test-id',
          title: 'Original Title',
          author: 'Original Author',
          coverPath: '',
          filePath: '',
          importedDate: DateTime.now(),
          currentPage: 0,
        );

        await repository.addBook(book);

        final updatedBook = book.copyWith(
          title: 'Updated Title',
          currentPage: 10,
        );

        await repository.updateBook(updatedBook);

        final result = await repository.getBookById('test-id');

        expect(result, isNotNull);
        expect(result!.title, equals('Updated Title'));
        expect(result.currentPage, equals(10));
      });
    });

    group('deleteBook', () {
      test('should delete existing book', () async {
        final book = BookEntity(
          id: 'test-id',
          title: 'Test Book',
          author: 'Test Author',
          coverPath: '',
          filePath: '',
          importedDate: DateTime.now(),
        );

        await repository.addBook(book);
        await repository.deleteBook('test-id');

        final result = await repository.getBookById('test-id');

        expect(result, isNull);
      });

      test('should not throw error when deleting nonexistent book', () async {
        await repository.deleteBook('nonexistent');
        // If we get here without throwing, the test passes
        expect(true, isTrue);
      });

      test('should delete book bytes when deleting book', () async {
        final book = BookEntity(
          id: 'test-id',
          title: 'Test Book',
          author: 'Test Author',
          coverPath: '',
          filePath: '',
          importedDate: DateTime.now(),
        );

        final bytes = [1, 2, 3, 4, 5];

        await repository.addBook(book);
        await repository.saveBookBytes('test-id', bytes);
        await repository.deleteBook('test-id');

        final result = await repository.getBookBytes('test-id');

        expect(result, isNull);
      });
    });

    group('saveBookBytes and getBookBytes', () {
      test('should save and retrieve book bytes', () async {
        final bookId = 'test-id';
        final bytes = [1, 2, 3, 4, 5];

        await repository.saveBookBytes(bookId, bytes);
        final result = await repository.getBookBytes(bookId);

        expect(result, equals(bytes));
      });

      test('should return null when bytes do not exist', () async {
        final result = await repository.getBookBytes('nonexistent');

        expect(result, isNull);
      });

      test('should overwrite existing bytes', () async {
        final bookId = 'test-id';
        final bytes1 = [1, 2, 3];
        final bytes2 = [4, 5, 6];

        await repository.saveBookBytes(bookId, bytes1);
        await repository.saveBookBytes(bookId, bytes2);

        final result = await repository.getBookBytes(bookId);

        expect(result, equals(bytes2));
      });

      test('should handle empty bytes', () async {
        final bookId = 'test-id';
        final bytes = <int>[];

        await repository.saveBookBytes(bookId, bytes);
        final result = await repository.getBookBytes(bookId);

        expect(result, equals(bytes));
      });

      test('should handle large bytes', () async {
        final bookId = 'test-id';
        final bytes = List.generate(100000, (index) => index % 256);

        await repository.saveBookBytes(bookId, bytes);
        final result = await repository.getBookBytes(bookId);

        expect(result, equals(bytes));
      });
    });

    group('integration - complete book lifecycle', () {
      test('should handle complete book lifecycle', () async {
        final bookId = const Uuid().v4();
        final book = BookEntity(
          id: bookId,
          title: 'Test Book',
          author: 'Test Author',
          coverPath: '',
          filePath: '',
          importedDate: DateTime.now(),
          currentPage: 0,
          totalPages: 100,
        );
        final bytes = [1, 2, 3, 4, 5];

        // Create
        await repository.addBook(book);
        var retrievedBook = await repository.getBookById(bookId);
        expect(retrievedBook, isNotNull);
        expect(retrievedBook!.title, equals('Test Book'));

        // Save bytes
        await repository.saveBookBytes(bookId, bytes);
        var retrievedBytes = await repository.getBookBytes(bookId);
        expect(retrievedBytes, equals(bytes));

        // Update progress
        final updatedBook = book.copyWith(currentPage: 50);
        await repository.updateBook(updatedBook);
        retrievedBook = await repository.getBookById(bookId);
        expect(retrievedBook!.currentPage, equals(50));

        // Verify bytes still exist after update
        retrievedBytes = await repository.getBookBytes(bookId);
        expect(retrievedBytes, equals(bytes));

        // Delete
        await repository.deleteBook(bookId);
        retrievedBook = await repository.getBookById(bookId);
        expect(retrievedBook, isNull);
        retrievedBytes = await repository.getBookBytes(bookId);
        expect(retrievedBytes, isNull);
      });

      test('should handle multiple books independently', () async {
        final book1 = BookEntity(
          id: 'book-1',
          title: 'Book 1',
          author: 'Author 1',
          coverPath: '',
          filePath: '',
          importedDate: DateTime.now(),
        );
        final book2 = BookEntity(
          id: 'book-2',
          title: 'Book 2',
          author: 'Author 2',
          coverPath: '',
          filePath: '',
          importedDate: DateTime.now(),
        );
        final bytes1 = [1, 2, 3];
        final bytes2 = [4, 5, 6];

        await repository.addBook(book1);
        await repository.addBook(book2);
        await repository.saveBookBytes('book-1', bytes1);
        await repository.saveBookBytes('book-2', bytes2);

        final allBooks = await repository.getAllBooks();
        expect(allBooks.length, 2);

        final retrievedBytes1 = await repository.getBookBytes('book-1');
        final retrievedBytes2 = await repository.getBookBytes('book-2');
        expect(retrievedBytes1, equals(bytes1));
        expect(retrievedBytes2, equals(bytes2));

        await repository.deleteBook('book-1');
        final remainingBooks = await repository.getAllBooks();
        expect(remainingBooks.length, 1);
        expect(remainingBooks.first.id, equals('book-2'));

        final remainingBytes = await repository.getBookBytes('book-2');
        expect(remainingBytes, equals(bytes2));
      });
    });
  });
}
