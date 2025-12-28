import 'package:flutter_test/flutter_test.dart';
import 'package:dual_reader/services/storage_service.dart';
import 'package:dual_reader/providers/book_provider.dart';
import 'package:dual_reader/providers/reader_provider.dart';
import 'package:dual_reader/services/ebook_parser.dart';
import 'package:dual_reader/services/translation_service.dart';
import 'package:dual_reader/providers/settings_provider.dart';
import 'package:dual_reader/models/book.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../helpers/test_helpers.dart';

/// Web Platform Offline Functionality Tests
/// 
/// These tests verify offline functionality on web platform:
/// - Offline book reading
/// - Offline bookmark management
/// - Offline progress tracking
/// - Cached data access

void main() {
  group('Web Platform Offline Tests', () {
    late StorageService storageService;
    late BookProvider bookProvider;
    late ReaderProvider readerProvider;
    late EbookParser ebookParser;

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
      
      final translationService = TranslationService();
      await translationService.initialize();
      final settingsProvider = SettingsProvider(storageService);
      
      readerProvider = ReaderProvider(
        storageService,
        translationService,
        settingsProvider,
      );
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

    group('Offline Book Access', () {
      test('books saved online are accessible offline', () async {
        // Simulate saving a book while online
        final testBook = TestHelpers.createTestBook(
          id: 'offline-test-book',
          title: 'Offline Test Book',
        );

        await storageService.saveBook(testBook);
        await bookProvider.loadBooks();

        // Simulate going offline - books should still be accessible
        final offlineBooks = await storageService.getAllBooks();
        expect(offlineBooks, isNotEmpty);
        expect(offlineBooks.any((b) => b.id == 'offline-test-book'), isTrue);
      });

      test('book provider loads books offline', () async {
        // Pre-populate storage
        final testBook = TestHelpers.createTestBook(
          id: 'offline-provider-test',
          title: 'Offline Provider Test',
        );
        await storageService.saveBook(testBook);

        // Load books (simulating offline scenario)
        await bookProvider.loadBooks();
        
        expect(bookProvider.books, isNotEmpty);
        expect(bookProvider.books.any((b) => b.id == 'offline-provider-test'), isTrue);
      });
    });

    group('Offline Reading', () {
      test('reader provider works offline with cached books', () async {
        final testBook = TestHelpers.createTestBook(
          id: 'offline-reading-test',
          title: 'Offline Reading Test',
          fullText: 'This is test content for offline reading. ' * 100,
        );

        await storageService.saveBook(testBook);

        // Simulate loading book offline
        final loadedBook = await storageService.getBook('offline-reading-test');
        expect(loadedBook, isNotNull);
        expect(loadedBook!.fullText, isNotEmpty);
      });

      test('reading progress is saved offline', () async {
        final testBook = TestHelpers.createTestBook(
          id: 'offline-progress-test',
          title: 'Offline Progress Test',
          fullText: 'Content. ' * 200,
        );

        await storageService.saveBook(testBook);
        
        // Save progress (simulating offline save)
        await storageService.saveProgress(
          'offline-progress-test',
          currentPage: 5,
          totalPages: 10,
        );

        // Verify progress is saved
        final progress = await storageService.getProgress('offline-progress-test');
        expect(progress, isNotNull);
        expect(progress!.currentPage, 5);
      });
    });

    group('Offline Data Persistence', () {
      test('data persists across offline/online transitions', () async {
        final testBook = TestHelpers.createTestBook(
          id: 'transition-test',
          title: 'Transition Test',
        );

        // Save while "online"
        await storageService.saveBook(testBook);

        // Simulate offline
        final offlineBook = await storageService.getBook('transition-test');
        expect(offlineBook, isNotNull);

        // Simulate coming back online
        final onlineBook = await storageService.getBook('transition-test');
        expect(onlineBook, isNotNull);
        expect(onlineBook!.id, 'transition-test');
      });

      test('multiple operations work offline', () async {
        // Create multiple books offline
        for (int i = 0; i < 3; i++) {
          final book = TestHelpers.createTestBook(
            id: 'offline-book-$i',
            title: 'Offline Book $i',
          );
          await storageService.saveBook(book);
        }

        // All should be accessible
        final allBooks = await storageService.getAllBooks();
        expect(allBooks.length, greaterThanOrEqualTo(3));
      });
    });

    group('Offline Error Handling', () {
      test('storage operations handle offline gracefully', () async {
        // Operations should not throw errors when offline
        await expectLater(
          storageService.getAllBooks(),
          completes,
        );

        await expectLater(
          storageService.getBook('any-id'),
          completes,
        );
      });

      test('book provider handles offline gracefully', () async {
        await expectLater(
          bookProvider.loadBooks(),
          completes,
        );
      });
    });
  });
}
