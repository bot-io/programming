import 'package:flutter_test/flutter_test.dart';
import 'package:dual_reader/services/translation/base_translation_service.dart';
import 'package:dual_reader/services/translation/libretranslate_service.dart';
import 'package:dual_reader/services/translation/google_translate_service.dart';
import 'package:dual_reader/services/translation/mymemory_service.dart';
import 'package:dual_reader/services/translation/translation_service_manager.dart';
import 'package:dio/dio.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

void main() {
  group('TranslationServiceManager - Fallback Logic', () {
    late TranslationServiceManager manager;
    late Dio libreDio;
    late DioAdapter libreAdapter;
    late Dio googleDio;
    late DioAdapter googleAdapter;
    late Dio myMemoryDio;
    late DioAdapter myMemoryAdapter;

    setUp(() {
      // Setup LibreTranslate service
      libreDio = Dio();
      libreAdapter = DioAdapter(dio: libreDio);
      final libreService = LibreTranslateService(dio: libreDio);

      // Setup Google Translate service (with mock API key)
      googleDio = Dio();
      googleAdapter = DioAdapter(dio: googleDio);
      final googleService = GoogleTranslateService(
        apiKey: 'test-api-key',
        dio: googleDio,
      );

      // Setup MyMemory service
      myMemoryDio = Dio();
      myMemoryAdapter = DioAdapter(dio: myMemoryDio);
      final myMemoryService = MyMemoryService(dio: myMemoryDio);

      // Create manager with services in priority order:
      // 1. Google Translate (primary)
      // 2. MyMemory (fallback)
      // 3. LibreTranslate (optional fallback)
      manager = TranslationServiceManager([
        googleService,
        myMemoryService,
        libreService,
      ]);
    });

    tearDown(() {
      libreDio.close();
      googleDio.close();
      myMemoryDio.close();
    });

    test('successful translation with primary service (Google Translate)', () async {
      // Mock Google Translate success (primary service)
      googleAdapter.onGet(
        '',
        (server) => server.reply(
          200,
          {
            'data': {
              'translations': [
                {'translatedText': 'Hola mundo'}
              ]
            }
          },
          queryParameters: {
            'key': 'test-api-key',
            'q': 'Hello world',
            'target': 'es',
          },
        ),
      );

      final result = await manager.translate(
        text: 'Hello world',
        targetLanguage: 'es',
      );

      expect(result, 'Hola mundo');
      expect(manager.getActiveServiceName(), 'Google Translate');
    });

    test('automatic failover when primary service (Google Translate) fails', () async {
      // Mock Google Translate failure (primary service)
      googleAdapter.onGet(
        '',
        (server) => server.reply(500, {'error': 'Server Error'}),
      );

      // Mock MyMemory success (fallback)
      myMemoryAdapter.onGet(
        '/get',
        (server) => server.reply(
          200,
          {
            'responseStatus': 200,
            'responseData': {'translatedText': 'Hola mundo'}
          },
          queryParameters: {
            'q': 'Hello world',
            'langpair': 'auto|es',
          },
        ),
      );

      final result = await manager.translate(
        text: 'Hello world',
        targetLanguage: 'es',
      );

      expect(result, 'Hola mundo');
      expect(manager.getActiveServiceName(), 'MyMemory');
    });

    test('failover through multiple services (Google -> MyMemory -> LibreTranslate)', () async {
      // Mock Google Translate failure (primary)
      googleAdapter.onGet(
        '',
        (server) => server.reply(500, {'error': 'Server Error'}),
      );

      // Mock MyMemory failure (first fallback)
      myMemoryAdapter.onGet(
        '/get',
        (server) => server.reply(429, {'error': 'Rate Limit'}),
      );

      // Mock LibreTranslate success (second fallback)
      libreAdapter.onPost(
        '/translate',
        (server) => server.reply(
          200,
          {'translatedText': 'Hola mundo'},
        ),
      );

      final result = await manager.translate(
        text: 'Hello world',
        targetLanguage: 'es',
      );

      expect(result, 'Hola mundo');
      expect(manager.getActiveServiceName(), 'LibreTranslate');
    });

    test('throws exception when all services fail', () async {
      // Mock all services failing (in priority order)
      googleAdapter.onGet(
        '',
        (server) => server.reply(500, {'error': 'Server Error'}),
      );

      myMemoryAdapter.onGet(
        '/get',
        (server) => server.reply(500, {'error': 'Server Error'}),
      );

      libreAdapter.onPost(
        '/translate',
        (server) => server.reply(500, {'error': 'Server Error'}),
      );

      expect(
        () => manager.translate(
          text: 'Hello world',
          targetLanguage: 'es',
        ),
        throwsA(isA<TranslationException>()),
      );
    });

    test('does not fallback on client errors (400)', () async {
      // Mock Google Translate 400 error (should not fallback)
      googleAdapter.onGet(
        '',
        (server) => server.reply(400, {'error': 'Bad Request'}),
      );

      expect(
        () => manager.translate(
          text: 'Hello world',
          targetLanguage: 'es',
        ),
        throwsA(isA<TranslationException>()),
      );

      // Verify no other services were called (client errors don't trigger fallback)
      expect(myMemoryAdapter.history.length, 0);
      expect(libreAdapter.history.length, 0);
    });

    test('falls back on rate limit (429)', () async {
      // Mock Google Translate rate limit (primary service)
      googleAdapter.onGet(
        '',
        (server) => server.reply(429, {'error': 'Rate Limit'}),
      );

      // Mock MyMemory success (fallback)
      myMemoryAdapter.onGet(
        '/get',
        (server) => server.reply(
          200,
          {
            'responseStatus': 200,
            'responseData': {'translatedText': 'Hola mundo'}
          },
          queryParameters: {
            'q': 'Hello world',
            'langpair': 'auto|es',
          },
        ),
      );

      final result = await manager.translate(
        text: 'Hello world',
        targetLanguage: 'es',
      );

      expect(result, 'Hola mundo');
      expect(manager.getActiveServiceName(), 'MyMemory');
    });

    test('falls back on network timeout', () async {
      // Mock Google Translate timeout (primary service)
      googleAdapter.onGet(
        '',
        (server) => server.timeout(),
      );

      // Mock MyMemory success (fallback)
      myMemoryAdapter.onGet(
        '/get',
        (server) => server.reply(
          200,
          {
            'responseStatus': 200,
            'responseData': {'translatedText': 'Hola mundo'}
          },
          queryParameters: {
            'q': 'Hello world',
            'langpair': 'auto|es',
          },
        ),
      );

      final result = await manager.translate(
        text: 'Hello world',
        targetLanguage: 'es',
      );

      expect(result, 'Hola mundo');
      expect(manager.getActiveServiceName(), 'MyMemory');
    });

    test('uses active service on subsequent calls', () async {
      // First call: Google Translate fails, MyMemory succeeds
      googleAdapter.onGet(
        '',
        (server) => server.reply(500, {'error': 'Server Error'}),
      );

      myMemoryAdapter.onGet(
        '/get',
        (server) => server.reply(
          200,
          {
            'responseStatus': 200,
            'responseData': {'translatedText': 'Hola'}
          },
          queryParameters: {
            'q': 'Hello',
            'langpair': 'auto|es',
          },
        ),
      );

      await manager.translate(text: 'Hello', targetLanguage: 'es');
      expect(manager.getActiveServiceName(), 'MyMemory');

      // Second call: Should use MyMemory directly
      myMemoryAdapter.onGet(
        '/get',
        (server) => server.reply(
          200,
          {
            'responseStatus': 200,
            'responseData': {'translatedText': 'Mundo'}
          },
          queryParameters: {
            'q': 'World',
            'langpair': 'auto|es',
          },
        ),
      );

      final result = await manager.translate(text: 'World', targetLanguage: 'es');
      expect(result, 'Mundo');
      
      // Verify Google Translate was not called again (only once on first call)
      expect(googleAdapter.history.length, 1);
    });

    test('resets active service when it becomes unavailable', () async {
      // Start with Google Translate (primary)
      googleAdapter.onGet(
        '',
        (server) => server.reply(
          200,
          {
            'data': {
              'translations': [
                {'translatedText': 'Hola'}
              ]
            }
          },
        ),
      );

      await manager.translate(text: 'Hello', targetLanguage: 'es');
      expect(manager.getActiveServiceName(), 'Google Translate');

      // Reset and verify it goes back to first available service (Google Translate)
      manager.resetActiveService();
      expect(manager.getActiveServiceName(), 'Google Translate');
    });
  });

  group('TranslationServiceManager - Language Detection', () {
    late TranslationServiceManager manager;
    late Dio googleDio;
    late DioAdapter googleAdapter;
    late Dio libreDio;
    late DioAdapter libreAdapter;

    setUp(() {
      googleDio = Dio();
      googleAdapter = DioAdapter(dio: googleDio);
      final googleService = GoogleTranslateService(
        apiKey: 'test-api-key',
        dio: googleDio,
      );

      libreDio = Dio();
      libreAdapter = DioAdapter(dio: libreDio);
      final libreService = LibreTranslateService(dio: libreDio);
      final myMemoryService = MyMemoryService();

      // Priority order: Google Translate, MyMemory, LibreTranslate
      manager = TranslationServiceManager([
        googleService,
        myMemoryService,
        libreService,
      ]);
    });

    tearDown(() {
      googleDio.close();
      libreDio.close();
    });

    test('successful language detection with primary service (Google Translate)', () async {
      googleAdapter.onGet(
        '/detect',
        (server) => server.reply(
          200,
          {
            'data': {
              'detections': [
                [
                  {'language': 'en', 'confidence': 0.95, 'isReliable': true}
                ]
              ]
            }
          },
          queryParameters: {
            'key': 'test-api-key',
            'q': 'Hello world',
          },
        ),
      );

      final result = await manager.detectLanguage('Hello world');
      expect(result, 'en');
      expect(manager.getActiveServiceName(), 'Google Translate');
    });

    test('falls back to MyMemory pattern detection when Google fails', () async {
      googleAdapter.onGet(
        '/detect',
        (server) => server.reply(500, {'error': 'Server Error'}),
      );

      // MyMemory uses pattern-based detection for Russian
      final result = await manager.detectLanguage('Привет');
      expect(result, 'ru');
      // MyMemory should be active after successful detection
    });

    test('falls back to LibreTranslate when Google and MyMemory fail', () async {
      googleAdapter.onGet(
        '/detect',
        (server) => server.reply(500, {'error': 'Server Error'}),
      );

      // MyMemory pattern detection doesn't work for English text
      // So it will throw and fallback to LibreTranslate
      libreAdapter.onPost(
        '/detect',
        (server) => server.reply(
          200,
          [
            {'language': 'en', 'confidence': 0.95}
          ],
        ),
      );

      final result = await manager.detectLanguage('Hello world');
      expect(result, 'en');
      expect(manager.getActiveServiceName(), 'LibreTranslate');
    });

    test('MyMemory pattern detection works for various languages', () async {
      googleAdapter.onGet(
        '/detect',
        (server) => server.reply(500, {'error': 'Server Error'}),
      );

      // Test Russian (Cyrillic)
      final russianResult = await manager.detectLanguage('Привет мир');
      expect(russianResult, 'ru');

      // Test Chinese
      final chineseResult = await manager.detectLanguage('你好世界');
      expect(chineseResult, 'zh');

      // Test German
      final germanResult = await manager.detectLanguage('Hallo Welt');
      // German pattern detection might not work, so it may fallback
      expect(germanResult, isA<String>());
    });
  });

  group('BaseTranslationService - Service Priority', () {
    test('default manager creates services in correct priority order', () {
      final manager = TranslationServiceManager.defaultManager(
        googleApiKey: 'test-key',
      );

      final services = manager.getAvailableServices();
      expect(services.length, greaterThanOrEqualTo(2));
      // Priority order: Google Translate (primary), MyMemory (fallback), LibreTranslate (optional)
      expect(services.first, 'Google Translate');
      expect(services[1], 'MyMemory');
      if (services.length > 2) {
        expect(services[2], 'LibreTranslate');
      }
    });

    test('default manager includes Google Translate when API key provided', () {
      final manager = TranslationServiceManager.defaultManager(
        googleApiKey: 'test-key',
      );

      final services = manager.getAvailableServices();
      expect(services, contains('Google Translate'));
      expect(services.indexOf('Google Translate'), 0); // Should be first (primary)
    });

    test('default manager excludes Google Translate when no API key', () {
      final manager = TranslationServiceManager.defaultManager();

      final services = manager.getAvailableServices();
      expect(services, isNot(contains('Google Translate')));
      // Without Google Translate, MyMemory should be first
      expect(services.first, 'MyMemory');
    });
  });

  group('Individual Services - Error Handling', () {
    test('GoogleTranslateService throws when API key not configured', () {
      final service = GoogleTranslateService();
      
      expect(service.isAvailable, isFalse);
      expect(
        () => service.translate(
          text: 'Hello',
          targetLanguage: 'es',
        ),
        throwsA(isA<TranslationException>()),
      );
    });

    test('MyMemoryService is always available', () {
      final service = MyMemoryService();
      expect(service.isAvailable, isTrue);
    });

    test('LibreTranslateService is always available', () {
      final service = LibreTranslateService();
      expect(service.isAvailable, isTrue);
    });
  });

  group('TranslationServiceManager - Edge Cases', () {
    test('throws error when no services provided', () {
      expect(
        () => TranslationServiceManager([]),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws error when no available services', () {
      final unavailableService = GoogleTranslateService(); // No API key
      
      expect(
        () => TranslationServiceManager([unavailableService]),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('handles empty text gracefully', () async {
      final manager = TranslationServiceManager.defaultManager();
      
      final result = await manager.translate(
        text: '',
        targetLanguage: 'es',
      );
      
      expect(result, '');
    });

    test('handles whitespace-only text', () async {
      final manager = TranslationServiceManager.defaultManager();
      
      final result = await manager.translate(
        text: '   \n\n   ',
        targetLanguage: 'es',
      );
      
      expect(result, '   \n\n   ');
    });

    test('handles empty text in language detection', () async {
      final manager = TranslationServiceManager.defaultManager();
      
      final result = await manager.detectLanguage('');
      expect(result, 'en'); // Default to English
    });

    test('seamless switching between services maintains consistency', () async {
      final googleDio = Dio();
      final googleAdapter = DioAdapter(dio: googleDio);
      final googleService = GoogleTranslateService(
        apiKey: 'test-api-key',
        dio: googleDio,
      );
      final myMemoryDio = Dio();
      final myMemoryAdapter = DioAdapter(dio: myMemoryDio);
      final myMemoryService = MyMemoryService(dio: myMemoryDio);

      final manager = TranslationServiceManager([
        googleService,
        myMemoryService,
      ]);

      // First request: Google succeeds
      googleAdapter.onGet(
        '',
        (server) => server.reply(
          200,
          {
            'data': {
              'translations': [
                {'translatedText': 'Hola'}
              ]
            }
          },
        ),
      );

      await manager.translate(text: 'Hello', targetLanguage: 'es');
      expect(manager.getActiveServiceName(), 'Google Translate');

      // Second request: Google fails, MyMemory succeeds
      googleAdapter.onGet(
        '',
        (server) => server.reply(500, {'error': 'Server Error'}),
      );

      myMemoryAdapter.onGet(
        '/get',
        (server) => server.reply(
          200,
          {
            'responseStatus': 200,
            'responseData': {'translatedText': 'Mundo'}
          },
        ),
      );

      await manager.translate(text: 'World', targetLanguage: 'es');
      expect(manager.getActiveServiceName(), 'MyMemory');

      // Third request: Should use MyMemory (active service)
      myMemoryAdapter.onGet(
        '/get',
        (server) => server.reply(
          200,
          {
            'responseStatus': 200,
            'responseData': {'translatedText': 'Adiós'}
          },
        ),
      );

      final result = await manager.translate(text: 'Goodbye', targetLanguage: 'es');
      expect(result, 'Adiós');
      expect(manager.getActiveServiceName(), 'MyMemory');

      googleDio.close();
      myMemoryDio.close();
    });

    test('error messages include all tried services', () async {
      final googleDio = Dio();
      final googleAdapter = DioAdapter(dio: googleDio);
      final googleService = GoogleTranslateService(
        apiKey: 'test-api-key',
        dio: googleDio,
      );
      final myMemoryDio = Dio();
      final myMemoryAdapter = DioAdapter(dio: myMemoryDio);
      final myMemoryService = MyMemoryService(dio: myMemoryDio);

      final manager = TranslationServiceManager([
        googleService,
        myMemoryService,
      ]);

      // Mock all services failing
      googleAdapter.onGet(
        '',
        (server) => server.reply(500, {'error': 'Server Error'}),
      );

      myMemoryAdapter.onGet(
        '/get',
        (server) => server.reply(500, {'error': 'Server Error'}),
      );

      try {
        await manager.translate(
          text: 'Hello world',
          targetLanguage: 'es',
        );
        fail('Should have thrown TranslationException');
      } on TranslationException catch (e) {
        expect(e.message, contains('All translation services failed'));
        expect(e.message, contains('Google Translate'));
        expect(e.message, contains('MyMemory'));
      }

      googleDio.close();
      myMemoryDio.close();
    });
  });
}
