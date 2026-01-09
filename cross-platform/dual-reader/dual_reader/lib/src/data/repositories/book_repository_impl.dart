import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dual_reader/src/domain/entities/book_entity.dart';
import 'package:dual_reader/src/domain/repositories/book_repository.dart';
import 'package:dual_reader/src/core/utils/logging_service.dart';
import 'package:universal_io/io.dart';

class BookRepositoryImpl implements BookRepository {
  static const String _boxName = 'books';
  static const String _bytesBoxName = 'book_bytes';
  static const String _componentName = 'BookRepository';

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
    try {
      final box = await _openBox();
      final books = box.values.toList();

      _componentName.logDebug('Retrieved all books - count: ${books.length}');

      return books;
    } catch (e) {
      _componentName.logError('Failed to get all books', error: e);
      rethrow;
    }
  }

  @override
  Future<BookEntity?> getBookById(String id) async {
    try {
      final box = await _openBox();
      final book = box.get(id);

      if (book != null) {
        _componentName.logDebug('Retrieved book by id - id: $id, title: "${book.title}"');
      } else {
        _componentName.logWarning('Book not found - id: $id');
      }

      return book;
    } catch (e) {
      _componentName.logError('Failed to get book by id - id: $id', error: e);
      rethrow;
    }
  }

  @override
  Future<void> addBook(BookEntity book) async {
    try {
      final box = await _openBox();
      await box.put(book.id, book);

      _componentName.logInfo('Book added - id: ${book.id}, title: "${book.title}", author: "${book.author}"');
    } catch (e) {
      _componentName.logError('Failed to add book - id: ${book.id}, title: "${book.title}"', error: e);
      rethrow;
    }
  }

  @override
  Future<void> updateBook(BookEntity book) async {
    try {
      final box = await _openBox();
      await box.put(book.id, book);

      _componentName.logInfo(
        'Book updated - id: ${book.id}, title: "${book.title}", page: ${book.currentPage}/${book.totalPages}'
      );
    } catch (e) {
      _componentName.logError('Failed to update book - id: ${book.id}', error: e);
      rethrow;
    }
  }

  @override
  Future<void> deleteBook(String id) async {
    try {
      final box = await _openBox();
      final bookToDelete = box.get(id);

      if (bookToDelete != null) {
        _componentName.logInfo('Deleting book - id: $id, title: "${bookToDelete.title}"');

        if (!kIsWeb) {
          final file = File(bookToDelete.filePath);
          if (await file.exists()) {
            await file.delete();
            _componentName.logDebug('Deleted book file - path: ${bookToDelete.filePath}');
          }

          if (bookToDelete.coverPath.isNotEmpty && !bookToDelete.coverPath.startsWith('assets/')) {
            final coverFile = File(bookToDelete.coverPath);
            if (await coverFile.exists()) {
              await coverFile.delete();
              _componentName.logDebug('Deleted cover file - path: ${bookToDelete.coverPath}');
            }
          }
        }

        final bytesBox = await _openBytesBox();
        await bytesBox.delete(id);
        _componentName.logDebug('Deleted book bytes - id: $id');

        await box.delete(id);
        _componentName.logInfo('Book deleted successfully - id: $id');
      } else {
        _componentName.logWarning('Attempted to delete non-existent book - id: $id');
      }
    } catch (e) {
      _componentName.logError('Failed to delete book - id: $id', error: e);
      rethrow;
    }
  }

  @override
  Future<void> saveBookBytes(String id, List<int> bytes) async {
    try {
      final box = await _openBytesBox();
      await box.put(id, bytes);

      _componentName.logDebug('Saved book bytes - id: $id, size: ${bytes.length} bytes (${(bytes.length / 1024).toStringAsFixed(2)} KB)');
    } catch (e) {
      _componentName.logError('Failed to save book bytes - id: $id', error: e);
      rethrow;
    }
  }

  @override
  Future<List<int>?> getBookBytes(String id) async {
    try {
      if (!kIsWeb) {
        final book = await getBookById(id);
        if (book != null && book.filePath.isNotEmpty) {
          final file = File(book.filePath);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            _componentName.logDebug('Retrieved book bytes from file - id: $id, size: ${bytes.length} bytes');
            return bytes;
          }
        }
      }

      final box = await _openBytesBox();
      final bytes = box.get(id);

      if (bytes != null) {
        _componentName.logDebug('Retrieved book bytes from cache - id: $id, size: ${bytes.length} bytes');
      } else {
        _componentName.logWarning('Book bytes not found - id: $id');
      }

      return bytes;
    } catch (e) {
      _componentName.logError('Failed to get book bytes - id: $id', error: e);
      rethrow;
    }
  }
}
