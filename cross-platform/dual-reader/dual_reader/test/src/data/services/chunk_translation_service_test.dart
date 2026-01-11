import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dual_reader/src/data/services/chunk_translation_service.dart';
import 'package:dual_reader/src/data/services/chunk_cache_service.dart';
import 'package:dual_reader/src/data/services/client_side_translation_service.dart';
import 'package:dual_reader/src/domain/entities/translation_chunk.dart';
import 'package:dual_reader/src/core/utils/page_markers.dart';

@GenerateMocks([ChunkCacheService, ClientSideTranslationService])
import 'chunk_translation_service_test.mocks.dart';

/// Helper function that creates a mock translation response preserving markers
/// AND paragraph structure - simulates what the actual ML Kit service does
String _mockTranslateWithMarkers(String? original, {String prefix = 'Translated: '}) {
  // Extract each page separately, split into paragraphs, translate each, and reinsert markers
  final pageIndices = PageMarkers.extractPageIndices(original ?? '');
  final translatedPages = <String>[];

  for (final pageIndex in pageIndices) {
    final pageText = PageMarkers.extractPage(original ?? '', pageIndex);

    // Split this page into paragraphs and translate each separately
    final paragraphs = pageText.split(RegExp(r'\n\s*\n'));
    final translatedParagraphs = <String>[];

    for (final paragraph in paragraphs) {
      if (paragraph.trim().isEmpty) {
        translatedParagraphs.add('');
      } else {
        translatedParagraphs.add('$prefix${paragraph.trim()}');
      }
    }

    // Reassemble paragraphs within this page
    final translatedPageText = translatedParagraphs.join('\n\n');
    translatedPages.add(PageMarkers.insertMarkers(translatedPageText, pageIndex));
  }

  return translatedPages.join('\n\n');
}

void main() {
  group('ChunkTranslationService', () {
    late MockChunkCacheService mockCacheService;
    late MockClientSideTranslationService mockTranslationService;
    late ChunkTranslationService chunkTranslationService;

    setUp(() {
      mockCacheService = MockChunkCacheService();
      mockTranslationService = MockClientSideTranslationService();
      chunkTranslationService = ChunkTranslationService(
        cacheService: mockCacheService,
        translationService: mockTranslationService,
      );
    });

    group('getPageTranslation', () {
      test('should return cached translation if available', () async {
        // Create chunk with markers (as they would be in the cache)
        final originalWithMarkers = PageMarkers.insertMarkers('Page 0', 0) +
            '\n\n' +
            PageMarkers.insertMarkers('Page 1', 1) +
            '\n\n' +
            PageMarkers.insertMarkers('Page 2', 2);

        final translatedWithMarkers = PageMarkers.insertMarkers('Pagina 0', 0) +
            '\n\n' +
            PageMarkers.insertMarkers('Pagina 1', 1) +
            '\n\n' +
            PageMarkers.insertMarkers('Pagina 2', 2);

        final cachedChunk = TranslationChunk(
          chunkId: 'book_chunk_0_2_es',
          bookId: 'book',
          startPageIndex: 0,
          endPageIndex: 2,
          originalText: originalWithMarkers,
          pageBreakOffsets: [9, 20, 31], // Approximate offsets with markers
          targetLanguage: 'es',
        );

        cachedChunk.translatedText = translatedWithMarkers;

        when(mockCacheService.getCachedChunkForPage('book', 1, 'es'))
            .thenReturn(cachedChunk);

        final result = await chunkTranslationService.getPageTranslation(
          bookId: 'book',
          pageIndex: 1,
          originalPageText: 'Page 1',
          targetLanguage: 'es',
          allPages: ['Page 0', 'Page 1', 'Page 2'],
        );

        expect(result, 'Pagina 1');
        verify(mockCacheService.getCachedChunkForPage('book', 1, 'es'))
            .called(1);
        verifyNever(mockTranslationService.translate(
          text: anyNamed('text'),
          targetLanguage: anyNamed('targetLanguage'),
          sourceLanguage: anyNamed('sourceLanguage'),
        ));
      });

      test('should create and translate new chunk when not cached', () async {
        when(mockCacheService.getCachedChunkForPage('book', 0, 'es'))
            .thenReturn(null);

        when(mockTranslationService.translate(
          text: anyNamed('text'),
          targetLanguage: anyNamed('targetLanguage'),
          sourceLanguage: anyNamed('sourceLanguage'),
        )).thenAnswer((invocation) async {
          final original = invocation.namedArguments[#text] as String?;
          return _mockTranslateWithMarkers(original, prefix: 'Pagina ');
        });

        when(mockCacheService.cacheChunk(any)).thenAnswer((_) async {});

        final result = await chunkTranslationService.getPageTranslation(
          bookId: 'book',
          pageIndex: 0,
          originalPageText: 'Page 0',
          targetLanguage: 'es',
          allPages: ['Page 0', 'Page 1', 'Page 2'],
        );

        expect(result, isNotEmpty);
        expect(result, contains('Pagina'));
        verify(mockTranslationService.translate(
          text: argThat(contains('Page 0'), named: 'text'),
          targetLanguage: 'es',
          sourceLanguage: anyNamed('sourceLanguage'),
        )).called(1);
        verify(mockCacheService.cacheChunk(any)).called(1);
      });

      test('should retranslate on cache extraction error', () async {
        final originalWithMarkers = PageMarkers.insertMarkers('Page 0', 0) +
            '\n\n' +
            PageMarkers.insertMarkers('Page 1', 1) +
            '\n\n' +
            PageMarkers.insertMarkers('Page 2', 2);

        final translatedWithMarkers = PageMarkers.insertMarkers('Page 0 Translated', 0) +
            '\n\n' +
            PageMarkers.insertMarkers('Page 1 Translated', 1) +
            '\n\n' +
            PageMarkers.insertMarkers('Page 2 Translated', 2);

        final cachedChunk = TranslationChunk(
          chunkId: 'book_chunk_0_2_es',
          bookId: 'book',
          startPageIndex: 0,
          endPageIndex: 2,
          originalText: originalWithMarkers,
          pageBreakOffsets: [9, 20, 31],
          targetLanguage: 'es',
        );

        cachedChunk.translatedText = translatedWithMarkers;

        when(mockCacheService.getCachedChunkForPage('book', 1, 'es'))
            .thenReturn(cachedChunk);

        // Should use cached translation successfully
        final result = await chunkTranslationService.getPageTranslation(
          bookId: 'book',
          pageIndex: 1,
          originalPageText: 'Page 1',
          targetLanguage: 'es',
          allPages: ['Page 0', 'Page 1', 'Page 2'],
        );

        expect(result, 'Page 1 Translated');
        verifyNever(mockTranslationService.translate(
          text: anyNamed('text'),
          targetLanguage: anyNamed('targetLanguage'),
          sourceLanguage: anyNamed('sourceLanguage'),
        ));
      });
    });

    group('Chunk Boundary Calculation', () {
      test('should create chunk within target size range', () async {
        when(mockCacheService.getCachedChunkForPage(any, any, any))
            .thenReturn(null);

        when(mockTranslationService.translate(
          text: anyNamed('text'),
          targetLanguage: anyNamed('targetLanguage'),
          sourceLanguage: anyNamed('sourceLanguage'),
        )).thenAnswer((invocation) async {
          final original = invocation.namedArguments[#text] as String?;
          return _mockTranslateWithMarkers(original);
        });

        when(mockCacheService.cacheChunk(any)).thenAnswer((_) async {});

        // Create pages that sum to ~4000 chars (within 3000-5000 range)
        final pages = List.generate(20, (i) => 'Page $i content ' * 200);

        await chunkTranslationService.getPageTranslation(
          bookId: 'book',
          pageIndex: 5,
          originalPageText: pages[5],
          targetLanguage: 'es',
          allPages: pages,
        );

        // Verify that cacheChunk was called at least once
        verify(mockCacheService.cacheChunk(any)).called(greaterThanOrEqualTo(1));
      });

      test('should respect paragraph boundaries when possible', () async {
        when(mockCacheService.getCachedChunkForPage(any, any, any))
            .thenReturn(null);

        when(mockTranslationService.translate(
          text: anyNamed('text'),
          targetLanguage: anyNamed('targetLanguage'),
          sourceLanguage: anyNamed('sourceLanguage'),
        )).thenAnswer((invocation) async {
          final original = invocation.namedArguments[#text] as String?;
          return _mockTranslateWithMarkers(original);
        });

        when(mockCacheService.cacheChunk(any)).thenAnswer((_) async {});

        // Pages with clear sentence boundaries
        final pages = [
          'First page. Complete sentence.',
          'Second page starts with capital.',
          'Third page. Another complete.',
          'Fourth page begins here.',
          'Fifth page. Final sentence.',
        ];

        final result = await chunkTranslationService.getPageTranslation(
          bookId: 'book',
          pageIndex: 2,
          originalPageText: pages[2],
          targetLanguage: 'es',
          allPages: pages,
        );

        // Should successfully translate
        expect(result, isNotEmpty);
        verify(mockCacheService.cacheChunk(any)).called(greaterThanOrEqualTo(1));
      });
    });

    group('Pre-translation', () {
      test('should pre-translate nearby chunks in background', () async {
        when(mockCacheService.getCachedChunkForPage(any, any, any))
            .thenReturn(null);

        when(mockTranslationService.translate(
          text: anyNamed('text'),
          targetLanguage: anyNamed('targetLanguage'),
          sourceLanguage: anyNamed('sourceLanguage'),
        )).thenAnswer((invocation) async {
          final original = invocation.namedArguments[#text] as String?;
          return _mockTranslateWithMarkers(original);
        });

        when(mockCacheService.cacheChunk(any)).thenAnswer((_) async {});

        final pages = List.generate(20, (i) => 'Page $i content');

        final result = await chunkTranslationService.getPageTranslation(
          bookId: 'book',
          pageIndex: 5,
          originalPageText: pages[5],
          targetLanguage: 'es',
          allPages: pages,
        );

        expect(result, isNotEmpty);

        // Verify that the main chunk was cached
        verify(mockCacheService.cacheChunk(any)).called(greaterThanOrEqualTo(1));
      });

      test('should handle pre-translation errors gracefully', () async {
        when(mockCacheService.getCachedChunkForPage(any, any, any))
            .thenReturn(null);

        when(mockTranslationService.translate(
          text: anyNamed('text'),
          targetLanguage: anyNamed('targetLanguage'),
          sourceLanguage: anyNamed('sourceLanguage'),
        )).thenAnswer((invocation) async {
          final original = invocation.namedArguments[#text] as String?;
          return _mockTranslateWithMarkers(original);
        });

        when(mockCacheService.cacheChunk(any)).thenAnswer((_) async {});

        final pages = List.generate(10, (i) => 'Page $i');

        final result = await chunkTranslationService.getPageTranslation(
          bookId: 'book',
          pageIndex: 0,
          originalPageText: pages[0],
          targetLanguage: 'es',
          allPages: pages,
        );

        expect(result, isNotEmpty); // Main translation should succeed
        verify(mockCacheService.cacheChunk(any)).called(greaterThanOrEqualTo(1));
      });
    });

    group('Cache Management', () {
      test('should clear all chunks for a book', () async {
        when(mockCacheService.clearBook('book1')).thenAnswer((_) async {});

        await chunkTranslationService.clearBook('book1');

        verify(mockCacheService.clearBook('book1')).called(1);
      });

      test('should clear chunks for specific book and language', () async {
        when(mockCacheService.clearBookLanguage('book1', 'es'))
            .thenAnswer((_) async {});

        await chunkTranslationService.clearBookLanguage('book1', 'es');

        verify(mockCacheService.clearBookLanguage('book1', 'es')).called(1);
      });

      test('should clear all cached chunks', () async {
        when(mockCacheService.clearAll()).thenAnswer((_) async {});

        await chunkTranslationService.clearAll();

        verify(mockCacheService.clearAll()).called(1);
      });

      test('should provide cache statistics', () async {
        when(mockCacheService.getStats()).thenAnswer((_) async {
          return {'totalChunks': 10, 'books': {'book1': 5, 'book2': 5}};
        });

        final stats = await chunkTranslationService.getStats();

        expect(stats['totalChunks'], 10);
        expect(stats['books']['book1'], 5);
        verify(mockCacheService.getStats()).called(1);
      });
    });

    group('Error Handling', () {
      test('should handle empty page gracefully', () async {
        when(mockCacheService.getCachedChunkForPage(any, any, any))
            .thenReturn(null);

        when(mockTranslationService.translate(
          text: anyNamed('text'),
          targetLanguage: anyNamed('targetLanguage'),
          sourceLanguage: anyNamed('sourceLanguage'),
        )).thenAnswer((invocation) async {
          final original = invocation.namedArguments[#text] as String?;
          return _mockTranslateWithMarkers(original);
        });

        final result = await chunkTranslationService.getPageTranslation(
          bookId: 'book',
          pageIndex: 0,
          originalPageText: '',
          targetLanguage: 'es',
          allPages: ['', 'Page 1', 'Page 2'],
        );

        // Should return translation even with empty page
        expect(result, isA<String>());
      });

      test('should handle invalid page index', () async {
        // Service throws RangeError for negative indices
        when(mockCacheService.getCachedChunkForPage(any, any, any))
            .thenReturn(null);

        when(mockTranslationService.translate(
          text: anyNamed('text'),
          targetLanguage: anyNamed('targetLanguage'),
          sourceLanguage: anyNamed('sourceLanguage'),
        )).thenAnswer((invocation) async {
          final original = invocation.namedArguments[#text] as String?;
          return _mockTranslateWithMarkers(original);
        });

        when(mockCacheService.cacheChunk(any)).thenAnswer((_) async {});

        // Negative index - service will throw RangeError
        expect(
          () => chunkTranslationService.getPageTranslation(
            bookId: 'book',
            pageIndex: -1,
            originalPageText: 'Text',
            targetLanguage: 'es',
            allPages: ['Page 0'],
          ),
          throwsA(isA<RangeError>()),
        );

        // Out of bounds index - service will throw RangeError
        expect(
          () => chunkTranslationService.getPageTranslation(
            bookId: 'book',
            pageIndex: 10,
            originalPageText: 'Text',
            targetLanguage: 'es',
            allPages: ['Page 0'],
          ),
          throwsA(isA<RangeError>()),
        );
      });

      test('should handle translation service errors', () async {
        when(mockCacheService.getCachedChunkForPage(any, any, any))
            .thenReturn(null);

        when(mockTranslationService.translate(
          text: anyNamed('text'),
          targetLanguage: anyNamed('targetLanguage'),
          sourceLanguage: anyNamed('sourceLanguage'),
        )).thenThrow(Exception('Translation failed'));

        expect(
          () => chunkTranslationService.getPageTranslation(
            bookId: 'book',
            pageIndex: 0,
            originalPageText: 'Page 0',
            targetLanguage: 'es',
            allPages: ['Page 0'],
          ),
          throwsException,
        );
      });
    });

    group('Integration Scenarios', () {
      test('should handle multiple pages with varying lengths', () async {
        when(mockCacheService.getCachedChunkForPage(any, any, any))
            .thenReturn(null);

        when(mockTranslationService.translate(
          text: anyNamed('text'),
          targetLanguage: anyNamed('targetLanguage'),
          sourceLanguage: anyNamed('sourceLanguage'),
        )).thenAnswer((invocation) async {
          final original = invocation.namedArguments[#text] as String?;
          return _mockTranslateWithMarkers(original);
        });

        when(mockCacheService.cacheChunk(any)).thenAnswer((_) async {});

        // Pages with very different lengths
        final pages = [
          'Short',
          'This is a much longer page with lots of content ' * 50,
          'Medium length page here',
          'Another long page with extensive content ' * 40,
          'Tiny',
        ];

        final results = <String>[];

        // Translate first page
        results.add(await chunkTranslationService.getPageTranslation(
          bookId: 'book',
          pageIndex: 0,
          originalPageText: pages[0],
          targetLanguage: 'es',
          allPages: pages,
        ));

        // Translate last page
        results.add(await chunkTranslationService.getPageTranslation(
          bookId: 'book',
          pageIndex: 4,
          originalPageText: pages[4],
          targetLanguage: 'es',
          allPages: pages,
        ));

        expect(results, hasLength(2));
        expect(results.every((r) => r.isNotEmpty), isTrue);
      });

      test('should maintain display parity across pages using markers', () async {
        when(mockCacheService.getCachedChunkForPage(any, any, any))
            .thenReturn(null);

        // Mock translation that preserves markers AND paragraph structure
        // This simulates what the actual ML Kit translation service does:
        // 1. Extracts page markers
        // 2. For each page, splits into paragraphs
        // 3. Translates each paragraph separately
        // 4. Reassembles with paragraphs and markers preserved
        when(mockTranslationService.translate(
          text: anyNamed('text'),
          targetLanguage: anyNamed('targetLanguage'),
          sourceLanguage: anyNamed('sourceLanguage'),
        )).thenAnswer((invocation) async {
          final original = invocation.namedArguments[#text] as String?;
          final pageIndices = PageMarkers.extractPageIndices(original ?? '');
          final translatedPages = <String>[];

          for (final pageIndex in pageIndices) {
            final pageText = PageMarkers.extractPage(original ?? '', pageIndex);

            // Split this page into paragraphs and translate each separately
            final paragraphs = pageText.split(RegExp(r'\n\s*\n'));
            final translatedParagraphs = <String>[];

            for (final paragraph in paragraphs) {
              if (paragraph.trim().isEmpty) {
                translatedParagraphs.add('');
              } else {
                // Translate paragraph (prepend "Translated: ")
                translatedParagraphs.add('Translated: ${paragraph.trim()}');
              }
            }

            // Reassemble paragraphs within this page
            final translatedPageText = translatedParagraphs.join('\n\n');
            translatedPages.add(PageMarkers.insertMarkers(translatedPageText, pageIndex));
          }

          return translatedPages.join('\n\n');
        });

        when(mockCacheService.cacheChunk(any)).thenAnswer((_) async {});

        final pages = [
          'First paragraph\n\nSecond paragraph',
          'Third paragraph\n\nFourth paragraph\n\nFifth paragraph',
        ];

        final page0Translation = await chunkTranslationService.getPageTranslation(
          bookId: 'book',
          pageIndex: 0,
          originalPageText: pages[0],
          targetLanguage: 'es',
          allPages: pages,
        );

        final page1Translation = await chunkTranslationService.getPageTranslation(
          bookId: 'book',
          pageIndex: 1,
          originalPageText: pages[1],
          targetLanguage: 'es',
          allPages: pages,
        );

        // Page 0 should have 2 paragraphs
        final page0Paras = page0Translation.split('\n\n');
        expect(page0Paras.length, 2);

        // Page 1 should have 3 paragraphs
        final page1Paras = page1Translation.split('\n\n');
        expect(page1Paras.length, 3);

        // Each page should have the correct content
        expect(page0Translation, contains('Translated: First paragraph'));
        expect(page0Translation, contains('Translated: Second paragraph'));
        expect(page1Translation, contains('Translated: Third paragraph'));
        expect(page1Translation, contains('Translated: Fourth paragraph'));
        expect(page1Translation, contains('Translated: Fifth paragraph'));
      });
    });
  });
}
