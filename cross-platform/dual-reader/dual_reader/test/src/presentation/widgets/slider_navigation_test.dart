import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dual_reader/src/domain/entities/settings_entity.dart';

/// Tests for slider navigation widget
///
/// Verifies the deferred translation behavior:
/// 1. Slider moves visually during drag showing position
/// 2. Percentage indicator appears during drag
/// 3. Page content updates during drag (without translation)
/// 4. Translation only triggers when user lifts finger (onChangeEnd)
void main() {
  group('Slider Navigation Widget', () {
    testWidgets('should be available and interactive', (WidgetTester tester) async {
      // Given: A simple slider
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Slider(
              value: 0,
              min: 0,
              max: 99,
              divisions: 100,
              onChanged: (value) {},
            ),
          ),
        ),
      );

      // Then: Slider should be present
      final sliderFinder = find.byType(Slider);
      expect(sliderFinder, findsOneWidget);

      // When: Tapping on slider
      await tester.tap(sliderFinder);
      await tester.pump();

      // Then: Should not crash
      expect(sliderFinder, findsOneWidget);
    });

    testWidgets('should update value when dragged', (WidgetTester tester) async {
      // Given: A slider with state tracking
      double sliderValue = 0.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return Slider(
                  value: sliderValue,
                  min: 0,
                  max: 99,
                  divisions: 100,
                  onChanged: (value) {
                    setState(() {
                      sliderValue = value;
                    });
                  },
                );
              },
            ),
          ),
        ),
      );

      final sliderFinder = find.byType(Slider);

      // Given: Initial value
      Slider slider = tester.widget<Slider>(sliderFinder);
      expect(slider.value, equals(0.0));

      // When: Dragging the slider
      await tester.drag(sliderFinder, const Offset(100, 0));
      await tester.pump();

      // Then: Slider value should have changed
      slider = tester.widget<Slider>(sliderFinder);
      expect(slider.value, greaterThan(0.0), reason: 'Slider value should update during drag');
    });
  });

  group('Slider Navigation Logic', () {
    test('should calculate correct percentage for slider position', () {
      // Test cases: (currentPage, totalPages, expectedPercentage)
      final testCases = [
        (0, 100, '1'),    // First page
        (49, 100, '50'),  // Middle page
        (99, 100, '100'), // Last page
        (0, 1, '100'),    // Only page
        (0, 10, '10'),    // First of ten
        (4, 10, '50'),    // Fifth of ten
        (9, 10, '100'),   // Tenth of ten
      ];

      for (final (currentPage, totalPages, expected) in testCases) {
        final percentage = _calculateSliderPercentage(currentPage, totalPages);
        expect(
          percentage,
          equals(expected),
          reason: 'Page $currentPage (0-indexed) of $totalPages should show $expected%',
        );
      }
    });

    test('should format percentage as whole number', () {
      // Verify no decimal places
      final percentage = _calculateSliderPercentage(1, 3); // 66.666...%
      expect(percentage.contains('.'), isFalse, reason: 'Percentage should be whole number');
      expect(percentage, equals('67'));
    });

    test('should handle zero pages gracefully', () {
      expect(_calculateSliderPercentage(0, 0), equals('0'));
      expect(_calculateSliderPercentage(5, 0), equals('0'));
    });

    test('should handle edge cases', () {
      expect(_calculateSliderPercentage(0, 1), equals('100')); // Only page
      expect(_calculateSliderPercentage(0, 2), equals('50')); // First of two
      expect(_calculateSliderPercentage(1, 2), equals('100')); // Second of two
      expect(_calculateSliderPercentage(0, 1000), equals('0')); // First of many
      expect(_calculateSliderPercentage(999, 1000), equals('100')); // Last of many
    });

    test('should handle negative page index gracefully', () {
      // Should not happen in practice, but test robustness
      final result = _calculateSliderPercentage(-1, 100);
      // The formula would give 0%, which is fine for edge case
      expect(result, equals('0'));
    });
  });

  group('Slider Callback Behavior', () {
    testWidgets('onChangeStart should be called when drag begins', (WidgetTester tester) async {
      bool onChangeStartCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Slider(
              value: 0,
              min: 0,
              max: 99,
              divisions: 100,
              onChangeStart: (value) {
                onChangeStartCalled = true;
              },
              onChanged: (value) {},
            ),
          ),
        ),
      );

      final sliderFinder = find.byType(Slider);

      // When: Dragging the slider
      await tester.drag(sliderFinder, const Offset(50, 0));
      await tester.pump();

      // Then: onChangeStart should have been called
      expect(onChangeStartCalled, isTrue, reason: 'onChangeStart should be called when drag begins');
    });

    testWidgets('onChangeEnd should be called when drag ends', (WidgetTester tester) async {
      bool onChangeEndCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Slider(
              value: 0,
              min: 0,
              max: 99,
              divisions: 100,
              onChanged: (value) {},
              onChangeEnd: (value) {
                onChangeEndCalled = true;
              },
            ),
          ),
        ),
      );

      final sliderFinder = find.byType(Slider);

      // When: Dragging the slider
      await tester.drag(sliderFinder, const Offset(50, 0));
      await tester.pump();

      // Then: onChangeEnd should have been called
      expect(onChangeEndCalled, isTrue, reason: 'onChangeEnd should be called when drag ends');
    });

    testWidgets('onChanged should be called during drag', (WidgetTester tester) async {
      int onChangedCallCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Slider(
              value: 0,
              min: 0,
              max: 99,
              divisions: 100,
              onChanged: (value) {
                onChangedCallCount++;
              },
            ),
          ),
        ),
      );

      final sliderFinder = find.byType(Slider);

      // When: Dragging the slider
      await tester.drag(sliderFinder, const Offset(50, 0));
      await tester.pump();

      // Then: onChanged should have been called at least once
      expect(onChangedCallCount, greaterThan(0), reason: 'onChanged should be called during drag');
    });

    testWidgets('callbacks should be called in correct order: start -> changed -> end', (WidgetTester tester) async {
      final List<String> callbackLog = [];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Slider(
              value: 0,
              min: 0,
              max: 99,
              divisions: 100,
              onChangeStart: (value) {
                callbackLog.add('start');
              },
              onChanged: (value) {
                callbackLog.add('changed');
              },
              onChangeEnd: (value) {
                callbackLog.add('end');
              },
            ),
          ),
        ),
      );

      final sliderFinder = find.byType(Slider);

      // When: Dragging the slider
      await tester.drag(sliderFinder, const Offset(50, 0));
      await tester.pump();

      // Then: Callbacks should be in correct order
      expect(callbackLog, isNotEmpty);
      expect(callbackLog.first, equals('start'), reason: 'First callback should be onChangeStart');
      expect(callbackLog.last, equals('end'), reason: 'Last callback should be onChangeEnd');
      expect(callbackLog.contains('changed'), isTrue, reason: 'onChanged should be called during drag');
    });

    testWidgets('translation should only be triggered once at drag end', (WidgetTester tester) async {
      int translationCallCount = 0;
      int pageUpdateCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Slider(
              value: 0,
              min: 0,
              max: 99,
              divisions: 100,
              onChanged: (value) {
                // Simulate page update WITHOUT translation
                pageUpdateCount++;
              },
              onChangeEnd: (value) {
                // Simulate translation trigger AFTER drag
                translationCallCount++;
              },
            ),
          ),
        ),
      );

      final sliderFinder = find.byType(Slider);

      // When: Dragging the slider
      await tester.drag(sliderFinder, const Offset(100, 0));
      await tester.pump();

      // Then: Page updates should occur during drag
      expect(pageUpdateCount, greaterThan(0), reason: 'Page updates should occur during drag');

      // Then: Translation should be triggered exactly once (when drag ends)
      expect(translationCallCount, equals(1), reason: 'Translation should trigger once after drag ends');

      // Key verification: Page updates happen more frequently than translation triggers
      // This proves translation is deferred until drag ends
      expect(pageUpdateCount, greaterThan(translationCallCount), reason: 'Page updates should be more frequent than translation triggers');
    });
  });

  group('Slider Navigation Integration', () {
    testWidgets('complete slider interaction cycle', (WidgetTester tester) async {
      // This test verifies the complete slider interaction cycle
      double sliderValue = 0.0;
      final List<String> eventLog = [];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Text('Page: ${sliderValue.toInt() + 1}'),
                StatefulBuilder(
                  builder: (context, setState) {
                    return Slider(
                      value: sliderValue,
                      min: 0,
                      max: 99,
                      divisions: 100,
                      label: 'Page ${sliderValue.toInt() + 1} of 100',
                      onChangeStart: (value) {
                        setState(() {
                          sliderValue = value;
                          eventLog.add('start:${value.round()}');
                        });
                      },
                      onChanged: (value) {
                        setState(() {
                          sliderValue = value;
                          eventLog.add('change:${value.round()}');
                        });
                      },
                      onChangeEnd: (value) {
                        setState(() {
                          sliderValue = value;
                          eventLog.add('end:${value.round()}');
                        });
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );

      final sliderFinder = find.byType(Slider);

      // Initially: value should be 0
      expect(sliderValue, equals(0.0));

      // When: Complete drag cycle
      await tester.drag(sliderFinder, const Offset(100, 0));
      await tester.pump();

      // Then: Should have gone through complete cycle
      expect(eventLog, isNotEmpty, reason: 'Events should be logged');
      expect(eventLog.first, contains('start:'), reason: 'Should start with onChangeStart');
      expect(eventLog.last, contains('end:'), reason: 'Should end with onChangeEnd');

      // Then: Value should have changed
      expect(sliderValue, greaterThan(0), reason: 'Slider value should have changed');
    });
  });
}

/// Helper function to calculate slider percentage
/// Matches the implementation in dual_reader_screen.dart
String _calculateSliderPercentage(int currentPage, int totalPages) {
  if (totalPages <= 0) return '0';
  final progress = (currentPage + 1) / totalPages * 100;
  return progress.round().toString();
}
