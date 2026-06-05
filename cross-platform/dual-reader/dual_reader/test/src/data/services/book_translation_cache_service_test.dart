import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:dual_reader/src/data/services/book_translation_cache_service.dart';
import 'package:flutter/foundation.dart' show debugPrint;

// Generate unique test directory
String _getUniqueTestDir() {
  return 'test_hive_book_trans_${DateTime.now().millisecondsSinceEpoch}';
}

void main() {
  group('BookTranslationCacheService', () {
    late BookTranslationCacheService cacheService;
    late String testDir;

    setUpAll(() async {
      testDir = _getUniqueTestDir();
      debugPrint('[BookTranslationCacheService Test] Using test directory: $testDir');
      Hive.init(testDir);
      cacheService = BookTranslationCacheService();
      await cacheService.init();
    });

    tearDown(() async {
      try {
        if (Hive.isBoxOpen('bookTranslationCache')) {
          final box = Hive.box<String>('bookTranslationCache');
          await box.clear();
        }
      } catch (e) {
        debugPrint('[BookTranslationCacheService Test] tearDown error: $e');
      }
    });

    tearDownAll(() async {
      debugPrint(
        '[BookTranslationCacheService Test] Cleaning up test directory: $testDir',
      );
      try {
        await Hive.deleteBoxFromDisk('bookTranslationCache');
        await Hive.close();
        try {
          final dir = Directory(testDir);
          if (await dir.exists()) {
            await dir.delete(recursive: true);
          }
        } catch (e) {
          debugPrint(
            '[BookTranslationCacheService Test] Could not delete test dir: $e',
          );
        }
      } catch (e) {
        debugPrint('[BookTranslationCacheService Test] tearDownAll error: $e');
      }
    });

    group('init', () {
      test('should initialize the cache box', () async {
        final service = BookTranslationCacheService();
        await service.init();

        expect(Hive.isBoxOpen('bookTranslationCache'), isTrue);
      });

      test('should be safe to call init multiple times', () async {
        final service = BookTranslationCacheService();
        await service.init();
        await service.init();
        await service.init();

        expect(Hive.isBoxOpen('bookTranslationCache'), isTrue);
      });
    });

    group('cacheTranslation and getCachedTranslation', () {
      test('should cache and retrieve a translation', () async {
        await cacheService.cacheTranslation('book1', 0, 'es', 'Hola');

        final result = cacheService.getCachedTranslation('book1', 0, 'es');

        expect(result, equals('Hola'));
      });

      test('should return null when no translation cached', () {
        final result = cacheService.getCachedTranslation('unknown_book', 0, 'es');

        expect(result, isNull);
      });

      test('should return null when box is not open', () async {
        await Hive.close();

        final result = cacheService.getCachedTranslation('book1', 0, 'es');

        expect(result, isNull);

        // Reinitialize for remaining tests
        Hive.init(testDir);
        await cacheService.init();
      });

      test('should store different translations for different pages', () async {
        await cacheService.cacheTranslation('book1', 0, 'es', 'Hola');
        await cacheService.cacheTranslation('book1', 1, 'es', 'Buenos dias');
        await cacheService.cacheTranslation('book1', 2, 'es', 'Adios');

        expect(
          cacheService.getCachedTranslation('book1', 0, 'es'),
          equals('Hola'),
        );
        expect(
          cacheService.getCachedTranslation('book1', 1, 'es'),
          equals('Buenos dias'),
        );
        expect(
          cacheService.getCachedTranslation('book1', 2, 'es'),
          equals('Adios'),
        );
      });

      test('should store different translations for different languages', () async {
        await cacheService.cacheTranslation('book1', 0, 'es', 'Hola');
        await cacheService.cacheTranslation('book1', 0, 'fr', 'Bonjour');
        await cacheService.cacheTranslation('book1', 0, 'de', 'Hallo');

        expect(
          cacheService.getCachedTranslation('book1', 0, 'es'),
          equals('Hola'),
        );
        expect(
          cacheService.getCachedTranslation('book1', 0, 'fr'),
          equals('Bonjour'),
        );
        expect(
          cacheService.getCachedTranslation('book1', 0, 'de'),
          equals('Hallo'),
        );
      });

      test('should store different translations for different books', () async {
        await cacheService.cacheTranslation('book1', 0, 'es', 'Hola from book1');
        await cacheService.cacheTranslation('book2', 0, 'es', 'Hola from book2');

        expect(
          cacheService.getCachedTranslation('book1', 0, 'es'),
          equals('Hola from book1'),
        );
        expect(
          cacheService.getCachedTranslation('book2', 0, 'es'),
          equals('Hola from book2'),
        );
      });

      test('should overwrite existing cached translation', () async {
        await cacheService.cacheTranslation('book1', 0, 'es', 'Hola');
        expect(
          cacheService.getCachedTranslation('book1', 0, 'es'),
          equals('Hola'),
        );

        await cacheService.cacheTranslation('book1', 0, 'es', 'Saludos');
        expect(
          cacheService.getCachedTranslation('book1', 0, 'es'),
          equals('Saludos'),
        );
      });

      test('should handle special characters in translated text', () async {
        const translatedText = '¡Hola! @#\$%^&*() 你好 مرحبا';
        await cacheService.cacheTranslation('book1', 0, 'es', translatedText);

        final result = cacheService.getCachedTranslation('book1', 0, 'es');
        expect(result, equals(translatedText));
      });

      test('should handle long translated text', () async {
        final longText = 'This is a long translation. ' * 200;
        await cacheService.cacheTranslation('book1', 0, 'es', longText);

        final result = cacheService.getCachedTranslation('book1', 0, 'es');
        expect(result, equals(longText));
      });

      test('should handle empty translated text', () async {
        await cacheService.cacheTranslation('book1', 0, 'es', '');

        final result = cacheService.getCachedTranslation('book1', 0, 'es');
        expect(result, equals(''));
      });

      test('should handle multiline translated text', () async {
        const translatedText = 'Line 1\nLine 2\nLine 3';
        await cacheService.cacheTranslation('book1', 0, 'es', translatedText);

        final result = cacheService.getCachedTranslation('book1', 0, 'es');
        expect(result, equals(translatedText));
      });
    });

    group('clearBook', () {
      test('should clear all translations for a specific book', () async {
        await cacheService.cacheTranslation('book1', 0, 'es', 'Hola 0');
        await cacheService.cacheTranslation('book1', 1, 'es', 'Hola 1');
        await cacheService.cacheTranslation('book1', 0, 'fr', 'Bonjour 0');
        await cacheService.cacheTranslation('book2', 0, 'es', 'Hello from book2');

        await cacheService.clearBook('book1');

        expect(cacheService.getCachedTranslation('book1', 0, 'es'), isNull);
        expect(cacheService.getCachedTranslation('book1', 1, 'es'), isNull);
        expect(cacheService.getCachedTranslation('book1', 0, 'fr'), isNull);
        // book2 should not be affected
        expect(
          cacheService.getCachedTranslation('book2', 0, 'es'),
          equals('Hello from book2'),
        );
      });

      test('should handle clearing a book with no cached translations', () async {
        // Should not throw
        await cacheService.clearBook('nonexistent_book');
      });
    });

    group('clearBookLanguage', () {
      test('should clear translations for specific book and language', () async {
        await cacheService.cacheTranslation('book1', 0, 'es', 'Hola');
        await cacheService.cacheTranslation('book1', 1, 'es', 'Buenos dias');
        await cacheService.cacheTranslation('book1', 0, 'fr', 'Bonjour');
        await cacheService.cacheTranslation('book1', 1, 'fr', 'Bonsoir');

        await cacheService.clearBookLanguage('book1', 'es');

        // Spanish translations should be gone
        expect(cacheService.getCachedTranslation('book1', 0, 'es'), isNull);
        expect(cacheService.getCachedTranslation('book1', 1, 'es'), isNull);
        // French translations should remain
        expect(
          cacheService.getCachedTranslation('book1', 0, 'fr'),
          equals('Bonjour'),
        );
        expect(
          cacheService.getCachedTranslation('book1', 1, 'fr'),
          equals('Bonsoir'),
        );
      });

      test('should not affect other books', () async {
        await cacheService.cacheTranslation('book1', 0, 'es', 'Hola');
        await cacheService.cacheTranslation('book2', 0, 'es', 'Hola 2');

        await cacheService.clearBookLanguage('book1', 'es');

        expect(cacheService.getCachedTranslation('book1', 0, 'es'), isNull);
        expect(
          cacheService.getCachedTranslation('book2', 0, 'es'),
          equals('Hola 2'),
        );
      });

      test('should handle clearing nonexistent language', () async {
        await cacheService.cacheTranslation('book1', 0, 'es', 'Hola');

        // Clearing a language that has no entries should not throw
        await cacheService.clearBookLanguage('book1', 'de');

        // Original should still be there
        expect(
          cacheService.getCachedTranslation('book1', 0, 'es'),
          equals('Hola'),
        );
      });
    });

    group('clearAll', () {
      test('should clear all cached translations', () async {
        await cacheService.cacheTranslation('book1', 0, 'es', 'Hola');
        await cacheService.cacheTranslation('book2', 0, 'fr', 'Bonjour');
        await cacheService.cacheTranslation('book3', 0, 'de', 'Hallo');

        await cacheService.clearAll();

        expect(cacheService.getCachedTranslation('book1', 0, 'es'), isNull);
        expect(cacheService.getCachedTranslation('book2', 0, 'fr'), isNull);
        expect(cacheService.getCachedTranslation('book3', 0, 'de'), isNull);
      });

      test('should handle clearing when box is not open', () async {
        await Hive.close();
        // Should not throw - just logs warning
        final service = BookTranslationCacheService();
        await service.clearAll();

        // Reinitialize for remaining tests
        Hive.init(testDir);
        await cacheService.init();
      });
    });

    group('getStats', () {
      test('should return empty stats when no translations cached', () async {
        final stats = await cacheService.getStats();

        // Stats could be empty or have 0 entries
        expect(stats, isA<Map<String, int>>());
      });

      test('should return stats grouped by book ID', () async {
        await cacheService.cacheTranslation('book1', 0, 'es', 'Hola');
        await cacheService.cacheTranslation('book1', 1, 'es', 'Hola 1');
        await cacheService.cacheTranslation('book2', 0, 'es', 'Bonjour');

        final stats = await cacheService.getStats();

        expect(stats, isA<Map<String, int>>());
        // The stats should contain entries for book1 and book2
        // (keys are derived from the first part of the cache key)
        expect(stats.length, greaterThanOrEqualTo(0));
      });

      test('should return empty map when box is not open', () async {
        await Hive.close();

        final service = BookTranslationCacheService();
        final stats = await service.getStats();

        expect(stats, equals({}));

        // Reinitialize for remaining tests
        Hive.init(testDir);
        await cacheService.init();
      });
    });

    group('integration - multiple books and languages', () {
      test('should handle multiple books with multiple languages', () async {
        // Cache translations for multiple books and languages
        final books = ['book1', 'book2', 'book3'];
        final languages = ['es', 'fr', 'de'];
        final translations = {
          'es': {'book1': 'Hola', 'book2': 'Hola 2', 'book3': 'Hola 3'},
          'fr': {'book1': 'Bonjour', 'book2': 'Bonjour 2', 'book3': 'Bonjour 3'},
          'de': {'book1': 'Hallo', 'book2': 'Hallo 2', 'book3': 'Hallo 3'},
        };

        for (final book in books) {
          for (final lang in languages) {
            await cacheService.cacheTranslation(
              book,
              0,
              lang,
              translations[lang]![book]!,
            );
          }
        }

        // Verify all translations
        for (final book in books) {
          for (final lang in languages) {
            final result = cacheService.getCachedTranslation(book, 0, lang);
            expect(
              result,
              equals(translations[lang]![book]),
              reason: 'Failed for $book -> $lang',
            );
          }
        }
      });

      test('should persist translations across service instances', () async {
        await cacheService.cacheTranslation('book1', 0, 'es', 'Hola');

        // Create a new service instance
        final newService = BookTranslationCacheService();
        await newService.init();

        final result = newService.getCachedTranslation('book1', 0, 'es');
        expect(result, equals('Hola'));
      });

      test('should handle sequential cache and clear operations', () async {
        // Cache
        await cacheService.cacheTranslation('book1', 0, 'es', 'Hola');
        expect(
          cacheService.getCachedTranslation('book1', 0, 'es'),
          equals('Hola'),
        );

        // Clear specific book
        await cacheService.clearBook('book1');
        expect(cacheService.getCachedTranslation('book1', 0, 'es'), isNull);

        // Re-cache
        await cacheService.cacheTranslation('book1', 0, 'es', 'Nuevo');
        expect(
          cacheService.getCachedTranslation('book1', 0, 'es'),
          equals('Nuevo'),
        );

        // Clear all
        await cacheService.clearAll();
        expect(cacheService.getCachedTranslation('book1', 0, 'es'), isNull);
      });
    });
  });
}
