import 'package:hive/hive.dart';

part 'note.g.dart';

@HiveType(typeId: 0)
class Note extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String content;

  @HiveField(3)
  String? categoryId;

  @HiveField(4)
  final DateTime createdAt;

  @HiveField(5)
  DateTime updatedAt;

  Note({
    required this.id,
    required this.title,
    required this.content,
    this.categoryId,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Creates a Note from a JSON map
  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      categoryId: json['categoryId'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  /// Converts the Note to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'categoryId': categoryId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Validates the note data
  /// Returns a list of validation error messages, empty if valid
  List<String> validate() {
    final errors = <String>[];

    if (id.isEmpty) {
      errors.add('Note ID cannot be empty');
    }

    if (title.trim().isEmpty) {
      errors.add('Note title cannot be empty');
    }

    if (title.length > 200) {
      errors.add('Note title cannot exceed 200 characters');
    }

    if (content.length > 100000) {
      errors.add('Note content cannot exceed 100,000 characters');
    }

    return errors;
  }

  /// Checks if the note is valid
  bool get isValid => validate().isEmpty;

  /// Creates a copy of the note with updated fields
  Note copyWith({
    String? id,
    String? title,
    String? content,
    String? categoryId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      categoryId: categoryId ?? this.categoryId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Updates the note's updatedAt timestamp
  void touch() {
    updatedAt = DateTime.now();
  }

  @override
  String toString() {
    return 'Note(id: $id, title: $title, categoryId: $categoryId, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Note &&
        other.id == id &&
        other.title == title &&
        other.content == content &&
        other.categoryId == categoryId &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        title.hashCode ^
        content.hashCode ^
        categoryId.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode;
  }
}
