import 'package:hive_flutter/hive_flutter.dart';
import 'package:simplenotes/models/note.dart';
import 'package:simplenotes/models/category.dart';
import 'package:simplenotes/services/storage_service.dart';

/// Hive-based implementation of [StorageService].
/// 
/// This service uses Hive boxes to store notes and categories locally.
/// It provides persistent storage that survives app restarts.
class HiveStorageService extends StorageService {
  /// Box name for storing notes
  static const String _notesBoxName = 'notes';

  /// Box name for storing categories
  static const String _categoriesBoxName = 'categories';

  /// Hive box for notes
  Box<Note>? _notesBox;

  /// Hive box for categories
  Box<Category>? _categoriesBox;

  /// Whether the service has been initialized
  bool _initialized = false;

  @override
  bool get isInitialized => _initialized;

  @override
  Future<bool> initialize() async {
    if (_initialized) {
      return true;
    }

    try {
      // Initialize Hive for Flutter
      await Hive.initFlutter();

      // Register type adapters
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(NoteAdapter());
      }
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(CategoryAdapter());
      }

      // Open boxes
      _notesBox = await Hive.openBox<Note>(_notesBoxName);
      _categoriesBox = await Hive.openBox<Category>(_categoriesBoxName);

      _initialized = true;
      return true;
    } catch (e) {
      throw handleError(e, 'initialize');
    }
  }

  @override
  Future<void> close() async {
    if (!_initialized) {
      return;
    }

    try {
      await _notesBox?.close();
      await _categoriesBox?.close();
      _notesBox = null;
      _categoriesBox = null;
      _initialized = false;
    } catch (e) {
      throw handleError(e, 'close');
    }
  }

  /// Ensures the service is initialized before operations
  void _ensureInitialized() {
    if (!_initialized || _notesBox == null || _categoriesBox == null) {
      throw StorageException(
        message: 'Storage service is not initialized. Call initialize() first.',
        operation: 'operation',
      );
    }
  }

  // ==================== Note CRUD Operations ====================

  @override
  Future<Note> createNote(Note note) async {
    _ensureInitialized();

    try {
      // Validate note
      final validationErrors = note.validate();
      if (validationErrors.isNotEmpty) {
        throw StorageException(
          message: 'Note validation failed: ${validationErrors.join(", ")}',
          operation: 'createNote',
        );
      }

      // Check if note already exists
      if (_notesBox!.containsKey(note.id)) {
        throw StorageException(
          message: 'Note with id "${note.id}" already exists',
          operation: 'createNote',
        );
      }

      // Save note to box
      await _notesBox!.put(note.id, note);
      return note;
    } catch (e) {
      if (e is StorageException) {
        rethrow;
      }
      throw handleError(e, 'createNote');
    }
  }

  @override
  Future<Note?> getNote(String id) async {
    _ensureInitialized();

    try {
      return _notesBox!.get(id);
    } catch (e) {
      throw handleError(e, 'getNote');
    }
  }

  @override
  Future<List<Note>> getAllNotes() async {
    _ensureInitialized();

    try {
      return _notesBox!.values.toList();
    } catch (e) {
      throw handleError(e, 'getAllNotes');
    }
  }

  @override
  Future<List<Note>> getNotesByCategory(String categoryId) async {
    _ensureInitialized();

    try {
      return _notesBox!.values
          .where((note) => note.categoryId == categoryId)
          .toList();
    } catch (e) {
      throw handleError(e, 'getNotesByCategory');
    }
  }

  @override
  Future<Note> updateNote(Note note) async {
    _ensureInitialized();

    try {
      // Validate note
      final validationErrors = note.validate();
      if (validationErrors.isNotEmpty) {
        throw StorageException(
          message: 'Note validation failed: ${validationErrors.join(", ")}',
          operation: 'updateNote',
        );
      }

      // Check if note exists
      if (!_notesBox!.containsKey(note.id)) {
        throw StorageException(
          message: 'Note with id "${note.id}" does not exist',
          operation: 'updateNote',
        );
      }

      // Update updatedAt timestamp
      note.touch();

      // Save updated note
      await _notesBox!.put(note.id, note);
      return note;
    } catch (e) {
      if (e is StorageException) {
        rethrow;
      }
      throw handleError(e, 'updateNote');
    }
  }

  @override
  Future<bool> deleteNote(String id) async {
    _ensureInitialized();

    try {
      if (!_notesBox!.containsKey(id)) {
        return false;
      }

      await _notesBox!.delete(id);
      return true;
    } catch (e) {
      throw handleError(e, 'deleteNote');
    }
  }

  @override
  Future<int> deleteAllNotes() async {
    _ensureInitialized();

    try {
      final count = _notesBox!.length;
      await _notesBox!.clear();
      return count;
    } catch (e) {
      throw handleError(e, 'deleteAllNotes');
    }
  }

  // ==================== Category CRUD Operations ====================

  @override
  Future<Category> createCategory(Category category) async {
    _ensureInitialized();

    try {
      // Check if category already exists
      if (_categoriesBox!.containsKey(category.id)) {
        throw StorageException(
          message: 'Category with id "${category.id}" already exists',
          operation: 'createCategory',
        );
      }

      // Save category to box
      await _categoriesBox!.put(category.id, category);
      return category;
    } catch (e) {
      if (e is StorageException) {
        rethrow;
      }
      throw handleError(e, 'createCategory');
    }
  }

  @override
  Future<Category?> getCategory(String id) async {
    _ensureInitialized();

    try {
      return _categoriesBox!.get(id);
    } catch (e) {
      throw handleError(e, 'getCategory');
    }
  }

  @override
  Future<List<Category>> getAllCategories() async {
    _ensureInitialized();

    try {
      return _categoriesBox!.values.toList();
    } catch (e) {
      throw handleError(e, 'getAllCategories');
    }
  }

  @override
  Future<Category> updateCategory(Category category) async {
    _ensureInitialized();

    try {
      // Check if category exists
      if (!_categoriesBox!.containsKey(category.id)) {
        throw StorageException(
          message: 'Category with id "${category.id}" does not exist',
          operation: 'updateCategory',
        );
      }

      // Save updated category
      await _categoriesBox!.put(category.id, category);
      return category;
    } catch (e) {
      if (e is StorageException) {
        rethrow;
      }
      throw handleError(e, 'updateCategory');
    }
  }

  @override
  Future<bool> deleteCategory(String id) async {
    _ensureInitialized();

    try {
      if (!_categoriesBox!.containsKey(id)) {
        return false;
      }

      await _categoriesBox!.delete(id);
      return true;
    } catch (e) {
      throw handleError(e, 'deleteCategory');
    }
  }

  @override
  Future<int> deleteAllCategories() async {
    _ensureInitialized();

    try {
      final count = _categoriesBox!.length;
      await _categoriesBox!.clear();
      return count;
    } catch (e) {
      throw handleError(e, 'deleteAllCategories');
    }
  }

  // ==================== Error Handling ====================

  @override
  StorageException handleError(dynamic error, String operation) {
    String message;

    if (error is StorageException) {
      return error;
    } else if (error is HiveError) {
      message = 'Hive error: ${error.message}';
    } else if (error is Exception) {
      message = error.toString();
    } else {
      message = 'Unknown error: $error';
    }

    return StorageException(
      message: message,
      operation: operation,
      originalError: error,
    );
  }
}
