import 'package:hive/hive.dart';

part 'category.g.dart';

@HiveType(typeId: 1)
class Category extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String? color;

  @HiveField(3)
  final DateTime createdAt;

  Category({
    required this.id,
    required this.name,
    this.color,
    required this.createdAt,
  }) {
    _validate();
  }

  void _validate() {
    if (id.isEmpty) {
      throw ArgumentError('Category id cannot be empty');
    }
    if (name.isEmpty) {
      throw ArgumentError('Category name cannot be empty');
    }
    if (name.trim().isEmpty) {
      throw ArgumentError('Category name cannot be whitespace only');
    }
    if (color != null && color!.isNotEmpty) {
      if (!_isValidColorFormat(color!)) {
        throw ArgumentError('Category color must be a valid hex color format (e.g., #RRGGBB or #AARRGGBB)');
      }
    }
  }

  bool _isValidColorFormat(String color) {
    final hexPattern = RegExp(r'^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{8})$');
    return hexPattern.hasMatch(color);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'color': color,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      name: json['name'] as String,
      color: json['color'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Category copyWith({
    String? id,
    String? name,
    String? color,
    DateTime? createdAt,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Category &&
        other.id == id &&
        other.name == name &&
        other.color == color &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        name.hashCode ^
        color.hashCode ^
        createdAt.hashCode;
  }

  @override
  String toString() {
    return 'Category(id: $id, name: $name, color: $color, createdAt: $createdAt)';
  }
}
