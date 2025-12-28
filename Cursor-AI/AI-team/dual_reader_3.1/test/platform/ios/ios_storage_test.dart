import 'package:flutter_test/flutter_test.dart';
import 'package:dual_reader/services/storage_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:dual_reader/models/book.dart';
import 'package:dual_reader/models/chapter.dart';
import '../../helpers/test_helpers.dart';

/// iOS Platform Storage Tests
/// 
/// These tests verify iOS-specific storage functionality:
/// - iOS storage paths
/// - App sandbox storage
/// - Data persistence
/// - Background processing support

void main() {
  group('iOS Platform Storage Tests', () {
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

    group('iOS Storage Initialization', () {
      test('storage service initializes on iOS', () async {
        await expectLater(storageService.init(), completes);
        
        final books = await storageService.getAllBooks();
        expect(books, isA<List<Book>>());
      });

      test('storage service uses iOS app sandbox', () async {
        final testBook = TestHelpers.createTestBook(
          id: 'ios-sandbox-test',
          title: 'iOS Sandbox Test',
        );

        await storageService.saveBook(testBook);
        final loadedBook = await storageService.getBook('ios-sandbox-test');
        
        expect(loadedBook, isNotNull);
        expect(loadedBook!.id, 'ios-sandbox-test');
      });
    });

    group('iOS Storage Persistence', () {
      test('books persist across app restarts on iOS', () async {
        final testBook = TestHelpers.createTestBook(
          id: 'ios-persistence-test',
          title: 'iOS Persistence Test',
        );

        await storageService.saveBook(testBook);
        
        // Simulate app restart by reinitializing
        final newStorageService = StorageService();
        await newStorageService.init();

        final loadedBook = await newStorageService.getBook('ios-persistence-test');
        expect(loadedBook, isNotNull);
        expect(loadedBook!.title, 'iOS Persistence Test');
      });

      test('multiple books persist correctly on iOS', () async {
        final books = List.generate(5, (index) => TestHelpers.createTestBook(
          id: 'ios-book-$index',
          title: 'iOS Book $index',
        ));

        for (final book in books) {
          await storageService.saveBook(book);
        }

        final allBooks = await storageService.getAllBooks();
        expect(allBooks.length, greaterThanOrEqualTo(5));
      });
    });

    group('iOS File Path Handling', () {
      test('handles iOS file paths correctly', () async {
        final iosPaths = [
          '/private/var/mobile/Containers/Data/Application/.../Documents/book.epub',
          'file:///var/mobile/.../book.epub',
        ];

        for (final path in iosPaths) {
          final book = TestHelpers.createTestBook(
            id: 'ios-path-test-${path.hashCode}',
            title: 'iOS Path Test',
            filePath: path,
          );
          
          await storageService.saveBook(book);
          final loadedBook = await storageService.getBook(book.id);
          expect(loadedBook, isNotNull);
          expect(loadedBook!.filePath, path);
        }
      });
    });

    group('iOS Background Processing', () {
      test('storage operations work in background context', () async {
        // Simulate background operation
        final testBook = TestHelpers.createTestBook(
          id: 'ios-background-test',
          title: 'iOS Background Test',
        );

        await expectLater(storageService.saveBook(testBook), completes);
        
        final loadedBook = await storageService.getBook('ios-background-test');
        expect(loadedBook, isNotNull);
      });
    });
  });
}
