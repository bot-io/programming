import 'package:dual_reader/src/domain/repositories/book_repository.dart';

class DeleteBookUseCase {
  final BookRepository _bookRepository;

  DeleteBookUseCase(this._bookRepository);

  Future<void> call(String bookId) async {
    await _bookRepository.deleteBook(bookId);
  }
}

