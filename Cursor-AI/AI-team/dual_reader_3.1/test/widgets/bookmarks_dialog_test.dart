import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:dual_reader/widgets/bookmarks_dialog.dart';
import 'package:dual_reader/providers/bookmark_provider.dart';
import 'package:dual_reader/providers/reader_provider.dart';
import 'package:dual_reader/services/storage_service.dart';
import 'package:dual_reader/services/translation_service.dart';
import 'package:dual_reader/providers/settings_provider.dart';
import 'package:dual_reader/models/bookmark.dart';
import '../helpers/test_helpers.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() {
  group('BookmarksDialog Widget Tests', () {
    late StorageService storageService;
    late BookmarkProvider bookmarkProvider;
    late ReaderProvider readerProvider;
    late SettingsProvider settingsProvider;
    late TranslationService translationService;

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
      
      translationService = TranslationService();
      await translationService.initialize();
      
      settingsProvider = SettingsProvider(storageService);
      
      bookmarkProvider = BookmarkProvider(storageService, 'test-book-1');
      readerProvider = ReaderProvider(storageService, translationService, settingsProvider);
    });

    tearDown(() async {
      bookmarkProvider.dispose();
      readerProvider.dispose();
      
      // Clean up test data
      try {
        await Hive.deleteBoxFromDisk('bookmarks');
      } catch (e) {
        // Ignore errors if boxes don't exist
      }
    });

    testWidgets('displays empty state when no bookmarks exist', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultiProvider(
              providers: [
                ChangeNotifierProvider<BookmarkProvider>.value(value: bookmarkProvider),
                ChangeNotifierProvider<ReaderProvider>.value(value: readerProvider),
              ],
              child: const BookmarksDialog(),
            ),
          ),
        ),
      );

      // Wait for async loading to complete
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.text('No bookmarks yet'), findsOneWidget);
      expect(find.text('Tap the bookmark icon to save your place'), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
    });

    testWidgets('displays list of bookmarks when bookmarks exist', (WidgetTester tester) async {
      // Add test bookmarks using the provider (which triggers reload)
      await bookmarkProvider.addBookmark(10, note: 'Test note 1');
      await bookmarkProvider.addBookmark(25, note: 'Test note 2');
      
      // Wait for loading to complete
      await tester.pumpAndSettle();

      readerProvider.currentPageIndex = 9; // Page 10 is current (0-indexed)

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultiProvider(
              providers: [
                ChangeNotifierProvider<BookmarkProvider>.value(value: bookmarkProvider),
                ChangeNotifierProvider<ReaderProvider>.value(value: readerProvider),
              ],
              child: const BookmarksDialog(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Bookmarks'), findsOneWidget);
      expect(find.text('Page 10'), findsOneWidget);
      expect(find.text('Page 25'), findsOneWidget);
      expect(find.text('Test note 1'), findsOneWidget);
      expect(find.text('Test note 2'), findsOneWidget);
    });

    testWidgets('displays close button and closes dialog when tapped', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => MultiProvider(
                      providers: [
                        ChangeNotifierProvider<BookmarkProvider>.value(value: bookmarkProvider),
                        ChangeNotifierProvider<ReaderProvider>.value(value: readerProvider),
                      ],
                      child: const BookmarksDialog(),
                    ),
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Bookmarks'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.text('Bookmarks'), findsNothing);
    });

    testWidgets('displays "Add Bookmark" button', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultiProvider(
              providers: [
                ChangeNotifierProvider<BookmarkProvider>.value(value: bookmarkProvider),
                ChangeNotifierProvider<ReaderProvider>.value(value: readerProvider),
              ],
              child: const BookmarksDialog(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Add Bookmark'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('calls onBookmarkTap when bookmark is tapped', (WidgetTester tester) async {
      int? tappedPage;
      
      // Add a test bookmark using the provider
      await bookmarkProvider.addBookmark(10);
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultiProvider(
              providers: [
                ChangeNotifierProvider<BookmarkProvider>.value(value: bookmarkProvider),
                ChangeNotifierProvider<ReaderProvider>.value(value: readerProvider),
              ],
              child: BookmarksDialog(
                onBookmarkTap: (page) {
                  tappedPage = page;
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap on the bookmark list tile
      await tester.tap(find.text('Page 10'));
      await tester.pumpAndSettle();

      expect(tappedPage, 10);
    });
  });
}
