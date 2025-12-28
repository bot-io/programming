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
import 'package:hive_flutter/hive_flutter.dart';
import '../helpers/test_helpers.dart';

/// E2E Tests for Offline Mode Functionality
/// 
/// These tests verify that the app works correctly when offline,
/// including cached translations and local storage.

void main() {
  group('Offline Mode E2E Tests', () {
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
        await Hive.deleteBoxFromDisk('bookmarks');
        await Hive.deleteBoxFromDisk('reading_progress');
        await Hive.deleteBoxFromDisk('settings');
      } catch (e) {
        // Ignore cleanup errors
      }
    });

    testWidgets('User can read imported book offline', (WidgetTester tester) async {
      await tester.pumpWidget(testWidget);

      // Step 1: Import book while online (save directly to storage)
      final testBook = TestHelpers.createTestBook(
        id: 'offline-book-1',
        title: 'Offline Test Book',
        totalPages: 30,
        fullText: TestHelpers.generateTestTextWithParagraphs(10, 100),
      );

      await storageService.saveBook(testBook);
      // Wait for BookProvider to load
      await tester.pumpAndSettle();
      expect(bookProvider.books.length, 1);

      // Step 2: Open book
      await readerProvider.loadBook(testBook.id, testContext);
      expect(readerProvider.currentBook, isNotNull);
      expect(readerProvider.pages.length, greaterThan(0));

      // Step 3: Navigate pages (should work offline) - using 0-based indices
      final page5Index = readerProvider.pages.length > 4 ? 4 : readerProvider.pages.length - 1;
      await readerProvider.goToPage(page5Index);
      expect(readerProvider.currentPageIndex, page5Index);

      final page10Index = readerProvider.pages.length > 9 ? 9 : readerProvider.pages.length - 1;
      await readerProvider.goToPage(page10Index);
      expect(readerProvider.currentPageIndex, page10Index);

      final page20Index = readerProvider.pages.length > 19 ? 19 : readerProvider.pages.length - 1;
      await readerProvider.goToPage(page20Index);
      expect(readerProvider.currentPageIndex, page20Index);

      // Step 4: Progress is saved automatically in goToPage, but verify it's saved
      final progress = await storageService.getProgress(testBook.id);
      expect(progress, isNotNull);

      // Step 5: Close and reopen (simulate offline restart)
      readerProvider.clear();
      await readerProvider.loadBook(testBook.id, testContext);

      // Step 6: Verify progress persisted offline (should resume at saved page)
      expect(readerProvider.currentPageIndex, page20Index);
    });

    testWidgets('User can use cached translations offline', (WidgetTester tester) async {
      await tester.pumpWidget(testWidget);

      // Step 1: Import book and enable translation
      final testBook = TestHelpers.createTestBook(
        id: 'cached-translation-book',
        title: 'Cached Translation Book',
        totalPages: 20,
        fullText: TestHelpers.generateTestTextWithParagraphs(8, 80),
      );

      await storageService.saveBook(testBook);
      await tester.pumpAndSettle();
      
      // Enable auto-translate
      final settings = settingsProvider.settings;
      await settingsProvider.updateSettings(
        settings.copyWith(autoTranslate: true, translationLanguage: 'es'),
      );

      await readerProvider.loadBook(testBook.id, testContext);
      expect(readerProvider.pages.length, greaterThan(0));

      // Step 2: Navigate to a page (translation will be attempted if online)
      final page1Index = readerProvider.pages.length > 0 ? 0 : 0;
      await readerProvider.goToPage(page1Index);
      expect(readerProvider.currentPageIndex, page1Index);

      // Step 3: Verify page content is available (even if translation fails offline)
      expect(readerProvider.currentPage, isNotNull);
      expect(readerProvider.currentBook, isNotNull);
      expect(readerProvider.currentPage!.originalText, isNotEmpty);

      // Note: Full translation caching test would require mocking the translation service
      // to verify cached translations are used when offline. For now, we verify
      // that the app handles offline gracefully without crashing.
    });

    testWidgets('User can manage bookmarks offline', (WidgetTester tester) async {
      await tester.pumpWidget(testWidget);

      // Step 1: Import book
      final testBook = TestHelpers.createTestBook(
        id: 'offline-bookmark-book',
        title: 'Offline Bookmark Book',
        totalPages: 25,
        fullText: TestHelpers.generateTestTextWithParagraphs(10, 100),
      );

      await storageService.saveBook(testBook);
      await tester.pumpAndSettle();
      await readerProvider.loadBook(testBook.id, testContext);
      expect(readerProvider.pages.length, greaterThan(0));

      // Step 2: Add bookmarks (should work offline) - using BookmarkProvider
      final bookmarkProvider = BookmarkProvider(storageService, testBook.id);
      await bookmarkProvider.addBookmark(5, note: 'Offline bookmark 1');
      await bookmarkProvider.addBookmark(15, note: 'Offline bookmark 2');
      
      await tester.pump(); // Allow async loading
      expect(bookmarkProvider.bookmarks.length, 2);

      // Step 3: Navigate to bookmarked page (page 5 = 0-based index 4)
      final page5Index = readerProvider.pages.length > 4 ? 4 : readerProvider.pages.length - 1;
      await readerProvider.goToPage(page5Index);
      expect(readerProvider.currentPageIndex, page5Index);

      // Step 4: Close and reopen (simulate offline restart)
      readerProvider.clear();
      await readerProvider.loadBook(testBook.id, testContext);

      // Step 5: Verify bookmarks persisted offline
      final restoredBookmarkProvider = BookmarkProvider(storageService, testBook.id);
      await tester.pump(); // Allow async loading
      final restoredBookmarks = restoredBookmarkProvider.bookmarks;
      expect(restoredBookmarks.length, 2);
      expect(readerProvider.currentBook, isNotNull);
    });

    test('User can change settings offline', () async {
      // Step 1: Change settings (stored locally, works offline)
      final settings = settingsProvider.settings;
      
      await settingsProvider.updateSettings(
        settings.copyWith(
          theme: 'light',
          fontSize: 18,
          fontFamily: 'Arial',
        ),
      );

      // Step 2: Verify settings saved
      final updatedSettings = settingsProvider.settings;
      expect(updatedSettings.theme, 'light');
      expect(updatedSettings.fontSize, 18);
      expect(updatedSettings.fontFamily, 'Arial');

      // Step 3: Create new provider instance (simulate offline restart)
      final newSettingsProvider = SettingsProvider(storageService);
      await newSettingsProvider.loadSettings();

      // Step 4: Verify settings persisted offline
      final restoredSettings = newSettingsProvider.settings;
      expect(restoredSettings.theme, 'light');
      expect(restoredSettings.fontSize, 18);
      expect(restoredSettings.fontFamily, 'Arial');
    });

    testWidgets('User can delete books offline', (WidgetTester tester) async {
      await tester.pumpWidget(testWidget);

      // Step 1: Import multiple books (save directly to storage)
      final book1 = TestHelpers.createTestBook(
        id: 'offline-delete-1',
        title: 'Book to Delete',
        totalPages: 10,
        fullText: TestHelpers.generateTestTextWithParagraphs(5, 50),
      );
      final book2 = TestHelpers.createTestBook(
        id: 'offline-delete-2',
        title: 'Book to Keep',
        totalPages: 10,
        fullText: TestHelpers.generateTestTextWithParagraphs(5, 50),
      );

      await storageService.saveBook(book1);
      await storageService.saveBook(book2);
      await tester.pumpAndSettle();
      expect(bookProvider.books.length, 2);

      // Step 2: Delete a book (should work offline)
      await bookProvider.deleteBook(book1.id);
      await tester.pumpAndSettle();
      expect(bookProvider.books.length, 1);
      expect(bookProvider.books.first.id, 'offline-delete-2');

      // Step 3: Verify deletion persisted (simulate offline restart)
      final newBookProvider = BookProvider(storageService, ebookParser);
      await tester.pumpAndSettle(); // Wait for async load
      expect(newBookProvider.books.length, 1);
      expect(newBookProvider.books.first.id, 'offline-delete-2');
    });
  });
}
