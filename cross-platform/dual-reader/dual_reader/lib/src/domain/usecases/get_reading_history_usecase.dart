import 'package:dual_reader/src/domain/entities/reading_history_entity.dart';
import 'package:dual_reader/src/domain/repositories/reading_history_repository.dart';

class GetReadingHistoryUseCase {
  final ReadingHistoryRepository _repository;
  GetReadingHistoryUseCase(this._repository);

  Future<List<ReadingHistoryEntity>> call({int limit = 50}) {
    return _repository.getHistory(limit: limit);
  }

  Future<List<ReadingHistoryEntity>> forBook(String bookId) {
    return _repository.getHistoryForBook(bookId);
  }
}
