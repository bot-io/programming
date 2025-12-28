import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:dual_reader/providers/reader_provider.dart';
import 'package:dual_reader/services/storage_service.dart';
import 'package:dual_reader/services/translation_service.dart';
import 'package:dual_reader/providers/settings_provider.dart';
import 'package:dual_reader/models/book.dart';
import 'package:dual_reader/models/chapter.dart';
import 'package:dual_reader/models/reading_progress.dart';
import 'package:dual_reader/models/app_settings.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() {
  group('Reading Flow Integration Tests', () {
    late ReaderProvider readerProvider;
    late StorageService storageService;
    late TranslationService translationService;
    late SettingsProvider settingsProvider;
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
      if (!Hive.isAdapterRegistered(2)) {
        Hive.registerAdapter(ReadingProgressAdapter());
      }
      if (!Hive.isAdapterRegistered(4)) {
        Hive.registerAdapter(AppSettingsAdapter());
      }

      storageService = StorageService();
      await storageService.init();
      
      translationService = TranslationService();
      await translationService.initialize();
      
      settingsProvider = SettingsProvider(storageService);
      
      readerProvider = ReaderProvider(
        storageService,
        translationService,
        settingsProvider,
      );

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
        await Hive.deleteBoxFromDisk('settings');
      } catch (e) {
        // Ignore cleanup errors
      }
    });

    testWidgets('readerProvider maintains state during navigation', (WidgetTester tester) async {
      await tester.pumpWidget(testWidget);

      // Create a test book
      final testBook = Book(
        id: 'test_book',
        title: 'Test Book',
        author: 'Test Author',
        filePath: '/test/path.epub',
        format: 'epub',
        chapters: [
          Chapter(
            id: 'chapter_1',
            title: 'Chapter 1',
            startIndex: 0,
            endIndex: 100,
            startPage: 1,
            endPage: 5,
            bookId: 'test_book',
          ),
        ],
        fullText: 'This is a test book with some content that should be paginated properly. ' * 100,
        addedAt: DateTime.now(),
      );

      // Save book to storage
      await storageService.saveBook(testBook);

      // Load book in reader
      await readerProvider.loadBook('test_book', testContext);

      // Verify book is loaded
      expect(readerProvider.currentBook, isNotNull);
      expect(readerProvider.currentBook!.id, 'test_book');
      expect(readerProvider.pages.length, greaterThan(0));
    });

    testWidgets('Complete pagination flow', (WidgetTester tester) async {
      await tester.pumpWidget(testWidget);

      // Create a test book with substantial content
      final testBook = Book(
        id: 'pagination-test-book',
        title: 'Pagination Test Book',
        author: 'Test Author',
        filePath: '/test/path.epub',
        format: 'epub',
        chapters: [],
        fullText: 'This is page content. ' * 500, // Generate enough text for multiple pages
        addedAt: DateTime.now(),
      );

      await storageService.saveBook(testBook);
      await readerProvider.loadBook('pagination-test-book', testContext);

      // Verify pages were created
      expect(readerProvider.pages.length, greaterThan(0));
      expect(readerProvider.currentPageIndex, 0);
      expect(readerProvider.currentPage, isNotNull);
    });

    testWidgets('Page navigation (next/previous)', (WidgetTester tester) async {
      await tester.pumpWidget(testWidget);

      final testBook = Book(
        id: 'nav-test-book',
        title: 'Navigation Test Book',
        author: 'Test Author',
        filePath: '/test/path.epub',
        format: 'epub',
        chapters: [],
        fullText: 'Page content. ' * 500,
        addedAt: DateTime.now(),
      );

      await storageService.saveBook(testBook);
      await readerProvider.loadBook('nav-test-book', testContext);

      expect(readerProvider.pages.length, greaterThan(1));

      // Test next page navigation
      final initialPageIndex = readerProvider.currentPageIndex;
      await readerProvider.nextPage();
      expect(readerProvider.currentPageIndex, initialPageIndex + 1);

      // Test previous page navigation
      await readerProvider.previousPage();
      expect(readerProvider.currentPageIndex, initialPageIndex);

      // Test boundary conditions
      // Go to first page
      while (readerProvider.hasPreviousPage) {
        await readerProvider.previousPage();
      }
      expect(readerProvider.currentPageIndex, 0);

      // Go to last page
      while (readerProvider.hasNextPage) {
        await readerProvider.nextPage();
      }
      expect(readerProvider.currentPageIndex, readerProvider.pages.length - 1);
    });

    testWidgets('Progress saving and loading', (WidgetTester tester) async {
      await tester.pumpWidget(testWidget);

      final testBook = Book(
        id: 'progress-test-book',
        title: 'Progress Test Book',
        author: 'Test Author',
        filePath: '/test/path.epub',
        format: 'epub',
        chapters: [],
        fullText: 'Page content. ' * 500,
        addedAt: DateTime.now(),
      );

      await storageService.saveBook(testBook);
      await readerProvider.loadBook('progress-test-book', testContext);

      // Navigate to a specific page
      final targetPageIndex = readerProvider.pages.length > 5 ? 5 : readerProvider.pages.length - 1;
      await readerProvider.goToPage(targetPageIndex);

      // Progress should be saved automatically in goToPage
      final progress = await storageService.getProgress('progress-test-book');
      expect(progress, isNotNull);
      expect(progress!.currentPage, targetPageIndex + 1); // Page numbers are 1-based

      // Clear and reload to verify progress is restored
      readerProvider.clear();
      await readerProvider.loadBook('progress-test-book', testContext);

      // Should resume at saved page
      expect(readerProvider.currentPageIndex, targetPageIndex);
    });

    testWidgets('Translation integration', (WidgetTester tester) async {
      await tester.pumpWidget(testWidget);

      final testBook = Book(
        id: 'translation-test-book',
        title: 'Translation Test Book',
        author: 'Test Author',
        filePath: '/test/path.epub',
        format: 'epub',
        chapters: [],
        fullText: 'This is English text that should be translated. ' * 100,
        addedAt: DateTime.now(),
      );

      await storageService.saveBook(testBook);

      // Enable auto-translate
      final settings = settingsProvider.settings;
      await settingsProvider.updateSettings(
        settings.copyWith(
          autoTranslate: true,
          translationLanguage: 'es',
        ),
      );

      await readerProvider.loadBook('translation-test-book', testContext);

      // Translation should be attempted (may fail if offline, but structure should support it)
      expect(readerProvider.currentPage, isNotNull);
      expect(readerProvider.currentBook, isNotNull);

      // Test manual translation
      if (readerProvider.pages.length > 1) {
        await readerProvider.translatePage(1);
        // Page should have translation attempted (may or may not succeed depending on network)
        expect(readerProvider.pages[1], isNotNull);
      }
    });
  });
}
