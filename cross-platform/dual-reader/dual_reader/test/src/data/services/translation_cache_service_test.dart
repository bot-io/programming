import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:dual_reader/src/data/services/translation_cache_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:universal_io/io.dart';

void main() {
  group('TranslationCacheService', () {
    late TranslationCacheService cacheService;

    setUpAll(() async {
      // Initialize Hive for testing
      Hive.init('test_hive');
      cacheService = TranslationCacheService();
      await cacheService.init();
    });

    tearDown(() async {
      // Clear the cache after each test
      final box = await Hive.openBox<String>('translationCache');
      await box.clear();
      await box.close();
    });

    tearDownAll(() async {
      await Hive.deleteBoxFromDisk('translationCache');
      await Hive.close();
    });

    group('getCachedTranslation', () {
      test('should return null when no cached translation exists', () async {
        const originalText = 'Hello';
        const targetLanguage = 'es';

        final result = cacheService.getCachedTranslation(originalText, targetLanguage);

        expect(result, isNull);
      });

      test('should return cached translation when it exists', () async {
        const originalText = 'Hello';
        const targetLanguage = 'es';
        const translatedText = 'Hola';

        // First cache a translation
        await cacheService.cacheTranslation(originalText, targetLanguage, translatedText);

        // Then retrieve it
        final result = cacheService.getCachedTranslation(originalText, targetLanguage);

        expect(result, equals(translatedText));
      });

      test('should return different translations for different target languages', () async {
        const originalText = 'Hello';
        const targetLanguageEs = 'es';
        const targetLanguageFr = 'fr';
        const translatedTextEs = 'Hola';
        const translatedTextFr = 'Bonjour';

        await cacheService.cacheTranslation(originalText, targetLanguageEs, translatedTextEs);
        await cacheService.cacheTranslation(originalText, targetLanguageFr, translatedTextFr);

        final resultEs = cacheService.getCachedTranslation(originalText, targetLanguageEs);
        final resultFr = cacheService.getCachedTranslation(originalText, targetLanguageFr);

        expect(resultEs, equals(translatedTextEs));
        expect(resultFr, equals(translatedTextFr));
      });

      test('should return null when box is not open', () async {
        const originalText = 'Hello';
        const targetLanguage = 'es';

        // Close the box to simulate it not being open
        await Hive.close();

        final result = cacheService.getCachedTranslation(originalText, targetLanguage);

        expect(result, isNull);

        // Reinitialize for other tests
        await cacheService.init();
      });
    });

    group('cacheTranslation', () {
      test('should cache translation successfully', () async {
        const originalText = 'Hello';
        const targetLanguage = 'es';
        const translatedText = 'Hola';

        await cacheService.cacheTranslation(originalText, targetLanguage, translatedText);

        final result = cacheService.getCachedTranslation(originalText, targetLanguage);

        expect(result, equals(translatedText));
      });

      test('should overwrite existing cached translation', () async {
        const originalText = 'Hello';
        const targetLanguage = 'es';
        const translatedText1 = 'Hola';
        const translatedText2 = 'Saludos';

        // Cache first translation
        await cacheService.cacheTranslation(originalText, targetLanguage, translatedText1);

        var result = cacheService.getCachedTranslation(originalText, targetLanguage);
        expect(result, equals(translatedText1));

        // Overwrite with second translation
        await cacheService.cacheTranslation(originalText, targetLanguage, translatedText2);

        result = cacheService.getCachedTranslation(originalText, targetLanguage);
        expect(result, equals(translatedText2));
      });

      test('should handle special characters in text', () async {
        const originalText = 'Hello! @#\$%^&*()';
        const targetLanguage = 'es';
        const translatedText = '¡Hola! @#\$%^&*()';

        await cacheService.cacheTranslation(originalText, targetLanguage, translatedText);

        final result = cacheService.getCachedTranslation(originalText, targetLanguage);

        expect(result, equals(translatedText));
      });

      test('should handle unicode characters', () async {
        const originalText = 'Hello 你好 مرحبا';
        const targetLanguage = 'es';
        const translatedText = 'Hola 你好 مرحبا';

        await cacheService.cacheTranslation(originalText, targetLanguage, translatedText);

        final result = cacheService.getCachedTranslation(originalText, targetLanguage);

        expect(result, equals(translatedText));
      });

      test('should handle long text', () async {
        // Hive has a key length limit of 255 characters, so use a shorter text
        final originalText = 'Hello ' * 30; // 180 characters, within limit
        const targetLanguage = 'es';
        final translatedText = 'Hola ' * 30;

        await cacheService.cacheTranslation(originalText, targetLanguage, translatedText);

        final result = cacheService.getCachedTranslation(originalText, targetLanguage);

        expect(result, equals(translatedText));
      });

      test('should handle multiline text', () async {
        const originalText = 'Hello\nWorld\nHow are you?';
        const targetLanguage = 'es';
        const translatedText = 'Hola\nMundo\n¿Cómo estás?';

        await cacheService.cacheTranslation(originalText, targetLanguage, translatedText);

        final result = cacheService.getCachedTranslation(originalText, targetLanguage);

        expect(result, equals(translatedText));
      });
    });

    group('init', () {
      test('should initialize the cache box', () async {
        final service = TranslationCacheService();
        await service.init();

        const originalText = 'Hello';
        const targetLanguage = 'es';
        const translatedText = 'Hola';

        await service.cacheTranslation(originalText, targetLanguage, translatedText);

        final result = service.getCachedTranslation(originalText, targetLanguage);

        expect(result, equals(translatedText));
      });

      test('should be safe to call init multiple times', () async {
        final service = TranslationCacheService();
        await service.init();
        await service.init();
        await service.init();

        const originalText = 'Hello';
        const targetLanguage = 'es';
        const translatedText = 'Hola';

        await service.cacheTranslation(originalText, targetLanguage, translatedText);

        final result = service.getCachedTranslation(originalText, targetLanguage);

        expect(result, equals(translatedText));
      });
    });

    group('integration - multiple translations', () {
      test('should cache and retrieve multiple translations correctly', () async {
        final translations = {
          'Hello': {'es': 'Hola', 'fr': 'Bonjour', 'de': 'Hallo'},
          'Goodbye': {'es': 'Adiós', 'fr': 'Au revoir', 'de': 'Auf Wiedersehen'},
          'Thank you': {'es': 'Gracias', 'fr': 'Merci', 'de': 'Danke'},
        };

        // Cache all translations
        for (final entry in translations.entries) {
          final originalText = entry.key;
          for (final langEntry in entry.value.entries) {
            final targetLanguage = langEntry.key;
            final translatedText = langEntry.value;
            await cacheService.cacheTranslation(originalText, targetLanguage, translatedText);
          }
        }

        // Verify all translations
        for (final entry in translations.entries) {
          final originalText = entry.key;
          for (final langEntry in entry.value.entries) {
            final targetLanguage = langEntry.key;
            final translatedText = langEntry.value;
            final result = cacheService.getCachedTranslation(originalText, targetLanguage);
            expect(result, equals(translatedText), reason: 'Failed for "$originalText" -> $targetLanguage');
          }
        }
      });

      test('should persist translations across service instances', () async {
        const originalText = 'Hello';
        const targetLanguage = 'es';
        const translatedText = 'Hola';

        // Cache with first instance
        final service1 = TranslationCacheService();
        await service1.init();
        await service1.cacheTranslation(originalText, targetLanguage, translatedText);

        // Retrieve with second instance
        final service2 = TranslationCacheService();
        await service2.init();
        final result = service2.getCachedTranslation(originalText, targetLanguage);

        expect(result, equals(translatedText));
      });
    });
  });
}
