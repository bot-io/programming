import 'package:simplenotes/models/note.dart';
import 'package:simplenotes/services/storage_service.dart';

/// Service class for managing note business logic.
/// 
/// This service provides high-level operations for note management,
/// including creation, updates, deletion, retrieval, filtering, and sorting.
/// It delegates storage operations to the [StorageService] implementation.
class NoteService {
  /// The storage service used for persistence operations.
  final StorageService _storageService;

  /// Creates a new [NoteService] instance.
  /// 
  /// [storageService] - The storage service to use for persistence.
  /// 
  /// Throws [ArgumentError] if [storageService] is null.
  NoteService(this._storageService) {
    if (_storageService == null) {
      throw ArgumentError.notNull('storageService');
    }
  }

  /// Creates a new note with validation.
  /// 
  /// [title] - The title of the note (required, cannot be empty).
  /// [content] - The content of the note (required).
  /// [categoryId] - Optional category ID to assign the note to.
  /// 
  /// Returns the created note.
  /// 
  /// Throws [NoteServiceException] if:
  /// - Storage service is not initialized
  /// - Validation fails
  /// - Note creation fails
  Future<Note> createNote({
    required String title,
    required String content,
    String? categoryId,
  }) async {
    if (!_storageService.isInitialized) {
      throw NoteServiceException(
        message: 'Storage service is not initialized',
        operation: 'createNote',
      );
    }

    // Generate unique ID
    final id = _generateId();

    // Create note instance
    final note = Note(
      id: id,
      title: title.trim(),
      content: content,
      categoryId: categoryId,
    );

    // Validate note
    final validationErrors = note.validate();
    if (validationErrors.isNotEmpty) {
      throw NoteServiceException(
        message: 'Validation failed: ${validationErrors.join(", ")}',
        operation: 'createNote',
      );
    }

    try {
      // Save to storage
      return await _storageService.createNote(note);
    } catch (e) {
      throw NoteServiceException(
        message: 'Failed to create note: $e',
        operation: 'createNote',
        originalError: e,
      );
    }
  }

  /// Updates an existing note with timestamp management.
  /// 
  /// [id] - The ID of the note to update.
  /// [title] - Optional new title for the note.
  /// [content] - Optional new content for the note.
  /// [categoryId] - Optional new category ID (use empty string to remove category).
  /// 
  /// Returns the updated note.
  /// 
  /// Throws [NoteServiceException] if:
  /// - Storage service is not initialized
  /// - Note not found
  /// - Validation fails
  /// - Update fails
  Future<Note> updateNote({
    required String id,
    String? title,
    String? content,
    String? categoryId,
  }) async {
    if (!_storageService.isInitialized) {
      throw NoteServiceException(
        message: 'Storage service is not initialized',
        operation: 'updateNote',
      );
    }

    // Retrieve existing note
    final existingNote = await _storageService.getNote(id);
    if (existingNote == null) {
      throw NoteServiceException(
        message: 'Note with id "$id" not found',
        operation: 'updateNote',
      );
    }

    // Create updated note with new timestamp
    final updatedNote = existingNote.copyWith(
      title: title != null ? title.trim() : null,
      content: content ?? null,
      categoryId: categoryId != null 
          ? (categoryId.isEmpty ? null : categoryId)
          : null,
      updatedAt: DateTime.now(), // Update timestamp
    );

    // Validate updated note
    final validationErrors = updatedNote.validate();
    if (validationErrors.isNotEmpty) {
      throw NoteServiceException(
        message: 'Validation failed: ${validationErrors.join(", ")}',
        operation: 'updateNote',
      );
    }

    try {
      // Save updated note
      return await _storageService.updateNote(updatedNote);
    } catch (e) {
      throw NoteServiceException(
        message: 'Failed to update note: $e',
        operation: 'updateNote',
        originalError: e,
      );
    }
  }

  /// Deletes a note by ID.
  /// 
  /// [id] - The ID of the note to delete.
  /// 
  /// Returns `true` if the note was deleted, `false` if it didn't exist.
  /// 
  /// Throws [NoteServiceException] if:
  /// - Storage service is not initialized
  /// - Deletion fails
  Future<bool> deleteNote(String id) async {
    if (!_storageService.isInitialized) {
      throw NoteServiceException(
        message: 'Storage service is not initialized',
        operation: 'deleteNote',
      );
    }

    if (id.isEmpty) {
      throw NoteServiceException(
        message: 'Note ID cannot be empty',
        operation: 'deleteNote',
      );
    }

    try {
      return await _storageService.deleteNote(id);
    } catch (e) {
      throw NoteServiceException(
        message: 'Failed to delete note: $e',
        operation: 'deleteNote',
        originalError: e,
      );
    }
  }

  /// Retrieves a single note by ID.
  /// 
  /// [id] - The ID of the note to retrieve.
  /// 
  /// Returns the note if found, `null` if not found.
  /// 
  /// Throws [NoteServiceException] if:
  /// - Storage service is not initialized
  /// - Retrieval fails
  Future<Note?> getNote(String id) async {
    if (!_storageService.isInitialized) {
      throw NoteServiceException(
        message: 'Storage service is not initialized',
        operation: 'getNote',
      );
    }

    if (id.isEmpty) {
      throw NoteServiceException(
        message: 'Note ID cannot be empty',
        operation: 'getNote',
      );
    }

    try {
      return await _storageService.getNote(id);
    } catch (e) {
      throw NoteServiceException(
        message: 'Failed to retrieve note: $e',
        operation: 'getNote',
        originalError: e,
      );
    }
  }

  /// Retrieves all notes with optional filtering and sorting.
  /// 
  /// [categoryId] - Optional category ID to filter by. If provided, only notes
  ///                belonging to this category are returned. If `null`, all notes are returned.
  /// [sortBy] - Optional sort field (default: [NoteSortField.updatedAt]).
  /// [sortOrder] - Optional sort order (default: [SortOrder.descending]).
  /// 
  /// Returns a list of notes matching the criteria.
  /// 
  /// Throws [NoteServiceException] if:
  /// - Storage service is not initialized
  /// - Retrieval fails
  Future<List<Note>> getNotes({
    String? categoryId,
    NoteSortField sortBy = NoteSortField.updatedAt,
    SortOrder sortOrder = SortOrder.descending,
  }) async {
    if (!_storageService.isInitialized) {
      throw NoteServiceException(
        message: 'Storage service is not initialized',
        operation: 'getNotes',
      );
    }

    try {
      // Retrieve notes from storage
      final List<Note> notes;
      if (categoryId != null && categoryId.isNotEmpty) {
        notes = await _storageService.getNotesByCategory(categoryId);
      } else {
        notes = await _storageService.getAllNotes();
      }

      // Sort notes
      return _sortNotes(notes, sortBy, sortOrder);
    } catch (e) {
      throw NoteServiceException(
        message: 'Failed to retrieve notes: $e',
        operation: 'getNotes',
        originalError: e,
      );
    }
  }

  /// Filters notes by search query (searches in title and content).
  /// 
  /// [query] - The search query string.
  /// [categoryId] - Optional category ID to filter by.
  /// [sortBy] - Optional sort field (default: [NoteSortField.updatedAt]).
  /// [sortOrder] - Optional sort order (default: [SortOrder.descending]).
  /// 
  /// Returns a list of notes matching the search query.
  /// 
  /// Throws [NoteServiceException] if:
  /// - Storage service is not initialized
  /// - Retrieval fails
  Future<List<Note>> searchNotes({
    required String query,
    String? categoryId,
    NoteSortField sortBy = NoteSortField.updatedAt,
    SortOrder sortOrder = SortOrder.descending,
  }) async {
    if (!_storageService.isInitialized) {
      throw NoteServiceException(
        message: 'Storage service is not initialized',
        operation: 'searchNotes',
      );
    }

    if (query.trim().isEmpty) {
      // Empty query returns all notes (or filtered by category)
      return getNotes(
        categoryId: categoryId,
        sortBy: sortBy,
        sortOrder: sortOrder,
      );
    }

    try {
      // Get notes (filtered by category if provided)
      final List<Note> notes;
      if (categoryId != null && categoryId.isNotEmpty) {
        notes = await _storageService.getNotesByCategory(categoryId);
      } else {
        notes = await _storageService.getAllNotes();
      }

      // Filter by search query (case-insensitive)
      final queryLower = query.toLowerCase().trim();
      final filteredNotes = notes.where((note) {
        return note.title.toLowerCase().contains(queryLower) ||
            note.content.toLowerCase().contains(queryLower);
      }).toList();

      // Sort filtered notes
      return _sortNotes(filteredNotes, sortBy, sortOrder);
    } catch (e) {
      throw NoteServiceException(
        message: 'Failed to search notes: $e',
        operation: 'searchNotes',
        originalError: e,
      );
    }
  }

  /// Sorts a list of notes according to the specified field and order.
  /// 
  /// [notes] - The list of notes to sort.
  /// [sortBy] - The field to sort by.
  /// [sortOrder] - The sort order (ascending or descending).
  /// 
  /// Returns a new sorted list of notes.
  List<Note> _sortNotes(
    List<Note> notes,
    NoteSortField sortBy,
    SortOrder sortOrder,
  ) {
    final sortedNotes = List<Note>.from(notes);

    sortedNotes.sort((a, b) {
      int comparison = 0;

      switch (sortBy) {
        case NoteSortField.title:
          comparison = a.title.toLowerCase().compareTo(b.title.toLowerCase());
          break;
        case NoteSortField.createdAt:
          comparison = a.createdAt.compareTo(b.createdAt);
          break;
        case NoteSortField.updatedAt:
          comparison = a.updatedAt.compareTo(b.updatedAt);
          break;
      }

      // Apply sort order
      return sortOrder == SortOrder.ascending ? comparison : -comparison;
    });

    return sortedNotes;
  }

  /// Generates a unique ID for a new note.
  /// 
  /// Uses timestamp and random component to ensure uniqueness.
  /// 
  /// Returns a unique string ID.
  String _generateId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp % 1000000).toString().padLeft(6, '0');
    return 'note_${timestamp}_$random';
  }
}

/// Enumeration of fields that can be used for sorting notes.
enum NoteSortField {
  /// Sort by note title (alphabetical).
  title,

  /// Sort by creation timestamp.
  createdAt,

  /// Sort by last update timestamp.
  updatedAt,
}

/// Enumeration of sort orders.
enum SortOrder {
  /// Ascending order (A-Z, oldest first).
  ascending,

  /// Descending order (Z-A, newest first).
  descending,
}

/// Exception class for note service-related errors.
/// 
/// This exception is thrown when note service operations fail.
class NoteServiceException implements Exception {
  /// The error message describing what went wrong.
  final String message;

  /// The operation that failed (e.g., 'createNote', 'updateNote').
  final String operation;

  /// The underlying error, if any.
  final dynamic originalError;

  /// Creates a new [NoteServiceException].
  /// 
  /// [message] - The error message.
  /// [operation] - The operation that failed.
  /// [originalError] - The underlying error, if any.
  NoteServiceException({
    required this.message,
    required this.operation,
    this.originalError,
  });

  @override
  String toString() {
    final buffer = StringBuffer('NoteServiceException: $message');
    buffer.write(' (Operation: $operation)');
    if (originalError != null) {
      buffer.write(' (Original error: $originalError)');
    }
    return buffer.toString();
  }
}
