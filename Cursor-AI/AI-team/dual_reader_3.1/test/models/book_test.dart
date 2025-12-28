import 'package:flutter_test/flutter_test.dart';
import 'package:dual_reader/models/book.dart';
import 'package:dual_reader/models/chapter.dart';

void main() {
  group('Book', () {
    final sampleChapters = [
      Chapter(
        id: 'chapter_1',
        title: 'Introduction',
        startIndex: 0,
        endIndex: 1000,
        startPage: 1,
        endPage: 10,
        bookId: 'book1',
      ),
      Chapter(
        id: 'chapter_2',
        title: 'Chapter 1',
        startIndex: 1001,
        endIndex: 5000,
        startPage: 11,
        endPage: 50,
        bookId: 'book1',
      ),
    ];

    final sampleMetadata = {
      'publisher': 'Test Publisher',
      'isbn': '978-0-123456-78-9',
      'description': 'A test book description',
      'publicationDate': '2023-01-01',
    };

    test('creates with required fields', () {
      final now = DateTime.now();
      final book = Book(
        id: 'book1',
        title: 'Test Book',
        author: 'Test Author',
        filePath: '/path/to/book.epub',
        format: 'epub',
        chapters: sampleChapters,
        fullText: 'Full text content...',
        addedAt: now,
      );

      expect(book.id, 'book1');
      expect(book.title, 'Test Book');
      expect(book.author, 'Test Author');
      expect(book.filePath, '/path/to/book.epub');
      expect(book.format, 'epub');
      expect(book.chapters, sampleChapters);
      expect(book.fullText, 'Full text content...');
      expect(book.addedAt, now);
      expect(book.coverImagePath, isNull);
      expect(book.language, isNull);
      expect(book.totalPages, 0);
      expect(book.chapterHtml, isNull);
      expect(book.metadata, isNull);
    });

    test('creates with all optional fields', () {
      final now = DateTime.now();
      final chapterHtml = {
        'chapter_1': '<html>Chapter 1 content</html>',
        'chapter_2': '<html>Chapter 2 content</html>',
      };

      final book = Book(
        id: 'book1',
        title: 'Test Book',
        author: 'Test Author',
        filePath: '/path/to/book.epub',
        format: 'epub',
        coverImagePath: '/path/to/cover.jpg',
        chapters: sampleChapters,
        fullText: 'Full text content...',
        addedAt: now,
        language: 'en',
        totalPages: 100,
        chapterHtml: chapterHtml,
        metadata: sampleMetadata,
      );

      expect(book.coverImagePath, '/path/to/cover.jpg');
      expect(book.language, 'en');
      expect(book.totalPages, 100);
      expect(book.chapterHtml, chapterHtml);
      expect(book.metadata, sampleMetadata);
    });

    test('creates with MOBI format', () {
      final book = Book(
        id: 'book2',
        title: 'MOBI Book',
        author: 'MOBI Author',
        filePath: '/path/to/book.mobi',
        format: 'mobi',
        chapters: [],
        fullText: 'MOBI content',
        addedAt: DateTime.now(),
      );

      expect(book.format, 'mobi');
    });

    test('copyWith creates new instance with updated values', () {
      final original = Book(
        id: 'book1',
        title: 'Original Title',
        author: 'Original Author',
        filePath: '/original/path.epub',
        format: 'epub',
        chapters: sampleChapters,
        fullText: 'Original text',
        addedAt: DateTime(2023, 1, 1),
      );

      final updated = original.copyWith(
        title: 'Updated Title',
        author: 'Updated Author',
        totalPages: 200,
        language: 'es',
      );

      // Original unchanged
      expect(original.title, 'Original Title');
      expect(original.author, 'Original Author');
      expect(original.totalPages, 0);
      expect(original.language, isNull);

      // Updated has new values
      expect(updated.title, 'Updated Title');
      expect(updated.author, 'Updated Author');
      expect(updated.totalPages, 200);
      expect(updated.language, 'es');

      // Other values preserved
      expect(updated.id, original.id);
      expect(updated.filePath, original.filePath);
      expect(updated.format, original.format);
      expect(updated.chapters, original.chapters);
      expect(updated.fullText, original.fullText);
      expect(updated.addedAt, original.addedAt);
    });

    test('copyWith preserves all values when no parameters provided', () {
      final original = Book(
        id: 'book1',
        title: 'Test Book',
        author: 'Test Author',
        filePath: '/path/to/book.epub',
        format: 'epub',
        coverImagePath: '/path/to/cover.jpg',
        chapters: sampleChapters,
        fullText: 'Full text',
        addedAt: DateTime.now(),
        language: 'en',
        totalPages: 100,
        metadata: sampleMetadata,
      );

      final copied = original.copyWith();

      expect(copied.id, original.id);
      expect(copied.title, original.title);
      expect(copied.author, original.author);
      expect(copied.filePath, original.filePath);
      expect(copied.format, original.format);
      expect(copied.coverImagePath, original.coverImagePath);
      expect(copied.chapters, original.chapters);
      expect(copied.fullText, original.fullText);
      expect(copied.addedAt, original.addedAt);
      expect(copied.language, original.language);
      expect(copied.totalPages, original.totalPages);
      expect(copied.metadata, original.metadata);
    });

    test('copyWith can clear optional fields', () {
      final original = Book(
        id: 'book1',
        title: 'Test Book',
        author: 'Test Author',
        filePath: '/path/to/book.epub',
        format: 'epub',
        coverImagePath: '/path/to/cover.jpg',
        chapters: sampleChapters,
        fullText: 'Full text',
        addedAt: DateTime.now(),
        language: 'en',
        metadata: sampleMetadata,
      );

      final cleared = original.copyWith(
        coverImagePath: null,
        language: null,
        metadata: null,
      );

      expect(cleared.coverImagePath, isNull);
      expect(cleared.language, isNull);
      expect(cleared.metadata, isNull);
      expect(cleared.title, original.title);
    });

    test('readingProgressId returns book id', () {
      final book = Book(
        id: 'book1',
        title: 'Test Book',
        author: 'Test Author',
        filePath: '/path/to/book.epub',
        format: 'epub',
        chapters: [],
        fullText: 'Full text',
        addedAt: DateTime.now(),
      );

      expect(book.readingProgressId, 'book1');
    });

    group('JSON Serialization', () {
      test('toJson converts book to JSON map', () {
        final now = DateTime(2023, 1, 1, 12, 0, 0);
        final book = Book(
          id: 'book1',
          title: 'Test Book',
          author: 'Test Author',
          filePath: '/path/to/book.epub',
          format: 'epub',
          coverImagePath: '/path/to/cover.jpg',
          chapters: sampleChapters,
          fullText: 'Full text content',
          addedAt: now,
          language: 'en',
          totalPages: 100,
          chapterHtml: {'chapter_1': '<html>Content</html>'},
          metadata: sampleMetadata,
        );

        final json = book.toJson();

        expect(json['id'], 'book1');
        expect(json['title'], 'Test Book');
        expect(json['author'], 'Test Author');
        expect(json['filePath'], '/path/to/book.epub');
        expect(json['format'], 'epub');
        expect(json['coverImagePath'], '/path/to/cover.jpg');
        expect(json['language'], 'en');
        expect(json['totalPages'], 100);
        expect(json['fullText'], 'Full text content');
        expect(json['addedAt'], now.toIso8601String());
        expect(json['chapterHtml'], {'chapter_1': '<html>Content</html>'});
        expect(json['metadata'], sampleMetadata);
        expect(json['chapters'], isA<List>());
        expect((json['chapters'] as List).length, 2);
      });

      test('toJson handles null optional fields', () {
        final now = DateTime.now();
        final book = Book(
          id: 'book1',
          title: 'Test Book',
          author: 'Test Author',
          filePath: '/path/to/book.epub',
          format: 'epub',
          chapters: [],
          fullText: 'Full text',
          addedAt: now,
        );

        final json = book.toJson();

        expect(json['coverImagePath'], isNull);
        expect(json['language'], isNull);
        expect(json['chapterHtml'], isNull);
        expect(json['metadata'], isNull);
        expect(json['chapters'], isEmpty);
      });

      test('fromJson creates book from JSON map', () {
        final json = {
          'id': 'book1',
          'title': 'Test Book',
          'author': 'Test Author',
          'filePath': '/path/to/book.epub',
          'format': 'epub',
          'coverImagePath': '/path/to/cover.jpg',
          'chapters': [
            {
              'id': 'chapter_1',
              'title': 'Introduction',
              'startIndex': 0,
              'endIndex': 1000,
              'href': null,
              'startPage': 1,
              'endPage': 10,
              'bookId': 'book1',
            },
            {
              'id': 'chapter_2',
              'title': 'Chapter 1',
              'startIndex': 1001,
              'endIndex': 5000,
              'href': 'chapter2.html',
              'startPage': 11,
              'endPage': 50,
              'bookId': 'book1',
            },
          ],
          'fullText': 'Full text content',
          'addedAt': '2023-01-01T12:00:00.000Z',
          'language': 'en',
          'totalPages': 100,
          'chapterHtml': {
            'chapter_1': '<html>Content</html>',
          },
          'metadata': sampleMetadata,
        };

        final book = Book.fromJson(json);

        expect(book.id, 'book1');
        expect(book.title, 'Test Book');
        expect(book.author, 'Test Author');
        expect(book.filePath, '/path/to/book.epub');
        expect(book.format, 'epub');
        expect(book.coverImagePath, '/path/to/cover.jpg');
        expect(book.language, 'en');
        expect(book.totalPages, 100);
        expect(book.fullText, 'Full text content');
        expect(book.addedAt, DateTime(2023, 1, 1, 12, 0, 0));
        expect(book.chapters.length, 2);
        expect(book.chapters[0].id, 'chapter_1');
        expect(book.chapters[1].id, 'chapter_2');
        expect(book.chapterHtml, {'chapter_1': '<html>Content</html>'});
        expect(book.metadata, sampleMetadata);
      });

      test('fromJson handles missing optional fields', () {
        final json = {
          'id': 'book1',
          'title': 'Test Book',
          'author': 'Test Author',
          'filePath': '/path/to/book.epub',
          'format': 'epub',
          'chapters': [],
          'fullText': 'Full text',
          'addedAt': '2023-01-01T12:00:00.000Z',
        };

        final book = Book.fromJson(json);

        expect(book.coverImagePath, isNull);
        expect(book.language, isNull);
        expect(book.totalPages, 0);
        expect(book.chapterHtml, isNull);
        expect(book.metadata, isNull);
        expect(book.chapters, isEmpty);
      });

      test('fromJson handles null chapters list', () {
        final json = {
          'id': 'book1',
          'title': 'Test Book',
          'author': 'Test Author',
          'filePath': '/path/to/book.epub',
          'format': 'epub',
          'chapters': null,
          'fullText': 'Full text',
          'addedAt': '2023-01-01T12:00:00.000Z',
        };

        final book = Book.fromJson(json);

        expect(book.chapters, isEmpty);
      });

      test('toJsonString converts book to JSON string', () {
        final now = DateTime(2023, 1, 1, 12, 0, 0);
        final book = Book(
          id: 'book1',
          title: 'Test Book',
          author: 'Test Author',
          filePath: '/path/to/book.epub',
          format: 'epub',
          chapters: sampleChapters,
          fullText: 'Full text',
          addedAt: now,
        );

        final jsonString = book.toJsonString();

        expect(jsonString, isA<String>());
        expect(jsonString, contains('book1'));
        expect(jsonString, contains('Test Book'));
        expect(jsonString, contains('Test Author'));
      });

      test('fromJsonString creates book from JSON string', () {
        final jsonString = '''
        {
          "id": "book1",
          "title": "Test Book",
          "author": "Test Author",
          "filePath": "/path/to/book.epub",
          "format": "epub",
          "chapters": [
            {
              "id": "chapter_1",
              "title": "Introduction",
              "startIndex": 0,
              "endIndex": 1000,
              "href": null,
              "startPage": 1,
              "endPage": 10,
              "bookId": "book1"
            }
          ],
          "fullText": "Full text",
          "addedAt": "2023-01-01T12:00:00.000Z"
        }
        ''';

        final book = Book.fromJsonString(jsonString);

        expect(book.id, 'book1');
        expect(book.title, 'Test Book');
        expect(book.author, 'Test Author');
        expect(book.format, 'epub');
        expect(book.chapters.length, 1);
      });

      test('fromJsonString throws FormatException for invalid JSON', () {
        const invalidJson = 'invalid json string';

        expect(
          () => Book.fromJsonString(invalidJson),
          throwsA(isA<FormatException>()),
        );
      });

      test('round-trip JSON serialization preserves data', () {
        final original = Book(
          id: 'book1',
          title: 'Test Book',
          author: 'Test Author',
          filePath: '/path/to/book.epub',
          format: 'epub',
          coverImagePath: '/path/to/cover.jpg',
          chapters: sampleChapters,
          fullText: 'Full text content',
          addedAt: DateTime(2023, 1, 1, 12, 0, 0),
          language: 'en',
          totalPages: 100,
          chapterHtml: {'chapter_1': '<html>Content</html>'},
          metadata: sampleMetadata,
        );

        final jsonString = original.toJsonString();
        final restored = Book.fromJsonString(jsonString);

        expect(restored.id, original.id);
        expect(restored.title, original.title);
        expect(restored.author, original.author);
        expect(restored.filePath, original.filePath);
        expect(restored.format, original.format);
        expect(restored.coverImagePath, original.coverImagePath);
        expect(restored.language, original.language);
        expect(restored.totalPages, original.totalPages);
        expect(restored.fullText, original.fullText);
        expect(restored.addedAt, original.addedAt);
        expect(restored.chapters.length, original.chapters.length);
        expect(restored.chapters[0].id, original.chapters[0].id);
        expect(restored.chapterHtml, original.chapterHtml);
        expect(restored.metadata, original.metadata);
      });
    });

    group('Edge Cases', () {
      test('handles empty chapters list', () {
        final book = Book(
          id: 'book1',
          title: 'Test Book',
          author: 'Test Author',
          filePath: '/path/to/book.epub',
          format: 'epub',
          chapters: [],
          fullText: 'Full text',
          addedAt: DateTime.now(),
        );

        expect(book.chapters, isEmpty);
        expect(book.toJson()['chapters'], isEmpty);
      });

      test('handles empty fullText', () {
        final book = Book(
          id: 'book1',
          title: 'Test Book',
          author: 'Test Author',
          filePath: '/path/to/book.epub',
          format: 'epub',
          chapters: [],
          fullText: '',
          addedAt: DateTime.now(),
        );

        expect(book.fullText, isEmpty);
      });

      test('handles large totalPages value', () {
        final book = Book(
          id: 'book1',
          title: 'Test Book',
          author: 'Test Author',
          filePath: '/path/to/book.epub',
          format: 'epub',
          chapters: [],
          fullText: 'Full text',
          addedAt: DateTime.now(),
          totalPages: 99999,
        );

        expect(book.totalPages, 99999);
      });

      test('handles metadata with various value types', () {
        final complexMetadata = {
          'string': 'value',
          'int': 42,
          'double': 3.14,
          'bool': true,
          'list': [1, 2, 3],
          'nested': {'key': 'value'},
        };

        final book = Book(
          id: 'book1',
          title: 'Test Book',
          author: 'Test Author',
          filePath: '/path/to/book.epub',
          format: 'epub',
          chapters: [],
          fullText: 'Full text',
          addedAt: DateTime.now(),
          metadata: complexMetadata,
        );

        expect(book.metadata, complexMetadata);
        final json = book.toJson();
        final restored = Book.fromJson(json);
        expect(restored.metadata, complexMetadata);
      });

      test('handles very long file paths', () {
        final longPath = '/very/long/path/' + 'a' * 200 + '/book.epub';
        final book = Book(
          id: 'book1',
          title: 'Test Book',
          author: 'Test Author',
          filePath: longPath,
          format: 'epub',
          chapters: [],
          fullText: 'Full text',
          addedAt: DateTime.now(),
        );

        expect(book.filePath, longPath);
        expect(book.toJson()['filePath'], longPath);
      });
    });
  });
}
