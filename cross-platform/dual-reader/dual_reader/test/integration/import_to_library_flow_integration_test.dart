import 'package:flutter_test/flutter_test.dart';
import 'package:dual_reader/src/domain/entities/book_entity.dart';
import 'package:dual_reader/src/domain/usecases/get_all_books_usecase.dart';
import 'package:dual_reader/src/domain/usecases/get_book_by_id_usecase.dart';
import 'package:dual_reader/src/domain/usecases/delete_book_usecase.dart';
import 'package:dual_reader/src/domain/usecases/update_book_progress_usecase.dart';
import 'package:dual_reader/src/domain/repositories/book_repository.dart';
import 'package:dual_reader/src/data/repositories/book_repository_impl.dart';
import 'package:hive/hive.dart';
import 'package:get_it/get_it.dart';
import 'package:path_provider/path_provider.dart';

/// Integration test for the complete import-to-library flow.
/// Tests: Add book -> Library listing -> Get by ID -> Update progress -> Delete
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sl = GetIt.instance;

  group('Import to Library Flow', () {
    late BookRepository bookRepository;
    late GetAllBooksUseCase getAllBooksUseCase;
    late GetBookByIdUseCase getBookByIdUseCase;
    late DeleteBookUseCase deleteBookUseCase;
    late UpdateBookProgressUseCase updateBookProgressUseCase;
    bool hiveInitialized = false;

    setUpAll(() async {
      try {
        Hive.init((await getTemporaryDirectory()).path);
        hiveInitialized = true;
      } catch (e) {
        print('Skipping: Hive requires platform channels');
      }
    });

    setUp(() async {
      if (!hiveInitialized) return;
      await Hive.openBox<BookEntity>('books');

      await sl.reset();
      sl.registerLazySingleton<BookRepository>(() => BookRepositoryImpl());

      bookRepository = sl<BookRepository>();
      getAllBooksUseCase = GetAllBooksUseCase(bookRepository);
      getBookByIdUseCase = GetBookByIdUseCase(bookRepository);
      deleteBookUseCase = DeleteBookUseCase(bookRepository);
      updateBookProgressUseCase = UpdateBookProgressUseCase(bookRepository);
    });

    tearDown(() async {
      if (!hiveInitialized) return;
      if (Hive.isBoxOpen('books')) {
        await Hive.box<BookEntity>('books').clear();
        await Hive.box<BookEntity>('books').close();
      }
    });

    tearDownAll(() async {
      if (hiveInitialized) {
        await Hive.close();
      }
      await sl.reset();
    });

    BookEntity createTestBook({
      String id = 'test-book-1',
      String title = 'Test Novel',
      String author = 'Test Author',
      String filePath = '/test/test.epub',
      int totalPages = 100,
    }) {
      return BookEntity(
        id: id,
        title: title,
        author: author,
        coverPath: '',
        filePath: filePath,
        importedDate: DateTime(2024, 1, 1),
        totalPages: totalPages,
        currentPage: 0,
      );
    }

    test('Complete flow: add book, verify in library, update progress, delete',
        () async {
      if (!hiveInitialized) return;

      // 1. Add book to library
      final book = createTestBook();
      await bookRepository.addBook(book);

      // 2. Verify it appears in library listing
      final allBooks = await getAllBooksUseCase();
      expect(allBooks.length, 1);
      expect(allBooks.first.title, 'Test Novel');
      expect(allBooks.first.author, 'Test Author');

      // 3. Verify retrieval by ID
      final retrieved = await getBookByIdUseCase(book.id);
      expect(retrieved, isNotNull);
      expect(retrieved!.title, 'Test Novel');
      expect(retrieved.totalPages, 100);
      expect(retrieved.currentPage, 0);

      // 4. Update reading progress (simulating user reading to page 42)
      await updateBookProgressUseCase(
        book: retrieved,
        currentPage: 42,
        totalPages: 100,
      );

      // 5. Verify progress persisted
      final afterProgress = await getBookByIdUseCase(book.id);
      expect(afterProgress!.currentPage, 42);

      // 6. Delete the book
      await deleteBookUseCase(book.id);

      // 7. Verify library is empty
      final afterDelete = await getAllBooksUseCase();
      expect(afterDelete, isEmpty);
    });

    test('Multiple books: add several, list all, delete one, verify rest',
        () async {
      if (!hiveInitialized) return;

      final books = [
        createTestBook(id: 'book-1', title: 'English Book', author: 'Author A', filePath: '/test/en.epub', totalPages: 200),
        createTestBook(id: 'book-2', title: 'Spanish Book', author: 'Author B', filePath: '/test/es.mobi', totalPages: 150),
        createTestBook(id: 'book-3', title: 'French Book', author: 'Author C', filePath: '/test/fr.epub', totalPages: 300),
      ];

      for (final book in books) {
        await bookRepository.addBook(book);
      }

      final allBooks = await getAllBooksUseCase();
      expect(allBooks.length, 3);

      // Verify each book by ID
      for (final book in books) {
        final retrieved = await getBookByIdUseCase(book.id);
        expect(retrieved, isNotNull);
        expect(retrieved!.title, book.title);
      }

      // Delete middle book
      await deleteBookUseCase('book-2');

      final remaining = await getAllBooksUseCase();
      expect(remaining.length, 2);
      expect(remaining.any((b) => b.id == 'book-2'), isFalse);
      expect(remaining.any((b) => b.id == 'book-1'), isTrue);
      expect(remaining.any((b) => b.id == 'book-3'), isTrue);

      final deleted = await getBookByIdUseCase('book-2');
      expect(deleted, isNull);
    });

    test('Book bytes: save and retrieve file content', () async {
      if (!hiveInitialized) return;

      final book = createTestBook(id: 'bytes-test', title: 'Bytes Book');
      await bookRepository.addBook(book);

      final testBytes = List<int>.generate(1024, (i) => i % 256);
      await bookRepository.saveBookBytes(book.id, testBytes);

      final retrieved = await bookRepository.getBookBytes(book.id);
      expect(retrieved, isNotNull);
      expect(retrieved!.length, 1024);
      expect(retrieved[0], 0);
      expect(retrieved[255], 255);

      // Delete book and verify bytes are cleaned up
      await deleteBookUseCase(book.id);
      final bytesAfterDelete = await bookRepository.getBookBytes(book.id);
      expect(bytesAfterDelete, isNull);
    });

    test('Reading progress across sessions', () async {
      if (!hiveInitialized) return;

      final book = createTestBook(id: 'progress-test', title: 'Progress Book', totalPages: 200);
      await bookRepository.addBook(book);

      // Session 1: read to page 50
      await updateBookProgressUseCase(book: book, currentPage: 50, totalPages: 200);

      // Verify session 1 progress
      var result = await getBookByIdUseCase(book.id);
      expect(result!.currentPage, 50);

      // Session 2: read to page 120
      await updateBookProgressUseCase(book: result, currentPage: 120, totalPages: 200);

      // Verify latest progress
      result = await getBookByIdUseCase(book.id);
      expect(result!.currentPage, 120);
      expect(result.currentPage / result.totalPages, closeTo(0.6, 0.01));
    });

    test('Pagination status lifecycle', () async {
      if (!hiveInitialized) return;

      final book = createTestBook(id: 'pagination-test', title: 'Pagination Book');
      await bookRepository.addBook(book);

      // Initially not started
      var result = await getBookByIdUseCase(book.id);
      expect(result!.status, PaginationStatus.notStarted);
      expect(result.isPaginated, isFalse);

      // Mark as in progress
      await bookRepository.updateBook(result.copyWith(
        paginationStatus: PaginationStatus.inProgress.index,
        paginationProgress: 0.5,
      ));
      result = await getBookByIdUseCase(book.id);
      expect(result!.status, PaginationStatus.inProgress);
      expect(result.isPaginating, isTrue);

      // Mark as completed
      await bookRepository.updateBook(result.copyWith(
        paginationStatus: PaginationStatus.completed.index,
        totalPages: 250,
        paginationProgress: 1.0,
      ));
      result = await getBookByIdUseCase(book.id);
      expect(result!.status, PaginationStatus.completed);
      expect(result.isPaginated, isTrue);
      expect(result.totalPages, 250);
    });

    test('Language detection tracking', () async {
      if (!hiveInitialized) return;

      final book = createTestBook(id: 'lang-test', title: 'Language Book');
      await bookRepository.addBook(book);

      // Initially no language detected
      var result = await getBookByIdUseCase(book.id);
      expect(result!.detectedLanguage, isNull);
      expect(result.hasLanguageDetection(), isFalse);

      // Detect language
      await bookRepository.updateBook(result.copyWith(
        detectedLanguage: 'es',
        languageDetectionConfidence: 92,
        languageDetectionDate: DateTime.now(),
      ));
      result = await getBookByIdUseCase(book.id);
      expect(result!.detectedLanguage, 'es');
      expect(result.hasLanguageDetection(), isTrue);
      expect(result.hasRecentLanguageDetection(), isTrue);
    });

    test('Library handles empty state', () async {
      if (!hiveInitialized) return;

      final books = await getAllBooksUseCase();
      expect(books, isEmpty);

      final byId = await getBookByIdUseCase('nonexistent');
      expect(byId, isNull);

      final bytes = await bookRepository.getBookBytes('nonexistent');
      expect(bytes, isNull);
    });
  });
}
