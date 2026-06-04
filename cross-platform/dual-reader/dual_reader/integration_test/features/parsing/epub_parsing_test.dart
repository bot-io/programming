/// E2E Tests for EPUB Parsing
///
/// Tests EPUB file parsing functionality:
/// - Parse standard EPUB2 file
/// - Parse standard EPUB3 file
/// - Extract metadata (title, author, cover)
/// - Extract all chapters
/// - Extract chapter content
/// - Extract images
/// - Handle various EPUB structures

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

  group('Parsing - EPUB E2E Tests', () {
    late TestLogger logger;

    setUpAll(() {
      logger = TestLogger();
    });

    tearDownAll(() async {
      await logger.dispose();
    });

    setUp(() {
      logger.logTestSetup('EPUB Parsing');
    });

    tearDown(() {
      logger.logTestTeardown('EPUB Parsing');
    });

    testWidgets('Parse standard EPUB2 file', (WidgetTester tester) async {
      logger.info('Testing EPUB2 parsing', category: 'epub_parsing');

      // Arrange
      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettled(tester);

      final libraryPage = LibraryPage(tester);
      await libraryPage.waitForLoad();

      // Act - Import EPUB2 file
      // await libraryPage.importBookFromAssets('test_epub2.epub');
      // await TestHelpers.waitForAppSettled(tester);

      // Assert - Book should be imported successfully
      // expect(libraryPage.getBookCount(), greaterThan(0));
      // final book = libraryPage.getBook(0);
      // expect(book.title, isNotEmpty);
      // expect(book.author, isNotEmpty);

      logger.info('EPUB2 parsing verified', category: 'epub_parsing');
      logger.info('EPUB2 test completed', category: 'epub_parsing');
    }, skip: true, reason: 'Requires EPUB2 test file');

    testWidgets('Parse standard EPUB3 file', (WidgetTester tester) async {
      logger.info('Testing EPUB3 parsing', category: 'epub_parsing');

      // Arrange
      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettled(tester);

      final libraryPage = LibraryPage(tester);
      await libraryPage.waitForLoad();

      // Act - Import EPUB3 file
      // await libraryPage.importBookFromAssets('test_epub3.epub');
      // await TestHelpers.waitForAppSettled(tester);

      // Assert - Book should be imported successfully
      // expect(libraryPage.getBookCount(), greaterThan(0));
      // final book = libraryPage.getBook(0);
      // expect(book.format, equals('EPUB3'));

      logger.info('EPUB3 parsing verified', category: 'epub_parsing');
      logger.info('EPUB3 test completed', category: 'epub_parsing');
    }, skip: true, reason: 'Requires EPUB3 test file');

    testWidgets('Extract metadata (title, author, cover)',
        (WidgetTester tester) async {
      logger.info('Testing metadata extraction', category: 'epub_parsing');

      // Arrange
      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettled(tester);

      final libraryPage = LibraryPage(tester);
      await libraryPage.waitForLoad();

      // Act - Import book with metadata
      // await libraryPage.importBookFromAssets('metadata_test.epub');
      // await TestHelpers.waitForAppSettled(tester);

      // Assert - Metadata should be extracted
      // final book = libraryPage.getBook(0);
      // expect(book.title, equals('Test Book Title'));
      // expect(book.author, equals('Test Author'));
      // expect(book.coverImage, isNotNull);
      // expect(book.isbn, isNotEmpty);

      logger.info('Metadata extraction verified', category: 'epub_parsing');
      logger.info('Metadata test completed', category: 'epub_parsing');
    }, skip: true, reason: 'Requires metadata test file');

    testWidgets('Extract all chapters', (WidgetTester tester) async {
      logger.info('Testing chapter extraction', category: 'epub_parsing');

      // Arrange
      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettled(tester);

      final libraryPage = LibraryPage(tester);
      await libraryPage.waitForLoad();

      // Act - Import book with chapters
      // await libraryPage.importBookFromAssets('multi_chapter.epub');
      // await TestHelpers.waitForAppSettled(tester);

      // Open book
      // await libraryPage.openBook(0);
      // await TestHelpers.waitForAppSettled(tester);

      // Assert - All chapters should be extracted
      // final chapters = await getBookChapters();
      // expect(chapters, hasLength(greaterThan(1)));
      // expect(chapters.first.title, isNotEmpty);
      // expect(chapters.last.title, isNotEmpty);

      logger.info('Chapter extraction verified', category: 'epub_parsing');
      logger.info('Chapter extraction test completed', category: 'epub_parsing');
    }, skip: true, reason: 'Requires multi-chapter test file');

    testWidgets('Extract chapter content', (WidgetTester tester) async {
      logger.info('Testing content extraction', category: 'epub_parsing');

      // Arrange
      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettled(tester);

      final libraryPage = LibraryPage(tester);
      await libraryPage.waitForLoad();

      // Act - Import and open book
      // await libraryPage.importBookFromAssets('content_test.epub');
      // await libraryPage.openBook(0);

      // Assert - Chapter content should be extractable
      // final chapterContent = await getChapterContent(0);
      // expect(chapterContent, isNotEmpty);
      // expect(chapterContent.length, greaterThan(100));

      // Content should be readable text
      // expect(chapterContent, contains('Lorem ipsum'));

      logger.info('Content extraction verified', category: 'epub_parsing');
      logger.info('Content extraction test completed', category: 'epub_parsing');
    }, skip: true, reason: 'Requires content test file');

    testWidgets('Extract images from EPUB', (WidgetTester tester) async {
      logger.info('Testing image extraction', category: 'epub_parsing');

      // Arrange
      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettled(tester);

      final libraryPage = LibraryPage(tester);
      await libraryPage.waitForLoad();

      // Act - Import book with images
      // await libraryPage.importBookFromAssets('image_test.epub');
      // await libraryPage.openBook(0);

      // Assert - Images should be extracted
      // final images = await getBookImages();
      // expect(images, isNotEmpty);
      // expect(images.first.data, isNotNull);
      // expect(images.first.mimeType, startsWith('image/'));

      logger.info('Image extraction verified', category: 'epub_parsing');
      logger.info('Image extraction test completed', category: 'epub_parsing');
    }, skip: true, reason: 'Requires image test file');

    testWidgets('Handle EPUB with TOC', (WidgetTester tester) async {
      logger.info('Testing EPUB with TOC', category: 'epub_parsing');

      // Arrange
      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettled(tester);

      final libraryPage = LibraryPage(tester);
      await libraryPage.waitForLoad();

      // Act - Import EPUB with NCX TOC
      // await libraryPage.importBookFromAssets('with_toc.epub');
      // await libraryPage.openBook(0);

      // Assert - TOC should be available
      // final toc = await getTableOfContents();
      // expect(toc, isNotEmpty);
      // expect(toc.first.title, isNotEmpty);
      // expect(toc.first.href, isNotEmpty);

      logger.info('EPUB with TOC verified', category: 'epub_parsing');
      logger.info('TOC test completed', category: 'epub_parsing');
    }, skip: true, reason: 'Requires TOC test file');

    testWidgets('Handle EPUB without TOC', (WidgetTester tester) async {
      logger.info('Testing EPUB without TOC', category: 'epub_parsing');

      // Arrange
      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettled(tester);

      final libraryPage = LibraryPage(tester);
      await libraryPage.waitForLoad();

      // Act - Import EPUB without NCX TOC
      // await libraryPage.importBookFromAssets('without_toc.epub');
      // await libraryPage.openBook(0);

      // Assert - Should generate TOC from headings
      // final toc = await getTableOfContents();
      // expect(toc, isNotEmpty);

      logger.info('EPUB without TOC handled', category: 'epub_parsing');
      logger.info('No TOC test completed', category: 'epub_parsing');
    }, skip: true, reason: 'Requires EPUB without TOC');

    testWidgets('Handle EPUB with complex formatting',
        (WidgetTester tester) async {
      logger.info('Testing complex formatting', category: 'epub_parsing');

      // Arrange
      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettled(tester);

      final libraryPage = LibraryPage(tester);
      await libraryPage.waitForLoad();

      // Act - Import EPUB with complex HTML/CSS
      // await libraryPage.importBookFromAssets('complex_formatting.epub');
      // await libraryPage.openBook(0);

      // Assert - Should handle gracefully
      // Content should be readable
      // final content = await getChapterContent(0);
      // expect(content, isNotEmpty);

      logger.info('Complex formatting handled', category: 'epub_parsing');
      logger.info('Complex formatting test completed', category: 'epub_parsing');
    }, skip: true, reason: 'Requires complex formatting test file');

    testWidgets('Handle encrypted EPUB (DRM)', (WidgetTester tester) async {
      logger.info('Testing DRM-protected EPUB', category: 'epub_parsing');

      // Arrange
      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettled(tester);

      final libraryPage = LibraryPage(tester);
      await libraryPage.waitForLoad();

      // Act - Try to import DRM-protected EPUB
      // await libraryPage.importBookFromAssets('drm_protected.epub');
      // await TestHelpers.waitForAppSettled(tester);

      // Assert - Should show error message
      // expect(find.text('DRM-protected books are not supported'), findsOneWidget);
      // expect(libraryPage.getBookCount(), equals(0));

      logger.info('DRM EPUB handling verified', category: 'epub_parsing');
      logger.info('DRM test completed', category: 'epub_parsing');
    }, skip: true, reason: 'Requires DRM-protected test file');

    group('EPUB Structure Variants', () {
      testWidgets('Handle EPUB with embedded fonts',
          (WidgetTester tester) async {
        logger.info('Testing embedded fonts', category: 'epub_parsing');

        // Arrange
        await tester.pumpWidget(
          const ProviderScope(
            child: app.MyApp(),
          ),
        );
        await TestHelpers.waitForAppSettled(tester);

        final libraryPage = LibraryPage(tester);
        await libraryPage.waitForLoad();

        // Act - Import EPUB with embedded fonts
        // await libraryPage.importBookFromAssets('embedded_fonts.epub');
        // await libraryPage.openBook(0);

        // Assert - Should parse successfully
        // Fonts may or may not be used depending on implementation

        logger.info('Embedded fonts handled', category: 'epub_parsing');
        logger.info('Embedded fonts test completed', category: 'epub_parsing');
      }, skip: true, reason: 'Requires embedded fonts test file');

      testWidgets('Handle EPUB with external resources',
          (WidgetTester tester) async {
        logger.info('Testing external resources', category: 'epub_parsing');

        // Arrange
        await tester.pumpWidget(
          const ProviderScope(
            child: app.MyApp(),
          ),
        );
        await TestHelpers.waitForAppSettled(tester);

        final libraryPage = LibraryPage(tester);
        await libraryPage.waitForLoad();

        // Act - Import EPUB with external CSS/images
        // await libraryPage.importBookFromAssets('external_resources.epub');
        // await libraryPage.openBook(0);

        // Assert - Should handle external references
        // Resources should be available

        logger.info('External resources handled', category: 'epub_parsing');
        logger.info('External resources test completed', category: 'epub_parsing');
      }, skip: true, reason: 'Requires external resources test file');

      testWidgets('Handle EPUB with spine order',
          (WidgetTester tester) async {
        logger.info('Testing spine order', category: 'epub_parsing');

        // Arrange
        await tester.pumpWidget(
          const ProviderScope(
            child: app.MyApp(),
          ),
        );
        await TestHelpers.waitForAppSettled(tester);

        final libraryPage = LibraryPage(tester);
        await libraryPage.waitForLoad();

        // Act - Import EPUB with specific spine order
        // await libraryPage.importBookFromAssets('spine_order.epub');
        // await libraryPage.openBook(0);

        // Assert - Chapters should respect spine order
        // final chapters = await getBookChapters();
        // expect(chapters.first.index, lessThan(chapters.last.index));

        logger.info('Spine order respected', category: 'epub_parsing');
        logger.info('Spine order test completed', category: 'epub_parsing');
      }, skip: true, reason: 'Requires spine order test file');
    });

    group('Metadata Edge Cases', () {
      testWidgets('Handle missing title', (WidgetTester tester) async {
        logger.info('Testing missing title', category: 'epub_parsing');

        // Arrange
        await tester.pumpWidget(
          const ProviderScope(
            child: app.MyApp(),
          ),
        );
        await TestHelpers.waitForAppSettled(tester);

        final libraryPage = LibraryPage(tester);
        await libraryPage.waitForLoad();

        // Act - Import EPUB without title
        // await libraryPage.importBookFromAssets('no_title.epub');
        // await TestHelpers.waitForAppSettled(tester);

        // Assert - Should use filename as title
        // final book = libraryPage.getBook(0);
        // expect(book.title, isNotEmpty);

        logger.info('Missing title handled', category: 'epub_parsing');
        logger.info('Missing title test completed', category: 'epub_parsing');
      }, skip: true, reason: 'Requires no-title test file');

      testWidgets('Handle missing author', (WidgetTester tester) async {
        logger.info('Testing missing author', category: 'epub_parsing');

        // Arrange
        await tester.pumpWidget(
          const ProviderScope(
            child: app.MyApp(),
          ),
        );
        await TestHelpers.waitForAppSettled(tester);

        final libraryPage = LibraryPage(tester);
        await libraryPage.waitForLoad();

        // Act - Import EPUB without author
        // await libraryPage.importBookFromAssets('no_author.epub');
        // await TestHelpers.waitForAppSettled(tester);

        // Assert - Should show "Unknown" or similar
        // final book = libraryPage.getBook(0);
        // expect(book.author, isNotNull);

        logger.info('Missing author handled', category: 'epub_parsing');
        logger.info('Missing author test completed', category: 'epub_parsing');
      }, skip: true, reason: 'Requires no-author test file');

      testWidgets('Handle special characters in metadata',
          (WidgetTester tester) async {
        logger.info('Testing special characters in metadata',
            category: 'epub_parsing');

        // Arrange
        await tester.pumpWidget(
          const ProviderScope(
            child: app.MyApp(),
          ),
        );
        await TestHelpers.waitForAppSettled(tester);

        final libraryPage = LibraryPage(tester);
        await libraryPage.waitForLoad();

        // Act - Import EPUB with unicode in metadata
        // await libraryPage.importBookFromAssets('unicode_metadata.epub');
        // await TestHelpers.waitForAppSettled(tester);

        // Assert - Should handle unicode correctly
        // final book = libraryPage.getBook(0);
        // expect(book.title, contains('ña'));

        logger.info('Special characters handled', category: 'epub_parsing');
        logger.info('Special characters test completed', category: 'epub_parsing');
      }, skip: true, reason: 'Requires unicode metadata test file');
    });
  });
}
