/// Represents a multi-page translation chunk.
///
/// Chunks contain original text from multiple pages that are translated together
/// to provide better context for the translation model. Each chunk maintains
/// metadata to map individual pages back to their translated segments.
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
  String extractOriginalPage(int pageIndex) {
    if (pageIndex < startPageIndex || pageIndex > endPageIndex) {
      throw ArgumentError('Page $pageIndex is not in chunk ($startPageIndex-$endPageIndex)');
    }

    final pageIndexInChunk = pageIndex - startPageIndex;

    // Calculate offsets, accounting for \n\n separators between pages
    final startOffset = pageIndexInChunk == 0
        ? 0
        : pageBreakOffsets[pageIndexInChunk - 1] + 2; // Add 2 for \n\n separator
    final endOffset = pageBreakOffsets[pageIndexInChunk];

    return originalText.substring(startOffset, endOffset);
  }

  /// Extracts the translated text for a specific page within this chunk.
  ///
  /// Requires [translatedText] to be non-null.
  /// [pageIndex] must be within [startPageIndex] and [endPageIndex].
  String extractTranslatedPage(int pageIndex) {
    if (translatedText == null) {
      throw StateError('Chunk has not been translated yet');
    }

    if (pageIndex < startPageIndex || pageIndex > endPageIndex) {
      throw ArgumentError('Page $pageIndex is not in chunk ($startPageIndex-$endPageIndex)');
    }

    final pageIndexInChunk = pageIndex - startPageIndex;

    // Calculate offsets, accounting for \n\n separators between pages
    final startOffset = pageIndexInChunk == 0
        ? 0
        : pageBreakOffsets[pageIndexInChunk - 1] + 2; // Add 2 for \n\n separator
    final endOffset = pageBreakOffsets[pageIndexInChunk];

    // Use paragraph-based extraction for better display parity
    return _extractByParagraphs(
      translatedText!,
      pageIndexInChunk,
      startOffset,
      endOffset,
    );
  }

  /// Extracts a segment from translated text using paragraph counting.
  ///
  /// This is the primary method for maintaining display parity.
  /// It counts paragraphs in the original segment and extracts the same
  /// number from the translation.
  String _extractByParagraphs(
    String fullTranslation,
    int pageIndexInChunk,
    int originalStartOffset,
    int originalEndOffset,
  ) {
    // Count paragraphs in the original page segment
    final originalSegment = originalText.substring(originalStartOffset, originalEndOffset);
    final originalParagraphs = originalSegment.split(RegExp(r'\n\s*\n'));
    final targetParagraphCount = originalParagraphs.length;

    // Find position of this page within the full original text
    final pagesBefore = pageIndexInChunk;

    // Count total paragraphs before this page in the chunk
    int paragraphCountBefore = 0;
    for (int i = 0; i < pagesBefore; i++) {
      final pageStart = i == 0 ? 0 : pageBreakOffsets[i - 1] + 2; // Add 2 for \n\n separator
      final pageEnd = pageBreakOffsets[i];
      final pageText = originalText.substring(pageStart, pageEnd);
      paragraphCountBefore += pageText.split(RegExp(r'\n\s*\n')).length;
    }

    // Split translation into paragraphs
    final translatedParagraphs = fullTranslation.split(RegExp(r'\n\s*\n'));

    // Extract the same number of paragraphs
    final startParagraph = paragraphCountBefore;
    final endParagraph = startParagraph + targetParagraphCount;

    if (startParagraph >= translatedParagraphs.length) {
      // Fallback: return empty if we've run out of paragraphs
      return '';
    }

    final actualEnd = endParagraph > translatedParagraphs.length
        ? translatedParagraphs.length
        : endParagraph;

    final selectedParagraphs = translatedParagraphs.sublist(startParagraph, actualEnd);
    return selectedParagraphs.join('\n\n');
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
