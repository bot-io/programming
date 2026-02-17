import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';

part 'book_entity.g.dart';

enum PaginationStatus {
  notStarted,
  inProgress,
  completed,
  failed,
}

@HiveType(typeId: 0)
class BookEntity extends Equatable {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String title;
  @HiveField(2)
  final String author;
  @HiveField(3)
  final String coverPath; // Local path to the cover image
  @HiveField(4)
  final String filePath; // Local path to the ebook file
  @HiveField(5)
  final DateTime importedDate;
  @HiveField(6)
  final int currentPage;
  @HiveField(7)
  final int totalPages; // Will be determined after parsing
  @HiveField(8)
  final int? paginationStatus; // Stored as int: 0=notStarted, 1=inProgress, 2=completed, 3=failed (nullable for migration)
  @HiveField(9)
  final double? paginationProgress; // 0.0 to 1.0 (nullable for migration)

  const BookEntity({
    required this.id,
    required this.title,
    required this.author,
    required this.coverPath,
    required this.filePath,
    required this.importedDate,
    this.currentPage = 0,
    this.totalPages = 0,
    this.paginationStatus = 0, // Default to notStarted
    this.paginationProgress = 0.0,
  });

  PaginationStatus get status => PaginationStatus.values[paginationStatus ?? 0];
  bool get isPaginating => status == PaginationStatus.inProgress;
  bool get isPaginated => status == PaginationStatus.completed && totalPages > 0;
  bool get canBeOpened => isPaginated || status == PaginationStatus.notStarted;

  BookEntity copyWith({
    String? id,
    String? title,
    String? author,
    String? coverPath,
    String? filePath,
    DateTime? importedDate,
    int? currentPage,
    int? totalPages,
    int? paginationStatus,
    double? paginationProgress,
    PaginationStatus? status,
  }) {
    return BookEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      coverPath: coverPath ?? this.coverPath,
      filePath: filePath ?? this.filePath,
      importedDate: importedDate ?? this.importedDate,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      paginationStatus: paginationStatus ?? (status?.index ?? this.paginationStatus),
      paginationProgress: paginationProgress ?? this.paginationProgress,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        author,
        coverPath,
        filePath,
        importedDate,
        currentPage,
        totalPages,
        paginationStatus,
        paginationProgress,
      ];
}

