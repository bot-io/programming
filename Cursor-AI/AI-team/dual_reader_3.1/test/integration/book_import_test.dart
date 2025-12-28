import 'package:flutter_test/flutter_test.dart';
import 'package:dual_reader/providers/book_provider.dart';
import 'package:dual_reader/services/storage_service.dart';
import 'package:dual_reader/services/ebook_parser.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:dual_reader/models/book.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('Book Import Integration Tests', () {
    late StorageService storageService;
    late EbookParser ebookParser;
    late BookProvider bookProvider;

    setUp(() async {
      await Hive.initFlutter();
      
      // Register adapters
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(BookAdapter());
      }
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(ChapterAdapter());
      }

      storageService = StorageService();
      await storageService.init();
      
      ebookParser = EbookParser(storageService);
      bookProvider = BookProvider(storageService, ebookParser);
      
      // Wait for initial load to complete
      await Future.delayed(const Duration(milliseconds: 100));
    });

    tearDown(() async {
      try {
        await Hive.deleteBoxFromDisk('books');
        await Hive.deleteBoxFromDisk('reading_progress');
        await Hive.deleteBoxFromDisk('bookmarks');
      } catch (e) {
        // Ignore cleanup errors
      }
    });

    test('bookProvider initializes with empty library', () async {
      // Wait for async initialization
      await Future.delayed(const Duration(milliseconds: 100));
      
      expect(bookProvider.books, isEmpty);
      expect(bookProvider.isLoading, false);
      expect(bookProvider.error, isNull);
    });

    test('save book to storage and load via provider', () async {
      // Create a test book
      final testBook = TestHelpers.createTestBook(
        id: 'integration-test-1',
        title: 'Integration Test Book',
        author: 'Test Author',
        fullText: TestHelpers.generateTestTextWithParagraphs(5, 50),
      );

      // Save directly to storage
      await storageService.saveBook(testBook);
      
      // Create a new provider instance to trigger load (simulating app restart)
      final newProvider = BookProvider(storageService, ebookParser);
      
      // Wait for async load to complete
      while (newProvider.isLoading) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      
      // Verify book is loaded
      expect(newProvider.books.length, 1);
      expect(newProvider.books.first.id, 'integration-test-1');
      expect(newProvider.books.first.title, 'Integration Test Book');
      expect(newProvider.books.first.author, 'Test Author');
    });

    test('import flow: save book → verify in storage → verify in provider', () async {
      // Step 1: Create and save book
      final testBook = TestHelpers.createTestBook(
        id: 'import-flow-1',
        title: 'Import Flow Book',
        author: 'Flow Author',
        format: 'epub',
        fullText: TestHelpers.generateTestTextWithParagraphs(10, 100),
      );

      await storageService.saveBook(testBook);

      // Step 2: Verify in storage directly
      final savedBook = await storageService.getBook('import-flow-1');
      expect(savedBook, isNotNull);
      expect(savedBook!.title, 'Import Flow Book');
      expect(savedBook.format, 'epub');

      // Step 3: Verify in provider (create new instance to trigger load)
      final newProvider = BookProvider(storageService, ebookParser);
      while (newProvider.isLoading) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      expect(newProvider.books.length, 1);
      expect(newProvider.books.first.id, 'import-flow-1');
    });

    test('import multiple books and verify all are loaded', () async {
      // Create multiple test books
      final book1 = TestHelpers.createTestBook(
        id: 'multi-import-1',
        title: 'Book One',
        fullText: TestHelpers.generateTestTextWithParagraphs(5, 50),
      );
      final book2 = TestHelpers.createTestBook(
        id: 'multi-import-2',
        title: 'Book Two',
        fullText: TestHelpers.generateTestTextWithParagraphs(5, 50),
      );
      final book3 = TestHelpers.createTestBook(
        id: 'multi-import-3',
        title: 'Book Three',
        fullText: TestHelpers.generateTestTextWithParagraphs(5, 50),
      );

      // Save all books
      await storageService.saveBook(book1);
      await storageService.saveBook(book2);
      await storageService.saveBook(book3);

      // Reload in provider (create new instance)
      final newProvider = BookProvider(storageService, ebookParser);
      while (newProvider.isLoading) {
        await Future.delayed(const Duration(milliseconds: 50));
      }

      // Verify all books are loaded
      expect(newProvider.books.length, 3);
      expect(newProvider.books.any((b) => b.id == 'multi-import-1'), true);
      expect(newProvider.books.any((b) => b.id == 'multi-import-2'), true);
      expect(newProvider.books.any((b) => b.id == 'multi-import-3'), true);
    });

    test('delete book and verify removal from storage and provider', () async {
      // Create and save book
      final testBook = TestHelpers.createTestBook(
        id: 'delete-test-1',
        title: 'Delete Test Book',
        fullText: TestHelpers.generateTestTextWithParagraphs(5, 50),
      );

      await storageService.saveBook(testBook);
      final providerForDelete = BookProvider(storageService, ebookParser);
      while (providerForDelete.isLoading) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      expect(providerForDelete.books.length, 1);

      // Delete book
      await providerForDelete.deleteBook('delete-test-1');
      
      // Wait for delete to complete
      while (providerForDelete.isLoading) {
        await Future.delayed(const Duration(milliseconds: 50));
      }

      // Verify removed from provider
      expect(providerForDelete.books.length, 0);

      // Verify removed from storage
      final deletedBook = await storageService.getBook('delete-test-1');
      expect(deletedBook, isNull);
    });

    test('import EPUB format book', () async {
      final epubBook = TestHelpers.createTestBook(
        id: 'epub-import-1',
        title: 'EPUB Test Book',
        format: 'epub',
        fullText: TestHelpers.generateTestTextWithParagraphs(8, 80),
      );

      await storageService.saveBook(epubBook);
      final newProvider = BookProvider(storageService, ebookParser);
      while (newProvider.isLoading) {
        await Future.delayed(const Duration(milliseconds: 50));
      }

      expect(newProvider.books.length, 1);
      expect(newProvider.books.first.format, 'epub');
    });

    test('import MOBI format book', () async {
      final mobiBook = TestHelpers.createTestBook(
        id: 'mobi-import-1',
        title: 'MOBI Test Book',
        format: 'mobi',
        fullText: TestHelpers.generateTestTextWithParagraphs(8, 80),
      );

      await storageService.saveBook(mobiBook);
      final newProvider = BookProvider(storageService, ebookParser);
      while (newProvider.isLoading) {
        await Future.delayed(const Duration(milliseconds: 50));
      }

      expect(newProvider.books.length, 1);
      expect(newProvider.books.first.format, 'mobi');
    });

    test('book with chapters is properly stored and loaded', () async {
      final chapters = [
        TestHelpers.createTestChapter(
          id: 'chapter-1',
          title: 'Chapter One',
          startIndex: 0,
          endIndex: 500,
          bookId: 'chapter-book-1',
        ),
        TestHelpers.createTestChapter(
          id: 'chapter-2',
          title: 'Chapter Two',
          startIndex: 500,
          endIndex: 1000,
          bookId: 'chapter-book-1',
        ),
      ];

      final bookWithChapters = TestHelpers.createTestBook(
        id: 'chapter-book-1',
        title: 'Book with Chapters',
        chapters: chapters,
        fullText: TestHelpers.generateTestTextWithParagraphs(10, 100),
      );

      await storageService.saveBook(bookWithChapters);
      final newProvider = BookProvider(storageService, ebookParser);
      while (newProvider.isLoading) {
        await Future.delayed(const Duration(milliseconds: 50));
      }

      expect(newProvider.books.length, 1);
      expect(newProvider.books.first.chapters.length, 2);
      expect(newProvider.books.first.chapters.first.title, 'Chapter One');
      expect(newProvider.books.first.chapters.last.title, 'Chapter Two');
    });
  });
}
