import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hive_test/hive_test.dart';
import 'package:dual_reader/src/data/services/enhanced_translation_cache_service.dart';

void main() {
  group('EnhancedTranslationCacheService', () {
    late EnhancedTranslationCacheService cacheService;

    setUp(() async {
      // Initialize Hive for testing
      await Hive.initFlutter();
      await Hive.deleteBoxFromDisk('translationCache');
      await Hive.deleteBoxFromDisk('translationCacheMetadata');

      cacheService = EnhancedTranslationCacheService.instance;
      await cacheService.init();
    });

    tearDown(() async {
      await cacheService.close();
      await Hive.deleteBoxFromDisk('translationCache');
      await Hive.deleteBoxFromDisk('translationCacheMetadata');
    });

    group('Basic Caching', () {
      test('caches a translation', () async {
        const originalText = 'Hello world';
        const targetLanguage = 'es';
        const translatedText = 'Hola mundo';

        await cacheService.cacheTranslation(
          originalText: originalText,
          sourceLanguage: 'en',
          targetLanguage: targetLanguage,
          translatedText: translatedText,
        );

        final retrieved = cacheService.getCachedTranslation(
          originalText: originalText,
          sourceLanguage: 'en',
          targetLanguage: targetLanguage,
        );

        expect(retrieved, equals(translatedText));
      });

      test('returns null for uncached text', () {
        const originalText = 'Uncached text';
        const targetLanguage = 'es';

        final retrieved = cacheService.getCachedTranslation(
          originalText: originalText,
          sourceLanguage: 'en',
          targetLanguage: targetLanguage,
        );

        expect(retrieved, isNull);
      });

      test('returns null for different target language', () async {
        const originalText = 'Hello world';
        const translatedText = 'Hola mundo';

        await cacheService.cacheTranslation(
          originalText: originalText,
          sourceLanguage: 'en',
          targetLanguage: 'es',
          translatedText: translatedText,
        );

        final retrieved = cacheService.getCachedTranslation(
          originalText: originalText,
          sourceLanguage: 'en',
          targetLanguage: 'fr', // Different language
        );

        expect(retrieved, isNull);
      });

      test('handles empty text', () async {
        const originalText = '';
        const targetLanguage = 'es';
        const translatedText = '';

        await cacheService.cacheTranslation(
          originalText: originalText,
          sourceLanguage: 'en',
          targetLanguage: targetLanguage,
          translatedText: translatedText,
        );

        final retrieved = cacheService.getCachedTranslation(
          originalText: originalText,
          sourceLanguage: 'en',
          targetLanguage: targetLanguage,
        );

        expect(retrieved, equals(''));
      });

      test('handles special characters', () async {
        const originalText = 'Hello! @#\$%^&*()';
        const targetLanguage = 'es';
        const translatedText = '¡Hola! @#\$%^&*()';

        await cacheService.cacheTranslation(
          originalText: originalText,
          sourceLanguage: 'en',
          targetLanguage: targetLanguage,
          translatedText: translatedText,
        );

        final retrieved = cacheService.getCachedTranslation(
          originalText: originalText,
          sourceLanguage: 'en',
          targetLanguage: targetLanguage,
        );

        expect(retrieved, equals(translatedText));
      });
    });

    group('Sentence-Level Caching', () {
      test('caches multiple sentences', () async {
        const sentences = ['Hello world', 'How are you?', 'I am fine'];
        const translations = ['Hola mundo', '¿Cómo estás?', 'Estoy bien'];

        await cacheService.cacheSentenceTranslations(
          sentences: sentences,
          sourceLanguage: 'en',
          targetLanguage: 'es',
          translations: translations,
        );

        for (int i = 0; i < sentences.length; i++) {
          final retrieved = cacheService.getCachedTranslation(
            originalText: sentences[i],
            sourceLanguage: 'en',
            targetLanguage: 'es',
          );
          expect(retrieved, equals(translations[i]));
        }
      });

      test('retrieves cached sentence translations', () {
        const sentences = ['Hello world', 'How are you?'];
        const translations = ['Hola mundo', '¿Cómo estás?'];

        // Pre-cache one sentence
        cacheService.cacheTranslation(
          originalText: sentences[0],
          sourceLanguage: 'en',
          targetLanguage: 'es',
          translatedText: translations[0],
        );

        final results = cacheService.getCachedSentenceTranslations(
          sentences: sentences,
          sourceLanguage: 'en',
          targetLanguage: 'es',
        );

        expect(results, hasLength(2));
        expect(results[0].wasCached, isTrue);
        expect(results[0].translation, equals(translations[0]));
        expect(results[1].wasCached, isFalse);
        expect(results[1].translation, isEmpty);
      });

      test('handles mismatched sentence and translation counts', () async {
        const sentences = ['Hello', 'World'];
        const translations = ['Hola']; // Mismatched

        await cacheService.cacheSentenceTranslations(
          sentences: sentences,
          sourceLanguage: 'en',
          targetLanguage: 'es',
          translations: translations,
        );

        // Should not crash, just log warning
        expect(cacheService.getCurrentEntryCount(), greaterThanOrEqualTo(0));
      });
    });

    group('Compression', () {
      test('compresses large translations', () async {
        // Create a large text (> 1KB to trigger compression)
        final largeText = 'This is a very long sentence. ' * 50;
        expect(largeText.length, greaterThan(1024));

        const targetLanguage = 'es';

        await cacheService.cacheTranslation(
          originalText: largeText,
          sourceLanguage: 'en',
          targetLanguage: targetLanguage,
          translatedText: largeText,
        );

        final retrieved = cacheService.getCachedTranslation(
          originalText: largeText,
          sourceLanguage: 'en',
          targetLanguage: targetLanguage,
        );

        expect(retrieved, equals(largeText));
      });

      test('does not compress small translations', () async {
        const smallText = 'Hello';
        const targetLanguage = 'es';

        await cacheService.cacheTranslation(
          originalText: smallText,
          sourceLanguage: 'en',
          targetLanguage: targetLanguage,
          translatedText: 'Hola',
        );

        final retrieved = cacheService.getCachedTranslation(
          originalText: smallText,
          sourceLanguage: 'en',
          targetLanguage: targetLanguage,
        );

        expect(retrieved, equals('Hola'));
      });
    });

    group('Cache Size Tracking', () {
      test('tracks cache size in bytes', () async {
        const text1 = 'Hello world, this is a test';
        const text2 = 'Another test sentence';

        await cacheService.cacheTranslation(
          originalText: text1,
          sourceLanguage: 'en',
          targetLanguage: 'es',
          translatedText: 'Texto de prueba',
        );

        final sizeAfterFirst = cacheService.getCurrentCacheSizeBytes();
        expect(sizeAfterFirst, greaterThan(0));

        await cacheService.cacheTranslation(
          originalText: text2,
          sourceLanguage: 'en',
          targetLanguage: 'es',
          translatedText: 'Otra oración de prueba',
        );

        final sizeAfterSecond = cacheService.getCurrentCacheSizeBytes();
        expect(sizeAfterSecond, greaterThan(sizeAfterFirst));
      });

      test('tracks entry count', () async {
        expect(cacheService.getCurrentEntryCount(), equals(0));

        await cacheService.cacheTranslation(
          originalText: 'Test',
          sourceLanguage: 'en',
          targetLanguage: 'es',
          translatedText: 'Prueba',
        );

        expect(cacheService.getCurrentEntryCount(), equals(1));

        await cacheService.cacheTranslation(
          originalText: 'Test 2',
          sourceLanguage: 'en',
          targetLanguage: 'es',
          translatedText: 'Prueba 2',
        );

        expect(cacheService.getCurrentEntryCount(), equals(2));
      });

      test('formats cache size correctly', () {
        expect(cacheService.getCacheSizeFormatted(), contains('B'));
      });
    });

    group('Cache Configuration', () {
      test('respects max cache size limit', () async {
        cacheService.configure(
          maxCacheSizeBytes: 500, // Very small limit for testing
          maxEntries: 5,
        );

        // Add several entries that exceed the limit
        for (int i = 0; i < 10; i++) {
          await cacheService.cacheTranslation(
            originalText: 'Test $i',
            sourceLanguage: 'en',
            targetLanguage: 'es',
            translatedText: 'Prueba $i con más texto para usar espacio',
          );
        }

        // Should have evicted some entries to stay under limit
        final size = cacheService.getCurrentCacheSizeBytes();
        expect(size, lessThan(600)); // Allow some buffer
      });

      test('respects max entries limit', () async {
        cacheService.configure(
          maxCacheSizeBytes: 10000,
          maxEntries: 3, // Very low limit for testing
        );

        // Add more entries than the limit
        for (int i = 0; i < 10; i++) {
          await cacheService.cacheTranslation(
            originalText: 'Test $i',
            sourceLanguage: 'en',
            targetLanguage: 'es',
            translatedText: 'Prueba $i',
          );
        }

        // Should have evicted entries to stay under limit
        final count = cacheService.getCurrentEntryCount();
        expect(count, lessThanOrEqualTo(3));
      });
    });

    group('LRU Eviction', () {
      test('evicts least recently used entries', () async {
        cacheService.configure(maxCacheSizeBytes: 200, maxEntries: 3);

        // Add entries up to limit
        await cacheService.cacheTranslation(
          originalText: 'First',
          sourceLanguage: 'en',
          targetLanguage: 'es',
          translatedText: 'Primero',
        );

        await cacheService.cacheTranslation(
          originalText: 'Second',
          sourceLanguage: 'en',
          targetLanguage: 'es',
          translatedText: 'Segundo',
        );

        await cacheService.cacheTranslation(
          originalText: 'Third',
          sourceLanguage: 'en',
          targetLanguage: 'es',
          translatedText: 'Tercero',
        );

        // Access first entry to make it more recent
        cacheService.getCachedTranslation(
          originalText: 'First',
          sourceLanguage: 'en',
          targetLanguage: 'es',
        );

        // Add fourth entry (should evict second or third, not first)
        await cacheService.cacheTranslation(
          originalText: 'Fourth',
          sourceLanguage: 'en',
          targetLanguage: 'es',
          translatedText: 'Cuarto',
        );

        // First should still be cached
        final first = cacheService.getCachedTranslation(
          originalText: 'First',
          sourceLanguage: 'en',
          targetLanguage: 'es',
        );
        expect(first, equals('Primero'));

        // Second or third should be evicted
        final second = cacheService.getCachedTranslation(
          originalText: 'Second',
          sourceLanguage: 'en',
          targetLanguage: 'es',
        );
        final third = cacheService.getCachedTranslation(
          originalText: 'Third',
          sourceLanguage: 'en',
          targetLanguage: 'es',
        );

        // At least one should be evicted
        expect(second == null || third == null, isTrue);
      });
    });

    group('Cache Management', () {
      test('clears all cache', () async {
        await cacheService.cacheTranslation(
          originalText: 'Test',
          sourceLanguage: 'en',
          targetLanguage: 'es',
          translatedText: 'Prueba',
        );

        expect(cacheService.getCurrentEntryCount(), greaterThan(0));

        await cacheService.clearCache();

        expect(cacheService.getCurrentEntryCount(), equals(0));
        expect(cacheService.getCurrentCacheSizeBytes(), equals(0));
      });

      test('clears cache for specific language pair', () async {
        await cacheService.cacheTranslation(
          originalText: 'Test',
          sourceLanguage: 'en',
          targetLanguage: 'es',
          translatedText: 'Prueba ES',
        );

        await cacheService.cacheTranslation(
          originalText: 'Test',
          sourceLanguage: 'en',
          targetLanguage: 'fr',
          translatedText: 'Test FR',
        );

        expect(cacheService.getCurrentEntryCount(), equals(2));

        await cacheService.clearLanguagePair('en', 'es');

        // Spanish should be cleared
        final esResult = cacheService.getCachedTranslation(
          originalText: 'Test',
          sourceLanguage: 'en',
          targetLanguage: 'es',
        );
        expect(esResult, isNull);

        // French should still be cached
        final frResult = cacheService.getCachedTranslation(
          originalText: 'Test',
          sourceLanguage: 'en',
          targetLanguage: 'fr',
        );
        expect(frResult, equals('Test FR'));
      });
    });

    group('Common Phrase Preloading', () {
      test('preloads common phrases', () async {
        await cacheService.preloadCommonPhrases('es');

        // Check that common phrases are cached
        final hello = cacheService.getCachedTranslation(
          originalText: 'Hello',
          sourceLanguage: 'en',
          targetLanguage: 'es',
        );

        expect(hello, isNotNull);
        expect(hello?.toLowerCase(), contains('hola'));
      });

      test('preloads custom phrases', () async {
        final customPhrases = {
          'Custom phrase 1': 'Frase personalizada 1',
          'Custom phrase 2': 'Frase personalizada 2',
        };

        await cacheService.preloadCommonPhrases(
          'es',
          customPhrases: customPhrases,
        );

        final phrase1 = cacheService.getCachedTranslation(
          originalText: 'Custom phrase 1',
          sourceLanguage: 'en',
          targetLanguage: 'es',
        );

        expect(phrase1, equals('Frase personalizada 1'));
      });
    });

    group('Cache Statistics', () {
      test('calculates hit rate', () async {
        final stats = await cacheService.getStatistics();

        expect(stats.hits, equals(0));
        expect(stats.misses, equals(0));
        expect(stats.hitRate, equals(0.0));
      });

      test('tracks cache size in statistics', () async {
        await cacheService.cacheTranslation(
          originalText: 'Test',
          sourceLanguage: 'en',
          targetLanguage: 'es',
          translatedText: 'Prueba',
        );

        final stats = await cacheService.getStatistics();

        expect(stats.sizeBytes, greaterThan(0));
        expect(stats.entryCount, equals(1));
      });
    });

    group('Export/Import', () {
      test('exports cache as JSON', () async {
        await cacheService.cacheTranslation(
          originalText: 'Hello',
          sourceLanguage: 'en',
          targetLanguage: 'es',
          translatedText: 'Hola',
        );

        final exported = await cacheService.exportCache();

        expect(exported, isNotNull);
        expect(exported, contains('"Hello'));
        expect(exported, contains('Hola'));
      });

      test('imports cache from JSON', () async {
        const jsonData = '{"test_key_es": "Prueba", "another_key_fr": "Test"}';

        final success = await cacheService.importCache(jsonData);

        expect(success, isTrue);
        expect(cacheService.getCurrentEntryCount(), greaterThan(0));
      });

      test('handles invalid import JSON', () async {
        const invalidJson = '{invalid json}';

        final success = await cacheService.importCache(invalidJson);

        expect(success, isFalse);
      });
    });

    group('Edge Cases', () {
      test('handles very long text with hash key', () async {
        // Text longer than 255 characters should use hash key
        final veryLongText = 'This is a very long text. ' * 30;

        await cacheService.cacheTranslation(
          originalText: veryLongText,
          sourceLanguage: 'en',
          targetLanguage: 'es',
          translatedText: veryLongText,
        );

        final retrieved = cacheService.getCachedTranslation(
          originalText: veryLongText,
          sourceLanguage: 'en',
          targetLanguage: 'es',
        );

        expect(retrieved, equals(veryLongText));
      });

      test('handles unicode characters', () async {
        const text = 'Hello 世界 🌍 مرحبا';
        const translated = 'Hola 世界 🌍 مرحبا';

        await cacheService.cacheTranslation(
          originalText: text,
          sourceLanguage: 'en',
          targetLanguage: 'es',
          translatedText: translated,
        );

        final retrieved = cacheService.getCachedTranslation(
          originalText: text,
          sourceLanguage: 'en',
          targetLanguage: 'es',
        );

        expect(retrieved, equals(translated));
      });

      test('handles newlines in text', () async {
        const text = 'Line 1\nLine 2\nLine 3';
        const translated = 'Línea 1\nLínea 2\nLínea 3';

        await cacheService.cacheTranslation(
          originalText: text,
          sourceLanguage: 'en',
          targetLanguage: 'es',
          translatedText: translated,
        );

        final retrieved = cacheService.getCachedTranslation(
          originalText: text,
          sourceLanguage: 'en',
          targetLanguage: 'es',
        );

        expect(retrieved, equals(translated));
      });

      test('updates existing cache entry', () async {
        const text = 'Hello';

        await cacheService.cacheTranslation(
          originalText: text,
          sourceLanguage: 'en',
          targetLanguage: 'es',
          translatedText: 'Hola',
        );

        await cacheService.cacheTranslation(
          originalText: text,
          sourceLanguage: 'en',
          targetLanguage: 'es',
          translatedText: 'Hola!', // Updated translation
        );

        final retrieved = cacheService.getCachedTranslation(
          originalText: text,
          sourceLanguage: 'en',
          targetLanguage: 'es',
        );

        expect(retrieved, equals('Hola!'));
      });
    });

    group('Integration Scenarios', () {
      test('handles realistic translation workflow', () async {
        // Simulate translating a paragraph sentence by sentence
        const sentences = [
          'The quick brown fox jumps.',
          'He is very fast and agile.',
          'The dog watches quietly.',
        ];

        final translations = [
          'El zorro marrón rápido salta.',
          'Es muy rápido y ágil.',
          'El perro observa silenciosamente.',
        ];

        // Cache translations as they come in
        for (int i = 0; i < sentences.length; i++) {
          await cacheService.cacheTranslation(
            originalText: sentences[i],
            sourceLanguage: 'en',
            targetLanguage: 'es',
            translatedText: translations[i],
          );
        }

        // Verify all are cached
        for (int i = 0; i < sentences.length; i++) {
          final retrieved = cacheService.getCachedTranslation(
            originalText: sentences[i],
            sourceLanguage: 'en',
            targetLanguage: 'es',
          );
          expect(retrieved, equals(translations[i]));
        }

        expect(cacheService.getCurrentEntryCount(), equals(3));
      });

      test('handles cache across multiple language pairs', () async {
        const text = 'Hello';

        await cacheService.cacheTranslation(
          originalText: text,
          sourceLanguage: 'en',
          targetLanguage: 'es',
          translatedText: 'Hola',
        );

        await cacheService.cacheTranslation(
          originalText: text,
          sourceLanguage: 'en',
          targetLanguage: 'fr',
          translatedText: 'Bonjour',
        );

        await cacheService.cacheTranslation(
          originalText: text,
          sourceLanguage: 'en',
          targetLanguage: 'de',
          translatedText: 'Hallo',
        );

        expect(cacheService.getCurrentEntryCount(), equals(3));

        // Each language pair should have correct translation
        final esResult = cacheService.getCachedTranslation(
          originalText: text,
          sourceLanguage: 'en',
          targetLanguage: 'es',
        );
        final frResult = cacheService.getCachedTranslation(
          originalText: text,
          sourceLanguage: 'en',
          targetLanguage: 'fr',
        );
        final deResult = cacheService.getCachedTranslation(
          originalText: text,
          sourceLanguage: 'en',
          targetLanguage: 'de',
        );

        expect(esResult, equals('Hola'));
        expect(frResult, equals('Bonjour'));
        expect(deResult, equals('Hallo'));
      });
    });

    group('Performance', () {
      test('caches and retrieves quickly', () async {
        const text = 'Performance test';

        final stopwatch = Stopwatch()..start();

        await cacheService.cacheTranslation(
          originalText: text,
          sourceLanguage: 'en',
          targetLanguage: 'es',
          translatedText: 'Prueba de rendimiento',
        );

        final cacheTime = stopwatch.elapsedMilliseconds;
        stopwatch.reset();

        final retrieved = cacheService.getCachedTranslation(
          originalText: text,
          sourceLanguage: 'en',
          targetLanguage: 'es',
        );

        final retrieveTime = stopwatch.elapsedMilliseconds;

        expect(cacheTime, lessThan(100)); // Should cache in < 100ms
        expect(retrieveTime, lessThan(50)); // Should retrieve in < 50ms
        expect(retrieved, equals('Prueba de rendimiento'));
      });

      test('handles bulk caching efficiently', () async {
        const sentenceCount = 50;
        final sentences = List.generate(
          sentenceCount,
          (i) => 'Sentence number $i',
        );
        final translations = List.generate(
          sentenceCount,
          (i) => 'Oración número $i',
        );

        final stopwatch = Stopwatch()..start();

        await cacheService.cacheSentenceTranslations(
          sentences: sentences,
          sourceLanguage: 'en',
          targetLanguage: 'es',
          translations: translations,
        );

        final bulkTime = stopwatch.elapsedMilliseconds;

        expect(cacheService.getCurrentEntryCount(), equals(sentenceCount));
        expect(bulkTime, lessThan(1000)); // Should complete in < 1 second

        // Verify a sample of translations
        for (int i = 0; i < 5; i++) {
          final retrieved = cacheService.getCachedTranslation(
            originalText: sentences[i],
            sourceLanguage: 'en',
            targetLanguage: 'es',
          );
          expect(retrieved, equals(translations[i]));
        }
      });
    });
  });
}
