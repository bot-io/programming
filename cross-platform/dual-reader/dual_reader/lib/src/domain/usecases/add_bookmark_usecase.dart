import 'package:dual_reader/src/domain/entities/bookmark_entity.dart';
import 'package:dual_reader/src/domain/repositories/bookmark_repository.dart';

class AddBookmarkUseCase {
  final BookmarkRepository _bookmarkRepository;

  AddBookmarkUseCase(this._bookmarkRepository);

  Future<BookmarkEntity> call(BookmarkEntity bookmark) async {
    return await _bookmarkRepository.addBookmark(bookmark);
  }
}
