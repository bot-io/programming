import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';

part 'bookmark_entity.g.dart';

@HiveType(typeId: 3)
class BookmarkEntity extends Equatable {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String bookId;

  @HiveField(2)
  final int pageIndex;

  @HiveField(3)
  final String label;

  @HiveField(4)
  final int createdAtMillis;

  @HiveField(5)
  final String chapterTitle;

  const BookmarkEntity({
    required this.id,
    required this.bookId,
    required this.pageIndex,
    this.label = '',
    required this.createdAtMillis,
    this.chapterTitle = '',
  });

  DateTime get createdAt =>
      DateTime.fromMillisecondsSinceEpoch(createdAtMillis);

  BookmarkEntity copyWith({
    String? id,
    String? bookId,
    int? pageIndex,
    String? label,
    int? createdAtMillis,
    String? chapterTitle,
  }) {
    return BookmarkEntity(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      pageIndex: pageIndex ?? this.pageIndex,
      label: label ?? this.label,
      createdAtMillis: createdAtMillis ?? this.createdAtMillis,
      chapterTitle: chapterTitle ?? this.chapterTitle,
    );
  }

  @override
  List<Object?> get props => [
        id,
        bookId,
        pageIndex,
        label,
        createdAtMillis,
        chapterTitle,
      ];
}
