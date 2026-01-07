import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dual_reader/src/domain/entities/book_entity.dart';
import 'package:dual_reader/src/domain/repositories/book_repository.dart';
import 'package:universal_io/io.dart';

class BookRepositoryImpl implements BookRepository {
  static const String _boxName = 'books';
  static const String _bytesBoxName = 'book_bytes';

  Future<Box<BookEntity>> _openBox() async {
    if (!Hive.isBoxOpen(_boxName)) {
      return await Hive.openBox<BookEntity>(_boxName);
    } else {
      return Hive.box<BookEntity>(_boxName);
    }
  }

  Future<Box<List<int>>> _openBytesBox() async {
    if (!Hive.isBoxOpen(_bytesBoxName)) {
      return await Hive.openBox<List<int>>(_bytesBoxName);
    } else {
      return Hive.box<List<int>>(_bytesBoxName);
    }
  }

  @override
  Future<List<BookEntity>> getAllBooks() async {
    final box = await _openBox();
    return box.values.toList();
  }

  @override
  Future<BookEntity?> getBookById(String id) async {
    final box = await _openBox();
    return box.get(id);
  }

  @override
  Future<void> addBook(BookEntity book) async {
    final box = await _openBox();
    await box.put(book.id, book);
  }

  @override
  Future<void> updateBook(BookEntity book) async {
    final box = await _openBox();
    await box.put(book.id, book);
  }

  @override
  Future<void> deleteBook(String id) async {
    final box = await _openBox();
    final bookToDelete = box.get(id);
    if (bookToDelete != null) {
      if (!kIsWeb) {
        final file = File(bookToDelete.filePath);
        if (await file.exists()) {
          await file.delete();
        }
        if (bookToDelete.coverPath.isNotEmpty && !bookToDelete.coverPath.startsWith('assets/')) {
          final coverFile = File(bookToDelete.coverPath);
          if (await coverFile.exists()) {
            await coverFile.delete();
          }
        }
      }
      
      final bytesBox = await _openBytesBox();
      await bytesBox.delete(id);
      
      await box.delete(id);
    }
  }

  @override
  Future<void> saveBookBytes(String id, List<int> bytes) async {
    final box = await _openBytesBox();
    await box.put(id, bytes);
  }

  @override
  Future<List<int>?> getBookBytes(String id) async {
    if (!kIsWeb) {
      final book = await getBookById(id);
      if (book != null && book.filePath.isNotEmpty) {
        final file = File(book.filePath);
        if (await file.exists()) {
          return await file.readAsBytes();
        }
      }
    }
    
    final box = await _openBytesBox();
    return box.get(id);
  }
}
