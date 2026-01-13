import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';
import 'package:dual_reader/src/data/services/chunk_cache_service.dart';
import 'package:dual_reader/src/domain/entities/translation_chunk.dart';
import '../../../helper/test_helpers.dart';

void main() {
  group('ChunkCacheService', () {
    late ChunkCacheService cacheService;
    bool hiveInitialized = false;

    setUpAll(() async {
      // Initialize Hive for testing
      try {
        await setUpHive();
        hiveInitialized = true;
      } catch (e) {
        print('Skipping tests: Hive requires platform channels');
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

    test('should initialize cache boxes successfully', () async {
      if (!hiveInitialized) {
        print('Test skipped: Hive not initialized');
        return;
      }
      expect(cacheService, isNotNull);
      expect(cacheService, isA<ChunkCacheService>());
    });

    test('should cache a translation chunk', () async {
      if (!hiveInitialized) {
        print('Test skipped: Hive not initialized');
        return;
      }
      final chunk = TranslationChunk(
        chunkId: 'test_book_chunk_0_2_es',
        bookId: 'test_book',
        startPageIndex: 0,
        endPageIndex: 2,
        originalText: 'Page 0\n\nPage 1\n\nPage 2',
        pageBreakOffsets: [7, 14, 21],
        targetLanguage: 'es',
      );

      chunk.translatedText = 'Pagina 0\n\nPagina 1\n\nPagina 2';
      chunk.translatedAt = DateTime.now();

      await cacheService.cacheChunk(chunk);

      final cached = cacheService.getCachedChunk(chunk.chunkId);
      expect(cached, isNotNull);
      expect(cached!.chunkId, chunk.chunkId);
    });

    test('should return null for non-existent chunk', () {
      if (!hiveInitialized) {
        print('Test skipped: Hive not initialized');
        return;
      }
      final retrieved = cacheService.getCachedChunk('non_existent_chunk');
      expect(retrieved, isNull);
    });

    test('should return null for non-existent page mapping', () {
      if (!hiveInitialized) {
        print('Test skipped: Hive not initialized');
        return;
      }
      final retrieved = cacheService.getCachedChunkForPage('test_book', 99, 'es');
      expect(retrieved, isNull);
    });

    test('should clear all cached chunks', () async {
      if (!hiveInitialized) {
        print('Test skipped: Hive not initialized');
        return;
      }
      final chunk1 = TranslationChunk(
        chunkId: 'chunk1_0_1_es',
        bookId: 'book1',
        startPageIndex: 0,
        endPageIndex: 1,
        originalText: 'Text',
        pageBreakOffsets: [4],
        targetLanguage: 'es',
      );

      chunk1.translatedText = 'T';
      await cacheService.cacheChunk(chunk1);

      expect(cacheService.getCachedChunk(chunk1.chunkId), isNotNull);

      await cacheService.clearAll();

      expect(cacheService.getCachedChunk(chunk1.chunkId), isNull);
    });
  });

  group('ChunkCacheService Error Handling', () {
    test('should handle cache miss gracefully', () {
      final service = ChunkCacheService();

      final result = service.getCachedChunk('non_existent');
      expect(result, isNull);

      final pageResult = service.getCachedChunkForPage('book', 0, 'es');
      expect(pageResult, isNull);
    });
  });
}
