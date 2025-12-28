import 'package:flutter_test/flutter_test.dart';
import 'package:dual_reader/models/page_content.dart';

void main() {
  group('PageContent', () {
    test('creates with required fields', () {
      final page = PageContent(
        originalText: 'Test text',
        pageNumber: 1,
        totalPages: 10,
      );

      expect(page.originalText, 'Test text');
      expect(page.translatedText, isNull);
      expect(page.pageNumber, 1);
      expect(page.totalPages, 10);
      expect(page.isTranslated, false);
    });

    test('creates with translated text', () {
      final page = PageContent(
        originalText: 'Hello',
        translatedText: 'Hola',
        pageNumber: 1,
        totalPages: 5,
        isTranslated: true,
      );

      expect(page.originalText, 'Hello');
      expect(page.translatedText, 'Hola');
      expect(page.isTranslated, true);
    });

    test('copyWith creates new instance with updated values', () {
      final original = PageContent(
        originalText: 'Original',
        pageNumber: 1,
        totalPages: 10,
      );

      final updated = original.copyWith(
        translatedText: 'Traducido',
        isTranslated: true,
        pageNumber: 2,
      );

      // Original unchanged
      expect(original.translatedText, isNull);
      expect(original.isTranslated, false);
      expect(original.pageNumber, 1);

      // Updated has new values
      expect(updated.translatedText, 'Traducido');
      expect(updated.isTranslated, true);
      expect(updated.pageNumber, 2);

      // Other values preserved
      expect(updated.originalText, original.originalText);
      expect(updated.totalPages, original.totalPages);
    });

    test('copyWith preserves all values when no parameters provided', () {
      final original = PageContent(
        originalText: 'Test',
        translatedText: 'Prueba',
        pageNumber: 3,
        totalPages: 20,
        isTranslated: true,
      );

      final copied = original.copyWith();

      expect(copied.originalText, original.originalText);
      expect(copied.translatedText, original.translatedText);
      expect(copied.pageNumber, original.pageNumber);
      expect(copied.totalPages, original.totalPages);
      expect(copied.isTranslated, original.isTranslated);
    });

    test('copyWith can clear translated text', () {
      final original = PageContent(
        originalText: 'Test',
        translatedText: 'Prueba',
        pageNumber: 1,
        totalPages: 10,
        isTranslated: true,
      );

      final cleared = original.copyWith(
        translatedText: null,
        isTranslated: false,
      );

      expect(cleared.translatedText, isNull);
      expect(cleared.isTranslated, false);
      expect(cleared.originalText, original.originalText);
    });

    test('handles empty text', () {
      final page = PageContent(
        originalText: '',
        pageNumber: 1,
        totalPages: 1,
      );

      expect(page.originalText, '');
      expect(page.pageNumber, 1);
      expect(page.totalPages, 1);
    });

    test('handles large page numbers', () {
      final page = PageContent(
        originalText: 'Test',
        pageNumber: 1000,
        totalPages: 2000,
      );

      expect(page.pageNumber, 1000);
      expect(page.totalPages, 2000);
    });
  });
}
