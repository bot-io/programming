import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:dual_reader/src/data/services/pagination_service_impl.dart';
import 'package:flutter/material.dart';

/// Debug test to investigate pagination issues with real book content
///
/// This test helps diagnose why the last page contains excessive text.
/// Run with: flutter test test/integration/pagination_debug_test.dart
void main() {
  group('Pagination Debug Tests', () {
    late PaginationServiceImpl service;

    setUp(() {
      service = PaginationServiceImpl();
    });

    test('Debug: Paginate large book with typical ebook settings', () {
      // Simulate typical ebook reader constraints
      // Based on dual_reader_screen.dart calculations:
      // - Screen height: ~800 (typical phone)
      // - AppBar: ~56
      // - Status bar: ~24
      // - Bottom nav: ~80
      // - Panel label: ~40
      // - Each panel gets: (800 - 56 - 24 - 80) / 2 - 40 = ~270px height
      // - Width: ~400px (phone width) - margins
      const constraints = BoxConstraints(
        maxWidth: 350,  // Typical phone width minus margins
        maxHeight: 270, // Typical panel height on phone
      );
      const textStyle = TextStyle(
        fontSize: 16,   // Default font size
        height: 1.5,    // Default line height
      );

      // Create a large text similar to a book chapter
      // Use varied sentence lengths and paragraph structures
      final paragraphs = <String>[];

      // Add 100 paragraphs of varying lengths
      for (int i = 0; i < 100; i++) {
        if (i % 3 == 0) {
          // Short paragraph
          paragraphs.add('This is a short paragraph. It has only a few sentences.');
        } else if (i % 3 == 1) {
          // Medium paragraph
          paragraphs.add(
            'This is a medium paragraph with more content. '
            'It contains several sentences that provide more detail. '
            'The text flows naturally and represents typical book content.'
          );
        } else {
          // Long paragraph
          paragraphs.add(
            'This is a longer paragraph that contains significantly more text. '
            'It represents the kind of detailed writing you might find in a novel. '
            'Such paragraphs can describe scenes, characters, or complex ideas. '
            'When paginating, we need to ensure these don\'t all get crammed '
            'onto the final page just because they\'re near the end of the book. '
            'The pagination algorithm should handle this gracefully.'
          );
        }
      }

      final text = paragraphs.join('\n\n');
      print('DEBUG: Total text length: ${text.length} characters');

      // When: Paginate the text
      final stopwatch = Stopwatch()..start();
      final pages = service.paginateText(
        text: text,
        constraints: constraints,
        textStyle: textStyle,
      );
      stopwatch.stop();

      // Then: Analyze the results
      print('\n========== PAGINATION RESULTS ==========');
      print('Total pages: ${pages.length}');
      print('Pagination time: ${stopwatch.elapsedMilliseconds}ms');
      print('Total characters: ${text.length}');
      print('Average chars per page: ${(text.length / pages.length).toStringAsFixed(1)}');

      // Analyze page sizes
      print('\n---------- PAGE SIZE ANALYSIS ----------');
      final pageSizes = pages.map((p) => p.length).toList();
      final minPageSize = pageSizes.reduce((a, b) => a < b ? a : b);
      final maxPageSize = pageSizes.reduce((a, b) => a > b ? a : b);
      final avgPageSize = pageSizes.reduce((a, b) => a + b) / pageSizes.length;

      print('Min page size: $minPageSize chars');
      print('Max page size: $maxPageSize chars');
      print('Avg page size: ${avgPageSize.toStringAsFixed(1)} chars');

      // Check if last page is abnormally large
      final lastPageSize = pages.last.length;
      final secondToLastPageSize = pages.length > 1 ? pages[pages.length - 2].length : 0;

      print('\n---------- FINAL PAGES ----------');
      if (pages.length > 1) {
        print('Page ${pages.length - 1} size: $secondToLastPageSize chars');
      }
      print('Page ${pages.length} size: $lastPageSize chars');

      final ratio = lastPageSize / avgPageSize;
      print('Last page / Average ratio: ${ratio.toStringAsFixed(2)}x');

      // Show first few and last few pages
      print('\n---------- FIRST 3 PAGES ----------');
      for (int i = 0; i < min(3, pages.length); i++) {
        final preview = pages[i].length > 100
            ? '${pages[i].substring(0, 100)}...'
            : pages[i];
        print('Page $i (${pages[i].length} chars): "$preview"');
      }

      print('\n---------- LAST 3 PAGES ----------');
      final start = max(0, pages.length - 3);
      for (int i = start; i < pages.length; i++) {
        final preview = pages[i].length > 100
            ? '${pages[i].substring(0, 100)}...'
            : pages[i];
        print('Page $i (${pages[i].length} chars): "$preview"');
      }

      // Assertions to verify correct behavior
      expect(pages, isNotEmpty);
      expect(pages.length, greaterThan(10), reason: 'Should create multiple pages');

      // Last page should not be excessively larger than average
      expect(
        ratio,
        lessThan(3.0),
        reason: 'Last page (${lastPageSize} chars) should not be more than 3x the average (${avgPageSize.toStringAsFixed(1)} chars). '
                'This indicates the pagination algorithm is putting too much text on the final page.',
      );

      // Last page should not be more than 3000 chars
      expect(
        lastPageSize,
        lessThan(3000),
        reason: 'Last page should not contain excessive text (> 3000 chars)',
      );

      // All text should be preserved
      final reconstructed = pages.join();
      expect(reconstructed.length, equals(text.length));

      print('\n========== TEST PASSED ==========\n');
    });

    test('Debug: Test edge case - small remaining text at end', () {
      // This test specifically checks the scenario where remaining text is < 5000 chars
      const constraints = BoxConstraints(
        maxWidth: 300,
        maxHeight: 400,
      );
      const textStyle = TextStyle(fontSize: 16, height: 1.5);

      // Create text that will result in exactly < 5000 chars remaining near the end
      final baseText = 'Word. ' * 100; // ~600 chars
      final fullText = baseText * 15; // ~9000 chars total

      print('\n========== SMALL REMAINING TEXT TEST ==========');
      print('Total text: ${fullText.length} chars');

      final pages = service.paginateText(
        text: fullText,
        constraints: constraints,
        textStyle: textStyle,
      );

      print('Pages created: ${pages.length}');

      // Check the last few pages
      print('\nLast 3 page sizes:');
      for (int i = max(0, pages.length - 3); i < pages.length; i++) {
        print('  Page $i: ${pages[i].length} chars');
      }

      // Verify last page is reasonable
      final lastPageSize = pages.last.length;
      final avgPageSize = fullText.length / pages.length;
      final ratio = lastPageSize / avgPageSize;

      print('Last page ratio to average: ${ratio.toStringAsFixed(2)}x');

      expect(
        ratio,
        lessThan(3.0),
        reason: 'Last page should not be excessively large compared to average',
      );

      print('========== TEST PASSED ==========\n');
    });
  });
}
