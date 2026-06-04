import 'package:equatable/equatable.dart';
import 'chapter_entity.dart';

class EpubBookEntity extends Equatable {
  final String title;
  final String author;
  final String coverPath;
  final List<ChapterEntity> chapters;
  final String? publisher;
  final String? description;
  final String? language;
  final String? isbn;
  final String? publishDate;
  final List<String>? tags;

  const EpubBookEntity({
    required this.title,
    required this.author,
    required this.coverPath,
    required this.chapters,
    this.publisher,
    this.description,
    this.language,
    this.isbn,
    this.publishDate,
    this.tags,
  });

  @override
  List<Object?> get props => [
        title,
        author,
        coverPath,
        chapters,
        publisher,
        description,
        language,
        isbn,
        publishDate,
        tags,
      ];

  EpubBookEntity copyWith({
    String? title,
    String? author,
    String? coverPath,
    List<ChapterEntity>? chapters,
    String? publisher,
    String? description,
    String? language,
    String? isbn,
    String? publishDate,
    List<String>? tags,
  }) {
    return EpubBookEntity(
      title: title ?? this.title,
      author: author ?? this.author,
      coverPath: coverPath ?? this.coverPath,
      chapters: chapters ?? this.chapters,
      publisher: publisher ?? this.publisher,
      description: description ?? this.description,
      language: language ?? this.language,
      isbn: isbn ?? this.isbn,
      publishDate: publishDate ?? this.publishDate,
      tags: tags ?? this.tags,
    );
  }
}

