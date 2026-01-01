import 'package:flutter_test/flutter_test.dart';
import 'package:simplenotes/models/note.dart';

void main() {
  group('Note Model Tests', () {
    test('should create a Note with all required fields', () {
      final now = DateTime.now();
      final note = Note(
        id: 'test-id-1',
        title: 'Test Note',
        content: 'This is test content',
        createdAt: now,
        updatedAt: now,
      );

      expect(note.id, 'test-id-1');
      expect(note.title, 'Test Note');
      expect(note.content, 'This is test content');
      expect(note.categoryId, isNull);
      expect(note.createdAt, now);
      expect(note.updatedAt, now);
    });

    test('should create a Note with optional categoryId', () {
      final now = DateTime.now();
      final note = Note(
        id: 'test-id-2',
        title: 'Categorized Note',
        content: 'Content with category',
        categoryId: 'category-1',
        createdAt: now,
        updatedAt: now,
      );

      expect(note.id, 'test-id-2');
      expect(note.title, 'Categorized Note');
      expect(note.content, 'Content with category');
      expect(note.categoryId, 'category-1');
      expect(note.createdAt, now);
      expect(note.updatedAt, now);
    });

    test('should create a Note with default timestamps when not provided', () {
      final beforeCreation = DateTime.now();
      final note = Note(
        id: 'test-id-default-time',
        title: 'Default Time Note',
        content: 'Content',
      );
      final afterCreation = DateTime.now();

      expect(note.createdAt.isAfter(beforeCreation) || note.createdAt.isAtSameMomentAs(beforeCreation), isTrue);
      expect(note.createdAt.isBefore(afterCreation) || note.createdAt.isAtSameMomentAs(afterCreation), isTrue);
      expect(note.updatedAt.isAfter(beforeCreation) || note.updatedAt.isAtSameMomentAs(beforeCreation), isTrue);
      expect(note.updatedAt.isBefore(afterCreation) || note.updatedAt.isAtSameMomentAs(afterCreation), isTrue);
    });

    test('should serialize Note to JSON correctly', () {
      final now = DateTime.now();
      final note = Note(
        id: 'test-id-3',
        title: 'JSON Test Note',
        content: 'JSON content',
        categoryId: 'category-2',
        createdAt: now,
        updatedAt: now,
      );

      final json = note.toJson();

      expect(json['id'], 'test-id-3');
      expect(json['title'], 'JSON Test Note');
      expect(json['content'], 'JSON content');
      expect(json['categoryId'], 'category-2');
      expect(json['createdAt'], now.toIso8601String());
      expect(json['updatedAt'], now.toIso8601String());
    });

    test('should serialize Note to JSON without categoryId when null', () {
      final now = DateTime.now();
      final note = Note(
        id: 'test-id-4',
        title: 'No Category Note',
        content: 'No category content',
        createdAt: now,
        updatedAt: now,
      );

      final json = note.toJson();

      expect(json['id'], 'test-id-4');
      expect(json['title'], 'No Category Note');
      expect(json['content'], 'No category content');
      expect(json['categoryId'], isNull);
      expect(json['createdAt'], now.toIso8601String());
      expect(json['updatedAt'], now.toIso8601String());
    });

    test('should deserialize Note from JSON correctly', () {
      final now = DateTime.now();
      final json = {
        'id': 'test-id-5',
        'title': 'Deserialized Note',
        'content': 'Deserialized content',
        'categoryId': 'category-3',
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      };

      final note = Note.fromJson(json);

      expect(note.id, 'test-id-5');
      expect(note.title, 'Deserialized Note');
      expect(note.content, 'Deserialized content');
      expect(note.categoryId, 'category-3');
      expect(note.createdAt, now);
      expect(note.updatedAt, now);
    });

    test('should deserialize Note from JSON without categoryId', () {
      final now = DateTime.now();
      final json = {
        'id': 'test-id-6',
        'title': 'No Category Deserialized',
        'content': 'No category deserialized content',
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      };

      final note = Note.fromJson(json);

      expect(note.id, 'test-id-6');
      expect(note.title, 'No Category Deserialized');
      expect(note.content, 'No category deserialized content');
      expect(note.categoryId, isNull);
      expect(note.createdAt, now);
      expect(note.updatedAt, now);
    });

    test('should deserialize Note from JSON with null timestamps using defaults', () {
      final json = {
        'id': 'test-id-null-time',
        'title': 'Null Time Note',
        'content': 'Content',
      };

      final note = Note.fromJson(json);

      expect(note.id, 'test-id-null-time');
      expect(note.title, 'Null Time Note');
      expect(note.content, 'Content');
      expect(note.createdAt, isA<DateTime>());
      expect(note.updatedAt, isA<DateTime>());
    });

    test('should create a copy of Note with updated fields', () {
      final now = DateTime.now();
      final later = now.add(const Duration(hours: 1));
      final note = Note(
        id: 'test-id-7',
        title: 'Original Note',
        content: 'Original content',
        categoryId: 'category-4',
        createdAt: now,
        updatedAt: now,
      );

      final updatedNote = note.copyWith(
        title: 'Updated Note',
        content: 'Updated content',
        updatedAt: later,
      );

      expect(updatedNote.id, 'test-id-7');
      expect(updatedNote.title, 'Updated Note');
      expect(updatedNote.content, 'Updated content');
      expect(updatedNote.categoryId, 'category-4');
      expect(updatedNote.createdAt, now);
      expect(updatedNote.updatedAt, later);
    });

    test('should validate Note with empty id', () {
      final now = DateTime.now();
      final note = Note(
        id: '',
        title: 'Title',
        content: 'Content',
        createdAt: now,
        updatedAt: now,
      );

      final errors = note.validate();
      expect(errors, contains('Note ID cannot be empty'));
      expect(note.isValid, isFalse);
    });

    test('should validate Note with empty title', () {
      final now = DateTime.now();
      final note = Note(
        id: 'test-id-empty-title',
        title: '',
        content: 'Content',
        createdAt: now,
        updatedAt: now,
      );

      final errors = note.validate();
      expect(errors, contains('Note title cannot be empty'));
      expect(note.isValid, isFalse);
    });

    test('should validate Note with whitespace-only title', () {
      final now = DateTime.now();
      final note = Note(
        id: 'test-id-whitespace-title',
        title: '   ',
        content: 'Content',
        createdAt: now,
        updatedAt: now,
      );

      final errors = note.validate();
      expect(errors, contains('Note title cannot be empty'));
      expect(note.isValid, isFalse);
    });

    test('should validate Note with title exceeding 200 characters', () {
      final now = DateTime.now();
      final longTitle = 'A' * 201;
      final note = Note(
        id: 'test-id-long-title',
        title: longTitle,
        content: 'Content',
        createdAt: now,
        updatedAt: now,
      );

      final errors = note.validate();
      expect(errors, contains('Note title cannot exceed 200 characters'));
      expect(note.isValid, isFalse);
    });

    test('should validate Note with content exceeding 100000 characters', () {
      final now = DateTime.now();
      final longContent = 'A' * 100001;
      final note = Note(
        id: 'test-id-long-content',
        title: 'Title',
        content: longContent,
        createdAt: now,
        updatedAt: now,
      );

      final errors = note.validate();
      expect(errors, contains('Note content cannot exceed 100,000 characters'));
      expect(note.isValid, isFalse);
    });

    test('should validate Note with valid data', () {
      final now = DateTime.now();
      final note = Note(
        id: 'test-id-valid',
        title: 'Valid Title',
        content: 'Valid content',
        createdAt: now,
        updatedAt: now,
      );

      final errors = note.validate();
      expect(errors, isEmpty);
      expect(note.isValid, isTrue);
    });

    test('should validate Note with multiple validation errors', () {
      final now = DateTime.now();
      final longTitle = 'A' * 201;
      final longContent = 'A' * 100001;
      final note = Note(
        id: '',
        title: longTitle,
        content: longContent,
        createdAt: now,
        updatedAt: now,
      );

      final errors = note.validate();
      expect(errors.length, greaterThan(1));
      expect(errors, contains('Note ID cannot be empty'));
      expect(errors, contains('Note title cannot exceed 200 characters'));
      expect(errors, contains('Note content cannot exceed 100,000 characters'));
      expect(note.isValid, isFalse);
    });

    test('should update updatedAt timestamp when touch is called', () async {
      final now = DateTime.now();
      final note = Note(
        id: 'test-id-touch',
        title: 'Touch Test',
        content: 'Content',
        createdAt: now,
        updatedAt: now,
      );

      final beforeTouch = DateTime.now();
      await Future.delayed(const Duration(milliseconds: 10));
      note.touch();
      final afterTouch = DateTime.now();

      expect(note.updatedAt.isAfter(beforeTouch) || note.updatedAt.isAtSameMomentAs(beforeTouch), isTrue);
      expect(note.updatedAt.isBefore(afterTouch) || note.updatedAt.isAtSameMomentAs(afterTouch), isTrue);
      expect(note.createdAt, now);
    });

    test('should compare Note instances for equality', () {
      final now = DateTime.now();
      final note1 = Note(
        id: 'test-id-9',
        title: 'Equal Note',
        content: 'Content',
        categoryId: 'category-5',
        createdAt: now,
        updatedAt: now,
      );

      final note2 = Note(
        id: 'test-id-9',
        title: 'Equal Note',
        content: 'Content',
        categoryId: 'category-5',
        createdAt: now,
        updatedAt: now,
      );

      expect(note1, equals(note2));
      expect(note1.hashCode, equals(note2.hashCode));
    });

    test('should compare Note instances for inequality', () {
      final now = DateTime.now();
      final note1 = Note(
        id: 'test-id-10',
        title: 'Note 1',
        content: 'Content 1',
        createdAt: now,
        updatedAt: now,
      );

      final note2 = Note(
        id: 'test-id-11',
        title: 'Note 2',
        content: 'Content 2',
        createdAt: now,
        updatedAt: now,
      );

      expect(note1, isNot(equals(note2)));
    });

    test('should handle Note with very long content', () {
      final now = DateTime.now();
      final longContent = 'A' * 10000;
      final note = Note(
        id: 'test-id-12',
        title: 'Long Content Note',
        content: longContent,
        createdAt: now,
        updatedAt: now,
      );

      expect(note.content.length, 10000);
      expect(note.content, longContent);
    });

    test('should handle Note with special characters in title and content', () {
      final now = DateTime.now();
      final note = Note(
        id: 'test-id-13',
        title: 'Special: !@#\$%^&*() Note',
        content: 'Content with\nnewlines\tand\ttabs',
        createdAt: now,
        updatedAt: now,
      );

      expect(note.title, 'Special: !@#\$%^&*() Note');
      expect(note.content, 'Content with\nnewlines\tand\ttabs');
    });

    test('should return proper string representation', () {
      final now = DateTime.now();
      final note = Note(
        id: 'test-id-14',
        title: 'String Test',
        content: 'Content',
        categoryId: 'category-6',
        createdAt: now,
        updatedAt: now,
      );

      final str = note.toString();
      expect(str, contains('test-id-14'));
      expect(str, contains('String Test'));
      expect(str, contains('category-6'));
    });
  });
}
