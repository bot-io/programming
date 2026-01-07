import 'dart:convert';
import 'package:hive/hive.dart';
import 'chapter.dart';

part 'book.g.dart';

@HiveType(typeId: 0)
class Book {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String author;

  @HiveField(3)
  final String filePath;

  @HiveField(4)
  final String format; // 'epub' or 'mobi'

  @HiveField(5)
  final String? coverImagePath;

  @HiveField(6)
  final List<Chapter> chapters;

  @HiveField(7)
  final String fullText;

  @HiveField(8)
  final DateTime addedAt;

  @HiveField(9)
  final String? language;

  @HiveField(10)
  final int totalPages;

  @HiveField(11)
  final Map<String, String>? chapterHtml; // Map of chapter ID to HTML content

  @HiveField(12)
  final Map<String, dynamic>? metadata; // Additional metadata (publisher, ISBN, description, etc.)

  Book({
    required this.id,
    required this.title,
    required this.author,
    required this.filePath,
    required this.format,
    this.coverImagePath,
    required this.chapters,
    required this.fullText,
    required this.addedAt,
    this.language,
    this.totalPages = 0,
    this.chapterHtml,
    this.metadata,
  });

  Book copyWith({
    String? id,
    String? title,
    String? author,
    String? filePath,
    String? format,
    String? coverImagePath,
    List<Chapter>? chapters,
    String? fullText,
    DateTime? addedAt,
    String? language,
    int? totalPages,
    Map<String, String>? chapterHtml,
    Map<String, dynamic>? metadata,
  }) {
    return Book(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      filePath: filePath ?? this.filePath,
      format: format ?? this.format,
      coverImagePath: coverImagePath ?? this.coverImagePath,
      chapters: chapters ?? this.chapters,
      fullText: fullText ?? this.fullText,
      addedAt: addedAt ?? this.addedAt,
      language: language ?? this.language,
      totalPages: totalPages ?? this.totalPages,
      chapterHtml: chapterHtml ?? this.chapterHtml,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Convert book to JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'filePath': filePath,
      'format': format,
      'coverImagePath': coverImagePath,
      'chapters': chapters.map((chapter) => chapter.toJson()).toList(),
      'fullText': fullText,
      'addedAt': addedAt.toIso8601String(),
      'language': language,
      'totalPages': totalPages,
      'chapterHtml': chapterHtml,
      'metadata': metadata,
    };
  }

  /// Create book from JSON map
  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      id: json['id'] as String,
      title: json['title'] as String,
      author: json['author'] as String,
      filePath: json['filePath'] as String,
      format: json['format'] as String,
      coverImagePath: json['coverImagePath'] as String?,
      chapters: (json['chapters'] as List<dynamic>?)
              ?.map((chapterJson) => Chapter.fromJson(chapterJson as Map<String, dynamic>))
              .toList() ??
          [],
      fullText: json['fullText'] as String,
      addedAt: DateTime.parse(json['addedAt'] as String),
      language: json['language'] as String?,
      totalPages: json['totalPages'] as int? ?? 0,
      chapterHtml: json['chapterHtml'] != null
          ? Map<String, String>.from(json['chapterHtml'] as Map)
          : null,
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : null,
    );
  }

  /// Convert book to JSON string
  String toJsonString() {
    return jsonEncode(toJson());
  }

  /// Create book from JSON string
  factory Book.fromJsonString(String jsonString) {
    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return Book.fromJson(json);
    } catch (e) {
      throw FormatException('Invalid JSON string for Book: $e');
    }
  }

  /// Get reading progress reference ID (bookId for ReadingProgress lookup)
  /// This allows the Book model to reference its reading progress
  String get readingProgressId => id;
}
