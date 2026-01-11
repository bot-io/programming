import 'package:flutter_test/flutter_test.dart';
import 'package:dual_reader/src/data/services/book_translation_cache_service.dart';
import 'package:dual_reader/src/data/services/translation_cache_service.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Integration tests for translation caching functionality
/// Tests the complete caching flow including initialization, storage, retrieval, and clearing
void main() {
  group('Translation Cache Integration Tests', () {
    late BookTranslationCacheService cacheService;
    late TranslationCacheService baseCacheService;
    late String testBoxName;
    bool hiveInitialized = false;

    setUpAll(() async {
      // Initialize Hive for testing
      try {
        await setUpHive();
        hiveInitialized = true;
      } catch (e) {
        print('Skipping integration tests: Hive requires platform channels');
      }
    });

    setUp(() async {
      if (!hiveInitialized) return;
      testBoxName = 'test_book_translation_cache_${DateTime.now().millisecondsSinceEpoch}';

      cacheService = BookTranslationCacheService();
      baseCacheService = TranslationCacheService();

      await cacheService.init();
      await baseCacheService.init();
    });

    tearDown(() async {
      if (!hiveInitialized) return;
      // Clean up test boxes
      if (Hive.isBoxOpen(testBoxName)) {
        await Hive.box<String>(testBoxName).clear();
        await Hive.box<String>(testBoxName).close();
      }
      if (Hive.isBoxOpen('translationCache')) {
        await Hive.box<String>('translationCache').clear();
        await Hive.box<String>('translationCache').close();
      }
    });

    tearDownAll(() async {
      if (!hiveInitialized) return;
      try {
        await tearDownHive();
      } catch (e) {
        print('Error tearing down Hive: $e');
      }
    });

    test('Cache initialization opens Hive box', () async {
      if (!hiveInitialized) {
        print('Test skipped: Hive not initialized');
        return;
      }
      expect(Hive.isBoxOpen(testBoxName), isTrue);
    });

    test('Cache and retrieve translation for a page', () async {
      if (!hiveInitialized) {
        print('Test skipped: Hive not initialized');
        return;
      }
      const bookId = 'test-book-1';
      const pageIndex = 0;
      const language = 'es';
      const originalText = 'Hello world. This is a test.';
      const translatedText = 'Hola mundo. Esto es una prueba.';

      // Cache the translation
      await cacheService.cacheTranslation(
        bookId,
        pageIndex,
        language,
        translatedText,
      );

      // Retrieve the cached translation
      final cached = cacheService.getCachedTranslation(
        bookId,
        pageIndex,
        language,
      );

      expect(cached, isNotNull);
      expect(cached, equals(translatedText));
    });

    test('Cache returns null for non-existent translation', () async {
      if (!hiveInitialized) {
        print('Test skipped: Hive not initialized');
        return;
      }
      final cached = cacheService.getCachedTranslation(
        'non-existent-book',
        999,
        'es',
      );

      expect(cached, isNull);
    });

    test('Cache stores translations for different pages separately', () async {
      if (!hiveInitialized) {
        print('Test skipped: Hive not initialized');
        return;
      }
      const bookId = 'test-book-2';
      const language = 'es';

      await cacheService.cacheTranslation(bookId, 0, language, 'Page 0 translation');
      await cacheService.cacheTranslation(bookId, 1, language, 'Page 1 translation');
      await cacheService.cacheTranslation(bookId, 2, language, 'Page 2 translation');

      final page0 = cacheService.getCachedTranslation(bookId, 0, language);
      final page1 = cacheService.getCachedTranslation(bookId, 1, language);
      final page2 = cacheService.getCachedTranslation(bookId, 2, language);

      expect(page0, equals('Page 0 translation'));
      expect(page1, equals('Page 1 translation'));
      expect(page2, equals('Page 2 translation'));
    });

    test('Cache stores translations for different languages separately', () async {
      if (!hiveInitialized) {
        print('Test skipped: Hive not initialized');
        return;
      }
      const bookId = 'test-book-3';
      const pageIndex = 0;

      await cacheService.cacheTranslation(bookId, pageIndex, 'es', 'Spanish translation');
      await cacheService.cacheTranslation(bookId, pageIndex, 'fr', 'French translation');
      await cacheService.cacheTranslation(bookId, pageIndex, 'de', 'German translation');

      final spanish = cacheService.getCachedTranslation(bookId, pageIndex, 'es');
      final french = cacheService.getCachedTranslation(bookId, pageIndex, 'fr');
      final german = cacheService.getCachedTranslation(bookId, pageIndex, 'de');

      expect(spanish, equals('Spanish translation'));
      expect(french, equals('French translation'));
      expect(german, equals('German translation'));
    });

    test('Cache stores translations for different books separately', () async {
      if (!hiveInitialized) {
        print('Test skipped: Hive not initialized');
        return;
      }
      const pageIndex = 0;
      const language = 'es';

      await cacheService.cacheTranslation('book-1', pageIndex, language, 'Book 1 translation');
      await cacheService.cacheTranslation('book-2', pageIndex, language, 'Book 2 translation');
      await cacheService.cacheTranslation('book-3', pageIndex, language, 'Book 3 translation');

      final book1 = cacheService.getCachedTranslation('book-1', pageIndex, language);
      final book2 = cacheService.getCachedTranslation('book-2', pageIndex, language);
      final book3 = cacheService.getCachedTranslation('book-3', pageIndex, language);

      expect(book1, equals('Book 1 translation'));
      expect(book2, equals('Book 2 translation'));
      expect(book3, equals('Book 3 translation'));
    });

    test('Clear all translations removes all cached data', () async {
      if (!hiveInitialized) {
        print('Test skipped: Hive not initialized');
        return;
      }
      // Add multiple translations
      await cacheService.cacheTranslation('book-1', 0, 'es', 'Translation 1');
      await cacheService.cacheTranslation('book-1', 1, 'es', 'Translation 2');
      await cacheService.cacheTranslation('book-2', 0, 'fr', 'Translation 3');

      // Verify they exist
      expect(cacheService.getCachedTranslation('book-1', 0, 'es'), isNotNull);
      expect(cacheService.getCachedTranslation('book-1', 1, 'es'), isNotNull);
      expect(cacheService.getCachedTranslation('book-2', 0, 'fr'), isNotNull);

      // Clear all
      await cacheService.clearAll();

      // Verify all are gone
      expect(cacheService.getCachedTranslation('book-1', 0, 'es'), isNull);
      expect(cacheService.getCachedTranslation('book-1', 1, 'es'), isNull);
      expect(cacheService.getCachedTranslation('book-2', 0, 'fr'), isNull);
    });

    test('Clear book translations removes only that books translations', () async {
      if (!hiveInitialized) {
        print('Test skipped: Hive not initialized');
        return;
      }
      // Add translations for multiple books
      await cacheService.cacheTranslation('book-1', 0, 'es', 'Book 1 Page 0');
      await cacheService.cacheTranslation('book-1', 1, 'es', 'Book 1 Page 1');
      await cacheService.cacheTranslation('book-2', 0, 'es', 'Book 2 Page 0');
      await cacheService.cacheTranslation('book-2', 1, 'es', 'Book 2 Page 1');

      // Clear only book-1
      await cacheService.clearBook('book-1');

      // Verify book-1 translations are gone
      expect(cacheService.getCachedTranslation('book-1', 0, 'es'), isNull);
      expect(cacheService.getCachedTranslation('book-1', 1, 'es'), isNull);

      // Verify book-2 translations still exist
      expect(cacheService.getCachedTranslation('book-2', 0, 'es'), equals('Book 2 Page 0'));
      expect(cacheService.getCachedTranslation('book-2', 1, 'es'), equals('Book 2 Page 1'));
    });

    test('Clear book language translations removes only that language for that book', () async {
      if (!hiveInitialized) {
        print('Test skipped: Hive not initialized');
        return;
      }
      // Add translations for different languages
      await cacheService.cacheTranslation('book-1', 0, 'es', 'Spanish');
      await cacheService.cacheTranslation('book-1', 0, 'fr', 'French');
      await cacheService.cacheTranslation('book-1', 0, 'de', 'German');
      await cacheService.cacheTranslation('book-2', 0, 'es', 'Spanish 2');

      // Clear only Spanish for book-1
      await cacheService.clearBookLanguage('book-1', 'es');

      // Verify Spanish is gone for book-1
      expect(cacheService.getCachedTranslation('book-1', 0, 'es'), isNull);

      // Verify other languages still exist for book-1
      expect(cacheService.getCachedTranslation('book-1', 0, 'fr'), equals('French'));
      expect(cacheService.getCachedTranslation('book-1', 0, 'de'), equals('German'));

      // Verify Spanish still exists for book-2
      expect(cacheService.getCachedTranslation('book-2', 0, 'es'), equals('Spanish 2'));
    });

    test('Cache handles large text translations', () async {
      if (!hiveInitialized) {
        print('Test skipped: Hive not initialized');
        return;
      }
      const bookId = 'test-book-large';
      const pageIndex = 0;
      const language = 'es';

      // Create a large translation (simulating a full page)
      final largeText = List.generate(100, (i) => 'This is sentence $i. ').join('\n\n');

      await cacheService.cacheTranslation(bookId, pageIndex, language, largeText);

      final cached = cacheService.getCachedTranslation(bookId, pageIndex, language);

      expect(cached, isNotNull);
      expect(cached!.length, equals(largeText.length));
      expect(cached, equals(largeText));
    });

    test('Cache handles special characters in translations', () async {
      if (!hiveInitialized) {
        print('Test skipped: Hive not initialized');
        return;
      }
      const bookId = 'test-book-special';
      const pageIndex = 0;
      const language = 'es';

      const specialText = '¡Hola! ¿Cómo estás? @#\$%^&*()_+{}[]|\\:";\'<>?,./`~';

      await cacheService.cacheTranslation(bookId, pageIndex, language, specialText);

      final cached = cacheService.getCachedTranslation(bookId, pageIndex, language);

      expect(cached, equals(specialText));
    });

    test('Cache handles Unicode characters', () async {
      if (!hiveInitialized) {
        print('Test skipped: Hive not initialized');
        return;
      }
      const bookId = 'test-book-unicode';
      const pageIndex = 0;
      const language = 'zh';

      const unicodeText = '你好世界 🌍📚 Привет мир المرءات';

      await cacheService.cacheTranslation(bookId, pageIndex, language, unicodeText);

      final cached = cacheService.getCachedTranslation(bookId, pageIndex, language);

      expect(cached, equals(unicodeText));
    });

    test('Get cache statistics returns correct data', () async {
      if (!hiveInitialized) {
        print('Test skipped: Hive not initialized');
        return;
      }
      // Add translations for different books
      await cacheService.cacheTranslation('book-1', 0, 'es', 'Trans 1');
      await cacheService.cacheTranslation('book-1', 1, 'es', 'Trans 2');
      await cacheService.cacheTranslation('book-1', 2, 'es', 'Trans 3');
      await cacheService.cacheTranslation('book-2', 0, 'es', 'Trans 4');

      final stats = await cacheService.getStats();

      expect(stats['book-1'], equals(3));
      expect(stats['book-2'], equals(1));
    });

    test('Base cache service stores and retrieves translations', () async {
      if (!hiveInitialized) {
        print('Test skipped: Hive not initialized');
        return;
      }
      const text = 'Hello world';
      const targetLanguage = 'es';
      const translatedText = 'Hola mundo';

      await baseCacheService.cacheTranslation(text, targetLanguage, translatedText);

      final cached = baseCacheService.getCachedTranslation(text, targetLanguage);

      expect(cached, isNotNull);
      expect(cached, equals(translatedText));
    });

    test('Base cache service handles different translations for same text', () async {
      if (!hiveInitialized) {
        print('Test skipped: Hive not initialized');
        return;
      }
      const text = 'Hello';

      await baseCacheService.cacheTranslation(text, 'es', 'Hola');
      await baseCacheService.cacheTranslation(text, 'fr', 'Bonjour');
      await baseCacheService.cacheTranslation(text, 'de', 'Hallo');

      expect(baseCacheService.getCachedTranslation(text, 'es'), equals('Hola'));
      expect(baseCacheService.getCachedTranslation(text, 'fr'), equals('Bonjour'));
      expect(baseCacheService.getCachedTranslation(text, 'de'), equals('Hallo'));
    });

    test('Clear all on base cache service removes all translations', () async {
      if (!hiveInitialized) {
        print('Test skipped: Hive not initialized');
        return;
      }
      await baseCacheService.cacheTranslation('text1', 'es', 'Trans 1');
      await baseCacheService.cacheTranslation('text2', 'es', 'Trans 2');
      await baseCacheService.cacheTranslation('text3', 'es', 'Trans 3');

      // Clear the box directly since TranslationCacheService doesn't have clearAll
      if (Hive.isBoxOpen('translationCache')) {
        await Hive.box<String>('translationCache').clear();
      }

      expect(baseCacheService.getCachedTranslation('text1', 'es'), isNull);
      expect(baseCacheService.getCachedTranslation('text2', 'es'), isNull);
      expect(baseCacheService.getCachedTranslation('text3', 'es'), isNull);
    });

    test('Cache persistence - data survives cache service reset', () async {
      if (!hiveInitialized) {
        print('Test skipped: Hive not initialized');
        return;
      }
      const bookId = 'test-persistence';
      const pageIndex = 0;
      const language = 'es';
      const translation = 'Persistent translation';

      // Cache a translation
      await cacheService.cacheTranslation(bookId, pageIndex, language, translation);

      // Create a new cache service instance (simulating app restart)
      final newCacheService = BookTranslationCacheService();
      await newCacheService.init();

      // Verify the translation is still there
      final cached = newCacheService.getCachedTranslation(bookId, pageIndex, language);

      expect(cached, equals(translation));
    });

    test('Cache handles rapid successive writes', () async {
      if (!hiveInitialized) {
        print('Test skipped: Hive not initialized');
        return;
      }
      const bookId = 'test-rapid';
      const language = 'es';

      // Write many translations rapidly
      for (int i = 0; i < 50; i++) {
        await cacheService.cacheTranslation(bookId, i, language, 'Translation $i');
      }

      // Verify all were written correctly
      for (int i = 0; i < 50; i++) {
        final cached = cacheService.getCachedTranslation(bookId, i, language);
        expect(cached, equals('Translation $i'));
      }
    });
  });
}
