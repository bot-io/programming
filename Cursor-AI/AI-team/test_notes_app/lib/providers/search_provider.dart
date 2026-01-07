import 'package:flutter/material.dart';
import 'package:simplenotes/models/note.dart';
import 'package:simplenotes/services/search_service.dart';

/// SearchProvider manages search state using the Provider pattern.
/// 
/// This provider implements reactive state management for search functionality
/// with search query, results, and filtering state. It handles loading and error states.
class SearchProvider with ChangeNotifier {
  /// The search service used for search operations.
  final SearchService _searchService;

  /// Current search query string.
  String _query = '';

  /// List of search results.
  List<Note> _results = [];

  /// Current loading state.
  bool _isLoading = false;

  /// Current error message, if any.
  String? _error;

  /// Optional category filter applied to search.
  String? _categoryFilter;

  /// Whether search is currently active (has non-empty query or filter).
  bool _isSearchActive = false;

  /// Creates a new [SearchProvider] instance.
  /// 
  /// [searchService] - The search service to use for operations.
  SearchProvider(this._searchService);

  /// Gets the current search query.
  String get query => _query;

  /// Gets the current list of search results.
  List<Note> get results => List.unmodifiable(_results);

  /// Gets the current loading state.
  bool get isLoading => _isLoading;

  /// Gets the current error message, if any.
  String? get error => _error;

  /// Checks if there's an error.
  bool get hasError => _error != null;

  /// Gets the current category filter.
  String? get categoryFilter => _categoryFilter;

  /// Checks if search is currently active.
  bool get isSearchActive => _isSearchActive;

  /// Gets the count of search results.
  int get resultCount => _results.length;

  /// Checks if there are no search results.
  bool get isEmpty => _results.isEmpty;

  /// Checks if there are search results.
  bool get hasResults => _results.isNotEmpty;

  /// Performs a search with the given query.
  /// 
  /// [query] - The search query string.
  /// [categoryId] - Optional category ID to filter by. If null, uses current category filter.
  /// 
  /// Throws [SearchServiceException] if the operation fails.
  Future<void> search({
    required String query,
    String? categoryId,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      // Update query and category filter
      _query = query.trim();
      if (categoryId != null) {
        _categoryFilter = categoryId.isEmpty ? null : categoryId;
      }

      // Update search active state
      _isSearchActive = _query.isNotEmpty || _categoryFilter != null;

      // Perform search
      if (_query.isEmpty && _categoryFilter == null) {
        // No search criteria, clear results
        _results = [];
      } else {
        _results = await _searchService.search(
          query: _query,
          categoryId: _categoryFilter,
        );
      }

      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setLoading(false);
      _setError('Failed to search: ${e.toString()}');
      rethrow;
    }
  }

  /// Performs a debounced search with the given query.
  /// 
  /// This method is useful for real-time search as the user types.
  /// It cancels any pending search and schedules a new one after the debounce delay.
  /// 
  /// [query] - The search query string.
  /// [categoryId] - Optional category ID to filter by. If null, uses current category filter.
  /// [debounceMs] - Debounce delay in milliseconds (default: 300ms).
  /// 
  /// Throws [SearchServiceException] if the operation fails.
  Future<void> searchDebounced({
    required String query,
    String? categoryId,
    int debounceMs = 300,
  }) async {
    _clearError();

    // Update query immediately for UI responsiveness
    _query = query.trim();
    if (categoryId != null) {
      _categoryFilter = categoryId.isEmpty ? null : categoryId;
    }

    // Update search active state
    _isSearchActive = _query.isNotEmpty || _categoryFilter != null;

    // If query is empty and no filter, clear results immediately
    if (_query.isEmpty && _categoryFilter == null) {
      _results = [];
      _setLoading(false);
      notifyListeners();
      return;
    }

    // Set loading state
    _setLoading(true);
    notifyListeners();

    try {
      await _searchService.searchDebounced(
        query: _query,
        categoryId: _categoryFilter,
        debounceMs: debounceMs,
        onResults: (results) {
          _results = results;
          _setLoading(false);
          notifyListeners();
        },
      );
    } catch (e) {
      _setLoading(false);
      _setError('Failed to search: ${e.toString()}');
      notifyListeners();
      rethrow;
    }
  }

  /// Sets the search query without performing a search.
  /// 
  /// [query] - The search query string.
  void setQuery(String query) {
    if (_query != query) {
      _query = query.trim();
      _isSearchActive = _query.isNotEmpty || _categoryFilter != null;
      notifyListeners();
    }
  }

  /// Sets the category filter and performs a search with the current query.
  /// 
  /// [categoryId] - The category ID to filter by. Pass `null` to clear the filter.
  /// 
  /// Throws [SearchServiceException] if the operation fails.
  Future<void> setCategoryFilter(String? categoryId) async {
    if (_categoryFilter != categoryId) {
      await search(
        query: _query,
        categoryId: categoryId,
      );
    }
  }

  /// Clears the search query and results.
  /// 
  /// This method resets the search state to its initial state.
  void clearSearch() {
    _query = '';
    _results = [];
    _categoryFilter = null;
    _isSearchActive = false;
    _clearError();
    _setLoading(false);
    notifyListeners();
  }

  /// Clears only the search query, keeping results and filters.
  void clearQuery() {
    _query = '';
    _isSearchActive = _categoryFilter != null;
    notifyListeners();
  }

  /// Clears only the category filter, keeping query and results.
  /// 
  /// Throws [SearchServiceException] if the operation fails.
  Future<void> clearCategoryFilter() async {
    await setCategoryFilter(null);
  }

  /// Refreshes the search results with the current query and filter.
  /// 
  /// Throws [SearchServiceException] if the operation fails.
  Future<void> refresh() async {
    if (_isSearchActive) {
      await search(
        query: _query,
        categoryId: _categoryFilter,
      );
    }
  }

  /// Highlights search matches in text and returns a list of TextSpan objects.
  /// 
  /// [text] - The text to highlight matches in.
  /// [matchStyle] - Optional text style for matched text.
  /// [normalStyle] - Optional text style for non-matched text.
  /// 
  /// Returns a list of [TextSpan] objects that can be used in a [Text.rich] widget.
  List<TextSpan> highlightMatches(
    String text, {
    TextStyle? matchStyle,
    TextStyle? normalStyle,
  }) {
    return _searchService.highlightMatches(
      text,
      _query,
      matchStyle: matchStyle,
      normalStyle: normalStyle,
    );
  }

  /// Highlights search matches in note title and returns a list of TextSpan objects.
  /// 
  /// [note] - The note whose title should be highlighted.
  /// [matchStyle] - Optional text style for matched text.
  /// [normalStyle] - Optional text style for non-matched text.
  /// 
  /// Returns a list of [TextSpan] objects for the note title.
  List<TextSpan> highlightNoteTitle(
    Note note, {
    TextStyle? matchStyle,
    TextStyle? normalStyle,
  }) {
    return _searchService.highlightNoteTitle(
      note,
      _query,
      matchStyle: matchStyle,
      normalStyle: normalStyle,
    );
  }

  /// Highlights search matches in note content and returns a list of TextSpan objects.
  /// 
  /// [note] - The note whose content should be highlighted.
  /// [matchStyle] - Optional text style for matched text.
  /// [normalStyle] - Optional text style for non-matched text.
  /// 
  /// Returns a list of [TextSpan] objects for the note content.
  List<TextSpan> highlightNoteContent(
    Note note, {
    TextStyle? matchStyle,
    TextStyle? normalStyle,
  }) {
    return _searchService.highlightNoteContent(
      note,
      _query,
      matchStyle: matchStyle,
      normalStyle: normalStyle,
    );
  }

  /// Checks if a note matches the current search query.
  /// 
  /// [note] - The note to check.
  /// 
  /// Returns `true` if the note matches the current query, `false` otherwise.
  bool noteMatches(Note note) {
    return _searchService.noteMatches(note, _query);
  }

  /// Cancels any pending debounced search.
  /// 
  /// Call this method when you want to cancel a scheduled search operation.
  void cancelDebouncedSearch() {
    _searchService.cancelDebouncedSearch();
    _setLoading(false);
    notifyListeners();
  }

  /// Clears the current error state.
  void clearError() {
    _clearError();
    notifyListeners();
  }

  /// Sets the loading state.
  void _setLoading(bool loading) {
    _isLoading = loading;
  }

  /// Sets the error message.
  void _setError(String errorMessage) {
    _error = errorMessage;
  }

  /// Clears the error message.
  void _clearError() {
    _error = null;
  }

  @override
  void dispose() {
    // Cancel any pending debounced searches
    _searchService.cancelDebouncedSearch();
    super.dispose();
  }
}
