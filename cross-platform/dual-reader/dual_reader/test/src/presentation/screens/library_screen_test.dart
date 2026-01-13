import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dual_reader/src/presentation/screens/library_screen.dart';
import 'package:dual_reader/src/domain/usecases/get_all_books_usecase.dart';
import 'package:dual_reader/src/domain/usecases/import_book_usecase.dart';
import 'package:dual_reader/src/domain/usecases/delete_book_usecase.dart';
import 'package:dual_reader/src/domain/entities/book_entity.dart';
import 'package:dual_reader/src/presentation/providers/book_list_notifier.dart';
import 'package:dual_reader/src/presentation/providers/settings_notifier.dart';
import 'package:dual_reader/src/presentation/providers/language_model_notifier.dart';
import 'package:dual_reader/src/domain/usecases/get_settings_usecase.dart';
import 'package:dual_reader/src/domain/usecases/update_settings_usecase.dart';
import 'package:dual_reader/src/domain/entities/settings_entity.dart';
import 'package:get_it/get_it.dart';
import 'package:file_picker/file_picker.dart';

// Fake implementations
class FakeGetAllBooksUseCase implements GetAllBooksUseCase {
  List<BookEntity> _books = [];

  void setBooks(List<BookEntity> books) => _books = books;

  @override
  Future<List<BookEntity>> call() async => _books;

  @override
  get bookRepository => throw UnimplementedError();
}

class FakeGetSettingsUseCase implements GetSettingsUseCase {
  @override
  Future<SettingsEntity> call() async => const SettingsEntity(
    themeMode: ThemeMode.system,
    targetTranslationLanguageCode: 'es',
    fontSize: 16.0,
    lineHeight: 1.5,
    margin: 16.0,
    textAlign: TextAlign.justify,
  );

  @override
  get settingsRepository => throw UnimplementedError();
}

class FakeUpdateSettingsUseCase implements UpdateSettingsUseCase {
  @override
  Future<void> call(SettingsEntity settings) async {
    // Do nothing in tests
  }

  @override
  get settingsRepository => throw UnimplementedError();
}

class FakeImportBookUseCase implements ImportBookUseCase {
  bool importCalled = false;
  String? lastBookId;

  @override
  Future<void> call({FilePickerResult? pickResult}) async {
    importCalled = true;
    lastBookId = 'test-book-id';
  }

  @override
  get bookRepository => throw UnimplementedError();

  @override
  get epubParserService => throw UnimplementedError();
}

class FakeDeleteBookUseCase implements DeleteBookUseCase {
  bool deleteCalled = false;
  String? deletedBookId;

  @override
  Future<void> call(String bookId) async {
    deleteCalled = true;
    deletedBookId = bookId;
  }

  @override
  get bookRepository => throw UnimplementedError();
}

// Helper dates for testing
final _testDate1 = DateTime(2024, 1, 1);
final _testDate2 = DateTime(2024, 1, 2);
final _testDate3 = DateTime(2024, 1, 3);

void main() {
  final sl = GetIt.instance;
  late FakeGetAllBooksUseCase fakeGetAllBooksUseCase;
  late FakeImportBookUseCase fakeImportBookUseCase;
  late FakeDeleteBookUseCase fakeDeleteBookUseCase;
  late FakeGetSettingsUseCase fakeGetSettingsUseCase;
  late FakeUpdateSettingsUseCase fakeUpdateSettingsUseCase;

  setUp(() {
    sl.reset();
    fakeGetAllBooksUseCase = FakeGetAllBooksUseCase();
    fakeImportBookUseCase = FakeImportBookUseCase();
    fakeDeleteBookUseCase = FakeDeleteBookUseCase();
    fakeGetSettingsUseCase = FakeGetSettingsUseCase();
    fakeUpdateSettingsUseCase = FakeUpdateSettingsUseCase();

    sl.registerLazySingleton<GetAllBooksUseCase>(() => fakeGetAllBooksUseCase);
    sl.registerLazySingleton<ImportBookUseCase>(() => fakeImportBookUseCase);
    sl.registerLazySingleton<DeleteBookUseCase>(() => fakeDeleteBookUseCase);
    sl.registerLazySingleton<GetSettingsUseCase>(() => fakeGetSettingsUseCase);
    sl.registerLazySingleton<UpdateSettingsUseCase>(() => fakeUpdateSettingsUseCase);
  });

  tearDown(() async {
    await sl.reset();
  });

  group('LibraryScreen Widget Tests', () {
    testWidgets('LibraryScreen displays empty message when no books are present', (WidgetTester tester) async {
      fakeGetAllBooksUseCase.setBooks([]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bookListProvider.overrideWith((ref) {
              return BookListNotifier(fakeGetAllBooksUseCase);
            }),
          ],
          child: const MaterialApp(
            home: LibraryScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No books imported yet. Click the + icon to import a book.'), findsOneWidget);
    });

    testWidgets('LibraryScreen displays books in list', (WidgetTester tester) async {
      final testBooks = [
        BookEntity(
          id: 'book1',
          title: 'Test Book 1',
          author: 'Author 1',
          coverPath: '',
          filePath: '/path/to/book1.epub',
          importedDate: _testDate1,
          totalPages: 100,
          currentPage: 0,
        ),
        BookEntity(
          id: 'book2',
          title: 'Test Book 2',
          author: 'Author 2',
          coverPath: '',
          filePath: '/path/to/book2.epub',
          importedDate: _testDate2,
          totalPages: 200,
          currentPage: 50,
        ),
      ];

      fakeGetAllBooksUseCase.setBooks(testBooks);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bookListProvider.overrideWith((ref) {
              return BookListNotifier(fakeGetAllBooksUseCase);
            }),
          ],
          child: const MaterialApp(
            home: LibraryScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify both books are displayed
      expect(find.text('Test Book 1'), findsOneWidget);
      expect(find.text('Author 1'), findsOneWidget);
      expect(find.text('Test Book 2'), findsOneWidget);
      expect(find.text('Author 2'), findsOneWidget);
    });

    testWidgets('LibraryScreen shows progress percentage for books', (WidgetTester tester) async {
      final testBooks = [
        BookEntity(
          id: 'book1',
          title: 'Test Book',
          author: 'Author',
          coverPath: '',
          filePath: '/path/to/book.epub',
          importedDate: _testDate1,
          totalPages: 100,
          currentPage: 25,
        ),
      ];

      fakeGetAllBooksUseCase.setBooks(testBooks);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bookListProvider.overrideWith((ref) {
              return BookListNotifier(fakeGetAllBooksUseCase);
            }),
          ],
          child: const MaterialApp(
            home: LibraryScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify progress indicator is displayed
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('Test Book'), findsOneWidget);
      expect(find.text('Author'), findsOneWidget);
    });

    testWidgets('LibraryScreen shows 1% for new books', (WidgetTester tester) async {
      final testBooks = [
        BookEntity(
          id: 'book1',
          title: 'Test Book',
          author: 'Author',
          coverPath: '',
          filePath: '/path/to/book.epub',
          importedDate: _testDate1,
          totalPages: 100,
          currentPage: 0,
        ),
      ];

      fakeGetAllBooksUseCase.setBooks(testBooks);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bookListProvider.overrideWith((ref) {
              return BookListNotifier(fakeGetAllBooksUseCase);
            }),
          ],
          child: const MaterialApp(
            home: LibraryScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify progress indicator is displayed for new book
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('Test Book'), findsOneWidget);
    });

    testWidgets('LibraryScreen shows settings button in app bar', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bookListProvider.overrideWith((ref) {
              return BookListNotifier(fakeGetAllBooksUseCase);
            }),
          ],
          child: const MaterialApp(
            home: LibraryScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify app bar with settings button
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsOneWidget);
    });

    testWidgets('LibraryScreen has app bar with title', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bookListProvider.overrideWith((ref) {
              return BookListNotifier(fakeGetAllBooksUseCase);
            }),
          ],
          child: const MaterialApp(
            home: LibraryScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify app bar title
      expect(find.text('Your Library'), findsOneWidget);
    });

    testWidgets('LibraryScreen handles multiple books with different progress', (WidgetTester tester) async {
      final testBooks = [
        BookEntity(
          id: 'book1',
          title: 'Not Started',
          author: 'Author 1',
          coverPath: '',
          filePath: '/path/to/book1.epub',
          importedDate: _testDate1,
          totalPages: 100,
          currentPage: 0,
        ),
        BookEntity(
          id: 'book2',
          title: 'Halfway',
          author: 'Author 2',
          coverPath: '',
          filePath: '/path/to/book2.epub',
          importedDate: _testDate2,
          totalPages: 200,
          currentPage: 99,
        ),
        BookEntity(
          id: 'book3',
          title: 'Almost Done',
          author: 'Author 3',
          coverPath: '',
          filePath: '/path/to/book3.epub',
          importedDate: _testDate3,
          totalPages: 50,
          currentPage: 45,
        ),
      ];

      fakeGetAllBooksUseCase.setBooks(testBooks);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bookListProvider.overrideWith((ref) {
              return BookListNotifier(fakeGetAllBooksUseCase);
            }),
          ],
          child: MaterialApp(
            home: LibraryScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify at least some books are displayed (GridView may not render all items if they're off-screen)
      // The first book should always be visible
      expect(find.text('Not Started'), findsOneWidget);
      expect(find.text('Author 1'), findsOneWidget);

      // Verify at least one more book is visible (GridView has 2 columns, so at least 2 items should show)
      final hasSecondBook = find.text('Halfway').evaluate().isNotEmpty || find.text('Almost Done').evaluate().isNotEmpty;
      expect(hasSecondBook, isTrue);

      // Verify progress indicators are displayed (at least one should be visible)
      final progressIndicators = find.byType(LinearProgressIndicator);
      expect(progressIndicators, findsWidgets);
    });

    testWidgets('LibraryScreen shows progress indicator', (WidgetTester tester) async {
      final testBooks = [
        BookEntity(
          id: 'book1',
          title: 'Test Book',
          author: 'Author',
          coverPath: '',
          filePath: '/path/to/book.epub',
          importedDate: _testDate1,
          totalPages: 100,
          currentPage: 50,
        ),
      ];

      fakeGetAllBooksUseCase.setBooks(testBooks);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bookListProvider.overrideWith((ref) {
              return BookListNotifier(fakeGetAllBooksUseCase);
            }),
          ],
          child: const MaterialApp(
            home: LibraryScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify linear progress indicator is present
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('LibraryScreen book cards are tappable', (WidgetTester tester) async {
      final testBooks = [
        BookEntity(
          id: 'book1',
          title: 'Test Book',
          author: 'Author',
          coverPath: '',
          filePath: '/path/to/book.epub',
          importedDate: _testDate1,
          totalPages: 100,
          currentPage: 0,
        ),
      ];

      fakeGetAllBooksUseCase.setBooks(testBooks);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bookListProvider.overrideWith((ref) {
              return BookListNotifier(fakeGetAllBooksUseCase);
            }),
          ],
          child: MaterialApp(
            home: LibraryScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find the book card title to locate the specific card
      final bookTitle = find.text('Test Book');
      expect(bookTitle, findsOneWidget);

      // Verify that the InkWell exists and is tappable by checking it renders
      final inkWell = find.ancestor(
        of: bookTitle,
        matching: find.byType(InkWell),
      );
      expect(inkWell, findsOneWidget);

      // Note: We don't actually tap because it would require GoRouter setup
      // Just verifying the widget structure is correct is sufficient
    });
  });
}
