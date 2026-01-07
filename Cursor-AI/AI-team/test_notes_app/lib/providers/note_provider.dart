import 'package:flutter/material.dart';
import 'package:simplenotes/models/note.dart';
import 'package:simplenotes/services/note_service.dart';

/// NoteProvider manages note state using the Provider pattern.
/// 
/// This provider implements reactive state management for notes with methods
/// to create, update, delete, and retrieve notes. It handles loading and error states.
class NoteProvider with ChangeNotifier {
  /// The note service used for business logic operations.
  final NoteService _noteService;

  /// List of all notes currently loaded in memory.
  List<Note> _notes = [];

  /// Current loading state.
  bool _isLoading = false;

  /// Current error message, if any.
  String? _error;

  /// Optional category filter applied to notes.
  String? _categoryFilter;

  /// Current sort field.
  NoteSortField _sortBy = NoteSortField.updatedAt;

  /// Current sort order.
  SortOrder _sortOrder = SortOrder.descending;

  /// Creates a new [NoteProvider] instance.
  /// 
  /// [noteService] - The note service to use for operations.
  NoteProvider(this._noteService);

  /// Gets the current list of notes (filtered and sorted).
  List<Note> get notes => List.unmodifiable(_notes);

  /// Gets the current loading state.
  bool get isLoading => _isLoading;

  /// Gets the current error message, if any.
  String? get error => _error;

  /// Checks if there's an error.
  bool get hasError => _error != null;

  /// Gets the current category filter.
  String? get categoryFilter => _categoryFilter;

  /// Gets the current sort field.
  NoteSortField get sortBy => _sortBy;

  /// Gets the current sort order.
  SortOrder get sortOrder => _sortOrder;

  /// Gets the count of notes.
  int get noteCount => _notes.length;

  /// Checks if there are no notes.
  bool get isEmpty => _notes.isEmpty;

  /// Loads all notes from storage.
  /// 
  /// This method retrieves all notes (optionally filtered by category)
  /// and updates the internal state. It handles loading and error states.
  /// 
  /// [categoryId] - Optional category ID to filter by. If null, all notes are loaded.
  /// [sortBy] - Optional sort field (default: current sort field).
  /// [sortOrder] - Optional sort order (default: current sort order).
  /// 
  /// Throws [NoteServiceException] if the operation fails.
  Future<void> loadNotes({
    String? categoryId,
    NoteSortField? sortBy,
    SortOrder? sortOrder,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      // Update filter and sort if provided
      if (categoryId != null) {
        _categoryFilter = categoryId.isEmpty ? null : categoryId;
      }
      if (sortBy != null) {
        _sortBy = sortBy;
      }
      if (sortOrder != null) {
        _sortOrder = sortOrder;
      }

      // Load notes from service
      _notes = await _noteService.getNotes(
        categoryId: _categoryFilter,
        sortBy: _sortBy,
        sortOrder: _sortOrder,
      );

      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setLoading(false);
      _setError('Failed to load notes: ${e.toString()}');
      rethrow;
    }
  }

  /// Creates a new note.
  /// 
  /// [title] - The title of the note (required).
  /// [content] - The content of the note (required).
  /// [categoryId] - Optional category ID to assign the note to.
  /// 
  /// Returns the created note.
  /// 
  /// Throws [NoteServiceException] if creation fails.
  Future<Note> createNote({
    required String title,
    required String content,
    String? categoryId,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final note = await _noteService.createNote(
        title: title,
        content: content,
        categoryId: categoryId,
      );

      // Reload notes to get updated list with proper sorting
      await loadNotes();

      _setLoading(false);
      notifyListeners();
      return note;
    } catch (e) {
      _setLoading(false);
      _setError('Failed to create note: ${e.toString()}');
      rethrow;
    }
  }

  /// Updates an existing note.
  /// 
  /// [id] - The ID of the note to update.
  /// [title] - Optional new title for the note.
  /// [content] - Optional new content for the note.
  /// [categoryId] - Optional new category ID (use empty string to remove category).
  /// 
  /// Returns the updated note.
  /// 
  /// Throws [NoteServiceException] if:
  /// - Note not found
  /// - Update fails
  Future<Note> updateNote({
    required String id,
    String? title,
    String? content,
    String? categoryId,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final updatedNote = await _noteService.updateNote(
        id: id,
        title: title,
        content: content,
        categoryId: categoryId,
      );

      // Reload notes to get updated list with proper sorting
      await loadNotes();

      _setLoading(false);
      notifyListeners();
      return updatedNote;
    } catch (e) {
      _setLoading(false);
      _setError('Failed to update note: ${e.toString()}');
      rethrow;
    }
  }

  /// Deletes a note by ID.
  /// 
  /// [id] - The ID of the note to delete.
  /// 
  /// Returns `true` if the note was deleted, `false` if it didn't exist.
  /// 
  /// Throws [NoteServiceException] if deletion fails.
  Future<bool> deleteNote(String id) async {
    _setLoading(true);
    _clearError();

    try {
      final deleted = await _noteService.deleteNote(id);

      if (deleted) {
        // Reload notes to get updated list
        await loadNotes();
      }

      _setLoading(false);
      notifyListeners();
      return deleted;
    } catch (e) {
      _setLoading(false);
      _setError('Failed to delete note: ${e.toString()}');
      rethrow;
    }
  }

  /// Retrieves a single note by ID.
  /// 
  /// [id] - The ID of the note to retrieve.
  /// 
  /// Returns the note if found, `null` if not found.
  /// 
  /// Throws [NoteServiceException] if retrieval fails.
  Future<Note?> getNote(String id) async {
    _clearError();

    try {
      return await _noteService.getNote(id);
    } catch (e) {
      _setError('Failed to retrieve note: ${e.toString()}');
      rethrow;
    }
  }

  /// Searches notes by query string.
  /// 
  /// [query] - The search query string.
  /// [categoryId] - Optional category ID to filter by.
  /// [sortBy] - Optional sort field (default: current sort field).
  /// [sortOrder] - Optional sort order (default: current sort order).
  /// 
  /// Returns a list of notes matching the search query.
  /// 
  /// Throws [NoteServiceException] if search fails.
  Future<List<Note>> searchNotes({
    required String query,
    String? categoryId,
    NoteSortField? sortBy,
    SortOrder? sortOrder,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final results = await _noteService.searchNotes(
        query: query,
        categoryId: categoryId ?? _categoryFilter,
        sortBy: sortBy ?? _sortBy,
        sortOrder: sortOrder ?? _sortOrder,
      );

      // Update the notes list with search results
      _notes = results;

      _setLoading(false);
      notifyListeners();
      return results;
    } catch (e) {
      _setLoading(false);
      _setError('Failed to search notes: ${e.toString()}');
      rethrow;
    }
  }

  /// Sets the category filter and reloads notes.
  /// 
  /// [categoryId] - The category ID to filter by. Pass `null` to clear the filter.
  Future<void> setCategoryFilter(String? categoryId) async {
    await loadNotes(categoryId: categoryId);
  }

  /// Sets the sort field and reloads notes.
  /// 
  /// [sortBy] - The field to sort by.
  Future<void> setSortBy(NoteSortField sortBy) async {
    await loadNotes(sortBy: sortBy);
  }

  /// Sets the sort order and reloads notes.
  /// 
  /// [sortOrder] - The sort order.
  Future<void> setSortOrder(SortOrder sortOrder) async {
    await loadNotes(sortOrder: sortOrder);
  }

  /// Clears the current error state.
  void clearError() {
    _clearError();
    notifyListeners();
  }

  /// Refreshes the notes list by reloading from storage.
  Future<void> refresh() async {
    await loadNotes();
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
}
