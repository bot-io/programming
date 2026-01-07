import 'package:hive/hive.dart';

part 'reading_progress.g.dart';

@HiveType(typeId: 2)
class ReadingProgress {
  @HiveField(0)
  final String bookId;

  @HiveField(1)
  final int currentPage;

  @HiveField(2)
  final int totalPages;

  @HiveField(3)
  final double progress; // 0.0 to 1.0

  @HiveField(4)
  final DateTime lastReadAt;

  @HiveField(5)
  final String? currentChapterId;

  ReadingProgress({
    required this.bookId,
    required this.currentPage,
    required this.totalPages,
    required this.progress,
    required this.lastReadAt,
    this.currentChapterId,
  });

  ReadingProgress copyWith({
    String? bookId,
    int? currentPage,
    int? totalPages,
    double? progress,
    DateTime? lastReadAt,
    String? currentChapterId,
  }) {
    return ReadingProgress(
      bookId: bookId ?? this.bookId,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      progress: progress ?? this.progress,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      currentChapterId: currentChapterId ?? this.currentChapterId,
    );
  }
}
