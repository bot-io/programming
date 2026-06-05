import 'package:hive/hive.dart';
import 'package:dual_reader/src/domain/entities/reading_history_entity.dart';
import 'package:dual_reader/src/domain/repositories/reading_history_repository.dart';
import 'package:dual_reader/src/core/utils/logging_service.dart';

class ReadingHistoryRepositoryImpl implements ReadingHistoryRepository {
  static const String _boxName = 'reading_history';
  static const String _componentName = 'ReadingHistoryRepository';

  Future<Box<ReadingHistoryEntity>> _openBox() async {
    if (!Hive.isBoxOpen(_boxName)) {
      return await Hive.openBox<ReadingHistoryEntity>(_boxName);
    } else {
      return Hive.box<ReadingHistoryEntity>(_boxName);
    }
  }

  @override
  Future<List<ReadingHistoryEntity>> getHistory({int limit = 50}) async {
    try {
      final box = await _openBox();
      final all = box.values.toList();
      all.sort((a, b) => b.endedAtMillis.compareTo(a.endedAtMillis));
      return all.take(limit).toList();
    } catch (e) {
      _componentName.logError('Failed to get reading history', error: e);
      rethrow;
    }
  }

  @override
  Future<List<ReadingHistoryEntity>> getHistoryForBook(String bookId) async {
    try {
      final box = await _openBox();
      final entries = box.values
          .where((e) => e.bookId == bookId)
          .toList();
      entries.sort((a, b) => b.endedAtMillis.compareTo(a.endedAtMillis));
      return entries;
    } catch (e) {
      _componentName.logError(
        'Failed to get history for book - bookId: $bookId',
        error: e,
      );
      rethrow;
    }
  }

  @override
  Future<ReadingHistoryEntity> addHistory(ReadingHistoryEntity entry) async {
    try {
      final box = await _openBox();
      await box.put(entry.id, entry);
      _componentName.logInfo(
        'Reading history added - bookId: ${entry.bookId}, pages: ${entry.startPage}-${entry.endPage}',
      );
      return entry;
    } catch (e) {
      _componentName.logError('Failed to add reading history', error: e);
      rethrow;
    }
  }

  @override
  Future<void> clearHistory() async {
    try {
      final box = await _openBox();
      await box.clear();
      _componentName.logInfo('Reading history cleared');
    } catch (e) {
      _componentName.logError('Failed to clear reading history', error: e);
      rethrow;
    }
  }

  @override
  Future<void> clearHistoryForBook(String bookId) async {
    try {
      final box = await _openBox();
      final keysToDelete = box.values
          .where((e) => e.bookId == bookId)
          .map((e) => e.id)
          .toList();
      for (final key in keysToDelete) {
        await box.delete(key);
      }
      _componentName.logInfo(
        'Reading history cleared for book - bookId: $bookId, entries removed: ${keysToDelete.length}',
      );
    } catch (e) {
      _componentName.logError(
        'Failed to clear history for book - bookId: $bookId',
        error: e,
      );
      rethrow;
    }
  }
}
