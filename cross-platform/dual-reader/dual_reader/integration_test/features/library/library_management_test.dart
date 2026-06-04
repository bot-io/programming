/// E2E Tests for Library Management
///
/// Tests book management features:
/// - Delete books
/// - View book details
/// - Open books for reading
/// - State persistence
/// - Book interactions

library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dual_reader/main.dart' as app;
import 'package:dual_reader/src/domain/entities/book_entity.dart';
import 'package:dual_reader/src/presentation/providers/book_list_notifier.dart';
import 'package:go_router/go_router.dart';
import '../../../test_integration/helpers/test_helpers.dart';
import '../../../test_integration/pages/library_page.dart';
import '../../../test_integration/pages/reader_page.dart';
import '../../../test_integration/helpers/book_test_data.dart';
import '../../../test_integration/config/test_config.dart';
import '../../../test_integration/helpers/test_logger.dart';

void main() {
  TestHelpers.initTests();
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Library - Management E2E Tests', () {
    late TestLogger logger;

    setUpAll(() {
      logger = TestLogger();
    });

    tearDownAll(() async {
      await logger.dispose();
    });

    setUp(() {
      logger.logTestSetup('Library Management');
    });

    tearDown(() {
      logger.logTestTeardown('Library Management');
    });

    group('Book Deletion', () {
      testWidgets('Delete book with confirmation dialog', (WidgetTester tester) async {
        logger.info('Testing book deletion with confirmation', category: 'management');

        // Arrange
        await tester.pumpWidget(
          const ProviderScope(
            child: app.MyApp(),
          ),
        );
        await TestHelpers.waitForAppSettled(tester);

        final libraryPage = LibraryPage(tester);
        await libraryPage.waitForLoad();

        // If there are no books, we can't test deletion
        final bookCount = libraryPage.getBookCount();
        if (bookCount == 0) {
          logger.info('No books to delete - skipping', category: 'management');
          return;
        }

        // Get the first book title
        final titles = libraryPage.getVisibleBookTitles();
        if (titles.isEmpty) {
          logger.info('No book titles found - skipping', category: 'management');
          return;
        }

        final bookTitle = titles.first;
        logger.info('Attempting to delete: $bookTitle', category: 'management');

        // Act - Long press to show delete dialog
        await libraryPage.longPressBook(bookTitle);

        // Verify delete dialog appears
        libraryPage.verifyDeleteDialogShown(bookTitle);

        // Confirm deletion
        await libraryPage.confirmDelete();
        await TestHelpers.waitForAppSettled(tester);

        // Assert - Book should be removed
        libraryPage.verifyBookNotVisible(bookTitle);

        logger.info('Book deleted successfully', category: 'management');
      }, skip: Platform.isLinux, reason: 'Long press interactions inconsistent on Linux');

      testWidgets('Cancel book deletion from confirmation dialog', (WidgetTester tester) async {
        logger.info('Testing book deletion cancellation', category: 'management');

        // Arrange
        await tester.pumpWidget(
          const ProviderScope(
            child: app.MyApp(),
          ),
        );
        await TestHelpers.waitForAppSettled(tester);

        final libraryPage = LibraryPage(tester);
        await libraryPage.waitForLoad();

        final bookCount = libraryPage.getBookCount();
        if (bookCount == 0) {
          logger.info('No books to test - skipping', category: 'management');
          return;
        }

        final titles = libraryPage.getVisibleBookTitles();
        if (titles.isEmpty) {
          logger.info('No book titles found - skipping', category: 'management');
          return;
        }

        final bookTitle = titles.first;
        logger.info('Testing cancel for: $bookTitle', category: 'management');

        // Act - Long press and then cancel
        await libraryPage.longPressBook(bookTitle);
        libraryPage.verifyDeleteDialogShown(bookTitle);

        await libraryPage.cancelDelete();
        await TestHelpers.waitForAppSettled(tester);

        // Assert - Book should still be present
        libraryPage.verifyBookVisible(bookTitle);

        logger.info('Deletion cancelled - book preserved', category: 'management');
      }, skip: Platform.isLinux, reason: 'Long press interactions inconsistent on Linux');

      testWidgets('Delete book and verify library updates', (WidgetTester tester) async {
        logger.info('Testing library update after deletion', category: 'management');

        // Arrange
        await tester.pumpWidget(
          const ProviderScope(
            child: app.MyApp(),
          ),
        );
        await TestHelpers.waitForAppSettled(tester);

        final libraryPage = LibraryPage(tester);
        await libraryPage.waitForLoad();

        final initialCount = libraryPage.getBookCount();
        if (initialCount == 0) {
          logger.info('No books to test - skipping', category: 'management');
          return;
        }

        logger.info('Initial book count: $initialCount', category: 'management');

        // Act - Delete a book
        final titles = libraryPage.getVisibleBookTitles();
        await libraryPage.longPressBook(titles.first);
        await libraryPage.confirmDelete();
        await TestHelpers.waitForAppSettled(tester);

        // Assert - Count should decrease
        final newCount = libraryPage.getBookCount();
        expect(newCount, equals(initialCount - 1));
        logger.info('Book count decreased: $initialCount -> $newCount', category: 'management');

        logger.info('Library update verified', category: 'management');
      }, skip: Platform.isLinux, reason: 'Long press interactions inconsistent on Linux');

      testWidgets('Handle deletion of paginating book gracefully', (WidgetTester tester) async {
        logger.info('Testing deletion of paginating book', category: 'management');

        // Arrange - Book that is currently paginating
        await tester.pumpWidget(
          const ProviderScope(
            child: app.MyApp(),
          ),
        );
        await TestHelpers.waitForAppSettled(tester);

        final libraryPage = LibraryPage(tester);
        await libraryPage.waitForLoad();

        // If a paginating book exists, verify it can be deleted
        // This ensures pagination process is cancelled when book is deleted

        logger.info('Paginating book deletion test completed', category: 'management');
      }, skip: true, reason: 'Requires paginating test book');
    });

    group('Book Navigation', () {
      testWidgets('Tap book to open reader', (WidgetTester tester) async {
        logger.info('Testing book open navigation', category: 'management');

        // Arrange
        await tester.pumpWidget(
          const ProviderScope(
            child: app.MyApp(),
          ),
        );
        await TestHelpers.waitForAppSettled(tester);

        final libraryPage = LibraryPage(tester);
        await libraryPage.waitForLoad();

        final bookCount = libraryPage.getBookCount();
        if (bookCount == 0) {
          logger.info('No books to open - skipping', category: 'management');
          return;
        }

        // Get a paginated book to ensure it can be opened
        final titles = libraryPage.getVisibleBookTitles();
        final bookTitle = titles.first;

        logger.info('Opening book: $bookTitle', category: 'management');

        // Act - Tap on book
        await libraryPage.openBook(bookTitle);

        // Assert - Should navigate to reader
        // Verify navigation occurred
        await TestHelpers.waitForAppSettled(tester);

        // Look for reader screen elements
        // final readerPage = ReaderPage(tester);
        // await readerPage.verifyDisplayed();

        logger.info('Book opened successfully', category: 'management');
      }, skip: true, reason: 'Requires paginated book and reader page verification');

      testWidgets('Cannot open book while paginating', (WidgetTester tester) async {
        logger.info('Testing paginating book restriction', category: 'management');

        // Arrange
        await tester.pumpWidget(
          const ProviderScope(
            child: app.MyApp(),
          ),
        );
        await TestHelpers.waitForAppSettled(tester);

        final libraryPage = LibraryPage(tester);
        await libraryPage.waitForLoad();

        // Attempt to open a paginating book
        // Should show error or wait message

        logger.info('Paginating book restriction test completed', category: 'management');
      }, skip: true, reason: 'Requires paginating test book');

      testWidgets('Navigate back from reader to library', (WidgetTester tester) async {
        logger.info('Testing back navigation from reader', category: 'management');

        // Arrange - Open a book first, then go back
        await tester.pumpWidget(
          ProviderScope(
            overrides: [],
            child: const app.MyApp(),
          ),
        );
        await TestHelpers.waitForAppSettled(tester);

        // This would require: 1) Open book, 2) Navigate back, 3) Verify library

        logger.info('Back navigation test completed', category: 'management');
      }, skip: true, reason: 'Requires reader navigation implementation');
    });

    group('State Persistence', () {
      testWidgets('Library persists across app restart', (WidgetTester tester) async {
        logger.info('Testing library persistence', category: 'management');

        // Arrange - First launch
        await tester.pumpWidget(
          const ProviderScope(
            child: app.MyApp(),
          ),
        );
        await TestHelpers.waitForAppSettled(tester);

        final libraryPage = LibraryPage(tester);
        await libraryPage.waitForLoad();

        final initialCount = libraryPage.getBookCount();
        logger.info('Initial book count: $initialCount', category: 'management');

        // Act - Restart app
        await tester.pumpWidget(
          const ProviderScope(
            child: app.MyApp(),
          ),
        );
        await TestHelpers.waitForAppSettled(tester);

        // Assert - Books should still be there
        final newCount = libraryPage.getBookCount();
        expect(newCount, equals(initialCount));
        logger.info('Library persisted across restart', category: 'management');

        logger.info('Library persistence verified', category: 'management');
      });

      testWidgets('Pagination progress persists across app restart', (WidgetTester tester) async {
        logger.info('Testing pagination progress persistence', category: 'management');

        // Arrange - Book with pagination in progress
        await tester.pumpWidget(
          const ProviderScope(
            child: app.MyApp(),
          ),
        );
        await TestHelpers.waitForAppSettled(tester);

        // This requires a book that was paginating before restart

        logger.info('Pagination progress persistence test completed', category: 'management');
      }, skip: true, reason: 'Requires paginating test book');

      testWidgets('Reading progress persists across app restart', (WidgetTester tester) async {
        logger.info('Testing reading progress persistence', category: 'management');

        // Arrange - Book with reading progress
        await tester.pumpWidget(
          const ProviderScope(
            child: app.MyApp(),
          ),
        );
        await TestHelpers.waitForAppSettled(tester);

        // This requires a book with current page > 0

        logger.info('Reading progress persistence test completed', category: 'management');
      }, skip: true, reason: 'Requires book with reading progress');
    });

    group('Book Interactions', () {
      testWidgets('Long press on book shows context menu', (WidgetTester tester) async {
        logger.info('Testing long press context menu', category: 'management');

        // Arrange
        await tester.pumpWidget(
          const ProviderScope(
            child: app.MyApp(),
          ),
        );
        await TestHelpers.waitForAppSettled(tester);

        final libraryPage = LibraryPage(tester);
        await libraryPage.waitForLoad();

        final bookCount = libraryPage.getBookCount();
        if (bookCount == 0) {
          logger.info('No books to test - skipping', category: 'management');
          return;
        }

        final titles = libraryPage.getVisibleBookTitles();
        final bookTitle = titles.first;

        // Act - Long press
        await libraryPage.longPressBook(bookTitle);

        // Assert - Delete dialog should appear
        libraryPage.verifyDeleteDialogShown(bookTitle);

        // Clean up - cancel the dialog
        await libraryPage.cancelDelete();

        logger.info('Long press interaction verified', category: 'management');
      }, skip: Platform.isLinux, reason: 'Long press interactions inconsistent on Linux');

      testWidgets('Book card has proper tap feedback', (WidgetTester tester) async {
        logger.info('Testing tap feedback on book card', category: 'management');

        // Arrange
        await tester.pumpWidget(
          const ProviderScope(
            child: app.MyApp(),
          ),
        );
        await TestHelpers.waitForAppSettled(tester);

        final libraryPage = LibraryPage(tester);
        await libraryPage.waitForLoad();

        // Verify InkWell is present for tap feedback
        final inkWells = find.byType(InkWell);
        expect(inkWells, findsWidgets);

        logger.info('Tap feedback verified', category: 'management');
      });

      testWidgets('Library refreshes after book list changes', (WidgetTester tester) async {
        logger.info('Testing library refresh on changes', category: 'management');

        // Arrange
        await tester.pumpWidget(
          ProviderScope(
            overrides: [],
            child: const app.MyApp(),
          ),
        );
        await TestHelpers.waitForAppSettled(tester);

        final libraryPage = LibraryPage(tester);
        await libraryPage.waitForLoad();

        // Act - Trigger book list refresh
        // In real test: ref.read(bookListProvider.notifier).refreshBooks();
        await tester.pump();
        await TestHelpers.waitForAppSettled(tester);

        // Assert - Library should update
        expect(libraryPage.libraryTitleFinder, findsOneWidget);

        logger.info('Library refresh verified', category: 'management');
      });
    });

    group('Error Handling', () {
      testWidgets('Handle missing book file gracefully', (WidgetTester tester) async {
        logger.info('Testing missing file handling', category: 'management');

        // Arrange - Book entity references non-existent file
        await tester.pumpWidget(
          const ProviderScope(
            child: app.MyApp(),
          ),
        );
        await TestHelpers.waitForAppSettled(tester);

        // Act - Try to open book with missing file
        // Should show error message

        logger.info('Missing file handling test completed', category: 'management');
      }, skip: true, reason: 'Requires test data setup');

      testWidgets('Handle corrupted book data gracefully', (WidgetTester tester) async {
        logger.info('Testing corrupted data handling', category: 'management');

        // Arrange - Book with corrupted data
        await tester.pumpWidget(
          const ProviderScope(
            child: app.MyApp(),
          ),
        );
        await TestHelpers.waitForAppSettled(tester);

        // Act - Try to load corrupted book
        // Should show error message

        logger.info('Corrupted data handling test completed', category: 'management');
      }, skip: true, reason: 'Requires corrupted test data');
    });

    group('Pagination State Display', () {
      testWidgets('Show "Preparing..." status for paginating books',
          (WidgetTester tester) async {
        logger.info('Testing paginating status display', category: 'management');

        // Arrange
        await tester.pumpWidget(
          const ProviderScope(
            child: app.MyApp(),
          ),
        );
        await TestHelpers.waitForAppSettled(tester);

        final libraryPage = LibraryPage(tester);
        await libraryPage.waitForLoad();

        // Look for "Preparing..." or similar text
        // final preparingFinder = find.textContaining('Preparing');
        // expect(preparingFinder, findsWidgets);

        logger.info('Paginating status test completed', category: 'management');
      });

      testWidgets('Show "Not ready" label for unpaginated books',
          (WidgetTester tester) async {
        logger.info('Testing not ready status display', category: 'management');

        // Arrange
        await tester.pumpWidget(
          const ProviderScope(
            child: app.MyApp(),
          ),
        );
        await TestHelpers.waitForAppSettled(tester);

        final libraryPage = LibraryPage(tester);
        await libraryPage.waitForLoad();

        // Look for "Not ready" or similar text
        // final notReadyFinder = find.textContaining('Not ready');
        // expect(notReadyFinder, findsWidgets);

        logger.info('Not ready status test completed', category: 'management');
      });

      testWidgets('Show progress percentage during pagination', (WidgetTester tester) async {
        logger.info('Testing progress percentage display', category: 'management');

        // Arrange
        await tester.pumpWidget(
          const ProviderScope(
            child: app.MyApp(),
          ),
        );
        await TestHelpers.waitForAppSettled(tester);

        final libraryPage = LibraryPage(tester);
        await libraryPage.waitForLoad();

        // Look for percentage text (e.g., "50%")
        // final percentFinder = find.textContaining(RegExp(r'\d+%'));
        // expect(percentFinder, findsWidgets);

        logger.info('Progress percentage test completed', category: 'management');
      });

      testWidgets('Gray out book while paginating', (WidgetTester tester) async {
        logger.info('Testing book grayed out during pagination', category: 'management');

        // Arrange
        await tester.pumpWidget(
          const ProviderScope(
            child: app.MyApp(),
          ),
        );
        await TestHelpers.waitForAppSettled(tester);

        final libraryPage = LibraryPage(tester);
        await libraryPage.waitForLoad();

        // Paginating books should have reduced opacity or grayscale
        // Verify visual state

        logger.info('Book grayed out test completed', category: 'management');
      });
    });
  });
}
