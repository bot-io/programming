import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dual_reader/src/presentation/screens/library_screen.dart';
import 'package:get_it/get_it.dart';
import 'package:dual_reader/src/domain/usecases/get_all_books_usecase.dart';
import 'package:dual_reader/src/domain/usecases/import_book_usecase.dart';
import 'package:dual_reader/src/domain/usecases/delete_book_usecase.dart';
import 'package:dual_reader/src/domain/entities/book_entity.dart';
import 'package:file_picker/file_picker.dart';

class FakeGetAllBooksUseCase implements GetAllBooksUseCase {
  @override
  Future<List<BookEntity>> call() async => [];
  @override
  get bookRepository => throw UnimplementedError();
}

class FakeImportBookUseCase implements ImportBookUseCase {
  @override
  Future<void> call({FilePickerResult? pickResult}) async {}
  @override
  get bookRepository => throw UnimplementedError();
  @override
  get epubParserService => throw UnimplementedError();
}

class FakeDeleteBookUseCase implements DeleteBookUseCase {
  @override
  Future<void> call(String bookId) async {}
  @override
  get bookRepository => throw UnimplementedError();
}

void main() {
  final sl = GetIt.instance;

  setUp(() {
    sl.reset();
    sl.registerLazySingleton<GetAllBooksUseCase>(() => FakeGetAllBooksUseCase());
    sl.registerLazySingleton<ImportBookUseCase>(() => FakeImportBookUseCase());
    sl.registerLazySingleton<DeleteBookUseCase>(() => FakeDeleteBookUseCase());
  });

  testWidgets('LibraryScreen displays empty message when no books are present', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: LibraryScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('No books imported yet. Click the + icon to import a book.'), findsOneWidget);
  });
}
