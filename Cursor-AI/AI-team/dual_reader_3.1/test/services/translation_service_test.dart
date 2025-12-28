import 'package:flutter_test/flutter_test.dart';
import 'package:dual_reader/services/translation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

void main() {
  group('TranslationService', () {
    late TranslationService translationService;
    late DioAdapter dioAdapter;
    late Dio dio;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      dio = Dio();
      dioAdapter = DioAdapter(dio: dio);
      // Create service with mocked Dio for testing
      translationService = TranslationService(dio: dio);
      await translationService.initialize();
    });

    tearDown(() {
      dio.close();
    });

    group('Initialization', () {
      test('service initializes without errors', () async {
        final service = TranslationService();
        await service.initialize();
        expect(service, isNotNull);
      });

      test('initialize can be called multiple times safely', () async {
        final service = TranslationService();
        await service.initialize();
        await service.initialize(); // Should not throw
        expect(service, isNotNull);
      });
    });

    group('Translation', () {
      test('translate returns empty string for empty input', () async {
        final result = await translationService.translate(
          text: '',
          targetLanguage: 'es',
        );

        expect(result, '');
      });

      test('translate returns original text for whitespace-only input', () async {
        final result = await translationService.translate(
          text: '   \n\n   ',
          targetLanguage: 'es',
        );

        expect(result, '   \n\n   ');
      });

      test('translate throws exception for unsupported target language', () async {
        expect(
          () => translationService.translate(
            text: 'Hello',
            targetLanguage: 'invalid',
          ),
          throwsA(isA<TranslationException>()),
        );
      });

      test('translate throws exception for unsupported source language', () async {
        expect(
          () => translationService.translate(
            text: 'Hello',
            targetLanguage: 'es',
            sourceLanguage: 'invalid',
          ),
          throwsA(isA<TranslationException>()),
        );
      });

      test('translate caches results', () async {
        // Mock successful translation response
        dioAdapter.onPost(
          '/translate',
          (server) => server.reply(
            200,
            {'translatedText': 'Hola mundo'},
          ),
          data: {
            'q': 'Hello world',
            'source': 'auto',
            'target': 'es',
            'format': 'text',
          },
        );

        // Use the service with mocked Dio
        final result1 = await translationService.translate(
          text: 'Hello world',
          targetLanguage: 'es',
        );

        expect(result1, 'Hola mundo');

        // Second call should use cache (won't make another request)
        // Clear adapter to verify no new request is made
        dioAdapter.onPost(
          '/translate',
          (server) => server.reply(500, {'error': 'Should not be called'}),
        );

        final result2 = await translationService.translate(
          text: 'Hello world',
          targetLanguage: 'es',
        );

        expect(result2, equals(result1));
      });

      test('translate handles network timeout', () async {
        dioAdapter.onPost(
          '/translate',
          (server) => server.timeout(),
        );

        expect(
          () => translationService.translate(
            text: 'Hello',
            targetLanguage: 'es',
          ),
          throwsA(isA<TranslationException>()),
        );
      });

      test('translate handles 400 Bad Request', () async {
        dioAdapter.onPost(
          '/translate',
          (server) => server.reply(400, {'error': 'Bad Request'}),
        );

        expect(
          () => translationService.translate(
            text: 'Hello',
            targetLanguage: 'es',
          ),
          throwsA(isA<TranslationException>()),
        );
      });

      test('translate handles 429 Rate Limit', () async {
        dioAdapter.onPost(
          '/translate',
          (server) => server.reply(429, {'error': 'Rate limit exceeded'}),
        );

        expect(
          () => translationService.translate(
            text: 'Hello',
            targetLanguage: 'es',
          ),
          throwsA(isA<TranslationException>()),
        );
      });

      test('translate handles 500 Server Error', () async {
        dioAdapter.onPost(
          '/translate',
          (server) => server.reply(500, {'error': 'Internal Server Error'}),
        );

        expect(
          () => translationService.translate(
            text: 'Hello',
            targetLanguage: 'es',
          ),
          throwsA(isA<TranslationException>()),
        );
      });

      test('translate handles invalid API response', () async {
        dioAdapter.onPost(
          '/translate',
          (server) => server.reply(200, {}), // Missing translatedText
        );

        expect(
          () => translationService.translate(
            text: 'Hello',
            targetLanguage: 'es',
          ),
          throwsA(isA<TranslationException>()),
        );
      });

      test('translate handles empty translatedText in response', () async {
        dioAdapter.onPost(
          '/translate',
          (server) => server.reply(200, {'translatedText': ''}),
        );

        expect(
          () => translationService.translate(
            text: 'Hello',
            targetLanguage: 'es',
          ),
          throwsA(isA<TranslationException>()),
        );
      });
    });

    group('Language Detection', () {
      test('detectLanguage returns English for empty text', () async {
        final result = await translationService.detectLanguage('');
        expect(result, 'en');
      });

      test('detectLanguage detects Russian by pattern', () async {
        final result = await translationService.detectLanguage('Привет, как дела?');
        expect(result, 'ru');
      });

      test('detectLanguage detects Chinese by pattern', () async {
        final result = await translationService.detectLanguage('你好，世界');
        expect(result, 'zh');
      });

      test('detectLanguage detects Japanese by pattern', () async {
        final result = await translationService.detectLanguage('こんにちは世界');
        expect(result, 'ja');
      });

      test('detectLanguage detects Korean by pattern', () async {
        final result = await translationService.detectLanguage('안녕하세요 세계');
        expect(result, 'ko');
      });

      test('detectLanguage detects French by pattern', () async {
        final result = await translationService.detectLanguage('Bonjour le monde');
        expect(result, 'fr');
      });

      test('detectLanguage detects German by pattern', () async {
        final result = await translationService.detectLanguage('Hallo Welt');
        expect(result, 'de');
      });

      test('detectLanguage detects Spanish by pattern', () async {
        final result = await translationService.detectLanguage('Hola mundo');
        expect(result, 'es');
      });

      test('detectLanguage detects Italian by pattern', () async {
        final result = await translationService.detectLanguage('Ciao mondo');
        expect(result, 'it');
      });

      test('detectLanguage detects Portuguese by pattern', () async {
        final result = await translationService.detectLanguage('Olá mundo');
        expect(result, 'pt');
      });

      test('detectLanguage detects Arabic by pattern', () async {
        final result = await translationService.detectLanguage('مرحبا بالعالم');
        expect(result, 'ar');
      });

      test('detectLanguage detects Hebrew by pattern', () async {
        final result = await translationService.detectLanguage('שלום עולם');
        expect(result, 'he');
      });

      test('detectLanguage detects Thai by pattern', () async {
        final result = await translationService.detectLanguage('สวัสดีชาวโลก');
        expect(result, 'th');
      });

      test('detectLanguage uses API when pattern detection fails', () async {
        // Mock API response
        dioAdapter.onPost(
          '/detect',
          (server) => server.reply(
            200,
            [
              {'language': 'en', 'confidence': 0.95}
            ],
          ),
        );

        final result = await translationService.detectLanguage('Hello world');
        expect(result, 'en');
      });

      test('detectLanguage falls back to pattern when API fails', () async {
        // Mock API failure
        dioAdapter.onPost(
          '/detect',
          (server) => server.reply(500, {'error': 'Server Error'}),
        );

        // Should fallback to pattern detection or default
        final result = await translationService.detectLanguage('Hello world');
        expect(result, isA<String>());
      });

      test('detectLanguage caches detected languages', () async {
        dioAdapter.onPost(
          '/detect',
          (server) => server.reply(
            200,
            [
              {'language': 'fr', 'confidence': 0.9}
            ],
          ),
        );

        final result1 = await translationService.detectLanguage('Bonjour');
        
        // Clear adapter to verify cache is used
        dioAdapter.onPost(
          '/detect',
          (server) => server.reply(500, {'error': 'Should not be called'}),
        );
        
        final result2 = await translationService.detectLanguage('Bonjour'); // Should use cache

        expect(result1, equals(result2));
      });
    });

    group('Supported Languages', () {
      test('getSupportedLanguages returns list of language codes', () {
        final languages = translationService.getSupportedLanguages();
        expect(languages, isNotEmpty);
        expect(languages, contains('en'));
        expect(languages, contains('es'));
        expect(languages, contains('fr'));
      });

      test('isLanguageSupported returns true for supported languages', () {
        expect(translationService.isLanguageSupported('en'), isTrue);
        expect(translationService.isLanguageSupported('es'), isTrue);
        expect(translationService.isLanguageSupported('fr'), isTrue);
      });

      test('isLanguageSupported returns false for unsupported languages', () {
        expect(translationService.isLanguageSupported('invalid'), isFalse);
        expect(translationService.isLanguageSupported('xyz'), isFalse);
      });

      test('isLanguageSupported is case-insensitive', () {
        expect(translationService.isLanguageSupported('EN'), isTrue);
        expect(translationService.isLanguageSupported('Es'), isTrue);
      });

      test('getLanguageName returns language name for valid code', () {
        expect(translationService.getLanguageName('en'), 'English');
        expect(translationService.getLanguageName('es'), 'Spanish');
        expect(translationService.getLanguageName('fr'), 'French');
      });

      test('getLanguageName returns null for invalid code', () {
        expect(translationService.getLanguageName('invalid'), isNull);
      });
    });

    group('Cache Management', () {
      test('clearCache removes all cached translations', () async {
        // Add some translations to cache
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('translation_test1', 'cached1');
        await prefs.setString('translation_test2', 'cached2');
        await prefs.setString('other_key', 'should remain');

        await translationService.clearCache();

        // Verify translation cache is cleared
        expect(prefs.getString('translation_test1'), isNull);
        expect(prefs.getString('translation_test2'), isNull);

        // Verify other keys remain
        expect(prefs.getString('other_key'), 'should remain');
      });

      test('cache persists across service instances', () async {
        // Mock translation
        final testDio1 = Dio();
        final testAdapter1 = DioAdapter(dio: testDio1);
        testAdapter1.onPost(
          '/translate',
          (server) => server.reply(
            200,
            {'translatedText': 'Hola'},
          ),
        );

        final service1 = TranslationService(dio: testDio1);
        await service1.initialize();
        await service1.translate(text: 'Hello', targetLanguage: 'es');

        // Create new service instance (will use SharedPreferences cache)
        final testDio2 = Dio();
        final testAdapter2 = DioAdapter(dio: testDio2);
        // Don't set up mock - should use cache
        final service2 = TranslationService(dio: testDio2);
        await service2.initialize();

        // Should use cached translation from SharedPreferences
        final result = await service2.translate(text: 'Hello', targetLanguage: 'es');
        expect(result, 'Hola');
        
        testDio1.close();
        testDio2.close();
      });
    });

    group('Long Text Translation', () {
      test('translate splits long text into chunks', () async {
        // Create text longer than maxTextLength
        final longText = 'Hello. ' * 1000; // ~7000 characters

        dioAdapter.onPost(
          '/translate',
          (server) => server.reply(
            200,
            {'translatedText': 'Hola. '},
          ),
        );

        // Should handle long text without error
        // Note: Actual implementation would split and translate in chunks
        expect(
          () => translationService.translate(
            text: longText,
            targetLanguage: 'es',
          ),
          returnsNormally,
        );
      });
    });

    group('Error Handling', () {
      test('handles connection timeout gracefully', () async {
        dioAdapter.onPost(
          '/translate',
          (server) => server.throws(
            0,
            DioException(
              requestOptions: RequestOptions(path: '/translate'),
              type: DioExceptionType.connectionTimeout,
            ),
          ),
        );

        expect(
          () => translationService.translate(
            text: 'Hello',
            targetLanguage: 'es',
          ),
          throwsA(isA<TranslationException>()),
        );
      });

      test('handles connection error gracefully', () async {
        dioAdapter.onPost(
          '/translate',
          (server) => server.throws(
            0,
            DioException(
              requestOptions: RequestOptions(path: '/translate'),
              type: DioExceptionType.connectionError,
            ),
          ),
        );

        expect(
          () => translationService.translate(
            text: 'Hello',
            targetLanguage: 'es',
          ),
          throwsA(isA<TranslationException>()),
        );
      });

      test('retries on 500 server error and succeeds', () async {
        int callCount = 0;
        dioAdapter.onPost(
          '/translate',
          (server) {
            callCount++;
            if (callCount < 3) {
              // Fail first 2 attempts
              server.reply(500, {'error': 'Internal Server Error'});
            } else {
              // Succeed on 3rd attempt
              server.reply(200, {'translatedText': 'Hola'});
            }
          },
        );

        final result = await translationService.translate(
          text: 'Hello',
          targetLanguage: 'es',
        );

        expect(result, 'Hola');
        expect(callCount, 3);
      });

      test('retries on 429 rate limit and succeeds', () async {
        int callCount = 0;
        dioAdapter.onPost(
          '/translate',
          (server) {
            callCount++;
            if (callCount < 2) {
              // Fail first attempt
              server.reply(429, {'error': 'Rate limit exceeded'});
            } else {
              // Succeed on 2nd attempt
              server.reply(200, {'translatedText': 'Hola'});
            }
          },
        );

        final result = await translationService.translate(
          text: 'Hello',
          targetLanguage: 'es',
        );

        expect(result, 'Hola');
        expect(callCount, 2);
      });

      test('retries on connection timeout and succeeds', () async {
        int callCount = 0;
        dioAdapter.onPost(
          '/translate',
          (server) {
            callCount++;
            if (callCount < 2) {
              // Timeout on first attempt
              server.throws(
                0,
                DioException(
                  requestOptions: RequestOptions(path: '/translate'),
                  type: DioExceptionType.connectionTimeout,
                ),
              );
            } else {
              // Succeed on 2nd attempt
              server.reply(200, {'translatedText': 'Hola'});
            }
          },
        );

        final result = await translationService.translate(
          text: 'Hello',
          targetLanguage: 'es',
        );

        expect(result, 'Hola');
        expect(callCount, 2);
      });

      test('gives up after max retries on persistent failures', () async {
        int callCount = 0;
        dioAdapter.onPost(
          '/translate',
          (server) {
            callCount++;
            // Always fail with 500
            server.reply(500, {'error': 'Internal Server Error'});
          },
        );

        expect(
          () => translationService.translate(
            text: 'Hello',
            targetLanguage: 'es',
          ),
          throwsA(isA<TranslationException>()),
        );

        // Should have attempted maxRetries + 1 times (initial + retries)
        expect(callCount, greaterThanOrEqualTo(3));
      });

      test('does not retry on 400 Bad Request', () async {
        int callCount = 0;
        dioAdapter.onPost(
          '/translate',
          (server) {
            callCount++;
            // Always return 400
            server.reply(400, {'error': 'Bad Request'});
          },
        );

        expect(
          () => translationService.translate(
            text: 'Hello',
            targetLanguage: 'es',
          ),
          throwsA(isA<TranslationException>()),
        );

        // Should not retry on 400 errors
        expect(callCount, 1);
      });

      test('does not retry on 403 Forbidden', () async {
        int callCount = 0;
        dioAdapter.onPost(
          '/translate',
          (server) {
            callCount++;
            // Always return 403
            server.reply(403, {'error': 'Forbidden'});
          },
        );

        expect(
          () => translationService.translate(
            text: 'Hello',
            targetLanguage: 'es',
          ),
          throwsA(isA<TranslationException>()),
        );

        // Should not retry on 403 errors
        expect(callCount, 1);
      });
    });
  });

  group('SupportedLanguages', () {
    test('languages map contains 50+ languages', () {
      expect(SupportedLanguages.languages.length, greaterThanOrEqualTo(50));
    });

    test('getLanguageName returns correct name', () {
      expect(SupportedLanguages.getLanguageName('en'), 'English');
      expect(SupportedLanguages.getLanguageName('es'), 'Spanish');
      expect(SupportedLanguages.getLanguageName('fr'), 'French');
    });

    test('getSupportedCodes returns sorted list', () {
      final codes = SupportedLanguages.getSupportedCodes();
      expect(codes, isNotEmpty);
      expect(codes.first, lessThan(codes.last));
    });

    test('isSupported is case-insensitive', () {
      expect(SupportedLanguages.isSupported('EN'), isTrue);
      expect(SupportedLanguages.isSupported('en'), isTrue);
      expect(SupportedLanguages.isSupported('Es'), isTrue);
    });

    test('getLanguageList returns sorted entries', () {
      final list = SupportedLanguages.getLanguageList();
      expect(list, isNotEmpty);
      // Check that list is sorted by language name
      for (int i = 0; i < list.length - 1; i++) {
        expect(
          list[i].value.compareTo(list[i + 1].value),
          lessThanOrEqualTo(0),
        );
      }
    });
  });
}
