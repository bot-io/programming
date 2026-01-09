import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:dual_reader/src/core/utils/logging_service.dart';

/// Cache service specifically for book translations.
/// Stores translations by book location (book ID + page index + language) for efficient reuse.
class BookTranslationCacheService {
  static const String _boxName = 'bookTranslationCache';
  static const String _componentName = 'BookTranslationCache';

  Future<void> init() async {
    try {
      if (!Hive.isBoxOpen(_boxName)) {
        await Hive.openBox<String>(_boxName);
      }
      _componentName.logInfo('Initialized cache box');
    } catch (e) {
      _componentName.logError('Failed to initialize cache box', error: e);
      rethrow;
    }
  }

  Future<Box<String>> _getBox() async {
    if (!Hive.isBoxOpen(_boxName)) {
      return await Hive.openBox<String>(_boxName);
    }
    return Hive.box<String>(_boxName);
  }

  /// Generate cache key from book ID, page index, and language
  String _generateKey(String bookId, int pageIndex, String language) {
    return '${bookId}_page_${pageIndex}_$language';
  }

  /// Cache a translation for a specific book page and language
  Future<void> cacheTranslation(
    String bookId,
    int pageIndex,
    String language,
    String translatedText,
  ) async {
    try {
      final box = await _getBox();
      final key = _generateKey(bookId, pageIndex, language);
      await box.put(key, translatedText);

      // Log cache operation with translation length (not content)
      _componentName.logDebug(
        'Cached translation - book: $bookId, page: $pageIndex, lang: $language, length: ${translatedText.length} chars'
      );
    } catch (e) {
      _componentName.logError(
        'Failed to cache translation - book: $bookId, page: $pageIndex, lang: $language',
        error: e,
      );
      rethrow;
    }
  }

  /// Get cached translation for a specific book page and language
  String? getCachedTranslation(
    String bookId,
    int pageIndex,
    String language,
  ) {
    try {
      if (!Hive.isBoxOpen(_boxName)) {
        _componentName.logWarning('Box not open, returning null - book: $bookId, page: $pageIndex, lang: $language');
        return null;
      }

      final box = Hive.box<String>(_boxName);
      final key = _generateKey(bookId, pageIndex, language);
      final cached = box.get(key);

      if (cached != null) {
        _componentName.logDebug(
          'Cache HIT - book: $bookId, page: $pageIndex, lang: $language, length: ${cached.length} chars'
        );
      } else {
        _componentName.logDebug('Cache MISS - book: $bookId, page: $pageIndex, lang: $language');
      }

      return cached;
    } catch (e) {
      _componentName.logError(
        'Error getting cached translation - book: $bookId, page: $pageIndex, lang: $language',
        error: e,
      );
      return null;
    }
  }

  /// Clear all cached translations for a specific book
  Future<void> clearBook(String bookId) async {
    try {
      final box = await _getBox();
      final keysToDelete = box.keys
          .where((key) => key.toString().startsWith('${bookId}_page_'))
          .toList();

      for (final key in keysToDelete) {
        await box.delete(key);
      }

      _componentName.logInfo('Cleared ${keysToDelete.length} translations for book: $bookId');
    } catch (e) {
      _componentName.logError('Failed to clear book cache - book: $bookId', error: e);
      rethrow;
    }
  }

  /// Clear all cached translations for a specific book and language
  Future<void> clearBookLanguage(String bookId, String language) async {
    try {
      final box = await _getBox();
      final keysToDelete = box.keys
          .where((key) => key.toString().startsWith('${bookId}_page_') &&
                      key.toString().endsWith('_$language'))
          .toList();

      for (final key in keysToDelete) {
        await box.delete(key);
      }

      _componentName.logInfo(
        'Cleared ${keysToDelete.length} translations - book: $bookId, language: $language'
      );
    } catch (e) {
      _componentName.logError(
        'Failed to clear book-language cache - book: $bookId, language: $language',
        error: e,
      );
      rethrow;
    }
  }

  /// Clear all cached translations
  Future<void> clearAll() async {
    try {
      if (!Hive.isBoxOpen(_boxName)) {
        _componentName.logWarning('Box not open, nothing to clear');
        return;
      }

      final box = Hive.box<String>(_boxName);
      final count = box.length;
      await box.clear();

      _componentName.logInfo('Cleared all $count cached translations');
    } catch (e) {
      _componentName.logError('Failed to clear all cache', error: e);
      rethrow;
    }
  }

  /// Get cache statistics
  Future<Map<String, int>> getStats() async {
    try {
      if (!Hive.isBoxOpen(_boxName)) {
        return {};
      }

      final box = Hive.box<String>(_boxName);
      final stats = <String, int>{};

      for (final key in box.keys) {
        final keyStr = key.toString();
        final parts = keyStr.split('_');
        if (parts.length >= 4) {
          final bookId = parts[0];
          stats[bookId] = (stats[bookId] ?? 0) + 1;
        }
      }

      _componentName.logDebug('Cache stats - books: ${stats.length}, total entries: ${box.length}');
      return stats;
    } catch (e) {
      _componentName.logError('Failed to get cache stats', error: e);
      return {};
    }
  }
}
