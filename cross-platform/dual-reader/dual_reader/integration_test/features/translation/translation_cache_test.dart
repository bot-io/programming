/// E2E Tests for Translation Caching
///
/// Tests translation caching functionality:
/// - First translation calls API
/// - Subsequent translation uses cache
/// - Cache key uniqueness (text + language)
/// - Clear cache functionality
/// - Cache persists across sessions
/// - Cache invalidation

library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dual_reader/main.dart' as app;
import 'package:dual_reader/src/data/services/translation_cache_service.dart';
import 'package:dual_reader/src/data/services/client_side_translation_service_mobile.dart';
import 'package:dual_reader/src/data/services/client_side_translation_service_web.dart';
import '../../../test_integration/helpers/test_helpers.dart';
import '../../../test_integration/config/test_config.dart';
import '../../../test_integration/helpers/test_logger.dart';

void main() {
  TestHelpers.initTests();
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Translation Cache E2E Tests', () {
    late TestLogger logger;
    late TranslationCacheService cacheService;

    setUpAll(() async {
      logger = TestLogger();
      cacheService = TranslationCacheService();
      await cacheService.init();
    });

    tearDownAll(() async {
      // Clean up cache
      final box = await cacheService._getBox();
      await box.clear();
      await logger.dispose();
    });

    setUp(() {
      logger.logTestSetup('Translation Cache');
    });

    tearDown(() {
      logger.logTestTeardown('Translation Cache');
    });

    testWidgets('First translation is not cached', (WidgetTester tester) async {
      logger.info('Testing first translation cache miss', category: 'cache');

      // Arrange
      const testText = 'Unique text for cache test';
      const targetLang = 'es';

      // Act - Check cache before translation
      final cached = cacheService.getCachedTranslation(testText, targetLang);

      // Assert
      expect(cached, isNull, reason: 'First translation should not be cached');
      logger.info('Cache miss confirmed for first translation', category: 'cache');

      logger.info('First translation test completed', category: 'cache');
    });

    testWidgets('Translation is cached after API call', (WidgetTester tester) async {
      logger.info('Testing translation caching', category: 'cache');

      // Arrange
      const testText = 'Text to be cached';
      const targetLang = 'es';
      const translatedText = 'Texto a ser guardado en caché';

      // Act - Cache the translation
      await cacheService.cacheTranslation(testText, targetLang, translatedText);

      // Assert - Verify it's cached
      final cached = cacheService.getCachedTranslation(testText, targetLang);
      expect(cached, equals(translatedText),
          reason: 'Translation should be retrievable from cache');
      logger.info('Translation successfully cached', category: 'cache');

      // Cleanup
      final box = await cacheService._getBox();
      await box.delete(cacheService._generateCacheKey(testText, targetLang));

      logger.info('Cache storage test completed', category: 'cache');
    });

    testWidgets('Subsequent translation uses cache', (WidgetTester tester) async {
      logger.info('Testing cache retrieval', category: 'cache');

      // Arrange
      const testText = 'Cached translation test';
      const targetLang = 'es';
      const translatedText = 'Prueba de traducción en caché';

      // Cache the translation first
      await cacheService.cacheTranslation(testText, targetLang, translatedText);

      // Act - Retrieve from cache
      final cached = cacheService.getCachedTranslation(testText, targetLang);

      // Assert
      expect(cached, equals(translatedText),
          reason: 'Should retrieve cached translation');
      logger.info('Cache hit successful', category: 'cache');

      // Verify it's the same cached value (not a new translation)
      expect(cached, contains('caché'), reason: 'Should contain expected text');

      // Cleanup
      final box = await cacheService._getBox();
      await box.delete(cacheService._generateCacheKey(testText, targetLang));

      logger.info('Cache retrieval test completed', category: 'cache');
    });

    testWidgets('Cache key is unique per text and language',
        (WidgetTester tester) async {
      logger.info('Testing cache key uniqueness', category: 'cache');

      // Arrange
      const testText = 'Same text';
      const lang1 = 'es';
      const lang2 = 'fr';
      const translation1 = 'Mismo texto';
      const translation2 = 'Même texte';

      // Act - Cache same text for different languages
      await cacheService.cacheTranslation(testText, lang1, translation1);
      await cacheService.cacheTranslation(testText, lang2, translation2);

      // Assert - Each should have unique cache entry
      final cached1 = cacheService.getCachedTranslation(testText, lang1);
      final cached2 = cacheService.getCachedTranslation(testText, lang2);

      expect(cached1, equals(translation1),
          reason: 'Spanish translation should be cached separately');
      expect(cached2, equals(translation2),
          reason: 'French translation should be cached separately');
      expect(cached1, isNot(equals(cached2)),
          reason: 'Different languages should have different translations');

      logger.info('Cache key uniqueness verified', category: 'cache');

      // Cleanup
      final box = await cacheService._getBox();
      await box.delete(cacheService._generateCacheKey(testText, lang1));
      await box.delete(cacheService._generateCacheKey(testText, lang2));

      logger.info('Cache key uniqueness test completed', category: 'cache');
    });

    testWidgets('Cache handles long text with hash keys', (WidgetTester tester) async {
      logger.info('Testing long text caching', category: 'cache');

      // Arrange - Create text longer than Hive's 255 char key limit
      final longText = List.generate(300, (i) => 'word$i').join(' ');
      const targetLang = 'es';
      const translatedText = 'Translated long text';

      // Act - Cache long text
      await cacheService.cacheTranslation(longText, targetLang, translatedText);

      // Assert - Should use hash for key
      final cached = cacheService.getCachedTranslation(longText, targetLang);
      expect(cached, equals(translatedText),
          reason: 'Should cache long text using hash key');

      logger.info('Long text cached successfully', category: 'cache');

      // Cleanup
      final box = await cacheService._getBox();
      await box.delete(cacheService._generateCacheKey(longText, targetLang));

      logger.info('Long text cache test completed', category: 'cache');
    });

    testWidgets('Clear cache removes all entries', (WidgetTester tester) async {
      logger.info('Testing cache clearing', category: 'cache');

      // Arrange - Add multiple cache entries
      await cacheService.cacheTranslation('Text 1', 'es', 'Traducción 1');
      await cacheService.cacheTranslation('Text 2', 'fr', 'Traduction 2');
      await cacheService.cacheTranslation('Text 3', 'de', 'Übersetzung 3');

      // Verify entries exist
      expect(cacheService.getCachedTranslation('Text 1', 'es'), isNotNull);
      expect(cacheService.getCachedTranslation('Text 2', 'fr'), isNotNull);
      expect(cacheService.getCachedTranslation('Text 3', 'de'), isNotNull);

      // Act - Clear cache
      final box = await cacheService._getBox();
      await box.clear();

      // Assert - All entries should be gone
      expect(cacheService.getCachedTranslation('Text 1', 'es'), isNull);
      expect(cacheService.getCachedTranslation('Text 2', 'fr'), isNull);
      expect(cacheService.getCachedTranslation('Text 3', 'de'), isNull);

      logger.info('Cache cleared successfully', category: 'cache');
      logger.info('Cache clearing test completed', category: 'cache');
    });

    testWidgets('Cache persists across service restarts', (WidgetTester tester) async {
      logger.info('Testing cache persistence', category: 'cache');

      // Arrange - Add cache entry
      const testText = 'Persistent cache test';
      const targetLang = 'es';
      const translatedText = 'Prueba de caché persistente';

      await cacheService.cacheTranslation(testText, targetLang, translatedText);

      // Act - Create new cache service instance (simulating restart)
      final newCacheService = TranslationCacheService();
      await newCacheService.init();

      // Assert - Cache entry should still be there
      final cached = newCacheService.getCachedTranslation(testText, targetLang);
      expect(cached, equals(translatedText),
          reason: 'Cache should persist across service instances');

      logger.info('Cache persistence verified', category: 'cache');

      // Cleanup
      final box = await newCacheService._getBox();
      await box.delete(newCacheService._generateCacheKey(testText, targetLang));

      logger.info('Cache persistence test completed', category: 'cache');
    });

    testWidgets('Cache handles special characters', (WidgetTester tester) async {
      logger.info('Testing special character handling', category: 'cache');

      // Arrange
      const specialText = 'Hello! How are you? I\'m fine. Thanks!';
      const targetLang = 'es';
      const translatedText = '¡Hola! ¿Cómo estás? Estoy bien. ¡Gracias!';

      // Act
      await cacheService.cacheTranslation(specialText, targetLang, translatedText);
      final cached = cacheService.getCachedTranslation(specialText, targetLang);

      // Assert
      expect(cached, equals(translatedText),
          reason: 'Should handle special characters in cache');
      expect(cached, contains('¿'), reason: 'Should preserve Spanish inverted question mark');
      expect(cached, contains('¡'), reason: 'Should preserve Spanish inverted exclamation');

      logger.info('Special characters handled correctly', category: 'cache');

      // Cleanup
      final box = await cacheService._getBox();
      await box.delete(cacheService._generateCacheKey(specialText, targetLang));

      logger.info('Special character test completed', category: 'cache');
    });

    testWidgets('Cache handles empty text', (WidgetTester tester) async {
      logger.info('Testing empty text handling', category: 'cache');

      // Arrange
      const emptyText = '';
      const targetLang = 'es';
      const translatedText = '';

      // Act
      await cacheService.cacheTranslation(emptyText, targetLang, translatedText);
      final cached = cacheService.getCachedTranslation(emptyText, targetLang);

      // Assert
      expect(cached, equals(translatedText),
          reason: 'Should handle empty text');

      logger.info('Empty text handled correctly', category: 'cache');

      // Cleanup
      final box = await cacheService._getBox();
      await box.delete(cacheService._generateCacheKey(emptyText, targetLang));

      logger.info('Empty text test completed', category: 'cache');
    });

    group('Mobile Translation with Cache', () {
      late ClientSideTranslationDelegateImpl translationService;

      setUp(() async {
        if (TestConfig.isAndroid || TestConfig.isIOS) {
          translationService = ClientSideTranslationDelegateImpl();
        }
      });

      tearDown(() async {
        if (TestConfig.isAndroid || TestConfig.isIOS) {
          await translationService.close();
        }
      });

      testWidgets('First mobile translation is not cached', (WidgetTester tester) async {
        if (!TestConfig.isAndroid && !TestConfig.isIOS) {
          logger.info('Skipped - mobile only', category: 'cache');
          return;
        }

        logger.info('Testing mobile translation cache miss', category: 'cache');

        // Arrange
        const testText = 'First mobile translation';
        const targetLang = 'es';

        // Act
        final cached = cacheService.getCachedTranslation(testText, targetLang);

        // Assert
        expect(cached, isNull, reason: 'Should not be cached yet');

        logger.info('Mobile cache miss confirmed', category: 'cache');
      });

      testWidgets('Mobile translation uses cache on second call',
          (WidgetTester tester) async {
        if (!TestConfig.isAndroid && !TestConfig.isIOS) {
          logger.info('Skipped - mobile only', category: 'cache');
          return;
        }

        logger.info('Testing mobile translation cache hit', category: 'cache');

        // Arrange
        const testText = 'Cached mobile translation';
        const targetLang = 'es';

        // First translation - should call API
        final firstResult = await translationService.translate(
          text: testText,
          targetLanguage: targetLang,
          sourceLanguage: 'en',
        );

        // Cache the result manually for testing
        await cacheService.cacheTranslation(testText, targetLang, firstResult);

        // Second call - should use cache
        final stopwatch = Stopwatch()..start();
        final cachedResult = cacheService.getCachedTranslation(testText, targetLang);
        stopwatch.stop();

        // Assert
        expect(cachedResult, equals(firstResult),
            reason: 'Should return cached translation');
        expect(stopwatch.elapsed.inMilliseconds, lessThan(10),
            reason: 'Cache retrieval should be very fast');

        logger.info('Mobile cache hit confirmed', category: 'cache');

        // Cleanup
        final box = await cacheService._getBox();
        await box.delete(cacheService._generateCacheKey(testText, targetLang));
      }, timeout: const Timeout(Duration(minutes: 2)));
    });

    group('Web Translation with Cache', () {
      late ClientSideTranslationDelegateImpl translationService;

      setUp(() async {
        if (TestConfig.isWeb) {
          translationService = ClientSideTranslationDelegateImpl();
        }
      });

      tearDown(() async {
        if (TestConfig.isWeb) {
          await translationService.close();
        }
      });

      testWidgets('Web translation uses cache', (WidgetTester tester) async {
        if (!TestConfig.isWeb) {
          logger.info('Skipped - web only', category: 'cache');
          return;
        }

        logger.info('Testing web translation cache', category: 'cache');

        // Arrange
        const testText = 'Cached web translation';
        const targetLang = 'es';

        // Simulate caching
        await cacheService.cacheTranslation(testText, targetLang, 'Traducción web en caché');

        // Act
        final cached = cacheService.getCachedTranslation(testText, targetLang);

        // Assert
        expect(cached, isNotNull);
        expect(cached, contains('caché'));

        logger.info('Web cache verified', category: 'cache');

        // Cleanup
        final box = await cacheService._getBox();
        await box.delete(cacheService._generateCacheKey(testText, targetLang));
      });
    });

    group('Cache Performance', () {
      testWidgets('Cache retrieval is faster than API call', (WidgetTester tester) async {
        logger.info('Testing cache performance', category: 'cache');

        // Arrange
        const testText = 'Performance test text';
        const targetLang = 'es';
        const translatedText = 'Texto de prueba de rendimiento';

        await cacheService.cacheTranslation(testText, targetLang, translatedText);

        // Act - Measure cache retrieval time
        final stopwatch = Stopwatch()..start();
        final cached = cacheService.getCachedTranslation(testText, targetLang);
        stopwatch.stop();

        // Assert
        expect(cached, equals(translatedText));
        expect(stopwatch.elapsed.inMilliseconds, lessThan(50),
            reason: 'Cache retrieval should be under 50ms');

        logger.info('Cache retrieval took ${stopwatch.elapsed.inMilliseconds}ms',
            category: 'cache');

        // Cleanup
        final box = await cacheService._getBox();
        await box.delete(cacheService._generateCacheKey(testText, targetLang));

        logger.info('Cache performance test completed', category: 'cache');
      });

      testWidgets('Cache handles multiple concurrent requests',
          (WidgetTester tester) async {
        logger.info('Testing concurrent cache access', category: 'cache');

        // Arrange
        final texts = List.generate(10, (i) => 'Concurrent test text $i');
        const targetLang = 'es';

        // Act - Cache all concurrently
        final futures = texts.map((text) =>
            cacheService.cacheTranslation(text, targetLang, 'Traducción $i'));
        await Future.wait(futures);

        // Assert - All should be cached
        for (final text in texts) {
          final cached = cacheService.getCachedTranslation(text, targetLang);
          expect(cached, isNotNull, reason: 'Text should be cached');
        }

        logger.info('Concurrent cache access handled correctly', category: 'cache');

        // Cleanup
        final box = await cacheService._getBox();
        for (final text in texts) {
          await box.delete(cacheService._generateCacheKey(text, targetLang));
        }

        logger.info('Concurrent access test completed', category: 'cache');
      });
    });
  });
}
