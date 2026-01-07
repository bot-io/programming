import 'dart:convert';
import 'package:hive/hive.dart';

part 'chapter.g.dart';

/// Chapter data model representing a chapter in a book.
/// 
/// A chapter contains metadata about its position in the book,
/// including page ranges and text indices for navigation.
@HiveType(typeId: 1)
class Chapter {
  /// Unique identifier for the chapter
  @HiveField(0)
  final String id;

  /// Title of the chapter
  @HiveField(1)
  final String title;

  /// Starting character index in the book's full text
  @HiveField(2)
  final int startIndex;

  /// Ending character index in the book's full text
  @HiveField(3)
  final int endIndex;

  /// Optional reference link (e.g., HTML href) for the chapter
  @HiveField(4)
  final String? href;

  /// Starting page number for this chapter
  @HiveField(5)
  final int startPage;

  /// Ending page number for this chapter
  @HiveField(6)
  final int endPage;

  /// ID of the book this chapter belongs to
  @HiveField(7)
  final String bookId;

  /// Creates a new Chapter instance.
  /// 
  /// [id] - Unique identifier for the chapter
  /// [title] - Title of the chapter
  /// [startIndex] - Starting character index in the book's full text
  /// [endIndex] - Ending character index in the book's full text
  /// [startPage] - Starting page number for this chapter
  /// [endPage] - Ending page number for this chapter
  /// [bookId] - ID of the book this chapter belongs to
  /// [href] - Optional reference link (e.g., HTML href) for the chapter
  Chapter({
    required this.id,
    required this.title,
    required this.startIndex,
    required this.endIndex,
    this.href,
    required this.startPage,
    required this.endPage,
    required this.bookId,
  });

  Chapter copyWith({
    String? id,
    String? title,
    int? startIndex,
    int? endIndex,
    String? href,
    int? startPage,
    int? endPage,
    String? bookId,
  }) {
    return Chapter(
      id: id ?? this.id,
      title: title ?? this.title,
      startIndex: startIndex ?? this.startIndex,
      endIndex: endIndex ?? this.endIndex,
      href: href ?? this.href,
      startPage: startPage ?? this.startPage,
      endPage: endPage ?? this.endPage,
      bookId: bookId ?? this.bookId,
    );
  }

  /// Convert chapter to JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'startIndex': startIndex,
      'endIndex': endIndex,
      'href': href,
      'startPage': startPage,
      'endPage': endPage,
      'bookId': bookId,
    };
  }

  /// Create chapter from JSON map
  factory Chapter.fromJson(Map<String, dynamic> json) {
    try {
      return Chapter(
        id: json['id'] as String,
        title: json['title'] as String,
        startIndex: json['startIndex'] as int,
        endIndex: json['endIndex'] as int,
        href: json['href'] as String?,
        startPage: json['startPage'] as int,
        endPage: json['endPage'] as int,
        bookId: json['bookId'] as String,
      );
    } catch (e) {
      throw FormatException(
        'Failed to create Chapter from JSON: $e. JSON: $json',
      );
    }
  }

  /// Convert chapter to JSON string
  String toJsonString() {
    return jsonEncode(toJson());
  }

  /// Create chapter from JSON string
  factory Chapter.fromJsonString(String jsonString) {
    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return Chapter.fromJson(json);
    } catch (e) {
      throw FormatException('Invalid JSON string for Chapter: $e');
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Chapter &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          startIndex == other.startIndex &&
          endIndex == other.endIndex &&
          href == other.href &&
          startPage == other.startPage &&
          endPage == other.endPage &&
          bookId == other.bookId;

  @override
  int get hashCode =>
      id.hashCode ^
      title.hashCode ^
      startIndex.hashCode ^
      endIndex.hashCode ^
      href.hashCode ^
      startPage.hashCode ^
      endPage.hashCode ^
      bookId.hashCode;

  @override
  String toString() {
    return 'Chapter{id: $id, title: $title, startPage: $startPage, '
        'endPage: $endPage, bookId: $bookId}';
  }
}
