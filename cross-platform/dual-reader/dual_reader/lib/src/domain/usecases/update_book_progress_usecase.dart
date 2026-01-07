import 'package:dual_reader/src/domain/entities/book_entity.dart';
import 'package:dual_reader/src/domain/repositories/book_repository.dart';

class UpdateBookProgressUseCase {
  final BookRepository _bookRepository;

  UpdateBookProgressUseCase(this._bookRepository);

  Future<void> call({required BookEntity book, required int currentPage, required int totalPages}) async {
    final updatedBook = book.copyWith(currentPage: currentPage, totalPages: totalPages);
    await _bookRepository.updateBook(updatedBook);
  }
}

