import 'dart:io' show Platform;
import 'package:flutter_test/flutter_test.dart';
import 'package:dual_reader/src/data/services/language_model_downloader.dart';
import 'package:dual_reader/src/domain/services/translation_service.dart';

/// Manual mock for TranslationService
class MockTranslationService implements TranslationService {
  final Map<String, String> _translateResults = {};
  final Map<String, String> _detectResults = {};
  final Map<String, bool> _modelReadyResults = {};
  final Map<String, bool> _downloadModelResults = {};

  final List<({String text, String target, String? source})> translateCalls = [];
  final List<String> detectLanguageCalls = [];
  final List<String> isModelReadyCalls = [];
  final List<String> downloadModelCalls = [];
  final List<String> downloadProgressMessages = [];

  void stubTranslate(String text, String target, String result) {
    _translateResults['${text}_$target'] = result;
  }

  void stubDetectLanguage(String text, String result) {
    _detectResults[text] = result;
  }

  void stubIsLanguageModelReady(String lang, bool ready) {
    _modelReadyResults[lang] = ready;
  }

  void stubDownloadLanguageModel(String lang, bool success) {
    _downloadModelResults[lang] = success;
  }

  @override
  Future<String> translate({
    required String text,
    required String targetLanguage,
    String? sourceLanguage,
  }) async {
    translateCalls.add((text: text, target: targetLanguage, source: sourceLanguage));
    return _translateResults['${text}_$targetLanguage'] ?? text;
  }

  @override
  Future<String> detectLanguage(String text) async {
    detectLanguageCalls.add(text);
    return _detectResults[text] ?? 'en';
  }

  @override
  Future<bool> isLanguageModelReady(String languageCode) async {
    isModelReadyCalls.add(languageCode);
    return _modelReadyResults[languageCode] ?? false;
  }

  @override
  Future<bool> downloadLanguageModel(String languageCode, {void Function(String)? onProgress}) async {
    downloadModelCalls.add(languageCode);
    final result = _downloadModelResults[languageCode] ?? false;
    if (onProgress != null) {
      onProgress('Downloading $languageCode...');
    }
    return result;
  }
}

void main() {
  group('LanguageModelDownloader', () {
    late MockTranslationService mockService;

    setUp(() {
      mockService = MockTranslationService();
    });

    // ----- downloadSpanishModelInBackground -----
    group('downloadSpanishModelInBackground', () {
      test(
        'returns early on non-mobile platform without error',
        () async {
          final downloader = LanguageModelDownloader.getInstance(mockService);

          // On desktop, this should return early without calling the service
          await downloader.downloadSpanishModelInBackground();

          // The TranslationService should not have been called on non-mobile
          if (!Platform.isAndroid && !Platform.isIOS) {
            expect(mockService.isModelReadyCalls, isEmpty);
            expect(mockService.downloadModelCalls, isEmpty);
          }
        },
      );

      test(
        'does not throw on desktop',
        () async {
          final downloader = LanguageModelDownloader.getInstance(mockService);
          // Should complete without throwing
          expect(
            downloader.downloadSpanishModelInBackground(),
            completes,
          );
        },
      );
    });

    // ----- downloadCommonModelsInBackground -----
    group('downloadCommonModelsInBackground', () {
      test(
        'returns early on non-mobile platform without error',
        () async {
          final downloader = LanguageModelDownloader.getInstance(mockService);

          await downloader.downloadCommonModelsInBackground();

          // On desktop, TranslationService should not have been called
          if (!Platform.isAndroid && !Platform.isIOS) {
            expect(mockService.isModelReadyCalls, isEmpty);
            expect(mockService.downloadModelCalls, isEmpty);
          }
        },
      );

      test(
        'does not throw on desktop',
        () async {
          final downloader = LanguageModelDownloader.getInstance(mockService);
          expect(
            downloader.downloadCommonModelsInBackground(),
            completes,
          );
        },
      );
    });

    // ----- Mobile platform tests (would need a real device/emulator) -----
    group('downloadSpanishModelInBackground (mobile)', () {
      test(
        'downloads Spanish model when not ready',
        () async {
          final downloader = LanguageModelDownloader.getInstance(mockService);
          mockService.stubIsLanguageModelReady('es', false);
          mockService.stubDownloadLanguageModel('es', true);

          await downloader.downloadSpanishModelInBackground();

          expect(mockService.isModelReadyCalls, contains('es'));
        },
        skip: 'Requires mobile platform (Android/iOS)',
      );

      test(
        'skips download when model is already ready',
        () async {
          final downloader = LanguageModelDownloader.getInstance(mockService);
          mockService.stubIsLanguageModelReady('es', true);

          await downloader.downloadSpanishModelInBackground();

          expect(mockService.isModelReadyCalls, contains('es'));
          // downloadModel should not be called since model is already ready
        },
        skip: 'Requires mobile platform (Android/iOS)',
      );

      test(
        'handles download failure gracefully',
        () async {
          final downloader = LanguageModelDownloader.getInstance(mockService);
          mockService.stubIsLanguageModelReady('es', false);
          mockService.stubDownloadLanguageModel('es', false);

          // Should not throw even on failure
          await downloader.downloadSpanishModelInBackground();
        },
        skip: 'Requires mobile platform (Android/iOS)',
      );

      test(
        'handles exception during download',
        () async {
          // Create a failing mock for this test
          final failingService = _FailingTranslationService();
          final downloader = LanguageModelDownloader.getInstance(failingService);

          // Should not throw - background operation swallows errors
          await downloader.downloadSpanishModelInBackground();
        },
        skip: 'Requires mobile platform (Android/iOS)',
      );
    });

    group('downloadCommonModelsInBackground (mobile)', () {
      test(
        'downloads es, fr, de models when not ready',
        () async {
          final downloader = LanguageModelDownloader.getInstance(mockService);

          for (final lang in ['es', 'fr', 'de']) {
            mockService.stubIsLanguageModelReady(lang, false);
            mockService.stubDownloadLanguageModel(lang, true);
          }

          await downloader.downloadCommonModelsInBackground();

          for (final lang in ['es', 'fr', 'de']) {
            expect(mockService.isModelReadyCalls, contains(lang));
          }
        },
        skip: 'Requires mobile platform (Android/iOS)',
      );

      test(
        'skips already-ready models',
        () async {
          final downloader = LanguageModelDownloader.getInstance(mockService);

          // Only Spanish is not ready
          mockService.stubIsLanguageModelReady('es', false);
          mockService.stubIsLanguageModelReady('fr', true);
          mockService.stubIsLanguageModelReady('de', true);
          mockService.stubDownloadLanguageModel('es', true);

          await downloader.downloadCommonModelsInBackground();

          // Spanish should be checked and downloaded
          expect(mockService.isModelReadyCalls, contains('es'));
        },
        skip: 'Requires mobile platform (Android/iOS)',
      );

      test(
        'continues downloading other models if one fails',
        () async {
          final downloader = LanguageModelDownloader.getInstance(mockService);

          for (final lang in ['es', 'fr', 'de']) {
            mockService.stubIsLanguageModelReady(lang, false);
            mockService.stubDownloadLanguageModel(lang, lang != 'fr');
          }

          await downloader.downloadCommonModelsInBackground();

          // All three should be checked
          expect(mockService.isModelReadyCalls.length, greaterThanOrEqualTo(3));
        },
        skip: 'Requires mobile platform (Android/iOS)',
      );
    });

    // ----- Singleton behavior -----
    group('singleton behavior', () {
      test(
        'getInstance returns same instance',
        () {
          final a = LanguageModelDownloader.getInstance(mockService);
          final b = LanguageModelDownloader.getInstance(mockService);
          expect(identical(a, b), isTrue);
        },
      );
    });
  });
}

/// A TranslationService that throws on every call, for error-handling tests
class _FailingTranslationService implements TranslationService {
  @override
  Future<String> translate({
    required String text,
    required String targetLanguage,
    String? sourceLanguage,
  }) async {
    throw Exception('Translation failed');
  }

  @override
  Future<String> detectLanguage(String text) async {
    throw Exception('Detection failed');
  }

  @override
  Future<bool> isLanguageModelReady(String languageCode) async {
    throw Exception('Check failed');
  }

  @override
  Future<bool> downloadLanguageModel(String languageCode, {void Function(String)? onProgress}) async {
    throw Exception('Download failed');
  }
}
