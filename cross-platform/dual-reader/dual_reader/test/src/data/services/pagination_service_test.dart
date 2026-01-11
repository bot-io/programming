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
  });
}

