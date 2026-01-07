import 'dart:math';
import 'package:simplenotes/models/category.dart';
import 'package:simplenotes/models/note.dart';
import 'package:simplenotes/services/storage_service.dart';

/// Service class for managing category business logic.
/// 
/// This service provides high-level operations for category management,
/// including validation, default category initialization, and note reassignment
/// when categories are deleted.
class CategoryService {
  /// The storage service used for persistence
  final StorageService _storageService;

  /// Random number generator for ID generation
  final Random _random = Random();

  /// Creates a new [CategoryService] instance.
  /// 
  /// [storageService] - The storage service to use for persistence.
  CategoryService(this._storageService);

  /// Validates a category name.
  /// 
  /// [name] - The category name to validate.
  /// 
  /// Returns a list of validation error messages, empty if valid.
  List<String> _validateCategoryName(String name) {
    final errors = <String>[];

    if (name.isEmpty) {
      errors.add('Category name cannot be empty');
    } else if (name.trim().isEmpty) {
      errors.add('Category name cannot be whitespace only');
    } else if (name.length > 100) {
      errors.add('Category name cannot exceed 100 characters');
    }

    return errors;
  }

  /// Generates a unique category ID.
  /// 
  /// Returns a unique string ID.
  String _generateCategoryId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = _random.nextInt(10000);
    return 'cat_${timestamp}_$random';
  }

  /// Creates a new category with name validation.
  /// 
  /// [name] - The category name (required, must be non-empty and trimmed).
  /// [color] - Optional color in hex format (e.g., #RRGGBB or #AARRGGBB).
  /// 
  /// Returns the created category.
  /// 
  /// Throws [ArgumentError] if name validation fails.
  /// Throws [StorageException] if creation fails or category with same name exists.
  Future<Category> createCategory({
    required String name,
    String? color,
  }) async {
    // Validate name
    final trimmedName = name.trim();
    final validationErrors = _validateCategoryName(trimmedName);
    if (validationErrors.isNotEmpty) {
      throw ArgumentError(validationErrors.join(', '));
    }

    // Check for duplicate names (case-insensitive)
    final existingCategories = await _storageService.getAllCategories();
    final hasDuplicate = existingCategories.any(
      (cat) => cat.name.trim().toLowerCase() == trimmedName.toLowerCase(),
    );

    if (hasDuplicate) {
      throw StorageException(
        message: 'Category with name "$trimmedName" already exists',
        operation: 'createCategory',
      );
    }

    // Generate ID and create category
    final id = _generateCategoryId();
    final category = Category(
      id: id,
      name: trimmedName,
      color: color,
      createdAt: DateTime.now(),
    );

    // Save to storage
    return await _storageService.createCategory(category);
  }

  /// Updates a category's name (rename).
  /// 
  /// [categoryId] - The ID of the category to rename.
  /// [newName] - The new name for the category.
  /// 
  /// Returns the updated category.
  /// 
  /// Throws [ArgumentError] if name validation fails.
  /// Throws [StorageException] if category doesn't exist or update fails.
  Future<Category> renameCategory({
    required String categoryId,
    required String newName,
  }) async {
    // Validate new name
    final trimmedName = newName.trim();
    final validationErrors = _validateCategoryName(trimmedName);
    if (validationErrors.isNotEmpty) {
      throw ArgumentError(validationErrors.join(', '));
    }

    // Get existing category
    final category = await _storageService.getCategory(categoryId);
    if (category == null) {
      throw StorageException(
        message: 'Category with id "$categoryId" does not exist',
        operation: 'renameCategory',
      );
    }

    // Check for duplicate names (excluding current category)
    final existingCategories = await _storageService.getAllCategories();
    final hasDuplicate = existingCategories.any(
      (cat) =>
          cat.id != categoryId &&
          cat.name.trim().toLowerCase() == trimmedName.toLowerCase(),
    );

    if (hasDuplicate) {
      throw StorageException(
        message: 'Category with name "$trimmedName" already exists',
        operation: 'renameCategory',
      );
    }

    // Update category
    final updatedCategory = category.copyWith(name: trimmedName);
    return await _storageService.updateCategory(updatedCategory);
  }

  /// Updates a category's color.
  /// 
  /// [categoryId] - The ID of the category to update.
  /// [color] - The new color in hex format (e.g., #RRGGBB or #AARRGGBB).
  ///           Pass null to remove the color.
  /// 
  /// Returns the updated category.
  /// 
  /// Throws [StorageException] if category doesn't exist or update fails.
  Future<Category> updateCategoryColor({
    required String categoryId,
    String? color,
  }) async {
    // Get existing category
    final category = await _storageService.getCategory(categoryId);
    if (category == null) {
      throw StorageException(
        message: 'Category with id "$categoryId" does not exist',
        operation: 'updateCategoryColor',
      );
    }

    // Update category color
    final updatedCategory = category.copyWith(color: color);
    return await _storageService.updateCategory(updatedCategory);
  }

  /// Updates a category (rename and/or change color).
  /// 
  /// [categoryId] - The ID of the category to update.
  /// [name] - Optional new name for the category.
  /// [color] - Optional new color for the category. Pass null to remove color.
  /// 
  /// Returns the updated category.
  /// 
  /// Throws [ArgumentError] if name validation fails.
  /// Throws [StorageException] if category doesn't exist or update fails.
  Future<Category> updateCategory({
    required String categoryId,
    String? name,
    String? color,
  }) async {
    // Get existing category
    final category = await _storageService.getCategory(categoryId);
    if (category == null) {
      throw StorageException(
        message: 'Category with id "$categoryId" does not exist',
        operation: 'updateCategory',
      );
    }

    // Validate name if provided
    String? trimmedName;
    if (name != null) {
      trimmedName = name.trim();
      final validationErrors = _validateCategoryName(trimmedName);
      if (validationErrors.isNotEmpty) {
        throw ArgumentError(validationErrors.join(', '));
      }

      // Check for duplicate names (excluding current category)
      final existingCategories = await _storageService.getAllCategories();
      final hasDuplicate = existingCategories.any(
        (cat) =>
            cat.id != categoryId &&
            cat.name.trim().toLowerCase() == trimmedName.toLowerCase(),
      );

      if (hasDuplicate) {
        throw StorageException(
          message: 'Category with name "$trimmedName" already exists',
          operation: 'updateCategory',
        );
      }
    }

    // Update category
    final updatedCategory = category.copyWith(
      name: trimmedName ?? category.name,
      color: color,
    );
    return await _storageService.updateCategory(updatedCategory);
  }

  /// Deletes a category and reassigns its notes to another category or removes category assignment.
  /// 
  /// [categoryId] - The ID of the category to delete.
  /// [reassignToCategoryId] - Optional ID of category to reassign notes to.
  ///                          If null, notes will have their categoryId set to null.
  /// 
  /// Returns the number of notes that were reassigned.
  /// 
  /// Throws [StorageException] if category doesn't exist, deletion fails, or reassignment fails.
  Future<int> deleteCategory({
    required String categoryId,
    String? reassignToCategoryId,
  }) async {
    // Verify category exists
    final category = await _storageService.getCategory(categoryId);
    if (category == null) {
      throw StorageException(
        message: 'Category with id "$categoryId" does not exist',
        operation: 'deleteCategory',
      );
    }

    // If reassigning to another category, verify it exists
    if (reassignToCategoryId != null) {
      final targetCategory = await _storageService.getCategory(reassignToCategoryId);
      if (targetCategory == null) {
        throw StorageException(
          message: 'Target category with id "$reassignToCategoryId" does not exist',
          operation: 'deleteCategory',
        );
      }
    }

    // Get all notes with this category
    final notesToReassign = await _storageService.getNotesByCategory(categoryId);
    int reassignedCount = 0;

    // Reassign notes
    for (final note in notesToReassign) {
      final updatedNote = note.copyWith(categoryId: reassignToCategoryId);
      await _storageService.updateNote(updatedNote);
      reassignedCount++;
    }

    // Delete the category
    await _storageService.deleteCategory(categoryId);

    return reassignedCount;
  }

  /// Retrieves a category by its ID.
  /// 
  /// [categoryId] - The ID of the category to retrieve.
  /// 
  /// Returns the category if found, null otherwise.
  /// 
  /// Throws [StorageException] if retrieval fails.
  Future<Category?> getCategory(String categoryId) async {
    return await _storageService.getCategory(categoryId);
  }

  /// Retrieves all categories.
  /// 
  /// Returns a list of all categories, sorted by creation date (oldest first).
  /// 
  /// Throws [StorageException] if retrieval fails.
  Future<List<Category>> getAllCategories() async {
    final categories = await _storageService.getAllCategories();
    categories.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return categories;
  }

  /// Retrieves all categories sorted by name (case-insensitive).
  /// 
  /// Returns a list of all categories, sorted alphabetically by name.
  /// 
  /// Throws [StorageException] if retrieval fails.
  Future<List<Category>> getAllCategoriesSortedByName() async {
    final categories = await _storageService.getAllCategories();
    categories.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return categories;
  }

  /// Initializes default categories if none exist.
  /// 
  /// Creates default categories: "Personal", "Work", "Ideas", "Tasks".
  /// Only creates categories if no categories currently exist.
  /// 
  /// Returns the list of created default categories.
  /// 
  /// Throws [StorageException] if initialization fails.
  Future<List<Category>> initializeDefaultCategories() async {
    // Check if categories already exist
    final existingCategories = await _storageService.getAllCategories();
    if (existingCategories.isNotEmpty) {
      return existingCategories;
    }

    // Define default categories
    final defaultCategoriesData = [
      {'name': 'Personal', 'color': '#2196F3'}, // Blue
      {'name': 'Work', 'color': '#FF9800'}, // Orange
      {'name': 'Ideas', 'color': '#9C27B0'}, // Purple
      {'name': 'Tasks', 'color': '#4CAF50'}, // Green
    ];

    final createdCategories = <Category>[];

    // Create each default category
    for (final categoryData in defaultCategoriesData) {
      try {
        final category = await createCategory(
          name: categoryData['name'] as String,
          color: categoryData['color'] as String,
        );
        createdCategories.add(category);
      } catch (e) {
        // If creation fails, log but continue with other categories
        // This ensures we create as many defaults as possible
        if (e is StorageException) {
          rethrow;
        }
      }
    }

    return createdCategories;
  }

  /// Checks if a category name already exists (case-insensitive).
  /// 
  /// [name] - The category name to check.
  /// [excludeCategoryId] - Optional category ID to exclude from the check.
  /// 
  /// Returns true if a category with the name exists, false otherwise.
  /// 
  /// Throws [StorageException] if retrieval fails.
  Future<bool> categoryNameExists({
    required String name,
    String? excludeCategoryId,
  }) async {
    final trimmedName = name.trim().toLowerCase();
    final categories = await _storageService.getAllCategories();
    
    return categories.any((cat) =>
        cat.id != excludeCategoryId &&
        cat.name.trim().toLowerCase() == trimmedName);
  }

  /// Gets the count of notes assigned to a category.
  /// 
  /// [categoryId] - The ID of the category.
  /// 
  /// Returns the number of notes assigned to the category.
  /// 
  /// Throws [StorageException] if retrieval fails.
  Future<int> getNoteCount(String categoryId) async {
    final notes = await _storageService.getNotesByCategory(categoryId);
    return notes.length;
  }
}
