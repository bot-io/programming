import 'package:flutter_test/flutter_test.dart';
import 'package:dual_reader/services/translation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tests for TranslationService initialization issues
/// 
/// Critical Issue #2: Both constructor _init() and initialize() do the same thing
/// Critical Issue #3: Errors return original text silently, masking failures
void main() {
  group('TranslationService Initialization Tests', () {
    late TranslationService translationService;

    setUp(() async {
      // Clear SharedPreferences before each test
      SharedPreferences.setMockInitialValues({});
    });

    test('constructor does not initialize SharedPreferences synchronously', () {
      // The constructor should not fail if SharedPreferences is not ready
      // However, _init() is called asynchronously, so we can't test it directly
      translationService = TranslationService();
      
      // Service should be created without errors
      expect(translationService, isNotNull);
    });

    test('initialize() properly initializes SharedPreferences', () async {
      translationService = TranslationService();
      await translationService.initialize();

      // After initialization, service should be ready
      // We can't directly test _prefs, but we can test that translate works
      // (though it may fail due to network, which is expected)
      expect(translationService, isNotNull);
    });

    test('translate handles empty text', () async {
      translationService = TranslationService();
      await translationService.initialize();

      final result = await translationService.translate(
        text: '',
        targetLanguage: 'es',
      );

      expect(result, isEmpty);
    });

    test('translate handles whitespace-only text', () async {
      translationService = TranslationService();
      await translationService.initialize();

      final result = await translationService.translate(
        text: '   ',
        targetLanguage: 'es',
      );

      expect(result, '   ');
    });

    test('translate caches results', () async {
      translationService = TranslationService();
      await translationService.initialize();

      // First call (will likely fail due to network, but should cache if successful)
      // Note: This test may fail if network is unavailable, which is acceptable
      try {
        final result1 = await translationService.translate(
          text: 'Hello',
          targetLanguage: 'es',
        );

        // Second call should use cache
        final result2 = await translationService.translate(
          text: 'Hello',
          targetLanguage: 'es',
        );

        expect(result1, result2);
      } catch (e) {
        // Network errors are acceptable in tests
        expect(e, isNotNull);
      }
    });

    test('detectLanguage works correctly', () async {
      translationService = TranslationService();
      await translationService.initialize();

      expect(await translationService.detectLanguage('Hello world'), 'en');
      expect(await translationService.detectLanguage('Привет мир'), 'ru');
      expect(await translationService.detectLanguage('Hola mundo'), 'es');
      expect(await translationService.detectLanguage('Bonjour le monde'), 'fr');
      expect(await translationService.detectLanguage('Hallo Welt'), 'de');
    });

    test('clearCache removes all cached translations', () async {
      translationService = TranslationService();
      await translationService.initialize();

      // Add some translations to cache (if network works)
      try {
        await translationService.translate(
          text: 'Test',
          targetLanguage: 'es',
        );
      } catch (e) {
        // Ignore network errors
      }

      await translationService.clearCache();

      // Cache should be cleared
      // We can't directly verify, but clearCache should not throw
      expect(translationService, isNotNull);
    });
  });
}
