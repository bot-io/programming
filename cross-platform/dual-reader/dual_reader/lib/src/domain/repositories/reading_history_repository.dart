import 'package:dual_reader/src/domain/entities/reading_history_entity.dart';

abstract class ReadingHistoryRepository {
  Future<List<ReadingHistoryEntity>> getHistory({int limit = 50});
  Future<List<ReadingHistoryEntity>> getHistoryForBook(String bookId);
  Future<ReadingHistoryEntity> addHistory(ReadingHistoryEntity entry);
  Future<void> clearHistory();
  Future<void> clearHistoryForBook(String bookId);
}
