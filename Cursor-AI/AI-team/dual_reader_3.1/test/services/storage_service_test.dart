import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:dual_reader/services/storage_service.dart';
import 'package:dual_reader/models/book.dart';
import 'package:dual_reader/models/reading_progress.dart';
import 'package:dual_reader/models/bookmark.dart';
import 'package:dual_reader/models/app_settings.dart';
import 'package:dual_reader/models/chapter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

void main() {
  group('StorageService', () {
    late StorageService storageService;

    setUp(() async {
      // Initialize Hive for testing
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

      storageService = StorageService();
      await storageService.init();
    });

    tearDown(() async {
      // Clean up test data
      try {
        await storageService.dispose();
        await Hive.deleteBoxFromDisk('books');
        await Hive.deleteBoxFromDisk('reading_progress');
        await Hive.deleteBoxFromDisk('bookmarks');
        await Hive.deleteBoxFromDisk('settings');
        await Hive.deleteBoxFromDisk('book_files_base64');
        await Hive.deleteBoxFromDisk('book_covers_base64');
        await Hive.deleteBoxFromDisk('translations_base64');
      } catch (e) {
        // Ignore errors if boxes don't exist
      }
    });

    test('saveBook and getBook work correctly', () async {
      final book = Book(
        id: 'test_book_1',
        title: 'Test Book',
        author: 'Test Author',
        filePath: '/test/path.epub',
        format: 'epub',
        chapters: [],
        fullText: 'Test content',
        addedAt: DateTime.now(),
      );

      await storageService.saveBook(book);
      final retrieved = await storageService.getBook('test_book_1');

      expect(retrieved, isNotNull);
      expect(retrieved!.id, book.id);
      expect(retrieved.title, book.title);
      expect(retrieved.author, book.author);
    });

    test('getBook returns null for non-existent book', () async {
      final book = await storageService.getBook('non_existent');
      expect(book, isNull);
    });

    test('getAllBooks returns all saved books', () async {
      final book1 = Book(
        id: 'book1',
        title: 'Book 1',
        author: 'Author 1',
        filePath: '/path1.epub',
        format: 'epub',
        chapters: [],
        fullText: 'Content 1',
        addedAt: DateTime.now(),
      );

      final book2 = Book(
        id: 'book2',
        title: 'Book 2',
        author: 'Author 2',
        filePath: '/path2.epub',
        format: 'epub',
        chapters: [],
        fullText: 'Content 2',
        addedAt: DateTime.now(),
      );

      await storageService.saveBook(book1);
      await storageService.saveBook(book2);

      final allBooks = await storageService.getAllBooks();
      expect(allBooks.length, greaterThanOrEqualTo(2));
      expect(allBooks.any((b) => b.id == 'book1'), true);
      expect(allBooks.any((b) => b.id == 'book2'), true);
    });

    test('deleteBook removes book and related data', () async {
      final book = Book(
        id: 'book_to_delete',
        title: 'To Delete',
        author: 'Author',
        filePath: '/path.epub',
        format: 'epub',
        chapters: [],
        fullText: 'Content',
        addedAt: DateTime.now(),
      );

      await storageService.saveBook(book);
      await storageService.deleteBook('book_to_delete');

      final retrieved = await storageService.getBook('book_to_delete');
      expect(retrieved, isNull);
    });

    test('saveProgress and getProgress work correctly', () async {
      final progress = ReadingProgress(
        bookId: 'book1',
        currentPage: 5,
        totalPages: 100,
        progress: 0.05,
        lastReadAt: DateTime.now(),
      );

      await storageService.saveProgress(progress);
      final retrieved = await storageService.getProgress('book1');

      expect(retrieved, isNotNull);
      expect(retrieved!.bookId, progress.bookId);
      expect(retrieved.currentPage, progress.currentPage);
      expect(retrieved.totalPages, progress.totalPages);
      expect(retrieved.progress, progress.progress);
    });

    test('saveBookmark and getBookmark work correctly', () async {
      final bookmark = Bookmark(
        id: 'bookmark1',
        bookId: 'book1',
        page: 42,
        createdAt: DateTime.now(),
        note: 'Test note',
      );

      await storageService.saveBookmark(bookmark);
      final retrieved = await storageService.getBookmark('bookmark1');

      expect(retrieved, isNotNull);
      expect(retrieved!.id, bookmark.id);
      expect(retrieved.bookId, bookmark.bookId);
      expect(retrieved.page, bookmark.page);
      expect(retrieved.note, bookmark.note);
    });

    test('getBookmarksForBook returns only bookmarks for specific book', () async {
      final bookmark1 = Bookmark(
        id: 'bm1',
        bookId: 'book1',
        page: 10,
        createdAt: DateTime.now(),
      );

      final bookmark2 = Bookmark(
        id: 'bm2',
        bookId: 'book2',
        page: 20,
        createdAt: DateTime.now(),
      );

      final bookmark3 = Bookmark(
        id: 'bm3',
        bookId: 'book1',
        page: 30,
        createdAt: DateTime.now(),
      );

      await storageService.saveBookmark(bookmark1);
      await storageService.saveBookmark(bookmark2);
      await storageService.saveBookmark(bookmark3);

      final book1Bookmarks = await storageService.getBookmarksForBook('book1');
      expect(book1Bookmarks.length, 2);
      expect(book1Bookmarks.any((b) => b.id == 'bm1'), true);
      expect(book1Bookmarks.any((b) => b.id == 'bm3'), true);
      expect(book1Bookmarks.any((b) => b.id == 'bm2'), false);
    });

    test('deleteBookmark removes bookmark', () async {
      final bookmark = Bookmark(
        id: 'bm_to_delete',
        bookId: 'book1',
        page: 10,
        createdAt: DateTime.now(),
      );

      await storageService.saveBookmark(bookmark);
      await storageService.deleteBookmark('bm_to_delete');

      final retrieved = await storageService.getBookmark('bm_to_delete');
      expect(retrieved, isNull);
    });

    test('saveSettings and getSettings work correctly', () async {
      final settings = AppSettings(
        theme: 'light',
        fontSize: 18,
        autoTranslate: false,
      );

      await storageService.saveSettings(settings);
      final retrieved = await storageService.getSettings();

      expect(retrieved.theme, settings.theme);
      expect(retrieved.fontSize, settings.fontSize);
      expect(retrieved.autoTranslate, settings.autoTranslate);
    });

    test('getSettings returns default settings if none saved', () async {
      // Clear settings first
      try {
        final box = await Hive.openBox<AppSettings>('settings');
        await box.clear();
      } catch (e) {
        // Ignore if box doesn't exist
      }

      // Reinitialize to get default
      final storage = StorageService();
      await storage.init();
      final settings = await storage.getSettings();

      expect(settings, isNotNull);
      expect(settings.theme, 'dark'); // Default theme
    });

    // ==================== File Operations Tests ====================

    group('File Operations', () {
      test('saveBookFile throws ArgumentError for empty fileName', () async {
        expect(
          () => storageService.saveBookFile(fileName: ''),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('saveBookFile on web requires fileData', () async {
        if (kIsWeb) {
          expect(
            () => storageService.saveBookFile(
              fileName: 'test.epub',
              fileData: null,
            ),
            throwsA(isA<ArgumentError>()),
          );
        }
      });

      test('saveBookFile on web saves file data', () async {
        if (kIsWeb) {
          final testData = Uint8List.fromList([1, 2, 3, 4, 5]);
          final filePath = await storageService.saveBookFile(
            fileName: 'test_book.epub',
            fileData: testData,
          );

          expect(filePath, startsWith('web://books/'));
          expect(filePath, contains('test_book.epub'));

          final retrieved = await storageService.readBookFile(filePath);
          expect(retrieved, isNotNull);
          expect(retrieved, equals(testData));
        }
      });

      test('saveBookFile on mobile requires sourcePath', () async {
        if (!kIsWeb) {
          expect(
            () => storageService.saveBookFile(
              fileName: 'test.epub',
              sourcePath: null,
            ),
            throwsA(isA<ArgumentError>()),
          );
        }
      });

      test('saveBookFile on mobile copies file to books directory', () async {
        if (!kIsWeb) {
          // Create a temporary test file
          final tempDir = await Directory.systemTemp.createTemp();
          final tempFile = File('${tempDir.path}/source.epub');
          final testData = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
          await tempFile.writeAsBytes(testData);

          try {
            final savedPath = await storageService.saveBookFile(
              sourcePath: tempFile.path,
              fileName: 'saved_book.epub',
            );

            expect(savedPath, isNotEmpty);
            final savedFile = File(savedPath);
            expect(await savedFile.exists(), isTrue);

            final savedData = await savedFile.readAsBytes();
            expect(savedData, equals(testData));
          } finally {
            // Cleanup
            await tempFile.delete();
            await tempDir.delete(recursive: true);
          }
        }
      });

      test('readBookFile returns null for non-existent file', () async {
        final data = await storageService.readBookFile('non_existent_path');
        expect(data, isNull);
      });

      test('bookFileExists returns false for non-existent file', () async {
        final exists = await storageService.bookFileExists('non_existent_path');
        expect(exists, isFalse);
      });

      test('bookFileExists returns true for existing file', () async {
        if (kIsWeb) {
          final testData = Uint8List.fromList([1, 2, 3]);
          final filePath = await storageService.saveBookFile(
            fileName: 'exists_test.epub',
            fileData: testData,
          );

          final exists = await storageService.bookFileExists(filePath);
          expect(exists, isTrue);
        } else {
          // Create a temporary test file
          final tempDir = await Directory.systemTemp.createTemp();
          final tempFile = File('${tempDir.path}/exists_test.epub');
          await tempFile.writeAsBytes([1, 2, 3]);

          try {
            final savedPath = await storageService.saveBookFile(
              sourcePath: tempFile.path,
              fileName: 'exists_test.epub',
            );

            final exists = await storageService.bookFileExists(savedPath);
            expect(exists, isTrue);
          } finally {
            await tempFile.delete();
            await tempDir.delete(recursive: true);
          }
        }
      });

      test('deleteBookFile removes file', () async {
        if (kIsWeb) {
          final testData = Uint8List.fromList([1, 2, 3]);
          final filePath = await storageService.saveBookFile(
            fileName: 'delete_test.epub',
            fileData: testData,
          );

          await storageService.deleteBookFile(filePath);
          final exists = await storageService.bookFileExists(filePath);
          expect(exists, isFalse);
        } else {
          // Create a temporary test file
          final tempDir = await Directory.systemTemp.createTemp();
          final tempFile = File('${tempDir.path}/delete_test.epub');
          await tempFile.writeAsBytes([1, 2, 3]);

          try {
            final savedPath = await storageService.saveBookFile(
              sourcePath: tempFile.path,
              fileName: 'delete_test.epub',
            );

            await storageService.deleteBookFile(savedPath);
            final exists = await storageService.bookFileExists(savedPath);
            expect(exists, isFalse);
          } finally {
            await tempFile.delete();
            await tempDir.delete(recursive: true);
          }
        }
      });
    });

    // ==================== Cover Image Operations Tests ====================

    group('Cover Image Operations', () {
      test('saveCoverImage throws ArgumentError for empty bookId', () async {
        expect(
          () => storageService.saveCoverImage('', [1, 2, 3]),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('saveCoverImage throws ArgumentError for empty imageData', () async {
        expect(
          () => storageService.saveCoverImage('book1', []),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('saveCoverImage saves cover image', () async {
        final imageData = Uint8List.fromList([1, 2, 3, 4, 5]);
        final coverPath = await storageService.saveCoverImage('book1', imageData);

        if (kIsWeb) {
          expect(coverPath, startsWith('web://covers/'));
        } else {
          expect(coverPath, isNotEmpty);
        }

        final retrieved = await storageService.getCoverImageData(coverPath);
        expect(retrieved, isNotNull);
        expect(retrieved, equals(imageData));
      });

      test('getCoverImageData returns null for null path', () async {
        final data = await storageService.getCoverImageData(null);
        expect(data, isNull);
      });

      test('getCoverImageData returns null for non-existent cover', () async {
        final data = await storageService.getCoverImageData('non_existent_cover.jpg');
        expect(data, isNull);
      });

      test('deleteCoverImage removes cover image', () async {
        final imageData = Uint8List.fromList([1, 2, 3]);
        final coverPath = await storageService.saveCoverImage('book_to_delete', imageData);

        await storageService.deleteCoverImage(coverPath);

        final retrieved = await storageService.getCoverImageData(coverPath);
        expect(retrieved, isNull);
      });

      test('deleteCoverImage handles null path gracefully', () async {
        // Should not throw
        await storageService.deleteCoverImage(null);
      });
    });

    // ==================== Translation Cache Operations Tests ====================

    group('Translation Cache Operations', () {
      test('saveTranslationCache throws ArgumentError for empty cacheKey', () async {
        expect(
          () => storageService.saveTranslationCache('', 'translation'),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('saveTranslationCache throws ArgumentError for empty translation', () async {
        expect(
          () => storageService.saveTranslationCache('key', ''),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('saveTranslationCache saves translation', () async {
        await storageService.saveTranslationCache('key1', 'Hello World');
        final retrieved = await storageService.getTranslationCache('key1');
        expect(retrieved, equals('Hello World'));
      });

      test('getTranslationCache returns null for non-existent key', () async {
        final translation = await storageService.getTranslationCache('non_existent');
        expect(translation, isNull);
      });

      test('getTranslationCache retrieves saved translation', () async {
        await storageService.saveTranslationCache('test_key', 'Test translation');
        final translation = await storageService.getTranslationCache('test_key');
        expect(translation, equals('Test translation'));
      });

      test('deleteTranslationCache removes translation', () async {
        await storageService.saveTranslationCache('delete_key', 'To delete');
        await storageService.deleteTranslationCache('delete_key');
        final translation = await storageService.getTranslationCache('delete_key');
        expect(translation, isNull);
      });

      test('clearTranslationCache removes all translations', () async {
        await storageService.saveTranslationCache('key1', 'Translation 1');
        await storageService.saveTranslationCache('key2', 'Translation 2');
        await storageService.saveTranslationCache('key3', 'Translation 3');

        await storageService.clearTranslationCache();

        expect(await storageService.getTranslationCache('key1'), isNull);
        expect(await storageService.getTranslationCache('key2'), isNull);
        expect(await storageService.getTranslationCache('key3'), isNull);
      });
    });

    // ==================== Directory Operations Tests ====================

    group('Directory Operations', () {
      test('getBooksDirectory creates directory if it does not exist', () async {
        if (!kIsWeb) {
          final booksDir = await storageService.getBooksDirectory();
          expect(booksDir, isNotEmpty);
          final dir = Directory(booksDir);
          expect(await dir.exists(), isTrue);
        }
      });

      test('getCoversDirectory creates directory if it does not exist', () async {
        if (!kIsWeb) {
          final coversDir = await storageService.getCoversDirectory();
          expect(coversDir, isNotEmpty);
          final dir = Directory(coversDir);
          expect(await dir.exists(), isTrue);
        }
      });

      test('getTranslationsDirectory creates directory if it does not exist', () async {
        if (!kIsWeb) {
          final translationsDir = await storageService.getTranslationsDirectory();
          expect(translationsDir, isNotEmpty);
          final dir = Directory(translationsDir);
          expect(await dir.exists(), isTrue);
        }
      });

      test('getCacheDirectory creates directory if it does not exist', () async {
        if (!kIsWeb) {
          final cacheDir = await storageService.getCacheDirectory();
          expect(cacheDir, isNotEmpty);
          final dir = Directory(cacheDir);
          expect(await dir.exists(), isTrue);
        }
      });

      test('getBooksDirectory throws UnsupportedError on web', () async {
        if (kIsWeb) {
          expect(
            () => storageService.getBooksDirectory(),
            throwsA(isA<UnsupportedError>()),
          );
        }
      });
    });

    // ==================== Error Handling Tests ====================

    group('Error Handling', () {
      test('saveBook throws ArgumentError for empty book id', () async {
        final book = Book(
          id: '',
          title: 'Test',
          author: 'Author',
          filePath: '/path.epub',
          format: 'epub',
          chapters: [],
          fullText: 'Content',
          addedAt: DateTime.now(),
        );

        expect(
          () => storageService.saveBook(book),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('saveProgress throws ArgumentError for empty bookId', () async {
        final progress = ReadingProgress(
          bookId: '',
          currentPage: 1,
          totalPages: 100,
          progress: 0.01,
          lastReadAt: DateTime.now(),
        );

        expect(
          () => storageService.saveProgress(progress),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('saveBookmark throws ArgumentError for empty bookmark id', () async {
        final bookmark = Bookmark(
          id: '',
          bookId: 'book1',
          page: 1,
          createdAt: DateTime.now(),
        );

        expect(
          () => storageService.saveBookmark(bookmark),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('saveBookmark throws ArgumentError for empty bookId', () async {
        final bookmark = Bookmark(
          id: 'bm1',
          bookId: '',
          page: 1,
          createdAt: DateTime.now(),
        );

        expect(
          () => storageService.saveBookmark(bookmark),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('operations throw StateError if service not initialized', () async {
        final uninitializedService = StorageService();
        expect(
          () => uninitializedService.saveBook(Book(
            id: 'test',
            title: 'Test',
            author: 'Author',
            filePath: '/path.epub',
            format: 'epub',
            chapters: [],
            fullText: 'Content',
            addedAt: DateTime.now(),
          )),
          throwsA(isA<StateError>()),
        );
      });
    });

    // ==================== Storage Statistics Tests ====================

    group('Storage Statistics', () {
      test('getStorageStats returns correct counts', () async {
        // Add some test data
        await storageService.saveBook(Book(
          id: 'stats_book1',
          title: 'Book 1',
          author: 'Author',
          filePath: '/path.epub',
          format: 'epub',
          chapters: [],
          fullText: 'Content',
          addedAt: DateTime.now(),
        ));

        await storageService.saveProgress(ReadingProgress(
          bookId: 'stats_book1',
          currentPage: 1,
          totalPages: 100,
          progress: 0.01,
          lastReadAt: DateTime.now(),
        ));

        await storageService.saveBookmark(Bookmark(
          id: 'stats_bm1',
          bookId: 'stats_book1',
          page: 1,
          createdAt: DateTime.now(),
        ));

        final stats = await storageService.getStorageStats();
        expect(stats['booksCount'], greaterThanOrEqualTo(1));
        expect(stats['progressCount'], greaterThanOrEqualTo(1));
        expect(stats['bookmarksCount'], greaterThanOrEqualTo(1));
        expect(stats['platform'], isA<String>());
      });

      test('getStorageSize returns non-negative value', () async {
        final size = await storageService.getStorageSize();
        expect(size, greaterThanOrEqualTo(0));
      });
    });

    // ==================== Book Management Integration Tests ====================

    group('Book Management Integration', () {
      test('deleteBook removes book and all associated data', () async {
        final book = Book(
          id: 'integration_test_book',
          title: 'Integration Test',
          author: 'Author',
          filePath: '/test/path.epub',
          format: 'epub',
          chapters: [],
          fullText: 'Content',
          addedAt: DateTime.now(),
        );

        await storageService.saveBook(book);
        await storageService.saveProgress(ReadingProgress(
          bookId: book.id,
          currentPage: 5,
          totalPages: 100,
          progress: 0.05,
          lastReadAt: DateTime.now(),
        ));
        await storageService.saveBookmark(Bookmark(
          id: 'bm1',
          bookId: book.id,
          page: 5,
          createdAt: DateTime.now(),
        ));

        await storageService.deleteBook(book.id);

        expect(await storageService.getBook(book.id), isNull);
        expect(await storageService.getProgress(book.id), isNull);
        final bookmarks = await storageService.getBookmarksForBook(book.id);
        expect(bookmarks, isEmpty);
      });

      test('deleteBookmarksForBook removes all bookmarks for a book', () async {
        final bookId = 'book_with_bookmarks';
        await storageService.saveBookmark(Bookmark(
          id: 'bm1',
          bookId: bookId,
          page: 1,
          createdAt: DateTime.now(),
        ));
        await storageService.saveBookmark(Bookmark(
          id: 'bm2',
          bookId: bookId,
          page: 2,
          createdAt: DateTime.now(),
        ));
        await storageService.saveBookmark(Bookmark(
          id: 'bm3',
          bookId: 'other_book',
          page: 1,
          createdAt: DateTime.now(),
        ));

        await storageService.deleteBookmarksForBook(bookId);

        final bookBookmarks = await storageService.getBookmarksForBook(bookId);
        expect(bookBookmarks, isEmpty);

        final otherBookmarks = await storageService.getBookmarksForBook('other_book');
        expect(otherBookmarks.length, 1);
      });
    });
  });
}
