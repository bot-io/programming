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
        // Search backwards for a safe break point (space or newline)
        // limit lookback to avoid expensive searches
        int lookbackLimit = (end - start > 1000) ? end - 1000 : start;
        bool foundBreak = false;
        for (int i = end - 1; i >= lookbackLimit; i--) {
          final char = text[i];
          if (char == ' ' || char == '\n') {
            end = i + 1;
            foundBreak = true;
            break;
          }
        }
        
        // If no space/newline found, try punctuation
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
    }

    return pages;
  }
}
