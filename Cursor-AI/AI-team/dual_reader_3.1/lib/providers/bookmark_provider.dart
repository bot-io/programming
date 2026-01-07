import 'package:flutter/foundation.dart';
import '../models/bookmark.dart';
import '../services/storage_service.dart';
import 'package:uuid/uuid.dart';

class BookmarkProvider with ChangeNotifier {
  final StorageService _storageService;
  final String _bookId;
  
  List<Bookmark> _bookmarks = [];
  bool _isLoading = false;
  String? _error;

  BookmarkProvider(this._storageService, this._bookId) {
    _loadBookmarks();
  }

  List<Bookmark> get bookmarks => _bookmarks;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> _loadBookmarks() async {
    _isLoading = true;
    notifyListeners();

    try {
      _bookmarks = await _storageService.getBookmarksForBook(_bookId);
      _bookmarks.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      _error = null;
    } catch (e) {
      _error = 'Failed to load bookmarks: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addBookmark(int page, {String? note, String? chapterId}) async {
    try {
      final bookmark = Bookmark(
        id: const Uuid().v4(),
        bookId: _bookId,
        page: page,
        note: note,
        createdAt: DateTime.now(),
        chapterId: chapterId,
      );

      await _storageService.saveBookmark(bookmark);
      await _loadBookmarks();
      _error = null;
    } catch (e) {
      _error = 'Failed to add bookmark. Please try again.';
      notifyListeners();
      rethrow; // Re-throw so UI can show feedback
    }
  }

  Future<void> deleteBookmark(String bookmarkId) async {
    try {
      await _storageService.deleteBookmark(bookmarkId);
      await _loadBookmarks();
      _error = null;
    } catch (e) {
      _error = 'Failed to delete bookmark: $e';
      notifyListeners();
    }
  }

  Future<void> updateBookmark(Bookmark bookmark) async {
    try {
      await _storageService.saveBookmark(bookmark);
      await _loadBookmarks();
      _error = null;
    } catch (e) {
      _error = 'Failed to update bookmark: $e';
      notifyListeners();
    }
  }

  bool hasBookmarkOnPage(int page) {
    return _bookmarks.any((b) => b.page == page);
  }
}
