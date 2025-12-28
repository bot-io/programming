import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dual_reader/widgets/reader_controls.dart';

void main() {
  group('ReaderControls Widget Tests', () {
    testWidgets('displays current page and total pages', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderControls(
              currentPage: 5,
              totalPages: 100,
            ),
          ),
        ),
      );

      expect(find.text('Page 5 of 100'), findsOneWidget);
    });

    testWidgets('calls onPreviousPage when previous button is tapped', (WidgetTester tester) async {
      bool previousCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderControls(
              currentPage: 5,
              totalPages: 100,
              onPreviousPage: () {
                previousCalled = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();

      expect(previousCalled, true);
    });

    testWidgets('calls onNextPage when next button is tapped', (WidgetTester tester) async {
      bool nextCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderControls(
              currentPage: 5,
              totalPages: 100,
              onNextPage: () {
                nextCalled = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();

      expect(nextCalled, true);
    });

    testWidgets('disables previous button when onPreviousPage is null', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderControls(
              currentPage: 1,
              totalPages: 100,
            ),
          ),
        ),
      );

      final previousButton = tester.widget<IconButton>(find.byIcon(Icons.chevron_left));
      expect(previousButton.onPressed, isNull);
    });

    testWidgets('disables next button when onNextPage is null', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderControls(
              currentPage: 100,
              totalPages: 100,
            ),
          ),
        ),
      );

      final nextButton = tester.widget<IconButton>(find.byIcon(Icons.chevron_right));
      expect(nextButton.onPressed, isNull);
    });

    testWidgets('shows page input when page text is tapped', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderControls(
              currentPage: 5,
              totalPages: 100,
            ),
          ),
        ),
      );

      // Initially, page input should not be visible
      expect(find.byType(TextField), findsNothing);

      // Tap on page text
      await tester.tap(find.text('Page 5 of 100'));
      await tester.pumpAndSettle();

      // Page input should now be visible
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('calls onPageChanged when valid page is entered', (WidgetTester tester) async {
      int? changedPage;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderControls(
              currentPage: 5,
              totalPages: 100,
              onPageChanged: (page) {
                changedPage = page;
              },
            ),
          ),
        ),
      );

      // Show page input
      await tester.tap(find.text('Page 5 of 100'));
      await tester.pumpAndSettle();

      // Enter a valid page number
      await tester.enterText(find.byType(TextField), '25');
      await tester.tap(find.byIcon(Icons.check));
      await tester.pumpAndSettle();

      expect(changedPage, 25);
    });

    testWidgets('shows error snackbar for invalid page number', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderControls(
              currentPage: 5,
              totalPages: 100,
            ),
          ),
        ),
      );

      // Show page input
      await tester.tap(find.text('Page 5 of 100'));
      await tester.pumpAndSettle();

      // Enter an invalid page number
      await tester.enterText(find.byType(TextField), '150');
      await tester.tap(find.byIcon(Icons.check));
      await tester.pumpAndSettle();

      expect(find.textContaining('Please enter a page number between 1 and 100'), findsOneWidget);
    });

    testWidgets('calls onPageChanged when slider is moved', (WidgetTester tester) async {
      int? changedPage;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderControls(
              currentPage: 5,
              totalPages: 100,
              onPageChanged: (page) {
                changedPage = page;
              },
            ),
          ),
        ),
      );

      final slider = tester.widget<Slider>(find.byType(Slider));
      slider.onChanged!(50.0);
      await tester.pumpAndSettle();

      expect(changedPage, 50);
    });

    testWidgets('displays all control buttons', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderControls(
              currentPage: 5,
              totalPages: 100,
              onBookmarks: () {},
              onSettings: () {},
              onChapters: () {},
              onBack: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsOneWidget);
      expect(find.byIcon(Icons.menu_book), findsOneWidget);
      expect(find.text('Back'), findsOneWidget);
    });

    testWidgets('hides chapters button when onChapters is null', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderControls(
              currentPage: 5,
              totalPages: 100,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.menu_book), findsNothing);
    });

    testWidgets('calls onBack when back button is tapped', (WidgetTester tester) async {
      bool backCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderControls(
              currentPage: 5,
              totalPages: 100,
              onBack: () {
                backCalled = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();

      expect(backCalled, true);
    });

    testWidgets('calls onSettings when settings button is tapped', (WidgetTester tester) async {
      bool settingsCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderControls(
              currentPage: 5,
              totalPages: 100,
              onSettings: () {
                settingsCalled = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      expect(settingsCalled, true);
    });

    testWidgets('calls onBookmarks when bookmarks button is tapped', (WidgetTester tester) async {
      bool bookmarksCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderControls(
              currentPage: 5,
              totalPages: 100,
              onBookmarks: () {
                bookmarksCalled = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.bookmark_border));
      await tester.pumpAndSettle();

      expect(bookmarksCalled, true);
    });

    testWidgets('updates page input when currentPage changes', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: ReaderControls(
                  currentPage: 5,
                  totalPages: 100,
                ),
              );
            },
          ),
        ),
      );

      // Show page input
      await tester.tap(find.text('Page 5 of 100'));
      await tester.pumpAndSettle();

      expect(find.text('5'), findsOneWidget);
    });
  });
}
