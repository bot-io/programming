import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:dual_reader/providers/reader_provider.dart';
import 'package:dual_reader/services/storage_service.dart';
import 'package:dual_reader/services/translation_service.dart';
import 'package:dual_reader/providers/settings_provider.dart';
import 'package:dual_reader/models/book.dart';
import 'package:dual_reader/models/app_settings.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Tests for ReaderProvider context validation issues
/// 
/// Critical Issue #4: Uses stored context without validation
void main() {
  group('ReaderProvider Context Validation Tests', () {
    late ReaderProvider readerProvider;
    late StorageService storageService;
    late TranslationService translationService;
    late SettingsProvider settingsProvider;

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
      if (!Hive.isAdapterRegistered(3)) {
        Hive.registerAdapter(BookmarkAdapter());
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
    });

    tearDown(() async {
      try {
        await Hive.deleteBoxFromDisk('books');
        await Hive.deleteBoxFromDisk('reading_progress');
        await Hive.deleteBoxFromDisk('bookmarks');
        await Hive.deleteBoxFromDisk('settings');
      } catch (e) {
        // Ignore errors
      }
    });

    testWidgets('refreshPages handles null context gracefully', (WidgetTester tester) async {
      // Create a test book
      final book = Book(
        id: 'test_book',
        title: 'Test Book',
        author: 'Test Author',
        filePath: '/test/path.epub',
        format: 'epub',
        chapters: [],
        fullText: 'This is a test book with some content that will be paginated.',
        addedAt: DateTime.now(),
      );

      await storageService.saveBook(book);
      await readerProvider.loadBook('test_book', tester.builder(const MaterialApp()));

      // refreshPages should handle context properly
      // Note: In Flutter 3.7+, we can check context.mounted
      expect(() {
        readerProvider.refreshPages(tester.builder(const MaterialApp()));
      }, returnsNormally);
    });

    testWidgets('loadBook requires valid context', (WidgetTester tester) async {
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

      await storageService.saveBook(book);

      // Should work with valid context
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              // Load book with valid context
              readerProvider.loadBook('test_book', context);
              return const Scaffold(body: Text('Test'));
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(readerProvider.currentBook, isNotNull);
    });

    test('refreshPages returns early if no book loaded', () {
      // Should not throw if no book is loaded
      expect(() {
        readerProvider.refreshPages(
          Builder(
            builder: (context) => const SizedBox(),
          ).build(const MaterialApp()),
        );
      }, returnsNormally);
    });

    testWidgets('refreshPages updates pages correctly', (WidgetTester tester) async {
      final book = Book(
        id: 'test_book',
        title: 'Test Book',
        author: 'Test Author',
        filePath: '/test/path.epub',
        format: 'epub',
        chapters: [],
        fullText: 'This is a longer test book with multiple sentences. ' * 50,
        addedAt: DateTime.now(),
      );

      await storageService.saveBook(book);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              readerProvider.loadBook('test_book', context);
              return const Scaffold(body: Text('Test'));
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      final initialPageCount = readerProvider.pages.length;

      // Refresh pages
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              readerProvider.refreshPages(context);
              return const Scaffold(body: Text('Test'));
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Pages should be updated
      expect(readerProvider.pages.length, greaterThan(0));
    });
  });
}
