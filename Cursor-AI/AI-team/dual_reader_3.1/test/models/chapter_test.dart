import 'package:flutter_test/flutter_test.dart';
import 'package:dual_reader/models/chapter.dart';

void main() {
  group('Chapter', () {
    test('creates with required fields', () {
      final chapter = Chapter(
        id: 'chapter_1',
        title: 'Introduction',
        startIndex: 0,
        endIndex: 1000,
        startPage: 1,
        endPage: 10,
        bookId: 'book_1',
      );

      expect(chapter.id, 'chapter_1');
      expect(chapter.title, 'Introduction');
      expect(chapter.startIndex, 0);
      expect(chapter.endIndex, 1000);
      expect(chapter.startPage, 1);
      expect(chapter.endPage, 10);
      expect(chapter.bookId, 'book_1');
      expect(chapter.href, isNull);
    });

    test('creates with optional href', () {
      final chapter = Chapter(
        id: 'chapter_1',
        title: 'Introduction',
        startIndex: 0,
        endIndex: 1000,
        startPage: 1,
        endPage: 10,
        bookId: 'book_1',
        href: 'chapter1.html',
      );

      expect(chapter.href, 'chapter1.html');
      expect(chapter.startPage, 1);
      expect(chapter.endPage, 10);
      expect(chapter.bookId, 'book_1');
    });

    test('copyWith creates new instance with updated values', () {
      final original = Chapter(
        id: 'chapter_1',
        title: 'Introduction',
        startIndex: 0,
        endIndex: 1000,
        startPage: 1,
        endPage: 10,
        bookId: 'book_1',
      );

      final updated = original.copyWith(
        title: 'Updated Title',
        startIndex: 100,
        endIndex: 2000,
        startPage: 5,
        endPage: 15,
        bookId: 'book_2',
        href: 'new_href.html',
      );

      // Original unchanged
      expect(original.title, 'Introduction');
      expect(original.startIndex, 0);
      expect(original.endIndex, 1000);
      expect(original.startPage, 1);
      expect(original.endPage, 10);
      expect(original.bookId, 'book_1');
      expect(original.href, isNull);

      // Updated has new values
      expect(updated.title, 'Updated Title');
      expect(updated.startIndex, 100);
      expect(updated.endIndex, 2000);
      expect(updated.startPage, 5);
      expect(updated.endPage, 15);
      expect(updated.bookId, 'book_2');
      expect(updated.href, 'new_href.html');

      // Other values preserved
      expect(updated.id, original.id);
    });

    test('copyWith preserves all values when no parameters provided', () {
      final original = Chapter(
        id: 'chapter_1',
        title: 'Introduction',
        startIndex: 0,
        endIndex: 1000,
        startPage: 1,
        endPage: 10,
        bookId: 'book_1',
        href: 'chapter1.html',
      );

      final copied = original.copyWith();

      expect(copied.id, original.id);
      expect(copied.title, original.title);
      expect(copied.startIndex, original.startIndex);
      expect(copied.endIndex, original.endIndex);
      expect(copied.startPage, original.startPage);
      expect(copied.endPage, original.endPage);
      expect(copied.bookId, original.bookId);
      expect(copied.href, original.href);
    });

    test('handles valid index ranges', () {
      final chapter = Chapter(
        id: 'chapter_1',
        title: 'Test',
        startIndex: 100,
        endIndex: 200,
        startPage: 5,
        endPage: 10,
        bookId: 'book_1',
      );

      expect(chapter.startIndex, lessThanOrEqualTo(chapter.endIndex));
      expect(chapter.startPage, lessThanOrEqualTo(chapter.endPage));
    });

    test('handles zero-length chapter', () {
      final chapter = Chapter(
        id: 'chapter_1',
        title: 'Empty Chapter',
        startIndex: 100,
        endIndex: 100,
        startPage: 5,
        endPage: 5,
        bookId: 'book_1',
      );

      expect(chapter.startIndex, chapter.endIndex);
      expect(chapter.startPage, chapter.endPage);
    });

    test('handles large indices', () {
      final chapter = Chapter(
        id: 'chapter_1',
        title: 'Large Chapter',
        startIndex: 0,
        endIndex: 1000000,
        startPage: 1,
        endPage: 1000,
        bookId: 'book_1',
      );

      expect(chapter.endIndex, 1000000);
      expect(chapter.endPage, 1000);
    });

    test('handles page ranges correctly', () {
      final chapter = Chapter(
        id: 'chapter_1',
        title: 'Chapter with Pages',
        startIndex: 0,
        endIndex: 5000,
        startPage: 10,
        endPage: 25,
        bookId: 'book_1',
      );

      expect(chapter.startPage, 10);
      expect(chapter.endPage, 25);
      expect(chapter.endPage - chapter.startPage, 15);
    });

    test('bookId references correct book', () {
      final chapter1 = Chapter(
        id: 'chapter_1',
        title: 'Chapter 1',
        startIndex: 0,
        endIndex: 1000,
        startPage: 1,
        endPage: 10,
        bookId: 'book_1',
      );

      final chapter2 = Chapter(
        id: 'chapter_2',
        title: 'Chapter 2',
        startIndex: 1000,
        endIndex: 2000,
        startPage: 11,
        endPage: 20,
        bookId: 'book_1',
      );

      final chapter3 = Chapter(
        id: 'chapter_3',
        title: 'Chapter 3',
        startIndex: 0,
        endIndex: 1000,
        startPage: 1,
        endPage: 10,
        bookId: 'book_2',
      );

      expect(chapter1.bookId, chapter2.bookId);
      expect(chapter1.bookId, isNot(chapter3.bookId));
    });

    group('JSON Serialization', () {
      test('toJson converts chapter to JSON map', () {
        final chapter = Chapter(
          id: 'chapter_1',
          title: 'Introduction',
          startIndex: 0,
          endIndex: 1000,
          startPage: 1,
          endPage: 10,
          bookId: 'book_1',
          href: 'chapter1.html',
        );

        final json = chapter.toJson();

        expect(json['id'], 'chapter_1');
        expect(json['title'], 'Introduction');
        expect(json['startIndex'], 0);
        expect(json['endIndex'], 1000);
        expect(json['startPage'], 1);
        expect(json['endPage'], 10);
        expect(json['bookId'], 'book_1');
        expect(json['href'], 'chapter1.html');
      });

      test('toJson handles null href', () {
        final chapter = Chapter(
          id: 'chapter_1',
          title: 'Introduction',
          startIndex: 0,
          endIndex: 1000,
          startPage: 1,
          endPage: 10,
          bookId: 'book_1',
        );

        final json = chapter.toJson();

        expect(json['href'], isNull);
        expect(json['startPage'], 1);
        expect(json['endPage'], 10);
        expect(json['bookId'], 'book_1');
      });

      test('fromJson creates chapter from JSON map', () {
        final json = {
          'id': 'chapter_1',
          'title': 'Introduction',
          'startIndex': 0,
          'endIndex': 1000,
          'startPage': 1,
          'endPage': 10,
          'bookId': 'book_1',
          'href': 'chapter1.html',
        };

        final chapter = Chapter.fromJson(json);

        expect(chapter.id, 'chapter_1');
        expect(chapter.title, 'Introduction');
        expect(chapter.startIndex, 0);
        expect(chapter.endIndex, 1000);
        expect(chapter.startPage, 1);
        expect(chapter.endPage, 10);
        expect(chapter.bookId, 'book_1');
        expect(chapter.href, 'chapter1.html');
      });

      test('fromJson handles null href', () {
        final json = {
          'id': 'chapter_1',
          'title': 'Introduction',
          'startIndex': 0,
          'endIndex': 1000,
          'startPage': 1,
          'endPage': 10,
          'bookId': 'book_1',
          'href': null,
        };

        final chapter = Chapter.fromJson(json);

        expect(chapter.href, isNull);
        expect(chapter.startPage, 1);
        expect(chapter.endPage, 10);
        expect(chapter.bookId, 'book_1');
      });

      test('fromJson throws FormatException for invalid data types', () {
        final invalidJson = {
          'id': 'chapter_1',
          'title': 'Introduction',
          'startIndex': 'invalid', // Should be int
          'endIndex': 1000,
          'startPage': 1,
          'endPage': 10,
          'bookId': 'book_1',
        };

        expect(
          () => Chapter.fromJson(invalidJson),
          throwsA(isA<FormatException>()),
        );
      });

      test('fromJson throws FormatException for missing required fields', () {
        final incompleteJson = {
          'id': 'chapter_1',
          'title': 'Introduction',
          // Missing required fields
        };

        expect(
          () => Chapter.fromJson(incompleteJson),
          throwsA(isA<FormatException>()),
        );
      });

      test('toJsonString converts chapter to JSON string', () {
        final chapter = Chapter(
          id: 'chapter_1',
          title: 'Introduction',
          startIndex: 0,
          endIndex: 1000,
          startPage: 1,
          endPage: 10,
          bookId: 'book_1',
        );

        final jsonString = chapter.toJsonString();

        expect(jsonString, isA<String>());
        expect(jsonString, contains('chapter_1'));
        expect(jsonString, contains('Introduction'));
        expect(jsonString, contains('book_1'));
      });

      test('fromJsonString creates chapter from JSON string', () {
        const jsonString = '''
        {
          "id": "chapter_1",
          "title": "Introduction",
          "startIndex": 0,
          "endIndex": 1000,
          "startPage": 1,
          "endPage": 10,
          "bookId": "book_1",
          "href": "chapter1.html"
        }
        ''';

        final chapter = Chapter.fromJsonString(jsonString);

        expect(chapter.id, 'chapter_1');
        expect(chapter.title, 'Introduction');
        expect(chapter.startIndex, 0);
        expect(chapter.endIndex, 1000);
        expect(chapter.startPage, 1);
        expect(chapter.endPage, 10);
        expect(chapter.bookId, 'book_1');
        expect(chapter.href, 'chapter1.html');
      });

      test('fromJsonString throws FormatException for invalid JSON', () {
        const invalidJson = 'invalid json string';

        expect(
          () => Chapter.fromJsonString(invalidJson),
          throwsA(isA<FormatException>()),
        );
      });

      test('round-trip JSON serialization preserves data', () {
        final original = Chapter(
          id: 'chapter_1',
          title: 'Introduction',
          startIndex: 0,
          endIndex: 1000,
          startPage: 1,
          endPage: 10,
          bookId: 'book_1',
          href: 'chapter1.html',
        );

        final jsonString = original.toJsonString();
        final restored = Chapter.fromJsonString(jsonString);

        expect(restored.id, original.id);
        expect(restored.title, original.title);
        expect(restored.startIndex, original.startIndex);
        expect(restored.endIndex, original.endIndex);
        expect(restored.startPage, original.startPage);
        expect(restored.endPage, original.endPage);
        expect(restored.bookId, original.bookId);
        expect(restored.href, original.href);
      });
    });

    group('Equality and HashCode', () {
      test('two chapters with same values are equal', () {
        final chapter1 = Chapter(
          id: 'chapter_1',
          title: 'Introduction',
          startIndex: 0,
          endIndex: 1000,
          startPage: 1,
          endPage: 10,
          bookId: 'book_1',
          href: 'chapter1.html',
        );

        final chapter2 = Chapter(
          id: 'chapter_1',
          title: 'Introduction',
          startIndex: 0,
          endIndex: 1000,
          startPage: 1,
          endPage: 10,
          bookId: 'book_1',
          href: 'chapter1.html',
        );

        expect(chapter1, equals(chapter2));
        expect(chapter1.hashCode, equals(chapter2.hashCode));
      });

      test('two chapters with different values are not equal', () {
        final chapter1 = Chapter(
          id: 'chapter_1',
          title: 'Introduction',
          startIndex: 0,
          endIndex: 1000,
          startPage: 1,
          endPage: 10,
          bookId: 'book_1',
        );

        final chapter2 = Chapter(
          id: 'chapter_2',
          title: 'Introduction',
          startIndex: 0,
          endIndex: 1000,
          startPage: 1,
          endPage: 10,
          bookId: 'book_1',
        );

        expect(chapter1, isNot(equals(chapter2)));
      });

      test('chapters with different startPage are not equal', () {
        final chapter1 = Chapter(
          id: 'chapter_1',
          title: 'Introduction',
          startIndex: 0,
          endIndex: 1000,
          startPage: 1,
          endPage: 10,
          bookId: 'book_1',
        );

        final chapter2 = Chapter(
          id: 'chapter_1',
          title: 'Introduction',
          startIndex: 0,
          endIndex: 1000,
          startPage: 2,
          endPage: 10,
          bookId: 'book_1',
        );

        expect(chapter1, isNot(equals(chapter2)));
      });

      test('chapters with different endPage are not equal', () {
        final chapter1 = Chapter(
          id: 'chapter_1',
          title: 'Introduction',
          startIndex: 0,
          endIndex: 1000,
          startPage: 1,
          endPage: 10,
          bookId: 'book_1',
        );

        final chapter2 = Chapter(
          id: 'chapter_1',
          title: 'Introduction',
          startIndex: 0,
          endIndex: 1000,
          startPage: 1,
          endPage: 11,
          bookId: 'book_1',
        );

        expect(chapter1, isNot(equals(chapter2)));
      });

      test('chapters with different bookId are not equal', () {
        final chapter1 = Chapter(
          id: 'chapter_1',
          title: 'Introduction',
          startIndex: 0,
          endIndex: 1000,
          startPage: 1,
          endPage: 10,
          bookId: 'book_1',
        );

        final chapter2 = Chapter(
          id: 'chapter_1',
          title: 'Introduction',
          startIndex: 0,
          endIndex: 1000,
          startPage: 1,
          endPage: 10,
          bookId: 'book_2',
        );

        expect(chapter1, isNot(equals(chapter2)));
      });

      test('chapters with null vs non-null href are not equal', () {
        final chapter1 = Chapter(
          id: 'chapter_1',
          title: 'Introduction',
          startIndex: 0,
          endIndex: 1000,
          startPage: 1,
          endPage: 10,
          bookId: 'book_1',
        );

        final chapter2 = Chapter(
          id: 'chapter_1',
          title: 'Introduction',
          startIndex: 0,
          endIndex: 1000,
          startPage: 1,
          endPage: 10,
          bookId: 'book_1',
          href: 'chapter1.html',
        );

        expect(chapter1, isNot(equals(chapter2)));
      });

      test('chapters can be used in Set', () {
        final chapter1 = Chapter(
          id: 'chapter_1',
          title: 'Introduction',
          startIndex: 0,
          endIndex: 1000,
          startPage: 1,
          endPage: 10,
          bookId: 'book_1',
        );

        final chapter2 = Chapter(
          id: 'chapter_1',
          title: 'Introduction',
          startIndex: 0,
          endIndex: 1000,
          startPage: 1,
          endPage: 10,
          bookId: 'book_1',
        );

        final chapter3 = Chapter(
          id: 'chapter_2',
          title: 'Chapter 2',
          startIndex: 1000,
          endIndex: 2000,
          startPage: 11,
          endPage: 20,
          bookId: 'book_1',
        );

        final chapters = {chapter1, chapter2, chapter3};

        expect(chapters.length, 2); // chapter1 and chapter2 are equal
        expect(chapters.contains(chapter1), isTrue);
        expect(chapters.contains(chapter2), isTrue);
        expect(chapters.contains(chapter3), isTrue);
      });
    });

    group('toString', () {
      test('toString returns formatted string', () {
        final chapter = Chapter(
          id: 'chapter_1',
          title: 'Introduction',
          startIndex: 0,
          endIndex: 1000,
          startPage: 1,
          endPage: 10,
          bookId: 'book_1',
        );

        final string = chapter.toString();

        expect(string, contains('Chapter'));
        expect(string, contains('chapter_1'));
        expect(string, contains('Introduction'));
        expect(string, contains('startPage: 1'));
        expect(string, contains('endPage: 10'));
        expect(string, contains('bookId: book_1'));
      });
    });
  });
}
