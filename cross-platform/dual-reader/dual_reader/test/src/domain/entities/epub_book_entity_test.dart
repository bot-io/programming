import 'package:dual_reader/src/domain/entities/chapter_entity.dart';
import 'package:dual_reader/src/domain/entities/epub_book_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EpubBookEntity', () {
    // ── Helpers ──────────────────────────────────────────────────────

    final testChapters = [
      const ChapterEntity(title: 'Ch 1', content: 'Content 1'),
      const ChapterEntity(title: 'Ch 2', content: 'Content 2'),
    ];

    EpubBookEntity createEpubBook({
      String title = 'Test Book',
      String author = 'Author',
      String coverPath = '/covers/test.png',
      List<ChapterEntity>? chapters,
      String? publisher,
      String? description,
      String? language,
      String? isbn,
      String? publishDate,
      List<String>? tags,
    }) {
      return EpubBookEntity(
        title: title,
        author: author,
        coverPath: coverPath,
        chapters: chapters ?? testChapters,
        publisher: publisher,
        description: description,
        language: language,
        isbn: isbn,
        publishDate: publishDate,
        tags: tags,
      );
    }

    // ── Construction ─────────────────────────────────────────────────

    test('should construct with required fields only', () {
      final epub = createEpubBook();

      expect(epub.title, 'Test Book');
      expect(epub.author, 'Author');
      expect(epub.coverPath, '/covers/test.png');
      expect(epub.chapters, testChapters);
      expect(epub.publisher, isNull);
      expect(epub.description, isNull);
      expect(epub.language, isNull);
      expect(epub.isbn, isNull);
      expect(epub.publishDate, isNull);
      expect(epub.tags, isNull);
    });

    test('should construct with all fields provided', () {
      final chapters = [
        const ChapterEntity(title: 'Intro', content: 'Intro content'),
      ];
      final tags = ['fiction', 'adventure'];

      final epub = EpubBookEntity(
        title: 'Full Book',
        author: 'Jane Doe',
        coverPath: '/c/full.png',
        chapters: chapters,
        publisher: 'PubCo',
        description: 'A great book',
        language: 'en',
        isbn: '978-3-16-148410-0',
        publishDate: '2024-01-15',
        tags: tags,
      );

      expect(epub.title, 'Full Book');
      expect(epub.author, 'Jane Doe');
      expect(epub.coverPath, '/c/full.png');
      expect(epub.chapters, chapters);
      expect(epub.publisher, 'PubCo');
      expect(epub.description, 'A great book');
      expect(epub.language, 'en');
      expect(epub.isbn, '978-3-16-148410-0');
      expect(epub.publishDate, '2024-01-15');
      expect(epub.tags, tags);
    });

    test('should construct with empty chapters list', () {
      final epub = createEpubBook(chapters: []);
      expect(epub.chapters, isEmpty);
    });

    test('should construct with empty tags list', () {
      final epub = createEpubBook(tags: []);
      expect(epub.tags, isEmpty);
    });

    // ── copyWith ─────────────────────────────────────────────────────

    test('copyWith returns new instance with updated title', () {
      final epub = createEpubBook();
      final copied = epub.copyWith(title: 'New Title');
      expect(copied.title, 'New Title');
      expect(copied.author, epub.author);
    });

    test('copyWith returns new instance with updated author', () {
      final epub = createEpubBook();
      final copied = epub.copyWith(author: 'New Author');
      expect(copied.author, 'New Author');
    });

    test('copyWith returns new instance with updated coverPath', () {
      final epub = createEpubBook();
      final copied = epub.copyWith(coverPath: '/new/cover.png');
      expect(copied.coverPath, '/new/cover.png');
    });

    test('copyWith returns new instance with updated chapters', () {
      final epub = createEpubBook();
      final newChapters = [
        const ChapterEntity(title: 'New Ch', content: 'New content'),
      ];
      final copied = epub.copyWith(chapters: newChapters);
      expect(copied.chapters, newChapters);
      expect(copied.chapters.length, 1);
    });

    test('copyWith returns new instance with updated publisher', () {
      final epub = createEpubBook();
      final copied = epub.copyWith(publisher: 'NewPub');
      expect(copied.publisher, 'NewPub');
    });

    test('copyWith returns new instance with updated description', () {
      final epub = createEpubBook();
      final copied = epub.copyWith(description: 'New desc');
      expect(copied.description, 'New desc');
    });

    test('copyWith returns new instance with updated language', () {
      final epub = createEpubBook();
      final copied = epub.copyWith(language: 'de');
      expect(copied.language, 'de');
    });

    test('copyWith returns new instance with updated isbn', () {
      final epub = createEpubBook();
      final copied = epub.copyWith(isbn: '978-0-13-468599-1');
      expect(copied.isbn, '978-0-13-468599-1');
    });

    test('copyWith returns new instance with updated publishDate', () {
      final epub = createEpubBook();
      final copied = epub.copyWith(publishDate: '2025-06-04');
      expect(copied.publishDate, '2025-06-04');
    });

    test('copyWith returns new instance with updated tags', () {
      final epub = createEpubBook();
      final copied = epub.copyWith(tags: ['sci-fi', 'space']);
      expect(copied.tags, ['sci-fi', 'space']);
    });

    test('copyWith with no arguments returns identical copy', () {
      final epub = createEpubBook(
        publisher: 'Pub',
        language: 'en',
        tags: ['a'],
      );
      final copied = epub.copyWith();
      expect(copied, equals(epub));
    });

    test('copyWith updates multiple fields at once', () {
      final epub = createEpubBook();
      final copied = epub.copyWith(
        title: 'T',
        author: 'A',
        language: 'fr',
        tags: ['new'],
      );
      expect(copied.title, 'T');
      expect(copied.author, 'A');
      expect(copied.language, 'fr');
      expect(copied.tags, ['new']);
      // Unchanged
      expect(copied.coverPath, epub.coverPath);
      expect(copied.chapters, epub.chapters);
    });

    test('copyWith preserves nullable fields when not overridden', () {
      final epub = EpubBookEntity(
        title: 'T',
        author: 'A',
        coverPath: '/c.png',
        chapters: testChapters,
        publisher: 'Pub',
        description: 'Desc',
        language: 'en',
        isbn: '123',
        publishDate: '2024',
        tags: ['x'],
      );
      final copied = epub.copyWith(title: 'T2');
      expect(copied.publisher, 'Pub');
      expect(copied.description, 'Desc');
      expect(copied.language, 'en');
      expect(copied.isbn, '123');
      expect(copied.publishDate, '2024');
      expect(copied.tags, ['x']);
    });

    // ── Equality ─────────────────────────────────────────────────────

    test('equal when all fields match', () {
      final epub1 = createEpubBook(
        publisher: 'P',
        description: 'D',
        language: 'en',
        isbn: '978',
        publishDate: '2024',
        tags: ['a'],
      );
      final epub2 = createEpubBook(
        publisher: 'P',
        description: 'D',
        language: 'en',
        isbn: '978',
        publishDate: '2024',
        tags: ['a'],
      );
      expect(epub1, equals(epub2));
      expect(epub1.hashCode, equals(epub2.hashCode));
    });

    test('equal when both have null optional fields', () {
      final epub1 = createEpubBook();
      final epub2 = createEpubBook();
      expect(epub1, equals(epub2));
    });

    test('not equal when title differs', () {
      final epub1 = createEpubBook(title: 'A');
      final epub2 = createEpubBook(title: 'B');
      expect(epub1, isNot(equals(epub2)));
    });

    test('not equal when author differs', () {
      final epub1 = createEpubBook(author: 'A');
      final epub2 = createEpubBook(author: 'B');
      expect(epub1, isNot(equals(epub2)));
    });

    test('not equal when coverPath differs', () {
      final epub1 = createEpubBook(coverPath: '/a.png');
      final epub2 = createEpubBook(coverPath: '/b.png');
      expect(epub1, isNot(equals(epub2)));
    });

    test('not equal when chapters differ', () {
      final epub1 = createEpubBook(chapters: [const ChapterEntity(title: 'A', content: 'A')]);
      final epub2 = createEpubBook(chapters: [const ChapterEntity(title: 'B', content: 'B')]);
      expect(epub1, isNot(equals(epub2)));
    });

    test('not equal when chapters count differs', () {
      final epub1 = createEpubBook(chapters: [
        const ChapterEntity(title: 'A', content: 'A'),
      ]);
      final epub2 = createEpubBook(chapters: [
        const ChapterEntity(title: 'A', content: 'A'),
        const ChapterEntity(title: 'B', content: 'B'),
      ]);
      expect(epub1, isNot(equals(epub2)));
    });

    test('not equal when publisher differs', () {
      final epub1 = createEpubBook(publisher: 'A');
      final epub2 = createEpubBook(publisher: 'B');
      expect(epub1, isNot(equals(epub2)));
    });

    test('not equal when description differs', () {
      final epub1 = createEpubBook(description: 'A');
      final epub2 = createEpubBook(description: 'B');
      expect(epub1, isNot(equals(epub2)));
    });

    test('not equal when language differs', () {
      final epub1 = createEpubBook(language: 'en');
      final epub2 = createEpubBook(language: 'es');
      expect(epub1, isNot(equals(epub2)));
    });

    test('not equal when isbn differs', () {
      final epub1 = createEpubBook(isbn: '111');
      final epub2 = createEpubBook(isbn: '222');
      expect(epub1, isNot(equals(epub2)));
    });

    test('not equal when publishDate differs', () {
      final epub1 = createEpubBook(publishDate: '2024');
      final epub2 = createEpubBook(publishDate: '2025');
      expect(epub1, isNot(equals(epub2)));
    });

    test('not equal when tags differ', () {
      final epub1 = createEpubBook(tags: ['a']);
      final epub2 = createEpubBook(tags: ['b']);
      expect(epub1, isNot(equals(epub2)));
    });

    test('not equal when one has null tags and other has tags', () {
      final epub1 = createEpubBook();
      final epub2 = createEpubBook(tags: ['a']);
      expect(epub1, isNot(equals(epub2)));
    });

    test('not equal when one has null publisher and other has publisher', () {
      final epub1 = createEpubBook();
      final epub2 = createEpubBook(publisher: 'Pub');
      expect(epub1, isNot(equals(epub2)));
    });

    // ── Edge cases ───────────────────────────────────────────────────

    test('handles empty title', () {
      final epub = createEpubBook(title: '');
      expect(epub.title, '');
    });

    test('handles empty author', () {
      final epub = createEpubBook(author: '');
      expect(epub.author, '');
    });

    test('handles empty coverPath', () {
      final epub = createEpubBook(coverPath: '');
      expect(epub.coverPath, '');
    });

    test('handles empty publisher', () {
      final epub = createEpubBook(publisher: '');
      expect(epub.publisher, '');
    });

    test('handles empty description', () {
      final epub = createEpubBook(description: '');
      expect(epub.description, '');
    });

    test('handles empty language', () {
      final epub = createEpubBook(language: '');
      expect(epub.language, '');
    });

    test('handles empty isbn', () {
      final epub = createEpubBook(isbn: '');
      expect(epub.isbn, '');
    });

    test('handles empty publishDate', () {
      final epub = createEpubBook(publishDate: '');
      expect(epub.publishDate, '');
    });

    test('handles many chapters', () {
      final manyChapters = List.generate(
        1000,
        (i) => ChapterEntity(title: 'Ch $i', content: 'Content $i'),
      );
      final epub = createEpubBook(chapters: manyChapters);
      expect(epub.chapters.length, 1000);
    });

    test('handles many tags', () {
      final manyTags = List.generate(100, (i) => 'tag$i');
      final epub = createEpubBook(tags: manyTags);
      expect(epub.tags!.length, 100);
    });
  });
}
