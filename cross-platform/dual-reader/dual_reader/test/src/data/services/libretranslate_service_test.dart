import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:http/http.dart' as http;
import 'package:dual_reader/src/data/services/libretranslate_service_impl.dart';
import 'package:dual_reader/src/data/services/translation_cache_service.dart';

@GenerateMocks([http.Client, TranslationCacheService])
import 'libretranslate_service_test.mocks.dart';

void main() {
  group('LibreTranslateServiceImpl', () {
    late LibreTranslateServiceImpl service;
    late MockClient mockHttpClient;
    late MockTranslationCacheService mockCacheService;

    setUp(() {
      mockHttpClient = MockClient();
      mockCacheService = MockTranslationCacheService();
      service = LibreTranslateServiceImpl(mockCacheService, mockHttpClient);
    });

    group('translate - cache hit', () {
      test('should return cached translation if available', () async {
        const originalText = 'Hello';
        const targetLanguage = 'es';
        const cachedTranslation = 'Hola';

        when(mockCacheService.getCachedTranslation(originalText, targetLanguage))
            .thenReturn(cachedTranslation);

        final result = await service.translate(
          text: originalText,
          targetLanguage: targetLanguage,
        );

        expect(result, cachedTranslation);
        verify(mockCacheService.getCachedTranslation(originalText, targetLanguage)).called(1);
        verifyNever(mockHttpClient.post(any, headers: anyNamed('headers'), body: anyNamed('body')));
        verifyNever(mockCacheService.cacheTranslation(any, any, any));
      });
    });

    group('translate - cache miss, successful API call', () {
      test('should translate text and cache the result when cache miss', () async {
        const originalText = 'Hello';
        const targetLanguage = 'es';
        const translatedText = 'Hola';
        const detectedLanguage = 'en';

        when(mockCacheService.getCachedTranslation(originalText, targetLanguage))
            .thenReturn(null);

        // Mock detectLanguage response (called when no sourceLanguage provided)
        when(mockHttpClient.post(
          argThat(contains('/detect')),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => http.Response(
          '[{"confidence": 0.99, "language": "$detectedLanguage"}]',
          200,
        ));

        // Mock translate response
        when(mockHttpClient.post(
          argThat(contains('/translate')),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => http.Response(
          '{"translatedText": "$translatedText"}',
          200,
        ));

        final result = await service.translate(
          text: originalText,
          targetLanguage: targetLanguage,
        );

        expect(result, translatedText);
        verify(mockCacheService.getCachedTranslation(originalText, targetLanguage)).called(1);
        verify(mockCacheService.cacheTranslation(originalText, targetLanguage, translatedText)).called(1);
      });

      test('should use provided source language when given', () async {
        const originalText = 'Hello';
        const sourceLanguage = 'en';
        const targetLanguage = 'es';
        const translatedText = 'Hola';

        when(mockCacheService.getCachedTranslation(originalText, targetLanguage))
            .thenReturn(null);

        when(mockHttpClient.post(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => http.Response(
          '{"translatedText": "$translatedText"}',
          200,
        ));

        await service.translate(
          text: originalText,
          targetLanguage: targetLanguage,
          sourceLanguage: sourceLanguage,
        );

        final captured = verify(mockHttpClient.post(
          any,
          headers: anyNamed('headers'),
          body: captureAnyNamed('body'),
        )).captured.single as String;

        expect(captured, contains('"source":"$sourceLanguage"'));
        verifyNever(mockHttpClient.post(
          argThat(endsWith('/detect')),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ));
      });

      test('should call detectLanguage when source language not provided (non-web)', () async {
        const originalText = 'Hello';
        const targetLanguage = 'es';
        const detectedLanguage = 'en';
        const translatedText = 'Hola';

        when(mockCacheService.getCachedTranslation(originalText, targetLanguage))
            .thenReturn(null);

        // Mock detectLanguage response
        when(mockHttpClient.post(
          argThat(contains('/detect')),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => http.Response(
          '[{"confidence": 0.99, "language": "$detectedLanguage"}]',
          200,
        ));

        // Mock translate response
        when(mockHttpClient.post(
          argThat(contains('/translate')),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => http.Response(
          '{"translatedText": "$translatedText"}',
          200,
        ));

        final result = await service.translate(
          text: originalText,
          targetLanguage: targetLanguage,
        );

        expect(result, translatedText);
        // Verify that both detect and translate were called
        verify(mockHttpClient.post(
          argThat(contains('/detect')),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).called(1);
        verify(mockHttpClient.post(
          argThat(contains('/translate')),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).called(1);
      });
    });

    group('translate - error handling', () {
      test('should throw exception when API returns non-200 status', () async {
        const originalText = 'Hello';
        const targetLanguage = 'es';

        when(mockCacheService.getCachedTranslation(originalText, targetLanguage))
            .thenReturn(null);

        when(mockHttpClient.post(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => http.Response(
          'Bad Request',
          400,
        ));

        expect(
          () => service.translate(
            text: originalText,
            targetLanguage: targetLanguage,
          ),
          throwsA(isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Failed to translate text'),
          )),
        );

        verifyNever(mockCacheService.cacheTranslation(any, any, any));
      });

      test('should throw exception when API response is invalid JSON', () async {
        const originalText = 'Hello';
        const targetLanguage = 'es';

        when(mockCacheService.getCachedTranslation(originalText, targetLanguage))
            .thenReturn(null);

        when(mockHttpClient.post(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => http.Response(
          'Invalid JSON{{{',
          200,
        ));

        expect(
          () => service.translate(
            text: originalText,
            targetLanguage: targetLanguage,
          ),
          throwsA(isA<Exception>()),
        );

        verifyNever(mockCacheService.cacheTranslation(any, any, any));
      });

      test('should throw exception when API response missing translatedText', () async {
        const originalText = 'Hello';
        const targetLanguage = 'es';

        when(mockCacheService.getCachedTranslation(originalText, targetLanguage))
            .thenReturn(null);

        when(mockHttpClient.post(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => http.Response(
          '{"otherField": "value"}',
          200,
        ));

        expect(
          () => service.translate(
            text: originalText,
            targetLanguage: targetLanguage,
          ),
          throwsA(isA<Exception>()),
        );

        verifyNever(mockCacheService.cacheTranslation(any, any, any));
      });

      test('should propagate network errors', () async {
        const originalText = 'Hello';
        const targetLanguage = 'es';
        const sourceLanguage = 'en';

        when(mockCacheService.getCachedTranslation(originalText, targetLanguage))
            .thenReturn(null);

        when(mockHttpClient.post(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenThrow(Exception('Network error'));

        expect(
          () => service.translate(
            text: originalText,
            targetLanguage: targetLanguage,
            sourceLanguage: sourceLanguage,
          ),
          throwsException,
        );

        verifyNever(mockCacheService.cacheTranslation(any, any, any));
      });
    });

    group('detectLanguage', () {
      test('should return detected language from API', () async {
        const text = 'Hello world';
        const detectedLanguage = 'en';

        when(mockHttpClient.post(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => http.Response(
          '[{"confidence": 0.99, "language": "$detectedLanguage"}]',
          200,
        ));

        final result = await service.detectLanguage(text);

        expect(result, detectedLanguage);
        verify(mockHttpClient.post(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).called(1);
      });

      test('should throw exception when detect API returns non-200 status', () async {
        const text = 'Hello world';

        when(mockHttpClient.post(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => http.Response(
          'Unauthorized',
          401,
        ));

        expect(
          () => service.detectLanguage(text),
          throwsA(isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Failed to detect language'),
          )),
        );
      });

      test('should throw exception when detect response is empty', () async {
        const text = 'Hello world';

        when(mockHttpClient.post(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => http.Response(
          '[]',
          200,
        ));

        expect(
          () => service.detectLanguage(text),
          throwsA(isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Failed to detect language'),
          )),
        );
      });

      test('should throw exception when detect response missing language field', () async {
        const text = 'Hello world';

        when(mockHttpClient.post(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => http.Response(
          '[{"confidence": 0.99}]',
          200,
        ));

        expect(
          () => service.detectLanguage(text),
          throwsA(isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Failed to detect language'),
          )),
        );
      });

      test('should propagate network errors during detection', () async {
        const text = 'Hello world';

        when(mockHttpClient.post(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenThrow(Exception('Network error'));

        expect(
          () => service.detectLanguage(text),
          throwsException,
        );
      });
    });

    group('integration - cache and translate', () {
      test('should cache translation after successful API call and return on subsequent call', () async {
        const originalText = 'Hello';
        const targetLanguage = 'es';
        const translatedText = 'Hola';
        const detectedLanguage = 'en';

        // First call - cache miss
        when(mockCacheService.getCachedTranslation(originalText, targetLanguage))
            .thenReturn(null);

        // Mock detectLanguage response
        when(mockHttpClient.post(
          argThat(endsWith('/detect')),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => http.Response(
          '[{"confidence": 0.99, "language": "$detectedLanguage"}]',
          200,
        ));

        // Mock translate response
        when(mockHttpClient.post(
          argThat(endsWith('/translate')),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => http.Response(
          '{"translatedText": "$translatedText"}',
          200,
        ));

        final result1 = await service.translate(
          text: originalText,
          targetLanguage: targetLanguage,
        );

        expect(result1, translatedText);
        verify(mockCacheService.cacheTranslation(originalText, targetLanguage, translatedText)).called(1);

        // Second call - cache hit
        when(mockCacheService.getCachedTranslation(originalText, targetLanguage))
            .thenReturn(translatedText);

        final result2 = await service.translate(
          text: originalText,
          targetLanguage: targetLanguage,
        );

        expect(result2, translatedText);
        // API should not be called again
        verify(mockHttpClient.post(
          argThat(endsWith('/translate')),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).called(1); // Only called once from first translate
      });
    });
  });
}
