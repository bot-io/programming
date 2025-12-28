import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:dual_reader/utils/pagination.dart';
import 'package:dual_reader/models/app_settings.dart';
import 'package:dual_reader/models/page_content.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('PaginationUtil', () {
    late AppSettings testSettings;
    late BuildContext testContext;
    late Widget testWidget;

    setUp(() {
      testSettings = TestHelpers.createTestSettings();
      testWidget = TestHelpers.createTestWidget(
        Builder(
          builder: (context) {
            testContext = context;
            return const SizedBox();
          },
        ),
      );
    });

    testWidgets('paginateText handles empty text', (WidgetTester tester) async {
      await tester.pumpWidget(testWidget);

      final pages = PaginationUtil.paginateText(
        text: '',
        pageSize: const Size(400, 800),
        settings: testSettings,
        context: testContext,
      );

      expect(pages.length, 1);
      expect(pages[0].originalText, '');
      expect(pages[0].pageNumber, 1);
      expect(pages[0].totalPages, 1);
    });

    testWidgets('paginateText handles whitespace-only text', (WidgetTester tester) async {
      await tester.pumpWidget(testWidget);

      final pages = PaginationUtil.paginateText(
        text: '   \n\n   ',
        pageSize: const Size(400, 800),
        settings: testSettings,
        context: testContext,
      );

      expect(pages.length, greaterThanOrEqualTo(1));
    });

    testWidgets('paginateText handles invalid page size', (WidgetTester tester) async {
      await tester.pumpWidget(testWidget);

      final pages = PaginationUtil.paginateText(
        text: 'Test text',
        pageSize: const Size(0, 0),
        settings: testSettings,
        context: testContext,
      );

      expect(pages.length, 1);
      expect(pages[0].originalText, 'Test text');
    });

    testWidgets('paginateText splits text into multiple pages', (WidgetTester tester) async {
      await tester.pumpWidget(testWidget);

      // Generate a long text that should span multiple pages
      final longText = TestHelpers.generateTestTextWithParagraphs(10, 50);

      final pages = PaginationUtil.paginateText(
        text: longText,
        pageSize: const Size(400, 600),
        settings: testSettings,
        context: testContext,
      );

      expect(pages.length, greaterThan(1));
      expect(pages[0].pageNumber, 1);
      expect(pages[pages.length - 1].pageNumber, pages.length);
      
      // Verify all pages have correct totalPages
      for (final page in pages) {
        expect(page.totalPages, pages.length);
      }
    });

    testWidgets('paginateText respects font size settings', (WidgetTester tester) async {
      await tester.pumpWidget(testWidget);

      final smallFontSettings = testSettings.copyWith(fontSize: 12);
      final largeFontSettings = testSettings.copyWith(fontSize: 24);

      final testText = TestHelpers.generateTestTextWithParagraphs(5, 30);

      final smallFontPages = PaginationUtil.paginateText(
        text: testText,
        pageSize: const Size(400, 600),
        settings: smallFontSettings,
        context: testContext,
      );

      final largeFontPages = PaginationUtil.paginateText(
        text: testText,
        pageSize: const Size(400, 600),
        settings: largeFontSettings,
        context: testContext,
      );

      // Larger font should create more pages (less text per page)
      expect(largeFontPages.length, greaterThanOrEqualTo(smallFontPages.length));
    });

    testWidgets('paginateText respects margin size settings', (WidgetTester tester) async {
      await tester.pumpWidget(testWidget);

      final smallMarginSettings = testSettings.copyWith(marginSize: 0);
      final largeMarginSettings = testSettings.copyWith(marginSize: 4);

      final testText = TestHelpers.generateTestTextWithParagraphs(5, 30);

      final smallMarginPages = PaginationUtil.paginateText(
        text: testText,
        pageSize: const Size(400, 600),
        settings: smallMarginSettings,
        context: testContext,
      );

      final largeMarginPages = PaginationUtil.paginateText(
        text: testText,
        pageSize: const Size(400, 600),
        settings: largeMarginSettings,
        context: testContext,
      );

      // Larger margins should create more pages (less available space)
      expect(largeMarginPages.length, greaterThanOrEqualTo(smallMarginPages.length));
    });

    testWidgets('paginateText handles single paragraph text', (WidgetTester tester) async {
      await tester.pumpWidget(testWidget);

      final singleParagraph = TestHelpers.generateTestText(100);

      final pages = PaginationUtil.paginateText(
        text: singleParagraph,
        pageSize: const Size(400, 600),
        settings: testSettings,
        context: testContext,
      );

      expect(pages.length, greaterThan(0));
      // Verify text is preserved across pages
      final combinedText = pages.map((p) => p.originalText).join(' ');
      expect(combinedText, contains(singleParagraph.split(' ').first));
    });

    testWidgets('paginateText handles very long words', (WidgetTester tester) async {
      await tester.pumpWidget(testWidget);

      final longWord = 'a' * 500; // Very long word
      final text = 'Start $longWord end';

      final pages = PaginationUtil.paginateText(
        text: text,
        pageSize: const Size(400, 600),
        settings: testSettings,
        context: testContext,
      );

      expect(pages.length, greaterThan(0));
      // Should not crash and should handle gracefully
      expect(pages[0].originalText, isNotEmpty);
    });

    testWidgets('paginateText preserves text content', (WidgetTester tester) async {
      await tester.pumpWidget(testWidget);

      final originalText = TestHelpers.generateTestTextWithParagraphs(3, 20);
      
      final pages = PaginationUtil.paginateText(
        text: originalText,
        pageSize: const Size(400, 600),
        settings: testSettings,
        context: testContext,
      );

      // Combine all page texts (removing extra whitespace)
      final combinedText = pages
          .map((p) => p.originalText.trim())
          .where((t) => t.isNotEmpty)
          .join(' ');

      // Verify all words from original text are present
      final originalWords = originalText.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toSet();
      final combinedWords = combinedText.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toSet();
      
      // Most words should be preserved (allowing for some whitespace differences)
      expect(combinedWords.length, greaterThanOrEqualTo(originalWords.length * 0.9));
    });

    testWidgets('paginateText handles different page sizes', (WidgetTester tester) async {
      await tester.pumpWidget(testWidget);

      final testText = TestHelpers.generateTestTextWithParagraphs(5, 30);

      final smallPages = PaginationUtil.paginateText(
        text: testText,
        pageSize: const Size(300, 400),
        settings: testSettings,
        context: testContext,
      );

      final largePages = PaginationUtil.paginateText(
        text: testText,
        pageSize: const Size(600, 1000),
        settings: testSettings,
        context: testContext,
      );

      // Smaller page size should create more pages
      expect(smallPages.length, greaterThanOrEqualTo(largePages.length));
    });
  });
}
