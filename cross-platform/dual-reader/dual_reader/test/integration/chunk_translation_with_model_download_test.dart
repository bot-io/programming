import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show debugPrint;
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
  // Skip integration tests on non-mobile platforms due to platform channel requirements
  final isMobilePlatform = Platform.isAndroid || Platform.isIOS;

  group('Chunk Translation with Model Download Integration Tests', () {
    late ClientSideTranslationService translationService;

    setUpAll(() async {
      if (!isMobilePlatform) {
        debugPrint('ML Kit Integration Tests require a mobile device or emulator');
        debugPrint('Run with: flutter test test/integration/chunk_translation_with_model_download_test.dart --device-id=<emulator-id>');
        return;
      }

      // Initialize Hive with test configuration
      await Hive.initFlutter();

      // Initialize DI container
      await di.init();

      translationService = di.sl<ClientSideTranslationService>();
    });

    tearDownAll(() async {
      if (!isMobilePlatform) return;
      await translationService.close();
      await Hive.close();
    });

    test('should check model readiness before translation', () async {
      if (!isMobilePlatform) return;

      // Check if Spanish model is ready (may trigger download check)
      final isReady = await translationService.isLanguageModelReady('es');

      // Result should be a boolean
      expect(isReady, isA<bool>());

      debugPrint('[Integration Test] Spanish model ready: $isReady');
    }, skip: !isMobilePlatform);

    test('should download language model when requested', () async {
      if (!isMobilePlatform) return;

      final progressMessages = <String>[];

      // Attempt to download Spanish model
      final result = await translationService.downloadLanguageModel(
        'es',
        onProgress: (message) {
          progressMessages.add(message);
          debugPrint('[Integration Test] Progress: $message');
        },
      );

      // Result indicates success or failure
      expect(result, isA<bool>());

      // Should have received some progress messages
      expect(progressMessages, isNotEmpty);

      debugPrint('[Integration Test] Download result: $result');
      debugPrint('[Integration Test] Total progress messages: ${progressMessages.length}');
      for (final msg in progressMessages) {
        debugPrint('[Integration Test]   - $msg');
      }

      // Verify model is ready after download attempt
      final isReady = await translationService.isLanguageModelReady('es');
      debugPrint('[Integration Test] Model ready after download: $isReady');
    }, skip: !isMobilePlatform);

    test('should translate text after model download', () async {
      if (!isMobilePlatform) return;

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

      debugPrint('[Integration Test] Translation result: $result');
    }, skip: !isMobilePlatform);

    test('should handle model download timeout gracefully', () async {
      if (!isMobilePlatform) return;

      // Try to download a model with a timeout
      final stopwatch = Stopwatch()..start();

      final result = await translationService.downloadLanguageModel(
        'fr',
        onProgress: (message) {
          debugPrint('[Integration Test] FR Progress: $message');
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('[Integration Test] Download timeout after 10s');
          return false; // Indicate timeout
        },
      );

      stopwatch.stop();

      debugPrint('[Integration Test] Download completed in ${stopwatch.elapsedMilliseconds}ms');
      debugPrint('[Integration Test] Download result: $result');

      // Should complete without throwing
      expect(result, isA<bool>());
    }, skip: !isMobilePlatform);

    test('should translate chunk with automatic model download', () async {
      if (!isMobilePlatform) return;

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

      debugPrint('[Integration Test] Chunk translation completed in ${stopwatch.elapsedMilliseconds}ms');
      debugPrint('[Integration Test] Original: $testText');
      debugPrint('[Integration Test] Translated: $result');
    }, skip: !isMobilePlatform);

    test('should check multiple language models', () async {
      if (!isMobilePlatform) return;

      final languages = ['es', 'fr', 'de', 'it'];
      final results = <String, bool>{};

      for (final lang in languages) {
        final isReady = await translationService.isLanguageModelReady(lang);
        results[lang] = isReady;
        debugPrint('[Integration Test] $lang model ready: $isReady');
      }

      // All languages should be checked
      expect(results, hasLength(languages.length));

      // At least one should be ready (English is default)
      expect(results.values.any((ready) => ready), isTrue);
    }, skip: !isMobilePlatform);

    test('should handle concurrent translation requests', () async {
      if (!isMobilePlatform) return;

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

      debugPrint('[Integration Test] Concurrent translations completed in ${stopwatch.elapsedMilliseconds}ms');
      for (int i = 0; i < results.length; i++) {
        debugPrint('[Integration Test] Page $i: ${results[i]}');
      }
    }, skip: !isMobilePlatform);

    test('should maintain model state across translations', () async {
      if (!isMobilePlatform) return;

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

      debugPrint('[Integration Test] Model state maintained across translations');
    }, skip: !isMobilePlatform);
  });
}
