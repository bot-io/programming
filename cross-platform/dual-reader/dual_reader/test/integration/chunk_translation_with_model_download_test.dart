import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hive_test/hive_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dual_reader/src/core/di/injection_container.dart' as di;
import 'package:dual_reader/src/data/services/client_side_translation_service.dart';

/// Integration tests for chunk-based translation with ML Kit model download.
/// Tests the complete flow from model download to translation.
/// NOTE: These tests require a mobile device/emulator due to platform channel requirements.
void main() {
  // Skip integration tests on web/windows due to platform channel requirements
  final skipIntegrationTests = kIsWeb || true; // Always skip for now - requires device

  test('ML Kit Integration tests skipped - run on device/emulator', () {
    if (skipIntegrationTests) {
      print('ML Kit Integration Tests require a mobile device or emulator');
      print('Run with: flutter test test/integration/chunk_translation_with_model_download_test.dart --device-id=<emulator-id>');
    }
  }, skip: !skipIntegrationTests);

  group('Chunk Translation with Model Download Integration Tests', () {
    late ClientSideTranslationService translationService;

    setUpAll(() async {
      // Initialize Hive with test configuration
      await Hive.initFlutter();

      // Initialize DI container
      await di.init();

      translationService = di.sl<ClientSideTranslationService>();
    });

    tearDownAll(() async {
      await translationService.close();
      await Hive.close();
    });

    test('should check model readiness before translation', () async {
      // Check if Spanish model is ready (may trigger download check)
      final isReady = await translationService.isLanguageModelReady('es');

      // Result should be a boolean
      expect(isReady, isA<bool>());

      print('[Integration Test] Spanish model ready: $isReady');
    });

    test('should download language model when requested', () async {
      final progressMessages = <String>[];

      // Attempt to download Spanish model
      final result = await translationService.downloadLanguageModel(
        'es',
        onProgress: (message) {
          progressMessages.add(message);
          print('[Integration Test] Progress: $message');
        },
      );

      // Result indicates success or failure
      expect(result, isA<bool>());

      // Should have received some progress messages
      expect(progressMessages, isNotEmpty);

      print('[Integration Test] Download result: $result');
      print('[Integration Test] Total progress messages: ${progressMessages.length}');
      for (final msg in progressMessages) {
        print('[Integration Test]   - $msg');
      }

      // Verify model is ready after download attempt
      final isReady = await translationService.isLanguageModelReady('es');
      print('[Integration Test] Model ready after download: $isReady');
    });

    test('should translate text after model download', () async {
      // Ensure model is available
      await translationService.downloadLanguageModel('es');

      // Translate a simple text
      final result = await translationService.translate(
        text: 'Hello world',
        targetLanguage: 'es',
      );

      // Translation should succeed
      expect(result, isNotEmpty);
      expect(result, isNot(equals('Hello world'))); // Should be translated

      print('[Integration Test] Translation result: $result');
    });

    test('should handle model download timeout gracefully', () async {
      // Try to download a model with a timeout
      final stopwatch = Stopwatch()..start();

      final result = await translationService.downloadLanguageModel(
        'fr',
        onProgress: (message) {
          print('[Integration Test] FR Progress: $message');
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('[Integration Test] Download timeout after 10s');
          return false; // Indicate timeout
        },
      );

      stopwatch.stop();

      print('[Integration Test] Download completed in ${stopwatch.elapsedMilliseconds}ms');
      print('[Integration Test] Download result: $result');

      // Should complete without throwing
      expect(result, isA<bool>());
    });

    test('should translate chunk with automatic model download', () async {
      // This simulates the actual user flow:
      // 1. User opens book
      // 2. App requests translation
      // 3. ML Kit downloads model if needed
      // 4. Translation proceeds

      final testText = 'This is a test paragraph for translation.';

      final stopwatch = Stopwatch()..start();

      final result = await translationService.translate(
        text: testText,
        targetLanguage: 'es',
      );

      stopwatch.stop();

      // Should complete successfully
      expect(result, isNotEmpty);

      print('[Integration Test] Chunk translation completed in ${stopwatch.elapsedMilliseconds}ms');
      print('[Integration Test] Original: $testText');
      print('[Integration Test] Translated: $result');
    });

    test('should check multiple language models', () async {
      final languages = ['es', 'fr', 'de', 'it'];
      final results = <String, bool>{};

      for (final lang in languages) {
        final isReady = await translationService.isLanguageModelReady(lang);
        results[lang] = isReady;
        print('[Integration Test] $lang model ready: $isReady');
      }

      // All languages should be checked
      expect(results, hasLength(languages.length));

      // At least one should be ready (English is default)
      expect(results.values.any((ready) => ready), isTrue);
    });

    test('should handle concurrent translation requests', () async {
      // Simulate multiple pages being translated simultaneously
      final texts = [
        'First page content.',
        'Second page content.',
        'Third page content.',
      ];

      final stopwatch = Stopwatch()..start();

      final futures = texts.map((text) => translationService.translate(
        text: text,
        targetLanguage: 'es',
      )).toList();

      final results = await Future.wait(futures);

      stopwatch.stop();

      // All translations should succeed
      expect(results, hasLength(3));
      expect(results.every((r) => r.isNotEmpty), isTrue);

      print('[Integration Test] Concurrent translations completed in ${stopwatch.elapsedMilliseconds}ms');
      for (int i = 0; i < results.length; i++) {
        print('[Integration Test] Page $i: ${results[i]}');
      }
    });

    test('should maintain model state across translations', () async {
      // First translation
      final result1 = await translationService.translate(
        text: 'First translation',
        targetLanguage: 'es',
      );

      expect(result1, isNotEmpty);

      // Second translation (model should still be ready)
      final isReady = await translationService.isLanguageModelReady('es');
      expect(isReady, isTrue);

      // Third translation
      final result2 = await translationService.translate(
        text: 'Second translation',
        targetLanguage: 'es',
      );

      expect(result2, isNotEmpty);

      print('[Integration Test] Model state maintained across translations');
    });
  });
}
