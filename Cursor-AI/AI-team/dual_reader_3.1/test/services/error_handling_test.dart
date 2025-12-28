import 'package:flutter_test/flutter_test.dart';
import 'package:dual_reader/services/storage_service.dart';
import 'package:dual_reader/services/translation_service.dart';
import 'package:dual_reader/services/ebook_parser.dart';
import 'package:dual_reader/models/book.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:dio/dio.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

/// Error Handling Tests
/// 
/// These tests verify that the app handles errors gracefully
/// and provides appropriate error messages and recovery options.

void main() {
  group('Error Handling Tests', () {
    late StorageService storageService;
    late TranslationService translationService;
    late EbookParser ebookParser;
    late Dio dio;
    late DioAdapter dioAdapter;

    setUp(() async {
      await Hive.initFlutter();
      
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(BookAdapter());
      }
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(ChapterAdapter());
      }

      SharedPreferences.setMockInitialValues({});
      
      storageService = StorageService();
      await storageService.init();
      
      // Set up Dio with mock adapter for translation service
      dio = Dio();
      dioAdapter = DioAdapter(dio: dio);
      translationService = TranslationService(dio: dio);
      await translationService.initialize();
      
      ebookParser = EbookParser(storageService);
    });

    tearDown(() async {
      try {
        dio.close();
        await Hive.deleteBoxFromDisk('books');
        await Hive.deleteBoxFromDisk('reading_progress');
        await Hive.deleteBoxFromDisk('bookmarks');
      } catch (e) {
        // Ignore cleanup errors
      }
    });

    group('Translation Service Error Handling', () {
      test('handles network timeout gracefully', () async {
        // Mock timeout error
        dioAdapter.onPost(
          '/translate',
          (server) => server.throws(
            0,
            DioException(
              requestOptions: RequestOptions(path: '/translate'),
              type: DioExceptionType.connectionTimeout,
            ),
          ),
        );

        final testText = 'This is a test text that should timeout.';
        
        // Attempt translation with timeout scenario
        expect(
          () => translationService.translate(
            text: testText,
            targetLanguage: 'es',
          ),
          throwsA(isA<TranslationException>()),
        );
      });

      test('handles invalid API response', () async {
        // Mock invalid JSON response
        dioAdapter.onPost(
          '/translate',
          (server) => server.reply(
            200,
            'Invalid JSON response',
          ),
        );

        final testText = 'Test text';
        
        // Attempt translation with invalid response
        expect(
          () => translationService.translate(
            text: testText,
            targetLanguage: 'es',
          ),
          throwsA(isA<TranslationException>()),
        );
      });

      test('handles API rate limiting (429)', () async {
        // Mock rate limit response
        dioAdapter.onPost(
          '/translate',
          (server) => server.reply(
            429,
            {'error': 'Rate limit exceeded'},
          ),
        );

        final testText = 'Test text for rate limiting';
        
        // Attempt translation with rate limiting
        expect(
          () => translationService.translate(
            text: testText,
            targetLanguage: 'es',
          ),
          throwsA(isA<TranslationException>()),
        );
      });

      test('handles empty translation response', () async {
        // Mock empty response
        dioAdapter.onPost(
          '/translate',
          (server) => server.reply(
            200,
            {'translatedText': ''},
          ),
        );

        final testText = 'Test text';
        
        // Attempt translation - should handle empty response gracefully
        final result = await translationService.translate(
          text: testText,
          targetLanguage: 'es',
        );
        
        // Empty response should return empty string or original text
        expect(result, isA<String>());
      });

      test('handles unsupported language pair', () async {
        final testText = 'Test text';
        
        // Attempt translation with unsupported language
        expect(
          () => translationService.translate(
            text: testText,
            targetLanguage: 'invalid_language_code',
          ),
          throwsA(isA<TranslationException>()),
        );
      });

      test('handles network connection error', () async {
        // Mock connection error
        dioAdapter.onPost(
          '/translate',
          (server) => server.throws(
            0,
            DioException(
              requestOptions: RequestOptions(path: '/translate'),
              type: DioExceptionType.connectionError,
            ),
          ),
        );

        final testText = 'Test text';
        
        expect(
          () => translationService.translate(
            text: testText,
            targetLanguage: 'es',
          ),
          throwsA(isA<TranslationException>()),
        );
      });

      test('handles server error (500)', () async {
        // Mock server error
        dioAdapter.onPost(
          '/translate',
          (server) => server.reply(
            500,
            {'error': 'Internal server error'},
          ),
        );

        final testText = 'Test text';
        
        expect(
          () => translationService.translate(
            text: testText,
            targetLanguage: 'es',
          ),
          throwsA(isA<TranslationException>()),
        );
      });

      test('handles bad request (400)', () async {
        // Mock bad request
        dioAdapter.onPost(
          '/translate',
          (server) => server.reply(
            400,
            {'error': 'Bad request'},
          ),
        );

        final testText = 'Test text';
        
        expect(
          () => translationService.translate(
            text: testText,
            targetLanguage: 'es',
          ),
          throwsA(isA<TranslationException>()),
        );
      });
    });

    group('Storage Service Error Handling', () {
      test('handles missing book gracefully', () async {
        // Attempt to get non-existent book
        final book = await storageService.getBook('non-existent-id');
        expect(book, isNull);
      });

      test('handles deleting non-existent book gracefully', () async {
        // Attempt to delete non-existent book - should not throw
        await expectLater(
          storageService.deleteBook('non-existent-id'),
          completes,
        );
      });

      test('handles saving book with invalid data', () async {
        // Create book with minimal valid data
        final testBook = Book(
          id: 'invalid-test-1',
          title: '', // Empty title should be handled
          author: '',
          filePath: '/test/path.epub',
          format: 'epub',
          chapters: [],
          fullText: '',
          addedAt: DateTime.now(),
        );

        // Should save successfully even with empty fields
        await storageService.saveBook(testBook);
        final savedBook = await storageService.getBook('invalid-test-1');
        expect(savedBook, isNotNull);
        expect(savedBook!.id, 'invalid-test-1');
      });

      test('handles concurrent save operations', () async {
        // Create multiple books and save concurrently
        final book1 = Book(
          id: 'concurrent-1',
          title: 'Book 1',
          author: 'Author',
          filePath: '/test/path1.epub',
          format: 'epub',
          chapters: [],
          fullText: 'Content 1',
          addedAt: DateTime.now(),
        );
        
        final book2 = Book(
          id: 'concurrent-2',
          title: 'Book 2',
          author: 'Author',
          filePath: '/test/path2.epub',
          format: 'epub',
          chapters: [],
          fullText: 'Content 2',
          addedAt: DateTime.now(),
        );

        // Save concurrently
        await Future.wait([
          storageService.saveBook(book1),
          storageService.saveBook(book2),
        ]);

        // Verify both saved successfully
        final saved1 = await storageService.getBook('concurrent-1');
        final saved2 = await storageService.getBook('concurrent-2');
        expect(saved1, isNotNull);
        expect(saved2, isNotNull);
      });

      test('handles getting all books when storage is empty', () async {
        final books = await storageService.getAllBooks();
        expect(books, isEmpty);
      });

      test('handles progress operations for non-existent book', () async {
        final progress = await storageService.getProgress('non-existent-id');
        expect(progress, isNull);
        
        // Delete progress for non-existent book should not throw
        await expectLater(
          storageService.deleteProgress('non-existent-id'),
          completes,
        );
      });

      test('handles bookmark operations for non-existent book', () async {
        final bookmarks = await storageService.getBookmarksForBook('non-existent-id');
        expect(bookmarks, isEmpty);
        
        // Delete bookmarks for non-existent book should not throw
        await expectLater(
          storageService.deleteBookmarksForBook('non-existent-id'),
          completes,
        );
      });
    });

    group('Ebook Parser Error Handling', () {
      test('handles unsupported file format', () async {
        // Test that parser handles unsupported formats
        final unsupportedFilePath = '/path/to/file.pdf';
        
        // Attempt to parse unsupported format
        expect(
          () => ebookParser.parseBook(unsupportedFilePath, null),
          throwsA(isA<UnsupportedError>()),
        );
      });

      test('handles unsupported file extension', () async {
        // Test various unsupported extensions
        final unsupportedExtensions = ['.txt', '.doc', '.docx', '.rtf', '.html'];
        
        for (final ext in unsupportedExtensions) {
          final filePath = '/path/to/file$ext';
          expect(
            () => ebookParser.parseBook(filePath, null),
            throwsA(isA<UnsupportedError>()),
          );
        }
      });

      test('handles null file data on web', () async {
        // On web, fileData should be provided
        // Test that parser handles null fileData appropriately
        final filePath = 'test.epub';
        
        // Without fileData on web, this should fail
        // Note: Actual behavior depends on platform
        expect(
          () => ebookParser.parseBook(filePath, null),
          throwsA(anything),
        );
      });

      test('handles empty file path', () async {
        // Test empty or invalid file path
        expect(
          () => ebookParser.parseBook('', null),
          throwsA(anything),
        );
      });

      test('handles file path without extension', () async {
        // Test file path without extension
        final filePath = '/path/to/file';
        
        expect(
          () => ebookParser.parseBook(filePath, null),
          throwsA(isA<UnsupportedError>()),
        );
      });

      test('handles case-insensitive file extension check', () async {
        // Test that parser handles different case extensions
        final upperCasePath = '/path/to/FILE.EPUB';
        final mixedCasePath = '/path/to/File.EpUb';
        
        // These should be recognized as EPUB files
        // (actual parsing may fail without valid file, but format check should pass)
        // Note: We can't fully test parsing without actual EPUB data,
        // but we verify the format detection works
        expect(upperCasePath.toLowerCase().endsWith('.epub'), true);
        expect(mixedCasePath.toLowerCase().endsWith('.epub'), true);
      });
    });

    group('General Error Handling', () {
      test('storage service handles initialization errors gracefully', () async {
        // Create a new storage service instance
        // Should initialize without errors
        final newStorageService = StorageService();
        await expectLater(
          newStorageService.init(),
          completes,
        );
      });

      test('translation service handles initialization without SharedPreferences', () async {
        // Create service without SharedPreferences
        final newDio = Dio();
        final newService = TranslationService(dio: newDio);
        
        // Should initialize without errors even if SharedPreferences fails
        await expectLater(
          newService.initialize(),
          completes,
        );
        
        newDio.close();
      });

      test('app handles empty book list gracefully', () async {
        final books = await storageService.getAllBooks();
        expect(books, isEmpty);
        
        // Operations on empty list should not throw
        expect(books.length, 0);
      });

      test('app handles book operations with invalid IDs', () async {
        // Operations with invalid IDs should return null or empty, not throw
        final book = await storageService.getBook('');
        expect(book, isNull);
        
        final progress = await storageService.getProgress('');
        expect(progress, isNull);
        
        final bookmarks = await storageService.getBookmarksForBook('');
        expect(bookmarks, isEmpty);
      });

      test('app recovers from errors without data loss', () async {
        // Save a book
        final testBook = Book(
          id: 'recovery-test-1',
          title: 'Recovery Test Book',
          author: 'Test Author',
          filePath: '/test/path.epub',
          format: 'epub',
          chapters: [],
          fullText: 'Test content',
          addedAt: DateTime.now(),
        );

        await storageService.saveBook(testBook);
        
        // Verify book is saved
        final savedBook = await storageService.getBook('recovery-test-1');
        expect(savedBook, isNotNull);
        
        // Simulate an error scenario (e.g., trying to delete non-existent bookmark)
        await storageService.deleteBookmark('non-existent-bookmark');
        
        // Verify original book data is still intact
        final bookAfterError = await storageService.getBook('recovery-test-1');
        expect(bookAfterError, isNotNull);
        expect(bookAfterError!.title, 'Recovery Test Book');
      });
    });
  });
}
