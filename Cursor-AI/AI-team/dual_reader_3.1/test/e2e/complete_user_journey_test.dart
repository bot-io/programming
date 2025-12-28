import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:dual_reader/providers/book_provider.dart';
import 'package:dual_reader/providers/reader_provider.dart';
import 'package:dual_reader/providers/settings_provider.dart';
import 'package:dual_reader/providers/bookmark_provider.dart';
import 'package:dual_reader/services/storage_service.dart';
import 'package:dual_reader/services/ebook_parser.dart';
import 'package:dual_reader/services/translation_service.dart';
import 'package:dual_reader/models/book.dart';
import 'package:dual_reader/models/bookmark.dart';
import 'package:dual_reader/models/reading_progress.dart';
import 'package:dual_reader/models/app_settings.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../helpers/test_helpers.dart';

/// E2E Tests for Complete User Journeys
/// 
/// These tests verify complete user workflows from start to finish,
/// ensuring all features work together correctly.

void main() {
  group('Complete User Journey E2E Tests', () {
    late StorageService storageService;
    late EbookParser ebookParser;
    late BookProvider bookProvider;
    late ReaderProvider readerProvider;
    late SettingsProvider settingsProvider;
    late TranslationService translationService;
    late BuildContext testContext;
    late Widget testWidget;

    setUp(() async {
      await Hive.initFlutter();
      
      // Register adapters (matching main.dart registration order)
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
      
      ebookParser = EbookParser(storageService);
      bookProvider = BookProvider(storageService, ebookParser);
      translationService = TranslationService();
      await translationService.initialize();
      settingsProvider = SettingsProvider(storageService);
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
        await Hive.deleteBoxFromDisk('bookmarks');
        await Hive.deleteBoxFromDisk('settings');
      } catch (e) {
        // Ignore cleanup errors
      }
    });

    testWidgets('Complete journey: Import EPUB → Read → Translate → Bookmark → Resume', (WidgetTester tester) async {
      await tester.pumpWidget(testWidget);

      // Step 1: Import a book (save directly to storage for testing)
      final testBook = TestHelpers.createTestBook(
        id: 'journey-book-1',
        title: 'Journey Test Book',
        author: 'Test Author',
        totalPages: 50,
        fullText: TestHelpers.generateTestTextWithParagraphs(10, 100), // Generate enough text for pagination
      );

      await storageService.saveBook(testBook);
      // Wait for BookProvider to load books (it loads asynchronously in constructor)
      await tester.pumpAndSettle();
      // Verify via storageService directly for E2E test
      final savedBooks = await storageService.getAllBooks();
      expect(savedBooks.length, 1);
      expect(bookProvider.books.first.id, 'journey-book-1');

      // Step 2: Open book in reader
      await readerProvider.loadBook(testBook.id, testContext);
      expect(readerProvider.currentBook, isNotNull);
      expect(readerProvider.currentBook!.id, 'journey-book-1');
      expect(readerProvider.pages.length, greaterThan(0));
      expect(readerProvider.currentPageIndex, 0); // Start at first page (0-based)

      // Step 3: Navigate to page 5 (0-based index 4)
      await readerProvider.goToPage(4);
      expect(readerProvider.currentPageIndex, 4);
      expect(readerProvider.currentPage?.pageNumber, 5); // Page number is 1-based

      // Step 4: Enable translation (if auto-translate is off)
      final settings = settingsProvider.settings;
      if (!settings.autoTranslate) {
        await settingsProvider.updateSettings(
          settings.copyWith(autoTranslate: true),
        );
      }

      // Step 5: Add a bookmark (create BookmarkProvider for this book)
      final bookmarkProvider = BookmarkProvider(storageService, testBook.id);
      await bookmarkProvider.addBookmark(5, note: 'Important page');
      
      final bookmarks = bookmarkProvider.bookmarks;
      expect(bookmarks.length, 1);
      expect(bookmarks.first.page, 5);

      // Step 6: Navigate to page 10 (0-based index 9)
      final targetPageIndex = readerProvider.pages.length > 9 ? 9 : readerProvider.pages.length - 1;
      await readerProvider.goToPage(targetPageIndex);
      expect(readerProvider.currentPageIndex, targetPageIndex);

      // Step 7: Save progress
      await readerProvider.saveProgress();
      
      // Step 8: Close reader (simulate app close)
      readerProvider.clear();

      // Step 9: Reopen book and verify resume
      await readerProvider.loadBook(testBook.id, testContext);
      // Should resume at saved page (page 10 = index 9)
      expect(readerProvider.currentPageIndex, targetPageIndex);

      // Step 10: Verify bookmark still exists
      final restoredBookmarkProvider = BookmarkProvider(storageService, testBook.id);
      await tester.pump(); // Allow async loading
      final restoredBookmarks = restoredBookmarkProvider.bookmarks;
      expect(restoredBookmarks.length, 1);
      expect(restoredBookmarks.first.page, 5);
    });

    testWidgets('Complete journey: Import MOBI → Change Settings → Navigate Chapters → Delete Book', (WidgetTester tester) async {
      await tester.pumpWidget(testWidget);

      // Step 1: Import MOBI book (save directly to storage for testing)
      final mobiBook = TestHelpers.createTestBook(
        id: 'mobi-journey-1',
        title: 'MOBI Journey Book',
        author: 'MOBI Author',
        format: 'mobi',
        totalPages: 30,
        fullText: TestHelpers.generateTestTextWithParagraphs(8, 80),
      );

      await storageService.saveBook(mobiBook);
      // Wait for BookProvider to load books
      await tester.pumpAndSettle();
      final savedBooks = await storageService.getAllBooks();
      expect(savedBooks.length, 1);

      // Step 2: Change settings
      final currentSettings = settingsProvider.settings;
      await settingsProvider.updateSettings(
        currentSettings.copyWith(
          theme: 'light',
          fontSize: 18,
          fontFamily: 'Arial',
          translationLanguage: 'fr',
        ),
      );

      final updatedSettings = settingsProvider.settings;
      expect(updatedSettings.theme, 'light');
      expect(updatedSettings.fontSize, 18);
      expect(updatedSettings.fontFamily, 'Arial');
      expect(updatedSettings.translationLanguage, 'fr');

      // Step 3: Open book
      await readerProvider.loadBook(mobiBook.id, testContext);
      expect(readerProvider.currentBook, isNotNull);
      expect(readerProvider.pages.length, greaterThan(0));

      // Step 4: Navigate through pages (0-based indices)
      final page5Index = readerProvider.pages.length > 4 ? 4 : readerProvider.pages.length - 1;
      await readerProvider.goToPage(page5Index);
      expect(readerProvider.currentPageIndex, page5Index);
      
      final page15Index = readerProvider.pages.length > 14 ? 14 : readerProvider.pages.length - 1;
      await readerProvider.goToPage(page15Index);
      expect(readerProvider.currentPageIndex, page15Index);

      // Step 5: Delete book
      await bookProvider.deleteBook(mobiBook.id);
      expect(bookProvider.books.length, 0);

      // Step 6: Verify bookmarks are cleaned up (if any were created)
      final bookmarkProvider = BookmarkProvider(storageService, mobiBook.id);
      await tester.pump(); // Allow async loading
      final bookmarks = bookmarkProvider.bookmarks;
      expect(bookmarks, isEmpty);
    });

    test('Complete journey: Settings persist across app restarts', () async {
      // Step 1: Change multiple settings
      final initialSettings = settingsProvider.settings;
      
      await settingsProvider.updateSettings(
        initialSettings.copyWith(
          theme: 'sepia',
          fontSize: 20,
          fontFamily: 'Georgia',
          lineHeight: 1.8,
          marginSize: 4,
          textAlignment: 'justify',
          translationLanguage: 'de',
          autoTranslate: false,
        ),
      );

      // Step 2: Verify settings saved
      final savedSettings = settingsProvider.settings;
      expect(savedSettings.theme, 'sepia');
      expect(savedSettings.fontSize, 20);
      expect(savedSettings.fontFamily, 'Georgia');
      expect(savedSettings.lineHeight, 1.8);
      expect(savedSettings.marginSize, 4);
      expect(savedSettings.textAlignment, 'justify');
      expect(savedSettings.translationLanguage, 'de');
      expect(savedSettings.autoTranslate, false);

      // Step 3: Create new provider instance (simulate app restart)
      final newSettingsProvider = SettingsProvider(storageService);
      await newSettingsProvider.loadSettings();

      // Step 4: Verify settings persisted
      final restoredSettings = newSettingsProvider.settings;
      expect(restoredSettings.theme, 'sepia');
      expect(restoredSettings.fontSize, 20);
      expect(restoredSettings.fontFamily, 'Georgia');
      expect(restoredSettings.lineHeight, 1.8);
      expect(restoredSettings.marginSize, 4);
      expect(restoredSettings.textAlignment, 'justify');
      expect(restoredSettings.translationLanguage, 'de');
      expect(restoredSettings.autoTranslate, false);
    });

    testWidgets('Complete journey: Multiple books → Navigate between them', (WidgetTester tester) async {
      await tester.pumpWidget(testWidget);

      // Step 1: Import multiple books (save directly to storage for testing)
      final book1 = TestHelpers.createTestBook(
        id: 'multi-book-1',
        title: 'Book One',
        totalPages: 20,
        fullText: TestHelpers.generateTestTextWithParagraphs(6, 70),
      );
      final book2 = TestHelpers.createTestBook(
        id: 'multi-book-2',
        title: 'Book Two',
        totalPages: 30,
        fullText: TestHelpers.generateTestTextWithParagraphs(8, 80),
      );
      final book3 = TestHelpers.createTestBook(
        id: 'multi-book-3',
        title: 'Book Three',
        totalPages: 40,
        fullText: TestHelpers.generateTestTextWithParagraphs(10, 90),
      );

      await storageService.saveBook(book1);
      await storageService.saveBook(book2);
      await storageService.saveBook(book3);
      // Wait for BookProvider to load books
      await tester.pumpAndSettle();
      final savedBooks = await storageService.getAllBooks();
      expect(savedBooks.length, 3);

      // Step 2: Open first book and read to page 10 (0-based index 9)
      await readerProvider.loadBook(book1.id, testContext);
      final book1Page10Index = readerProvider.pages.length > 9 ? 9 : readerProvider.pages.length - 1;
      await readerProvider.goToPage(book1Page10Index);
      await readerProvider.saveProgress();
      expect(readerProvider.currentPageIndex, book1Page10Index);

      // Step 3: Switch to second book and read to page 15 (0-based index 14)
      await readerProvider.loadBook(book2.id, testContext);
      final book2Page15Index = readerProvider.pages.length > 14 ? 14 : readerProvider.pages.length - 1;
      await readerProvider.goToPage(book2Page15Index);
      await readerProvider.saveProgress();
      expect(readerProvider.currentPageIndex, book2Page15Index);

      // Step 4: Switch to third book and read to page 20 (0-based index 19)
      await readerProvider.loadBook(book3.id, testContext);
      final book3Page20Index = readerProvider.pages.length > 19 ? 19 : readerProvider.pages.length - 1;
      await readerProvider.goToPage(book3Page20Index);
      await readerProvider.saveProgress();
      expect(readerProvider.currentPageIndex, book3Page20Index);

      // Step 5: Switch back to first book and verify progress
      await readerProvider.loadBook(book1.id, testContext);
      expect(readerProvider.currentPageIndex, book1Page10Index); // Should resume at saved page

      // Step 6: Switch back to second book and verify progress
      await readerProvider.loadBook(book2.id, testContext);
      expect(readerProvider.currentPageIndex, book2Page15Index); // Should resume at saved page

      // Step 7: Switch back to third book and verify progress
      await readerProvider.loadBook(book3.id, testContext);
      expect(readerProvider.currentPageIndex, book3Page20Index); // Should resume at saved page
    });

    testWidgets('Complete journey: Bookmark management across sessions', (WidgetTester tester) async {
      await tester.pumpWidget(testWidget);

      // Step 1: Import book (save directly to storage for testing)
      final book = TestHelpers.createTestBook(
        id: 'bookmark-journey-1',
        title: 'Bookmark Journey Book',
        totalPages: 50,
        fullText: TestHelpers.generateTestTextWithParagraphs(12, 100),
      );

      await storageService.saveBook(book);
      // Wait for BookProvider to load books
      await tester.pumpAndSettle();
      await readerProvider.loadBook(book.id, testContext);

      // Step 2: Add multiple bookmarks (create BookmarkProvider for this book)
      final bookmarkProvider = BookmarkProvider(storageService, book.id);
      await bookmarkProvider.addBookmark(5, note: 'First bookmark');
      await bookmarkProvider.addBookmark(15, note: 'Second bookmark');
      await bookmarkProvider.addBookmark(25, note: 'Third bookmark');

      await tester.pump(); // Allow async loading
      var bookmarks = bookmarkProvider.bookmarks;
      expect(bookmarks.length, 3);

      // Step 3: Navigate to bookmark (page 15 = 0-based index 14)
      final bookmark2PageIndex = readerProvider.pages.length > 14 ? 14 : readerProvider.pages.length - 1;
      await readerProvider.goToPage(bookmark2PageIndex);
      expect(readerProvider.currentPageIndex, bookmark2PageIndex);

      // Step 4: Delete a bookmark
      final bookmark2 = bookmarks.firstWhere((b) => b.page == 15);
      await bookmarkProvider.deleteBookmark(bookmark2.id);
      await tester.pump(); // Allow async loading
      bookmarks = bookmarkProvider.bookmarks;
      expect(bookmarks.length, 2);

      // Step 5: Close and reopen (simulate app restart)
      readerProvider.clear();
      await readerProvider.loadBook(book.id, testContext);

      // Step 6: Verify bookmarks persisted
      final restoredBookmarkProvider = BookmarkProvider(storageService, book.id);
      await tester.pump(); // Allow async loading
      final restoredBookmarks = restoredBookmarkProvider.bookmarks;
      expect(restoredBookmarks.length, 2);
      expect(restoredBookmarks.any((b) => b.page == 5), true);
      expect(restoredBookmarks.any((b) => b.page == 25), true);
      expect(restoredBookmarks.any((b) => b.page == 15), false);
    });
  });
}
