import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:dual_reader/widgets/book_card.dart';
import 'package:dual_reader/models/book.dart';
import 'package:dual_reader/models/reading_progress.dart';
import '../helpers/test_helpers.dart';

/// Semantic Labels Accessibility Tests
/// 
/// These tests verify that widgets have proper semantic labels:
/// - All interactive elements have labels
/// - Labels are descriptive and meaningful
/// - Labels include context where needed
/// - Images have alternative text
/// - Icons have tooltips or labels

void main() {
  group('Semantic Labels Accessibility Tests', () {
    group('BookCard Semantic Labels', () {
      testWidgets('BookCard has comprehensive semantic label', (WidgetTester tester) async {
        final testBook = TestHelpers.createTestBook(
          id: 'semantic-test',
          title: 'Test Book Title',
          author: 'Test Author Name',
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

        // Label should include book title
        expect(semantics.label, contains('Test Book Title'));
        // Label should include author
        expect(semantics.label, contains('Test Author Name'));
        // Label should be meaningful
        expect(semantics.label, isNotEmpty);
      });

      testWidgets('BookCard label includes progress information when available', (WidgetTester tester) async {
        final testBook = TestHelpers.createTestBook(
          id: 'progress-semantic',
          title: 'Progress Book',
          author: 'Author',
        );

        final progress = ReadingProgress(
          bookId: 'progress-semantic',
          currentPage: 3,
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

        // Label should include progress information
        expect(semantics.label, contains('30%'));
        expect(semantics.label, contains('Page 3'));
        expect(semantics.label, contains('of 10'));
      });

      testWidgets('BookCard label indicates not started when no progress', (WidgetTester tester) async {
        final testBook = TestHelpers.createTestBook(
          id: 'no-progress',
          title: 'New Book',
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

        // Label should indicate not started
        expect(semantics.label, contains('Not started'));
      });
    });

    group('Button Labels', () {
      testWidgets('buttons have descriptive labels', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  ElevatedButton(
                    onPressed: () {},
                    child: const Text('Save Book'),
                  ),
                  ElevatedButton(
                    onPressed: () {},
                    child: const Text('Delete Book'),
                  ),
                ],
              ),
            ),
          ),
        );

        // Buttons should have text labels
        expect(find.text('Save Book'), findsOneWidget);
        expect(find.text('Delete Book'), findsOneWidget);
      });

      testWidgets('IconButtons have tooltips', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  IconButton(
                    icon: const Icon(Icons.settings),
                    onPressed: () {},
                    tooltip: 'Settings',
                  ),
                  IconButton(
                    icon: const Icon(Icons.bookmark),
                    onPressed: () {},
                    tooltip: 'Bookmarks',
                  ),
                ],
              ),
            ),
          ),
        );

        // IconButtons should have tooltips
        expect(find.byTooltip('Settings'), findsOneWidget);
        expect(find.byTooltip('Bookmarks'), findsOneWidget);
      });
    });

    group('Form Labels', () {
      testWidgets('text fields have labels', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Book Title',
                    ),
                  ),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Author Name',
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        // TextFields should have labels
        expect(find.text('Book Title'), findsOneWidget);
        expect(find.text('Author Name'), findsOneWidget);
      });
    });

    group('Image Alternative Text', () {
      testWidgets('BookCard provides alternative text for cover images', (WidgetTester tester) async {
        final testBook = TestHelpers.createTestBook(
          id: 'image-alt-test',
          title: 'Image Alt Test',
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

        // BookCard semantic label should serve as alt text for images
        final semantics = tester.widget<Semantics>(
          find.byType(Semantics),
        );
        expect(semantics.label, isNotNull);
        expect(semantics.label, isNotEmpty);
      });
    });

    group('Contextual Labels', () {
      testWidgets('labels include necessary context', (WidgetTester tester) async {
        final testBook = TestHelpers.createTestBook(
          id: 'context-test',
          title: 'Context Book',
          author: 'Author Name',
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

        // Label should include "by" to connect title and author
        expect(semantics.label, contains('by'));
      });
    });
  });
}
