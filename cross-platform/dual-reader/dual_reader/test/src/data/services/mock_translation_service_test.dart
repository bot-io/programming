import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:dual_reader/src/data/services/mock_translation_service_impl.dart';
import 'package:dual_reader/src/data/services/translation_cache_service.dart';

void main() {
  group('MockTranslationServiceImpl', () {
    late MockTranslationServiceImpl service;
    late TranslationCacheService cacheService;

    setUpAll(() async {
      Hive.init('test_hive');
      cacheService = TranslationCacheService();
      await cacheService.init();
    });

    setUp(() {
      service = MockTranslationServiceImpl(cacheService);
    });

    tearDown(() async {
      final box = await Hive.openBox<String>('translationCache');
      await box.clear();
      await box.close();
    });

    tearDownAll(() async {
      await Hive.deleteBoxFromDisk('translationCache');
      await Hive.close();
    });

    group('translate - core functionality', () {
      test('should translate English to Spanish and cache result', () async {
        const text = 'hello world';
        const targetLanguage = 'es';

        print('[TEST] Translating "$text" to $targetLanguage...');
        final result = await service.translate(text: text, targetLanguage: targetLanguage);
        print('[TEST] Translation result: "$result"');

        expect(result, contains('hola'));
        expect(result, contains('mundo'));
        expect(result, contains('🇪🇸 Spanish'));

        // Verify caching - second call should be faster
        final stopwatch = Stopwatch()..start();
        await service.translate(text: text, targetLanguage: targetLanguage);
        stopwatch.stop();
        print('[TEST] Second translation took: ${stopwatch.elapsedMilliseconds}ms (should be cached)');
        expect(stopwatch.elapsedMilliseconds, lessThan(100));
      });

      test('should use alternative language when source equals target', () async {
        const text = 'hello world';
        const targetLanguage = 'en';

        print('[TEST] Testing source=language=$targetLanguage scenario...');
        final result = await service.translate(
          text: text,
          targetLanguage: targetLanguage,
          sourceLanguage: 'en', // Force detection to match target
        );
        print('[TEST] Alternative result: "$result"');

        // Should translate to Spanish (first alternative)
        expect(result, contains('hola'));
        expect(result, contains('🇪🇸 Spanish'));
      });

      test('should handle text with no common words', () async {
        const text = 'xyz abc def unknown words';
        const targetLanguage = 'es';

        print('[TEST] Testing unknown words...');
        final result = await service.translate(text: text, targetLanguage: targetLanguage);
        print('[TEST] Result for unknown words: "$result"');

        expect(result, contains('[🇪🇸 Spanish]'));
        expect(result, contains(text));
      });

      test('should return text unchanged when translating to English', () async {
        const text = 'hola mundo';
        const targetLanguage = 'en';

        print('[TEST] Translating to English (should be unchanged)...');
        final result = await service.translate(
          text: text,
          targetLanguage: targetLanguage,
          sourceLanguage: 'es',
        );
        print('[TEST] Result: "$result"');

        expect(result, equals(text));
      });
    });

    group('detectLanguage', () {
      test('should detect English as default', () async {
        const text = 'hello world this is a test';

        print('[TEST] Detecting language for: "$text"');
        final result = await service.detectLanguage(text);
        print('[TEST] Detected language: $result');

        expect(result, equals('en'));
      });

      test('should detect Spanish', () async {
        const text = 'hola mundo los amigos';

        print('[TEST] Detecting Spanish...');
        final result = await service.detectLanguage(text);
        print('[TEST] Detected: $result');

        expect(result, equals('es'));
      });

      test('should detect Cyrillic as Bulgarian or Russian', () async {
        const text = 'здравейте свят';

        print('[TEST] Detecting Cyrillic...');
        final result = await service.detectLanguage(text);
        print('[TEST] Detected Cyrillic as: $result');

        expect(result, isIn(['bg', 'ru']));
      });

      test('should detect Chinese characters', () async {
        const text = '你好世界';

        print('[TEST] Detecting Chinese characters...');
        final result = await service.detectLanguage(text);
        print('[TEST] Detected: $result');

        expect(result, equals('zh'));
      });
    });

    group('caching', () {
      test('should cache and reuse translations', () async {
        const text = 'hello world';
        const targetLanguage = 'es';

        print('[TEST] Testing caching behavior...');
        final result1 = await service.translate(text: text, targetLanguage: targetLanguage);
        final result2 = await service.translate(text: text, targetLanguage: targetLanguage);
        print('[TEST] Both results identical: ${result1 == result2}');

        expect(result1, equals(result2));
      });
    });

    group('performance', () {
      test('should translate within reasonable time', () async {
        const text = 'hello world this is a test';
        const targetLanguage = 'es';

        final stopwatch = Stopwatch()..start();
        await service.translate(text: text, targetLanguage: targetLanguage);
        stopwatch.stop();

        print('[TEST] Translation took: ${stopwatch.elapsedMilliseconds}ms');
        expect(stopwatch.elapsedMilliseconds, lessThan(1000));
      });
    });
  });
}
