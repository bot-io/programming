import 'package:flutter/foundation.dart' show ChangeNotifier, kIsWeb, notifyListeners;
import '../models/book.dart';
import '../models/reading_progress.dart';
import '../services/storage_service.dart';
import '../services/ebook_parser.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';

class BookProvider with ChangeNotifier {
  final StorageService _storageService;
  final EbookParser _ebookParser;

  List<Book> _books = [];
  bool _isLoading = false;
  String? _error;

  BookProvider(this._storageService, this._ebookParser) {
    _loadBooks();
  }

  List<Book> get books => _books;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> _loadBooks() async {
    _isLoading = true;
    notifyListeners();

    try {
      _books = await _storageService.getAllBooks();
      _error = null;
    } catch (e) {
      _error = 'Failed to load books: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> importBook() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['epub', 'mobi'],
        withData: kIsWeb, // On web, we need the file data
      );

      if (result == null || result.files.isEmpty) {
        // User cancelled file picker
        return;
      }

      final file = result.files.single;
      
      if ((file.path == null || file.path!.isEmpty) && 
          (kIsWeb && (file.bytes == null || file.bytes!.isEmpty))) {
        _error = 'Unable to read file. Please try again.';
        _isLoading = false;
        notifyListeners();
        return;
      }

      String filePath;
      Uint8List? fileData;
      
      if (kIsWeb) {
        // On web, use bytes and create a virtual path
        fileData = file.bytes;
        if (fileData == null || fileData.isEmpty) {
          throw Exception('Failed to read file data on web');
        }
        filePath = file.name;
        
        // Validate file extension
        if (!filePath.toLowerCase().endsWith('.epub') && 
            !filePath.toLowerCase().endsWith('.mobi')) {
          throw Exception('Unsupported file format. Please use EPUB or MOBI files.');
        }
      } else {
        filePath = file.path!;
        if (filePath.isEmpty) {
          throw Exception('Invalid file path');
        }
      }

      await _importBookFromData(filePath, fileData);
    } catch (e) {
      String errorMessage = 'Failed to import book';
      if (e.toString().contains('Unsupported')) {
        errorMessage = e.toString().replaceAll('UnsupportedError: ', '');
      } else if (e.toString().contains('Failed to parse') || 
                 e.toString().contains('corrupted')) {
        errorMessage = 'The file appears to be corrupted or in an unsupported format.';
      } else if (e.toString().contains('empty')) {
        errorMessage = e.toString().replaceAll('Exception: ', '');
      } else {
        errorMessage = 'Failed to import book: ${e.toString().replaceAll('Exception: ', '')}';
      }
      _error = errorMessage;
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Import a book from file data (used for drag-and-drop on web)
  Future<void> importBookFromData(String fileName, Uint8List fileData) async {
    try {
      // Validate file extension
      if (!fileName.toLowerCase().endsWith('.epub') && 
          !fileName.toLowerCase().endsWith('.mobi')) {
        throw Exception('Unsupported file format. Please use EPUB or MOBI files.');
      }

      await _importBookFromData(fileName, fileData);
    } catch (e) {
      String errorMessage = 'Failed to import book';
      if (e.toString().contains('Unsupported')) {
        errorMessage = e.toString().replaceAll('UnsupportedError: ', '');
      } else if (e.toString().contains('Failed to parse') || 
                 e.toString().contains('corrupted')) {
        errorMessage = 'The file appears to be corrupted or in an unsupported format.';
      } else if (e.toString().contains('empty')) {
        errorMessage = e.toString().replaceAll('Exception: ', '');
      } else {
        errorMessage = 'Failed to import book: ${e.toString().replaceAll('Exception: ', '')}';
      }
      _error = errorMessage;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _importBookFromData(String filePath, Uint8List? fileData) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final book = await _ebookParser.parseBook(filePath, fileData);
      
      // Validate book was parsed successfully
      if (book.fullText.isEmpty) {
        throw Exception('The book appears to be empty or could not be parsed.');
      }
      
      // Save book file (with data on web)
      final savedPath = await _storageService.copyBookFile(
        filePath,
        '${book.id}.${book.format}',
        fileData: fileData,
      );
      
      final bookWithPath = book.copyWith(filePath: savedPath);
      await _storageService.saveBook(bookWithPath);
      
      await _loadBooks();
      _error = null;
    } catch (e) {
      String errorMessage = 'Failed to import book';
      if (e.toString().contains('Unsupported')) {
        errorMessage = e.toString().replaceAll('UnsupportedError: ', '');
      } else if (e.toString().contains('Failed to parse') || 
                 e.toString().contains('corrupted')) {
        errorMessage = 'The file appears to be corrupted or in an unsupported format.';
      } else if (e.toString().contains('empty')) {
        errorMessage = e.toString().replaceAll('Exception: ', '');
      } else {
        errorMessage = 'Failed to import book: ${e.toString().replaceAll('Exception: ', '')}';
      }
      _error = errorMessage;
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteBook(String bookId) async {
    try {
      final book = _books.firstWhere((b) => b.id == bookId);
      
      // Delete book file and cover
      await _storageService.deleteBookFile(book.filePath);
      if (book.coverImagePath != null) {
        await _storageService.deleteCoverImage(book.coverImagePath);
      }
      
      await _storageService.deleteBook(bookId);
      await _loadBooks();
      _error = null;
    } catch (e) {
      _error = 'Failed to delete book: $e';
      notifyListeners();
    }
  }

  Book? getBookById(String bookId) {
    try {
      return _books.firstWhere((b) => b.id == bookId);
    } catch (e) {
      return null;
    }
  }
}
