import 'package:dual_reader/src/domain/entities/chapter_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChapterEntity', () {
    // ── Helpers ──────────────────────────────────────────────────────

    ChapterEntity createChapter({
      String title = 'Chapter 1',
      String content = 'Once upon a time...',
      int? startIndex,
      int? endIndex,
      int? level,
    }) {
      return ChapterEntity(
        title: title,
        content: content,
        startIndex: startIndex,
        endIndex: endIndex,
        level: level,
      );
    }

    // ── Construction ─────────────────────────────────────────────────

    test('should construct with required fields only', () {
      final chapter = createChapter();

      expect(chapter.title, 'Chapter 1');
      expect(chapter.content, 'Once upon a time...');
      expect(chapter.startIndex, isNull);
      expect(chapter.endIndex, isNull);
      expect(chapter.level, isNull);
    });

    test('should construct with all fields provided', () {
      final chapter = ChapterEntity(
        title: 'Introduction',
        content: 'Welcome to the book.',
        startIndex: 0,
        endIndex: 500,
        level: 1,
      );

      expect(chapter.title, 'Introduction');
      expect(chapter.content, 'Welcome to the book.');
      expect(chapter.startIndex, 0);
      expect(chapter.endIndex, 500);
      expect(chapter.level, 1);
    });

    test('should construct with nullable fields set to zero', () {
      final chapter = ChapterEntity(
        title: 'Ch',
        content: 'Text',
        startIndex: 0,
        endIndex: 0,
        level: 0,
      );

      expect(chapter.startIndex, 0);
      expect(chapter.endIndex, 0);
      expect(chapter.level, 0);
    });

    // ── copyWith ─────────────────────────────────────────────────────

    test('copyWith returns new instance with updated title', () {
      final chapter = createChapter();
      final copied = chapter.copyWith(title: 'New Title');
      expect(copied.title, 'New Title');
      expect(copied.content, chapter.content);
    });

    test('copyWith returns new instance with updated content', () {
      final chapter = createChapter();
      final copied = chapter.copyWith(content: 'New content');
      expect(copied.content, 'New content');
      expect(copied.title, chapter.title);
    });

    test('copyWith returns new instance with updated startIndex', () {
      final chapter = createChapter();
      final copied = chapter.copyWith(startIndex: 100);
      expect(copied.startIndex, 100);
    });

    test('copyWith returns new instance with updated endIndex', () {
      final chapter = createChapter();
      final copied = chapter.copyWith(endIndex: 999);
      expect(copied.endIndex, 999);
    });

    test('copyWith returns new instance with updated level', () {
      final chapter = createChapter();
      final copied = chapter.copyWith(level: 3);
      expect(copied.level, 3);
    });

    test('copyWith with no arguments returns identical copy', () {
      final chapter = ChapterEntity(
        title: 'Test',
        content: 'Body',
        startIndex: 10,
        endIndex: 20,
        level: 2,
      );
      final copied = chapter.copyWith();
      expect(copied, equals(chapter));
    });

    test('copyWith updates multiple fields at once', () {
      final chapter = createChapter();
      final copied = chapter.copyWith(
        title: 'Updated',
        content: 'Updated content',
        startIndex: 50,
        endIndex: 150,
        level: 2,
      );
      expect(copied.title, 'Updated');
      expect(copied.content, 'Updated content');
      expect(copied.startIndex, 50);
      expect(copied.endIndex, 150);
      expect(copied.level, 2);
    });

    test('copyWith preserves original nullable fields when not overridden', () {
      final chapter = ChapterEntity(
        title: 'Test',
        content: 'Body',
        startIndex: 10,
        endIndex: 20,
        level: 2,
      );
      final copied = chapter.copyWith(title: 'New');
      expect(copied.startIndex, 10);
      expect(copied.endIndex, 20);
      expect(copied.level, 2);
    });

    // ── Equality ─────────────────────────────────────────────────────

    test('equal when all fields match', () {
      final chapter1 = ChapterEntity(
        title: 'A',
        content: 'B',
        startIndex: 0,
        endIndex: 10,
        level: 1,
      );
      final chapter2 = ChapterEntity(
        title: 'A',
        content: 'B',
        startIndex: 0,
        endIndex: 10,
        level: 1,
      );
      expect(chapter1, equals(chapter2));
      expect(chapter1.hashCode, equals(chapter2.hashCode));
    });

    test('equal when both have null optional fields', () {
      final chapter1 = ChapterEntity(title: 'A', content: 'B');
      final chapter2 = ChapterEntity(title: 'A', content: 'B');
      expect(chapter1, equals(chapter2));
    });

    test('not equal when title differs', () {
      final chapter1 = createChapter(title: 'Ch1');
      final chapter2 = createChapter(title: 'Ch2');
      expect(chapter1, isNot(equals(chapter2)));
    });

    test('not equal when content differs', () {
      final chapter1 = createChapter(content: 'abc');
      final chapter2 = createChapter(content: 'def');
      expect(chapter1, isNot(equals(chapter2)));
    });

    test('not equal when startIndex differs', () {
      final chapter1 = createChapter(startIndex: 0);
      final chapter2 = createChapter(startIndex: 1);
      expect(chapter1, isNot(equals(chapter2)));
    });

    test('not equal when endIndex differs', () {
      final chapter1 = createChapter(endIndex: 100);
      final chapter2 = createChapter(endIndex: 200);
      expect(chapter1, isNot(equals(chapter2)));
    });

    test('not equal when level differs', () {
      final chapter1 = createChapter(level: 1);
      final chapter2 = createChapter(level: 2);
      expect(chapter1, isNot(equals(chapter2)));
    });

    test('not equal when one has null startIndex and other has value', () {
      final chapter1 = createChapter();
      final chapter2 = createChapter(startIndex: 0);
      expect(chapter1, isNot(equals(chapter2)));
    });

    test('not equal when one has null endIndex and other has value', () {
      final chapter1 = createChapter();
      final chapter2 = createChapter(endIndex: 10);
      expect(chapter1, isNot(equals(chapter2)));
    });

    test('not equal when one has null level and other has value', () {
      final chapter1 = createChapter();
      final chapter2 = createChapter(level: 0);
      expect(chapter1, isNot(equals(chapter2)));
    });

    // ── Edge cases ───────────────────────────────────────────────────

    test('handles empty title', () {
      final chapter = createChapter(title: '');
      expect(chapter.title, '');
    });

    test('handles empty content', () {
      final chapter = createChapter(content: '');
      expect(chapter.content, '');
    });

    test('handles large index values', () {
      final chapter = createChapter(startIndex: 999999, endIndex: 9999999);
      expect(chapter.startIndex, 999999);
      expect(chapter.endIndex, 9999999);
    });

    test('handles very long content', () {
      final longContent = 'A' * 100000;
      final chapter = createChapter(content: longContent);
      expect(chapter.content.length, 100000);
    });

    test('handles level zero', () {
      final chapter = createChapter(level: 0);
      expect(chapter.level, 0);
    });

    test('handles negative startIndex', () {
      // Entity does not validate, so it should accept it
      final chapter = createChapter(startIndex: -1);
      expect(chapter.startIndex, -1);
    });
  });
}
