import 'dart:async';
import 'package:flutter/material.dart';
import 'package:simplenotes/models/note.dart';
import 'package:simplenotes/services/storage_service.dart';

/// Service class for search functionality across notes.
/// 
/// This service provides full-text search capabilities, real-time search with debouncing,
/// search result highlighting, and category filtering.
class SearchService {
  /// The storage service used for retrieving notes.
  final StorageService _storageService;

  /// Timer for debouncing search queries.
  Timer? _debounceTimer;

  /// Default debounce duration in milliseconds.
  static const int defaultDebounceMs = 300;

  /// Creates a new [SearchService] instance.
  /// 
  /// [storageService] - The storage service to use for retrieving notes.
  /// 
  /// Throws [ArgumentError] if [storageService] is null.
  SearchService(this._storageService) {
    if (_storageService == null) {
      throw ArgumentError.notNull('storageService');
    }
  }

  /// Performs a full-text search across note titles and content.
  /// 
  /// [query] - The search query string. Searches are case-insensitive.
  /// [categoryId] - Optional category ID to filter results by category.
  ///                If provided, only notes in this category are searched.
  ///                If `null`, all notes are searched.
  /// 
  /// Returns a list of notes matching the search query.
  /// 
  /// Throws [SearchServiceException] if:
  /// - Storage service is not initialized
  /// - Retrieval fails
  Future<List<Note>> search({
    required String query,
    String? categoryId,
  }) async {
    if (!_storageService.isInitialized) {
      throw SearchServiceException(
        message: 'Storage service is not initialized',
        operation: 'search',
      );
    }

    // Empty query returns all notes (or filtered by category)
    if (query.trim().isEmpty) {
      try {
        if (categoryId != null && categoryId.isNotEmpty) {
          return await _storageService.getNotesByCategory(categoryId);
        } else {
          return await _storageService.getAllNotes();
        }
      } catch (e) {
        throw SearchServiceException(
          message: 'Failed to retrieve notes: $e',
          operation: 'search',
          originalError: e,
        );
      }
    }

    try {
      // Get notes (filtered by category if provided)
      final List<Note> notes;
      if (categoryId != null && categoryId.isNotEmpty) {
        notes = await _storageService.getNotesByCategory(categoryId);
      } else {
        notes = await _storageService.getAllNotes();
      }

      // Perform case-insensitive search in title and content
      final queryLower = query.toLowerCase().trim();
      final matchingNotes = notes.where((note) {
        return note.title.toLowerCase().contains(queryLower) ||
            note.content.toLowerCase().contains(queryLower);
      }).toList();

      return matchingNotes;
    } catch (e) {
      throw SearchServiceException(
        message: 'Failed to search notes: $e',
        operation: 'search',
        originalError: e,
      );
    }
  }

  /// Performs a debounced search with a callback.
  /// 
  /// This method cancels any pending search and schedules a new one after the debounce delay.
  /// Useful for real-time search as the user types.
  /// 
  /// [query] - The search query string.
  /// [categoryId] - Optional category ID to filter results by category.
  /// [onResults] - Callback function that receives the search results.
  /// [debounceMs] - Debounce delay in milliseconds (default: [defaultDebounceMs]).
  /// 
  /// Returns a [Future] that completes when the search is executed.
  /// 
  /// Throws [SearchServiceException] if:
  /// - Storage service is not initialized
  /// - Retrieval fails
  Future<void> searchDebounced({
    required String query,
    String? categoryId,
    required Function(List<Note>) onResults,
    int debounceMs = defaultDebounceMs,
  }) async {
    // Cancel any pending search
    _debounceTimer?.cancel();

    // Schedule new search after debounce delay
    _debounceTimer = Timer(Duration(milliseconds: debounceMs), () async {
      try {
        final results = await search(query: query, categoryId: categoryId);
        onResults(results);
      } catch (e) {
        // Re-throw as SearchServiceException if not already
        if (e is! SearchServiceException) {
          throw SearchServiceException(
            message: 'Failed to perform debounced search: $e',
            operation: 'searchDebounced',
            originalError: e,
          );
        }
        rethrow;
      }
    });
  }

  /// Cancels any pending debounced search.
  /// 
  /// Call this method when you want to cancel a scheduled search operation.
  void cancelDebouncedSearch() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }

  /// Highlights search matches in text and returns a list of TextSpan objects.
  /// 
  /// This method splits the text into matching and non-matching segments,
  /// allowing UI components to style matches differently (e.g., with bold or background color).
  /// 
  /// [text] - The text to highlight matches in.
  /// [query] - The search query to highlight. Matching is case-insensitive.
  /// [matchStyle] - Optional text style for matched text (default: bold black).
  /// [normalStyle] - Optional text style for non-matched text (default: regular black).
  /// 
  /// Returns a list of [TextSpan] objects that can be used in a [Text.rich] widget.
  /// 
  /// Example:
  /// ```dart
  /// final spans = searchService.highlightMatches('Hello world', 'world');
  /// Text.rich(TextSpan(children: spans))
  /// ```
  List<TextSpan> highlightMatches(
    String text,
    String query, {
    TextStyle? matchStyle,
    TextStyle? normalStyle,
  }) {
    if (query.trim().isEmpty) {
      return [
        TextSpan(
          text: text,
          style: normalStyle ?? const TextStyle(),
        ),
      ];
    }

    // Default styles
    final defaultMatchStyle = matchStyle ??
        const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.black,
        );
    final defaultNormalStyle = normalStyle ?? const TextStyle();

    final queryLower = query.toLowerCase();
    final textLower = text.toLowerCase();
    final spans = <TextSpan>[];

    int lastIndex = 0;
    int index = textLower.indexOf(queryLower, lastIndex);

    while (index != -1) {
      // Add non-matching text before the match
      if (index > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, index),
          style: defaultNormalStyle,
        ));
      }

      // Add matching text
      spans.add(TextSpan(
        text: text.substring(index, index + query.length),
        style: defaultMatchStyle,
      ));

      lastIndex = index + query.length;
      index = textLower.indexOf(queryLower, lastIndex);
    }

    // Add remaining non-matching text
    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: defaultNormalStyle,
      ));
    }

    // If no matches found, return the entire text as normal
    if (spans.isEmpty) {
      spans.add(TextSpan(
        text: text,
        style: defaultNormalStyle,
      ));
    }

    return spans;
  }

  /// Highlights search matches in note title and returns a list of TextSpan objects.
  /// 
  /// Convenience method that calls [highlightMatches] on the note's title.
  /// 
  /// [note] - The note whose title should be highlighted.
  /// [query] - The search query to highlight.
  /// [matchStyle] - Optional text style for matched text.
  /// [normalStyle] - Optional text style for non-matched text.
  /// 
  /// Returns a list of [TextSpan] objects for the note title.
  List<TextSpan> highlightNoteTitle(
    Note note,
    String query, {
    TextStyle? matchStyle,
    TextStyle? normalStyle,
  }) {
    return highlightMatches(
      note.title,
      query,
      matchStyle: matchStyle,
      normalStyle: normalStyle,
    );
  }

  /// Highlights search matches in note content and returns a list of TextSpan objects.
  /// 
  /// Convenience method that calls [highlightMatches] on the note's content.
  /// 
  /// [note] - The note whose content should be highlighted.
  /// [query] - The search query to highlight.
  /// [matchStyle] - Optional text style for matched text.
  /// [normalStyle] - Optional text style for non-matched text.
  /// 
  /// Returns a list of [TextSpan] objects for the note content.
  List<TextSpan> highlightNoteContent(
    Note note,
    String query, {
    TextStyle? matchStyle,
    TextStyle? normalStyle,
  }) {
    return highlightMatches(
      note.content,
      query,
      matchStyle: matchStyle,
      normalStyle: normalStyle,
    );
  }

  /// Checks if a note matches the search query.
  /// 
  /// [note] - The note to check.
  /// [query] - The search query. Matching is case-insensitive.
  /// 
  /// Returns `true` if the note's title or content contains the query, `false` otherwise.
  bool noteMatches(Note note, String query) {
    if (query.trim().isEmpty) {
      return true;
    }

    final queryLower = query.toLowerCase().trim();
    return note.title.toLowerCase().contains(queryLower) ||
        note.content.toLowerCase().contains(queryLower);
  }

  /// Disposes resources used by the search service.
  /// 
  /// Call this method when the service is no longer needed to clean up timers.
  void dispose() {
    cancelDebouncedSearch();
  }
}

/// Exception class for search service-related errors.
/// 
/// This exception is thrown when search service operations fail.
class SearchServiceException implements Exception {
  /// The error message describing what went wrong.
  final String message;

  /// The operation that failed (e.g., 'search', 'searchDebounced').
  final String operation;

  /// The underlying error, if any.
  final dynamic originalError;

  /// Creates a new [SearchServiceException].
  /// 
  /// [message] - The error message.
  /// [operation] - The operation that failed.
  /// [originalError] - The underlying error, if any.
  SearchServiceException({
    required this.message,
    required this.operation,
    this.originalError,
  });

  @override
  String toString() {
    final buffer = StringBuffer('SearchServiceException: $message');
    buffer.write(' (Operation: $operation)');
    if (originalError != null) {
      buffer.write(' (Original error: $originalError)');
    }
    return buffer.toString();
  }
}
