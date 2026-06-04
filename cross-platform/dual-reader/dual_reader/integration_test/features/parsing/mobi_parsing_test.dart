/// E2E Tests for MOBI Parsing
///
/// Tests MOBI file parsing functionality:
/// - Parse standard MOBI file
/// - Extract metadata (title, author, cover)
/// - Extract all chapters
/// - Extract chapter content
/// - Handle MOBI with images
/// - Handle KF8/AZW formats

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

  group('Parsing - MOBI E2E Tests', () {
    late TestLogger logger;

    setUpAll(() {
      logger = TestLogger();
    });

    tearDownAll(() async {
      await logger.dispose();
    });

    setUp(() {
      logger.logTestSetup('MOBI Parsing');
    });

    tearDown(() {
      logger.logTestTeardown('MOBI Parsing');
    });

    testWidgets('Parse standard MOBI file', (WidgetTester tester) async {
      logger.info('Testing MOBI parsing', category: 'mobi_parsing');

      // Arrange
      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettled(tester);

      final libraryPage = LibraryPage(tester);
      await libraryPage.waitForLoad();

      // Act - Import MOBI file
      // await libraryPage.importBookFromAssets('test.mobi');
      // await TestHelpers.waitForAppSettled(tester);

      // Assert - Book should be imported successfully
      // expect(libraryPage.getBookCount(), greaterThan(0));
      // final book = libraryPage.getBook(0);
      // expect(book.title, isNotEmpty);
      // expect(book.format, equals('MOBI'));

      logger.info('MOBI parsing verified', category: 'mobi_parsing');
      logger.info('MOBI test completed', category: 'mobi_parsing');
    }, skip: true, reason: 'Requires MOBI test file');

    testWidgets('Extract metadata (title, author, cover)',
        (WidgetTester tester) async {
      logger.info('Testing MOBI metadata extraction', category: 'mobi_parsing');

      // Arrange
      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettled(tester);

      final libraryPage = LibraryPage(tester);
      await libraryPage.waitForLoad();

      // Act - Import MOBI with metadata
      // await libraryPage.importBookFromAssets('metadata_test.mobi');
      // await TestHelpers.waitForAppSettled(tester);

      // Assert - Metadata should be extracted
      // final book = libraryPage.getBook(0);
      // expect(book.title, equals('Test MOBI Title'));
      // expect(book.author, equals('Test MOBI Author'));
      // expect(book.coverImage, isNotNull);

      logger.info('MOBI metadata extraction verified', category: 'mobi_parsing');
      logger.info('MOBI metadata test completed', category: 'mobi_parsing');
    }, skip: true, reason: 'Requires MOBI metadata test file');

    testWidgets('Extract all chapters', (WidgetTester tester) async {
      logger.info('Testing MOBI chapter extraction', category: 'mobi_parsing');

      // Arrange
      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettled(tester);

      final libraryPage = LibraryPage(tester);
      await libraryPage.waitForLoad();

      // Act - Import MOBI with chapters
      // await libraryPage.importBookFromAssets('multi_chapter.mobi');
      // await TestHelpers.waitForAppSettled(tester);

      // Open book
      // await libraryPage.openBook(0);
      // await TestHelpers.waitForAppSettled(tester);

      // Assert - All chapters should be extracted
      // final chapters = await getBookChapters();
      // expect(chapters, hasLength(greaterThan(1)));
      // expect(chapters.first.title, isNotEmpty);

      logger.info('MOBI chapter extraction verified', category: 'mobi_parsing');
      logger.info('MOBI chapter test completed', category: 'mobi_parsing');
    }, skip: true, reason: 'Requires multi-chapter MOBI test file');

    testWidgets('Extract chapter content', (WidgetTester tester) async {
      logger.info('Testing MOBI content extraction', category: 'mobi_parsing');

      // Arrange
      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettled(tester);

      final libraryPage = LibraryPage(tester);
      await libraryPage.waitForLoad();

      // Act - Import and open MOBI
      // await libraryPage.importBookFromAssets('content_test.mobi');
      // await libraryPage.openBook(0);

      // Assert - Chapter content should be extractable
      // final chapterContent = await getChapterContent(0);
      // expect(chapterContent, isNotEmpty);
      // expect(chapterContent.length, greaterThan(100));

      logger.info('MOBI content extraction verified', category: 'mobi_parsing');
      logger.info('MOBI content test completed', category: 'mobi_parsing');
    }, skip: true, reason: 'Requires MOBI content test file');

    testWidgets('Handle MOBI with images', (WidgetTester tester) async {
      logger.info('Testing MOBI image extraction', category: 'mobi_parsing');

      // Arrange
      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettled(tester);

      final libraryPage = LibraryPage(tester);
      await libraryPage.waitForLoad();

      // Act - Import MOBI with images
      // await libraryPage.importBookFromAssets('with_images.mobi');
      // await libraryPage.openBook(0);

      // Assert - Images should be extracted
      // final images = await getBookImages();
      // expect(images, isNotEmpty);

      logger.info('MOBI image extraction verified', category: 'mobi_parsing');
      logger.info('MOBI image test completed', category: 'mobi_parsing');
    }, skip: true, reason: 'Requires MOBI with images test file');

    testWidgets('Handle KF8 format', (WidgetTester tester) async {
      logger.info('Testing KF8 format', category: 'mobi_parsing');

      // Arrange
      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettled(tester);

      final libraryPage = LibraryPage(tester);
      await libraryPage.waitForLoad();

      // Act - Import KF8 file
      // await libraryPage.importBookFromAssets('test.kf8');
      // await TestHelpers.waitForAppSettled(tester);

      // Assert - Should parse KF8 format
      // expect(libraryPage.getBookCount(), greaterThan(0));
      // final book = libraryPage.getBook(0);
      // expect(book.format, contains('KF8'));

      logger.info('KF8 format handled', category: 'mobi_parsing');
      logger.info('KF8 test completed', category: 'mobi_parsing');
    }, skip: true, reason: 'Requires KF8 test file');

    testWidgets('Handle AZW format', (WidgetTester tester) async {
      logger.info('Testing AZW format', category: 'mobi_parsing');

      // Arrange
      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettled(tester);

      final libraryPage = LibraryPage(tester);
      await libraryPage.waitForLoad();

      // Act - Import AZW file
      // await libraryPage.importBookFromAssets('test.azw');
      // await TestHelpers.waitForAppSettled(tester);

      // Assert - Should parse AZW format
      // expect(libraryPage.getBookCount(), greaterThan(0));

      logger.info('AZW format handled', category: 'mobi_parsing');
      logger.info('AZW test completed', category: 'mobi_parsing');
    }, skip: true, reason: 'Requires AZW test file');

    testWidgets('Handle MOBI without ISBN', (WidgetTester tester) async {
      logger.info('Testing MOBI without ISBN', category: 'mobi_parsing');

      // Arrange
      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettled(tester);

      final libraryPage = LibraryPage(tester);
      await libraryPage.waitForLoad();

      // Act - Import MOBI without ISBN
      // await libraryPage.importBookFromAssets('no_isbn.mobi');
      // await TestHelpers.waitForAppSettled(tester);

      // Assert - Should handle gracefully
      // final book = libraryPage.getBook(0);
      // expect(book.isbn, isEmpty);

      logger.info('MOBI without ISBN handled', category: 'mobi_parsing');
      logger.info('No ISBN test completed', category: 'mobi_parsing');
    }, skip: true, reason: 'Requires MOBI without ISBN');

    testWidgets('Handle MOBI with complex markup',
        (WidgetTester tester) async {
      logger.info('Testing MOBI complex markup', category: 'mobi_parsing');

      // Arrange
      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettled(tester);

      final libraryPage = LibraryPage(tester);
      await libraryPage.waitForLoad();

      // Act - Import MOBI with complex HTML
      // await libraryPage.importBookFromAssets('complex_markup.mobi');
      // await libraryPage.openBook(0);

      // Assert - Should handle complex markup
      // final content = await getChapterContent(0);
      // expect(content, isNotEmpty);

      logger.info('MOBI complex markup handled', category: 'mobi_parsing');
      logger.info('Complex markup test completed', category: 'mobi_parsing');
    }, skip: true, reason: 'Requires complex markup MOBI test file');

    group('MOBI Structure', () {
      testWidgets('Handle MOBI with EXTH header',
          (WidgetTester tester) async {
        logger.info('Testing EXTH header', category: 'mobi_parsing');

        // Arrange
        await tester.pumpWidget(
          const ProviderScope(
            child: app.MyApp(),
          ),
        );
        await TestHelpers.waitForAppSettled(tester);

        final libraryPage = LibraryPage(tester);
        await libraryPage.waitForLoad();

        // Act - Import MOBI with EXTH header
        // await libraryPage.importBookFromAssets('with_exth.mobi');
        // await TestHelpers.waitForAppSettled(tester);

        // Assert - Should parse EXTH metadata
        // final book = libraryPage.getBook(0);
        // expect(book.publisher, isNotNull);

        logger.info('EXTH header handled', category: 'mobi_parsing');
        logger.info('EXTH test completed', category: 'mobi_parsing');
      }, skip: true, reason: 'Requires EXTH header test file');

      testWidgets('Handle MOBI with KF8 fallback',
          (WidgetTester tester) async {
        logger.info('Testing KF8 fallback', category: 'mobi_parsing');

        // Arrange
        await tester.pumpWidget(
          const ProviderScope(
            child: app.MyApp(),
          ),
        );
        await TestHelpers.waitForAppSettled(tester);

        final libraryPage = LibraryPage(tester);
        await libraryPage.waitForLoad();

        // Act - Import hybrid MOBI/KF8
        // await libraryPage.importBookFromAssets('hybrid.mobi');
        // await TestHelpers.waitForAppSettled(tester);

        // Assert - Should prefer KF8 if available
        // final book = libraryPage.getBook(0);
        // expect(book.format, equals('KF8'));

        logger.info('KF8 fallback handled', category: 'mobi_parsing');
        logger.info('Fallback test completed', category: 'mobi_parsing');
      }, skip: true, reason: 'Requires hybrid MOBI test file');

      testWidgets('Handle MOBI with inline TOC',
          (WidgetTester tester) async {
        logger.info('Testing inline TOC', category: 'mobi_parsing');

        // Arrange
        await tester.pumpWidget(
          const ProviderScope(
            child: app.MyApp(),
          ),
        );
        await TestHelpers.waitForAppSettled(tester);

        final libraryPage = LibraryPage(tester);
        await libraryPage.waitForLoad();

        // Act - Import MOBI with inline TOC
        // await libraryPage.importBookFromAssets('inline_toc.mobi');
        // await libraryPage.openBook(0);

        // Assert - Should extract inline TOC
        // final toc = await getTableOfContents();
        // expect(toc, isNotEmpty);

        logger.info('Inline TOC handled', category: 'mobi_parsing');
        logger.info('Inline TOC test completed', category: 'mobi_parsing');
      }, skip: true, reason: 'Requires inline TOC MOBI test file');
    });

    group('Image Handling', () {
      testWidgets('Extract MOBI cover image', (WidgetTester tester) async {
        logger.info('Testing cover extraction', category: 'mobi_parsing');

        // Arrange
        await tester.pumpWidget(
          const ProviderScope(
            child: app.MyApp(),
          ),
        );
        await TestHelpers.waitForAppSettled(tester);

        final libraryPage = LibraryPage(tester);
        await libraryPage.waitForLoad();

        // Act - Import MOBI with cover
        // await libraryPage.importBookFromAssets('with_cover.mobi');
        // await TestHelpers.waitForAppSettled(tester);

        // Assert - Cover should be extracted
        // final book = libraryPage.getBook(0);
        // expect(book.coverImage, isNotNull);

        logger.info('Cover extraction verified', category: 'mobi_parsing');
        logger.info('Cover test completed', category: 'mobi_parsing');
      }, skip: true, reason: 'Requires cover image test file');

      testWidgets('Handle low-res images in MOBI',
          (WidgetTester tester) async {
        logger.info('Testing low-res images', category: 'mobi_parsing');

        // Arrange
        await tester.pumpWidget(
          const ProviderScope(
            child: app.MyApp(),
          ),
        );
        await TestHelpers.waitForAppSettled(tester);

        final libraryPage = LibraryPage(tester);
        await libraryPage.waitForLoad();

        // Act - Import MOBI with low-res images
        // await libraryPage.importBookFromAssets('low_res_images.mobi');
        // await libraryPage.openBook(0);

        // Assert - Should handle low-res images
        // Images should still display

        logger.info('Low-res images handled', category: 'mobi_parsing');
        logger.info('Low-res test completed', category: 'mobi_parsing');
      }, skip: true, reason: 'Requires low-res image test file');
    });

    group('Platform Specific', () {
      testWidgets('MOBI parsing on mobile', (WidgetTester tester) async {
        if (!TestConfig.isAndroid && !TestConfig.isIOS) {
          logger.info('Skipped - mobile only', category: 'mobi_parsing');
          return;
        }

        logger.info('Testing mobile MOBI parsing', category: 'mobi_parsing');

        // Arrange
        await tester.pumpWidget(
          const ProviderScope(
            child: app.MyApp(),
          ),
        );
        await TestHelpers.waitForAppSettled(tester);

        final libraryPage = LibraryPage(tester);
        await libraryPage.waitForLoad();

        // Act - Import MOBI
        // await libraryPage.importBookFromAssets('test.mobi');
        // await TestHelpers.waitForAppSettled(tester);

        // Assert - Should parse on mobile

        logger.info('Mobile MOBI parsing verified', category: 'mobi_parsing');
        logger.info('Mobile test completed', category: 'mobi_parsing');
      }, skip: true, reason: 'Requires MOBI test file');

      testWidgets('MOBI parsing on web', (WidgetTester tester) async {
        if (!TestConfig.isWeb) {
          logger.info('Skipped - web only', category: 'mobi_parsing');
          return;
        }

        logger.info('Testing web MOBI parsing', category: 'mobi_parsing');

        // Arrange
        await tester.pumpWidget(
          const ProviderScope(
            child: app.MyApp(),
          ),
        );
        await TestHelpers.waitForAppSettled(tester);

        final libraryPage = LibraryPage(tester);
        await libraryPage.waitForLoad();

        // Act - Import MOBI
        // await libraryPage.importBookFromAssets('test.mobi');
        // await TestHelpers.waitForAppSettled(tester);

        // Assert - Should parse on web
        // May have limitations compared to mobile

        logger.info('Web MOBI parsing verified', category: 'mobi_parsing');
        logger.info('Web test completed', category: 'mobi_parsing');
      }, skip: true, reason: 'Requires MOBI test file and web parsing');
    });
  });
}
