import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';

part 'reading_history_entity.g.dart';

/// Tracks when a user reads a book session.
@HiveType(typeId: 4)
class ReadingHistoryEntity extends Equatable {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String bookId;

  @HiveField(2)
  final String bookTitle;

  @HiveField(3)
  final int startPage;

  @HiveField(4)
  final int endPage;

  @HiveField(5)
  final int startedAtMillis;

  @HiveField(6)
  final int endedAtMillis;

  const ReadingHistoryEntity({
    required this.id,
    required this.bookId,
    required this.bookTitle,
    required this.startPage,
    required this.endPage,
    required this.startedAtMillis,
    required this.endedAtMillis,
  });

  DateTime get startedAt =>
      DateTime.fromMillisecondsSinceEpoch(startedAtMillis);
  DateTime get endedAt =>
      DateTime.fromMillisecondsSinceEpoch(endedAtMillis);

  Duration get duration =>
      endedAt.difference(startedAt);

  int get pagesRead => (endPage - startPage).abs();

  ReadingHistoryEntity copyWith({
    String? id,
    String? bookId,
    String? bookTitle,
    int? startPage,
    int? endPage,
    int? startedAtMillis,
    int? endedAtMillis,
  }) {
    return ReadingHistoryEntity(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      bookTitle: bookTitle ?? this.bookTitle,
      startPage: startPage ?? this.startPage,
      endPage: endPage ?? this.endPage,
      startedAtMillis: startedAtMillis ?? this.startedAtMillis,
      endedAtMillis: endedAtMillis ?? this.endedAtMillis,
    );
  }

  @override
  List<Object?> get props => [
        id,
        bookId,
        bookTitle,
        startPage,
        endPage,
        startedAtMillis,
        endedAtMillis,
      ];
}
