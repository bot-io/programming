import 'package:hive/hive.dart';
import 'package:dual_reader/src/domain/entities/bookmark_entity.dart';
import 'package:dual_reader/src/domain/repositories/bookmark_repository.dart';
import 'package:dual_reader/src/core/utils/logging_service.dart';

class BookmarkRepositoryImpl implements BookmarkRepository {
  static const String _boxName = 'bookmarks';
  static const String _componentName = 'BookmarkRepository';

  Future<Box<BookmarkEntity>> _openBox() async {
    if (!Hive.isBoxOpen(_boxName)) {
      return await Hive.openBox<BookmarkEntity>(_boxName);
    } else {
      return Hive.box<BookmarkEntity>(_boxName);
    }
  }

  @override
  Future<List<BookmarkEntity>> getBookmarks(String bookId) async {
    try {
      final box = await _openBox();
      final bookmarks = box.values
          .where((bookmark) => bookmark.bookId == bookId)
          .toList();
      _componentName.logDebug(
        'Retrieved bookmarks for book - bookId: $bookId, count: ${bookmarks.length}',
      );
      return bookmarks;
    } catch (e) {
      _componentName.logError(
        'Failed to get bookmarks for book - bookId: $bookId',
        error: e,
      );
      rethrow;
    }
  }

  @override
  Future<BookmarkEntity> addBookmark(BookmarkEntity bookmark) async {
    try {
      final box = await _openBox();
      await box.put(bookmark.id, bookmark);
      _componentName.logInfo(
        'Bookmark added - id: ${bookmark.id}, bookId: ${bookmark.bookId}, page: ${bookmark.pageIndex}',
      );
      return bookmark;
    } catch (e) {
      _componentName.logError(
        'Failed to add bookmark - id: ${bookmark.id}',
        error: e,
      );
      rethrow;
    }
  }

  @override
  Future<void> deleteBookmark(String id) async {
    try {
      final box = await _openBox();
      final bookmark = box.get(id);
      if (bookmark != null) {
        await box.delete(id);
        _componentName.logInfo(
          'Bookmark deleted - id: $id, bookId: ${bookmark.bookId}, page: ${bookmark.pageIndex}',
        );
      } else {
        _componentName.logWarning(
          'Attempted to delete non-existent bookmark - id: $id',
        );
      }
    } catch (e) {
      _componentName.logError(
        'Failed to delete bookmark - id: $id',
        error: e,
      );
      rethrow;
    }
  }

  @override
  Future<BookmarkEntity> updateBookmark(BookmarkEntity bookmark) async {
    try {
      final box = await _openBox();
      await box.put(bookmark.id, bookmark);
      _componentName.logInfo(
        'Bookmark updated - id: ${bookmark.id}, label: "${bookmark.label}"',
      );
      return bookmark;
    } catch (e) {
      _componentName.logError(
        'Failed to update bookmark - id: ${bookmark.id}',
        error: e,
      );
      rethrow;
    }
  }
}
