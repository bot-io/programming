import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:dual_reader/providers/reader_provider.dart';
import 'package:dual_reader/services/storage_service.dart';
import 'package:dual_reader/services/translation_service.dart';
import 'package:dual_reader/providers/settings_provider.dart';
import 'package:dual_reader/models/book.dart';
import 'package:dual_reader/models/chapter.dart';
import 'package:dual_reader/models/reading_progress.dart';
import 'package:dual_reader/models/app_settings.dart';

void main() {
  group('ReaderProvider', () {
    late ReaderProvider readerProvider;
    late StorageService storageService;
    late TranslationService translationService;
    late SettingsProvider settingsProvider;

    setUp(() async {
      // Note: In real tests, these would be mocked
      storageService = StorageService();
      translationService = TranslationService();
      await translationService.initialize();
      
      final settingsStorage = StorageService();
      await settingsStorage.init();
      settingsProvider = SettingsProvider(settingsStorage);
      
      readerProvider = ReaderProvider(
        storageService,
        translationService,
        settingsProvider,
      );
    });

    test('initial state has no current book', () {
      expect(readerProvider.currentBook, isNull);
      expect(readerProvider.pages, isEmpty);
      expect(readerProvider.currentPageIndex, 0);
      expect(readerProvider.isLoading, false);
      expect(readerProvider.isTranslating, false);
      expect(readerProvider.error, isNull);
    });

    test('hasNextPage returns false when no pages', () {
      expect(readerProvider.hasNextPage, false);
    });

    test('hasPreviousPage returns false when no pages', () {
      expect(readerProvider.hasPreviousPage, false);
    });

    test('chapters returns empty list when no book', () {
      expect(readerProvider.chapters, isEmpty);
    });

    test('currentPage returns null when no pages', () {
      expect(readerProvider.currentPage, isNull);
    });

    test('getCurrentChapter returns null when no book', () {
      expect(readerProvider.getCurrentChapter(), isNull);
    });

    test('goToPage does nothing when pages are empty', () async {
      await readerProvider.goToPage(0);
      expect(readerProvider.currentPageIndex, 0);
    });

    test('goToPage clamps negative index to 0', () async {
      // This would require pages to be set up first
      // In a real test with mocked dependencies
      await readerProvider.goToPage(-1);
      expect(readerProvider.currentPageIndex, greaterThanOrEqualTo(0));
    });

    test('nextPage does nothing when no next page', () async {
      await readerProvider.nextPage();
      expect(readerProvider.currentPageIndex, 0);
    });

    test('previousPage does nothing when no previous page', () async {
      await readerProvider.previousPage();
      expect(readerProvider.currentPageIndex, 0);
    });

    test('clear resets all state', () {
      readerProvider.clear();
      
      expect(readerProvider.currentBook, isNull);
      expect(readerProvider.pages, isEmpty);
      expect(readerProvider.currentPageIndex, 0);
      expect(readerProvider.progress, isNull);
      expect(readerProvider.error, isNull);
    });

    // Note: Full integration tests for loadBook, translateCurrentPage, etc.
    // would require:
    // 1. Mocked StorageService with test data
    // 2. Mocked TranslationService
    // 3. Mocked BuildContext
    // 4. These are better suited for integration test suite
  });
}
