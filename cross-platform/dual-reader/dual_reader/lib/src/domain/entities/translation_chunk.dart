import 'package:dual_reader/src/core/utils/page_markers.dart';

/// Represents a multi-page translation chunk.
///
/// Chunks contain original text from multiple pages that are translated together
/// to provide better context for the translation model. Each chunk maintains
/// metadata to map individual pages back to their translated segments.
///
/// Page synchronization is maintained using invisible Unicode markers
/// that are preserved during translation and used for exact page extraction.
class TranslationChunk {
  /// Unique identifier for this chunk: {bookId}_chunk_{startPage}_{endPage}_{lang}
  final String chunkId;

  /// ID of the book this chunk belongs to
  final String bookId;

  /// First page index in this chunk (0-based)
  final int startPageIndex;

  /// Last page index in this chunk (inclusive)
  final int endPageIndex;

  /// Combined original text from all pages in this chunk
  final String originalText;

  /// Cached translation of the original text (null if not yet translated)
  String? translatedText;

  /// Character offsets in [originalText] where each page breaks.
  /// Used to extract page-specific translations from the chunk.
  /// Length equals (endPageIndex - startPageIndex + 1).
  final List<int> pageBreakOffsets;

  /// Target language code for translation (e.g., 'es', 'fr', 'de')
  final String targetLanguage;

  /// When this chunk was last translated (null if not translated)
  DateTime? translatedAt;

  TranslationChunk({
    required this.chunkId,
    required this.bookId,
    required this.startPageIndex,
    required this.endPageIndex,
    required this.originalText,
    this.translatedText,
    required this.pageBreakOffsets,
    required this.targetLanguage,
    this.translatedAt,
  });

  /// Number of pages in this chunk
  int get pageCount => endPageIndex - startPageIndex + 1;

  /// Whether this chunk has been translated
  bool get isTranslated => translatedText != null;

  /// Extracts the original text for a specific page within this chunk.
  ///
  /// [pageIndex] must be within [startPageIndex] and [endPageIndex].
  ///
  /// Returns the original text with markers stripped for display.
  /// Markers are only used internally for page synchronization.
  String extractOriginalPage(int pageIndex) {
    if (pageIndex < startPageIndex || pageIndex > endPageIndex) {
      throw ArgumentError('Page $pageIndex is not in chunk ($startPageIndex-$endPageIndex)');
    }

    // Use marker-based extraction for exact page mapping
    String extracted = PageMarkers.extractPage(originalText, pageIndex);

    // Strip markers from the extracted text for display
    return PageMarkers.stripMarkers(extracted);
  }

  /// Extracts the translated text for a specific page within this chunk.
  ///
  /// Requires [translatedText] to be non-null.
  /// [pageIndex] must be within [startPageIndex] and [endPageIndex].
  ///
  /// Uses invisible Unicode markers to extract the exact page content,
  /// ensuring 1:1 mapping between original and translated pages.
  String extractTranslatedPage(int pageIndex) {
    if (translatedText == null) {
      throw StateError('Chunk has not been translated yet');
    }

    if (pageIndex < startPageIndex || pageIndex > endPageIndex) {
      throw ArgumentError('Page $pageIndex is not in chunk ($startPageIndex-$endPageIndex)');
    }

    // Use marker-based extraction for exact page mapping
    // Markers are preserved during translation and used for precise extraction
    String extracted = PageMarkers.extractPage(translatedText!, pageIndex);

    // Strip markers from the extracted text for display
    // Markers are only used internally for page synchronization
    return PageMarkers.stripMarkers(extracted);
  }

  /// Creates a copy of this chunk with some fields replaced.
  TranslationChunk copyWith({
    String? chunkId,
    String? bookId,
    int? startPageIndex,
    int? endPageIndex,
    String? originalText,
    String? translatedText,
    List<int>? pageBreakOffsets,
    String? targetLanguage,
    DateTime? translatedAt,
  }) {
    return TranslationChunk(
      chunkId: chunkId ?? this.chunkId,
      bookId: bookId ?? this.bookId,
      startPageIndex: startPageIndex ?? this.startPageIndex,
      endPageIndex: endPageIndex ?? this.endPageIndex,
      originalText: originalText ?? this.originalText,
      translatedText: translatedText ?? this.translatedText,
      pageBreakOffsets: pageBreakOffsets ?? this.pageBreakOffsets,
      targetLanguage: targetLanguage ?? this.targetLanguage,
      translatedAt: translatedAt ?? this.translatedAt,
    );
  }

  @override
  String toString() {
    return 'TranslationChunk(chunkId: $chunkId, bookId: $bookId, pages: $startPageIndex-$endPageIndex, isTranslated: $isTranslated)';
  }
}
