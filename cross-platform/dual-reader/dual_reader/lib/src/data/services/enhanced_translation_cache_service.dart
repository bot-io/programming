import 'dart:convert';
import 'dart:io';
import 'dart:collection';
import 'dart:typed_data';
import 'package:hive/hive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:collection/collection.dart';

/// Enhanced translation caching service with granular caching, LRU eviction,
/// compression, and cache management.
///
/// Features:
/// - Sentence-level caching for reuse across pages
/// - LRU eviction policy with configurable size limits
/// - Compression for space efficiency
/// - Cache size tracking
/// - Preloaded common phrases
class EnhancedTranslationCacheService {
  static const String _boxName = 'translationCache';
  static const String _metadataBoxName = 'translationCacheMetadata';
  static const int _maxKeyLength = 255;

  // Cache configuration
  static const int _defaultMaxCacheSizeBytes = 50 * 1024 * 1024; // 50MB default
  static const int _defaultMaxEntries = 10000;

  // Compression threshold (compress entries larger than 1KB)
  static const int _compressionThreshold = 1024;

  late final Box<String> _cacheBox;
  late final Box<String> _metadataBox;

  int _maxCacheSizeBytes = _defaultMaxCacheSizeBytes;
  int _maxEntries = _defaultMaxEntries;
  final LRUCache _lruCache = LRUCache();

  /// Singleton instance
  static EnhancedTranslationCacheService? _instance;
  static EnhancedTranslationCacheService get instance {
    _instance ??= EnhancedTranslationCacheService._();
    return _instance!;
  }

  EnhancedTranslationCacheService._();

  /// Initialize the cache service.
  Future<void> init() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox<String>(_boxName);
    }
    if (!Hive.isBoxOpen(_metadataBoxName)) {
      await Hive.openBox<String>(_metadataBoxName);
    }

    _cacheBox = Hive.box<String>(_boxName);
    _metadataBox = Hive.box<String>(_metadataBoxName);

    // Initialize metadata
    await _initializeMetadata();

    debugPrint('[EnhancedCache] Cache service initialized');
  }

  /// Initialize metadata tracking.
  Future<void> _initializeMetadata() async {
    final currentSize = _metadataBox.get('cacheSizeBytes');
    final entryCount = _metadataBox.get('entryCount');

    if (currentSize == null) {
      await _metadataBox.put('cacheSizeBytes', '0');
    }
    if (entryCount == null) {
      await _metadataBox.put('entryCount', '0');
    }

    // Load existing entries into LRU cache
    final accessOrder = _metadataBox.get('accessOrder') ?? '';
    if (accessOrder.isNotEmpty) {
      final keys = accessOrder.split(',');
      for (final key in keys) {
        _lruCache._access(key);
      }
    }
  }

  /// Configure cache limits.
  void configure({
    int? maxCacheSizeBytes,
    int? maxEntries,
  }) {
    _maxCacheSizeBytes = maxCacheSizeBytes ?? _maxCacheSizeBytes;
    _maxEntries = maxEntries ?? _maxEntries;
    debugPrint('[EnhancedCache] Cache limits updated: ${_maxCacheSizeBytes}bytes, $_maxEntries entries');
  }

  /// Generate a cache key from text, source language, and target language.
  /// Uses hash for long texts to avoid Hive's 255 character key limit.
  String _generateCacheKey(String text, String sourceLanguage, String targetLanguage) {
    final combined = '${text}_$sourceLanguage\$$targetLanguage';

    if (combined.length <= _maxKeyLength) {
      return combined;
    }

    // Use SHA256 hash for long texts
    final bytes = utf8.encode(combined);
    final hash = sha256.convert(bytes);
    return 'trans_${hash.toString().substring(0, 32)}';
  }

  /// Cache a translation with optional compression.
  Future<bool> cacheTranslation({
    required String originalText,
    required String sourceLanguage,
    required String targetLanguage,
    required String translatedText,
    bool forceCache = false,
  }) async {
    try {
      final key = _generateCacheKey(originalText, sourceLanguage, targetLanguage);

      // Check if already cached (unless forced)
      if (!forceCache && _cacheBox.containsKey(key)) {
        // Update the existing entry with the new translation
        final oldValue = _cacheBox.get(key);
        final cacheValue = await _prepareCacheValue(translatedText);
        if (oldValue != cacheValue) {
          final oldBytes = oldValue?.length ?? 0;
          final newBytes = cacheValue.length;
          await _cacheBox.put(key, cacheValue);
          await _metadataBox.put(
            'cacheSizeBytes',
            (getCurrentCacheSizeBytes() - oldBytes + newBytes).toString(),
          );
        }
        // Update access time for LRU
        _lruCache._access(key);
        await _updateAccessOrder();
        return true;
      }

      // Prepare value (with compression if needed)
      final cacheValue = await _prepareCacheValue(translatedText);
      final valueBytes = cacheValue.length;

      // Check cache limits and evict if necessary
      await _ensureCapacity(valueBytes);

      // Store in cache
      await _cacheBox.put(key, cacheValue);

      // Update metadata
      await _updateMetadata(key, valueBytes, added: true);

      // Update LRU
      _lruCache._access(key);
      await _updateAccessOrder();

      debugPrint('[EnhancedCache] Cached: "$originalText" ($valueBytes bytes)');
      return true;
    } catch (e) {
      debugPrint('[EnhancedCache] Cache error: $e');
      return false;
    }
  }

  /// Get a cached translation.
  String? getCachedTranslation({
    required String originalText,
    required String sourceLanguage,
    required String targetLanguage,
  }) {
    try {
      final key = _generateCacheKey(originalText, sourceLanguage, targetLanguage);

      if (!_cacheBox.containsKey(key)) {
        debugPrint('[EnhancedCache] Cache miss: "$originalText"');
        return null;
      }

      // Retrieve and decompress if needed
      final cachedValue = _cacheBox.get(key);
      final result = _extractCacheValue(cachedValue!);

      // Update access time for LRU
      _lruCache._access(key);
      _updateAccessOrder();

      debugPrint('[EnhancedCache] Cache hit: "$originalText"');
      return result;
    } catch (e) {
      debugPrint('[EnhancedCache] Retrieve error: $e');
      return null;
    }
  }

  /// Cache translations at sentence level for granular reuse.
  Future<void> cacheSentenceTranslations({
    required List<String> sentences,
    required String sourceLanguage,
    required String targetLanguage,
    required List<String> translations,
  }) async {
    if (sentences.length != translations.length) {
      debugPrint('[EnhancedCache] Sentence/translation count mismatch');
      return;
    }

    for (int i = 0; i < sentences.length; i++) {
      await cacheTranslation(
        originalText: sentences[i],
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
        translatedText: translations[i],
      );
    }

    debugPrint('[EnhancedCache] Cached ${sentences.length} sentence translations');
  }

  /// Get cached sentence translations.
  /// Returns a list of (translation, wasCached) pairs.
  List<TranslationResult> getCachedSentenceTranslations({
    required List<String> sentences,
    required String sourceLanguage,
    required String targetLanguage,
  }) {
    final results = <TranslationResult>[];
    int hitCount = 0;

    for (final sentence in sentences) {
      final cached = getCachedTranslation(
        originalText: sentence,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
      );

      if (cached != null) {
        results.add(TranslationResult(cached, true));
        hitCount++;
      } else {
        results.add(TranslationResult('', false));
      }
    }

    debugPrint('[EnhancedCache] Sentence cache: $hitCount/${sentences.length} hits');
    return results;
  }

  /// Prepare value for caching (with compression if needed).
  Future<String> _prepareCacheValue(String text) async {
    final bytes = utf8.encode(text);

    if (bytes.length < _compressionThreshold) {
      // No compression for small values
      return 'plain:$text';
    }

    // Compress using gzip
    try {
      final compressed = gzip.encode(bytes);
      final base64 = base64Encode(compressed);
      return 'gzip:$base64';
    } catch (e) {
      debugPrint('[EnhancedCache] Compression error: $e');
      // Fallback to uncompressed
      return 'plain:$text';
    }
  }

  /// Extract value from cache (decompress if needed).
  String _extractCacheValue(String cachedValue) {
    if (cachedValue.startsWith('plain:')) {
      return cachedValue.substring(6);
    }

    if (cachedValue.startsWith('gzip:')) {
      try {
        final base64 = cachedValue.substring(5);
        final compressed = base64Decode(base64);
        final decompressed = gzip.decode(compressed);
        return utf8.decode(decompressed);
      } catch (e) {
        debugPrint('[EnhancedCache] Decompression error: $e');
        return cachedValue.substring(5); // Fallback
      }
    }

    // Legacy format (no prefix)
    return cachedValue;
  }

  /// Ensure cache has capacity for new entry.
  Future<void> _ensureCapacity(int requiredBytes) async {
    final currentSize = getCurrentCacheSizeBytes();
    final currentEntries = getCurrentEntryCount();

    // Check if we need to evict
    bool needsEviction = false;

    if (currentEntries >= _maxEntries) {
      needsEviction = true;
    }

    if ((currentSize + requiredBytes) > _maxCacheSizeBytes) {
      needsEviction = true;
    }

    if (needsEviction) {
      await _evictLRU(requiredBytes);
    }
  }

  /// Evict least recently used entries.
  Future<void> _evictLRU(int requiredBytes) async {
    int freedBytes = 0;
    int freedEntries = 0;

    // Get LRU keys
    final keysToEvict = _lruCache._getEvictionCandidates();

    for (final key in keysToEvict) {
      if (!_cacheBox.containsKey(key)) continue;

      final value = _cacheBox.get(key);
      final entrySize = value?.length ?? 0;

      await _cacheBox.delete(key);
      await _updateMetadata(key, entrySize, added: false);

      freedBytes += entrySize;
      freedEntries++;

      // Stop if we've freed enough space
      if (freedBytes >= requiredBytes &&
          (getCurrentEntryCount() < _maxEntries * 0.8)) {
        break;
      }
    }

    // Clear from LRU
    for (final key in keysToEvict.take(freedEntries)) {
      _lruCache._remove(key);
    }

    await _updateAccessOrder();

    debugPrint('[EnhancedCache] Evicted $freedEntries entries ($freedBytes bytes)');
  }

  /// Update metadata after cache operation.
  Future<void> _updateMetadata(String key, int bytes, {required bool added}) async {
    final currentSize = int.parse(_metadataBox.get('cacheSizeBytes') ?? '0');
    final currentCount = int.parse(_metadataBox.get('entryCount') ?? '0');

    if (added) {
      await _metadataBox.put('cacheSizeBytes', (currentSize + bytes).toString());
      await _metadataBox.put('entryCount', (currentCount + 1).toString());
    } else {
      await _metadataBox.put('cacheSizeBytes', (currentSize - bytes).toString());
      await _metadataBox.put('entryCount', (currentCount - 1).toString());
    }
  }

  /// Update access order for LRU tracking.
  Future<void> _updateAccessOrder() async {
    final accessOrder = _lruCache._getAccessOrder();
    await _metadataBox.put('accessOrder', accessOrder.join(','));
  }

  /// Get current cache size in bytes.
  int getCurrentCacheSizeBytes() {
    return int.parse(_metadataBox.get('cacheSizeBytes') ?? '0');
  }

  /// Get current entry count.
  int getCurrentEntryCount() {
    return int.parse(_metadataBox.get('entryCount') ?? '0');
  }

  /// Get cache size as formatted string.
  String getCacheSizeFormatted() {
    final bytes = getCurrentCacheSizeBytes();
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Get cache hit rate statistics.
  Future<CacheStatistics> getStatistics() async {
    final hits = int.parse(_metadataBox.get('cacheHits') ?? '0');
    final misses = int.parse(_metadataBox.get('cacheMisses') ?? '0');
    final total = hits + misses;

    return CacheStatistics(
      hits: hits,
      misses: misses,
      hitRate: total > 0 ? hits / total : 0.0,
      sizeBytes: getCurrentCacheSizeBytes(),
      entryCount: getCurrentEntryCount(),
    );
  }

  /// Record cache hit.
  Future<void> _recordHit() async {
    final hits = int.parse(_metadataBox.get('cacheHits') ?? '0');
    await _metadataBox.put('cacheHits', (hits + 1).toString());
  }

  /// Record cache miss.
  Future<void> _recordMiss() async {
    final misses = int.parse(_metadataBox.get('cacheMisses') ?? '0');
    await _metadataBox.put('cacheMisses', (misses + 1).toString());
  }

  /// Clear all cached translations.
  Future<void> clearCache() async {
    await _cacheBox.clear();
    await _metadataBox.put('cacheSizeBytes', '0');
    await _metadataBox.put('entryCount', '0');
    _lruCache._clear();

    debugPrint('[EnhancedCache] Cache cleared');
  }

  /// Clear cache for specific language pair.
  Future<void> clearLanguagePair(String sourceLanguage, String targetLanguage) async {
    final keysToDelete = <String>[];

    for (final key in _cacheBox.keys) {
      if (key.endsWith('\$$targetLanguage') ||
          key.contains('\$$targetLanguage') ||
          key.contains('\$${sourceLanguage}\$')) {
        keysToDelete.add(key as String);
      }
    }

    for (final key in keysToDelete) {
      final value = _cacheBox.get(key);
      final bytes = value?.length ?? 0;
      await _cacheBox.delete(key);
      await _updateMetadata(key, bytes, added: false);
      _lruCache._remove(key);
    }

    await _updateAccessOrder();
    debugPrint('[EnhancedCache] Cleared ${keysToDelete.length} entries for $sourceLanguage->$targetLanguage');
  }

  /// Preload common phrases for a target language.
  Future<void> preloadCommonPhrases(
    String targetLanguage, {
    Map<String, String>? customPhrases,
  }) async {
    final commonPhrases = customPhrases ?? _getCommonPhrases(targetLanguage);
    final sourceLanguage = 'en';

    debugPrint('[EnhancedCache] Preloading ${commonPhrases.length} common phrases for $targetLanguage');

    for (final entry in commonPhrases.entries) {
      await cacheTranslation(
        originalText: entry.key,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
        translatedText: entry.value,
      );
    }

    debugPrint('[EnhancedCache] Preloading complete');
  }

  /// Get common phrases for preloading.
  Map<String, String> _getCommonPhrases(String targetLanguage) {
    // Return common UI phrases for various languages
    switch (targetLanguage.toLowerCase()) {
      case 'es':
        return {
          'Hello': 'Hola',
          'Goodbye': 'Adiós',
          'Thank you': 'Gracias',
          'Please': 'Por favor',
          'Yes': 'Sí',
          'No': 'No',
          'Settings': 'Configuración',
          'Library': 'Biblioteca',
          'Books': 'Libros',
          'Chapter': 'Capítulo',
          'Page': 'Página',
          'Loading...': 'Cargando...',
          'Error': 'Error',
          'Success': 'Éxito',
          'Cancel': 'Cancelar',
          'Save': 'Guardar',
          'Delete': 'Eliminar',
          'Edit': 'Editar',
          'Search': 'Buscar',
          'Filter': 'Filtrar',
          'Sort': 'Ordenar',
          'Close': 'Cerrar',
          'Open': 'Abrir',
          'Previous': 'Anterior',
          'Next': 'Siguiente',
        };
      case 'fr':
        return {
          'Hello': 'Bonjour',
          'Goodbye': 'Au revoir',
          'Thank you': 'Merci',
          'Please': 'S\'il vous plaît',
          'Yes': 'Oui',
          'No': 'Non',
          'Settings': 'Paramètres',
          'Library': 'Bibliothèque',
          'Books': 'Livres',
          'Chapter': 'Chapitre',
          'Page': 'Page',
          'Loading...': 'Chargement...',
          'Error': 'Erreur',
          'Success': 'Succès',
          'Cancel': 'Annuler',
          'Save': 'Enregistrer',
          'Delete': 'Supprimer',
          'Edit': 'Modifier',
          'Search': 'Rechercher',
        };
      case 'de':
        return {
          'Hello': 'Hallo',
          'Goodbye': 'Auf Wiedersehen',
          'Thank you': 'Danke',
          'Please': 'Bitte',
          'Yes': 'Ja',
          'No': 'Nein',
          'Settings': 'Einstellungen',
          'Library': 'Bibliothek',
          'Books': 'Bücher',
          'Chapter': 'Kapitel',
          'Page': 'Seite',
          'Loading...': 'Laden...',
          'Error': 'Fehler',
          'Success': 'Erfolg',
          'Cancel': 'Abbrechen',
          'Save': 'Speichern',
          'Delete': 'Löschen',
        };
      case 'ja':
        return {
          'Hello': 'こんにちは',
          'Goodbye': 'さようなら',
          'Thank you': 'ありがとう',
          'Please': 'お願いします',
          'Yes': 'はい',
          'No': 'いいえ',
          'Settings': '設定',
          'Library': 'ライブラリ',
          'Books': '本',
          'Chapter': '章',
          'Page': 'ページ',
          'Loading...': '読み込み中...',
          'Error': 'エラー',
          'Success': '成功',
          'Cancel': 'キャンセル',
          'Save': '保存',
        };
      case 'zh':
      case 'zh-cn':
        return {
          'Hello': '你好',
          'Goodbye': '再见',
          'Thank you': '谢谢',
          'Please': '请',
          'Yes': '是',
          'No': '不',
          'Settings': '设置',
          'Library': '图书馆',
          'Books': '书',
          'Chapter': '章',
          'Page': '页',
          'Loading...': '加载中...',
          'Error': '错误',
          'Success': '成功',
          'Cancel': '取消',
          'Save': '保存',
        };
      default:
        return {
          'Hello': 'Hello',
          'Thank you': 'Thank you',
          'Settings': 'Settings',
          'Loading...': 'Loading...',
        };
    }
  }

  /// Export cache as JSON for backup/transfer.
  Future<String> exportCache() async {
    final cacheData = <String, String>{};

    for (final key in _cacheBox.keys) {
      final value = _cacheBox.get(key);
      if (value != null) {
        cacheData[key as String] = value;
      }
    }

    return jsonEncode(cacheData);
  }

  /// Import cache from JSON.
  Future<bool> importCache(String jsonData) async {
    try {
      final cacheData = jsonDecode(jsonData) as Map<String, dynamic>;

      for (final entry in cacheData.entries) {
        await _cacheBox.put(entry.key, entry.value as String);
      }

      await _metadataBox.put('entryCount', cacheData.length.toString());

      debugPrint('[EnhancedCache] Imported ${cacheData.length} entries');
      return true;
    } catch (e) {
      debugPrint('[EnhancedCache] Import error: $e');
      return false;
    }
  }

  /// Close the cache service.
  Future<void> close() async {
    await _cacheBox.close();
    await _metadataBox.close();
    debugPrint('[EnhancedCache] Cache service closed');
  }
}

/// LRU cache implementation for tracking access order.
class LRUCache {
  final LinkedHashMap<String, int> _accessMap = LinkedHashMap();
  int _counter = 0;

  void _access(String key) {
    _accessMap[key] = ++_counter;
  }

  void _remove(String key) {
    _accessMap.remove(key);
  }

  void _clear() {
    _accessMap.clear();
    _counter = 0;
  }

  List<String> _getEvictionCandidates() {
    final sorted = _accessMap.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return sorted.map((e) => e.key).toList();
  }

  List<String> _getAccessOrder() {
    final sorted = _accessMap.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return sorted.map((e) => e.key).toList();
  }
}

/// Translation result with cache status.
class TranslationResult {
  final String translation;
  final bool wasCached;

  TranslationResult(this.translation, this.wasCached);
}

/// Cache statistics.
class CacheStatistics {
  final int hits;
  final int misses;
  final double hitRate;
  final int sizeBytes;
  final int entryCount;

  CacheStatistics({
    required this.hits,
    required this.misses,
    required this.hitRate,
    required this.sizeBytes,
    required this.entryCount,
  });

  @override
  String toString() {
    return 'CacheStatistics(hits: $hits, misses: $misses, hitRate: ${(hitRate * 100).toStringAsFixed(1)}%, size: $sizeBytes bytes, entries: $entryCount)';
  }
}
