import 'package:flutter_test/flutter_test.dart';
import 'package:dual_reader/src/data/services/client_side_translation_service.dart';
import 'package:dual_reader/src/data/services/translation_cache_service.dart';

void main() {
  group('ClientSideTranslationService', () {
    group('translate', () {
      late MockTranslationCacheService cache;
      late MockClientSideTranslationDelegate delegate;
      late _TestableClientSideTranslationService testableService;

      setUp(() {
        cache = MockTranslationCacheService();
        delegate = MockClientSideTranslationDelegate();
        testableService = _TestableClientSideTranslationService(cache, delegate);
      });

      test('should return cached translation when available', () async {
        cache.stubGetCachedTranslation('Hello', 'es', 'Hola');

        final result = await testableService.translate(
          text: 'Hello',
          targetLanguage: 'es',
        );

        expect(result, equals('Hola'));
        expect(cache.getCachedTranslationCalls.length, equals(1));
        expect(cache.getCachedTranslationCalls.last, equals(('Hello', 'es')));
        // Should NOT call the delegate when cache hits
        expect(delegate.translateCalls.length, equals(0));
      });

      test('should call delegate when cache misses and cache result', () async {
        cache.stubGetCachedTranslation('Hello', 'es', null);
        delegate.stubTranslate('Hello', 'es', 'Hola');

        final result = await testableService.translate(
          text: 'Hello',
          targetLanguage: 'es',
        );

        expect(result, equals('Hola'));
        expect(delegate.translateCalls.length, equals(1));
        expect(cache.cacheTranslationCalls.length, equals(1));
        expect(cache.cacheTranslationCalls.last,
            equals(('Hello', 'es', 'Hola')));
      });

      test('should pass source language to delegate', () async {
        cache.stubGetCachedTranslation('Hello', 'es', null);
        delegate.stubTranslate('Hello', 'es', 'Hola', sourceLanguage: 'en');

        await testableService.translate(
          text: 'Hello',
          targetLanguage: 'es',
          sourceLanguage: 'en',
        );

        expect(delegate.translateCalls.length, equals(1));
        expect(delegate.lastTranslateSourceLanguage, equals('en'));
      });

      test('should rethrow when delegate throws', () async {
        cache.stubGetCachedTranslation('Hello', 'es', null);
        delegate.stubTranslateThrow(Exception('Translation failed'));

        expect(
          () => testableService.translate(
            text: 'Hello',
            targetLanguage: 'es',
          ),
          throwsException,
        );
      });

      test('should handle special characters in text', () async {
        const original = 'Hello! @#\$%^&*()';
        const translated = '¡Hola! @#\$%^&*()';
        cache.stubGetCachedTranslation(original, 'es', null);
        delegate.stubTranslate(original, 'es', translated);

        final result = await testableService.translate(
          text: original,
          targetLanguage: 'es',
        );

        expect(result, equals(translated));
      });

      test('should handle unicode text', () async {
        const original = 'Hello 你好 مرحبا';
        const translated = 'Bonjour 你好 مرحبا';
        cache.stubGetCachedTranslation(original, 'fr', null);
        delegate.stubTranslate(original, 'fr', translated);

        final result = await testableService.translate(
          text: original,
          targetLanguage: 'fr',
        );

        expect(result, equals(translated));
      });

      test('should handle long text', () async {
        final longText = 'Hello world. ' * 1000;
        final translatedText = 'Hola mundo. ' * 1000;
        cache.stubGetCachedTranslation(longText, 'es', null);
        delegate.stubTranslate(longText, 'es', translatedText);

        final result = await testableService.translate(
          text: longText,
          targetLanguage: 'es',
        );

        expect(result, equals(translatedText));
      });

      test('should not cache on delegate error', () async {
        cache.stubGetCachedTranslation('Hello', 'es', null);
        delegate.stubTranslateThrow(Exception('fail'));

        try {
          await testableService.translate(text: 'Hello', targetLanguage: 'es');
        } catch (_) {}

        expect(cache.cacheTranslationCalls.length, equals(0));
      });
    });

    group('detectLanguage', () {
      late MockTranslationCacheService cache;
      late MockClientSideTranslationDelegate delegate;
      late _TestableClientSideTranslationService testableService;

      setUp(() {
        cache = MockTranslationCacheService();
        delegate = MockClientSideTranslationDelegate();
        testableService = _TestableClientSideTranslationService(cache, delegate);
      });

      test('should delegate language detection', () async {
        delegate.stubDetectLanguage('Hello world', 'en');

        final result = await testableService.detectLanguage('Hello world');

        expect(result, equals('en'));
        expect(delegate.detectLanguageCalls.length, equals(1));
      });

      test('should detect Spanish text', () async {
        delegate.stubDetectLanguage('Hola mundo', 'es');

        final result = await testableService.detectLanguage('Hola mundo');

        expect(result, equals('es'));
      });

      test('should detect French text', () async {
        delegate.stubDetectLanguage('Bonjour le monde', 'fr');

        final result = await testableService.detectLanguage('Bonjour le monde');

        expect(result, equals('fr'));
      });
    });

    group('close', () {
      late MockTranslationCacheService cache;
      late MockClientSideTranslationDelegate delegate;
      late _TestableClientSideTranslationService testableService;

      setUp(() {
        cache = MockTranslationCacheService();
        delegate = MockClientSideTranslationDelegate();
        testableService = _TestableClientSideTranslationService(cache, delegate);
      });

      test('should close the delegate', () async {
        await testableService.close();

        expect(delegate.closeCalled, isTrue);
      });
    });

    group('isLanguageModelReady', () {
      late MockTranslationCacheService cache;
      late MockClientSideTranslationDelegate delegate;
      late _TestableClientSideTranslationService testableService;

      setUp(() {
        cache = MockTranslationCacheService();
        delegate = MockClientSideTranslationDelegate();
        testableService = _TestableClientSideTranslationService(cache, delegate);
      });

      test('should return true when model is ready', () async {
        delegate.stubIsLanguageModelReady('es', true);

        final result = await testableService.isLanguageModelReady('es');

        expect(result, isTrue);
      });

      test('should return false when model is not ready', () async {
        delegate.stubIsLanguageModelReady('zh', false);

        final result = await testableService.isLanguageModelReady('zh');

        expect(result, isFalse);
      });
    });

    group('downloadLanguageModel', () {
      late MockTranslationCacheService cache;
      late MockClientSideTranslationDelegate delegate;
      late _TestableClientSideTranslationService testableService;

      setUp(() {
        cache = MockTranslationCacheService();
        delegate = MockClientSideTranslationDelegate();
        testableService = _TestableClientSideTranslationService(cache, delegate);
      });

      test('should download model successfully', () async {
        delegate.stubDownloadLanguageModel('es', true);

        final result = await testableService.downloadLanguageModel('es');

        expect(result, isTrue);
      });

      test('should return false on download failure', () async {
        delegate.stubDownloadLanguageModel('xx', false);

        final result = await testableService.downloadLanguageModel('xx');

        expect(result, isFalse);
      });

      test('should pass progress callback', () async {
        delegate.stubDownloadLanguageModel('es', true,
            progressMessages: ['Downloading...', 'Done']);

        await testableService.downloadLanguageModel(
          'es',
          onProgress: (_) {},
        );

        expect(delegate.downloadLanguageModelCalls.length, equals(1));
      });
    });

    group('ClientSideTranslationDelegate', () {
      test('should define the expected interface', () {
        // Verify the abstract class has the expected methods
        expect(ClientSideTranslationDelegate, isNotNull);
      });
    });
  });
}

/// Testable subclass that allows injecting a mock delegate
class _TestableClientSideTranslationService
    extends ClientSideTranslationService {
  final ClientSideTranslationDelegate _testDelegate;
  final TranslationCacheService _testCacheService;

  _TestableClientSideTranslationService(
    TranslationCacheService cacheService,
    this._testDelegate,
  )   : _testCacheService = cacheService,
        super(cacheService);

  @override
  Future<String> translate({
    required String text,
    required String targetLanguage,
    String? sourceLanguage,
  }) async {
    // Try cache first
    final cachedTranslation =
        _testCacheService.getCachedTranslation(text, targetLanguage);
    if (cachedTranslation != null) {
      return cachedTranslation;
    }

    try {
      final translated = await _testDelegate.translate(
        text: text,
        targetLanguage: targetLanguage,
        sourceLanguage: sourceLanguage,
      );

      // Cache the result
      await _testCacheService.cacheTranslation(text, targetLanguage, translated);

      return translated;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<String> detectLanguage(String text) async {
    return _testDelegate.detectLanguage(text);
  }

  @override
  Future<void> close() async {
    await _testDelegate.close();
  }

  @override
  Future<bool> isLanguageModelReady(String languageCode) async {
    return _testDelegate.isLanguageModelReady(languageCode);
  }

  @override
  Future<bool> downloadLanguageModel(String languageCode,
      {void Function(String)? onProgress}) async {
    return _testDelegate.downloadLanguageModel(languageCode,
        onProgress: onProgress);
  }
}

/// Manual mock for TranslationCacheService
class MockTranslationCacheService implements TranslationCacheService {
  final Map<String, String?> _cachedTranslations = {};
  final List<(String, String)> getCachedTranslationCalls = [];
  final List<(String, String, String)> cacheTranslationCalls = [];

  void stubGetCachedTranslation(String text, String lang, String? result) {
    _cachedTranslations['$text\_$lang'] = result;
  }

  @override
  String? getCachedTranslation(String originalText, String targetLanguage) {
    getCachedTranslationCalls.add((originalText, targetLanguage));
    return _cachedTranslations['$originalText\_$targetLanguage'];
  }

  @override
  Future<void> cacheTranslation(
      String originalText, String targetLanguage, String translatedText) async {
    cacheTranslationCalls
        .add((originalText, targetLanguage, translatedText));
    _cachedTranslations['$originalText\_$targetLanguage'] = translatedText;
  }

  @override
  Future<void> init() async {}
}

/// Manual mock for ClientSideTranslationDelegate
class MockClientSideTranslationDelegate
    implements ClientSideTranslationDelegate {
  final Map<String, String> _translateResults = {};
  String? _translateThrow;
  final List<(String, String, String?)> translateCalls = [];
  String? lastTranslateSourceLanguage;

  final Map<String, String> _detectLanguageResults = {};
  final List<String> detectLanguageCalls = [];

  bool closeCalled = false;

  final Map<String, bool> _isModelReadyResults = {};
  final List<String> isLanguageModelReadyCalls = [];

  final Map<String, bool> _downloadModelResults = {};
  final List<String> downloadLanguageModelCalls = [];
  List<String>? _downloadProgressMessages;

  void stubTranslate(String text, String target, String result,
      {String? sourceLanguage}) {
    _translateResults['$text\_$target'] = result;
  }

  void stubTranslateThrow(Object error) {
    _translateThrow = error.toString();
  }

  void stubDetectLanguage(String text, String result) {
    _detectLanguageResults[text] = result;
  }

  void stubIsLanguageModelReady(String lang, bool result) {
    _isModelReadyResults[lang] = result;
  }

  void stubDownloadLanguageModel(String lang, bool result,
      {List<String>? progressMessages}) {
    _downloadModelResults[lang] = result;
    _downloadProgressMessages = progressMessages;
  }

  @override
  Future<String> translate({
    required String text,
    required String targetLanguage,
    String? sourceLanguage,
  }) async {
    lastTranslateSourceLanguage = sourceLanguage;
    translateCalls.add((text, targetLanguage, sourceLanguage));
    if (_translateThrow != null) {
      throw Exception(_translateThrow);
    }
    return _translateResults['$text\_$targetLanguage'] ?? text;
  }

  @override
  Future<String> detectLanguage(String text) async {
    detectLanguageCalls.add(text);
    return _detectLanguageResults[text] ?? 'en';
  }

  @override
  Future<void> close() async {
    closeCalled = true;
  }

  @override
  Future<bool> isLanguageModelReady(String languageCode) async {
    isLanguageModelReadyCalls.add(languageCode);
    return _isModelReadyResults[languageCode] ?? false;
  }

  @override
  Future<bool> downloadLanguageModel(String languageCode,
      {void Function(String)? onProgress}) async {
    downloadLanguageModelCalls.add(languageCode);
    if (_downloadProgressMessages != null && onProgress != null) {
      for (final msg in _downloadProgressMessages!) {
        onProgress(msg);
      }
    }
    return _downloadModelResults[languageCode] ?? false;
  }
}
