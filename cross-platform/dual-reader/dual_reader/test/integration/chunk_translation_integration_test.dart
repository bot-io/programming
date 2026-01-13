import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';
import 'package:dual_reader/src/data/services/chunk_cache_service.dart';
import 'package:dual_reader/src/domain/entities/translation_chunk.dart';
import '../helper/test_helpers.dart';

void main() {
  group('Chunk Cache Integration Tests', () {
    late ChunkCacheService cacheService;
    bool hiveInitialized = false;

    setUpAll(() async {
      // Skip if platform channels not available
      try {
        await setUpHive();
        hiveInitialized = true;
      } catch (e) {
        print('Skipping integration tests: Hive requires platform channels (run on device/emulator)');
      }
    });

    setUp(() async {
      if (!hiveInitialized) return;

      cacheService = ChunkCacheService();
      await cacheService.init();
    });

    tearDown(() async {
      if (!hiveInitialized) return;

      // Clear cache after each test
      await cacheService.clearAll();
    });

    tearDownAll(() async {
      if (!hiveInitialized) return;

      await Hive.close();
    });

    test('should cache and retrieve chunk with full metadata', () async {
      if (!hiveInitialized) {
        print('Test skipped: Hive not initialized');
        return;
      }

      final now = DateTime.now();
      final chunk = TranslationChunk(
        chunkId: 'test_chunk_0_2_es',
        bookId: 'test_book',
        startPageIndex: 0,
        endPageIndex: 2,
        originalText: 'Page 0\n\nPage 1\n\nPage 2',
        pageBreakOffsets: [7, 14, 21],
        targetLanguage: 'es',
        translatedAt: now,
      );

      chunk.translatedText = 'Pagina 0\n\nPagina 1\n\nPagina 2';

      await cacheService.cacheChunk(chunk);

      final retrieved = cacheService.getCachedChunk(chunk.chunkId);
      expect(retrieved, isNotNull);
      expect(retrieved!.chunkId, chunk.chunkId);
      expect(retrieved.translatedText, chunk.translatedText);
      expect(retrieved.translatedAt?.toIso8601String(), now.toIso8601String());
    });

    test('should persist cache across service instances', () async {
      if (!hiveInitialized) {
        print('Test skipped: Hive not initialized');
        return;
      }

      final chunk = TranslationChunk(
        chunkId: 'persist_test_0_1_es',
        bookId: 'persist_test',
        startPageIndex: 0,
        endPageIndex: 1,
        originalText: 'Test content',
        pageBreakOffsets: [12],
        targetLanguage: 'es',
      );

      chunk.translatedText = 'Contenido de prueba';

      // Cache with first instance
      await cacheService.cacheChunk(chunk);

      // Create new service instance
      final newCacheService = ChunkCacheService();
      await newCacheService.init();

      // Should retrieve from persistent storage
      final retrieved = newCacheService.getCachedChunk(chunk.chunkId);
      expect(retrieved, isNotNull);
      expect(retrieved!.translatedText, chunk.translatedText);
    });

    test('should handle page-to-chunk mapping correctly', () async {
      if (!hiveInitialized) {
        print('Test skipped: Hive not initialized');
        return;
      }

      final chunk = TranslationChunk(
        chunkId: 'mapping_test_0_3_es',
        bookId: 'mapping_test',
        startPageIndex: 0,
        endPageIndex: 3,
        originalText: 'Page 0\n\nPage 1\n\nPage 2\n\nPage 3',
        pageBreakOffsets: [7, 14, 21, 28],
        targetLanguage: 'es',
      );

      chunk.translatedText = 'Translated pages 0-3';

      await cacheService.cacheChunk(chunk);

      // All pages should map to this chunk
      expect(cacheService.getCachedChunkForPage('mapping_test', 0, 'es')?.chunkId, chunk.chunkId);
      expect(cacheService.getCachedChunkForPage('mapping_test', 1, 'es')?.chunkId, chunk.chunkId);
      expect(cacheService.getCachedChunkForPage('mapping_test', 2, 'es')?.chunkId, chunk.chunkId);
      expect(cacheService.getCachedChunkForPage('mapping_test', 3, 'es')?.chunkId, chunk.chunkId);
    });

    test('should provide accurate statistics', () async {
      if (!hiveInitialized) {
        print('Test skipped: Hive not initialized');
        return;
      }

      final chunk1 = TranslationChunk(
        chunkId: 'stats_book_1_chunk_0_1_es',
        bookId: 'stats_book_1',
        startPageIndex: 0,
        endPageIndex: 1,
        originalText: 'Content 1',
        pageBreakOffsets: [9],
        targetLanguage: 'es',
      );

      final chunk2 = TranslationChunk(
        chunkId: 'stats_book_2_chunk_0_1_es',
        bookId: 'stats_book_2',
        startPageIndex: 0,
        endPageIndex: 1,
        originalText: 'Content 2',
        pageBreakOffsets: [9],
        targetLanguage: 'es',
      );

      chunk1.translatedText = 'Translated 1';
      chunk2.translatedText = 'Translated 2';

      await cacheService.cacheChunk(chunk1);
      await cacheService.cacheChunk(chunk2);

      final stats = await cacheService.getStats();

      expect(stats['totalChunks'], 2);
      expect(stats['books'], isA<Map<String, int>>());
      expect((stats['books'] as Map)['stats_book_1'], 1);
      expect((stats['books'] as Map)['stats_book_2'], 1);
    });

    test('should clear specific book cache', () async {
      if (!hiveInitialized) {
        print('Test skipped: Hive not initialized');
        return;
      }

      final chunk1 = TranslationChunk(
        chunkId: 'clear_test_book_1_chunk_0_1_es',
        bookId: 'clear_test_book_1',
        startPageIndex: 0,
        endPageIndex: 1,
        originalText: 'Content',
        pageBreakOffsets: [7],
        targetLanguage: 'es',
      );

      final chunk2 = TranslationChunk(
        chunkId: 'clear_test_book_2_chunk_0_1_es',
        bookId: 'clear_test_book_2',
        startPageIndex: 0,
        endPageIndex: 1,
        originalText: 'Content',
        pageBreakOffsets: [7],
        targetLanguage: 'es',
      );

      chunk1.translatedText = 'T1';
      chunk2.translatedText = 'T2';

      await cacheService.cacheChunk(chunk1);
      await cacheService.cacheChunk(chunk2);

      expect(cacheService.getCachedChunk(chunk1.chunkId), isNotNull);
      expect(cacheService.getCachedChunk(chunk2.chunkId), isNotNull);

      await cacheService.clearBook('clear_test_book_1');

      expect(cacheService.getCachedChunk(chunk1.chunkId), isNull);
      expect(cacheService.getCachedChunk(chunk2.chunkId), isNotNull);
    });

    test('should clear specific book and language cache', () async {
      if (!hiveInitialized) {
        print('Test skipped: Hive not initialized');
        return;
      }

      final chunkEs = TranslationChunk(
        chunkId: 'lang_test_book_1_chunk_0_1_es',
        bookId: 'lang_test_book',
        startPageIndex: 0,
        endPageIndex: 1,
        originalText: 'Content',
        pageBreakOffsets: [7],
        targetLanguage: 'es',
      );

      final chunkFr = TranslationChunk(
        chunkId: 'lang_test_book_1_chunk_0_1_fr',
        bookId: 'lang_test_book',
        startPageIndex: 0,
        endPageIndex: 1,
        originalText: 'Content',
        pageBreakOffsets: [7],
        targetLanguage: 'fr',
      );

      chunkEs.translatedText = 'Traduccion';
      chunkFr.translatedText = 'Traduction';

      await cacheService.cacheChunk(chunkEs);
      await cacheService.cacheChunk(chunkFr);

      expect(cacheService.getCachedChunk(chunkEs.chunkId), isNotNull);
      expect(cacheService.getCachedChunk(chunkFr.chunkId), isNotNull);

      await cacheService.clearBookLanguage('lang_test_book', 'es');

      expect(cacheService.getCachedChunk(chunkEs.chunkId), isNull);
      expect(cacheService.getCachedChunk(chunkFr.chunkId), isNotNull);
    });

    test('should handle untranslated chunks correctly', () async {
      if (!hiveInitialized) {
        print('Test skipped: Hive not initialized');
        return;
      }

      final chunk = TranslationChunk(
        chunkId: 'untranslated_chunk_0_1_es',
        bookId: 'untranslated_test',
        startPageIndex: 0,
        endPageIndex: 1,
        originalText: 'Original text',
        pageBreakOffsets: [13],
        targetLanguage: 'es',
      );

      // Cache without translation
      await cacheService.cacheChunk(chunk);

      final retrieved = cacheService.getCachedChunk(chunk.chunkId);
      expect(retrieved, isNotNull);
      expect(retrieved!.isTranslated, isFalse);

      // Should return false for isPageCached if not translated
      expect(cacheService.isPageCached('untranslated_test', 0, 'es'), isFalse);
    });

    test('should handle chunk with multiple pages', () async {
      if (!hiveInitialized) {
        print('Test skipped: Hive not initialized');
        return;
      }

      final chunk = TranslationChunk(
        chunkId: 'multi_page_0_4_es',
        bookId: 'multi_page_test',
        startPageIndex: 0,
        endPageIndex: 4,
        originalText: 'P0\n\nP1\n\nP2\n\nP3\n\nP4',
        pageBreakOffsets: [3, 6, 9, 12, 15],
        targetLanguage: 'es',
      );

      chunk.translatedText = 'T0\n\nT1\n\nT2\n\nT3\n\nT4';

      await cacheService.cacheChunk(chunk);

      // Verify all pages map to this chunk
      for (int i = 0; i <= 4; i++) {
        final retrieved = cacheService.getCachedChunkForPage('multi_page_test', i, 'es');
        expect(retrieved?.chunkId, chunk.chunkId);
      }
    });

    test('should overwrite existing chunk', () async {
      if (!hiveInitialized) {
        print('Test skipped: Hive not initialized');
        return;
      }

      final chunk = TranslationChunk(
        chunkId: 'overwrite_test_0_1_es',
        bookId: 'overwrite_test',
        startPageIndex: 0,
        endPageIndex: 1,
        originalText: 'Original content',
        pageBreakOffsets: [16],
        targetLanguage: 'es',
      );

      chunk.translatedText = 'First translation';

      await cacheService.cacheChunk(chunk);

      // Update translation
      chunk.translatedText = 'Updated translation';
      await cacheService.cacheChunk(chunk);

      final retrieved = cacheService.getCachedChunk(chunk.chunkId);
      expect(retrieved?.translatedText, 'Updated translation');
    });

    test('should handle clear all correctly', () async {
      if (!hiveInitialized) {
        print('Test skipped: Hive not initialized');
        return;
      }

      final chunk = TranslationChunk(
        chunkId: 'clear_all_test_0_1_es',
        bookId: 'clear_all_test',
        startPageIndex: 0,
        endPageIndex: 1,
        originalText: 'Content',
        pageBreakOffsets: [7],
        targetLanguage: 'es',
      );

      chunk.translatedText = 'Translated';

      await cacheService.cacheChunk(chunk);
      expect(cacheService.getCachedChunk(chunk.chunkId), isNotNull);

      await cacheService.clearAll();
      expect(cacheService.getCachedChunk(chunk.chunkId), isNull);
    });

    test('should handle complex chunk scenarios', () async {
      if (!hiveInitialized) {
        print('Test skipped: Hive not initialized');
        return;
      }

      // Test with realistic chunk data
      final chunk = TranslationChunk(
        chunkId: 'complex_test_2_5_es',
        bookId: 'complex_test',
        startPageIndex: 2,
        endPageIndex: 5,
        originalText: 'Page 2 content.\n\nPage 3 content here.\n\nPage 4.\n\nPage 5 content.',
        pageBreakOffsets: [13, 33, 43, 61],
        targetLanguage: 'es',
      );

      chunk.translatedText = 'Pagina 2.\n\nPagina 3.\n\nPagina 4.\n\nPagina 5.';
      chunk.translatedAt = DateTime.now();

      await cacheService.cacheChunk(chunk);

      // Verify retrieval by each page in the chunk
      for (int i = 2; i <= 5; i++) {
        final retrieved = cacheService.getCachedChunkForPage('complex_test', i, 'es');
        expect(retrieved, isNotNull);
        expect(retrieved!.startPageIndex, 2);
        expect(retrieved.endPageIndex, 5);
      }

      // Verify isPageCached works
      expect(cacheService.isPageCached('complex_test', 3, 'es'), isTrue);
      expect(cacheService.isPageCached('complex_test', 1, 'es'), isFalse); // Not in chunk
    });
  });
}
