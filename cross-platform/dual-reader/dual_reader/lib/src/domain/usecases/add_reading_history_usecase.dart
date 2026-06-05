import 'package:dual_reader/src/domain/entities/reading_history_entity.dart';
import 'package:dual_reader/src/domain/repositories/reading_history_repository.dart';

class AddReadingHistoryUseCase {
  final ReadingHistoryRepository _repository;
  AddReadingHistoryUseCase(this._repository);

  Future<ReadingHistoryEntity> call(ReadingHistoryEntity entry) {
    return _repository.addHistory(entry);
  }
}
