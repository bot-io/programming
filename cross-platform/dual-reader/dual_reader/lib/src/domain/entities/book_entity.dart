import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';

part 'book_entity.g.dart';

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

  const BookEntity({
    required this.id,
    required this.title,
    required this.author,
    required this.coverPath,
    required this.filePath,
    required this.importedDate,
    this.currentPage = 0,
    this.totalPages = 0,
  });

  BookEntity copyWith({
    String? id,
    String? title,
    String? author,
    String? coverPath,
    String? filePath,
    DateTime? importedDate,
    int? currentPage,
    int? totalPages,
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
      ];
}

