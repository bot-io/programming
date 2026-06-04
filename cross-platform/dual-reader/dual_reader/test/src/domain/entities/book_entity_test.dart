import 'package:dual_reader/src/domain/entities/book_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BookEntity', () {
    // ── Helpers ──────────────────────────────────────────────────────
    final testDate = DateTime(2025, 6, 4, 12, 0);

    BookEntity createBook({
      String id = 'b1',
      String title = 'Test Book',
      String author = 'Author',
      String coverPath = '/covers/cover.png',
      String filePath = '/books/test.epub',
      DateTime? importedDate,
      int currentPage = 0,
      int totalPages = 0,
      int? paginationStatus = 0,
      double? paginationProgress = 0.0,
      String? detectedLanguage,
      int? languageDetectionConfidence,
      DateTime? languageDetectionDate,
    }) {
      return BookEntity(
        id: id,
        title: title,
        author: author,
        coverPath: coverPath,
        filePath: filePath,
        importedDate: importedDate ?? testDate,
        currentPage: currentPage,
        totalPages: totalPages,
        paginationStatus: paginationStatus,
        paginationProgress: paginationProgress,
        detectedLanguage: detectedLanguage,
        languageDetectionConfidence: languageDetectionConfidence,
        languageDetectionDate: languageDetectionDate,
      );
    }

    // ── Construction ─────────────────────────────────────────────────

    test('should construct with required fields and defaults', () {
      final book = createBook();

      expect(book.id, 'b1');
      expect(book.title, 'Test Book');
      expect(book.author, 'Author');
      expect(book.coverPath, '/covers/cover.png');
      expect(book.filePath, '/books/test.epub');
      expect(book.importedDate, testDate);
      expect(book.currentPage, 0);
      expect(book.totalPages, 0);
      expect(book.paginationStatus, 0);
      expect(book.paginationProgress, 0.0);
      expect(book.detectedLanguage, isNull);
      expect(book.languageDetectionConfidence, isNull);
      expect(book.languageDetectionDate, isNull);
    });

    test('should construct with all fields explicitly provided', () {
      final detectionDate = DateTime(2025, 5, 1);
      final book = BookEntity(
        id: 'b2',
        title: 'Advanced Dart',
        author: 'Jane Doe',
        coverPath: '/c/dart.png',
        filePath: '/b/dart.epub',
        importedDate: testDate,
        currentPage: 42,
        totalPages: 300,
        paginationStatus: 2,
        paginationProgress: 0.75,
        detectedLanguage: 'en',
        languageDetectionConfidence: 92,
        languageDetectionDate: detectionDate,
      );

      expect(book.id, 'b2');
      expect(book.title, 'Advanced Dart');
      expect(book.author, 'Jane Doe');
      expect(book.coverPath, '/c/dart.png');
      expect(book.filePath, '/b/dart.epub');
      expect(book.currentPage, 42);
      expect(book.totalPages, 300);
      expect(book.paginationStatus, 2);
      expect(book.paginationProgress, 0.75);
      expect(book.detectedLanguage, 'en');
      expect(book.languageDetectionConfidence, 92);
      expect(book.languageDetectionDate, detectionDate);
    });

    // ── status getter ────────────────────────────────────────────────

    test('status returns notStarted when paginationStatus is 0', () {
      final book = createBook(paginationStatus: 0);
      expect(book.status, PaginationStatus.notStarted);
    });

    test('status returns inProgress when paginationStatus is 1', () {
      final book = createBook(paginationStatus: 1);
      expect(book.status, PaginationStatus.inProgress);
    });

    test('status returns completed when paginationStatus is 2', () {
      final book = createBook(paginationStatus: 2);
      expect(book.status, PaginationStatus.completed);
    });

    test('status returns failed when paginationStatus is 3', () {
      final book = createBook(paginationStatus: 3);
      expect(book.status, PaginationStatus.failed);
    });

    test('status defaults to notStarted when paginationStatus is null', () {
      final book = createBook(paginationStatus: null);
      expect(book.status, PaginationStatus.notStarted);
    });

    // ── isPaginating ─────────────────────────────────────────────────

    test('isPaginating is true when status is inProgress', () {
      final book = createBook(paginationStatus: 1);
      expect(book.isPaginating, isTrue);
    });

    test('isPaginating is false when status is not inProgress', () {
      for (final status in [0, 2, 3]) {
        final book = createBook(paginationStatus: status);
        expect(book.isPaginating, isFalse, reason: 'status=$status');
      }
    });

    // ── isPaginated ──────────────────────────────────────────────────

    test('isPaginated is true when status is completed and totalPages > 0', () {
      final book = createBook(paginationStatus: 2, totalPages: 100);
      expect(book.isPaginated, isTrue);
    });

    test('isPaginated is false when status is completed but totalPages is 0', () {
      final book = createBook(paginationStatus: 2, totalPages: 0);
      expect(book.isPaginated, isFalse);
    });

    test('isPaginated is false when status is not completed', () {
      final book = createBook(paginationStatus: 1, totalPages: 100);
      expect(book.isPaginated, isFalse);
    });

    // ── canBeOpened ──────────────────────────────────────────────────

    test('canBeOpened is true when isPaginated', () {
      final book = createBook(paginationStatus: 2, totalPages: 100);
      expect(book.canBeOpened, isTrue);
    });

    test('canBeOpened is true when status is notStarted', () {
      final book = createBook(paginationStatus: 0);
      expect(book.canBeOpened, isTrue);
    });

    test('canBeOpened is false when status is inProgress', () {
      final book = createBook(paginationStatus: 1);
      expect(book.canBeOpened, isFalse);
    });

    test('canBeOpened is false when status is failed', () {
      final book = createBook(paginationStatus: 3);
      expect(book.canBeOpened, isFalse);
    });

    // ── hasLanguageDetection ─────────────────────────────────────────

    test('hasLanguageDetection returns false when detectedLanguage is null', () {
      final book = createBook();
      expect(book.hasLanguageDetection(), isFalse);
    });

    test('hasLanguageDetection returns false when detectedLanguage is empty', () {
      final book = createBook(detectedLanguage: '', languageDetectionConfidence: 80);
      expect(book.hasLanguageDetection(), isFalse);
    });

    test('hasLanguageDetection returns false when confidence is below default threshold', () {
      final book = createBook(detectedLanguage: 'en', languageDetectionConfidence: 49);
      expect(book.hasLanguageDetection(), isFalse);
    });

    test('hasLanguageDetection returns true when language present and confidence >= 50', () {
      final book = createBook(detectedLanguage: 'en', languageDetectionConfidence: 50);
      expect(book.hasLanguageDetection(), isTrue);
    });

    test('hasLanguageDetection respects custom minConfidence', () {
      final book = createBook(detectedLanguage: 'fr', languageDetectionConfidence: 70);
      expect(book.hasLanguageDetection(minConfidence: 80), isFalse);
      expect(book.hasLanguageDetection(minConfidence: 70), isTrue);
    });

    test('hasLanguageDetection returns true with high confidence and null detection date', () {
      final book = createBook(detectedLanguage: 'de', languageDetectionConfidence: 90);
      expect(book.hasLanguageDetection(), isTrue);
    });

    // ── hasRecentLanguageDetection ───────────────────────────────────

    test('hasRecentLanguageDetection returns false when date is null', () {
      final book = createBook();
      expect(book.hasRecentLanguageDetection(), isFalse);
    });

    test('hasRecentLanguageDetection returns true when date is within 7 days', () {
      final book = createBook(languageDetectionDate: DateTime.now().subtract(const Duration(days: 3)));
      expect(book.hasRecentLanguageDetection(), isTrue);
    });

    test('hasRecentLanguageDetection returns false when date is 7 or more days ago', () {
      final book = createBook(languageDetectionDate: DateTime.now().subtract(const Duration(days: 7)));
      expect(book.hasRecentLanguageDetection(), isFalse);
    });

    // ── copyWith ─────────────────────────────────────────────────────

    test('copyWith returns a new instance with updated id', () {
      final book = createBook();
      final copied = book.copyWith(id: 'b99');
      expect(copied.id, 'b99');
      expect(copied.title, book.title);
    });

    test('copyWith returns a new instance with updated title', () {
      final book = createBook();
      final copied = book.copyWith(title: 'New Title');
      expect(copied.title, 'New Title');
    });

    test('copyWith updates multiple fields at once', () {
      final book = createBook();
      final copied = book.copyWith(
        title: 'Updated',
        currentPage: 10,
        totalPages: 200,
        paginationStatus: 2,
      );
      expect(copied.title, 'Updated');
      expect(copied.currentPage, 10);
      expect(copied.totalPages, 200);
      expect(copied.paginationStatus, 2);
    });

    test('copyWith with no arguments returns identical copy', () {
      final book = createBook(
        detectedLanguage: 'en',
        languageDetectionConfidence: 90,
        languageDetectionDate: testDate,
      );
      final copied = book.copyWith();
      expect(copied, equals(book));
    });

    test('copyWith accepts PaginationStatus enum via status parameter', () {
      final book = createBook(paginationStatus: 0);
      final copied = book.copyWith(status: PaginationStatus.completed);
      expect(copied.paginationStatus, 2);
    });

    test('copyWith paginationStatus param takes precedence over status', () {
      // Both provided: paginationStatus wins because it's checked first
      final book = createBook(paginationStatus: 0);
      final copied = book.copyWith(
        paginationStatus: 1,
        status: PaginationStatus.completed,
      );
      // paginationStatus (1) wins over status?.index (2)
      expect(copied.paginationStatus, 1);
    });

    test('copyWith preserves language fields when not changed', () {
      final book = createBook(
        detectedLanguage: 'en',
        languageDetectionConfidence: 80,
        languageDetectionDate: testDate,
      );
      final copied = book.copyWith(title: 'Changed');
      expect(copied.detectedLanguage, 'en');
      expect(copied.languageDetectionConfidence, 80);
      expect(copied.languageDetectionDate, testDate);
    });

    test('copyWith clearLanguageDetection clears all language fields', () {
      final book = createBook(
        detectedLanguage: 'en',
        languageDetectionConfidence: 80,
        languageDetectionDate: testDate,
      );
      final copied = book.copyWith(clearLanguageDetection: true);
      expect(copied.detectedLanguage, isNull);
      expect(copied.languageDetectionConfidence, isNull);
      expect(copied.languageDetectionDate, isNull);
    });

    test('copyWith clearLanguageDetection=false preserves language fields', () {
      final book = createBook(
        detectedLanguage: 'en',
        languageDetectionConfidence: 80,
        languageDetectionDate: testDate,
      );
      final copied = book.copyWith(clearLanguageDetection: false);
      expect(copied.detectedLanguage, 'en');
    });

    // ── Equality ─────────────────────────────────────────────────────

    test('equal when all fields match', () {
      final book1 = createBook();
      final book2 = createBook();
      expect(book1, equals(book2));
      expect(book1.hashCode, equals(book2.hashCode));
    });

    test('not equal when id differs', () {
      final book1 = createBook(id: 'a');
      final book2 = createBook(id: 'b');
      expect(book1, isNot(equals(book2)));
    });

    test('not equal when title differs', () {
      final book1 = createBook(title: 'A');
      final book2 = createBook(title: 'B');
      expect(book1, isNot(equals(book2)));
    });

    test('not equal when currentPage differs', () {
      final book1 = createBook(currentPage: 1);
      final book2 = createBook(currentPage: 2);
      expect(book1, isNot(equals(book2)));
    });

    test('not equal when detectedLanguage differs', () {
      final book1 = createBook(detectedLanguage: 'en');
      final book2 = createBook(detectedLanguage: 'es');
      expect(book1, isNot(equals(book2)));
    });

    test('not equal when one has null detectedLanguage and other has value', () {
      final book1 = createBook();
      final book2 = createBook(detectedLanguage: 'en');
      expect(book1, isNot(equals(book2)));
    });

    // ── Edge cases ───────────────────────────────────────────────────

    test('handles empty strings for required fields', () {
      final book = createBook(id: '', title: '', author: '', coverPath: '', filePath: '');
      expect(book.id, '');
      expect(book.title, '');
      expect(book.author, '');
    });

    test('handles zero paginationProgress', () {
      final book = createBook(paginationProgress: 0.0);
      expect(book.paginationProgress, 0.0);
    });

    test('handles full paginationProgress', () {
      final book = createBook(paginationProgress: 1.0);
      expect(book.paginationProgress, 1.0);
    });

    test('handles large totalPages value', () {
      final book = createBook(totalPages: 999999);
      expect(book.totalPages, 999999);
    });
  });

  group('PaginationStatus', () {
    test('has exactly 4 values', () {
      expect(PaginationStatus.values.length, 4);
    });

    test('values are in correct order', () {
      expect(PaginationStatus.values[0], PaginationStatus.notStarted);
      expect(PaginationStatus.values[1], PaginationStatus.inProgress);
      expect(PaginationStatus.values[2], PaginationStatus.completed);
      expect(PaginationStatus.values[3], PaginationStatus.failed);
    });

    test('index property is correct', () {
      expect(PaginationStatus.notStarted.index, 0);
      expect(PaginationStatus.inProgress.index, 1);
      expect(PaginationStatus.completed.index, 2);
      expect(PaginationStatus.failed.index, 3);
    });
  });
}
