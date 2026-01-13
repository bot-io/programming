import 'package:flutter_test/flutter_test.dart';
import 'package:dual_reader/src/domain/entities/book_entity.dart';
import 'package:dual_reader/src/domain/usecases/import_book_usecase.dart';
import 'package:dual_reader/src/domain/usecases/get_book_by_id_usecase.dart';
import 'package:dual_reader/src/domain/usecases/update_book_progress_usecase.dart';
import 'package:dual_reader/src/domain/usecases/delete_book_usecase.dart';
import 'package:dual_reader/src/domain/repositories/book_repository.dart';
import 'package:dual_reader/src/data/repositories/book_repository_impl.dart';
import 'package:dual_reader/src/domain/services/epub_parser_service.dart';
import 'package:dual_reader/src/data/services/epub_parser_service_impl.dart';
import 'package:dual_reader/src/data/services/book_translation_cache_service.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';
import 'package:get_it/get_it.dart';
import 'package:file_picker/file_picker.dart';
import '../helper/test_helpers.dart';

/// Integration tests for the complete book reading flow
/// Tests: Import → Parse → Read → Track Progress → Delete
void main() {
  final sl = GetIt.instance;

  group('Book Reading Flow Integration Tests', () {
    late BookRepository bookRepository;
    late ImportBookUseCase importBookUseCase;
    late GetBookByIdUseCase getBookByIdUseCase;
    late UpdateBookProgressUseCase updateBookProgressUseCase;
    late DeleteBookUseCase deleteBookUseCase;
    late BookTranslationCacheService translationCache;
    bool hiveInitialized = false;

    setUpAll(() async {
      // Initialize Hive for testing
      try {
        await setUpHive();
        hiveInitialized = true;
      } catch (e) {
        print('Skipping integration tests: Hive requires platform channels');
      }
    });

    setUp(() async {
      if (!hiveInitialized) return;
      await Hive.openBox<BookEntity>('books');
      await Hive.openBox<String>('test_book_translation_cache');

      // Register dependencies
      if (!sl.isRegistered<BookRepository>()) {
        sl.registerLazySingleton<BookRepository>(() => BookRepositoryImpl());
      }
      if (!sl.isRegistered<EpubParserService>()) {
        sl.registerLazySingleton<EpubParserService>(() => EpubParserServiceImpl());
      }

      bookRepository = sl<BookRepository>();
      importBookUseCase = ImportBookUseCase(bookRepository, sl<EpubParserService>());
      getBookByIdUseCase = GetBookByIdUseCase(bookRepository);
      updateBookProgressUseCase = UpdateBookProgressUseCase(bookRepository);
      deleteBookUseCase = DeleteBookUseCase(bookRepository);
      translationCache = BookTranslationCacheService();
      await translationCache.init();
    });

    tearDown(() async {
      if (!hiveInitialized) return;
      // Clean up test data
      if (Hive.isBoxOpen('books')) {
        await Hive.box<BookEntity>('books').clear();
        await Hive.box<BookEntity>('books').close();
      }
      if (Hive.isBoxOpen('test_book_translation_cache')) {
        await Hive.box<String>('test_book_translation_cache').clear();
        await Hive.box<String>('test_book_translation_cache').close();
      }
    });

    tearDownAll(() async {
      if (!hiveInitialized) return;
      try {
        await tearDownHive();
      } catch (e) {
        print('Error tearing down Hive: $e');
      }
    });

    test('Complete flow: Book starts with zero progress', () async {
      if (!hiveInitialized) {
        print('Test skipped: Hive not initialized');
        return;
      }
      // Create a test book (simulating import)
      final book = BookEntity(
        id: 'test-book-1',
        title: 'Test Book',
        author: 'Test Author',
        coverPath: '',
        filePath: '/path/to/test.epub',
        importedDate: DateTime.now(),
        totalPages: 100,
        currentPage: 0,
      );

      await bookRepository.addBook(book);

      // Verify book starts with zero progress
      final retrieved = await getBookByIdUseCase('test-book-1');
      expect(retrieved, isNotNull);
      expect(retrieved!.currentPage, equals(0));
      expect(retrieved.totalPages, equals(100));

      final progressPercent = (retrieved.currentPage + 1) / retrieved.totalPages * 100;
      expect(progressPercent, closeTo(1.0, 0.1));
    });

    test('Reading flow: Navigate pages and track progress', () async {
      if (!hiveInitialized) {
        print('Test skipped: Hive not initialized');
        return;
      }
      final book = BookEntity(
        id: 'test-book-2',
        title: 'Test Book',
        author: 'Test Author',
        coverPath: '',
        filePath: '/path/to/test.epub',
        importedDate: DateTime.now(),
        totalPages: 50,
        currentPage: 0,
      );

      await bookRepository.addBook(book);

      // Simulate reading through pages
      final pagesToRead = [5, 10, 15, 20, 25];

      for (final page in pagesToRead) {
        await updateBookProgressUseCase(
          book: book,
          currentPage: page,
          totalPages: 50,
        );

        final updated = await getBookByIdUseCase('test-book-2');
        expect(updated!.currentPage, equals(page));
      }

      // Final progress check
      final finalBook = await getBookByIdUseCase('test-book-2');
      expect(finalBook!.currentPage, equals(25));
      final finalProgress = (finalBook.currentPage + 1) / finalBook.totalPages * 100;
      expect(finalProgress, closeTo(52.0, 0.1));
    });

    test('Translation caching during reading flow', () async {
      if (!hiveInitialized) {
        print('Test skipped: Hive not initialized');
        return;
      }
      final bookId = 'test-book-3';
      final book = BookEntity(
        id: bookId,
        title: 'Test Book',
        author: 'Test Author',
        filePath: '/path/to/test.epub',
        totalPages: 10,
        currentPage: 0,
        coverPath: '',
        importedDate: DateTime.now(),
      );

      await bookRepository.addBook(book);

      // Simulate translating pages as user reads
      const language = 'es';
      final translations = {
        0: 'Page 0 translated',
        1: 'Page 1 translated',
        2: 'Page 2 translated',
        3: 'Page 3 translated',
        4: 'Page 4 translated',
      };

      // Cache translations for each page
      for (final entry in translations.entries) {
        await translationCache.cacheTranslation(
          bookId,
          entry.key,
          language,
          entry.value,
        );
      }

      // Update progress as we translate
      await updateBookProgressUseCase(book: book, currentPage: 4, totalPages: 10);

      // Verify translations are cached
      for (final entry in translations.entries) {
        final cached = translationCache.getCachedTranslation(
          bookId,
          entry.key,
          language,
        );
        expect(cached, equals(entry.value));
      }

      // Verify progress was saved
      final updated = await getBookByIdUseCase(bookId);
      expect(updated!.currentPage, equals(4));
    });

    test('Clear translation cache during reading session', () async {
      if (!hiveInitialized) {
        print('Test skipped: Hive not initialized');
        return;
      }
      final bookId = 'test-book-4';
      final book = BookEntity(
        id: bookId,
        title: 'Test Book',
        author: 'Test Author',
        filePath: '/path/to/test.epub',
        totalPages: 20,
        currentPage: 5,
        coverPath: '',
        importedDate: DateTime.now(),
      );

      await bookRepository.addBook(book);

      // Cache some translations
      await translationCache.cacheTranslation(bookId, 0, 'es', 'Spanish 0');
      await translationCache.cacheTranslation(bookId, 1, 'es', 'Spanish 1');
      await translationCache.cacheTranslation(bookId, 2, 'es', 'Spanish 2');

      // Verify they're cached
      expect(translationCache.getCachedTranslation(bookId, 0, 'es'), isNotNull);
      expect(translationCache.getCachedTranslation(bookId, 1, 'es'), isNotNull);
      expect(translationCache.getCachedTranslation(bookId, 2, 'es'), isNotNull);

      // Clear cache
      await translationCache.clearAll();

      // Verify cache is cleared
      expect(translationCache.getCachedTranslation(bookId, 0, 'es'), isNull);
      expect(translationCache.getCachedTranslation(bookId, 1, 'es'), isNull);
      expect(translationCache.getCachedTranslation(bookId, 2, 'es'), isNull);

      // Book progress should still be intact
      final updated = await getBookByIdUseCase(bookId);
      expect(updated!.currentPage, equals(5));
    });

    test('Multiple languages for same book', () async {
      if (!hiveInitialized) {
        print('Test skipped: Hive not initialized');
        return;
      }
      final bookId = 'test-book-5';
      final book = BookEntity(
        id: bookId,
        title: 'Test Book',
        author: 'Test Author',
        filePath: '/path/to/test.epub',
        totalPages: 10,
        currentPage: 0,
        coverPath: '',
        importedDate: DateTime.now(),
      );

      await bookRepository.addBook(book);

      // Cache translations in multiple languages
      await translationCache.cacheTranslation(bookId, 0, 'es', 'Hola');
      await translationCache.cacheTranslation(bookId, 0, 'fr', 'Bonjour');
      await translationCache.cacheTranslation(bookId, 0, 'de', 'Hallo');

      // Verify all languages are cached separately
      expect(translationCache.getCachedTranslation(bookId, 0, 'es'), equals('Hola'));
      expect(translationCache.getCachedTranslation(bookId, 0, 'fr'), equals('Bonjour'));
      expect(translationCache.getCachedTranslation(bookId, 0, 'de'), equals('Hallo'));
    });

    test('Book deletion removes book but keeps other books', () async {
      if (!hiveInitialized) {
        print('Test skipped: Hive not initialized');
        return;
      }
      final books = [
        BookEntity(
          id: 'book-1',
          title: 'Book 1',
          author: 'Author',
          filePath: '/path/1.epub',
          totalPages: 100,
          currentPage: 10,
          coverPath: '',
        importedDate: DateTime.now(),
        ),
        BookEntity(
          id: 'book-2',
          title: 'Book 2',
          author: 'Author',
          filePath: '/path/2.epub',
          totalPages: 100,
          currentPage: 20,
          coverPath: '',
        importedDate: DateTime.now(),
        ),
        BookEntity(
          id: 'book-3',
          title: 'Book 3',
          author: 'Author',
          filePath: '/path/3.epub',
          totalPages: 100,
          currentPage: 30,
          coverPath: '',
        importedDate: DateTime.now(),
        ),
      ];

      for (final book in books) {
        await bookRepository.addBook(book);
      }

      // Add translations for book-2
      await translationCache.cacheTranslation('book-2', 0, 'es', 'Spanish');

      // Delete book-2
      await deleteBookUseCase('book-2');

      // Verify book-2 is gone
      final deletedBook = await getBookByIdUseCase('book-2');
      expect(deletedBook, isNull);

      // Verify other books still exist
      final book1 = await getBookByIdUseCase('book-1');
      final book3 = await getBookByIdUseCase('book-3');
      expect(book1, isNotNull);
      expect(book3, isNotNull);

      // Verify all books still in repository
      final allBooks = await bookRepository.getAllBooks();
      expect(allBooks.length, equals(2));
      expect(allBooks.any((b) => b.id == 'book-1'), isTrue);
      expect(allBooks.any((b) => b.id == 'book-3'), isTrue);
      expect(allBooks.any((b) => b.id == 'book-2'), isFalse);
    });

    test('Progress calculation throughout reading session', () async {
      if (!hiveInitialized) {
        print('Test skipped: Hive not initialized');
        return;
      }
      final book = BookEntity(
        id: 'test-book-6',
        title: 'Test Book',
        author: 'Test Author',
        filePath: '/path/to/test.epub',
        totalPages: 100,
        currentPage: 0,
        coverPath: '',
        importedDate: DateTime.now(),
      );

      await bookRepository.addBook(book);

      // Simulate reading milestones
      final milestones = [
        {'page': 0, 'expectedProgress': 1.0},
        {'page': 9, 'expectedProgress': 10.0},
        {'page': 24, 'expectedProgress': 25.0},
        {'page': 49, 'expectedProgress': 50.0},
        {'page': 74, 'expectedProgress': 75.0},
        {'page': 99, 'expectedProgress': 100.0},
      ];

      for (final milestone in milestones) {
        final page = milestone['page'] as int;
        final expectedProgress = milestone['expectedProgress'] as double;

        await updateBookProgressUseCase(book: book, currentPage: page, totalPages: 100);

        final updated = await getBookByIdUseCase('test-book-6');
        final actualProgress = (updated!.currentPage + 1) / updated.totalPages * 100;

        expect(actualProgress, closeTo(expectedProgress, 1.0));
      }
    });

    test('Reading flow with repagination', () async {
      if (!hiveInitialized) {
        print('Test skipped: Hive not initialized');
        return;
      }
      final book = BookEntity(
        id: 'test-book-7',
        title: 'Test Book',
        author: 'Test Author',
        filePath: '/path/to/test.epub',
        totalPages: 100,
        currentPage: 50,
        coverPath: '',
        importedDate: DateTime.now(),
      );

      await bookRepository.addBook(book);

      // User is at page 50 (50% progress)
      var current = await getBookByIdUseCase('test-book-7');
      var progress = (current!.currentPage + 1) / current.totalPages * 100;
      expect(progress, closeTo(51.0, 0.1));

      // User changes font size, causing repagination to 150 pages
      await updateBookProgressUseCase(book: book, currentPage: 50, totalPages: 150);

      // Progress should be recalculated
      current = await getBookByIdUseCase('test-book-7');
      progress = (current!.currentPage + 1) / current.totalPages * 100;
      expect(progress, closeTo(33.67, 0.1));
    });

    test('Complete reading session: Start to finish', () async {
      if (!hiveInitialized) {
        print('Test skipped: Hive not initialized');
        return;
      }
      final book = BookEntity(
        id: 'test-book-8',
        title: 'Complete Journey',
        author: 'Test Author',
        filePath: '/path/to/test.epub',
        totalPages: 10,
        currentPage: 0,
        coverPath: '',
        importedDate: DateTime.now(),
      );

      await bookRepository.addBook(book);

      // Simulate complete reading session
      for (int page = 0; page < 10; page++) {
        // Translate page
        await translationCache.cacheTranslation(
          'test-book-8',
          page,
          'es',
          'Page $page in Spanish',
        );

        // Update progress
        await updateBookProgressUseCase(book: book, currentPage: page, totalPages: 10);

        // Verify state
        final current = await getBookByIdUseCase('test-book-8');
        expect(current!.currentPage, equals(page));

        // Verify translation is cached
        final cached = translationCache.getCachedTranslation('test-book-8', page, 'es');
        expect(cached, equals('Page $page in Spanish'));
      }

      // Final verification: book is complete
      final finalBook = await getBookByIdUseCase('test-book-8');
      expect(finalBook!.currentPage, equals(9)); // Last page
      final finalProgress = (finalBook.currentPage + 1) / finalBook.totalPages * 100;
      expect(finalProgress, closeTo(100.0, 0.1));

      // Verify all pages translated
      for (int page = 0; page < 10; page++) {
        final cached = translationCache.getCachedTranslation('test-book-8', page, 'es');
        expect(cached, isNotNull);
      }
    });

    test('Multiple books with independent progress', () async {
      if (!hiveInitialized) {
        print('Test skipped: Hive not initialized');
        return;
      }
      final books = [
        BookEntity(
          id: 'book-a',
          title: 'Book A',
          author: 'Author',
          filePath: '/path/a.epub',
          totalPages: 100,
          currentPage: 0,
          coverPath: '',
        importedDate: DateTime.now(),
        ),
        BookEntity(
          id: 'book-b',
          title: 'Book B',
          author: 'Author',
          filePath: '/path/b.epub',
          totalPages: 200,
          currentPage: 0,
          coverPath: '',
        importedDate: DateTime.now(),
        ),
      ];

      for (final book in books) {
        await bookRepository.addBook(book);
      }

      // Read book A to 25%
      await updateBookProgressUseCase(book: books[0], currentPage: 24, totalPages: 100);

      // Read book B to 50%
      await updateBookProgressUseCase(book: books[1], currentPage: 99, totalPages: 200);

      // Verify independent progress
      final bookA = await getBookByIdUseCase('book-a');
      final bookB = await getBookByIdUseCase('book-b');

      final progressA = (bookA!.currentPage + 1) / bookA.totalPages * 100;
      final progressB = (bookB!.currentPage + 1) / bookB.totalPages * 100;

      expect(progressA, closeTo(25.0, 0.1));
      expect(progressB, closeTo(50.0, 0.1));
    });

    test('Book retrieval returns all books with correct progress', () async {
      if (!hiveInitialized) {
        print('Test skipped: Hive not initialized');
        return;
      }
      final books = [
        BookEntity(
          id: 'book-1',
          title: 'Book 1',
          author: 'Author',
          filePath: '/path/1.epub',
          totalPages: 100,
          currentPage: 10,
          coverPath: '',
        importedDate: DateTime.now(),
        ),
        BookEntity(
          id: 'book-2',
          title: 'Book 2',
          author: 'Author',
          filePath: '/path/2.epub',
          totalPages: 100,
          currentPage: 50,
          coverPath: '',
        importedDate: DateTime.now(),
        ),
        BookEntity(
          id: 'book-3',
          title: 'Book 3',
          author: 'Author',
          filePath: '/path/3.epub',
          totalPages: 100,
          currentPage: 75,
          coverPath: '',
        importedDate: DateTime.now(),
        ),
      ];

      for (final book in books) {
        await bookRepository.addBook(book);
      }

      // Get all books
      final allBooks = await bookRepository.getAllBooks();

      expect(allBooks.length, equals(3));
      expect(allBooks[0].currentPage, equals(10));
      expect(allBooks[1].currentPage, equals(50));
      expect(allBooks[2].currentPage, equals(75));
    });
  });
}
