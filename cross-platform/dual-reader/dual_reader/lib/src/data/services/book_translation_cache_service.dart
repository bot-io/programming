import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

/// Cache service specifically for book translations.
/// Stores translations by book location (book ID + page index + language) for efficient reuse.
class BookTranslationCacheService {
  static const String _boxName = 'bookTranslationCache';

  Future<void> init() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox<String>(_boxName);
      debugPrint('[BookTranslationCache] Initialized cache box');
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
    final box = await _getBox();
    final key = _generateKey(bookId, pageIndex, language);
    await box.put(key, translatedText);
    debugPrint('[BookTranslationCache] Cached: book=$bookId, page=$pageIndex, lang=$language');
  }

  /// Get cached translation for a specific book page and language
  String? getCachedTranslation(
    String bookId,
    int pageIndex,
    String language,
  ) {
    if (!Hive.isBoxOpen(_boxName)) {
      debugPrint('[BookTranslationCache] Box not open, returning null');
      return null;
    }
    final box = Hive.box<String>(_boxName);
    final key = _generateKey(bookId, pageIndex, language);
    final cached = box.get(key);
    if (cached != null) {
      debugPrint('[BookTranslationCache] Cache hit: book=$bookId, page=$pageIndex, lang=$language');
    } else {
      debugPrint('[BookTranslationCache] Cache miss: book=$bookId, page=$pageIndex, lang=$language');
    }
    return cached;
  }

  /// Clear all cached translations for a specific book
  Future<void> clearBook(String bookId) async {
    final box = await _getBox();
    final keysToDelete = box.keys
        .where((key) => key.toString().startsWith('${bookId}_page_'))
        .toList();

    for (final key in keysToDelete) {
      await box.delete(key);
    }
    debugPrint('[BookTranslationCache] Cleared $keysToDelete.length translations for book $bookId');
  }

  /// Clear all cached translations for a specific book and language
  Future<void> clearBookLanguage(String bookId, String language) async {
    final box = await _getBox();
    final keysToDelete = box.keys
        .where((key) => key.toString().startsWith('${bookId}_page_') &&
                      key.toString().endsWith('_$language'))
        .toList();

    for (final key in keysToDelete) {
      await box.delete(key);
    }
    debugPrint('[BookTranslationCache] Cleared $keysToDelete.length translations for book $bookId, language $language');
  }

  /// Get cache statistics
  Future<Map<String, int>> getStats() async {
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

    return stats;
  }
}
