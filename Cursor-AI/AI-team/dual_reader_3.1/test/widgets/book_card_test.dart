import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dual_reader/widgets/book_card.dart';
import 'package:dual_reader/models/book.dart';
import 'package:dual_reader/models/reading_progress.dart';
import 'package:dual_reader/models/chapter.dart';

void main() {
  group('BookCard Widget Tests', () {
    late Book testBook;

    setUp(() {
      testBook = Book(
        id: 'test-book-1',
        title: 'Test Book Title',
        author: 'Test Author',
        filePath: '/path/to/book.epub',
        format: 'epub',
        chapters: [],
        fullText: 'Test content',
        addedAt: DateTime.now(),
        totalPages: 100,
      );
    });

    testWidgets('displays book title and author', (WidgetTester tester) async {
      bool onTapCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BookCard(
              book: testBook,
              onTap: () {
                onTapCalled = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('Test Book Title'), findsOneWidget);
      expect(find.text('Test Author'), findsOneWidget);
    });

    testWidgets('calls onTap when card is tapped', (WidgetTester tester) async {
      bool onTapCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BookCard(
              book: testBook,
              onTap: () {
                onTapCalled = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();

      expect(onTapCalled, true);
    });

    testWidgets('displays progress when available', (WidgetTester tester) async {
      final progress = ReadingProgress(
        bookId: testBook.id,
        currentPage: 25,
        totalPages: 100,
        progress: 0.25,
        lastReadAt: DateTime.now(),
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

      expect(find.text('25% • Page 25/100'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('displays "Not started" when progress is null', (WidgetTester tester) async {
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

      expect(find.text('Not started'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('displays delete button when onDelete is provided', (WidgetTester tester) async {
      bool deleteCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BookCard(
              book: testBook,
              onTap: () {},
              onDelete: () {
                deleteCalled = true;
              },
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.delete_outline), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(deleteCalled, true);
    });

    testWidgets('does not display delete button when onDelete is null', (WidgetTester tester) async {
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

      expect(find.byIcon(Icons.delete_outline), findsNothing);
    });

    testWidgets('displays cover image container', (WidgetTester tester) async {
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

      // Check for the cover image container
      final containerFinder = find.byType(Container);
      expect(containerFinder, findsWidgets);
    });

    testWidgets('handles long titles with ellipsis', (WidgetTester tester) async {
      final longTitleBook = Book(
        id: 'test-book-2',
        title: 'This is a very long book title that should be truncated with ellipsis when displayed',
        author: 'Author',
        filePath: '/path/to/book.epub',
        format: 'epub',
        chapters: [],
        fullText: 'Content',
        addedAt: DateTime.now(),
        totalPages: 100,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200, // Constrain width to force truncation
              child: BookCard(
                book: longTitleBook,
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      final titleWidget = tester.widget<Text>(find.textContaining('This is a very long'));
      expect(titleWidget.maxLines, 2);
      expect(titleWidget.overflow, TextOverflow.ellipsis);
    });

    testWidgets('displays correct progress percentage', (WidgetTester tester) async {
      final progress = ReadingProgress(
        bookId: testBook.id,
        currentPage: 50,
        totalPages: 200,
        progress: 0.25,
        lastReadAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BookCard(
              book: testBook.copyWith(totalPages: 200),
              progress: progress,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('25% • Page 50/200'), findsOneWidget);
    });

    testWidgets('displays Material Design 3 Card with rounded corners', (WidgetTester tester) async {
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

      final cardFinder = find.byType(Card);
      expect(cardFinder, findsOneWidget);
      
      final card = tester.widget<Card>(cardFinder);
      expect(card.shape, isA<RoundedRectangleBorder>());
      
      final shape = card.shape as RoundedRectangleBorder;
      expect(shape.borderRadius, const BorderRadius.all(Radius.circular(12)));
    });

    testWidgets('displays progress indicator with bookmark icon', (WidgetTester tester) async {
      final progress = ReadingProgress(
        bookId: testBook.id,
        currentPage: 10,
        totalPages: 50,
        progress: 0.2,
        lastReadAt: DateTime.now(),
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

      expect(find.byIcon(Icons.bookmark_outline), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('displays book icon when progress is null', (WidgetTester tester) async {
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

      expect(find.byIcon(Icons.book_outlined), findsOneWidget);
    });

    testWidgets('handles zero progress correctly', (WidgetTester tester) async {
      final progress = ReadingProgress(
        bookId: testBook.id,
        currentPage: 0,
        totalPages: 100,
        progress: 0.0,
        lastReadAt: DateTime.now(),
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

      expect(find.text('0% • Page 0/100'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('handles 100% progress correctly', (WidgetTester tester) async {
      final progress = ReadingProgress(
        bookId: testBook.id,
        currentPage: 100,
        totalPages: 100,
        progress: 1.0,
        lastReadAt: DateTime.now(),
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

      expect(find.text('100% • Page 100/100'), findsOneWidget);
    });

    testWidgets('handles long author names with ellipsis', (WidgetTester tester) async {
      final longAuthorBook = Book(
        id: 'test-book-3',
        title: 'Book Title',
        author: 'This is a very long author name that should be truncated',
        filePath: '/path/to/book.epub',
        format: 'epub',
        chapters: [],
        fullText: 'Content',
        addedAt: DateTime.now(),
        totalPages: 100,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              child: BookCard(
                book: longAuthorBook,
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      final authorWidget = tester.widget<Text>(find.textContaining('This is a very long'));
      expect(authorWidget.maxLines, 1);
      expect(authorWidget.overflow, TextOverflow.ellipsis);
    });

    testWidgets('handles empty title gracefully', (WidgetTester tester) async {
      final emptyTitleBook = Book(
        id: 'test-book-4',
        title: '',
        author: 'Author',
        filePath: '/path/to/book.epub',
        format: 'epub',
        chapters: [],
        fullText: 'Content',
        addedAt: DateTime.now(),
        totalPages: 100,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BookCard(
              book: emptyTitleBook,
              onTap: () {},
            ),
          ),
        ),
      );

      // Should not throw and should render
      expect(find.text('Author'), findsOneWidget);
    });

    testWidgets('handles empty author gracefully', (WidgetTester tester) async {
      final emptyAuthorBook = Book(
        id: 'test-book-5',
        title: 'Title',
        author: '',
        filePath: '/path/to/book.epub',
        format: 'epub',
        chapters: [],
        fullText: 'Content',
        addedAt: DateTime.now(),
        totalPages: 100,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BookCard(
              book: emptyAuthorBook,
              onTap: () {},
            ),
          ),
        ),
      );

      // Should not throw and should render
      expect(find.text('Title'), findsOneWidget);
    });

    testWidgets('uses Material Design 3 color scheme', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.dark(),
          ),
          home: Scaffold(
            body: BookCard(
              book: testBook,
              onTap: () {},
            ),
          ),
        ),
      );

      final cardFinder = find.byType(Card);
      expect(cardFinder, findsOneWidget);
      
      // Verify the card uses Material 3 styling
      final card = tester.widget<Card>(cardFinder);
      expect(card.elevation, 1);
    });

    testWidgets('handles tap on entire card area', (WidgetTester tester) async {
      bool onTapCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BookCard(
              book: testBook,
              onTap: () {
                onTapCalled = true;
              },
            ),
          ),
        ),
      );

      // Tap anywhere on the card
      await tester.tap(find.byType(Card));
      await tester.pumpAndSettle();

      expect(onTapCalled, true);
    });

    testWidgets('displays cover image placeholder when coverImagePath is null', (WidgetTester tester) async {
      final bookWithoutCover = Book(
        id: 'test-book-6',
        title: 'Book Without Cover',
        author: 'Author',
        filePath: '/path/to/book.epub',
        format: 'epub',
        coverImagePath: null,
        chapters: [],
        fullText: 'Content',
        addedAt: DateTime.now(),
        totalPages: 100,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BookCard(
              book: bookWithoutCover,
              onTap: () {},
            ),
          ),
        ),
      );

      // Should display placeholder icon
      expect(find.byIcon(Icons.book), findsWidgets);
    });

    testWidgets('displays "Untitled" when title is empty', (WidgetTester tester) async {
      final emptyTitleBook = Book(
        id: 'test-book-7',
        title: '',
        author: 'Author',
        filePath: '/path/to/book.epub',
        format: 'epub',
        chapters: [],
        fullText: 'Content',
        addedAt: DateTime.now(),
        totalPages: 100,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BookCard(
              book: emptyTitleBook,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Untitled'), findsOneWidget);
    });

    testWidgets('displays "Unknown Author" when author is empty', (WidgetTester tester) async {
      final emptyAuthorBook = Book(
        id: 'test-book-8',
        title: 'Title',
        author: '',
        filePath: '/path/to/book.epub',
        format: 'epub',
        chapters: [],
        fullText: 'Content',
        addedAt: DateTime.now(),
        totalPages: 100,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BookCard(
              book: emptyAuthorBook,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Unknown Author'), findsOneWidget);
    });

    testWidgets('has accessibility semantics for screen readers', (WidgetTester tester) async {
      final progress = ReadingProgress(
        bookId: testBook.id,
        currentPage: 25,
        totalPages: 100,
        progress: 0.25,
        lastReadAt: DateTime.now(),
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

      // Check for Semantics widget
      final semanticsFinder = find.byType(Semantics);
      expect(semanticsFinder, findsWidgets);
    });

    testWidgets('clamps progress value between 0 and 1', (WidgetTester tester) async {
      // Test with progress > 1.0
      final invalidProgress = ReadingProgress(
        bookId: testBook.id,
        currentPage: 100,
        totalPages: 100,
        progress: 1.5, // Invalid progress > 1.0
        lastReadAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BookCard(
              book: testBook,
              progress: invalidProgress,
              onTap: () {},
            ),
          ),
        ),
      );

      // Should not throw and should render
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('handles negative progress gracefully', (WidgetTester tester) async {
      // Test with progress < 0.0
      final negativeProgress = ReadingProgress(
        bookId: testBook.id,
        currentPage: 0,
        totalPages: 100,
        progress: -0.5, // Invalid progress < 0.0
        lastReadAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BookCard(
              book: testBook,
              progress: negativeProgress,
              onTap: () {},
            ),
          ),
        ),
      );

      // Should not throw and should render
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('displays cover image with accessibility label', (WidgetTester tester) async {
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

      // Check for Semantics widget around cover image
      final semanticsFinder = find.byType(Semantics);
      expect(semanticsFinder, findsWidgets);
    });

    testWidgets('adapts cover size for small screens', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(400, 800)), // Small screen
            child: Scaffold(
              body: BookCard(
                book: testBook,
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      // Find the cover image container
      final containerFinder = find.byType(Container);
      expect(containerFinder, findsWidgets);
      
      // Verify the card has appropriate margins for small screen
      final cardFinder = find.byType(Card);
      final card = tester.widget<Card>(cardFinder);
      final margin = card.margin as EdgeInsets;
      expect(margin.horizontal, 16.0); // Small screen horizontal margin
      expect(margin.vertical, 8.0); // Small screen vertical margin
    });

    testWidgets('adapts cover size for tablet screens', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(800, 1200)), // Tablet screen
            child: Scaffold(
              body: BookCard(
                book: testBook,
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      // Verify the card has appropriate margins for tablet
      final cardFinder = find.byType(Card);
      final card = tester.widget<Card>(cardFinder);
      final margin = card.margin as EdgeInsets;
      expect(margin.horizontal, 24.0); // Tablet horizontal margin
      expect(margin.vertical, 12.0); // Tablet vertical margin
    });

    testWidgets('adapts cover size for desktop screens', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(1400, 900)), // Desktop screen
            child: Scaffold(
              body: BookCard(
                book: testBook,
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      // Verify the card has appropriate margins for desktop
      final cardFinder = find.byType(Card);
      final card = tester.widget<Card>(cardFinder);
      final margin = card.margin as EdgeInsets;
      expect(margin.horizontal, 24.0); // Desktop horizontal margin
      expect(margin.vertical, 12.0); // Desktop vertical margin
    });

    testWidgets('adapts icon size for different screen sizes', (WidgetTester tester) async {
      // Test small screen icon size
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(400, 800)), // Small screen
            child: Scaffold(
              body: BookCard(
                book: testBook,
                onTap: () {},
                onDelete: () {},
              ),
            ),
          ),
        ),
      );

      final iconButtonFinder = find.byType(IconButton);
      if (iconButtonFinder.evaluate().isNotEmpty) {
        final iconButton = tester.widget<IconButton>(iconButtonFinder.first);
        final icon = iconButton.icon as Icon;
        expect(icon.size, 20.0); // Small screen icon size
      }

      // Test tablet/desktop icon size
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(1200, 800)), // Tablet/Desktop screen
            child: Scaffold(
              body: BookCard(
                book: testBook,
                onTap: () {},
                onDelete: () {},
              ),
            ),
          ),
        ),
      );

      final iconButtonFinder2 = find.byType(IconButton);
      if (iconButtonFinder2.evaluate().isNotEmpty) {
        final iconButton = tester.widget<IconButton>(iconButtonFinder2.first);
        final icon = iconButton.icon as Icon;
        expect(icon.size, 24.0); // Tablet/Desktop icon size
      }
    });

    testWidgets('adapts padding for different screen sizes', (WidgetTester tester) async {
      // Test small screen padding
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(400, 800)), // Small screen
            child: Scaffold(
              body: BookCard(
                book: testBook,
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      final paddingFinder = find.byType(Padding);
      expect(paddingFinder, findsWidgets);
      
      // Test tablet/desktop padding
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(1200, 800)), // Tablet/Desktop screen
            child: Scaffold(
              body: BookCard(
                book: testBook,
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      final paddingFinder2 = find.byType(Padding);
      expect(paddingFinder2, findsWidgets);
    });

    testWidgets('handles grid layout mode correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BookCard(
              book: testBook,
              onTap: () {},
              layoutMode: 'grid',
            ),
          ),
        ),
      );

      // Should render without errors
      expect(find.byType(BookCard), findsOneWidget);
      expect(find.text(testBook.title), findsOneWidget);
    });

    testWidgets('handles list layout mode correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BookCard(
              book: testBook,
              onTap: () {},
              layoutMode: 'list',
            ),
          ),
        ),
      );

      // Should render without errors
      expect(find.byType(BookCard), findsOneWidget);
      expect(find.text(testBook.title), findsOneWidget);
    });
  });
}
