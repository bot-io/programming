import 'package:dual_reader/src/domain/entities/book_entity.dart';
import 'package:dual_reader/src/domain/repositories/book_repository.dart';

class GetBookByIdUseCase {
  final BookRepository _bookRepository;

  GetBookByIdUseCase(this._bookRepository);

  Future<BookEntity?> call(String id) async {
    return await _bookRepository.getBookById(id);
  }
}

