import 'package:equatable/equatable.dart';

class ChapterEntity extends Equatable {
  final String title;
  final String content;

  const ChapterEntity({
    required this.title,
    required this.content,
  });

  @override
  List<Object?> get props => [title, content];
}

