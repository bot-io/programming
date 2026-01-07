import 'package:equatable/equatable.dart';

class EpubBookEntity extends Equatable {
  final String title;
  final String author;
  final String coverPath;
  final List<ChapterEntity> chapters;

  const EpubBookEntity({
    required this.title,
    required this.author,
    required this.coverPath,
    required this.chapters,
  });

  @override
  List<Object?> get props => [title, author, coverPath, chapters];
}

