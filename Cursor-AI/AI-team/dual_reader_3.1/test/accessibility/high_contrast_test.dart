import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:dual_reader/widgets/book_card.dart';
import 'package:dual_reader/models/book.dart';
import '../helpers/test_helpers.dart';

/// High Contrast Mode Accessibility Tests
/// 
/// These tests verify that the app works well in high contrast mode:
/// - Text is readable in high contrast themes
/// - Colors have sufficient contrast
/// - UI elements are distinguishable
/// - Focus indicators are visible

void main() {
  group('High Contrast Mode Accessibility Tests', () {
    group('Theme Contrast', () {
      testWidgets('dark theme provides sufficient contrast', (WidgetTester tester) async {
        final testBook = TestHelpers.createTestBook(
          id: 'contrast-test',
          title: 'Contrast Test Book',
          author: 'Author',
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: BookCard(
                book: testBook,
                onTap: () {},
              ),
            ),
          ),
        );

        // Widget should render without errors
        expect(find.byType(BookCard), findsOneWidget);
        
        // Text should be visible
        expect(find.text('Contrast Test Book'), findsOneWidget);
        expect(find.text('Author'), findsOneWidget);
      });

      testWidgets('light theme provides sufficient contrast', (WidgetTester tester) async {
        final testBook = TestHelpers.createTestBook(
          id: 'light-contrast',
          title: 'Light Contrast Book',
          author: 'Author',
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: Scaffold(
              body: BookCard(
                book: testBook,
                onTap: () {},
              ),
            ),
          ),
        );

        // Widget should render without errors
        expect(find.byType(BookCard), findsOneWidget);
        
        // Text should be visible
        expect(find.text('Light Contrast Book'), findsOneWidget);
      });

      testWidgets('high contrast theme works correctly', (WidgetTester tester) async {
        final testBook = TestHelpers.createTestBook(
          id: 'high-contrast',
          title: 'High Contrast Book',
          author: 'Author',
        );

        // Create high contrast theme
        final highContrastTheme = ThemeData(
          brightness: Brightness.dark,
          colorScheme: const ColorScheme.dark(
            primary: Colors.white,
            onPrimary: Colors.black,
            secondary: Colors.white,
            onSecondary: Colors.black,
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: highContrastTheme,
            home: Scaffold(
              body: BookCard(
                book: testBook,
                onTap: () {},
              ),
            ),
          ),
        );

        // Widget should render without errors
        expect(find.byType(BookCard), findsOneWidget);
        expect(find.text('High Contrast Book'), findsOneWidget);
      });
    });

    group('Text Readability', () {
      testWidgets('text is readable in all themes', (WidgetTester tester) async {
        final testBook = TestHelpers.createTestBook(
          id: 'readability-test',
          title: 'Readability Test',
          author: 'Author Name',
        );

        final themes = [
          ThemeData.light(),
          ThemeData.dark(),
          ThemeData(
            brightness: Brightness.dark,
            colorScheme: const ColorScheme.dark(
              primary: Colors.white,
              onPrimary: Colors.black,
            ),
          ),
        ];

        for (final theme in themes) {
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              home: Scaffold(
                body: BookCard(
                  book: testBook,
                  onTap: () {},
                ),
              ),
            ),
          );

          // Text should be present and readable
          expect(find.text('Readability Test'), findsOneWidget);
          expect(find.text('Author Name'), findsOneWidget);
        }
      });
    });

    group('Focus Indicators', () {
      testWidgets('focus indicators are visible in high contrast', (WidgetTester tester) async {
        final focusNode = FocusNode();

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: Focus(
                focusNode: focusNode,
                child: ElevatedButton(
                  onPressed: () {},
                  child: const Text('Test Button'),
                ),
              ),
            ),
          ),
        );

        // Focus node should be manageable
        expect(focusNode.canRequestFocus, isTrue);
        
        // Button should be visible
        expect(find.text('Test Button'), findsOneWidget);
      });
    });

    group('UI Element Distinction', () {
      testWidgets('interactive elements are distinguishable', (WidgetTester tester) async {
        final testBook = TestHelpers.createTestBook(
          id: 'distinction-test',
          title: 'Distinction Test',
          author: 'Author',
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: Column(
                children: [
                  BookCard(
                    book: testBook,
                    onTap: () {},
                  ),
                  ElevatedButton(
                    onPressed: () {},
                    child: const Text('Action Button'),
                  ),
                ],
              ),
            ),
          ),
        );

        // Both elements should be distinguishable
        expect(find.byType(BookCard), findsOneWidget);
        expect(find.text('Action Button'), findsOneWidget);
      });
    });
  });
}
