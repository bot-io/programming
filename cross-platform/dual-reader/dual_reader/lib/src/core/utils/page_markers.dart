import 'package:flutter/foundation.dart';

/// Utility class for managing invisible page boundary markers in translated text.
///
/// Uses Unicode Private Use Area (PUA) characters to mark page boundaries
/// that are preserved during translation but invisible to users.
class PageMarkers {
  // Private constructor to prevent instantiation
  PageMarkers._();

  // Base code points for page markers in Unicode Private Use Area (U+E000-U+F8FF)
  // We use a split approach to support up to 4095 pages:
  // - Start markers: U+E000 to U+EFFF (pages 0-3839)
  // - End markers: U+F000 to U+FEFF (pages 0-3839)
  static const int _pageMarkerStartBase = 0xE000;
  static const int _pageMarkerEndBase = 0xF000;

  // Maximum page index supported (0-3839)
  // Using 3840 pages (0xEFFF - 0xE000 = 0x0F00 = 3840)
  static const int maxPageIndex = 0x0EFF; // 3839

  /// Generates the start marker character for a given page index.
  ///
  /// Uses PUA characters U+E000 to U+EFFF for pages 0-3839.
  static String _insertPageStartMarker(int pageIndex) {
    if (pageIndex > maxPageIndex) {
      throw ArgumentError('Page index $pageIndex exceeds maximum supported index of $maxPageIndex');
    }
    final codePoint = _pageMarkerStartBase + pageIndex;
    return String.fromCharCode(codePoint);
  }

  /// Generates the end marker character for a given page index.
  ///
  /// Uses PUA characters U+F000 to U+FEFF for pages 0-3839.
  static String _insertPageEndMarker(int pageIndex) {
    if (pageIndex > maxPageIndex) {
      throw ArgumentError('Page index $pageIndex exceeds maximum supported index of $maxPageIndex');
    }
    final codePoint = _pageMarkerEndBase + pageIndex;
    return String.fromCharCode(codePoint);
  }

  /// Wraps text with invisible page boundary markers.
  ///
  /// The markers are preserved during translation and allow exact page extraction.
  /// Format: [START_MARKERpageIndex]text[END_MARKERpageIndex]
  ///
  /// Example for page 0:
  /// ```dart
  /// PageMarkers.insertMarkers("Hello world", 0)
  /// // Returns: "\ue000Hello world\uf000"
  /// ```
  static String insertMarkers(String text, int pageIndex) {
    if (pageIndex < 0) {
      throw ArgumentError('Page index cannot be negative: $pageIndex');
    }
    return '${_insertPageStartMarker(pageIndex)}$text${_insertPageEndMarker(pageIndex)}';
  }

  /// Extracts text for a specific page using the invisible markers.
  ///
  /// Finds the text between START_MARKER and END_MARKER for the given page.
  /// Returns empty string if markers are not found.
  ///
  /// Example:
  /// ```dart
  /// final marked = "\ue000Hello\uf000\n\ue001World\uf001";
  /// PageMarkers.extractPage(marked, 0); // Returns "Hello"
  /// PageMarkers.extractPage(marked, 1); // Returns "World"
  /// ```
  static String extractPage(String markedText, int pageIndex) {
    if (pageIndex < 0) {
      throw ArgumentError('Page index cannot be negative: $pageIndex');
    }
    if (pageIndex > maxPageIndex) {
      throw ArgumentError('Page index $pageIndex exceeds maximum supported index of $maxPageIndex');
    }

    final startMarker = _insertPageStartMarker(pageIndex);
    final endMarker = _insertPageEndMarker(pageIndex);

    final startIndex = markedText.indexOf(startMarker);
    if (startIndex == -1) {
      debugPrint('[PageMarkers] Start marker not found for page $pageIndex');
      return '';
    }

    // Start after the start marker (single character)
    final contentStart = startIndex + 1;
    final endIndex = markedText.indexOf(endMarker, contentStart);

    if (endIndex == -1) {
      debugPrint('[PageMarkers] End marker not found for page $pageIndex');
      // Return everything after start marker if end marker is missing
      return markedText.substring(contentStart);
    }

    return markedText.substring(contentStart, endIndex);
  }

  /// Removes all page boundary markers from text.
  ///
  /// Use this before displaying text to users to hide the markers.
  /// Removes all PUA characters in the range U+E000 to U+FEFF.
  ///
  /// Example:
  /// ```dart
  /// final marked = "\ue000Hello\uf000";
  /// PageMarkers.stripMarkers(marked); // Returns "Hello"
  /// ```
  static String stripMarkers(String text) {
    // Remove all PUA characters in our marker range (U+E000 to U+FEFF)
    return text.replaceAll(RegExp(r'[\uE000-\uFEFF]'), '');
  }

  /// Checks if text contains any page markers.
  ///
  /// Returns true if any marker characters are found in the text.
  static bool hasMarkers(String text) {
    return RegExp(r'[\uE000-\uFEFF]').hasMatch(text);
  }

  /// Counts the number of pages marked in the text.
  ///
  /// Counts unique page start markers found in the text.
  /// Uses regex to find all start markers efficiently.
  static int countMarkedPages(String text) {
    // Find all start markers (U+E000 to U+EEFF) in the text
    final matches = RegExp(r'[\uE000-\uEEFF]').allMatches(text);
    // Each page has exactly one start marker
    return matches.length;
  }

  /// Extracts all page indices from marked text.
  ///
  /// Returns a list of page indices that have markers in the text.
  /// Uses efficient regex-based extraction instead of iteration.
  static List<int> extractPageIndices(String text) {
    final indices = <int>[];
    final startBase = _pageMarkerStartBase;

    // Find all start marker characters and calculate their page indices
    for (final rune in text.runes) {
      if (rune >= startBase && rune <= startBase + maxPageIndex) {
        indices.add(rune - startBase);
      }
    }
    return indices..sort();
  }
}
