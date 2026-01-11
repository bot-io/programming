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
    const maxPaginationTimeMs = 5000; // 5 seconds limit for safety

    while (start < text.length) {
      if (stopwatch.elapsedMilliseconds > maxPaginationTimeMs) {
        debugPrint('DEBUG: Pagination timeout. Adding remaining text as one page.');
        pages.add(text.substring(start));
        break;
      }

      // Binary search for the maximum number of characters that fit on the page
      int low = start;
      // Optimize: A page is very unlikely to have more than 10,000 characters
      int high = (start + 10000 < text.length) ? start + 10000 : text.length;
      int bestEnd = start;

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

      // Skip leading paragraph breaks for the next page
      while (start < text.length - 1 && text.substring(start, start + 2) == '\n\n') {
        start += 2;
      }
    }

    return pages;
  }
}
