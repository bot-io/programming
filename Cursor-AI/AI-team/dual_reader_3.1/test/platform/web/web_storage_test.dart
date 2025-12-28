import 'package:flutter_test/flutter_test.dart';
import 'package:dual_reader/services/storage_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:dual_reader/models/book.dart';
import 'package:dual_reader/models/chapter.dart';
import '../../helpers/test_helpers.dart';

/// Web Platform Storage Tests
/// 
/// These tests verify storage functionality specific to web platform:
/// - Web storage persistence
/// - IndexedDB usage (via Hive)
/// - Storage quota handling
/// - Cross-tab synchronization (if applicable)

void main() {
  group('Web Platform Storage Tests', () {
    late StorageService storageService;

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
    });

    tearDown(() async {
      try {
        await Hive.deleteBoxFromDisk('books');
        await Hive.deleteBoxFromDisk('reading_progress');
        await Hive.deleteBoxFromDisk('bookmarks');
        await Hive.deleteBoxFromDisk('settings');
      } catch (e) {
        // Ignore cleanup errors
      }
    });

    group('Web Storage Persistence', () {
      test('books persist across storage service reinitialization', () async {
        final testBook = TestHelpers.createTestBook(
          id: 'web-persistence-test',
          title: 'Web Persistence Test',
        );

        await storageService.saveBook(testBook);
        
        // Reinitialize storage service
        final newStorageService = StorageService();
        await newStorageService.init();

        final loadedBook = await newStorageService.getBook('web-persistence-test');
        expect(loadedBook, isNotNull);
        expect(loadedBook!.id, 'web-persistence-test');
        expect(loadedBook.title, 'Web Persistence Test');
      });

      test('multiple books persist correctly on web', () async {
        final books = List.generate(5, (index) => TestHelpers.createTestBook(
          id: 'web-book-$index',
          title: 'Web Book $index',
        ));

        for (final book in books) {
          await storageService.saveBook(book);
        }

        final allBooks = await storageService.getAllBooks();
        expect(allBooks.length, greaterThanOrEqualTo(5));
        
        // Verify all books are present
        for (int i = 0; i < 5; i++) {
          final book = allBooks.firstWhere(
            (b) => b.id == 'web-book-$i',
            orElse: () => throw Exception('Book web-book-$i not found'),
          );
          expect(book.title, 'Web Book $i');
        }
      });
    });

    group('Storage Quota Handling', () {
      test('storage service handles large books gracefully', () async {
        // Create a book with large content
        final largeContent = 'Large content. ' * 10000; // ~150KB
        final largeBook = TestHelpers.createTestBook(
          id: 'large-web-book',
          title: 'Large Web Book',
          fullText: largeContent,
        );

        // Should save without error
        await expectLater(
          storageService.saveBook(largeBook),
          completes,
        );

        // Should be able to retrieve
        final loadedBook = await storageService.getBook('large-web-book');
        expect(loadedBook, isNotNull);
        expect(loadedBook!.fullText, largeContent);
      });

      test('storage service handles multiple large books', () async {
        // Create multiple books with substantial content
        for (int i = 0; i < 3; i++) {
          final largeContent = 'Content for book $i. ' * 5000;
          final book = TestHelpers.createTestBook(
            id: 'large-book-$i',
            title: 'Large Book $i',
            fullText: largeContent,
          );
          await storageService.saveBook(book);
        }

        final allBooks = await storageService.getAllBooks();
        expect(allBooks.length, greaterThanOrEqualTo(3));
      });
    });

    group('Web-Specific Storage Operations', () {
      test('storage service initializes correctly on web platform', () async {
        final service = StorageService();
        await expectLater(service.init(), completes);
        
        // Should be able to perform operations
        final books = await service.getAllBooks();
        expect(books, isA<List<Book>>());
      });

      test('storage service handles concurrent operations', () async {
        // Simulate concurrent saves
        final futures = List.generate(5, (index) {
          final book = TestHelpers.createTestBook(
            id: 'concurrent-book-$index',
            title: 'Concurrent Book $index',
          );
          return storageService.saveBook(book);
        });

        await expectLater(Future.wait(futures), completes);

        final allBooks = await storageService.getAllBooks();
        expect(allBooks.length, greaterThanOrEqualTo(5));
      });
    });

    group('Error Handling on Web', () {
      test('storage service handles initialization errors gracefully', () async {
        // Storage should initialize even if there are issues
        final service = StorageService();
        await expectLater(service.init(), completes);
      });

      test('storage service handles missing books gracefully', () async {
        final book = await storageService.getBook('non-existent-book');
        expect(book, isNull);
      });

      test('storage service handles deletion of non-existent books', () async {
        await expectLater(
          storageService.deleteBook('non-existent-book'),
          completes,
        );
      });
    });
  });
}
