import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for progress percentage display functionality
///
/// Verifies that progress percentage is calculated correctly:
/// Pages are 0-indexed internally, so:
/// - Page 0 of 100 (first page) = 1.0%
/// - Page 49 of 100 = 50.0%
/// - Page 99 of 100 (last page) = 100.0%
/// - Page 0 of 1 = 100.0%
/// - Page 0 of 0 = 0.0%
void main() {
  group('Progress Percentage Display', () {
    test('should calculate progress percentage correctly for various page counts', () {
      // Test cases: (currentPage, totalPages, expectedPercentage)
      // Note: currentPage is 0-indexed
      final testCases = [
        (0, 100, '1.0'),   // First page
        (49, 100, '50.0'),  // Middle page
        (99, 100, '100.0'), // Last page
        (0, 1, '100.0'),    // Only page
        (0, 2, '50.0'),    // First of two
        (1, 2, '100.0'),   // Second of two
        (0, 3, '33.3'),    // First of three
        (1, 3, '66.7'),    // Second of three
        (2, 3, '100.0'),   // Third of three
        (0, 10, '10.0'),   // First of ten
        (4, 10, '50.0'),   // Fifth of ten
        (9, 10, '100.0'),  // Tenth of ten
        (0, 1000, '0.1'),  // First of many
        (998, 1000, '99.9'), // Near end of many
        (1050, 1051, '100.0'), // Last page
      ];

      for (final (currentPage, totalPages, expected) in testCases) {
        final percentage = _calculateProgressPercentage(currentPage, totalPages);
        expect(
          percentage,
          equals(expected),
          reason: 'Page $currentPage (0-indexed) of $totalPages should show $expected%',
        );
      }
    });

    test('should handle edge cases correctly', () {
      // Edge case: Zero total pages
      final zeroPages = _calculateProgressPercentage(0, 0);
      expect(zeroPages, equals('0.0'), reason: 'Zero pages should show 0.0%');

      // Edge case: Very large page numbers
      final largePages = _calculateProgressPercentage(99999, 100000);
      expect(largePages, equals('100.0'), reason: 'Last page should show 100.0%');

      // Edge case: First page of many
      final firstOfMany = _calculateProgressPercentage(0, 1000000);
      expect(firstOfMany, equals('0.0'), reason: 'First of many pages should show 0.0%');
    });

    test('should format percentage with one decimal place', () {
      // Verify formatting
      final percentage1 = _calculateProgressPercentage(0, 3);
      expect(percentage1, contains('.'), reason: 'Should have decimal point');
      expect(percentage1.split('.')[1].length, equals(1), reason: 'Should have one decimal place');

      final percentage2 = _calculateProgressPercentage(1, 8);
      expect(percentage2, equals('25.0'), reason: '1/8 (second page) should be 25.0%');
    });

    test('should never exceed 100%', () {
      // Test that percentage never exceeds 100
      for (int totalPages = 1; totalPages <= 1000; totalPages++) {
        for (int currentPage = 0; currentPage < totalPages; currentPage++) {
          final percentage = _calculateProgressPercentage(currentPage, totalPages);
          final percentageValue = double.parse(percentage);
          expect(
            percentageValue,
            lessThanOrEqualTo(100.0),
            reason: 'Percentage for page $currentPage of $totalPages should not exceed 100%',
          );
        }
      }
    });
  });
}

/// Helper function that mirrors the implementation in dual_reader_screen.dart
/// Note: currentPage is 0-indexed, matching the implementation
String _calculateProgressPercentage(int currentPage, int totalPages) {
  if (totalPages <= 0) return '0.0';
  final progress = (currentPage + 1) / totalPages * 100;
  return progress.toStringAsFixed(1);
}
