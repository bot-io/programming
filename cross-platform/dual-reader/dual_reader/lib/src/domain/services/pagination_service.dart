import 'package:flutter/widgets.dart';

/// Pagination configuration
class PaginationConfig {
  final int timeoutMs;
  final int progressInterval;
  final int maxCharsPerPage;
  final int lookbackChars;

  const PaginationConfig({
    this.timeoutMs = 5000, // 5 second timeout
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

abstract class PaginationService {
  /// Calculates page breaks for a given text.
  /// Returns a list of strings, where each string represents a page.
  List<String> paginateText({
    required String text,
    required BoxConstraints constraints,
    required TextStyle textStyle,
    double lineHeight,
    EdgeInsets padding,
  });

  /// Paginate with progress reporting and custom configuration.
  /// Returns detailed result including timing and timeout status.
  PaginationResult paginateWithProgress({
    required String text,
    required BoxConstraints constraints,
    required TextStyle textStyle,
    double? lineHeight,
    EdgeInsets? padding,
    PaginationConfig config,
    void Function(int currentPage, int totalPages)? progressCallback,
  });
}

