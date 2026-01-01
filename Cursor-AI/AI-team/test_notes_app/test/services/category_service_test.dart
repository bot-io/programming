import 'package:flutter_test/flutter_test.dart';
import 'package:simplenotes/models/category.dart';
import 'package:simplenotes/models/note.dart';
import 'package:simplenotes/services/category_service.dart';
import 'package:simplenotes/services/storage_service.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

@GenerateMocks([StorageService])
import 'category_service_test.mocks.dart';

void main() {
  late CategoryService categoryService;
  late MockStorageService mockStorageService;

  setUp(() {
    mockStorageService = MockStorageService();
    categoryService = CategoryService(mockStorageService);
  });

  group('CategoryService - Create Operations', () {
    test('should create a category successfully', () async {
      final now = DateTime.now();
      final category = Category(
        id: 'category-1',
        name: 'Test Category',
        createdAt: now,
      );

      when(mockStorageService.getAllCategories())
          .thenAnswer((_) async => []);
      when(mockStorageService.createCategory(any))
          .thenAnswer((_) async => category);

      final result = await categoryService.createCategory(name: 'Test Category');

      expect(result, isNotNull);
      expect(result.name, 'Test Category');
      verify(mockStorageService.createCategory(any)).called(1);
    });

    test('should create a category with color', () async {
      final now = DateTime.now();
      final category = Category(
        id: 'category-1',
        name: 'Colored Category',
        color: '#4285F4',
        createdAt: now,
      );

      when(mockStorageService.getAllCategories())
          .thenAnswer((_) async => []);
      when(mockStorageService.createCategory(any))
          .thenAnswer((_) async => category);

      final result = await categoryService.createCategory(
        name: 'Colored Category',
        color: '#4285F4',
      );

      expect(result.color, '#4285F4');
      verify(mockStorageService.createCategory(any)).called(1);
    });

    test('should throw error when creating category with empty name', () async {
      expect(
        () => categoryService.createCategory(name: ''),
        throwsA(isA<ArgumentError>()),
      );
      verifyNever(mockStorageService.createCategory(any));
    });

    test('should throw error when creating category with whitespace-only name', () async {
      expect(
        () => categoryService.createCategory(name: '   '),
        throwsA(isA<ArgumentError>()),
      );
      verifyNever(mockStorageService.createCategory(any));
    });

    test('should throw error when category name already exists', () async {
      final now = DateTime.now();
      final existingCategory = Category(
        id: 'category-1',
        name: 'Existing Category',
        createdAt: now,
      );

      when(mockStorageService.getAllCategories())
          .thenAnswer((_) async => [existingCategory]);

      expect(
        () => categoryService.createCategory(name: 'Existing Category'),
        throwsA(isA<StorageException>()),
      );
      verifyNever(mockStorageService.createCategory(any));
    });

    test('should handle storage error during category creation', () async {
      when(mockStorageService.getAllCategories())
          .thenAnswer((_) async => []);
      when(mockStorageService.createCategory(any))
          .thenThrow(StorageException(message: 'Storage error', operation: 'createCategory'));

      expect(
        () => categoryService.createCategory(name: 'Test Category'),
        throwsA(isA<StorageException>()),
      );
    });
  });

  group('CategoryService - Read Operations', () {
    test('should get a category by id', () async {
      final now = DateTime.now();
      final category = Category(
        id: 'category-1',
        name: 'Test Category',
        createdAt: now,
      );

      when(mockStorageService.getCategory('category-1'))
          .thenAnswer((_) async => category);

      final result = await categoryService.getCategory('category-1');

      expect(result, isNotNull);
      expect(result!.id, 'category-1');
      expect(result.name, 'Test Category');
      verify(mockStorageService.getCategory('category-1')).called(1);
    });

    test('should return null when category does not exist', () async {
      when(mockStorageService.getCategory('non-existent'))
          .thenAnswer((_) async => null);

      final result = await categoryService.getCategory('non-existent');

      expect(result, isNull);
      verify(mockStorageService.getCategory('non-existent')).called(1);
    });

    test('should get all categories', () async {
      final now = DateTime.now();
      final categories = [
        Category(
          id: 'category-1',
          name: 'Category 1',
          createdAt: now,
        ),
        Category(
          id: 'category-2',
          name: 'Category 2',
          createdAt: now.add(const Duration(hours: 1)),
        ),
      ];

      when(mockStorageService.getAllCategories())
          .thenAnswer((_) async => categories);

      final result = await categoryService.getAllCategories();

      expect(result, hasLength(2));
      expect(result[0].name, 'Category 1');
      expect(result[1].name, 'Category 2');
      verify(mockStorageService.getAllCategories()).called(1);
    });

    test('should return empty list when no categories exist', () async {
      when(mockStorageService.getAllCategories())
          .thenAnswer((_) async => []);

      final result = await categoryService.getAllCategories();

      expect(result, isEmpty);
      verify(mockStorageService.getAllCategories()).called(1);
    });

    test('should get all categories sorted by name', () async {
      final now = DateTime.now();
      final categories = [
        Category(
          id: 'category-1',
          name: 'Zebra Category',
          createdAt: now,
        ),
        Category(
          id: 'category-2',
          name: 'Apple Category',
          createdAt: now.add(const Duration(hours: 1)),
        ),
        Category(
          id: 'category-3',
          name: 'Banana Category',
          createdAt: now,
        ),
      ];

      when(mockStorageService.getAllCategories())
          .thenAnswer((_) async => categories);

      final result = await categoryService.getAllCategoriesSortedByName();

      expect(result, hasLength(3));
      expect(result[0].name, 'Apple Category');
      expect(result[1].name, 'Banana Category');
      expect(result[2].name, 'Zebra Category');
    });
  });

  group('CategoryService - Update Operations', () {
    test('should update category name successfully', () async {
      final now = DateTime.now();
      final originalCategory = Category(
        id: 'category-1',
        name: 'Original Name',
        createdAt: now,
      );
      final updatedCategory = Category(
        id: 'category-1',
        name: 'Updated Name',
        createdAt: now,
      );

      when(mockStorageService.getCategory('category-1'))
          .thenAnswer((_) async => originalCategory);
      when(mockStorageService.getAllCategories())
          .thenAnswer((_) async => [originalCategory]);
      when(mockStorageService.updateCategory(any))
          .thenAnswer((_) async => updatedCategory);

      final result = await categoryService.updateCategory(
        categoryId: 'category-1',
        name: 'Updated Name',
      );

      expect(result.name, 'Updated Name');
      verify(mockStorageService.updateCategory(any)).called(1);
    });

    test('should update category color', () async {
      final now = DateTime.now();
      final originalCategory = Category(
        id: 'category-1',
        name: 'Category',
        color: '#4285F4',
        createdAt: now,
      );
      final updatedCategory = Category(
        id: 'category-1',
        name: 'Category',
        color: '#34A853',
        createdAt: now,
      );

      when(mockStorageService.getCategory('category-1'))
          .thenAnswer((_) async => originalCategory);
      when(mockStorageService.updateCategory(any))
          .thenAnswer((_) async => updatedCategory);

      final result = await categoryService.updateCategoryColor(
        categoryId: 'category-1',
        color: '#34A853',
      );

      expect(result.color, '#34A853');
      verify(mockStorageService.updateCategory(any)).called(1);
    });

    test('should update both name and color', () async {
      final now = DateTime.now();
      final originalCategory = Category(
        id: 'category-1',
        name: 'Original Name',
        color: '#4285F4',
        createdAt: now,
      );
      final updatedCategory = Category(
        id: 'category-1',
        name: 'Updated Name',
        color: '#34A853',
        createdAt: now,
      );

      when(mockStorageService.getCategory('category-1'))
          .thenAnswer((_) async => originalCategory);
      when(mockStorageService.getAllCategories())
          .thenAnswer((_) async => [originalCategory]);
      when(mockStorageService.updateCategory(any))
          .thenAnswer((_) async => updatedCategory);

      final result = await categoryService.updateCategory(
        categoryId: 'category-1',
        name: 'Updated Name',
        color: '#34A853',
      );

      expect(result.name, 'Updated Name');
      expect(result.color, '#34A853');
      verify(mockStorageService.updateCategory(any)).called(1);
    });

    test('should rename category using renameCategory method', () async {
      final now = DateTime.now();
      final originalCategory = Category(
        id: 'category-1',
        name: 'Original Name',
        createdAt: now,
      );
      final updatedCategory = Category(
        id: 'category-1',
        name: 'New Name',
        createdAt: now,
      );

      when(mockStorageService.getCategory('category-1'))
          .thenAnswer((_) async => originalCategory);
      when(mockStorageService.getAllCategories())
          .thenAnswer((_) async => [originalCategory]);
      when(mockStorageService.updateCategory(any))
          .thenAnswer((_) async => updatedCategory);

      final result = await categoryService.renameCategory(
        categoryId: 'category-1',
        newName: 'New Name',
      );

      expect(result.name, 'New Name');
      verify(mockStorageService.updateCategory(any)).called(1);
    });

    test('should throw error when updating non-existent category', () async {
      when(mockStorageService.getCategory('non-existent'))
          .thenAnswer((_) async => null);

      expect(
        () => categoryService.updateCategory(categoryId: 'non-existent', name: 'New Name'),
        throwsA(isA<StorageException>()),
      );
      verifyNever(mockStorageService.updateCategory(any));
    });

    test('should throw error when updating with empty name', () async {
      final now = DateTime.now();
      final category = Category(
        id: 'category-1',
        name: 'Category',
        createdAt: now,
      );

      when(mockStorageService.getCategory('category-1'))
          .thenAnswer((_) async => category);

      expect(
        () => categoryService.updateCategory(categoryId: 'category-1', name: ''),
        throwsA(isA<ArgumentError>()),
      );
      verifyNever(mockStorageService.updateCategory(any));
    });

    test('should throw error when new name already exists', () async {
      final now = DateTime.now();
      final category1 = Category(
        id: 'category-1',
        name: 'Category 1',
        createdAt: now,
      );
      final category2 = Category(
        id: 'category-2',
        name: 'Category 2',
        createdAt: now,
      );

      when(mockStorageService.getCategory('category-1'))
          .thenAnswer((_) async => category1);
      when(mockStorageService.getAllCategories())
          .thenAnswer((_) async => [category1, category2]);

      expect(
        () => categoryService.updateCategory(categoryId: 'category-1', name: 'Category 2'),
        throwsA(isA<StorageException>()),
      );
      verifyNever(mockStorageService.updateCategory(any));
    });

    test('should handle storage error during category update', () async {
      final now = DateTime.now();
      final category = Category(
        id: 'category-1',
        name: 'Category',
        createdAt: now,
      );

      when(mockStorageService.getCategory('category-1'))
          .thenAnswer((_) async => category);
      when(mockStorageService.getAllCategories())
          .thenAnswer((_) async => [category]);
      when(mockStorageService.updateCategory(any))
          .thenThrow(StorageException(message: 'Storage error', operation: 'updateCategory'));

      expect(
        () => categoryService.updateCategory(categoryId: 'category-1', name: 'New Name'),
        throwsA(isA<StorageException>()),
      );
    });
  });

  group('CategoryService - Delete Operations', () {
    test('should delete a category successfully', () async {
      final now = DateTime.now();
      final category = Category(
        id: 'category-1',
        name: 'Category',
        createdAt: now,
      );

      when(mockStorageService.getCategory('category-1'))
          .thenAnswer((_) async => category);
      when(mockStorageService.getNotesByCategory('category-1'))
          .thenAnswer((_) async => []);
      when(mockStorageService.deleteCategory('category-1'))
          .thenAnswer((_) async => true);

      final result = await categoryService.deleteCategory(categoryId: 'category-1');

      expect(result, equals(0));
      verify(mockStorageService.deleteCategory('category-1')).called(1);
    });

    test('should reassign notes to null when deleting category', () async {
      final now = DateTime.now();
      final category = Category(
        id: 'category-1',
        name: 'Category',
        createdAt: now,
      );
      final note1 = Note(
        id: 'note-1',
        title: 'Note 1',
        content: 'Content 1',
        categoryId: 'category-1',
        createdAt: now,
        updatedAt: now,
      );
      final note2 = Note(
        id: 'note-2',
        title: 'Note 2',
        content: 'Content 2',
        categoryId: 'category-1',
        createdAt: now,
        updatedAt: now,
      );
      final note3 = Note(
        id: 'note-3',
        title: 'Note 3',
        content: 'Content 3',
        categoryId: 'category-2',
        createdAt: now,
        updatedAt: now,
      );

      when(mockStorageService.getCategory('category-1'))
          .thenAnswer((_) async => category);
      when(mockStorageService.getNotesByCategory('category-1'))
          .thenAnswer((_) async => [note1, note2]);
      when(mockStorageService.updateNote(any))
          .thenAnswer((_) async => note1.copyWith(categoryId: null));
      when(mockStorageService.deleteCategory('category-1'))
          .thenAnswer((_) async => true);

      final result = await categoryService.deleteCategory(categoryId: 'category-1');

      expect(result, equals(2));
      verify(mockStorageService.updateNote(any)).called(2);
      verify(mockStorageService.deleteCategory('category-1')).called(1);
    });

    test('should reassign notes to another category', () async {
      final now = DateTime.now();
      final category1 = Category(
        id: 'category-1',
        name: 'Category 1',
        createdAt: now,
      );
      final category2 = Category(
        id: 'category-2',
        name: 'Category 2',
        createdAt: now,
      );
      final note1 = Note(
        id: 'note-1',
        title: 'Note 1',
        content: 'Content 1',
        categoryId: 'category-1',
        createdAt: now,
        updatedAt: now,
      );

      when(mockStorageService.getCategory('category-1'))
          .thenAnswer((_) async => category1);
      when(mockStorageService.getCategory('category-2'))
          .thenAnswer((_) async => category2);
      when(mockStorageService.getNotesByCategory('category-1'))
          .thenAnswer((_) async => [note1]);
      when(mockStorageService.updateNote(any))
          .thenAnswer((_) async => note1.copyWith(categoryId: 'category-2'));
      when(mockStorageService.deleteCategory('category-1'))
          .thenAnswer((_) async => true);

      final result = await categoryService.deleteCategory(
        categoryId: 'category-1',
        reassignToCategoryId: 'category-2',
      );

      expect(result, equals(1));
      verify(mockStorageService.updateNote(any)).called(1);
      verify(mockStorageService.deleteCategory('category-1')).called(1);
    });

    test('should throw error when deleting non-existent category', () async {
      when(mockStorageService.getCategory('non-existent'))
          .thenAnswer((_) async => null);

      expect(
        () => categoryService.deleteCategory(categoryId: 'non-existent'),
        throwsA(isA<StorageException>()),
      );
      verifyNever(mockStorageService.deleteCategory(any));
    });

    test('should throw error when reassigning to non-existent category', () async {
      final now = DateTime.now();
      final category = Category(
        id: 'category-1',
        name: 'Category',
        createdAt: now,
      );

      when(mockStorageService.getCategory('category-1'))
          .thenAnswer((_) async => category);
      when(mockStorageService.getCategory('non-existent'))
          .thenAnswer((_) async => null);

      expect(
        () => categoryService.deleteCategory(
          categoryId: 'category-1',
          reassignToCategoryId: 'non-existent',
        ),
        throwsA(isA<StorageException>()),
      );
      verifyNever(mockStorageService.deleteCategory(any));
    });

    test('should handle storage error during category deletion', () async {
      final now = DateTime.now();
      final category = Category(
        id: 'category-1',
        name: 'Category',
        createdAt: now,
      );

      when(mockStorageService.getCategory('category-1'))
          .thenAnswer((_) async => category);
      when(mockStorageService.getNotesByCategory('category-1'))
          .thenAnswer((_) async => []);
      when(mockStorageService.deleteCategory('category-1'))
          .thenThrow(StorageException(message: 'Storage error', operation: 'deleteCategory'));

      expect(
        () => categoryService.deleteCategory(categoryId: 'category-1'),
        throwsA(isA<StorageException>()),
      );
    });
  });

  group('CategoryService - Default Categories', () {
    test('should initialize default categories when none exist', () async {
      when(mockStorageService.getAllCategories())
          .thenAnswer((_) async => []);

      final now = DateTime.now();
      final defaultCategory1 = Category(
        id: 'default-1',
        name: 'Personal',
        color: '#2196F3',
        createdAt: now,
      );
      final defaultCategory2 = Category(
        id: 'default-2',
        name: 'Work',
        color: '#FF9800',
        createdAt: now,
      );

      when(mockStorageService.createCategory(any))
          .thenAnswer((_) async => defaultCategory1);

      final result = await categoryService.initializeDefaultCategories();

      expect(result, isNotEmpty);
      verify(mockStorageService.createCategory(any)).called(greaterThan(0));
    });

    test('should not initialize default categories when they already exist', () async {
      final now = DateTime.now();
      final existingCategory = Category(
        id: 'category-1',
        name: 'Personal',
        createdAt: now,
      );

      when(mockStorageService.getAllCategories())
          .thenAnswer((_) async => [existingCategory]);

      final result = await categoryService.initializeDefaultCategories();

      expect(result, equals([existingCategory]));
      verifyNever(mockStorageService.createCategory(any));
    });

    test('should handle storage error during default categories initialization', () async {
      when(mockStorageService.getAllCategories())
          .thenThrow(StorageException(message: 'Storage error', operation: 'getAllCategories'));

      expect(
        () => categoryService.initializeDefaultCategories(),
        throwsA(isA<StorageException>()),
      );
    });
  });

  group('CategoryService - Validation and Utilities', () {
    test('should check if category name exists', () async {
      final now = DateTime.now();
      final categories = [
        Category(
          id: 'category-1',
          name: 'Existing Category',
          createdAt: now,
        ),
      ];

      when(mockStorageService.getAllCategories())
          .thenAnswer((_) async => categories);

      final exists = await categoryService.categoryNameExists(name: 'Existing Category');
      final notExists = await categoryService.categoryNameExists(name: 'New Category');

      expect(exists, isTrue);
      expect(notExists, isFalse);
    });

    test('should exclude category from name existence check', () async {
      final now = DateTime.now();
      final categories = [
        Category(
          id: 'category-1',
          name: 'Category',
          createdAt: now,
        ),
      ];

      when(mockStorageService.getAllCategories())
          .thenAnswer((_) async => categories);

      final exists = await categoryService.categoryNameExists(
        name: 'Category',
        excludeCategoryId: 'category-1',
      );

      expect(exists, isFalse);
    });

    test('should get note count for category', () async {
      final now = DateTime.now();
      final notes = [
        Note(
          id: 'note-1',
          title: 'Note 1',
          content: 'Content 1',
          categoryId: 'category-1',
          createdAt: now,
          updatedAt: now,
        ),
        Note(
          id: 'note-2',
          title: 'Note 2',
          content: 'Content 2',
          categoryId: 'category-1',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      when(mockStorageService.getNotesByCategory('category-1'))
          .thenAnswer((_) async => notes);

      final count = await categoryService.getNoteCount('category-1');

      expect(count, equals(2));
    });
  });
}
