import 'package:simplenotes/models/note.dart';
import 'package:simplenotes/models/category.dart';

/// Abstract interface for storage operations on notes and categories.
/// 
/// This interface defines the contract for storage implementations,
/// allowing different storage backends (Hive, SQLite, etc.) to be used
/// interchangeably while maintaining consistent behavior.
abstract class StorageService {
  /// Initializes the storage service.
  /// 
  /// This method should be called before any other operations.
  /// It prepares the storage backend (opens boxes, initializes databases, etc.).
  /// 
  /// Returns `true` if initialization was successful, `false` otherwise.
  /// 
  /// Throws [StorageException] if initialization fails.
  Future<bool> initialize();

  /// Closes the storage service and releases resources.
  /// 
  /// Should be called when the service is no longer needed.
  /// 
  /// Throws [StorageException] if closing fails.
  Future<void> close();

  // ==================== Note CRUD Operations ====================

  /// Creates a new note in storage.
  /// 
  /// [note] - The note to create.
  /// 
  /// Returns the created note (potentially with updated fields).
  /// 
  /// Throws [StorageException] if creation fails or note already exists.
  Future<Note> createNote(Note note);

  /// Retrieves a note by its ID.
  /// 
  /// [id] - The unique identifier of the note.
  /// 
  /// Returns the note if found, `null` if not found.
  /// 
  /// Throws [StorageException] if retrieval fails.
  Future<Note?> getNote(String id);

  /// Retrieves all notes from storage.
  /// 
  /// Returns a list of all notes, empty list if no notes exist.
  /// 
  /// Throws [StorageException] if retrieval fails.
  Future<List<Note>> getAllNotes();

  /// Retrieves notes filtered by category ID.
  /// 
  /// [categoryId] - The category ID to filter by.
  /// 
  /// Returns a list of notes belonging to the specified category.
  /// 
  /// Throws [StorageException] if retrieval fails.
  Future<List<Note>> getNotesByCategory(String categoryId);

  /// Updates an existing note in storage.
  /// 
  /// [note] - The note with updated fields.
  /// 
  /// Returns the updated note.
  /// 
  /// Throws [StorageException] if update fails or note doesn't exist.
  Future<Note> updateNote(Note note);

  /// Deletes a note from storage.
  /// 
  /// [id] - The unique identifier of the note to delete.
  /// 
  /// Returns `true` if deletion was successful, `false` if note doesn't exist.
  /// 
  /// Throws [StorageException] if deletion fails.
  Future<bool> deleteNote(String id);

  /// Deletes all notes from storage.
  /// 
  /// Returns the number of notes deleted.
  /// 
  /// Throws [StorageException] if deletion fails.
  Future<int> deleteAllNotes();

  // ==================== Category CRUD Operations ====================

  /// Creates a new category in storage.
  /// 
  /// [category] - The category to create.
  /// 
  /// Returns the created category (potentially with updated fields).
  /// 
  /// Throws [StorageException] if creation fails or category already exists.
  Future<Category> createCategory(Category category);

  /// Retrieves a category by its ID.
  /// 
  /// [id] - The unique identifier of the category.
  /// 
  /// Returns the category if found, `null` if not found.
  /// 
  /// Throws [StorageException] if retrieval fails.
  Future<Category?> getCategory(String id);

  /// Retrieves all categories from storage.
  /// 
  /// Returns a list of all categories, empty list if no categories exist.
  /// 
  /// Throws [StorageException] if retrieval fails.
  Future<List<Category>> getAllCategories();

  /// Updates an existing category in storage.
  /// 
  /// [category] - The category with updated fields.
  /// 
  /// Returns the updated category.
  /// 
  /// Throws [StorageException] if update fails or category doesn't exist.
  Future<Category> updateCategory(Category category);

  /// Deletes a category from storage.
  /// 
  /// [id] - The unique identifier of the category to delete.
  /// 
  /// Returns `true` if deletion was successful, `false` if category doesn't exist.
  /// 
  /// Throws [StorageException] if deletion fails.
  Future<bool> deleteCategory(String id);

  /// Deletes all categories from storage.
  /// 
  /// Returns the number of categories deleted.
  /// 
  /// Throws [StorageException] if deletion fails.
  Future<int> deleteAllCategories();

  // ==================== Error Handling ====================

  /// Checks if the storage service is initialized and ready for operations.
  /// 
  /// Returns `true` if initialized, `false` otherwise.
  bool get isInitialized;

  /// Handles storage errors and converts them to [StorageException].
  /// 
  /// This method can be used by implementations to standardize error handling.
  /// 
  /// [error] - The error that occurred.
  /// [operation] - The operation that failed (e.g., 'createNote', 'updateCategory').
  /// 
  /// Returns a [StorageException] with appropriate error details.
  StorageException handleError(dynamic error, String operation);
}

/// Exception class for storage-related errors.
/// 
/// This exception is thrown when storage operations fail.
class StorageException implements Exception {
  /// The error message describing what went wrong.
  final String message;

  /// The operation that failed (e.g., 'createNote', 'updateCategory').
  final String operation;

  /// The underlying error, if any.
  final dynamic originalError;

  /// Creates a new [StorageException].
  /// 
  /// [message] - The error message.
  /// [operation] - The operation that failed.
  /// [originalError] - The underlying error, if any.
  StorageException({
    required this.message,
    required this.operation,
    this.originalError,
  });

  @override
  String toString() {
    final buffer = StringBuffer('StorageException: $message');
    buffer.write(' (Operation: $operation)');
    if (originalError != null) {
      buffer.write(' (Original error: $originalError)');
    }
    return buffer.toString();
  }
}
