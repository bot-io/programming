import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:dual_reader/src/domain/services/pagination_service.dart';

/// Pagination configuration
class PaginationConfig {
  final int timeoutMs;
  final int progressInterval;
  final int maxCharsPerPage;
  final int lookbackChars;

  const PaginationConfig({
    this.timeoutMs = 5000, // 5 second timeout as specified
    this.progressInterval = 50, // Report progress every 50 pages
    this.maxCharsPerPage = 5000,
    this.lookbackChars = 500,
  });

  static const defaultConfig = PaginationConfig();
}

/// Result of pagination operation
class PaginationResult {
  final List<String> pages;
  final int elapsedMs;
  final bool timedOut;

  const PaginationResult({
    required this.pages,
    required this.elapsedMs,
    required this.timedOut,
  });
}

/// Service for paginating text content with smart boundary detection
///
/// Features:
/// - Binary search for optimal character count per page
/// - Sentence boundary detection (., !, ?)
/// - Word boundary fallback
/// - Paragraph break preservation
/// - Chapter title stripping (h1-h6 headings)
/// - Progress reporting
/// - Timeout protection (5 seconds)
class PaginationServiceImpl implements PaginationService {
  // Cached font metrics for performance
  final Map<String, double> _fontMetricsCache = {};

  // Progress callback
  void Function(int currentPage, int totalPages)? onProgress;

  @override
  List<String> paginateText({
    required String text,
    required BoxConstraints constraints,
    required TextStyle textStyle,
    double? lineHeight,
    EdgeInsets? padding,
  }) {
    return _paginateWithConfig(
      text: text,
      constraints: constraints,
      textStyle: textStyle,
      lineHeight: lineHeight,
      padding: padding,
      config: const PaginationConfig(),
    ).pages;
  }

  /// Paginate with progress reporting
  PaginationResult paginateWithProgress({
    required String text,
    required BoxConstraints constraints,
    required TextStyle textStyle,
    double? lineHeight,
    EdgeInsets? padding,
    PaginationConfig config = const PaginationConfig(),
    void Function(int currentPage, int totalPages)? progressCallback,
  }) {
    onProgress = progressCallback;
    final result = _paginateWithConfig(
      text: text,
      constraints: constraints,
      textStyle: textStyle,
      lineHeight: lineHeight,
      padding: padding,
      config: config,
    );
    onProgress = null;
    return result;
  }

  PaginationResult _paginateWithConfig({
    required String text,
    required BoxConstraints constraints,
    required TextStyle textStyle,
    double? lineHeight,
    EdgeInsets? padding,
    required PaginationConfig config,
  }) {
    final stopwatch = Stopwatch()..start();

    // Pre-process: Strip chapter titles and headings
    final processedText = _stripChapterTitles(text);

    if (processedText.isEmpty) {
      stopwatch.stop();
      return const PaginationResult(
        pages: [],
        elapsedMs: 0,
        timedOut: false,
      );
    }

    final List<String> pages = [];
    final double pageWidth = constraints.maxWidth - (padding?.horizontal ?? 0);
    final double pageHeight = constraints.maxHeight - (padding?.vertical ?? 0);

    int start = 0;
    bool timedOut = false;

    // Estimate total pages for progress reporting
    final estimatedPages = (processedText.length / 2000).ceil();

    while (start < processedText.length) {
      // Check timeout
      if (stopwatch.elapsedMilliseconds > config.timeoutMs) {
        debugPrint('[Pagination] Timeout at page ${pages.length}. Adding remaining text as one page.');
        debugPrint('[Pagination] Remaining text: ${processedText.length - start} characters');
        pages.add(processedText.substring(start));
        timedOut = true;
        break;
      }

      // Report progress
      if (pages.length % config.progressInterval == 0 && pages.length > 0) {
        onProgress?.call(pages.length, estimatedPages);
        debugPrint('[Pagination] Progress: Created ${pages.length} pages, at position $start/${processedText.length}');
      }

      // Binary search for optimal page break
      final pageEnd = _findPageBreak(
        text: processedText,
        start: start,
        pageWidth: pageWidth,
        pageHeight: pageHeight,
        textStyle: textStyle,
        config: config,
      );

      pages.add(processedText.substring(start, pageEnd));
      start = pageEnd;

      // Skip leading whitespace for next page
      start = _skipLeadingWhitespace(processedText, start);
    }

    // Final progress report
    onProgress?.call(pages.length, pages.length);

    stopwatch.stop();
    final elapsedMs = stopwatch.elapsedMilliseconds;

    _logPaginationStats(processedText.length, pages.length, elapsedMs, timedOut);

    return PaginationResult(
      pages: pages,
      elapsedMs: elapsedMs,
      timedOut: timedOut,
    );
  }

  /// Strip chapter titles and headings from text
  /// Removes h1-h6 headings and common chapter patterns
  String _stripChapterTitles(String text) {
    // Remove HTML heading tags
    String cleaned = text.replaceAll(
      RegExp(r'<h[1-6][^>]*>.*?</h[1-6]>', multiLine: true, caseSensitive: false),
      '',
    );

    // Remove markdown-style headings
    cleaned = cleaned.replaceAll(
      RegExp(r'^#+\s+.+$', multiLine: true),
      '',
    );

    // Remove common chapter patterns at the start of lines
    cleaned = cleaned.replaceAll(
      RegExp(r'^(Chapter|CHAPTER|Part|PART)\s+\d+.*$', multiLine: true),
      '',
    );

    // Remove "Chapter X: Title" patterns
    cleaned = cleaned.replaceAll(
      RegExp(r'^(Chapter|CHAPTER)\s+\d+:\s+.+$', multiLine: true),
      '',
    );

    // Remove Roman numeral chapters
    cleaned = cleaned.replaceAll(
      RegExp(r'^[IVXLCDM]+\.\s+.+$', multiLine: true),
      '',
    );

    // Clean up multiple consecutive newlines
    cleaned = cleaned.replaceAll(
      RegExp(r'\n\s*\n\s*\n+'),
      '\n\n',
    );

    // Trim leading whitespace
    cleaned = cleaned.replaceFirst(RegExp(r'^\s+'), '');

    return cleaned.trim();
  }

  /// Find the optimal page break position using binary search and boundary detection
  int _findPageBreak({
    required String text,
    required int start,
    required double pageWidth,
    required double pageHeight,
    required TextStyle textStyle,
    required PaginationConfig config,
  }) {
    // Binary search for maximum characters that fit
    int bestEnd = _binarySearchMaxChars(
      text: text,
      start: start,
      pageWidth: pageWidth,
      pageHeight: pageHeight,
      textStyle: textStyle,
      config: config,
    );

    // Apply smart boundary detection
    return _findBestBoundary(
      text: text,
      start: start,
      end: bestEnd,
      config: config,
    );
  }

  /// Binary search to find maximum characters that fit on a page
  int _binarySearchMaxChars({
    required String text,
    required int start,
    required double pageWidth,
    required double pageHeight,
    required TextStyle textStyle,
    required PaginationConfig config,
  }) {
    int low = start;
    int high = start + config.maxCharsPerPage;
    if (high > text.length) {
      high = text.length;
    }
    int bestEnd = start;

    while (low <= high) {
      final mid = (low + high) ~/ 2;
      if (mid <= start) {
        low = mid + 1;
        continue;
      }

      final fits = _textFitsOnPage(
        text.substring(start, mid),
        pageWidth,
        pageHeight,
        textStyle,
      );

      if (fits) {
        bestEnd = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }

    return bestEnd;
  }

  /// Check if text fits on a page using TextPainter
  bool _textFitsOnPage(
    String text,
    double pageWidth,
    double pageHeight,
    TextStyle style,
  ) {
    final painter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(text: text, style: style),
    );
    painter.layout(maxWidth: pageWidth);
    return painter.height <= pageHeight;
  }

  /// Find the best sentence/word boundary near the given end position
  int _findBestBoundary({
    required String text,
    required int start,
    required int end,
    required PaginationConfig config,
  }) {
    if (end >= text.length) {
      return text.length;
    }

    int lookbackLimit = (end - start > config.lookbackChars)
        ? end - config.lookbackChars
        : start;

    // Priority 1: Sentence endings (., !, ?)
    int sentenceEnd = _findSentenceBoundary(text, end, lookbackLimit);
    if (sentenceEnd > start) {
      return sentenceEnd;
    }

    // Priority 2: Paragraph breaks
    int paragraphEnd = _findParagraphBoundary(text, end, lookbackLimit);
    if (paragraphEnd > start) {
      return paragraphEnd;
    }

    // Priority 3: Word boundaries (space, newline, tab)
    int wordEnd = _findWordBoundary(text, end, lookbackLimit);
    if (wordEnd > start) {
      return wordEnd;
    }

    // Fallback: Mid-sentence break
    return end > start ? end : start + 1;
  }

  /// Find sentence boundary looking backward from end
  int _findSentenceBoundary(String text, int end, int lookbackLimit) {
    for (int i = end - 1; i >= lookbackLimit; i--) {
      if (i + 1 >= text.length) continue;

      final char = text[i];
      final nextChar = text[i + 1];

      // Sentence ending (. ! ?) followed by space, newline, or end
      if ((char == '.' || char == '!' || char == '?') &&
          (nextChar == ' ' || nextChar == '\n' || nextChar == '\t')) {
        // Check it's not an abbreviation
        if (!_isAbbreviation(text, i)) {
          return i + 1;
        }
      }
    }
    return -1;
  }

  /// Find paragraph boundary (double newline)
  int _findParagraphBoundary(String text, int end, int lookbackLimit) {
    for (int i = end - 1; i >= lookbackLimit; i--) {
      if (i + 2 < text.length) {
        // Check for \n\n pattern
        if (text[i] == '\n' && text[i + 1] == '\n') {
          return i;
        }
        // Also check for \n followed by spaces then \n
        if (text[i] == '\n' && text.substring(i + 1).startsWith(RegExp(r'\s*\n'))) {
          return i;
        }
      }
    }
    return -1;
  }

  /// Find word boundary (space, newline, tab)
  int _findWordBoundary(String text, int end, int lookbackLimit) {
    for (int i = end - 1; i >= lookbackLimit; i--) {
      final char = text[i];
      if (char == ' ' || char == '\n' || char == '\t') {
        return i + 1;
      }
    }
    return -1;
  }

  /// Check if a period is part of an abbreviation
  bool _isAbbreviation(String text, int periodPos) {
    // Check preceding characters for common abbreviations
    final start = periodPos - 5;
    if (start < 0) return false;

    final preceding = text.substring(start, periodPos).toLowerCase();
    final abbreviations = ['mr', 'mrs', 'ms', 'dr', 'prof', 'sr', 'jr', 'no', 'etc', 'vs', 'eg', 'ie', 'st'];

    for (final abbr in abbreviations) {
      if (preceding.endsWith(abbr)) {
        return true;
      }
    }

    return false;
  }

  /// Skip leading whitespace and paragraph breaks
  int _skipLeadingWhitespace(String text, int start) {
    int newStart = start;

    // Skip leading whitespace
    while (newStart < text.length && text[newStart].trim().isEmpty) {
      newStart++;
    }

    // If we skipped paragraph breaks, that's fine - they're between pages
    return newStart;
  }

  /// Log pagination statistics
  void _logPaginationStats(int textLength, int pageCount, int elapsedMs, bool timedOut) {
    debugPrint('[Pagination] Complete: Created $pageCount pages in ${elapsedMs}ms');
    if (pageCount > 0) {
      final avgCharsPerPage = textLength / pageCount;
      debugPrint('[Pagination] Stats: $textLength chars total, $pageCount pages, avg ${avgCharsPerPage.toStringAsFixed(0)} chars/page');
    }
    if (timedOut) {
      debugPrint('[Pagination] WARNING: Pagination timed out');
    }
  }

  /// Clear cached font metrics
  void clearCache() {
    _fontMetricsCache.clear();
  }
}
