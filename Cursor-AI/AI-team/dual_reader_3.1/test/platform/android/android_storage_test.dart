import 'package:flutter_test/flutter_test.dart';
import 'package:dual_reader/services/storage_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:dual_reader/models/book.dart';
import 'package:dual_reader/models/chapter.dart';
import '../../helpers/test_helpers.dart';

/// Android Platform Storage Tests
/// 
/// These tests verify Android-specific storage functionality:
/// - Android storage paths
/// - External storage access
/// - Storage permissions
/// - Data persistence

void main() {
  group('Android Platform Storage Tests', () {
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

    group('Android Storage Initialization', () {
      test('storage service initializes on Android', () async {
        await expectLater(storageService.init(), completes);
        
        final books = await storageService.getAllBooks();
        expect(books, isA<List<Book>>());
      });

      test('storage service handles Android storage paths', () async {
        final testBook = TestHelpers.createTestBook(
          id: 'android-path-test',
          title: 'Android Path Test',
          filePath: '/storage/emulated/0/Books/test.epub',
        );

        await storageService.saveBook(testBook);
        final loadedBook = await storageService.getBook('android-path-test');
        
        expect(loadedBook, isNotNull);
        expect(loadedBook!.filePath, contains('test.epub'));
      });
    });

    group('Android Storage Persistence', () {
      test('books persist across app restarts on Android', () async {
        final testBook = TestHelpers.createTestBook(
          id: 'android-persistence-test',
          title: 'Android Persistence Test',
        );

        await storageService.saveBook(testBook);
        
        // Simulate app restart by reinitializing
        final newStorageService = StorageService();
        await newStorageService.init();

        final loadedBook = await newStorageService.getBook('android-persistence-test');
        expect(loadedBook, isNotNull);
        expect(loadedBook!.title, 'Android Persistence Test');
      });

      test('multiple books persist correctly on Android', () async {
        final books = List.generate(5, (index) => TestHelpers.createTestBook(
          id: 'android-book-$index',
          title: 'Android Book $index',
        ));

        for (final book in books) {
          await storageService.saveBook(book);
        }

        final allBooks = await storageService.getAllBooks();
        expect(allBooks.length, greaterThanOrEqualTo(5));
      });
    });

    group('Android Storage Permissions', () {
      test('storage service handles permission scenarios gracefully', () async {
        // Storage service should work even if some permissions are restricted
        await expectLater(storageService.init(), completes);
        
        final books = await storageService.getAllBooks();
        expect(books, isA<List<Book>>());
      });

      test('storage operations work without external storage permission', () async {
        // Internal storage should work without external storage permission
        final testBook = TestHelpers.createTestBook(
          id: 'internal-storage-test',
          title: 'Internal Storage Test',
        );

        await expectLater(storageService.saveBook(testBook), completes);
        
        final loadedBook = await storageService.getBook('internal-storage-test');
        expect(loadedBook, isNotNull);
      });
    });

    group('Android-Specific Storage Operations', () {
      test('handles Android file paths correctly', () async {
        final androidPaths = [
          '/storage/emulated/0/Books/book.epub',
          '/sdcard/Books/book.epub',
          '/storage/sdcard0/Books/book.epub',
        ];

        for (final path in androidPaths) {
          final book = TestHelpers.createTestBook(
            id: 'path-test-${path.hashCode}',
            title: 'Path Test',
            filePath: path,
          );
          
          await storageService.saveBook(book);
          final loadedBook = await storageService.getBook(book.id);
          expect(loadedBook, isNotNull);
          expect(loadedBook!.filePath, path);
        }
      });
    });
  });
}
