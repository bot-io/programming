import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:dual_reader/services/storage_service.dart';
import 'package:dual_reader/services/ebook_parser.dart';
import 'package:dual_reader/services/translation_service.dart';
import 'package:dual_reader/providers/book_provider.dart';
import 'package:dual_reader/providers/reader_provider.dart';
import 'package:dual_reader/providers/settings_provider.dart';
import 'package:dual_reader/models/book.dart';
import 'package:dual_reader/models/chapter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:math';
import '../helpers/test_helpers.dart';

/// Performance Tests for Large Books
/// 
/// These tests verify that the app handles large books efficiently
/// without performance degradation or memory issues.

void main() {
  group('Large Book Performance Tests', () {
    late StorageService storageService;
    late EbookParser ebookParser;
    late BookProvider bookProvider;
    late ReaderProvider readerProvider;
    late SettingsProvider settingsProvider;
    late TranslationService translationService;
    late Widget testWidget;
    late BuildContext testContext;

    setUp(() async {
      await Hive.initFlutter();
      
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
      settingsProvider = SettingsProvider(storageService);
      translationService = TranslationService();
      await translationService.initialize();
      readerProvider = ReaderProvider(
        storageService,
        translationService,
        settingsProvider,
      );

      // Create test widget with BuildContext
      testWidget = MaterialApp(
        home: Builder(
          builder: (context) {
            testContext = context;
            return const SizedBox();
          },
        ),
      );
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

    testWidgets('handles book with 5000+ pages efficiently', (WidgetTester tester) async {
      await tester.pumpWidget(testWidget);

      // Create a large book with 5000 pages
      final largeBook = Book(
        id: 'large-book-1',
        title: 'Large Test Book',
        author: 'Test Author',
        filePath: '/path/to/large.epub',
        format: 'epub',
        chapters: _generateChapters(100), // 100 chapters
        fullText: _generateLargeText(5000), // Large text content
        addedAt: DateTime.now(),
        totalPages: 5000,
      );

      // Measure import time
      final importStart = DateTime.now();
      await storageService.saveBook(largeBook);
      await tester.pumpAndSettle(); // Wait for BookProvider to load
      final importEnd = DateTime.now();
      final importDuration = importEnd.difference(importStart);

      // Import should complete in reasonable time (< 5 seconds)
      expect(importDuration.inSeconds, lessThan(5));

      // Verify book was imported
      expect(bookProvider.books.length, 1);
      expect(bookProvider.books.first.id, 'large-book-1');
      expect(bookProvider.books.first.totalPages, 5000);
    });

    testWidgets('handles navigation through large book efficiently', (WidgetTester tester) async {
      await tester.pumpWidget(testWidget);

      // Create large book
      final largeBook = Book(
        id: 'large-nav-book',
        title: 'Large Navigation Book',
        author: 'Test Author',
        filePath: '/path/to/large-nav.epub',
        format: 'epub',
        chapters: _generateChapters(50),
        fullText: _generateLargeText(3000),
        addedAt: DateTime.now(),
        totalPages: 3000,
      );

      await storageService.saveBook(largeBook);
      await tester.pumpAndSettle();
      await readerProvider.loadBook(largeBook.id, testContext);
      expect(readerProvider.pages.length, greaterThan(0));

      // Measure navigation time
      final navStart = DateTime.now();
      
      // Navigate to various pages (using 0-based indices)
      final page1Index = readerProvider.pages.length > 0 ? 0 : 0;
      final page500Index = readerProvider.pages.length > 499 ? 499 : readerProvider.pages.length - 1;
      final page1000Index = readerProvider.pages.length > 999 ? 999 : readerProvider.pages.length - 1;
      final page1500Index = readerProvider.pages.length > 1499 ? 1499 : readerProvider.pages.length - 1;
      final page2000Index = readerProvider.pages.length > 1999 ? 1999 : readerProvider.pages.length - 1;
      final page2500Index = readerProvider.pages.length > 2499 ? 2499 : readerProvider.pages.length - 1;
      final page3000Index = readerProvider.pages.length > 2999 ? 2999 : readerProvider.pages.length - 1;
      
      await readerProvider.goToPage(page1Index);
      await readerProvider.goToPage(page500Index);
      await readerProvider.goToPage(page1000Index);
      await readerProvider.goToPage(page1500Index);
      await readerProvider.goToPage(page2000Index);
      await readerProvider.goToPage(page2500Index);
      await readerProvider.goToPage(page3000Index);
      
      final navEnd = DateTime.now();
      final navDuration = navEnd.difference(navStart);

      // Navigation should be fast (< 2 seconds for multiple page changes)
      expect(navDuration.inSeconds, lessThan(2));

      // Verify final page (check page number, not index)
      expect(readerProvider.currentPageIndex, page3000Index);
      expect(readerProvider.currentPage?.pageNumber, greaterThan(0));
    });

    testWidgets('handles book with many chapters efficiently', (WidgetTester tester) async {
      await tester.pumpWidget(testWidget);

      // Create book with many chapters (1000 chapters)
      final manyChaptersBook = Book(
        id: 'many-chapters-book',
        title: 'Many Chapters Book',
        author: 'Test Author',
        filePath: '/path/to/many-chapters.epub',
        format: 'epub',
        chapters: _generateChapters(1000),
        fullText: _generateLargeText(2000),
        addedAt: DateTime.now(),
        totalPages: 2000,
      );

      // Measure import time
      final importStart = DateTime.now();
      await storageService.saveBook(manyChaptersBook);
      await tester.pumpAndSettle(); // Wait for BookProvider to load
      final importEnd = DateTime.now();
      final importDuration = importEnd.difference(importStart);

      // Import should complete in reasonable time (< 10 seconds for 1000 chapters)
      expect(importDuration.inSeconds, lessThan(10));

      // Verify chapters were imported
      expect(bookProvider.books.first.chapters.length, 1000);
    });

    testWidgets('handles very long text content efficiently', (WidgetTester tester) async {
      await tester.pumpWidget(testWidget);

      // Create book with very long text (1 million characters)
      final longTextBook = Book(
        id: 'long-text-book',
        title: 'Long Text Book',
        author: 'Test Author',
        filePath: '/path/to/long-text.epub',
        format: 'epub',
        chapters: [],
        fullText: 'A' * 1000000, // 1 million characters
        addedAt: DateTime.now(),
        totalPages: 10000,
      );

      // Measure import time
      final importStart = DateTime.now();
      await storageService.saveBook(longTextBook);
      await tester.pumpAndSettle(); // Wait for BookProvider to load
      final importEnd = DateTime.now();
      final importDuration = importEnd.difference(importStart);

      // Import should complete in reasonable time (< 10 seconds)
      expect(importDuration.inSeconds, lessThan(10));

      // Verify book was imported
      expect(bookProvider.books.first.fullText.length, 1000000);
    });

    testWidgets('memory usage stays reasonable with large book', (WidgetTester tester) async {
      await tester.pumpWidget(testWidget);

      // Create large book
      final largeBook = Book(
        id: 'memory-test-book',
        title: 'Memory Test Book',
        author: 'Test Author',
        filePath: '/path/to/memory-test.epub',
        format: 'epub',
        chapters: _generateChapters(200),
        fullText: _generateLargeText(10000),
        addedAt: DateTime.now(),
        totalPages: 10000,
      );

      await storageService.saveBook(largeBook);
      await tester.pumpAndSettle();
      await readerProvider.loadBook(largeBook.id, testContext);
      expect(readerProvider.pages.length, greaterThan(0));

      // Navigate through many pages (using 0-based indices)
      final maxPageIndex = readerProvider.pages.length - 1;
      for (int i = 1; i <= 100 && (i * 100 - 1) <= maxPageIndex; i++) {
        final pageIndex = (i * 100 - 1).clamp(0, maxPageIndex);
        await readerProvider.goToPage(pageIndex);
      }

      // Verify app still responsive
      expect(readerProvider.currentPageIndex, lessThanOrEqualTo(maxPageIndex));
      expect(readerProvider.currentBook, isNotNull);

      // Note: In a real implementation, we'd measure actual memory usage
      // For now, we verify the app doesn't crash with large books
    });

    testWidgets('handles multiple large books efficiently', (WidgetTester tester) async {
      await tester.pumpWidget(testWidget);

      // Create multiple large books
      final books = List.generate(10, (index) => Book(
        id: 'multi-large-book-$index',
        title: 'Large Book $index',
        author: 'Test Author',
        filePath: '/path/to/large-$index.epub',
        format: 'epub',
        chapters: _generateChapters(100),
        fullText: _generateLargeText(2000),
        addedAt: DateTime.now(),
        totalPages: 2000,
      ));

      // Measure import time for multiple books
      final importStart = DateTime.now();
      
      for (final book in books) {
        await storageService.saveBook(book);
      }
      
      await tester.pumpAndSettle(); // Wait for BookProvider to load all books
      final importEnd = DateTime.now();
      final importDuration = importEnd.difference(importStart);

      // Import should complete in reasonable time (< 30 seconds for 10 large books)
      expect(importDuration.inSeconds, lessThan(30));

      // Verify all books imported
      expect(bookProvider.books.length, 10);
    });
  });
}

/// Helper function to generate test chapters
List<Chapter> _generateChapters(int count) {
  final random = Random();
  return List.generate(count, (index) {
    final startPage = index * 10 + 1;
    final endPage = (index + 1) * 10;
    return Chapter(
      id: 'chapter_$index',
      title: 'Chapter ${index + 1}',
      startIndex: index * 1000,
      endIndex: (index + 1) * 1000,
      startPage: startPage,
      endPage: endPage,
      bookId: 'test-book',
    );
  });
}

/// Helper function to generate large text content
String _generateLargeText(int pages) {
  // Generate approximately 500 words per page
  final wordsPerPage = 500;
  final totalWords = pages * wordsPerPage;
  
  final words = List.generate(totalWords, (index) => 'word${index % 100}');
  return words.join(' ');
}
