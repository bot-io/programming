import 'package:dual_reader/src/domain/entities/bookmark_entity.dart';
import 'package:dual_reader/src/domain/repositories/bookmark_repository.dart';

class GetBookmarksUseCase {
  final BookmarkRepository _bookmarkRepository;

  GetBookmarksUseCase(this._bookmarkRepository);

  Future<List<BookmarkEntity>> call(String bookId) async {
    return await _bookmarkRepository.getBookmarks(bookId);
  }
}
