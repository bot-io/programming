import 'package:dual_reader/src/domain/entities/chapter_entity.dart';

/// Exception thrown when MOBI file format is not supported
class MobiFormatException implements Exception {
  final String message;
  MobiFormatException(this.message);

  @override
  String toString() => 'MOBI Format Error: $message';
}

/// Exception thrown when MOBI file is DRM-protected
class MobiDrmException implements Exception {
  final String message;
  MobiDrmException(this.message);

  @override
  String toString() => 'MOBI DRM Protection: $message';
}

/// Exception thrown when MOBI file is corrupted or invalid
class MobiParseException implements Exception {
  final String message;
  final Object? innerError;

  MobiParseException(this.message, [this.innerError]);

  @override
  String toString() => 'MOBI Parse Error: $message${innerError != null ? ' (Caused by: $innerError)' : ''}';
}

/// Entity representing a parsed MOBI book
class MobiBookEntity {
  final String title;
  final String author;
  final String? publisher;
  final String? description;
  final String? language;
  final String? isbn;
  final String? publishDate;
  final List<ChapterEntity> chapters;
  final List<int>? coverImageBytes;
  final String mimeType;

  const MobiBookEntity({
    required this.title,
    required this.author,
    this.publisher,
    this.description,
    this.language,
    this.isbn,
    this.publishDate,
    required this.chapters,
    this.coverImageBytes,
    this.mimeType = 'application/x-mobipocket-ebook',
  });

  MobiBookEntity copyWith({
    String? title,
    String? author,
    String? publisher,
    String? description,
    String? language,
    String? isbn,
    String? publishDate,
    List<ChapterEntity>? chapters,
    List<int>? coverImageBytes,
    String? mimeType,
  }) {
    return MobiBookEntity(
      title: title ?? this.title,
      author: author ?? this.author,
      publisher: publisher ?? this.publisher,
      description: description ?? this.description,
      language: language ?? this.language,
      isbn: isbn ?? this.isbn,
      publishDate: publishDate ?? this.publishDate,
      chapters: chapters ?? this.chapters,
      coverImageBytes: coverImageBytes ?? this.coverImageBytes,
      mimeType: mimeType ?? this.mimeType,
    );
  }
}

abstract class MobiParserService {
  /// Parse MOBI file bytes into a MobiBookEntity
  /// Throws [MobiDrmException] if the file is DRM-protected
  /// Throws [MobiParseException] if the file is corrupted or invalid
  /// Throws [MobiFormatException] if the file is not a valid MOBI format
  Future<MobiBookEntity> parseMobi(List<int> bytes);

  /// Extract cover image from MOBI and save to local storage
  /// Returns the local path to the cover image, or empty string if no cover
  Future<String> extractCoverImage(List<int> bytes, String bookId);

  /// Extract full text content from MOBI
  /// Converts markup to plain text while preserving paragraph structure
  Future<String> extractFullText(List<int> bytes);

  /// Parse table of contents from MOBI
  /// Returns list of chapters with titles and content
  Future<List<ChapterEntity>> parseTableOfContents(List<int> bytes);
}

