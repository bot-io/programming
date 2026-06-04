import 'package:equatable/equatable.dart';

class ChapterEntity extends Equatable {
  final String title;
  final String content;
  final int? startIndex;
  final int? endIndex;
  final int? level; // For nested TOC entries

  const ChapterEntity({
    required this.title,
    required this.content,
    this.startIndex,
    this.endIndex,
    this.level,
  });

  @override
  List<Object?> get props => [title, content, startIndex, endIndex, level];

  ChapterEntity copyWith({
    String? title,
    String? content,
    int? startIndex,
    int? endIndex,
    int? level,
  }) {
    return ChapterEntity(
      title: title ?? this.title,
      content: content ?? this.content,
      startIndex: startIndex ?? this.startIndex,
      endIndex: endIndex ?? this.endIndex,
      level: level ?? this.level,
    );
  }
}

