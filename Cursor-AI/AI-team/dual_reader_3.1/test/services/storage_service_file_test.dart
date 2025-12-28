import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:dual_reader/services/storage_service.dart';
import 'package:dual_reader/models/book.dart';
import 'package:dual_reader/models/chapter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Comprehensive tests for StorageService file storage operations
/// Tests file save, read, delete, and platform-specific handling
void main() {
  group('StorageService File Storage Tests', () {
    late StorageService storageService;
    late Directory tempDir;

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
      
      // Create temporary directory for test files (mobile only)
      if (!kIsWeb) {
        tempDir = await Directory.systemTemp.createTemp('storage_test_');
      }
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
        
        // Clean up temp directory (mobile only)
        if (!kIsWeb && tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      } catch (e) {
        // Ignore errors if boxes/directories don't exist
      }
    });

    group('Directory Management', () {
      test('getBooksDirectory creates directory if it does not exist', () async {
        if (kIsWeb) {
          expect(
            () => storageService.getBooksDirectory(),
            throwsA(isA<UnsupportedError>()),
          );
          return;
        }
        
        final booksDir = await storageService.getBooksDirectory();
        expect(booksDir, isNotEmpty);
        
        final dir = Directory(booksDir);
        expect(await dir.exists(), isTrue);
      });

      test('getCoversDirectory creates directory if it does not exist', () async {
        if (kIsWeb) {
          expect(
            () => storageService.getCoversDirectory(),
            throwsA(isA<UnsupportedError>()),
          );
          return;
        }
        
        final coversDir = await storageService.getCoversDirectory();
        expect(coversDir, isNotEmpty);
        
        final dir = Directory(coversDir);
        expect(await dir.exists(), isTrue);
      });

      test('getTranslationsDirectory creates directory if it does not exist', () async {
        if (kIsWeb) {
          expect(
            () => storageService.getTranslationsDirectory(),
            throwsA(isA<UnsupportedError>()),
          );
          return;
        }
        
        final translationsDir = await storageService.getTranslationsDirectory();
        expect(translationsDir, isNotEmpty);
        
        final dir = Directory(translationsDir);
        expect(await dir.exists(), isTrue);
      });

      test('getCacheDirectory creates directory if it does not exist', () async {
        if (kIsWeb) {
          expect(
            () => storageService.getCacheDirectory(),
            throwsA(isA<UnsupportedError>()),
          );
          return;
        }
        
        final cacheDir = await storageService.getCacheDirectory();
        expect(cacheDir, isNotEmpty);
        
        final dir = Directory(cacheDir);
        expect(await dir.exists(), isTrue);
      });
    });

    group('Book File Operations', () {
      test('saveBookFile saves file on mobile platform', () async {
        if (kIsWeb) {
          return; // Skip on web
        }
        
        // Create a test file
        final testFile = File('${tempDir.path}/test_book.epub');
        final testContent = Uint8List.fromList([1, 2, 3, 4, 5]);
        await testFile.writeAsBytes(testContent);
        
        // Save the file
        final savedPath = await storageService.saveBookFile(
          sourcePath: testFile.path,
          fileName: 'test_book.epub',
        );
        
        expect(savedPath, isNotEmpty);
        expect(savedPath, contains('test_book.epub'));
        
        // Verify file exists
        final savedFile = File(savedPath);
        expect(await savedFile.exists(), isTrue);
        
        // Verify content
        final savedContent = await savedFile.readAsBytes();
        expect(savedContent, equals(testContent));
      });

      test('saveBookFile saves file data on web platform', () async {
        if (!kIsWeb) {
          return; // Skip on mobile
        }
        
        final testContent = Uint8List.fromList([1, 2, 3, 4, 5]);
        
        // Save the file
        final savedPath = await storageService.saveBookFile(
          fileName: 'test_book.epub',
          fileData: testContent,
        );
        
        expect(savedPath, isNotEmpty);
        expect(savedPath, startsWith('web://books/'));
        
        // Verify file can be read back
        final readContent = await storageService.readBookFile(savedPath);
        expect(readContent, isNotNull);
        expect(readContent, equals(testContent));
      });

      test('saveBookFile throws error if sourcePath missing on mobile', () async {
        if (kIsWeb) {
          return; // Skip on web
        }
        
        expect(
          () => storageService.saveBookFile(fileName: 'test.epub'),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('saveBookFile throws error if fileData missing on web', () async {
        if (!kIsWeb) {
          return; // Skip on mobile
        }
        
        expect(
          () => storageService.saveBookFile(fileName: 'test.epub'),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('saveBookFile throws error if source file does not exist', () async {
        if (kIsWeb) {
          return; // Skip on web
        }
        
        expect(
          () => storageService.saveBookFile(
            sourcePath: '/nonexistent/path.epub',
            fileName: 'test.epub',
          ),
          throwsA(isA<StorageException>()),
        );
      });

      test('readBookFile reads file correctly on mobile', () async {
        if (kIsWeb) {
          return; // Skip on web
        }
        
        // Create and save a test file
        final testFile = File('${tempDir.path}/test_read.epub');
        final testContent = Uint8List.fromList([10, 20, 30, 40, 50]);
        await testFile.writeAsBytes(testContent);
        
        final savedPath = await storageService.saveBookFile(
          sourcePath: testFile.path,
          fileName: 'test_read.epub',
        );
        
        // Read the file
        final readContent = await storageService.readBookFile(savedPath);
        
        expect(readContent, isNotNull);
        expect(readContent, equals(testContent));
      });

      test('readBookFile reads file correctly on web', () async {
        if (!kIsWeb) {
          return; // Skip on mobile
        }
        
        final testContent = Uint8List.fromList([10, 20, 30, 40, 50]);
        
        final savedPath = await storageService.saveBookFile(
          fileName: 'test_read.epub',
          fileData: testContent,
        );
        
        // Read the file
        final readContent = await storageService.readBookFile(savedPath);
        
        expect(readContent, isNotNull);
        expect(readContent, equals(testContent));
      });

      test('readBookFile returns null for non-existent file', () async {
        final readContent = await storageService.readBookFile('/nonexistent/path.epub');
        expect(readContent, isNull);
      });

      test('bookFileExists returns true for existing file', () async {
        if (kIsWeb) {
          final testContent = Uint8List.fromList([1, 2, 3]);
          final savedPath = await storageService.saveBookFile(
            fileName: 'exists_test.epub',
            fileData: testContent,
          );
          
          final exists = await storageService.bookFileExists(savedPath);
          expect(exists, isTrue);
        } else {
          final testFile = File('${tempDir.path}/exists_test.epub');
          await testFile.writeAsBytes([1, 2, 3]);
          
          final savedPath = await storageService.saveBookFile(
            sourcePath: testFile.path,
            fileName: 'exists_test.epub',
          );
          
          final exists = await storageService.bookFileExists(savedPath);
          expect(exists, isTrue);
        }
      });

      test('bookFileExists returns false for non-existent file', () async {
        final exists = await storageService.bookFileExists('/nonexistent/file.epub');
        expect(exists, isFalse);
      });

      test('deleteBookFile deletes file on mobile', () async {
        if (kIsWeb) {
          return; // Skip on web
        }
        
        // Create and save a test file
        final testFile = File('${tempDir.path}/test_delete.epub');
        await testFile.writeAsBytes([1, 2, 3]);
        
        final savedPath = await storageService.saveBookFile(
          sourcePath: testFile.path,
          fileName: 'test_delete.epub',
        );
        
        // Verify file exists
        expect(await File(savedPath).exists(), isTrue);
        
        // Delete the file
        await storageService.deleteBookFile(savedPath);
        
        // Verify file is deleted
        expect(await File(savedPath).exists(), isFalse);
      });

      test('deleteBookFile deletes file on web', () async {
        if (!kIsWeb) {
          return; // Skip on mobile
        }
        
        final testContent = Uint8List.fromList([1, 2, 3]);
        final savedPath = await storageService.saveBookFile(
          fileName: 'test_delete.epub',
          fileData: testContent,
        );
        
        // Verify file exists
        expect(await storageService.bookFileExists(savedPath), isTrue);
        
        // Delete the file
        await storageService.deleteBookFile(savedPath);
        
        // Verify file is deleted
        expect(await storageService.bookFileExists(savedPath), isFalse);
        final readContent = await storageService.readBookFile(savedPath);
        expect(readContent, isNull);
      });

      test('deleteBookFile handles non-existent file gracefully', () async {
        // Should not throw an error
        await storageService.deleteBookFile('/nonexistent/file.epub');
      });
    });

    group('Cover Image Operations', () {
      test('saveCoverImage saves cover image on mobile', () async {
        if (kIsWeb) {
          return; // Skip on web
        }
        
        final imageData = [100, 101, 102, 103, 104];
        final bookId = 'test_book_1';
        
        final coverPath = await storageService.saveCoverImage(bookId, imageData);
        
        expect(coverPath, isNotEmpty);
        expect(coverPath, contains(bookId));
        expect(coverPath, endsWith('.jpg'));
        
        // Verify file exists
        final file = File(coverPath);
        expect(await file.exists(), isTrue);
        
        // Verify content
        final savedData = await file.readAsBytes();
        expect(savedData, equals(imageData));
      });

      test('saveCoverImage saves cover image on web', () async {
        if (!kIsWeb) {
          return; // Skip on mobile
        }
        
        final imageData = [100, 101, 102, 103, 104];
        final bookId = 'test_book_1';
        
        final coverPath = await storageService.saveCoverImage(bookId, imageData);
        
        expect(coverPath, isNotEmpty);
        expect(coverPath, startsWith('web://covers/'));
        expect(coverPath, contains(bookId));
        
        // Verify can read back
        final readData = await storageService.getCoverImageData(coverPath);
        expect(readData, isNotNull);
        expect(readData, equals(imageData));
      });

      test('getCoverImageData retrieves cover image on mobile', () async {
        if (kIsWeb) {
          return; // Skip on web
        }
        
        final imageData = [200, 201, 202, 203, 204];
        final bookId = 'test_book_2';
        
        final coverPath = await storageService.saveCoverImage(bookId, imageData);
        final retrievedData = await storageService.getCoverImageData(coverPath);
        
        expect(retrievedData, isNotNull);
        expect(retrievedData, equals(imageData));
      });

      test('getCoverImageData retrieves cover image on web', () async {
        if (!kIsWeb) {
          return; // Skip on mobile
        }
        
        final imageData = [200, 201, 202, 203, 204];
        final bookId = 'test_book_2';
        
        final coverPath = await storageService.saveCoverImage(bookId, imageData);
        final retrievedData = await storageService.getCoverImageData(coverPath);
        
        expect(retrievedData, isNotNull);
        expect(retrievedData, equals(imageData));
      });

      test('getCoverImageData returns null for non-existent cover', () async {
        final data = await storageService.getCoverImageData('nonexistent/path.jpg');
        expect(data, isNull);
      });

      test('getCoverImageData returns null for null path', () async {
        final data = await storageService.getCoverImageData(null);
        expect(data, isNull);
      });

      test('deleteCoverImage deletes cover on mobile', () async {
        if (kIsWeb) {
          return; // Skip on web
        }
        
        final imageData = [1, 2, 3];
        final bookId = 'test_book_3';
        
        final coverPath = await storageService.saveCoverImage(bookId, imageData);
        expect(await File(coverPath).exists(), isTrue);
        
        await storageService.deleteCoverImage(coverPath);
        expect(await File(coverPath).exists(), isFalse);
      });

      test('deleteCoverImage deletes cover on web', () async {
        if (!kIsWeb) {
          return; // Skip on mobile
        }
        
        final imageData = [1, 2, 3];
        final bookId = 'test_book_3';
        
        final coverPath = await storageService.saveCoverImage(bookId, imageData);
        expect(await storageService.getCoverImageData(coverPath), isNotNull);
        
        await storageService.deleteCoverImage(coverPath);
        expect(await storageService.getCoverImageData(coverPath), isNull);
      });

      test('deleteCoverImage handles null path gracefully', () async {
        await storageService.deleteCoverImage(null);
        // Should not throw
      });
    });

    group('Translation Cache Operations', () {
      test('saveTranslationCache saves translation on mobile', () async {
        if (kIsWeb) {
          return; // Skip on web
        }
        
        final cacheKey = 'test_key_1';
        final translation = '{"text": "Hello", "translated": "Hola"}';
        
        await storageService.saveTranslationCache(cacheKey, translation);
        
        // Verify file exists
        final translationsDir = await storageService.getTranslationsDirectory();
        final cacheFile = File('$translationsDir/$cacheKey.json');
        expect(await cacheFile.exists(), isTrue);
        
        // Verify content
        final content = await cacheFile.readAsString();
        expect(content, equals(translation));
      });

      test('saveTranslationCache saves translation on web', () async {
        if (!kIsWeb) {
          return; // Skip on mobile
        }
        
        final cacheKey = 'test_key_1';
        final translation = '{"text": "Hello", "translated": "Hola"}';
        
        await storageService.saveTranslationCache(cacheKey, translation);
        
        // Verify can read back
        final retrieved = await storageService.getTranslationCache(cacheKey);
        expect(retrieved, equals(translation));
      });

      test('getTranslationCache retrieves translation on mobile', () async {
        if (kIsWeb) {
          return; // Skip on web
        }
        
        final cacheKey = 'test_key_2';
        final translation = '{"text": "World", "translated": "Mundo"}';
        
        await storageService.saveTranslationCache(cacheKey, translation);
        final retrieved = await storageService.getTranslationCache(cacheKey);
        
        expect(retrieved, isNotNull);
        expect(retrieved, equals(translation));
      });

      test('getTranslationCache retrieves translation on web', () async {
        if (!kIsWeb) {
          return; // Skip on mobile
        }
        
        final cacheKey = 'test_key_2';
        final translation = '{"text": "World", "translated": "Mundo"}';
        
        await storageService.saveTranslationCache(cacheKey, translation);
        final retrieved = await storageService.getTranslationCache(cacheKey);
        
        expect(retrieved, isNotNull);
        expect(retrieved, equals(translation));
      });

      test('getTranslationCache returns null for non-existent key', () async {
        final translation = await storageService.getTranslationCache('nonexistent_key');
        expect(translation, isNull);
      });

      test('deleteTranslationCache deletes translation on mobile', () async {
        if (kIsWeb) {
          return; // Skip on web
        }
        
        final cacheKey = 'test_key_3';
        final translation = '{"text": "Test"}';
        
        await storageService.saveTranslationCache(cacheKey, translation);
        expect(await storageService.getTranslationCache(cacheKey), isNotNull);
        
        await storageService.deleteTranslationCache(cacheKey);
        expect(await storageService.getTranslationCache(cacheKey), isNull);
      });

      test('deleteTranslationCache deletes translation on web', () async {
        if (!kIsWeb) {
          return; // Skip on mobile
        }
        
        final cacheKey = 'test_key_3';
        final translation = '{"text": "Test"}';
        
        await storageService.saveTranslationCache(cacheKey, translation);
        expect(await storageService.getTranslationCache(cacheKey), isNotNull);
        
        await storageService.deleteTranslationCache(cacheKey);
        expect(await storageService.getTranslationCache(cacheKey), isNull);
      });

      test('clearTranslationCache clears all translations', () async {
        // Save some translations
        await storageService.saveTranslationCache('key1', 'translation1');
        await storageService.saveTranslationCache('key2', 'translation2');
        await storageService.saveTranslationCache('key3', 'translation3');
        
        // Verify they exist
        expect(await storageService.getTranslationCache('key1'), isNotNull);
        expect(await storageService.getTranslationCache('key2'), isNotNull);
        expect(await storageService.getTranslationCache('key3'), isNotNull);
        
        // Clear cache
        await storageService.clearTranslationCache();
        
        // Verify all are deleted
        expect(await storageService.getTranslationCache('key1'), isNull);
        expect(await storageService.getTranslationCache('key2'), isNull);
        expect(await storageService.getTranslationCache('key3'), isNull);
      });
    });

    group('Error Handling', () {
      test('methods throw StorageException on errors', () async {
        if (kIsWeb) {
          return; // Skip on web
        }
        
        // Try to save file with invalid source path
        expect(
          () => storageService.saveBookFile(
            sourcePath: '/invalid/path/that/does/not/exist.epub',
            fileName: 'test.epub',
          ),
          throwsA(isA<StorageException>()),
        );
      });

      test('readBookFile handles errors gracefully', () async {
        // Reading non-existent file should return null, not throw
        final content = await storageService.readBookFile('/nonexistent/file.epub');
        expect(content, isNull);
      });
    });

    group('Storage Statistics', () {
      test('getStorageStats returns correct statistics', () async {
        // Add some test data
        final book = Book(
          id: 'stats_test_book',
          title: 'Stats Test',
          author: 'Test Author',
          filePath: '/test/path.epub',
          format: 'epub',
          chapters: [],
          fullText: 'Content',
          addedAt: DateTime.now(),
        );
        
        await storageService.saveBook(book);
        
        final stats = await storageService.getStorageStats();
        
        expect(stats, isA<Map<String, dynamic>>());
        expect(stats['booksCount'], greaterThanOrEqualTo(1));
        expect(stats['platform'], isA<String>());
        
        if (kIsWeb) {
          expect(stats['webBookFilesCount'], isA<int>());
          expect(stats['webCoversCount'], isA<int>());
          expect(stats['webTranslationsCount'], isA<int>());
        }
      });

      test('getStorageSize returns total storage size', () async {
        if (kIsWeb) {
          // On web, add some test data
          final testContent = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
          await storageService.saveBookFile(
            fileName: 'size_test.epub',
            fileData: testContent,
          );
          
          final imageData = [100, 101, 102, 103, 104];
          await storageService.saveCoverImage('size_test_book', imageData);
          
          await storageService.saveTranslationCache('size_test_key', 'test translation');
          
          final size = await storageService.getStorageSize();
          expect(size, greaterThan(0));
        } else {
          // On mobile, create some test files
          final testFile = File('${tempDir.path}/size_test.epub');
          final testContent = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
          await testFile.writeAsBytes(testContent);
          
          await storageService.saveBookFile(
            sourcePath: testFile.path,
            fileName: 'size_test.epub',
          );
          
          final imageData = [100, 101, 102, 103, 104];
          await storageService.saveCoverImage('size_test_book', imageData);
          
          await storageService.saveTranslationCache('size_test_key', 'test translation');
          
          final size = await storageService.getStorageSize();
          expect(size, greaterThan(0));
        }
      });

      test('getStorageSize returns 0 for empty storage', () async {
        // Clear all storage first
        await storageService.clearAllStorage();
        
        final size = await storageService.getStorageSize();
        expect(size, equals(0));
      });
    });

    group('Backward Compatibility', () {
      test('copyBookFile works as alias for saveBookFile', () async {
        if (kIsWeb) {
          final testContent = Uint8List.fromList([1, 2, 3]);
          final path1 = await storageService.saveBookFile(
            fileName: 'test1.epub',
            fileData: testContent,
          );
          final path2 = await storageService.copyBookFile(
            '',
            'test2.epub',
            fileData: testContent,
          );
          
          expect(path1, isNotEmpty);
          expect(path2, isNotEmpty);
        } else {
          final testFile = File('${tempDir.path}/compat_test.epub');
          await testFile.writeAsBytes([1, 2, 3]);
          
          final path1 = await storageService.saveBookFile(
            sourcePath: testFile.path,
            fileName: 'compat_test1.epub',
          );
          final path2 = await storageService.copyBookFile(
            testFile.path,
            'compat_test2.epub',
          );
          
          expect(path1, isNotEmpty);
          expect(path2, isNotEmpty);
        }
      });

      test('getBookFileData works as alias for readBookFile', () async {
        if (kIsWeb) {
          final testContent = Uint8List.fromList([5, 6, 7]);
          final savedPath = await storageService.saveBookFile(
            fileName: 'alias_test.epub',
            fileData: testContent,
          );
          
          final data1 = await storageService.readBookFile(savedPath);
          final data2 = await storageService.getBookFileData(savedPath);
          
          expect(data1, equals(data2));
          expect(data1, equals(testContent));
        } else {
          final testFile = File('${tempDir.path}/alias_test.epub');
          await testFile.writeAsBytes([5, 6, 7]);
          
          final savedPath = await storageService.saveBookFile(
            sourcePath: testFile.path,
            fileName: 'alias_test.epub',
          );
          
          final data1 = await storageService.readBookFile(savedPath);
          final data2 = await storageService.getBookFileData(savedPath);
          
          expect(data1, equals(data2));
          expect(data1, equals([5, 6, 7]));
        }
      });
    });
  });
}
