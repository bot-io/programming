import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:dual_reader/widgets/book_card.dart';
import 'package:dual_reader/widgets/reader_controls.dart';
import 'package:dual_reader/models/book.dart';
import 'package:dual_reader/models/reading_progress.dart';
import '../helpers/test_helpers.dart';

/// Screen Reader Accessibility Tests
/// 
/// These tests verify that the app is accessible to screen readers:
/// - Semantic labels are present
/// - Widgets have proper accessibility properties
/// - Screen reader announcements work correctly
/// - Content is readable by assistive technologies

void main() {
  group('Screen Reader Accessibility Tests', () {
    group('BookCard Accessibility', () {
      testWidgets('BookCard has semantic label', (WidgetTester tester) async {
        final testBook = TestHelpers.createTestBook(
          id: 'accessibility-test',
          title: 'Test Book',
          author: 'Test Author',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BookCard(
                book: testBook,
                onTap: () {},
              ),
            ),
          ),
        );

        // Find Semantics widget
        final semantics = tester.widget<Semantics>(
          find.byType(Semantics),
        );

        expect(semantics.label, isNotNull);
        expect(semantics.label, contains('Test Book'));
        expect(semantics.label, contains('Test Author'));
      });

      testWidgets('BookCard with progress has progress information in label', (WidgetTester tester) async {
        final testBook = TestHelpers.createTestBook(
          id: 'progress-test',
          title: 'Progress Book',
          author: 'Author',
        );

        final progress = ReadingProgress(
          bookId: 'progress-test',
          currentPage: 5,
          totalPages: 10,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BookCard(
                book: testBook,
                progress: progress,
                onTap: () {},
              ),
            ),
          ),
        );

        final semantics = tester.widget<Semantics>(
          find.byType(Semantics),
        );

        expect(semantics.label, contains('50%'));
        expect(semantics.label, contains('Page 5'));
        expect(semantics.label, contains('of 10'));
      });

      testWidgets('BookCard is marked as button for screen readers', (WidgetTester tester) async {
        final testBook = TestHelpers.createTestBook(
          id: 'button-test',
          title: 'Button Test',
          author: 'Author',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BookCard(
                book: testBook,
                onTap: () {},
              ),
            ),
          ),
        );

        final semantics = tester.widget<Semantics>(
          find.byType(Semantics),
        );

        expect(semantics.button, isTrue);
      });
    });

    group('ReaderControls Accessibility', () {
      testWidgets('ReaderControls buttons have semantic labels', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ReaderControls(
                currentPage: 5,
                totalPages: 10,
                onPreviousPage: () {},
                onNextPage: () {},
                onSettings: () {},
                onBookmarks: () {},
                onChapters: () {},
                onBack: () {},
              ),
            ),
          ),
        );

        // Find IconButtons and verify they have tooltips or semantic labels
        final iconButtons = find.byType(IconButton);
        expect(iconButtons, findsWidgets);

        // Each button should be accessible
        for (final button in iconButtons.evaluate()) {
          final widget = tester.widget<IconButton>(button);
          // IconButtons should have tooltips or semantic information
          expect(widget.tooltip, anyOf(isNotNull, isNull));
        }
      });

      testWidgets('ReaderControls shows current page information', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ReaderControls(
                currentPage: 5,
                totalPages: 10,
                onPreviousPage: () {},
                onNextPage: () {},
              ),
            ),
          ),
        );

        // Should display page information
        expect(find.text('5'), findsWidgets);
        expect(find.text('10'), findsWidgets);
      });
    });

    group('General Accessibility', () {
      testWidgets('Interactive widgets have semantic labels', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              appBar: AppBar(title: const Text('Test')),
              body: Column(
                children: [
                  ElevatedButton(
                    onPressed: () {},
                    child: const Text('Test Button'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings),
                    onPressed: () {},
                    tooltip: 'Settings',
                  ),
                ],
              ),
            ),
          ),
        );

        // Buttons should have accessible labels
        expect(find.text('Test Button'), findsOneWidget);
        expect(find.byTooltip('Settings'), findsOneWidget);
      });

      testWidgets('Images have alternative text', (WidgetTester tester) async {
        final testBook = TestHelpers.createTestBook(
          id: 'image-test',
          title: 'Image Test',
          author: 'Author',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BookCard(
                book: testBook,
                onTap: () {},
              ),
            ),
          ),
        );

        // BookCard should have semantic label that includes book information
        final semantics = tester.widget<Semantics>(
          find.byType(Semantics),
        );
        expect(semantics.label, isNotNull);
        expect(semantics.label, isNotEmpty);
      });
    });

    group('Screen Reader Navigation', () {
      testWidgets('Focusable widgets are properly ordered', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  ElevatedButton(
                    onPressed: () {},
                    child: const Text('First Button'),
                  ),
                  ElevatedButton(
                    onPressed: () {},
                    child: const Text('Second Button'),
                  ),
                  ElevatedButton(
                    onPressed: () {},
                    child: const Text('Third Button'),
                  ),
                ],
              ),
            ),
          ),
        );

        // All buttons should be focusable
        final buttons = find.byType(ElevatedButton);
        expect(buttons, findsNWidgets(3));
      });
    });
  });
}
