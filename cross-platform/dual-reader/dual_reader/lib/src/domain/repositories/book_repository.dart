import 'package:dual_reader/src/domain/entities/book_entity.dart';

abstract class BookRepository {
  Future<List<BookEntity>> getAllBooks();
  Future<BookEntity?> getBookById(String id);
  Future<void> addBook(BookEntity book);
  Future<void> updateBook(BookEntity book);
  Future<void> deleteBook(String id);
  Future<void> saveBookBytes(String id, List<int> bytes);
  Future<List<int>?> getBookBytes(String id);
}

