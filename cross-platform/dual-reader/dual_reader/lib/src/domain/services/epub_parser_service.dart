import 'package:dual_reader/src/domain/entities/epub_book_entity.dart';
import 'package:dual_reader/src/domain/entities/chapter_entity.dart';

/// Exception thrown when EPUB is DRM-protected
class EpubDrmException implements Exception {
  final String message;
  EpubDrmException(this.message);

  @override
  String toString() => 'EPUB DRM Protection: $message';
}

/// Exception thrown when EPUB is corrupted or invalid
class EpubParseException implements Exception {
  final String message;
  final Object? innerError;

  EpubParseException(this.message, [this.innerError]);

  @override
  String toString() => 'EPUB Parse Error: $message${innerError != null ? ' (Caused by: $innerError)' : ''}';
}

abstract class EpubParserService {
  /// Parse EPUB file bytes into an EpubBook entity
  /// Throws [EpubDrmException] if the file is DRM-protected
  /// Throws [EpubParseException] if the file is corrupted or invalid
  Future<EpubBookEntity> parseEpub(List<int> bytes);

  /// Extract cover image from EPUB and save to local storage
  /// Returns the local path to the cover image, or empty string if no cover
  Future<String> extractCoverImage(List<int> bytes, String bookId);

  /// Extract full text content from all chapters
  /// Converts HTML to plain text while preserving paragraph structure
  Future<String> extractFullText(List<int> bytes);

  /// Parse table of contents with nesting support
  /// Returns list of chapters with titles and content indices
  Future<List<ChapterEntity>> parseTableOfContents(List<int> bytes);
}
