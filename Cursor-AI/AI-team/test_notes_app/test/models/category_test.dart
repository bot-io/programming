import 'package:flutter_test/flutter_test.dart';
import 'package:simplenotes/models/category.dart';

void main() {
  group('Category Model Tests', () {
    test('should create a Category with all required fields', () {
      final now = DateTime.now();
      final category = Category(
        id: 'category-id-1',
        name: 'Test Category',
        createdAt: now,
      );

      expect(category.id, 'category-id-1');
      expect(category.name, 'Test Category');
      expect(category.color, isNull);
      expect(category.createdAt, now);
    });

    test('should create a Category with optional color as hex string', () {
      final now = DateTime.now();
      final category = Category(
        id: 'category-id-2',
        name: 'Colored Category',
        color: '#4285F4',
        createdAt: now,
      );

      expect(category.id, 'category-id-2');
      expect(category.name, 'Colored Category');
      expect(category.color, '#4285F4');
      expect(category.createdAt, now);
    });

    test('should create a Category with color in ARGB format', () {
      final now = DateTime.now();
      final category = Category(
        id: 'category-id-argb',
        name: 'ARGB Category',
        color: '#FF4285F4',
        createdAt: now,
      );

      expect(category.color, '#FF4285F4');
    });

    test('should serialize Category to JSON correctly', () {
      final now = DateTime.now();
      final category = Category(
        id: 'category-id-3',
        name: 'JSON Category',
        color: '#34A853',
        createdAt: now,
      );

      final json = category.toJson();

      expect(json['id'], 'category-id-3');
      expect(json['name'], 'JSON Category');
      expect(json['color'], '#34A853');
      expect(json['createdAt'], now.toIso8601String());
    });

    test('should serialize Category to JSON without color when null', () {
      final now = DateTime.now();
      final category = Category(
        id: 'category-id-4',
        name: 'No Color Category',
        createdAt: now,
      );

      final json = category.toJson();

      expect(json['id'], 'category-id-4');
      expect(json['name'], 'No Color Category');
      expect(json['color'], isNull);
      expect(json['createdAt'], now.toIso8601String());
    });

    test('should deserialize Category from JSON correctly', () {
      final now = DateTime.now();
      final json = {
        'id': 'category-id-5',
        'name': 'Deserialized Category',
        'color': '#EA4335',
        'createdAt': now.toIso8601String(),
      };

      final category = Category.fromJson(json);

      expect(category.id, 'category-id-5');
      expect(category.name, 'Deserialized Category');
      expect(category.color, '#EA4335');
      expect(category.createdAt, now);
    });

    test('should deserialize Category from JSON without color', () {
      final now = DateTime.now();
      final json = {
        'id': 'category-id-6',
        'name': 'No Color Deserialized',
        'createdAt': now.toIso8601String(),
      };

      final category = Category.fromJson(json);

      expect(category.id, 'category-id-6');
      expect(category.name, 'No Color Deserialized');
      expect(category.color, isNull);
      expect(category.createdAt, now);
    });

    test('should create a copy of Category with updated fields', () {
      final now = DateTime.now();
      final category = Category(
        id: 'category-id-7',
        name: 'Original Category',
        color: '#4285F4',
        createdAt: now,
      );

      final updatedCategory = category.copyWith(
        name: 'Updated Category',
        color: '#34A853',
      );

      expect(updatedCategory.id, 'category-id-7');
      expect(updatedCategory.name, 'Updated Category');
      expect(updatedCategory.color, '#34A853');
      expect(updatedCategory.createdAt, now);
    });

    test('should validate Category with empty name', () {
      final now = DateTime.now();
      
      expect(() {
        Category(
          id: 'category-id-8',
          name: '',
          createdAt: now,
        );
      }, throwsA(isA<ArgumentError>()));
    });

    test('should validate Category with empty id', () {
      final now = DateTime.now();
      
      expect(() {
        Category(
          id: '',
          name: 'Valid Name',
          createdAt: now,
        );
      }, throwsA(isA<ArgumentError>()));
    });

    test('should validate Category with whitespace-only name', () {
      final now = DateTime.now();
      
      expect(() {
        Category(
          id: 'category-id-9',
          name: '   ',
          createdAt: now,
        );
      }, throwsA(isA<ArgumentError>()));
    });

    test('should validate Category with invalid color format - missing hash', () {
      final now = DateTime.now();
      
      expect(() {
        Category(
          id: 'category-id-invalid-color-1',
          name: 'Invalid Color Category',
          color: '4285F4',
          createdAt: now,
        );
      }, throwsA(isA<ArgumentError>()));
    });

    test('should validate Category with invalid color format - wrong length', () {
      final now = DateTime.now();
      
      expect(() {
        Category(
          id: 'category-id-invalid-color-2',
          name: 'Invalid Color Category',
          color: '#4285F',
          createdAt: now,
        );
      }, throwsA(isA<ArgumentError>()));
    });

    test('should validate Category with invalid color format - invalid characters', () {
      final now = DateTime.now();
      
      expect(() {
        Category(
          id: 'category-id-invalid-color-3',
          name: 'Invalid Color Category',
          color: '#GGGGGG',
          createdAt: now,
        );
      }, throwsA(isA<ArgumentError>()));
    });

    test('should accept Category with valid hex color format - 6 digits', () {
      final now = DateTime.now();
      final category = Category(
        id: 'category-id-valid-color-1',
        name: 'Valid Color Category',
        color: '#4285F4',
        createdAt: now,
      );

      expect(category.color, '#4285F4');
    });

    test('should accept Category with valid hex color format - 8 digits', () {
      final now = DateTime.now();
      final category = Category(
        id: 'category-id-valid-color-2',
        name: 'Valid ARGB Color Category',
        color: '#FF4285F4',
        createdAt: now,
      );

      expect(category.color, '#FF4285F4');
    });

    test('should accept Category with lowercase hex color', () {
      final now = DateTime.now();
      final category = Category(
        id: 'category-id-lowercase-color',
        name: 'Lowercase Color Category',
        color: '#4285f4',
        createdAt: now,
      );

      expect(category.color, '#4285f4');
    });

    test('should accept Category with empty string color as null', () {
      final now = DateTime.now();
      final category = Category(
        id: 'category-id-empty-color',
        name: 'Empty Color Category',
        color: '',
        createdAt: now,
      );

      expect(category.color, '');
    });

    test('should compare Category instances for equality', () {
      final now = DateTime.now();
      final category1 = Category(
        id: 'category-id-10',
        name: 'Equal Category',
        color: '#4285F4',
        createdAt: now,
      );

      final category2 = Category(
        id: 'category-id-10',
        name: 'Equal Category',
        color: '#4285F4',
        createdAt: now,
      );

      expect(category1, equals(category2));
      expect(category1.hashCode, equals(category2.hashCode));
    });

    test('should compare Category instances for inequality', () {
      final now = DateTime.now();
      final category1 = Category(
        id: 'category-id-11',
        name: 'Category 1',
        createdAt: now,
      );

      final category2 = Category(
        id: 'category-id-12',
        name: 'Category 2',
        createdAt: now,
      );

      expect(category1, isNot(equals(category2)));
    });

    test('should handle Category with different color values', () {
      final now = DateTime.now();
      
      final category1 = Category(
        id: 'category-id-13',
        name: 'Red Category',
        color: '#EA4335',
        createdAt: now,
      );

      final category2 = Category(
        id: 'category-id-14',
        name: 'Blue Category',
        color: '#4285F4',
        createdAt: now,
      );

      final category3 = Category(
        id: 'category-id-15',
        name: 'Green Category',
        color: '#34A853',
        createdAt: now,
      );

      expect(category1.color, '#EA4335');
      expect(category2.color, '#4285F4');
      expect(category3.color, '#34A853');
    });

    test('should handle Category with special characters in name', () {
      final now = DateTime.now();
      final category = Category(
        id: 'category-id-16',
        name: 'Special: !@#\$%^&*() Category',
        createdAt: now,
      );

      expect(category.name, 'Special: !@#\$%^&*() Category');
    });

    test('should handle Category with very long name', () {
      final now = DateTime.now();
      final longName = 'A' * 100;
      final category = Category(
        id: 'category-id-17',
        name: longName,
        createdAt: now,
      );

      expect(category.name.length, 100);
      expect(category.name, longName);
    });

    test('should handle Category with null color in copyWith', () {
      final now = DateTime.now();
      final category = Category(
        id: 'category-id-18',
        name: 'Colored Category',
        color: '#4285F4',
        createdAt: now,
      );

      final updatedCategory = category.copyWith(color: null);

      expect(updatedCategory.id, 'category-id-18');
      expect(updatedCategory.name, 'Colored Category');
      expect(updatedCategory.color, isNull);
      expect(updatedCategory.createdAt, now);
    });

    test('should return proper string representation', () {
      final now = DateTime.now();
      final category = Category(
        id: 'category-id-19',
        name: 'String Test Category',
        color: '#4285F4',
        createdAt: now,
      );

      final str = category.toString();
      expect(str, contains('category-id-19'));
      expect(str, contains('String Test Category'));
      expect(str, contains('#4285F4'));
    });
  });
}
