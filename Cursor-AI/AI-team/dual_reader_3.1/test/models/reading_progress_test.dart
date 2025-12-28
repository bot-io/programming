import 'package:flutter_test/flutter_test.dart';
import 'package:dual_reader/models/reading_progress.dart';

void main() {
  group('ReadingProgress', () {
    test('creates with required fields', () {
      final now = DateTime.now();
      final progress = ReadingProgress(
        bookId: 'book1',
        currentPage: 5,
        totalPages: 100,
        progress: 0.05,
        lastReadAt: now,
      );

      expect(progress.bookId, 'book1');
      expect(progress.currentPage, 5);
      expect(progress.totalPages, 100);
      expect(progress.progress, 0.05);
      expect(progress.lastReadAt, now);
      expect(progress.currentChapterId, isNull);
    });

    test('creates with optional chapter ID', () {
      final now = DateTime.now();
      final progress = ReadingProgress(
        bookId: 'book1',
        currentPage: 10,
        totalPages: 200,
        progress: 0.05,
        lastReadAt: now,
        currentChapterId: 'chapter_3',
      );

      expect(progress.currentChapterId, 'chapter_3');
    });

    test('copyWith creates new instance with updated values', () {
      final original = ReadingProgress(
        bookId: 'book1',
        currentPage: 5,
        totalPages: 100,
        progress: 0.05,
        lastReadAt: DateTime.now(),
      );

      final updated = original.copyWith(
        currentPage: 10,
        progress: 0.10,
        currentChapterId: 'chapter_2',
      );

      // Original unchanged
      expect(original.currentPage, 5);
      expect(original.progress, 0.05);
      expect(original.currentChapterId, isNull);

      // Updated has new values
      expect(updated.currentPage, 10);
      expect(updated.progress, 0.10);
      expect(updated.currentChapterId, 'chapter_2');

      // Other values preserved
      expect(updated.bookId, original.bookId);
      expect(updated.totalPages, original.totalPages);
      expect(updated.lastReadAt, original.lastReadAt);
    });

    test('copyWith preserves all values when no parameters provided', () {
      final original = ReadingProgress(
        bookId: 'book1',
        currentPage: 5,
        totalPages: 100,
        progress: 0.05,
        lastReadAt: DateTime.now(),
        currentChapterId: 'chapter_1',
      );

      final copied = original.copyWith();

      expect(copied.bookId, original.bookId);
      expect(copied.currentPage, original.currentPage);
      expect(copied.totalPages, original.totalPages);
      expect(copied.progress, original.progress);
      expect(copied.lastReadAt, original.lastReadAt);
      expect(copied.currentChapterId, original.currentChapterId);
    });

    test('handles progress at start (0.0)', () {
      final progress = ReadingProgress(
        bookId: 'book1',
        currentPage: 1,
        totalPages: 100,
        progress: 0.0,
        lastReadAt: DateTime.now(),
      );

      expect(progress.progress, 0.0);
      expect(progress.currentPage, 1);
    });

    test('handles progress at end (1.0)', () {
      final progress = ReadingProgress(
        bookId: 'book1',
        currentPage: 100,
        totalPages: 100,
        progress: 1.0,
        lastReadAt: DateTime.now(),
      );

      expect(progress.progress, 1.0);
      expect(progress.currentPage, 100);
    });

    test('handles progress in middle', () {
      final progress = ReadingProgress(
        bookId: 'book1',
        currentPage: 50,
        totalPages: 100,
        progress: 0.5,
        lastReadAt: DateTime.now(),
      );

      expect(progress.progress, 0.5);
      expect(progress.currentPage, 50);
    });
  });
}
