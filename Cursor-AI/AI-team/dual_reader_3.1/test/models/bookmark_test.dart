import 'package:flutter_test/flutter_test.dart';
import 'package:dual_reader/models/bookmark.dart';

void main() {
  group('Bookmark', () {
    test('creates with required fields', () {
      final now = DateTime.now();
      final bookmark = Bookmark(
        id: 'bookmark1',
        bookId: 'book1',
        page: 42,
        createdAt: now,
      );

      expect(bookmark.id, 'bookmark1');
      expect(bookmark.bookId, 'book1');
      expect(bookmark.page, 42);
      expect(bookmark.createdAt, now);
      expect(bookmark.note, isNull);
      expect(bookmark.chapterId, isNull);
    });

    test('creates with optional note and chapter ID', () {
      final now = DateTime.now();
      final bookmark = Bookmark(
        id: 'bookmark1',
        bookId: 'book1',
        page: 42,
        createdAt: now,
        note: 'Important passage',
        chapterId: 'chapter_5',
      );

      expect(bookmark.note, 'Important passage');
      expect(bookmark.chapterId, 'chapter_5');
    });

    test('copyWith creates new instance with updated values', () {
      final original = Bookmark(
        id: 'bookmark1',
        bookId: 'book1',
        page: 42,
        createdAt: DateTime.now(),
      );

      final updated = original.copyWith(
        page: 50,
        note: 'Updated note',
        chapterId: 'chapter_6',
      );

      // Original unchanged
      expect(original.page, 42);
      expect(original.note, isNull);
      expect(original.chapterId, isNull);

      // Updated has new values
      expect(updated.page, 50);
      expect(updated.note, 'Updated note');
      expect(updated.chapterId, 'chapter_6');

      // Other values preserved
      expect(updated.id, original.id);
      expect(updated.bookId, original.bookId);
      expect(updated.createdAt, original.createdAt);
    });

    test('copyWith preserves all values when no parameters provided', () {
      final original = Bookmark(
        id: 'bookmark1',
        bookId: 'book1',
        page: 42,
        createdAt: DateTime.now(),
        note: 'Note',
        chapterId: 'chapter_1',
      );

      final copied = original.copyWith();

      expect(copied.id, original.id);
      expect(copied.bookId, original.bookId);
      expect(copied.page, original.page);
      expect(copied.note, original.note);
      expect(copied.createdAt, original.createdAt);
      expect(copied.chapterId, original.chapterId);
    });

    test('copyWith can clear note and chapter ID', () {
      final original = Bookmark(
        id: 'bookmark1',
        bookId: 'book1',
        page: 42,
        createdAt: DateTime.now(),
        note: 'Note',
        chapterId: 'chapter_1',
      );

      final cleared = original.copyWith(
        note: null,
        chapterId: null,
      );

      expect(cleared.note, isNull);
      expect(cleared.chapterId, isNull);
      expect(cleared.page, original.page);
    });

    test('handles page 1', () {
      final bookmark = Bookmark(
        id: 'bookmark1',
        bookId: 'book1',
        page: 1,
        createdAt: DateTime.now(),
      );

      expect(bookmark.page, 1);
    });

    test('handles large page numbers', () {
      final bookmark = Bookmark(
        id: 'bookmark1',
        bookId: 'book1',
        page: 9999,
        createdAt: DateTime.now(),
      );

      expect(bookmark.page, 9999);
    });

    group('JSON serialization', () {
      test('toJson converts bookmark to JSON map with all fields', () {
        final now = DateTime(2024, 1, 15, 10, 30, 45);
        final bookmark = Bookmark(
          id: 'bookmark1',
          bookId: 'book1',
          page: 42,
          note: 'Important passage',
          createdAt: now,
          chapterId: 'chapter_5',
        );

        final json = bookmark.toJson();

        expect(json['id'], 'bookmark1');
        expect(json['bookId'], 'book1');
        expect(json['page'], 42);
        expect(json['note'], 'Important passage');
        expect(json['createdAt'], '2024-01-15T10:30:45.000');
        expect(json['chapterId'], 'chapter_5');
      });

      test('toJson handles null optional fields', () {
        final now = DateTime.now();
        final bookmark = Bookmark(
          id: 'bookmark1',
          bookId: 'book1',
          page: 42,
          createdAt: now,
        );

        final json = bookmark.toJson();

        expect(json['id'], 'bookmark1');
        expect(json['bookId'], 'book1');
        expect(json['page'], 42);
        expect(json['note'], isNull);
        expect(json['chapterId'], isNull);
        expect(json['createdAt'], isNotNull);
      });

      test('fromJson creates bookmark from JSON map', () {
        final json = {
          'id': 'bookmark1',
          'bookId': 'book1',
          'page': 42,
          'note': 'Important passage',
          'createdAt': '2024-01-15T10:30:45.000',
          'chapterId': 'chapter_5',
        };

        final bookmark = Bookmark.fromJson(json);

        expect(bookmark.id, 'bookmark1');
        expect(bookmark.bookId, 'book1');
        expect(bookmark.page, 42);
        expect(bookmark.note, 'Important passage');
        expect(bookmark.createdAt, DateTime(2024, 1, 15, 10, 30, 45));
        expect(bookmark.chapterId, 'chapter_5');
      });

      test('fromJson handles null optional fields', () {
        final json = {
          'id': 'bookmark1',
          'bookId': 'book1',
          'page': 42,
          'note': null,
          'createdAt': '2024-01-15T10:30:45.000',
          'chapterId': null,
        };

        final bookmark = Bookmark.fromJson(json);

        expect(bookmark.id, 'bookmark1');
        expect(bookmark.bookId, 'book1');
        expect(bookmark.page, 42);
        expect(bookmark.note, isNull);
        expect(bookmark.chapterId, isNull);
        expect(bookmark.createdAt, DateTime(2024, 1, 15, 10, 30, 45));
      });

      test('fromJson handles missing optional fields', () {
        final json = {
          'id': 'bookmark1',
          'bookId': 'book1',
          'page': 42,
          'createdAt': '2024-01-15T10:30:45.000',
        };

        final bookmark = Bookmark.fromJson(json);

        expect(bookmark.id, 'bookmark1');
        expect(bookmark.bookId, 'book1');
        expect(bookmark.page, 42);
        expect(bookmark.note, isNull);
        expect(bookmark.chapterId, isNull);
      });

      test('toJsonString converts bookmark to JSON string', () {
        final now = DateTime(2024, 1, 15, 10, 30, 45);
        final bookmark = Bookmark(
          id: 'bookmark1',
          bookId: 'book1',
          page: 42,
          note: 'Important passage',
          createdAt: now,
          chapterId: 'chapter_5',
        );

        final jsonString = bookmark.toJsonString();

        expect(jsonString, isA<String>());
        expect(jsonString, contains('bookmark1'));
        expect(jsonString, contains('book1'));
        expect(jsonString, contains('42'));
        expect(jsonString, contains('Important passage'));
        expect(jsonString, contains('chapter_5'));
      });

      test('fromJsonString creates bookmark from JSON string', () {
        final jsonString =
            '{"id":"bookmark1","bookId":"book1","page":42,"note":"Important passage","createdAt":"2024-01-15T10:30:45.000","chapterId":"chapter_5"}';

        final bookmark = Bookmark.fromJsonString(jsonString);

        expect(bookmark.id, 'bookmark1');
        expect(bookmark.bookId, 'book1');
        expect(bookmark.page, 42);
        expect(bookmark.note, 'Important passage');
        expect(bookmark.chapterId, 'chapter_5');
        expect(bookmark.createdAt, DateTime(2024, 1, 15, 10, 30, 45));
      });

      test('fromJsonString throws FormatException for invalid JSON', () {
        expect(
          () => Bookmark.fromJsonString('invalid json'),
          throwsA(isA<FormatException>()),
        );
      });

      test('fromJsonString throws FormatException for incomplete JSON', () {
        expect(
          () => Bookmark.fromJsonString('{"id":"bookmark1"}'),
          throwsA(isA<FormatException>()),
        );
      });

      test('round-trip JSON serialization preserves all data', () {
        final original = Bookmark(
          id: 'bookmark1',
          bookId: 'book1',
          page: 42,
          note: 'Important passage',
          createdAt: DateTime(2024, 1, 15, 10, 30, 45),
          chapterId: 'chapter_5',
        );

        final jsonString = original.toJsonString();
        final restored = Bookmark.fromJsonString(jsonString);

        expect(restored.id, original.id);
        expect(restored.bookId, original.bookId);
        expect(restored.page, original.page);
        expect(restored.note, original.note);
        expect(restored.createdAt, original.createdAt);
        expect(restored.chapterId, original.chapterId);
      });

      test('round-trip JSON serialization preserves data without optional fields', () {
        final original = Bookmark(
          id: 'bookmark1',
          bookId: 'book1',
          page: 42,
          createdAt: DateTime(2024, 1, 15, 10, 30, 45),
        );

        final jsonString = original.toJsonString();
        final restored = Bookmark.fromJsonString(jsonString);

        expect(restored.id, original.id);
        expect(restored.bookId, original.bookId);
        expect(restored.page, original.page);
        expect(restored.note, isNull);
        expect(restored.createdAt, original.createdAt);
        expect(restored.chapterId, isNull);
      });

      test('toJson and fromJson are symmetric', () {
        final original = Bookmark(
          id: 'bookmark1',
          bookId: 'book1',
          page: 42,
          note: 'Important passage',
          createdAt: DateTime(2024, 1, 15, 10, 30, 45),
          chapterId: 'chapter_5',
        );

        final json = original.toJson();
        final restored = Bookmark.fromJson(json);

        expect(restored.id, original.id);
        expect(restored.bookId, original.bookId);
        expect(restored.page, original.page);
        expect(restored.note, original.note);
        expect(restored.createdAt, original.createdAt);
        expect(restored.chapterId, original.chapterId);
      });

      test('fromJson throws FormatException for invalid id type', () {
        final json = {
          'id': 123, // Should be String
          'bookId': 'book1',
          'page': 42,
          'createdAt': '2024-01-15T10:30:45.000',
        };

        expect(
          () => Bookmark.fromJson(json),
          throwsA(isA<FormatException>()),
        );
      });

      test('fromJson throws FormatException for invalid page type', () {
        final json = {
          'id': 'bookmark1',
          'bookId': 'book1',
          'page': '42', // Should be int
          'createdAt': '2024-01-15T10:30:45.000',
        };

        expect(
          () => Bookmark.fromJson(json),
          throwsA(isA<FormatException>()),
        );
      });

      test('fromJson throws FormatException for invalid date format', () {
        final json = {
          'id': 'bookmark1',
          'bookId': 'book1',
          'page': 42,
          'createdAt': 'invalid-date',
        };

        expect(
          () => Bookmark.fromJson(json),
          throwsA(isA<FormatException>()),
        );
      });

      test('fromJson throws FormatException for missing required fields', () {
        final json = {
          'id': 'bookmark1',
          // Missing bookId, page, createdAt
        };

        expect(
          () => Bookmark.fromJson(json),
          throwsA(isA<FormatException>()),
        );
      });
    });
  });
}
