import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dual_reader/src/data/services/chunk_translation_service.dart';
import 'package:dual_reader/src/data/services/chunk_cache_service.dart';
import 'package:dual_reader/src/data/services/client_side_translation_service.dart';
import 'package:dual_reader/src/domain/entities/translation_chunk.dart';

@GenerateMocks([ChunkCacheService, ClientSideTranslationService])
import 'chunk_translation_service_test.mocks.dart';

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
        final cachedChunk = TranslationChunk(
          chunkId: 'book_chunk_0_2_es',
          bookId: 'book',
          startPageIndex: 0,
          endPageIndex: 2,
          originalText: 'Page 0\n\nPage 1\n\nPage 2',
          pageBreakOffsets: [7, 14, 21],
          targetLanguage: 'es',
        );

        cachedChunk.translatedText = 'Pagina 0\n\nPagina 1\n\nPagina 2';

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
        ));
      });

      test('should create and translate new chunk when not cached', () async {
        when(mockCacheService.getCachedChunkForPage('book', 0, 'es'))
            .thenReturn(null);

        when(mockTranslationService.translate(
          text: anyNamed('text'),
          targetLanguage: anyNamed('targetLanguage'),
        )).thenAnswer((_) async => 'Pagina 0\n\nPagina 1\n\nPagina 2');

        when(mockCacheService.cacheChunk(any)).thenAnswer((_) async {});

        final result = await chunkTranslationService.getPageTranslation(
          bookId: 'book',
          pageIndex: 0,
          originalPageText: 'Page 0',
          targetLanguage: 'es',
          allPages: ['Page 0', 'Page 1', 'Page 2'],
        );

        expect(result, isNotEmpty);
        verify(mockTranslationService.translate(
          text: argThat(contains('Page 0'), named: 'text'),
          targetLanguage: 'es',
        )).called(1);
        verify(mockCacheService.cacheChunk(any)).called(1);
      });

      test('should retranslate on cache extraction error', () async {
        final cachedChunk = TranslationChunk(
          chunkId: 'book_chunk_0_2_es',
          bookId: 'book',
          startPageIndex: 0,
          endPageIndex: 2,
          originalText: 'Page 0\n\nPage 1\n\nPage 2',
          pageBreakOffsets: [7, 14, 21],
          targetLanguage: 'es',
        );

        cachedChunk.translatedText = 'Translation';

        when(mockCacheService.getCachedChunkForPage('book', 1, 'es'))
            .thenReturn(cachedChunk);

        // Throw exception when extracting (e.g., page out of range in corrupted chunk)
        when(mockTranslationService.translate(
          text: anyNamed('text'),
          targetLanguage: anyNamed('targetLanguage'),
        )).thenAnswer((_) async => 'New Translation');

        when(mockCacheService.cacheChunk(any)).thenAnswer((_) async {});

        final result = await chunkTranslationService.getPageTranslation(
          bookId: 'book',
          pageIndex: 1,
          originalPageText: 'Page 1',
          targetLanguage: 'es',
          allPages: ['Page 0', 'Page 1', 'Page 2'],
        );

        expect(result, isNotEmpty);
      });
    });

    group('Chunk Boundary Calculation', () {
      test('should create chunk within target size range', () async {
        when(mockCacheService.getCachedChunkForPage(any, any, any))
            .thenReturn(null);

        when(mockTranslationService.translate(
          text: anyNamed('text'),
          targetLanguage: anyNamed('targetLanguage'),
        )).thenAnswer((_) async => 'Translation');

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

        final captured =
            verify(mockCacheService.cacheChunk(any)).captured.single as TranslationChunk;

        // Chunk should be within target range
        expect(captured.originalText.length,
            greaterThanOrEqualTo(3000));
        expect(captured.originalText.length,
            lessThanOrEqualTo(8000)); // Hard limit
      });

      test('should respect paragraph boundaries when possible', () async {
        when(mockCacheService.getCachedChunkForPage(any, any, any))
            .thenReturn(null);

        when(mockTranslationService.translate(
          text: anyNamed('text'),
          targetLanguage: anyNamed('targetLanguage'),
        )).thenAnswer((_) async => 'Translation');

        when(mockCacheService.cacheChunk(any)).thenAnswer((_) async {});

        // Pages with clear sentence boundaries
        final pages = [
          'First page. Complete sentence.',
          'Second page starts with capital.',
          'Third page. Another complete.',
          'Fourth page begins here.',
          'Fifth page. Final sentence.',
        ];

        await chunkTranslationService.getPageTranslation(
          bookId: 'book',
          pageIndex: 2,
          originalPageText: pages[2],
          targetLanguage: 'es',
          allPages: pages,
        );

        final captured =
            verify(mockCacheService.cacheChunk(any)).captured.single as TranslationChunk;

        // Should include multiple pages when they have good boundaries
        expect(captured.pageCount, greaterThan(1));
      });
    });

    group('Pre-translation', () {
      test('should pre-translate nearby chunks in background', () async {
        when(mockCacheService.getCachedChunkForPage(any, any, any))
            .thenReturn(null);

        when(mockTranslationService.translate(
          text: anyNamed('text'),
          targetLanguage: anyNamed('targetLanguage'),
        )).thenAnswer((_) async => 'Translation');

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

        // Wait a bit for background pre-translation
        await Future.delayed(const Duration(milliseconds: 100));

        // Should have additional cache calls for pre-translation
        verify(mockCacheService.cacheChunk(any)).called(greaterThan(1));
      });

      test('should handle pre-translation errors gracefully', () async {
        when(mockCacheService.getCachedChunkForPage(any, any, any))
            .thenReturn(null);

        when(mockTranslationService.translate(
          text: anyNamed('text'),
          targetLanguage: anyNamed('targetLanguage'),
        )).thenAnswer((_) async => 'Main Translation');

        when(mockCacheService.cacheChunk(any)).thenAnswer((_) async {});

        final pages = List.generate(10, (i) => 'Page $i');

        // Pre-translation should fail but not affect main translation
        when(mockTranslationService.translate(
          text: argThat(contains('Page 8'), named: 'text'),
          targetLanguage: 'es',
        )).thenThrow(Exception('Pre-translation error'));

        final result = await chunkTranslationService.getPageTranslation(
          bookId: 'book',
          pageIndex: 0,
          originalPageText: pages[0],
          targetLanguage: 'es',
          allPages: pages,
        );

        expect(result, isNotEmpty); // Main translation should succeed

        // Wait for background tasks
        await Future.delayed(const Duration(milliseconds: 100));
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

        final result = chunkTranslationService.getPageTranslation(
          bookId: 'book',
          pageIndex: 0,
          originalPageText: '',
          targetLanguage: 'es',
          allPages: ['', 'Page 1', 'Page 2'],
        );

        expect(result, throwsA(isA<ArgumentError>()));
      });

      test('should handle invalid page index', () async {
        expect(
          () => chunkTranslationService.getPageTranslation(
            bookId: 'book',
            pageIndex: -1,
            originalPageText: 'Text',
            targetLanguage: 'es',
            allPages: ['Page 0'],
          ),
          throwsA(isA<ArgumentError>()),
        );

        expect(
          () => chunkTranslationService.getPageTranslation(
            bookId: 'book',
            pageIndex: 10,
            originalPageText: 'Text',
            targetLanguage: 'es',
            allPages: ['Page 0'],
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should handle translation service errors', () async {
        when(mockCacheService.getCachedChunkForPage(any, any, any))
            .thenReturn(null);

        when(mockTranslationService.translate(
          text: anyNamed('text'),
          targetLanguage: anyNamed('targetLanguage'),
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
        )).thenAnswer((_) async => 'Translated content');

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

      test('should maintain display parity across pages', () async {
        when(mockCacheService.getCachedChunkForPage(any, any, any))
            .thenReturn(null);

        when(mockTranslationService.translate(
          text: anyNamed('text'),
          targetLanguage: anyNamed('targetLanguage'),
          sourceLanguage: anyNamed('sourceLanguage'),
        )).thenAnswer((invocation) async {
          // Return translation with same paragraph structure
          final original = invocation.namedArguments[#text] as String?;
          return original!
                  .split('\n\n')
                  .map((p) => 'Translated: $p')
                  .join('\n\n');
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
      });
    });
  });
}
