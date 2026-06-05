import 'package:dual_reader/src/domain/repositories/bookmark_repository.dart';

class DeleteBookmarkUseCase {
  final BookmarkRepository _bookmarkRepository;

  DeleteBookmarkUseCase(this._bookmarkRepository);

  Future<void> call(String bookmarkId) async {
    await _bookmarkRepository.deleteBookmark(bookmarkId);
  }
}
