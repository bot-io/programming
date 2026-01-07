import 'package:flutter/material.dart';
import 'package:simplenotes/models/category.dart';
import 'package:simplenotes/services/category_service.dart';

/// CategoryProvider manages category state using the Provider pattern.
/// 
/// This provider implements reactive state management for categories with methods
/// to create, update, delete, and retrieve categories. It handles loading and error states.
class CategoryProvider with ChangeNotifier {
  /// The category service used for business logic operations.
  final CategoryService _categoryService;

  /// List of all categories currently loaded in memory.
  List<Category> _categories = [];

  /// Current loading state.
  bool _isLoading = false;

  /// Current error message, if any.
  String? _error;

  /// Creates a new [CategoryProvider] instance.
  /// 
  /// [categoryService] - The category service to use for operations.
  CategoryProvider(this._categoryService);

  /// Gets the current list of categories.
  List<Category> get categories => List.unmodifiable(_categories);

  /// Gets the current loading state.
  bool get isLoading => _isLoading;

  /// Gets the current error message, if any.
  String? get error => _error;

  /// Checks if there's an error.
  bool get hasError => _error != null;

  /// Gets the count of categories.
  int get categoryCount => _categories.length;

  /// Checks if there are no categories.
  bool get isEmpty => _categories.isEmpty;

  /// Loads all categories from storage.
  /// 
  /// This method retrieves all categories and updates the internal state.
  /// It handles loading and error states.
  /// 
  /// [sortByName] - If true, sorts categories by name; otherwise sorts by creation date.
  /// 
  /// Throws [StorageException] if the operation fails.
  Future<void> loadCategories({bool sortByName = false}) async {
    _setLoading(true);
    _clearError();

    try {
      if (sortByName) {
        _categories = await _categoryService.getAllCategoriesSortedByName();
      } else {
        _categories = await _categoryService.getAllCategories();
      }

      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setLoading(false);
      _setError('Failed to load categories: ${e.toString()}');
      rethrow;
    }
  }

  /// Creates a new category.
  /// 
  /// [name] - The name of the category (required).
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
    _setLoading(true);
    _clearError();

    try {
      final category = await _categoryService.createCategory(
        name: name,
        color: color,
      );

      // Reload categories to get updated list
      await loadCategories();

      _setLoading(false);
      notifyListeners();
      return category;
    } catch (e) {
      _setLoading(false);
      _setError('Failed to create category: ${e.toString()}');
      rethrow;
    }
  }

  /// Updates an existing category.
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
    _setLoading(true);
    _clearError();

    try {
      final updatedCategory = await _categoryService.updateCategory(
        categoryId: categoryId,
        name: name,
        color: color,
      );

      // Reload categories to get updated list
      await loadCategories();

      _setLoading(false);
      notifyListeners();
      return updatedCategory;
    } catch (e) {
      _setLoading(false);
      _setError('Failed to update category: ${e.toString()}');
      rethrow;
    }
  }

  /// Renames a category.
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
    _setLoading(true);
    _clearError();

    try {
      final updatedCategory = await _categoryService.renameCategory(
        categoryId: categoryId,
        newName: newName,
      );

      // Reload categories to get updated list
      await loadCategories();

      _setLoading(false);
      notifyListeners();
      return updatedCategory;
    } catch (e) {
      _setLoading(false);
      _setError('Failed to rename category: ${e.toString()}');
      rethrow;
    }
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
    _setLoading(true);
    _clearError();

    try {
      final updatedCategory = await _categoryService.updateCategoryColor(
        categoryId: categoryId,
        color: color,
      );

      // Reload categories to get updated list
      await loadCategories();

      _setLoading(false);
      notifyListeners();
      return updatedCategory;
    } catch (e) {
      _setLoading(false);
      _setError('Failed to update category color: ${e.toString()}');
      rethrow;
    }
  }

  /// Deletes a category by ID.
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
    _setLoading(true);
    _clearError();

    try {
      final reassignedCount = await _categoryService.deleteCategory(
        categoryId: categoryId,
        reassignToCategoryId: reassignToCategoryId,
      );

      // Reload categories to get updated list
      await loadCategories();

      _setLoading(false);
      notifyListeners();
      return reassignedCount;
    } catch (e) {
      _setLoading(false);
      _setError('Failed to delete category: ${e.toString()}');
      rethrow;
    }
  }

  /// Retrieves a single category by ID.
  /// 
  /// [categoryId] - The ID of the category to retrieve.
  /// 
  /// Returns the category if found, `null` if not found.
  /// 
  /// Throws [StorageException] if retrieval fails.
  Future<Category?> getCategory(String categoryId) async {
    _clearError();

    try {
      return await _categoryService.getCategory(categoryId);
    } catch (e) {
      _setError('Failed to retrieve category: ${e.toString()}');
      rethrow;
    }
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
    _setLoading(true);
    _clearError();

    try {
      final defaultCategories = await _categoryService.initializeDefaultCategories();

      // Reload categories to get updated list
      await loadCategories();

      _setLoading(false);
      notifyListeners();
      return defaultCategories;
    } catch (e) {
      _setLoading(false);
      _setError('Failed to initialize default categories: ${e.toString()}');
      rethrow;
    }
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
    _clearError();

    try {
      return await _categoryService.categoryNameExists(
        name: name,
        excludeCategoryId: excludeCategoryId,
      );
    } catch (e) {
      _setError('Failed to check category name: ${e.toString()}');
      rethrow;
    }
  }

  /// Gets the count of notes assigned to a category.
  /// 
  /// [categoryId] - The ID of the category.
  /// 
  /// Returns the number of notes assigned to the category.
  /// 
  /// Throws [StorageException] if retrieval fails.
  Future<int> getNoteCount(String categoryId) async {
    _clearError();

    try {
      return await _categoryService.getNoteCount(categoryId);
    } catch (e) {
      _setError('Failed to get note count: ${e.toString()}');
      rethrow;
    }
  }

  /// Clears the current error state.
  void clearError() {
    _clearError();
    notifyListeners();
  }

  /// Refreshes the categories list by reloading from storage.
  Future<void> refresh() async {
    await loadCategories();
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
