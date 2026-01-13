import 'package:flutter_test/flutter_test.dart';
import 'package:dual_reader/src/domain/entities/translation_chunk.dart';
import 'package:dual_reader/src/core/utils/page_markers.dart';

void main() {
  group('TranslationChunk', () {
    late TranslationChunk chunk;

    setUp(() {
      // Use markers for page boundaries
      final page0Marked = PageMarkers.insertMarkers('Page 0 text', 0);
      final page1Marked = PageMarkers.insertMarkers('Page 1 text', 1);
      final page2Marked = PageMarkers.insertMarkers('Page 2 text', 2);

      chunk = TranslationChunk(
        chunkId: 'test_chunk_0_2_es',
        bookId: 'test_book',
        startPageIndex: 0,
        endPageIndex: 2,
        originalText: '$page0Marked\n\n$page1Marked\n\n$page2Marked',
        pageBreakOffsets: [11, 24, 37], // End of each page (before \n\n separator)
        targetLanguage: 'es',
      );
    });

    test('should create chunk with correct properties', () {
      expect(chunk.chunkId, 'test_chunk_0_2_es');
      expect(chunk.bookId, 'test_book');
      expect(chunk.startPageIndex, 0);
      expect(chunk.endPageIndex, 2);
      expect(chunk.pageCount, 3);
      expect(chunk.isTranslated, false);
      expect(chunk.translatedText, isNull);
      expect(chunk.translatedAt, isNull);
    });

    test('should calculate page count correctly', () {
      expect(chunk.pageCount, 3);

      final singlePageChunk = TranslationChunk(
        chunkId: 'single_5_5_es',
        bookId: 'test',
        startPageIndex: 5,
        endPageIndex: 5,
        originalText: PageMarkers.insertMarkers('Single page', 5),
        pageBreakOffsets: [11],
        targetLanguage: 'es',
      );
      expect(singlePageChunk.pageCount, 1);
    });

    test('should indicate translated status correctly', () {
      expect(chunk.isTranslated, false);

      chunk.translatedText = 'Translated text';
      chunk.translatedAt = DateTime.now();
      expect(chunk.isTranslated, true);
    });

    test('should extract original page text correctly', () {
      final page0 = chunk.extractOriginalPage(0);
      expect(page0, 'Page 0 text');

      final page1 = chunk.extractOriginalPage(1);
      expect(page1, 'Page 1 text');

      final page2 = chunk.extractOriginalPage(2);
      expect(page2, 'Page 2 text');
    });

    test('should throw when extracting page outside range', () {
      expect(
        () => chunk.extractOriginalPage(3),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('not in chunk'),
        )),
      );

      expect(
        () => chunk.extractOriginalPage(-1),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('should extract translated page using paragraph counting', () {
      // Set up a chunk with paragraphs using markers
      // Page 0: "Para 1\n\nPara 2"
      // Page 1: "Para 3\n\nPara 4"
      final page0Marked = PageMarkers.insertMarkers('Para 1\n\nPara 2', 0);
      final page1Marked = PageMarkers.insertMarkers('Para 3\n\nPara 4', 1);

      final chunkWithParagraphs = TranslationChunk(
        chunkId: 'para_test_0_1_es',
        bookId: 'test',
        startPageIndex: 0,
        endPageIndex: 1,
        originalText: '$page0Marked\n\n$page1Marked',
        pageBreakOffsets: [14, 30], // Cumulative offsets: 14, 14+2+14=30
        targetLanguage: 'es',
      );

      // Simulate translation with same paragraph structure and markers
      final translatedPage0Marked = PageMarkers.insertMarkers('Trad 1\n\nTrad 2', 0);
      final translatedPage1Marked = PageMarkers.insertMarkers('Trad 3\n\nTrad 4', 1);
      chunkWithParagraphs.translatedText = '$translatedPage0Marked\n\n$translatedPage1Marked';

      // Extract page 0 (should get first 2 paragraphs)
      final page0Translation = chunkWithParagraphs.extractTranslatedPage(0);
      expect(page0Translation, 'Trad 1\n\nTrad 2');

      // Extract page 1 (should get last 2 paragraphs)
      final page1Translation = chunkWithParagraphs.extractTranslatedPage(1);
      expect(page1Translation, 'Trad 3\n\nTrad 4');
    });

    test('should throw when extracting translated page before translation', () {
      expect(
        () => chunk.extractTranslatedPage(0),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('not been translated'),
        )),
      );
    });

    test('should create copy with updated fields', () {
      final now = DateTime.now();
      final copied = chunk.copyWith(
        translatedText: 'New translation',
        translatedAt: now,
      );

      expect(copied.chunkId, chunk.chunkId);
      expect(copied.bookId, chunk.bookId);
      expect(copied.translatedText, 'New translation');
      expect(copied.translatedAt, now);
      expect(copied.isTranslated, true);

      // Original should be unchanged
      expect(chunk.translatedText, isNull);
      expect(chunk.isTranslated, false);
    });

    test('should handle paragraphs with double newlines', () {
      final multiParaChunk = TranslationChunk(
        chunkId: 'multi_0_0_es',
        bookId: 'test',
        startPageIndex: 0,
        endPageIndex: 0,
        originalText: PageMarkers.insertMarkers('First paragraph\n\nSecond paragraph\n\nThird paragraph', 0),
        pageBreakOffsets: [50], // Total length of the text
        targetLanguage: 'es',
      );

      multiParaChunk.translatedText = PageMarkers.insertMarkers('Primero\n\nSegundo\n\nTercero', 0);

      final extracted = multiParaChunk.extractTranslatedPage(0);
      expect(extracted, 'Primero\n\nSegundo\n\nTercero');
    });

    test('should handle empty page gracefully', () {
      final emptyChunk = TranslationChunk(
        chunkId: 'empty_0_0_es',
        bookId: 'test',
        startPageIndex: 0,
        endPageIndex: 0,
        originalText: PageMarkers.insertMarkers('', 0),
        pageBreakOffsets: [0],
        targetLanguage: 'es',
      );

      emptyChunk.translatedText = PageMarkers.insertMarkers('', 0);
      final extracted = emptyChunk.extractTranslatedPage(0);
      expect(extracted, '');
    });

    test('toString should provide useful information', () {
      final str = chunk.toString();
      expect(str, contains('test_chunk_0_2_es'));
      expect(str, contains('test_book'));
      expect(str, contains('0-2'));
      expect(str, contains('isTranslated'));
    });
  });

  group('TranslationChunk Edge Cases', () {
    test('should handle single paragraph pages', () {
      final page0Marked = PageMarkers.insertMarkers('Single para page 0', 0);
      final page1Marked = PageMarkers.insertMarkers('Single para page 1', 1);

      final chunk = TranslationChunk(
        chunkId: 'single_para_0_1_es',
        bookId: 'test',
        startPageIndex: 0,
        endPageIndex: 1,
        originalText: '$page0Marked\n\n$page1Marked',
        pageBreakOffsets: [18, 38], // End of each page content (before \n\n separator)
        targetLanguage: 'es',
      );

      final translatedPage0Marked = PageMarkers.insertMarkers('Traduccion pagina 0', 0);
      final translatedPage1Marked = PageMarkers.insertMarkers('Traduccion pagina 1', 1);
      chunk.translatedText = '$translatedPage0Marked\n\n$translatedPage1Marked';

      final page0 = chunk.extractTranslatedPage(0);
      final page1 = chunk.extractTranslatedPage(1);

      expect(page0, 'Traduccion pagina 0');
      expect(page1, 'Traduccion pagina 1');
    });

    test('should handle pages with varying paragraph counts', () {
      // Page 0: 3 paragraphs, Page 1: 1 paragraph, Page 2: 2 paragraphs
      final page0Marked = PageMarkers.insertMarkers('P0-P1\n\nP0-P2\n\nP0-P3', 0);
      final page1Marked = PageMarkers.insertMarkers('P1-P1', 1);
      final page2Marked = PageMarkers.insertMarkers('P2-P1\n\nP2-P2', 2);

      final chunk = TranslationChunk(
        chunkId: 'varying_0_2_es',
        bookId: 'test',
        startPageIndex: 0,
        endPageIndex: 2,
        originalText: '$page0Marked\n\n$page1Marked\n\n$page2Marked',
        pageBreakOffsets: [19, 26, 40], // Cumulative offsets
        targetLanguage: 'es',
      );

      final translatedPage0Marked = PageMarkers.insertMarkers('T0-1\n\nT0-2\n\nT0-3', 0);
      final translatedPage1Marked = PageMarkers.insertMarkers('T1-1', 1);
      final translatedPage2Marked = PageMarkers.insertMarkers('T2-1\n\nT2-2', 2);
      chunk.translatedText = '$translatedPage0Marked\n\n$translatedPage1Marked\n\n$translatedPage2Marked';

      final page0 = chunk.extractTranslatedPage(0);
      final page1 = chunk.extractTranslatedPage(1);
      final page2 = chunk.extractTranslatedPage(2);

      expect(page0, 'T0-1\n\nT0-2\n\nT0-3');
      expect(page1, 'T1-1');
      expect(page2, 'T2-1\n\nT2-2');
    });

    test('should handle very long chunks', () {
      final longText = List.generate(100, (i) => 'Paragraph $i').join('\n\n');
      final chunk = TranslationChunk(
        chunkId: 'long_0_0_es',
        bookId: 'test',
        startPageIndex: 0,
        endPageIndex: 0,
        originalText: PageMarkers.insertMarkers(longText, 0),
        pageBreakOffsets: [longText.length],
        targetLanguage: 'es',
      );

      expect(chunk.originalText.length, greaterThan(1000));
    });
  });
}
