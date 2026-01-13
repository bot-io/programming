import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:dual_reader/src/domain/services/pagination_service.dart';

class PaginationServiceImpl implements PaginationService {
  @override
  List<String> paginateText({
    required String text,
    required BoxConstraints constraints,
    required TextStyle textStyle,
    double? lineHeight,
    EdgeInsets? padding,
  }) {
    if (text.isEmpty) return [];

    final List<String> pages = [];
    final double pageWidth = constraints.maxWidth - (padding?.horizontal ?? 0);
    final double pageHeight = constraints.maxHeight - (padding?.vertical ?? 0);

    int start = 0;
    final stopwatch = Stopwatch()..start();
    const maxPaginationTimeMs = 30000; // 30 seconds limit for large books

    while (start < text.length) {
      if (stopwatch.elapsedMilliseconds > maxPaginationTimeMs) {
        debugPrint('DEBUG: Pagination timeout at page ${pages.length}. Adding remaining text as one page.');
        debugPrint('DEBUG: Remaining text: ${text.length - start} characters');
        pages.add(text.substring(start));
        break;
      }

      // Log progress every 100 pages
      if (pages.length % 100 == 0 && pages.length > 0) {
        debugPrint('[Pagination] Progress: Created ${pages.length} pages, at position $start/${text.length}');
      }

      // Binary search for the maximum number of characters that fit on the page
      int low = start;
      // Start with a reasonable estimate for optimization
      // Most pages fit 1000-3000 characters, but some can fit more
      // IMPORTANT: We always use a reasonable upper bound to prevent the last page
      // from containing all remaining text when it's less than 5000 chars but still
      // too tall to fit on one page
      int high = start + 5000;
      if (high > text.length) {
        high = text.length;
      }
      int bestEnd = start;

      // Debug: Log when we're at the end with small remaining text
      final remaining = text.length - start;
      final isNearEnd = remaining < 5000 && remaining > 0;
      if (isNearEnd) {
        debugPrint('[Pagination] Near end: start=$start, remaining=$remaining chars, high=$high, text.length=${text.length}');
      }

      while (low <= high) {
        int mid = (low + high) ~/ 2;
        if (mid <= start) {
          low = mid + 1;
          continue;
        }

        final currentText = text.substring(start, mid);
        final TextPainter tempPainter = TextPainter(
          textDirection: TextDirection.ltr,
          text: TextSpan(text: currentText, style: textStyle),
        );
        tempPainter.layout(maxWidth: pageWidth);

        if (tempPainter.height <= pageHeight) {
          bestEnd = mid;
          low = mid + 1;
        } else {
          high = mid - 1;
        }

        // Debug: Log the final measurement at the end
        if (isNearEnd && mid == high) {
          debugPrint('[Pagination] Final measurement: mid=$mid, chars=${mid - start}, height=${tempPainter.height.toStringAsFixed(1)}, pageHeight=$pageHeight, fits=${tempPainter.height <= pageHeight}');
        }
      }

      // Debug logging for last few pages
      if (isNearEnd) {
        final charsOnPage = bestEnd - start;
        debugPrint('[Pagination] Result: charsOnPage=$charsOnPage, bestEnd=$bestEnd, end=${bestEnd == text.length ? "EOF" : bestEnd.toString()}');
      }

      int end = bestEnd;
      if (end < text.length) {
        // Priority 1: Break at sentence endings (., !, ?) to preserve sentence context
        // This ensures translations have complete sentences
        int lookbackLimit = (end - start > 500) ? end - 500 : start;
        bool foundBreak = false;

        // First, look for sentence-ending punctuation followed by space
        for (int i = end - 1; i >= lookbackLimit; i--) {
          if (i + 1 < text.length) {
            final char = text[i];
            final nextChar = text[i + 1];
            // Check for sentence ending (. ! ?) followed by space and capital letter
            if ((char == '.' || char == '!' || char == '?') &&
                (nextChar == ' ' || nextChar == '\n')) {
              end = i + 1;
              foundBreak = true;
              break;
            }
          }
        }

        // Priority 2: If no sentence boundary found, break at paragraph (double newline)
        if (!foundBreak) {
          for (int i = end - 1; i >= lookbackLimit; i--) {
            // Look for the pattern \n\n (two consecutive newlines)
            if (i + 2 < text.length && text.substring(i, i + 2) == '\n\n') {
              // Break after the paragraph content, before the \n\n
              end = i;
              foundBreak = true;
              break;
            }
          }
        }

        // Priority 3: Break at space/newline (word boundary)
        if (!foundBreak) {
          for (int i = end - 1; i >= lookbackLimit; i--) {
            final char = text[i];
            if (char == ' ' || char == '\n') {
              end = i + 1;
              foundBreak = true;
              break;
            }
          }
        }

        // Fallback: If nothing else works, break at punctuation mid-word
        if (!foundBreak) {
          for (int i = end - 1; i >= lookbackLimit; i--) {
            final char = text[i];
            if (char == '.' || char == '!' || char == '?') {
              end = i + 1;
              foundBreak = true;
              break;
            }
          }
        }
      }

      if (end <= start) {
        end = start + 1;
      }

      pages.add(text.substring(start, end));
      start = end;

      // Skip leading paragraph breaks for the next page to avoid empty pages
      // But only skip ONE set of paragraph breaks to avoid text loss
      while (start < text.length - 1 && text.substring(start, start + 2) == '\n\n') {
        // Preserve one paragraph break at the end of previous page if not already there
        if (pages.isNotEmpty && !pages.last.endsWith('\n\n')) {
          pages.last = pages.last + '\n\n';
        }
        start += 2;
      }
    }

    stopwatch.stop();
    debugPrint('[Pagination] Complete: Created ${pages.length} pages in ${stopwatch.elapsedMilliseconds}ms');
    if (pages.length > 0) {
      final avgCharsPerPage = text.length / pages.length;
      debugPrint('[Pagination] Stats: ${text.length} chars total, ${pages.length} pages, avg ${avgCharsPerPage.toStringAsFixed(0)} chars/page');
      debugPrint('[Pagination] Last page: ${pages.last.length} chars');
    }

    return pages;
  }
}
