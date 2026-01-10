import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:dual_reader/src/core/utils/logging_service.dart';
import 'package:dual_reader/src/domain/entities/translation_chunk.dart';

/// Cache service for translation chunks.
///
/// Stores translated chunks and maintains page-to-chunk mappings for efficient lookup.
/// Keys: {bookId}_chunk_{startPage}_{endPage}_{language}
class ChunkCacheService {
  static const String _boxName = 'translationChunkCache';
  static const String _mappingBoxName = 'translationChunkMapping';
  static const String _componentName = 'ChunkCache';

  /// Initialize cache boxes
  Future<void> init() async {
    try {
      if (!Hive.isBoxOpen(_boxName)) {
        await Hive.openBox<String>(_boxName);
      }
      if (!Hive.isBoxOpen(_mappingBoxName)) {
        await Hive.openBox<String>(_mappingBoxName);
      }
      _componentName.logInfo('Initialized chunk cache boxes');
    } catch (e) {
      _componentName.logError('Failed to initialize chunk cache boxes', error: e);
      rethrow;
    }
  }

  Future<Box<String>> _getBox() async {
    if (!Hive.isBoxOpen(_boxName)) {
      return await Hive.openBox<String>(_boxName);
    }
    return Hive.box<String>(_boxName);
  }

  Future<Box<String>> _getMappingBox() async {
    if (!Hive.isBoxOpen(_mappingBoxName)) {
      return await Hive.openBox<String>(_mappingBoxName);
    }
    return Hive.box<String>(_mappingBoxName);
  }

  /// Generate mapping key from page info
  String _generateMappingKey(String bookId, int pageIndex, String language) {
    return '${bookId}_page_${pageIndex}_$language';
  }

  /// Cache a translation chunk
  Future<void> cacheChunk(TranslationChunk chunk) async {
    try {
      final box = await _getBox();
      final mappingBox = await _getMappingBox();

      // Serialize chunk to JSON
      final chunkJson = _chunkToJson(chunk);

      // Cache the chunk
      await box.put(chunk.chunkId, chunkJson);

      // Update page-to-chunk mappings for all pages in this chunk
      for (int i = chunk.startPageIndex; i <= chunk.endPageIndex; i++) {
        final mappingKey = _generateMappingKey(chunk.bookId, i, chunk.targetLanguage);
        await mappingBox.put(mappingKey, chunk.chunkId);
      }

      _componentName.logDebug(
        'Cached chunk ${chunk.chunkId} - pages: ${chunk.startPageIndex}-${chunk.endPageIndex}, '
        'length: ${chunk.originalText.length} chars, translated: ${chunk.isTranslated}'
      );
    } catch (e) {
      _componentName.logError(
        'Failed to cache chunk - ${chunk.chunkId}',
        error: e,
      );
      rethrow;
    }
  }

  /// Get a cached chunk by its ID
  TranslationChunk? getCachedChunk(String chunkId) {
    try {
      if (!Hive.isBoxOpen(_boxName)) {
        _componentName.logWarning('Box not open, returning null - chunk: $chunkId');
        return null;
      }

      final box = Hive.box<String>(_boxName);
      final chunkJson = box.get(chunkId);

      if (chunkJson != null) {
        final chunk = _chunkFromJson(chunkJson);
        _componentName.logDebug(
          'Cache HIT - chunk: $chunkId, translated: ${chunk.isTranslated}'
        );
        return chunk;
      }

      _componentName.logDebug('Cache MISS - chunk: $chunkId');
      return null;
    } catch (e) {
      _componentName.logError(
        'Error getting cached chunk - $chunkId',
        error: e,
      );
      return null;
    }
  }

  /// Get the chunk containing a specific page
  TranslationChunk? getCachedChunkForPage(String bookId, int pageIndex, String language) {
    try {
      if (!Hive.isBoxOpen(_mappingBoxName)) {
        return null;
      }

      final mappingBox = Hive.box<String>(_mappingBoxName);
      final mappingKey = _generateMappingKey(bookId, pageIndex, language);
      final chunkId = mappingBox.get(mappingKey);

      if (chunkId != null) {
        return getCachedChunk(chunkId);
      }

      return null;
    } catch (e) {
      _componentName.logError(
        'Error getting chunk for page - book: $bookId, page: $pageIndex',
        error: e,
      );
      return null;
    }
  }

  /// Check if a page has a cached translation
  bool isPageCached(String bookId, int pageIndex, String language) {
    try {
      if (!Hive.isBoxOpen(_mappingBoxName)) {
        return false;
      }

      final mappingBox = Hive.box<String>(_mappingBoxName);
      final mappingKey = _generateMappingKey(bookId, pageIndex, language);
      final chunkId = mappingBox.get(mappingKey);

      if (chunkId == null) {
        return false;
      }

      final chunk = getCachedChunk(chunkId);
      return chunk?.isTranslated ?? false;
    } catch (e) {
      _componentName.logError(
        'Error checking if page is cached - book: $bookId, page: $pageIndex',
        error: e,
      );
      return false;
    }
  }

  /// Clear all cached chunks for a specific book
  Future<void> clearBook(String bookId) async {
    try {
      final box = await _getBox();
      final mappingBox = await _getMappingBox();

      // Find and delete all chunks for this book
      final chunkKeysToDelete = box.keys
          .where((key) => key.toString().startsWith('${bookId}_chunk_'))
          .toList();

      for (final key in chunkKeysToDelete) {
        await box.delete(key);
      }

      // Find and delete all mappings for this book
      final mappingKeysToDelete = mappingBox.keys
          .where((key) => key.toString().startsWith('${bookId}_page_'))
          .toList();

      for (final key in mappingKeysToDelete) {
        await mappingBox.delete(key);
      }

      _componentName.logInfo(
        'Cleared ${chunkKeysToDelete.length} chunks and ${mappingKeysToDelete.length} mappings for book: $bookId'
      );
    } catch (e) {
      _componentName.logError('Failed to clear book cache - book: $bookId', error: e);
      rethrow;
    }
  }

  /// Clear all cached chunks for a specific book and language
  Future<void> clearBookLanguage(String bookId, String language) async {
    try {
      final box = await _getBox();
      final mappingBox = await _getMappingBox();

      // Find and delete chunks for this book and language
      final chunkKeysToDelete = box.keys
          .where((key) {
            final keyStr = key.toString();
            return keyStr.startsWith('${bookId}_chunk_') && keyStr.endsWith('_$language');
          })
          .toList();

      for (final key in chunkKeysToDelete) {
        await box.delete(key);
      }

      // Find and delete mappings for this book and language
      final mappingKeysToDelete = mappingBox.keys
          .where((key) {
            final keyStr = key.toString();
            return keyStr.startsWith('${bookId}_page_') && keyStr.endsWith('_$language');
          })
          .toList();

      for (final key in mappingKeysToDelete) {
        await mappingBox.delete(key);
      }

      _componentName.logInfo(
        'Cleared ${chunkKeysToDelete.length} chunks and ${mappingKeysToDelete.length} mappings - '
        'book: $bookId, language: $language'
      );
    } catch (e) {
      _componentName.logError(
        'Failed to clear book-language cache - book: $bookId, language: $language',
        error: e,
      );
      rethrow;
    }
  }

  /// Clear all cached chunks
  Future<void> clearAll() async {
    try {
      if (!Hive.isBoxOpen(_boxName)) {
        _componentName.logWarning('Box not open, nothing to clear');
        return;
      }

      final box = Hive.box<String>(_boxName);
      final mappingBox = await _getMappingBox();

      final chunkCount = box.length;
      final mappingCount = mappingBox.length;

      await box.clear();
      await mappingBox.clear();

      _componentName.logInfo('Cleared all $chunkCount chunks and $mappingCount mappings');
    } catch (e) {
      _componentName.logError('Failed to clear all cache', error: e);
      rethrow;
    }
  }

  /// Serialize a TranslationChunk to JSON
  String _chunkToJson(TranslationChunk chunk) {
    final map = {
      'chunkId': chunk.chunkId,
      'bookId': chunk.bookId,
      'startPageIndex': chunk.startPageIndex,
      'endPageIndex': chunk.endPageIndex,
      'originalText': chunk.originalText,
      'translatedText': chunk.translatedText,
      'pageBreakOffsets': chunk.pageBreakOffsets,
      'targetLanguage': chunk.targetLanguage,
      'translatedAt': chunk.translatedAt?.toIso8601String(),
    };
    return jsonEncode(map);
  }

  /// Deserialize a TranslationChunk from JSON
  TranslationChunk _chunkFromJson(String json) {
    final map = jsonDecode(json) as Map<String, dynamic>;
    return TranslationChunk(
      chunkId: map['chunkId'] as String,
      bookId: map['bookId'] as String,
      startPageIndex: map['startPageIndex'] as int,
      endPageIndex: map['endPageIndex'] as int,
      originalText: map['originalText'] as String,
      translatedText: map['translatedText'] as String?,
      pageBreakOffsets: List<int>.from(map['pageBreakOffsets'] as List),
      targetLanguage: map['targetLanguage'] as String,
      translatedAt: map['translatedAt'] != null
          ? DateTime.parse(map['translatedAt'] as String)
          : null,
    );
  }

  /// Get cache statistics
  Future<Map<String, dynamic>> getStats() async {
    try {
      if (!Hive.isBoxOpen(_boxName)) {
        return {};
      }

      final box = Hive.box<String>(_boxName);
      final mappingBox = await _getMappingBox();

      final stats = <String, dynamic>{
        'totalChunks': box.length,
        'totalMappings': mappingBox.length,
        'books': <String, int>{},
      };

      // Count chunks per book
      for (final key in box.keys) {
        final keyStr = key.toString();
        final parts = keyStr.split('_chunk_');
        if (parts.isNotEmpty) {
          final bookId = parts[0];
          final bookStats = stats['books'] as Map<String, int>;
          bookStats[bookId] = (bookStats[bookId] ?? 0) + 1;
        }
      }

      _componentName.logDebug(
        'Cache stats - books: ${(stats['books'] as Map).length}, '
        'total chunks: ${stats['totalChunks']}, '
        'total mappings: ${stats['totalMappings']}'
      );

      return stats;
    } catch (e) {
      _componentName.logError('Failed to get cache stats', error: e);
      return {};
    }
  }
}
