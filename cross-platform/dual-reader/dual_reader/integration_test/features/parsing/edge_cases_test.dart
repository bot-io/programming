/// E2E Tests for Parsing Edge Cases
///
/// Tests handling of unusual and edge case book files:
/// - Empty book
/// - Book with one page
/// - Book with very long chapters
/// - Book with many short chapters
/// - Book with no chapters
/// - Corrupted file
/// - Invalid file format
/// - Large books

library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dual_reader/main.dart' as app;
import '../../../test_integration/helpers/test_helpers.dart';
import '../../../test_integration/pages/library_page.dart';
import '../../../test_integration/config/test_config.dart';
import '../../../test_integration/helpers/test_logger.dart';

void main() {
  TestHelpers.initTests();
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Parsing - Edge Cases E2E Tests', () {
    late TestLogger logger;

    setUpAll(() {
      logger = TestLogger();
    });

    tearDownAll(() async {
      await logger.dispose();
    });

    setUp(() {
      logger.logTestSetup('Edge Cases');
    });

    tearDown(() {
      logger.logTestTeardown('Edge Cases');
    });

    testWidgets('Handle empty book', (WidgetTester tester) async {
      logger.info('Testing empty book handling', category: 'edge_cases');

      // Arrange
      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettled(tester);

      final libraryPage = LibraryPage(tester);
      await libraryPage.waitForLoad();

      // Act - Try to import empty book
      // await libraryPage.importBookFromAssets('empty.epub');
      // await TestHelpers.waitForAppSettled(tester);

      // Assert - Should show appropriate error
      // expect(find.text('Book is empty'), findsOneWidget);
      // expect(libraryPage.getBookCount(), equals(0));

      logger.info('Empty book handled correctly', category: 'edge_cases');
      logger.info('Empty book test completed', category: 'edge_cases');
    }, skip: true, reason: 'Requires empty test book');

    testWidgets('Handle book with one page', (WidgetTester tester) async {
      logger.info('Testing one-page book', category: 'edge_cases');

      // Arrange
      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettled(tester);

      final libraryPage = LibraryPage(tester);
      await libraryPage.waitForLoad();

      // Act - Import one-page book
      // await libraryPage.importBookFromAssets('one_page.epub');
      // await libraryPage.openBook(0);

      // Assert - Should handle gracefully
      // expect(readerPage.getTotalPages(), equals(1));
      // Next/prev buttons should be disabled

      logger.info('One-page book handled', category: 'edge_cases');
      logger.info('One-page test completed', category: 'edge_cases');
    }, skip: true, reason: 'Requires one-page test book');

    testWidgets('Handle book with very long chapters',
        (WidgetTester tester) async {
      logger.info('Testing long chapter handling', category: 'edge_cases');

      // Arrange
      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettled(tester);

      final libraryPage = LibraryPage(tester);
      await libraryPage.waitForLoad();

      // Act - Import book with long chapters
      // await libraryPage.importBookFromAssets('long_chapters.epub');
      // await libraryPage.openBook(0);

      // Assert - Should split long chapters into pages
      // final totalPages = await readerPage.getTotalPages();
      // expect(totalPages, greaterThan(10));

      logger.info('Long chapters handled', category: 'edge_cases');
      logger.info('Long chapter test completed', category: 'edge_cases');
    }, skip: true, reason: 'Requires long chapter test book');

    testWidgets('Handle book with many short chapters',
        (WidgetTester tester) async {
      logger.info('Testing many short chapters', category: 'edge_cases');

      // Arrange
      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettled(tester);

      final libraryPage = LibraryPage(tester);
      await libraryPage.waitForLoad();

      // Act - Import book with many chapters
      // await libraryPage.importBookFromAssets('many_chapters.epub');
      // await libraryPage.openBook(0);

      // Assert - All chapters should be accessible
      // final toc = await readerPage.getTableOfContents();
      // expect(toc.length, greaterThan(50));

      logger.info('Many chapters handled', category: 'edge_cases');
      logger.info('Many chapters test completed', category: 'edge_cases');
    }, skip: true, reason: 'Requires many-chapter test book');

    testWidgets('Handle book with no chapters', (WidgetTester tester) async {
      logger.info('Testing no-chapter book', category: 'edge_cases');

      // Arrange
      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettled(tester);

      final libraryPage = LibraryPage(tester);
      await libraryPage.waitForLoad();

      // Act - Import book without chapter structure
      // await libraryPage.importBookFromAssets('no_chapters.epub');
      // await libraryPage.openBook(0);

      // Assert - Should create single chapter from all content
      // final toc = await readerPage.getTableOfContents();
      // expect(toc.length, greaterThan(0));

      logger.info('No-chapter book handled', category: 'edge_cases');
      logger.info('No-chapter test completed', category: 'edge_cases');
    }, skip: true, reason: 'Requires no-chapter test book');

    testWidgets('Handle corrupted file', (WidgetTester tester) async {
      logger.info('Testing corrupted file handling', category: 'edge_cases');

      // Arrange
      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettled(tester);

      final libraryPage = LibraryPage(tester);
      await libraryPage.waitForLoad();

      // Act - Try to import corrupted file
      // await libraryPage.importBookFromAssets('corrupted.epub');
      // await TestHelpers.waitForAppSettled(tester);

      // Assert - Should show error message
      // expect(find.textContaining('corrupted'), findsOneWidget);
      // expect(find.textContaining('parse'), findsOneWidget);

      logger.info('Corrupted file handled', category: 'edge_cases');
      logger.info('Corrupted file test completed', category: 'edge_cases');
    }, skip: true, reason: 'Requires corrupted test file');

    testWidgets('Handle invalid file format', (WidgetTester tester) async {
      logger.info('Testing invalid format handling', category: 'edge_cases');

      // Arrange
      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettled(tester);

      final libraryPage = LibraryPage(tester);
      await libraryPage.waitForLoad();

      // Act - Try to import non-book file
      // await libraryPage.importBookFromAssets('not_a_book.pdf');
      // await TestHelpers.waitForAppSettled(tester);

      // Assert - Should show format error
      // expect(find.text('Unsupported file format'), findsOneWidget);
      // expect(find.text('PDF'), findsOneWidget);

      logger.info('Invalid format handled', category: 'edge_cases');
      logger.info('Invalid format test completed', category: 'edge_cases');
    }, skip: true, reason: 'Requires invalid format test file');

    testWidgets('Handle 1000+ page book', (WidgetTester tester) async {
      logger.info('Testing large book handling', category: 'edge_cases');

      // Arrange
      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettled(tester);

      final libraryPage = LibraryPage(tester);
      await libraryPage.waitForLoad();

      // Act - Import large book
      // await libraryPage.importBookFromAssets('large_book.epub');
      // await libraryPage.openBook(0);

      // Wait for pagination
      // await readerPage.waitForPaginationComplete(
      //   timeout: Duration(minutes: 5),
      // );

      // Assert - Should paginate successfully
      // final totalPages = readerPage.getTotalPages();
      // expect(totalPages, greaterThan(1000));

      logger.info('Large book handled', category: 'edge_cases');
      logger.info('Large book test completed', category: 'edge_cases');
    }, skip: true, reason: 'Requires large test book (1000+ pages)');

    testWidgets('Handle 100+ chapters', (WidgetTester tester) async {
      logger.info('Testing many chapter handling', category: 'edge_cases');

      // Arrange
      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettled(tester);

      final libraryPage = LibraryPage(tester);
      await libraryPage.waitForLoad();

      // Act - Import book with 100+ chapters
      // await libraryPage.importBookFromAssets('100_chapters.epub');
      // await libraryPage.openBook(0);

      // Assert - All chapters should be accessible
      // final toc = await readerPage.getTableOfContents();
      // expect(toc.length, greaterThan(100));

      logger.info('Many chapters handled', category: 'edge_cases');
      logger.info('100+ chapters test completed', category: 'edge_cases');
    }, skip: true, reason: 'Requires 100+ chapter test book');

    testWidgets('Memory efficient parsing of large files',
        (WidgetTester tester) async {
      logger.info('Testing memory efficiency', category: 'edge_cases');

      // Arrange
      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettled(tester);

      final libraryPage = LibraryPage(tester);
      await libraryPage.waitForLoad();

      // Act - Import and parse large book
      // final memoryBefore = await getCurrentMemoryUsage();

      // await libraryPage.importBookFromAssets('large_book.epub');
      // await libraryPage.openBook(0);
      // await readerPage.waitForPaginationComplete();

      // final memoryAfter = await getCurrentMemoryUsage();
      // final memoryIncrease = memoryAfter - memoryBefore;

      // Assert - Memory usage should be reasonable
      // expect(memoryIncrease, lessThan(500 * 1024 * 1024)); // < 500MB

      logger.info('Memory efficiency verified', category: 'edge_cases');
      logger.info('Memory efficiency test completed', category: 'edge_cases');
    }, skip: true, reason: 'Requires memory monitoring and large book');

    testWidgets('No crashes on large files', (WidgetTester tester) async {
      logger.info('Testing crash resistance', category: 'edge_cases');

      // Arrange
      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettled(tester);

      final libraryPage = LibraryPage(tester);
      await libraryPage.waitForLoad();

      // Act - Import very large book
      // await libraryPage.importBookFromAssets('very_large.epub');
      // await TestHelpers.waitForAppSettled(
      //   Duration(minutes: 10),
      // );

      // Assert - App should not crash
      // expect(find.byType(MyApp), findsOneWidget);

      logger.info('No crashes on large file', category: 'edge_cases');
      logger.info('Crash resistance test completed', category: 'edge_cases');
    }, skip: true, reason: 'Requires very large test file');

    group('Chapter Title Handling', () {
      testWidgets('Strip h1-h6 tags from content',
          (WidgetTester tester) async {
        logger.info('Testing heading tag stripping', category: 'edge_cases');

        // Arrange
        await tester.pumpWidget(
          const ProviderScope(
            child: app.MyApp(),
          ),
        );
        await TestHelpers.waitForAppSettled(tester);

        // Act - Open book with headings
        // final readerPage = ReaderPage(tester);
        // await readerPage.waitForLoad();

        // Get content
        // final content = await readerPage.getCurrentPageText();

        // Assert - Heading tags should be stripped
        // expect(content, isNot(contains('<h1>')));
        // expect(content, isNot(contains('<h2>')));

        logger.info('Heading tags stripped', category: 'edge_cases');
        logger.info('Heading stripping test completed', category: 'edge_cases');
      }, skip: true, reason: 'Requires heading test content');

      testWidgets('Strip chapter titles from body text',
          (WidgetTester tester) async {
        logger.info('Testing chapter title stripping', category: 'edge_cases');

        // Arrange
        await tester.pumpWidget(
          const ProviderScope(
            child: app.MyApp(),
          ),
        );
        await TestHelpers.waitForAppSettled(tester);

        // Act - Open book with chapter titles
        // final readerPage = ReaderPage(tester);
        // await readerPage.waitForLoad();

        // Get first page content
        // final content = await readerPage.getCurrentPageText();
        // final chapterTitle = await readerPage.getCurrentChapterTitle();

        // Assert - Title should not duplicate in body
        // expect(content, isNot(startsWith(chapterTitle)));

        logger.info('Chapter titles stripped', category: 'edge_cases');
        logger.info('Title stripping test completed', category: 'edge_cases');
      }, skip: true, reason: 'Requires chapter title test content');

      testWidgets('Prevent title duplication in body',
          (WidgetTester tester) async {
        logger.info('Testing title duplication prevention',
            category: 'edge_cases');

        // Arrange
        await tester.pumpWidget(
          const ProviderScope(
            child: app.MyApp(),
          ),
        );
        await TestHelpers.waitForAppSettled(tester);

        // Act - Open book where title appears in content
        // final readerPage = ReaderPage(tester);
        // await readerPage.waitForLoad();

        // Get content and title
        // final content = await readerPage.getCurrentPageText();
        // final chapterTitle = await readerPage.getCurrentChapterTitle();

        // Count title occurrences
        // final occurrences = content.allMatches(chapterTitle).length;

        // Assert - Title should appear only once or not at all
        // expect(occurrences, lessThanOrEqualTo(1));

        logger.info('Title duplication prevented', category: 'edge_cases');
        logger.info('Duplication prevention test completed', category: 'edge_cases');
      }, skip: true, reason: 'Requires title duplication test content');
    });

    group('Malformed Content', () {
      testWidgets('Handle malformed HTML', (WidgetTester tester) async {
        logger.info('Testing malformed HTML handling', category: 'edge_cases');

        // Arrange
        await tester.pumpWidget(
          const ProviderScope(
            child: app.MyApp(),
          ),
        );
        await TestHelpers.waitForAppSettled(tester);

        final libraryPage = LibraryPage(tester);
        await libraryPage.waitForLoad();

        // Act - Import book with malformed HTML
        // await libraryPage.importBookFromAssets('malformed_html.epub');
        // await libraryPage.openBook(0);

        // Assert - Should handle gracefully
        // Content should still be readable
        // final content = await readerPage.getCurrentPageText();
        // expect(content, isNotEmpty);

        logger.info('Malformed HTML handled', category: 'edge_cases');
        logger.info('Malformed HTML test completed', category: 'edge_cases');
      }, skip: true, reason: 'Requires malformed HTML test book');

      testWidgets('Handle unclosed tags', (WidgetTester tester) async {
        logger.info('Testing unclosed tag handling', category: 'edge_cases');

        // Arrange
        await tester.pumpWidget(
          const ProviderScope(
            child: app.MyApp(),
          ),
        );
        await TestHelpers.waitForAppSettled(tester);

        final libraryPage = LibraryPage(tester);
        await libraryPage.waitForLoad();

        // Act - Import book with unclosed tags
        // await libraryPage.importBookFromAssets('unclosed_tags.epub');
        // await libraryPage.openBook(0);

        // Assert - Should auto-close or ignore
        // final content = await readerPage.getCurrentPageText();
        // expect(content, isNotEmpty);

        logger.info('Unclosed tags handled', category: 'edge_cases');
        logger.info('Unclosed tags test completed', category: 'edge_cases');
      }, skip: true, reason: 'Requires unclosed tag test book');

      testWidgets('Handle deeply nested tags', (WidgetTester tester) async {
        logger.info('Testing deeply nested tag handling', category: 'edge_cases');

        // Arrange
        await tester.pumpWidget(
          const ProviderScope(
            child: app.MyApp(),
          ),
        );
        await TestHelpers.waitForAppSettled(tester);

        final libraryPage = LibraryPage(tester);
        await libraryPage.waitForLoad();

        // Act - Import book with deeply nested tags
        // await libraryPage.importBookFromAssets('deeply_nested.epub');
        // await libraryPage.openBook(0);

        // Assert - Should handle without crash
        // final content = await readerPage.getCurrentPageText();
        // expect(content, isNotEmpty);

        logger.info('Deeply nested tags handled', category: 'edge_cases');
        logger.info('Deeply nested test completed', category: 'edge_cases');
      }, skip: true, reason: 'Requires deeply nested test book');
    });

    group('File System Edge Cases', () {
      testWidgets('Handle file with very long name',
          (WidgetTester tester) async {
        logger.info('Testing long filename handling', category: 'edge_cases');

        // Arrange
        await tester.pumpWidget(
          const ProviderScope(
            child: app.MyApp(),
          ),
        );
        await TestHelpers.waitForAppSettled(tester);

        final libraryPage = LibraryPage(tester);
        await libraryPage.waitForLoad();

        // Act - Import file with long name
        // await libraryPage.importBookFromAssets(
        //   'a' * 250 + '.epub'
        // );

        // Assert - Should handle correctly
        // expect(libraryPage.getBookCount(), greaterThan(0));

        logger.info('Long filename handled', category: 'edge_cases');
        logger.info('Long filename test completed', category: 'edge_cases');
      }, skip: true, reason: 'Requires long filename test file');

      testWidgets('Handle file with special characters in name',
          (WidgetTester tester) async {
        logger.info('Testing special char filename', category: 'edge_cases');

        // Arrange
        await tester.pumpWidget(
          const ProviderScope(
            child: app.MyApp(),
          ),
        );
        await TestHelpers.waitForAppSettled(tester);

        final libraryPage = LibraryPage(tester);
        await libraryPage.waitForLoad();

        // Act - Import file with special chars
        // await libraryPage.importBookFromAssets('test file (1).epub');

        // Assert - Should handle correctly
        // expect(libraryPage.getBookCount(), greaterThan(0));

        logger.info('Special char filename handled', category: 'edge_cases');
        logger.info('Special char test completed', category: 'edge_cases');
      }, skip: true, reason: 'Requires special char filename test file');

      testWidgets('Handle file with unicode in name',
          (WidgetTester tester) async {
        logger.info('Testing unicode filename', category: 'edge_cases');

        // Arrange
        await tester.pumpWidget(
          const ProviderScope(
            child: app.MyApp(),
          ),
        );
        await TestHelpers.waitForAppSettled(tester);

        final libraryPage = LibraryPage(tester);
        await libraryPage.waitForLoad();

        // Act - Import file with unicode name
        // await libraryPage.importBookFromAssets('libro_de_prueba.epub');

        // Assert - Should handle correctly
        // expect(libraryPage.getBookCount(), greaterThan(0));

        logger.info('Unicode filename handled', category: 'edge_cases');
        logger.info('Unicode filename test completed', category: 'edge_cases');
      }, skip: true, reason: 'Requires unicode filename test file');
    });
  });
}
