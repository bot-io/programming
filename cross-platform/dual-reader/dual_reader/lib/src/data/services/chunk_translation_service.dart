import 'package:dual_reader/src/core/utils/logging_service.dart';
import 'package:dual_reader/src/data/services/chunk_cache_service.dart';
import 'package:dual_reader/src/data/services/client_side_translation_service.dart';
import 'package:dual_reader/src/domain/entities/translation_chunk.dart';
import 'package:dual_reader/src/core/utils/page_markers.dart';

/// Service for chunk-based translation.
///
/// Groups multiple pages into chunks (3000-5000 characters) for better translation context,
/// then extracts page-specific translations while maintaining display parity.
class ChunkTranslationService {
  static const String _componentName = 'ChunkTranslation';

  final ChunkCacheService _cacheService;
  final ClientSideTranslationService _translationService;

  // Chunk size configuration
  static const int _minChunkSize = 3000; // 3000 chars minimum
  static const int _maxChunkSize = 5000; // 5000 chars ideal
  static const int _hardChunkLimit = 8000; // 8000 chars hard limit

  ChunkTranslationService({
    required ChunkCacheService cacheService,
    required ClientSideTranslationService translationService,
  })  : _cacheService = cacheService,
        _translationService = translationService;

  /// Get translation for a specific page.
  ///
  /// This is the main entry point for page translation. It:
  /// 1. Checks if the page is already cached (returns immediately if so)
  /// 2. Finds or creates a chunk for this page
  /// 3. Translates the chunk if not already translated
  /// 4. Extracts the page-specific translation from the chunk
  Future<String> getPageTranslation({
    required String bookId,
    required int pageIndex,
    required String originalPageText,
    required String targetLanguage,
    required List<String> allPages,
  }) async {
    _componentName.logInfo(
      'Getting translation for page $pageIndex - book: $bookId, lang: $targetLanguage'
    );

    // Check cache first
    final cachedChunk = _cacheService.getCachedChunkForPage(bookId, pageIndex, targetLanguage);
    if (cachedChunk?.isTranslated == true) {
      try {
        final translation = cachedChunk!.extractTranslatedPage(pageIndex);
        _componentName.logDebug('Cache HIT - page $pageIndex');
        return translation;
      } catch (e) {
        _componentName.logWarning('Failed to extract from cached chunk: $e');
        // Fall through to re-translate
      }
    }

    _componentName.logDebug('Cache MISS - page $pageIndex, creating chunk');

    // Create chunk for this page
    final chunk = await _createChunkForPage(
      bookId,
      pageIndex,
      originalPageText,
      targetLanguage,
      allPages,
    );

    // Translate the chunk if needed
    if (!chunk.isTranslated) {
      _componentName.logInfo('Translating chunk ${chunk.chunkId}');
      await _translateChunk(chunk);

      // Cache the translated chunk
      await _cacheService.cacheChunk(chunk);
    }

    // Extract page translation from chunk
    return chunk.extractTranslatedPage(pageIndex);
  }

  /// Create a chunk for a specific page.
  ///
  /// Determines the optimal chunk boundaries by respecting:
  /// 1. Chapter boundaries (priority 1 - not yet implemented, needs chapter metadata)
  /// 2. Paragraph boundaries (priority 2)
  /// 3. Page boundaries (fallback)
  Future<TranslationChunk> _createChunkForPage(
    String bookId,
    int pageIndex,
    String originalPageText,
    String targetLanguage,
    List<String> allPages,
  ) async {
    // Determine chunk boundaries
    final boundaries = _calculateChunkBoundaries(pageIndex, allPages);

    final startPage = boundaries['start'] as int;
    final endPage = boundaries['end'] as int;

    // Combine original text from all pages in chunk
    final originalText = _combinePagesToChunk(startPage, endPage, allPages);

    // Calculate page break offsets
    final pageBreakOffsets = _calculatePageBreakOffsets(startPage, endPage, allPages);

    // Generate chunk ID
    final chunkId = _generateChunkId(bookId, startPage, endPage, targetLanguage);

    final chunk = TranslationChunk(
      chunkId: chunkId,
      bookId: bookId,
      startPageIndex: startPage,
      endPageIndex: endPage,
      originalText: originalText,
      pageBreakOffsets: pageBreakOffsets,
      targetLanguage: targetLanguage,
    );

    _componentName.logInfo(
      'Created chunk $chunkId - pages: $startPage-$endPage, '
      'size: ${originalText.length} chars'
    );

    return chunk;
  }

  /// Calculate optimal chunk boundaries for a page.
  ///
  /// Tries to create chunks of 3000-5000 characters while respecting
  /// paragraph boundaries.
  Map<String, int> _calculateChunkBoundaries(int pageIndex, List<String> allPages) {
    int startPage = pageIndex;
    int endPage = pageIndex;
    int currentSize = allPages[pageIndex].length;

    // Expand chunk forward
    while (endPage < allPages.length - 1) {
      final nextPageSize = allPages[endPage + 1].length;
      final newSize = currentSize + nextPageSize;

      if (newSize > _hardChunkLimit) {
        // Hard limit reached, stop expanding
        break;
      }

      if (newSize > _maxChunkSize) {
        // Check if we're at least at minimum size
        if (currentSize >= _minChunkSize) {
          // Prefer stopping at a paragraph boundary if possible
          if (_isParagraphBoundary(allPages[endPage], allPages[endPage + 1])) {
            break;
          }
        }
      }

      endPage++;
      currentSize = newSize;
    }

    // Expand chunk backward
    while (startPage > 0) {
      final prevPageSize = allPages[startPage - 1].length;
      final newSize = currentSize + prevPageSize;

      if (newSize > _hardChunkLimit) {
        break;
      }

      if (newSize > _maxChunkSize) {
        if (currentSize >= _minChunkSize) {
          if (_isParagraphBoundary(allPages[startPage - 1], allPages[startPage])) {
            break;
          }
        }
      }

      startPage--;
      currentSize = newSize;
    }

    return {'start': startPage, 'end': endPage};
  }

  /// Check if there's a paragraph boundary between two pages.
  ///
  /// A paragraph boundary exists if:
  /// - Previous page ends with complete sentence (not mid-sentence)
  /// - Next page starts with capital letter (new sentence)
  bool _isParagraphBoundary(String endPage, String startPage) {
    final trimmedEnd = endPage.trim();
    final trimmedStart = startPage.trim();

    // Check if previous page ends with sentence terminator
    final endsWell = trimmedEnd.isNotEmpty &&
        '.!?'.contains(trimmedEnd[trimmedEnd.length - 1]);

    // Check if next page starts with capital letter
    final startsWell = trimmedStart.isNotEmpty &&
        RegExp(r'[A-Z]').hasMatch(trimmedStart[0]);

    return endsWell && startsWell;
  }

  /// Combine multiple pages into a single chunk string.
  ///
  /// Wraps each page with invisible markers before combining.
  /// Markers are preserved during translation and used for exact page extraction.
  String _combinePagesToChunk(int startPage, int endPage, List<String> allPages) {
    final buffer = StringBuffer();

    for (int i = startPage; i <= endPage; i++) {
      if (i > startPage) {
        buffer.write('\n\n'); // Paragraph break between pages
      }
      // Insert invisible page markers around the page text
      final markedText = PageMarkers.insertMarkers(allPages[i], i);
      buffer.write(markedText);
    }

    return buffer.toString();
  }

  /// Calculate character offsets where each page breaks within the combined chunk.
  List<int> _calculatePageBreakOffsets(int startPage, int endPage, List<String> allPages) {
    final offsets = <int>[];
    int currentOffset = 0;

    for (int i = startPage; i <= endPage; i++) {
      currentOffset += allPages[i].length;
      offsets.add(currentOffset);

      // Add paragraph break length if not last page
      if (i < endPage) {
        currentOffset += 2; // '\n\n'
      }
    }

    return offsets;
  }

  /// Generate a unique chunk ID.
  String _generateChunkId(String bookId, int startPage, int endPage, String language) {
    return '${bookId}_chunk_${startPage}_${endPage}_$language';
  }

  /// Translate a chunk using the underlying translation service.
  Future<void> _translateChunk(TranslationChunk chunk) async {
    final stopwatch = Stopwatch()..start();

    try {
      _componentName.logInfo(
        'Translating chunk ${chunk.chunkId} - size: ${chunk.originalText.length} chars'
      );

      // Translate the entire chunk
      final translated = await _translationService.translate(
        text: chunk.originalText,
        targetLanguage: chunk.targetLanguage,
        sourceLanguage: 'en', // Assume English source
      );

      // Update chunk with translation
      chunk.translatedText = translated;
      chunk.translatedAt = DateTime.now();

      stopwatch.stop();

      _componentName.logInfo(
        'Chunk translation complete - ${chunk.chunkId}, '
        'duration: ${stopwatch.elapsed.inMilliseconds}ms'
      );
    } catch (e, stackTrace) {
      stopwatch.stop();
      _componentName.logError(
        'Chunk translation failed - ${chunk.chunkId}, '
        'duration: ${stopwatch.elapsed.inMilliseconds}ms',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Pre-translate nearby chunks for a page (background operation).
  ///
  /// When user opens page N, this translates:
  /// - Next chunk (pages N+3 to N+7 approximately)
  /// - Previous chunk (pages N-3 to N-1 approximately)
  ///
  /// This provides a smooth reading experience as translations are ready
  /// when the user navigates to nearby pages.
  Future<void> preTranslateNearbyChunks({
    required String bookId,
    required int currentPageIndex,
    required String targetLanguage,
    required List<String> allPages,
  }) async {
    _componentName.logDebug(
      'Pre-translating nearby chunks - current page: $currentPageIndex'
    );

    // Pre-translate next chunk (background, don't await)
    Future.microtask(() => _preTranslateNextChunk(
      bookId,
      currentPageIndex,
      targetLanguage,
      allPages,
    ));

    // Pre-translate previous chunk (background, don't await)
    Future.microtask(() => _preTranslatePreviousChunk(
      bookId,
      currentPageIndex,
      targetLanguage,
      allPages,
    ));
  }

  Future<void> _preTranslateNextChunk(
    String bookId,
    int currentPageIndex,
    String targetLanguage,
    List<String> allPages,
  ) async {
    try {
      // Estimate start of next chunk (approximately 3 pages ahead)
      final estimatedNextStart = currentPageIndex + 3;

      if (estimatedNextStart >= allPages.length) {
        _componentName.logDebug('Pre-translate: Already near end of book');
        return; // Already near end of book
      }

      // Check if already cached
      if (_cacheService.isPageCached(bookId, estimatedNextStart, targetLanguage)) {
        _componentName.logDebug('Pre-translate: Next chunk already cached at page $estimatedNextStart');
        return; // Already translated
      }

      _componentName.logInfo('Pre-translating next chunk starting at page $estimatedNextStart');

      // Create and translate the next chunk
      await getPageTranslation(
        bookId: bookId,
        pageIndex: estimatedNextStart,
        originalPageText: allPages[estimatedNextStart],
        targetLanguage: targetLanguage,
        allPages: allPages,
      );

      _componentName.logDebug('Pre-translated next chunk starting at page $estimatedNextStart');
    } catch (e) {
      _componentName.logWarning('Failed to pre-translate next chunk: $e');
      // Don't throw - pre-translation is best-effort
    }
  }

  Future<void> _preTranslatePreviousChunk(
    String bookId,
    int currentPageIndex,
    String targetLanguage,
    List<String> allPages,
  ) async {
    try {
      // Estimate start of previous chunk (approximately 5 pages before)
      final estimatedPrevStart = currentPageIndex - 5;

      if (estimatedPrevStart < 0) {
        _componentName.logDebug('Pre-translate: Already near start of book');
        return; // Already near start of book
      }

      // Check if already cached
      if (_cacheService.isPageCached(bookId, estimatedPrevStart, targetLanguage)) {
        _componentName.logDebug('Pre-translate: Previous chunk already cached at page $estimatedPrevStart');
        return; // Already translated
      }

      _componentName.logInfo('Pre-translating previous chunk starting at page $estimatedPrevStart');

      // Create and translate the previous chunk
      await getPageTranslation(
        bookId: bookId,
        pageIndex: estimatedPrevStart,
        originalPageText: allPages[estimatedPrevStart],
        targetLanguage: targetLanguage,
        allPages: allPages,
      );

      _componentName.logDebug('Pre-translated previous chunk starting at page $estimatedPrevStart');
    } catch (e) {
      _componentName.logWarning('Failed to pre-translate previous chunk: $e');
      // Don't throw - pre-translation is best-effort
    }
  }

  /// Clear all cached translations for a specific book and language.
  Future<void> clearBook(String bookId) async {
    await _cacheService.clearBook(bookId);
    _componentName.logInfo('Cleared all chunks for book: $bookId');
  }

  /// Clear all cached translations for a specific book and language.
  Future<void> clearBookLanguage(String bookId, String language) async {
    await _cacheService.clearBookLanguage(bookId, language);
    _componentName.logInfo('Cleared chunks - book: $bookId, language: $language');
  }

  /// Clear all cached translations.
  Future<void> clearAll() async {
    await _cacheService.clearAll();
    _componentName.logInfo('Cleared all cached chunks');
  }

  /// Get cache statistics.
  Future<Map<String, dynamic>> getStats() async {
    return await _cacheService.getStats();
  }
}
