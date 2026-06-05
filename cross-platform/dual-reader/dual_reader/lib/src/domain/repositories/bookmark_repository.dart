import 'package:dual_reader/src/domain/entities/bookmark_entity.dart';

abstract class BookmarkRepository {
  Future<List<BookmarkEntity>> getBookmarks(String bookId);
  Future<BookmarkEntity> addBookmark(BookmarkEntity bookmark);
  Future<void> deleteBookmark(String id);
  Future<BookmarkEntity> updateBookmark(BookmarkEntity bookmark);
}
