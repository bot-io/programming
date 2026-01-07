import 'dart:convert';
import 'package:hive/hive.dart';

part 'bookmark.g.dart';

@HiveType(typeId: 3)
class Bookmark {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String bookId;

  @HiveField(2)
  final int page;

  @HiveField(3)
  final String? note;

  @HiveField(4)
  final DateTime createdAt;

  @HiveField(5)
  final String? chapterId;

  Bookmark({
    required this.id,
    required this.bookId,
    required this.page,
    this.note,
    required this.createdAt,
    this.chapterId,
  });

  Bookmark copyWith({
    String? id,
    String? bookId,
    int? page,
    String? note,
    DateTime? createdAt,
    String? chapterId,
  }) {
    return Bookmark(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      page: page ?? this.page,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      chapterId: chapterId ?? this.chapterId,
    );
  }

  /// Convert bookmark to JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bookId': bookId,
      'page': page,
      'note': note,
      'createdAt': createdAt.toIso8601String(),
      'chapterId': chapterId,
    };
  }

  /// Create bookmark from JSON map
  factory Bookmark.fromJson(Map<String, dynamic> json) {
    try {
      return Bookmark(
        id: json['id'] as String,
        bookId: json['bookId'] as String,
        page: json['page'] as int,
        note: json['note'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        chapterId: json['chapterId'] as String?,
      );
    } catch (e) {
      throw FormatException(
        'Failed to create Bookmark from JSON: $e. JSON: $json',
      );
    }
  }

  /// Convert bookmark to JSON string
  String toJsonString() {
    return jsonEncode(toJson());
  }

  /// Create bookmark from JSON string
  factory Bookmark.fromJsonString(String jsonString) {
    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return Bookmark.fromJson(json);
    } catch (e) {
      throw FormatException('Invalid JSON string for Bookmark: $e');
    }
  }
}
