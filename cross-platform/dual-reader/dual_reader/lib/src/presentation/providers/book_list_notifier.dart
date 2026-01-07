import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dual_reader/src/domain/entities/book_entity.dart';
import 'package:dual_reader/src/domain/usecases/get_all_books_usecase.dart';
import 'package:dual_reader/src/core/di/injection_container.dart';

class BookListNotifier extends StateNotifier<List<BookEntity>> {
  final GetAllBooksUseCase _getAllBooksUseCase;

  BookListNotifier(this._getAllBooksUseCase) : super([]) {
    _loadBooks();
  }

  Future<void> _loadBooks() async {
    state = await _getAllBooksUseCase();
  }

  Future<void> refreshBooks() async {
    await _loadBooks();
  }
}

final bookListProvider = StateNotifierProvider<BookListNotifier, List<BookEntity>>((ref) {
  return BookListNotifier(sl<GetAllBooksUseCase>());
});
