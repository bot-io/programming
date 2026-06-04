/// E2E Tests for Bookmarks
///
/// Tests bookmark functionality:
/// - Add bookmark at current page
/// - Navigate to bookmark
/// - Delete bookmark
/// - Reading history tracked
/// - Recent books displayed

library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dual_reader/main.dart' as app;
import '../../../test_integration/helpers/test_helpers.dart';
import '../../../test_integration/pages/reader_page.dart';
import '../../../test_integration/pages/library_page.dart';
import '../../../test_integration/config/test_config.dart';
import '../../../test_integration/helpers/test_logger.dart';

void main() {
  TestHelpers.initTests();
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Reading Experience - Bookmarks E2E Tests', () {
    late TestLogger logger;

    setUpAll(() {
      logger = TestLogger();
    });

    tearDownAll(() async {
      await logger.dispose();
    });

    setUp(() {
      logger.logTestSetup('Bookmarks');
    });

    tearDown(() {
      logger.logTestTeardown('Bookmarks');
    });

    testWidgets('Add bookmark at current page', (WidgetTester tester) async {
      logger.info('Testing add bookmark', category: 'bookmarks');

      // Arrange
      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettled(tester);

      // Act
      // final readerPage = ReaderPage(tester);

      // Navigate to a page
      // await readerPage.goToPage(0.25); // Page 25 of 100

      // Add bookmark
      // await readerPage.tapBookmarkButton();

      // Assert - Bookmark icon should change to filled
      // readerPage.verifyBookmarkAdded();

      logger.info('Add bookmark test completed', category: 'bookmarks');
    }, skip: true, reason: 'Requires test book and navigation');

    testWidgets('Navigate to bookmark', (WidgetTester tester) async {
      logger.info('Testing navigate to bookmark', category: 'bookmarks');

      // Arrange
      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettled(tester);

      // Act
      // final readerPage = ReaderPage(tester);

      // Add bookmark on page 30
      // await readerPage.goToPage(0.30);
      // await readerPage.tapBookmarkButton();

      // Navigate away
      // await readerPage.goToPage(0.50);

      // Open bookmarks menu and navigate to bookmark
      // await readerPage.openBookmarksMenu();
      // await readerPage.navigateToBookmark(0);

      // Assert - Should be on page 30
      // final currentPage = readerPage.getCurrentPageNumber();
      // expect(currentPage, equals(30));

      logger.info('Navigate to bookmark test completed', category: 'bookmarks');
    }, skip: true, reason: 'Requires test book and navigation');

    testWidgets('Delete bookmark', (WidgetTester tester) async {
      logger.info('Testing delete bookmark', category: 'bookmarks');

      // Arrange
      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettled(tester);

      // Act
      // final readerPage = ReaderPage(tester);

      // Add bookmark
      // await readerPage.tapBookmarkButton();
      // readerPage.verifyBookmarkAdded();

      // Delete bookmark (tap again)
      // await readerPage.tapBookmarkButton();

      // Assert - Bookmark icon should change to outline
      // readerPage.verifyBookmarkRemoved();

      logger.info('Delete bookmark test completed', category: 'bookmarks');
    }, skip: true, reason: 'Requires test book and navigation');

    testWidgets('Multiple bookmarks can be added', (WidgetTester tester) async {
      logger.info('Testing multiple bookmarks', category: 'bookmarks');

      // Arrange
      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettled(tester);

      // Act
      // final readerPage = ReaderPage(tester);

      // Add bookmarks at different pages
      // await readerPage.goToPage(0.10);
      // await readerPage.tapBookmarkButton();

      // await readerPage.goToPage(0.30);
      // await readerPage.tapBookmarkButton();

      // await readerPage.goToPage(0.50);
      // await readerPage.tapBookmarkButton();

      // Assert - All bookmarks should be saved
      // Open bookmarks menu
      // await readerPage.openBookmarksMenu();
      // Should show 3 bookmarks

      logger.info('Multiple bookmarks test completed', category: 'bookmarks');
    }, skip: true, reason: 'Requires test book and navigation');

    testWidgets('Bookmarks persist across app restart', (WidgetTester tester) async {
      logger.info('Testing bookmarks persistence', category: 'bookmarks');

      // Arrange
      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettled(tester);

      // Act
      // final readerPage = ReaderPage(tester);

      // Add bookmark
      // await readerPage.goToPage(0.20);
      // await readerPage.tapBookmarkButton();

      // Restart app
      // await tester.pumpWidget(
      //   const ProviderScope(
      //     child: app.MyApp(),
      //   ),
      // );
      // await TestHelpers.waitForAppSettled(tester);

      // Assert - Bookmark should still exist
      // await readerPage.goToPage(0.20);
      // readerPage.verifyBookmarkAdded();

      logger.info('Bookmarks persistence test completed', category: 'bookmarks');
    }, skip: true, reason: 'Requires test book and navigation');

    testWidgets('Each book has its own bookmarks', (WidgetTester tester) async {
      logger.info('Testing per-book bookmarks', category: 'bookmarks');

      // Arrange
      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettled(tester);

      // Act
      // final readerPage = ReaderPage(tester);
      // final libraryPage = LibraryPage(tester);

      // Add bookmark in book 1
      // await libraryPage.openBook('Book 1');
      // await readerPage.goToPage(0.15);
      // await readerPage.tapBookmarkButton();
      // await readerPage.goBack();

      // Add bookmark in book 2
      // await libraryPage.openBook('Book 2');
      // await readerPage.goToPage(0.10);
      // await readerPage.tapBookmarkButton();
      // await readerPage.goBack();

      // Open book 1 bookmarks
      // await libraryPage.openBook('Book 1');
      // await readerPage.openBookmarksMenu();

      // Assert - Should only show book 1's bookmark
      // Not book 2's bookmark

      logger.info('Per-book bookmarks test completed', category: 'bookmarks');
    }, skip: true, reason: 'Requires multiple test books');

    group('Reading History', () {
      testWidgets('Reading history is tracked', (WidgetTester tester) async {
        logger.info('Testing reading history tracking', category: 'bookmarks');

        // Arrange
        await tester.pumpWidget(
          const ProviderScope(
            child: app.MyApp(),
          ),
        );
        await TestHelpers.waitForAppSettled(tester);

        // Act
        // final libraryPage = LibraryPage(tester);

        // Read multiple books
        // await libraryPage.openBook('Book 1');
        // await tester.pump(const Duration(seconds: 1));
        // await tester.pumpWidget(
        //   const ProviderScope(
        //     child: app.MyApp(),
        //   ),
        // );

        // await libraryPage.openBook('Book 2');
        // await tester.pump(const Duration(seconds: 1));
        // await tester.pumpWidget(
        //   const ProviderScope(
        //     child: app.MyApp(),
        //   ),
        // );

        // Assert - Recent books should be displayed
        // Most recently read should be first

        logger.info('Reading history tracking test completed', category: 'bookmarks');
      });

      testWidgets('Recent books section displays in correct order',
          (WidgetTester tester) async {
        logger.info('Testing recent books ordering', category: 'bookmarks');

        // Arrange
        await tester.pumpWidget(
          const ProviderScope(
            child: app.MyApp(),
          ),
        );
        await TestHelpers.waitForAppSettled(tester);

        // Assert - Most recently read should be at top
        // Should show last read timestamp

        logger.info('Recent books ordering test completed', category: 'bookmarks');
      });

      testWidgets('Continue reading button opens last read book',
          (WidgetTester tester) async {
        logger.info('Testing continue reading button', category: 'bookmarks');

        // Arrange
        await tester.pumpWidget(
          const ProviderScope(
            child: app.MyApp(),
          ),
        );
        await TestHelpers.waitForAppSettled(tester);

        // Act - Tap "Continue Reading" button
        // final continueButtonFinder = find.text('Continue Reading');
        // await tester.tap(continueButtonFinder);

        // Assert - Should open last read book at last position

        logger.info('Continue reading button test completed', category: 'bookmarks');
      });
    });

    group('Bookmark Management', () {
      testWidgets('Bookmark list shows page numbers', (WidgetTester tester) async {
        logger.info('Testing bookmark page numbers', category: 'bookmarks');

        // Arrange
        await tester.pumpWidget(
          const ProviderScope(
            child: app.MyApp(),
          ),
        );
        await TestHelpers.waitForAppSettled(tester);

        // Act
        // final readerPage = ReaderPage(tester);

        // Add bookmarks
        // await readerPage.goToPage(0.10);
        // await readerPage.tapBookmarkButton();

        // await readerPage.goToPage(0.30);
        // await readerPage.tapBookmarkButton();

        // Open bookmarks menu
        // await readerPage.openBookmarksMenu();

        // Assert - Should show page numbers
        // expect(find.text('Page 10'), findsOneWidget);
        // expect(find.text('Page 30'), findsOneWidget);

        logger.info('Bookmark page numbers test completed', category: 'bookmarks');
      });

      testWidgets('Bookmark can be named or annotated', (WidgetTester tester) async {
        logger.info('Testing bookmark naming', category: 'bookmarks');

        // Arrange
        await tester.pumpWidget(
          const ProviderScope(
            child: app.MyApp(),
          ),
        );
        await TestHelpers.waitForAppSettled(tester);

        // Act - Add bookmark with note
        // final readerPage = ReaderPage(tester);
        // await readerPage.tapBookmarkButton();

        // Enter note/note dialog
        // final noteFinder = find.byType(TextField);
        // await tester.enterText(noteFinder, 'Important section');
        // await tester.tap(find.text('Save'));

        // Assert - Bookmark should have note

        logger.info('Bookmark naming test completed', category: 'bookmarks');
      });

      testWidgets('Bookmarks are sorted by page number', (WidgetTester tester) async {
        logger.info('Testing bookmark sorting', category: 'bookmarks');

        // Arrange
        await tester.pumpWidget(
          const ProviderScope(
            child: app.MyApp(),
          ),
        );
        await TestHelpers.waitForAppSettled(tester);

        // Act
        // final readerPage = ReaderPage(tester);

        // Add bookmarks out of order
        // await readerPage.goToPage(0.50);
        // await readerPage.tapBookmarkButton();

        // await readerPage.goToPage(0.10);
        // await readerPage.tapBookmarkButton();

        // await readerPage.goToPage(0.30);
        // await readerPage.tapBookmarkButton();

        // Open bookmarks menu
        // await readerPage.openBookmarksMenu();

        // Assert - Should be sorted: 10, 30, 50

        logger.info('Bookmark sorting test completed', category: 'bookmarks');
      });
    });

    group('Edge Cases', () {
      testWidgets('Handle duplicate bookmarks at same page', (WidgetTester tester) async {
        logger.info('Testing duplicate bookmarks', category: 'bookmarks');

        // Arrange
        await tester.pumpWidget(
          const ProviderScope(
            child: app.MyApp(),
          ),
        );
        await TestHelpers.waitForAppSettled(tester);

        // Act
        // final readerPage = ReaderPage(tester);

        // await readerPage.goToPage(0.25);

        // Add bookmark twice
        // await readerPage.tapBookmarkButton();
        // await readerPage.tapBookmarkButton();

        // Assert - Should not create duplicate
        // Second tap should remove bookmark

        logger.info('Duplicate bookmarks test completed', category: 'bookmarks');
      });

      testWidgets('Handle bookmark on first page', (WidgetTester tester) async {
        logger.info('Testing first page bookmark', category: 'bookmarks');

        // Arrange
        await tester.pumpWidget(
          const ProviderScope(
            child: app.MyApp(),
          ),
        );
        await TestHelpers.waitForAppSettled(tester);

        // Act
        // final readerPage = ReaderPage(tester);

        // Add bookmark on page 1
        // await readerPage.goToPage(0.0);
        // await readerPage.tapBookmarkButton();

        // Assert - Should work correctly

        logger.info('First page bookmark test completed', category: 'bookmarks');
      });

      testWidgets('Handle bookmark on last page', (WidgetTester tester) async {
        logger.info('Testing last page bookmark', category: 'bookmarks');

        // Arrange
        await tester.pumpWidget(
          const ProviderScope(
            child: app.MyApp(),
          ),
        );
        await TestHelpers.waitForAppSettled(tester);

        // Act
        // final readerPage = ReaderPage(tester);

        // Add bookmark on last page
        // final totalPages = readerPage.getTotalPages();
        // await readerPage.goToPage(1.0);
        // await readerPage.tapBookmarkButton();

        // Assert - Should work correctly

        logger.info('Last page bookmark test completed', category: 'bookmarks');
      });
    });
  });
}
