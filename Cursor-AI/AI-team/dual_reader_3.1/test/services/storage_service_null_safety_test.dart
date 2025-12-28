import 'package:flutter_test/flutter_test.dart';
import 'package:dual_reader/services/storage_service.dart';
import 'package:dual_reader/models/book.dart';
import 'package:dual_reader/models/reading_progress.dart';
import 'package:dual_reader/models/bookmark.dart';
import 'package:dual_reader/models/app_settings.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Tests for StorageService null safety issues
/// 
/// Critical Issue #1: Methods use null-assertion operators without checking initialization
/// This test suite verifies that StorageService properly handles uninitialized state
void main() {
  group('StorageService Null Safety Tests', () {
    late StorageService storageService;

    setUp(() async {
      await Hive.initFlutter();
      
      // Register adapters if not already registered
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(BookAdapter());
      }
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(ChapterAdapter());
      }
      if (!Hive.isAdapterRegistered(2)) {
        Hive.registerAdapter(ReadingProgressAdapter());
      }
      if (!Hive.isAdapterRegistered(3)) {
        Hive.registerAdapter(BookmarkAdapter());
      }
      if (!Hive.isAdapterRegistered(4)) {
        Hive.registerAdapter(AppSettingsAdapter());
      }
    });

    tearDown(() async {
      // Clean up test data
      try {
        await Hive.deleteBoxFromDisk('books');
        await Hive.deleteBoxFromDisk('reading_progress');
        await Hive.deleteBoxFromDisk('bookmarks');
        await Hive.deleteBoxFromDisk('settings');
      } catch (e) {
        // Ignore errors if boxes don't exist
      }
    });

    test('saveBook throws StateError when not initialized', () async {
      storageService = StorageService();
      final book = Book(
        id: 'test_book',
        title: 'Test Book',
        author: 'Test Author',
        filePath: '/test/path.epub',
        format: 'epub',
        chapters: [],
        fullText: 'Test content',
        addedAt: DateTime.now(),
      );

      // Should throw StateError if not initialized
      expect(
        () => storageService.saveBook(book),
        throwsA(isA<StateError>()),
      );
    });

    test('getBook throws StateError when not initialized', () async {
      storageService = StorageService();

      expect(
        () => storageService.getBook('test_id'),
        throwsA(isA<StateError>()),
      );
    });

    test('getAllBooks throws StateError when not initialized', () async {
      storageService = StorageService();

      expect(
        () => storageService.getAllBooks(),
        throwsA(isA<StateError>()),
      );
    });

    test('deleteBook throws StateError when not initialized', () async {
      storageService = StorageService();

      expect(
        () => storageService.deleteBook('test_id'),
        throwsA(isA<StateError>()),
      );
    });

    test('saveProgress throws StateError when not initialized', () async {
      storageService = StorageService();
      final progress = ReadingProgress(
        bookId: 'book1',
        currentPage: 1,
        totalPages: 100,
        progress: 0.01,
        lastReadAt: DateTime.now(),
      );

      expect(
        () => storageService.saveProgress(progress),
        throwsA(isA<StateError>()),
      );
    });

    test('getProgress throws StateError when not initialized', () async {
      storageService = StorageService();

      expect(
        () => storageService.getProgress('book1'),
        throwsA(isA<StateError>()),
      );
    });

    test('saveBookmark throws StateError when not initialized', () async {
      storageService = StorageService();
      final bookmark = Bookmark(
        id: 'bm1',
        bookId: 'book1',
        page: 1,
        createdAt: DateTime.now(),
      );

      expect(
        () => storageService.saveBookmark(bookmark),
        throwsA(isA<StateError>()),
      );
    });

    test('getBookmark throws StateError when not initialized', () async {
      storageService = StorageService();

      expect(
        () => storageService.getBookmark('bm1'),
        throwsA(isA<StateError>()),
      );
    });

    test('getBookmarksForBook throws StateError when not initialized', () async {
      storageService = StorageService();

      expect(
        () => storageService.getBookmarksForBook('book1'),
        throwsA(isA<StateError>()),
      );
    });

    test('deleteBookmark throws StateError when not initialized', () async {
      storageService = StorageService();

      expect(
        () => storageService.deleteBookmark('bm1'),
        throwsA(isA<StateError>()),
      );
    });

    test('saveSettings throws StateError when not initialized', () async {
      storageService = StorageService();
      final settings = AppSettings();

      expect(
        () => storageService.saveSettings(settings),
        throwsA(isA<StateError>()),
      );
    });

    test('getSettings throws StateError when not initialized', () async {
      storageService = StorageService();

      expect(
        () => storageService.getSettings(),
        throwsA(isA<StateError>()),
      );
    });

    test('file operations throw StateError when not initialized', () async {
      storageService = StorageService();

      expect(
        () => storageService.saveBookFile(fileName: 'test.epub', fileData: [1, 2, 3]),
        throwsA(isA<StateError>()),
      );

      expect(
        () => storageService.readBookFile('/test/path.epub'),
        throwsA(isA<StateError>()),
      );

      expect(
        () => storageService.deleteBookFile('/test/path.epub'),
        throwsA(isA<StateError>()),
      );

      expect(
        () => storageService.saveCoverImage('book1', [1, 2, 3]),
        throwsA(isA<StateError>()),
      );

      expect(
        () => storageService.getCoverImageData('/test/path.jpg'),
        throwsA(isA<StateError>()),
      );

      expect(
        () => storageService.deleteCoverImage('/test/path.jpg'),
        throwsA(isA<StateError>()),
      );

      expect(
        () => storageService.saveTranslationCache('key', 'value'),
        throwsA(isA<StateError>()),
      );

      expect(
        () => storageService.getTranslationCache('key'),
        throwsA(isA<StateError>()),
      );

      expect(
        () => storageService.deleteTranslationCache('key'),
        throwsA(isA<StateError>()),
      );

      expect(
        () => storageService.getStorageStats(),
        throwsA(isA<StateError>()),
      );
    });

    test('works correctly after initialization', () async {
      storageService = StorageService();
      await storageService.init();

      final book = Book(
        id: 'test_book',
        title: 'Test Book',
        author: 'Test Author',
        filePath: '/test/path.epub',
        format: 'epub',
        chapters: [],
        fullText: 'Test content',
        addedAt: DateTime.now(),
      );

      // Should work after initialization
      await storageService.saveBook(book);
      final retrieved = await storageService.getBook('test_book');

      expect(retrieved, isNotNull);
      expect(retrieved!.id, book.id);
    });
  });
}
