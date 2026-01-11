import 'package:flutter/foundation.dart';

/// Utility class for managing invisible page boundary markers in translated text.
///
/// Uses Unicode Private Use Area (PUA) characters to mark page boundaries
/// that are preserved during translation but invisible to users.
class PageMarkers {
  // Private constructor to prevent instantiation
  PageMarkers._();

  // Base code points for page markers in Unicode Private Use Area (U+E000-U+F8FF)
  static const int _pageMarkerStartBase = 0xE000;
  static const int _pageMarkerEndBase = 0xE100;

  // Maximum page index supported (due to PUA range limitation)
  static const int maxPageIndex = 0xFF;

  /// Generates the start marker character for a given page index.
  ///
  /// Uses PUA characters U+E000 to U+E0FF for page 0-255.
  static String _insertPageStartMarker(int pageIndex) {
    if (pageIndex > maxPageIndex) {
      throw ArgumentError('Page index $pageIndex exceeds maximum supported index of $maxPageIndex');
    }
    final codePoint = _pageMarkerStartBase + pageIndex;
    return String.fromCharCode(codePoint);
  }

  /// Generates the end marker character for a given page index.
  ///
  /// Uses PUA characters U+E100 to U+E1FF for page 0-255.
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
  /// // Returns: "\ue000Hello world\ue100"
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
  /// final marked = "\ue000Hello\ue100\n\ue001World\ue101";
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
  /// Removes all PUA characters in the range U+E000 to U+E1FF.
  ///
  /// Example:
  /// ```dart
  /// final marked = "\ue000Hello\ue100";
  /// PageMarkers.stripMarkers(marked); // Returns "Hello"
  /// ```
  static String stripMarkers(String text) {
    // Remove all PUA characters in our marker range
    return text.replaceAll(RegExp(r'[\uE000-\uE1FF]'), '');
  }

  /// Checks if text contains any page markers.
  ///
  /// Returns true if any marker characters are found in the text.
  static bool hasMarkers(String text) {
    return RegExp(r'[\uE000-\uE1FF]').hasMatch(text);
  }

  /// Counts the number of pages marked in the text.
  ///
  /// Counts unique page start markers found in the text.
  static int countMarkedPages(String text) {
    int count = 0;
    for (int i = 0; i <= maxPageIndex; i++) {
      if (text.contains(_insertPageStartMarker(i))) {
        count++;
      }
    }
    return count;
  }

  /// Extracts all page indices from marked text.
  ///
  /// Returns a list of page indices that have markers in the text.
  static List<int> extractPageIndices(String text) {
    final indices = <int>[];
    for (int i = 0; i <= maxPageIndex; i++) {
      if (text.contains(_insertPageStartMarker(i))) {
        indices.add(i);
      }
    }
    return indices;
  }
}
