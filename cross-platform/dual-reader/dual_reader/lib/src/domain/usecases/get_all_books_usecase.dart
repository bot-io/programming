import 'package:dual_reader/src/domain/entities/book_entity.dart';
import 'package:dual_reader/src/domain/repositories/book_repository.dart';

class GetAllBooksUseCase {
  final BookRepository _bookRepository;

  GetAllBooksUseCase(this._bookRepository);

  Future<List<BookEntity>> call() async {
    return await _bookRepository.getAllBooks();
  }
}

