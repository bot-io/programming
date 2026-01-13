import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dual_reader/src/data/services/pagination_service_impl.dart';

void main() {
  group('PaginationServiceImpl', () {
    late PaginationServiceImpl service;

    setUp(() {
      service = PaginationServiceImpl();
    });

    test('should paginate text correctly based on constraints', () {
      // Given
      const text = 'This is a short sentence. This is another sentence. And a third one.';
      const constraints = BoxConstraints(
        maxWidth: 100, // Small width to force pagination
        maxHeight: 50, // Small height to force pagination
      );
      const textStyle = TextStyle(fontSize: 14);
      const lineHeight = 18.0; // Approximate line height

      // When
      final pages = service.paginateText(
        text: text,
        constraints: constraints,
        textStyle: textStyle,
        lineHeight: lineHeight,
      );

      // Then
      expect(pages, isNotEmpty);
      expect(pages.length, greaterThan(1));
      // Reconstruct the text by joining pages and removing all spaces to compare
      final reconstructed = pages.join('').replaceAll(RegExp(r'\s+'), '');
      final originalStripped = text.replaceAll(RegExp(r'\s+'), '');
      expect(reconstructed, equals(originalStripped));
    });

    test('should handle empty text', () {
      // Given
      const text = '';
      const constraints = BoxConstraints(
        maxWidth: 100,
        maxHeight: 100,
      );
      const textStyle = TextStyle(fontSize: 14);

      // When
      final pages = service.paginateText(
        text: text,
        constraints: constraints,
        textStyle: textStyle,
      );

      // Then
      expect(pages, isEmpty);
    });

    test('should respect paragraph breaks', () {
      // Given
      const text = 'Paragraph one.\n\nParagraph two.';
      const constraints = BoxConstraints(
        maxWidth: 200,
        maxHeight: 30,
      ); // Force break between paragraphs
      const textStyle = TextStyle(fontSize: 14);

      // When
      final pages = service.paginateText(
        text: text,
        constraints: constraints,
        textStyle: textStyle,
      );

      // Debug output
      print('DEBUG: Number of pages: ${pages.length}');
      for (int i = 0; i < pages.length; i++) {
        print('DEBUG: Page $i: "${pages[i]}"');
      }

      // Then
      expect(pages.length, greaterThanOrEqualTo(2));
      expect(pages[0].contains('Paragraph one.'), isTrue);
      expect(pages[1].contains('Paragraph two.'), isTrue);
    });

    test('should not put all remaining text on last page when it exceeds page capacity', () {
      // Given: A large text that should span many pages
      final text = 'This is a test sentence. ' * 1000; // ~20,000 characters
      const constraints = BoxConstraints(
        maxWidth: 300,
        maxHeight: 400,
      );
      const textStyle = TextStyle(fontSize: 16);

      // When
      final pages = service.paginateText(
        text: text,
        constraints: constraints,
        textStyle: textStyle,
      );

      // Debug output
      print('DEBUG: Total pages: ${pages.length}');
      print('DEBUG: Last page length: ${pages.last.length}');

      // Then:
      // 1. Should have multiple pages (not just 1-2)
      expect(pages.length, greaterThan(10), reason: 'Should create many pages for large text');

      // 2. Last page should not contain all remaining text
      // If the text is 20,000 chars and we have ~20 pages, each should be ~1000 chars
      // The last page should be similar in size, not 10,000+ chars
      expect(pages.last.length, lessThan(2000), reason: 'Last page should not contain excessive text');

      // 3. All pages except possibly the last should be reasonably sized
      for (int i = 0; i < pages.length - 1; i++) {
        expect(pages[i].length, lessThan(3000), reason: 'Page $i should be reasonably sized');
      }

      // 4. All text should be preserved
      final reconstructed = pages.join();
      expect(reconstructed, equals(text));
    });

    test('should handle very long text without timeout or premature stopping', () {
      // Given: A very long text (simulating a book chapter)
      final text = 'Sentence. ' * 10000; // ~90,000 characters
      const constraints = BoxConstraints(
        maxWidth: 350,
        maxHeight: 500,
      );
      const textStyle = TextStyle(fontSize: 14);

      // When
      final pages = service.paginateText(
        text: text,
        constraints: constraints,
        textStyle: textStyle,
      );

      // Then
      expect(pages, isNotEmpty);
      expect(pages.length, greaterThan(50), reason: 'Should create many pages for very long text');

      // Verify no page is excessively large
      for (int i = 0; i < pages.length; i++) {
        expect(pages[i].length, lessThan(5000), reason: 'Page $i should not be excessively large');
      }

      // Verify all text is preserved
      final reconstructed = pages.join();
      expect(reconstructed.length, equals(text.length));
    });

    test('should preserve paragraph breaks without text loss', () {
      // Regression test for the text loss bug
      // Given: Text with multiple consecutive paragraph breaks
      const text = 'Paragraph 1\n\n\n\nParagraph 2\n\n\nParagraph 3\n\n\n\nParagraph 4';
      const constraints = BoxConstraints(
        maxWidth: 200,
        maxHeight: 100,
      );
      const textStyle = TextStyle(fontSize: 14);

      // When
      final pages = service.paginateText(
        text: text,
        constraints: constraints,
        textStyle: textStyle,
      );

      // Then: All text must be preserved
      final reconstructed = pages.join();
      expect(reconstructed, equals(text), reason: 'All text including paragraph breaks must be preserved');
      expect(pages, isNotEmpty);
    });

    test('should preserve paragraph breaks at page boundaries', () {
      // Given: Text that's likely to break at paragraph boundaries
      final text = 'A' * 100 + '\n\n' + 'B' * 100 + '\n\n' + 'C' * 100;
      const constraints = BoxConstraints(
        maxWidth: 150,
        maxHeight: 80,
      );
      const textStyle = TextStyle(fontSize: 12);

      // When
      final pages = service.paginateText(
        text: text,
        constraints: constraints,
        textStyle: textStyle,
      );

      // Then: Verify no text loss
      final reconstructed = pages.join();
      expect(reconstructed, equals(text), reason: 'Text with paragraph breaks must be preserved');

      // Verify paragraph breaks are preserved (should have \n\n in the result)
      expect(reconstructed, contains('\n\n'));
    });

    test('should handle text with many consecutive paragraph breaks', () {
      // Edge case: Text with many consecutive breaks
      const text = 'Start\n\n\n\n\n\n\nEnd';
      const constraints = BoxConstraints(
        maxWidth: 200,
        maxHeight: 200,
      );
      const textStyle = TextStyle(fontSize: 14);

      // When
      final pages = service.paginateText(
        text: text,
        constraints: constraints,
        textStyle: textStyle,
      );

      // Then: Must preserve all paragraph breaks
      final reconstructed = pages.join();
      expect(reconstructed, equals(text), reason: 'All consecutive paragraph breaks must be preserved');
    });

    test('should not create empty pages from paragraph breaks', () {
      // Given: Text with paragraph breaks at the end
      const text = 'Some content\n\n\n\n';
      const constraints = BoxConstraints(
        maxWidth: 300,
        maxHeight: 200,
      );
      const textStyle = TextStyle(fontSize: 14);

      // When
      final pages = service.paginateText(
        text: text,
        constraints: constraints,
        textStyle: textStyle,
      );

      // Then: Should have exactly one page (no empty pages)
      expect(pages.length, equals(1), reason: 'Should not create empty pages from trailing paragraph breaks');

      // The page should contain the paragraph breaks
      expect(pages[0], contains('\n\n'));
    });

    test('should handle edge case of single character pages', () {
      // Given: Very short text that might create single-character pages
      const text = 'A\n\nB\n\nC';
      const constraints = BoxConstraints(
        maxWidth: 50,
        maxHeight: 20,
      );
      const textStyle = TextStyle(fontSize: 14);

      // When
      final pages = service.paginateText(
        text: text,
        constraints: constraints,
        textStyle: textStyle,
      );

      // Then: All characters must be preserved
      final reconstructed = pages.join();
      expect(reconstructed, equals(text));
      expect(pages, isNotEmpty);
    });
  });
}

