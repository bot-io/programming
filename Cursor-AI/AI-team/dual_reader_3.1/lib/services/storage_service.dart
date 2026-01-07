import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/book.dart';
import '../models/reading_progress.dart';
import '../models/bookmark.dart';
import '../models/app_settings.dart';

/// Custom exception for storage-related errors
class StorageException implements Exception {
  final String message;
  final Object? originalError;
  
  StorageException(this.message, [this.originalError]);
  
  @override
  String toString() => 'StorageException: $message${originalError != null ? ' (Original: $originalError)' : ''}';
}

/// StorageService manages local file storage for imported books
/// Supports Android, iOS, and Web platforms with platform-specific implementations
class StorageService {
  // Hive box names
  static const String _booksBoxName = 'books';
  static const String _progressBoxName = 'reading_progress';
  static const String _bookmarksBoxName = 'bookmarks';
  static const String _settingsBoxName = 'settings';
  
  // Web storage box names
  static const String _webBookFilesBoxName = 'book_files_base64';
  static const String _webCoversBoxName = 'book_covers_base64';
  static const String _webTranslationsBoxName = 'translations_base64';
  
  // Directory names
  static const String _booksDirName = 'books';
  static const String _coversDirName = 'covers';
  static const String _translationsDirName = 'translations';
  static const String _cacheDirName = 'cache';
  
  // Hive boxes
  Box<Book>? _booksBox;
  Box<ReadingProgress>? _progressBox;
  Box<Bookmark>? _bookmarksBox;
  Box<AppSettings>? _settingsBox;
  
  // Web storage boxes
  Box<String>? _webBookFilesBox;
  Box<String>? _webCoversBox;
  Box<String>? _webTranslationsBox;
  
  // Initialization flag
  bool _isInitialized = false;
  
  // Platform-specific directories (cached)
  String? _booksDirectory;
  String? _coversDirectory;
  String? _translationsDirectory;
  String? _cacheDirectory;

  /// Initialize the storage service
  /// Must be called before using any storage methods
  Future<void> init() async {
    if (_isInitialized) {
      return;
    }
    
    try {
      // Initialize Hive
      await Hive.initFlutter();
      
      // Register adapters (if not already registered)
      _registerAdapters();
      
      // Open Hive boxes
      _booksBox = await Hive.openBox<Book>(_booksBoxName);
      _progressBox = await Hive.openBox<ReadingProgress>(_progressBoxName);
      _bookmarksBox = await Hive.openBox<Bookmark>(_bookmarksBoxName);
      _settingsBox = await Hive.openBox<AppSettings>(_settingsBoxName);
      
      // Initialize web storage boxes if on web
      if (kIsWeb) {
        _webBookFilesBox = await Hive.openBox<String>(_webBookFilesBoxName);
        _webCoversBox = await Hive.openBox<String>(_webCoversBoxName);
        _webTranslationsBox = await Hive.openBox<String>(_webTranslationsBoxName);
      } else {
        // Initialize directory structure for mobile platforms
        await _initializeDirectories();
      }
      
      // Initialize default settings if not exists
      if (_settingsBox!.isEmpty) {
        await _settingsBox!.put('default', AppSettings());
      }
      
      _isInitialized = true;
    } catch (e) {
      throw StorageException('Failed to initialize StorageService', e);
    }
  }
  
  /// Register Hive adapters
  void _registerAdapters() {
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(BookAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(ChapterAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(ReadingProgressAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(BookmarkAdapter());
    }
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(AppSettingsAdapter());
    }
  }
  
  /// Initialize directory structure for mobile platforms
  Future<void> _initializeDirectories() async {
    try {
      _booksDirectory = await getBooksDirectory();
      _coversDirectory = await getCoversDirectory();
      _translationsDirectory = await getTranslationsDirectory();
      _cacheDirectory = await getCacheDirectory();
    } catch (e) {
      throw StorageException('Failed to initialize directories', e);
    }
  }
  
  /// Ensure service is initialized
  void _ensureInitialized() {
    if (!_isInitialized) {
      throw StateError('StorageService must be initialized before use. Call init() first.');
    }
  }

  // ==================== Book Metadata Operations ====================
  
  /// Save a book to storage
  /// 
  /// [book] - Book object to save (must not be null)
  /// 
  /// Throws [ArgumentError] if book.id is empty
  /// Throws [StorageException] if save operation fails
  Future<void> saveBook(Book book) async {
    _ensureInitialized();
    
    // Validate book ID
    if (book.id.isEmpty) {
      throw ArgumentError('Book id cannot be empty');
    }
    
    try {
      await _booksBox!.put(book.id, book);
    } catch (e) {
      throw StorageException('Failed to save book: ${book.id}', e);
    }
  }

  /// Get a book by ID
  Future<Book?> getBook(String bookId) async {
    _ensureInitialized();
    try {
      return _booksBox!.get(bookId);
    } catch (e) {
      throw StorageException('Failed to get book: $bookId', e);
    }
  }

  /// Get all books
  Future<List<Book>> getAllBooks() async {
    _ensureInitialized();
    try {
      return _booksBox!.values.toList();
    } catch (e) {
      throw StorageException('Failed to get all books', e);
    }
  }

  /// Delete a book and all associated data
  Future<void> deleteBook(String bookId) async {
    _ensureInitialized();
    try {
      // Get book to delete associated files
      final book = await getBook(bookId);
      
      // Delete book metadata
      await _booksBox!.delete(bookId);
      
      // Delete associated data
      await deleteProgress(bookId);
      await deleteBookmarksForBook(bookId);
      
      // Delete book file and cover if they exist
      if (book != null) {
        await deleteBookFile(book.filePath);
        if (book.coverImagePath != null) {
          await deleteCoverImage(book.coverImagePath);
        }
      }
    } catch (e) {
      throw StorageException('Failed to delete book: $bookId', e);
    }
  }

  // ==================== Reading Progress Operations ====================
  
  /// Save reading progress
  /// 
  /// [progress] - ReadingProgress object to save (must not be null)
  /// 
  /// Throws [ArgumentError] if progress.bookId is empty
  /// Throws [StorageException] if save operation fails
  Future<void> saveProgress(ReadingProgress progress) async {
    _ensureInitialized();
    
    // Validate book ID
    if (progress.bookId.isEmpty) {
      throw ArgumentError('Progress bookId cannot be empty');
    }
    
    try {
      await _progressBox!.put(progress.bookId, progress);
    } catch (e) {
      throw StorageException('Failed to save progress for book: ${progress.bookId}', e);
    }
  }

  /// Get reading progress for a book
  Future<ReadingProgress?> getProgress(String bookId) async {
    _ensureInitialized();
    try {
      return _progressBox!.get(bookId);
    } catch (e) {
      throw StorageException('Failed to get progress for book: $bookId', e);
    }
  }

  /// Delete reading progress for a book
  Future<void> deleteProgress(String bookId) async {
    _ensureInitialized();
    try {
      await _progressBox!.delete(bookId);
    } catch (e) {
      throw StorageException('Failed to delete progress for book: $bookId', e);
    }
  }

  // ==================== Bookmark Operations ====================
  
  /// Save a bookmark
  /// 
  /// [bookmark] - Bookmark object to save (must not be null)
  /// 
  /// Throws [ArgumentError] if bookmark.id or bookmark.bookId is empty
  /// Throws [StorageException] if save operation fails
  Future<void> saveBookmark(Bookmark bookmark) async {
    _ensureInitialized();
    
    // Validate bookmark IDs
    if (bookmark.id.isEmpty) {
      throw ArgumentError('Bookmark id cannot be empty');
    }
    if (bookmark.bookId.isEmpty) {
      throw ArgumentError('Bookmark bookId cannot be empty');
    }
    
    try {
      await _bookmarksBox!.put(bookmark.id, bookmark);
    } catch (e) {
      throw StorageException('Failed to save bookmark: ${bookmark.id}', e);
    }
  }

  /// Get a bookmark by ID
  Future<Bookmark?> getBookmark(String bookmarkId) async {
    _ensureInitialized();
    try {
      return _bookmarksBox!.get(bookmarkId);
    } catch (e) {
      throw StorageException('Failed to get bookmark: $bookmarkId', e);
    }
  }

  /// Get all bookmarks for a specific book
  Future<List<Bookmark>> getBookmarksForBook(String bookId) async {
    _ensureInitialized();
    try {
      return _bookmarksBox!.values
          .where((bookmark) => bookmark.bookId == bookId)
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    } catch (e) {
      throw StorageException('Failed to get bookmarks for book: $bookId', e);
    }
  }

  /// Get all bookmarks
  Future<List<Bookmark>> getAllBookmarks() async {
    _ensureInitialized();
    try {
      return _bookmarksBox!.values.toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    } catch (e) {
      throw StorageException('Failed to get all bookmarks', e);
    }
  }

  /// Delete a bookmark
  Future<void> deleteBookmark(String bookmarkId) async {
    _ensureInitialized();
    try {
      await _bookmarksBox!.delete(bookmarkId);
    } catch (e) {
      throw StorageException('Failed to delete bookmark: $bookmarkId', e);
    }
  }

  /// Delete all bookmarks for a book
  Future<void> deleteBookmarksForBook(String bookId) async {
    _ensureInitialized();
    try {
      final bookmarks = await getBookmarksForBook(bookId);
      for (var bookmark in bookmarks) {
        await _bookmarksBox!.delete(bookmark.id);
      }
    } catch (e) {
      throw StorageException('Failed to delete bookmarks for book: $bookId', e);
    }
  }

  // ==================== Settings Operations ====================
  
  /// Save app settings
  Future<void> saveSettings(AppSettings settings) async {
    _ensureInitialized();
    try {
      await _settingsBox!.put('default', settings);
    } catch (e) {
      throw StorageException('Failed to save settings', e);
    }
  }

  /// Get app settings
  Future<AppSettings> getSettings() async {
    _ensureInitialized();
    try {
      return _settingsBox!.get('default') ?? AppSettings();
    } catch (e) {
      throw StorageException('Failed to get settings', e);
    }
  }

  // ==================== Directory Management ====================
  
  /// Get the books directory path
  /// Creates the directory if it doesn't exist
  /// Throws UnsupportedError on web
  Future<String> getBooksDirectory() async {
    if (kIsWeb) {
      throw UnsupportedError('File system access not available on web');
    }
    
    if (_booksDirectory != null) {
      return _booksDirectory!;
    }
    
    try {
      final directory = await getApplicationDocumentsDirectory();
      final booksDir = Directory(path.join(directory.path, _booksDirName));
      if (!await booksDir.exists()) {
        await booksDir.create(recursive: true);
      }
      _booksDirectory = booksDir.path;
      return _booksDirectory!;
    } catch (e) {
      throw StorageException('Failed to get books directory', e);
    }
  }

  /// Get the covers directory path
  /// Creates the directory if it doesn't exist
  /// Throws UnsupportedError on web
  Future<String> getCoversDirectory() async {
    if (kIsWeb) {
      throw UnsupportedError('File system access not available on web');
    }
    
    if (_coversDirectory != null) {
      return _coversDirectory!;
    }
    
    try {
      final directory = await getApplicationDocumentsDirectory();
      final coversDir = Directory(path.join(directory.path, _coversDirName));
      if (!await coversDir.exists()) {
        await coversDir.create(recursive: true);
      }
      _coversDirectory = coversDir.path;
      return _coversDirectory!;
    } catch (e) {
      throw StorageException('Failed to get covers directory', e);
    }
  }

  /// Get the translations directory path
  /// Creates the directory if it doesn't exist
  /// Throws UnsupportedError on web
  Future<String> getTranslationsDirectory() async {
    if (kIsWeb) {
      throw UnsupportedError('File system access not available on web');
    }
    
    if (_translationsDirectory != null) {
      return _translationsDirectory!;
    }
    
    try {
      final directory = await getApplicationDocumentsDirectory();
      final translationsDir = Directory(path.join(directory.path, _translationsDirName));
      if (!await translationsDir.exists()) {
        await translationsDir.create(recursive: true);
      }
      _translationsDirectory = translationsDir.path;
      return _translationsDirectory!;
    } catch (e) {
      throw StorageException('Failed to get translations directory', e);
    }
  }

  /// Get the cache directory path
  /// Creates the directory if it doesn't exist
  /// Throws UnsupportedError on web
  Future<String> getCacheDirectory() async {
    if (kIsWeb) {
      throw UnsupportedError('File system access not available on web');
    }
    
    if (_cacheDirectory != null) {
      return _cacheDirectory!;
    }
    
    try {
      final directory = await getTemporaryDirectory();
      final cacheDir = Directory(path.join(directory.path, _cacheDirName));
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }
      _cacheDirectory = cacheDir.path;
      return _cacheDirectory!;
    } catch (e) {
      throw StorageException('Failed to get cache directory', e);
    }
  }

  // ==================== File Operations ====================
  
  /// Save a book file to storage
  /// On mobile: copies file to books directory
  /// On web: stores file data in IndexedDB (via Hive)
  /// 
  /// [sourcePath] - Path to source file (mobile only)
  /// [fileName] - Name for the saved file (must not be empty)
  /// [fileData] - File data as bytes (required for web, optional for mobile)
  /// 
  /// Returns the path/reference to the saved file
  /// 
  /// Throws [ArgumentError] if fileName is empty or required parameters are missing
  /// Throws [StorageException] if file operations fail
  Future<String> saveBookFile({
    String? sourcePath,
    required String fileName,
    Uint8List? fileData,
  }) async {
    _ensureInitialized();
    
    // Validate fileName
    if (fileName.isEmpty) {
      throw ArgumentError('fileName cannot be empty');
    }
    
    if (kIsWeb) {
      // Web: Store in IndexedDB via Hive
      if (fileData == null) {
        throw ArgumentError('fileData is required for web platform');
      }
      
      if (fileData.isEmpty) {
        throw ArgumentError('fileData cannot be empty');
      }
      
      try {
        final base64Data = base64Encode(fileData);
        await _webBookFilesBox!.put(fileName, base64Data);
        return 'web://books/$fileName';
      } catch (e) {
        throw StorageException('Failed to save book file on web: $fileName', e);
      }
    } else {
      // Mobile: Copy file to books directory
      if (sourcePath == null || sourcePath.isEmpty) {
        throw ArgumentError('sourcePath is required for mobile platforms');
      }
      
      try {
        final booksDir = await getBooksDirectory();
        final destPath = path.join(booksDir, fileName);
        final sourceFile = File(sourcePath);
        
        if (!await sourceFile.exists()) {
          throw StorageException('Source file does not exist: $sourcePath');
        }
        
        // Check if source file is readable
        final sourceSize = await sourceFile.length();
        if (sourceSize == 0) {
          throw StorageException('Source file is empty: $sourcePath');
        }
        
        // If destination exists, delete it first
        final destFile = File(destPath);
        if (await destFile.exists()) {
          await destFile.delete();
        }
        
        await sourceFile.copy(destPath);
        return destPath;
      } catch (e) {
        if (e is StorageException) {
          rethrow;
        }
        throw StorageException('Failed to save book file: $fileName', e);
      }
    }
  }

  /// Copy a book file (alias for saveBookFile for backward compatibility)
  Future<String> copyBookFile(String sourcePath, String fileName, {Uint8List? fileData}) async {
    return saveBookFile(
      sourcePath: sourcePath,
      fileName: fileName,
      fileData: fileData,
    );
  }

  /// Read book file data
  /// Returns file data as bytes, or null if file doesn't exist
  Future<Uint8List?> readBookFile(String filePath) async {
    _ensureInitialized();
    
    if (kIsWeb && filePath.startsWith('web://books/')) {
      // Web: Read from IndexedDB
      try {
        final fileName = filePath.replaceFirst('web://books/', '');
        final base64Data = _webBookFilesBox!.get(fileName);
        if (base64Data != null) {
          return base64Decode(base64Data);
        }
        return null;
      } catch (e) {
        throw StorageException('Failed to read book file on web: $filePath', e);
      }
    } else if (!kIsWeb) {
      // Mobile: Read from file system
      try {
        final file = File(filePath);
        if (await file.exists()) {
          return await file.readAsBytes();
        }
        return null;
      } catch (e) {
        throw StorageException('Failed to read book file: $filePath', e);
      }
    }
    
    return null;
  }

  /// Get book file data (alias for readBookFile for backward compatibility)
  Future<Uint8List?> getBookFileData(String filePath) async {
    return readBookFile(filePath);
  }

  /// Delete a book file
  /// On web: removes from IndexedDB
  /// On mobile: deletes from file system
  Future<void> deleteBookFile(String filePath) async {
    _ensureInitialized();
    
    if (kIsWeb && filePath.startsWith('web://books/')) {
      // Web: Delete from IndexedDB
      try {
        final fileName = filePath.replaceFirst('web://books/', '');
        await _webBookFilesBox!.delete(fileName);
      } catch (e) {
        throw StorageException('Failed to delete book file on web: $filePath', e);
      }
    } else if (!kIsWeb) {
      // Mobile: Delete from file system
      try {
        final file = File(filePath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        throw StorageException('Failed to delete book file: $filePath', e);
      }
    }
  }

  /// Check if a book file exists
  Future<bool> bookFileExists(String filePath) async {
    _ensureInitialized();
    
    if (kIsWeb && filePath.startsWith('web://books/')) {
      final fileName = filePath.replaceFirst('web://books/', '');
      return _webBookFilesBox!.containsKey(fileName);
    } else if (!kIsWeb) {
      final file = File(filePath);
      return await file.exists();
    }
    
    return false;
  }

  // ==================== Cover Image Operations ====================
  
  /// Save a cover image
  /// On mobile: saves to covers directory
  /// On web: stores in IndexedDB
  /// 
  /// [bookId] - Unique identifier for the book (must not be empty)
  /// [imageData] - Image data as bytes (must not be empty)
  /// 
  /// Returns the path/reference to the saved cover image
  /// 
  /// Throws [ArgumentError] if bookId or imageData is empty
  /// Throws [StorageException] if file operations fail
  Future<String> saveCoverImage(String bookId, List<int> imageData) async {
    _ensureInitialized();
    
    // Validate inputs
    if (bookId.isEmpty) {
      throw ArgumentError('bookId cannot be empty');
    }
    if (imageData.isEmpty) {
      throw ArgumentError('imageData cannot be empty');
    }
    
    if (kIsWeb) {
      // Web: Store in IndexedDB
      try {
        final base64Data = base64Encode(imageData);
        await _webCoversBox!.put(bookId, base64Data);
        return 'web://covers/$bookId.jpg';
      } catch (e) {
        throw StorageException('Failed to save cover image on web: $bookId', e);
      }
    } else {
      // Mobile: Save to file system
      try {
        final coversDir = await getCoversDirectory();
        final coverPath = path.join(coversDir, '$bookId.jpg');
        final file = File(coverPath);
        await file.writeAsBytes(imageData);
        return coverPath;
      } catch (e) {
        throw StorageException('Failed to save cover image: $bookId', e);
      }
    }
  }

  /// Get cover image data
  /// Returns image data as bytes, or null if image doesn't exist
  Future<Uint8List?> getCoverImageData(String? coverImagePath) async {
    _ensureInitialized();
    
    if (coverImagePath == null) {
      return null;
    }
    
    if (kIsWeb && coverImagePath.startsWith('web://covers/')) {
      // Web: Read from IndexedDB
      try {
        final bookId = coverImagePath.replaceFirst('web://covers/', '').replaceAll('.jpg', '');
        final base64Data = _webCoversBox!.get(bookId);
        if (base64Data != null) {
          return base64Decode(base64Data);
        }
        return null;
      } catch (e) {
        throw StorageException('Failed to get cover image data on web: $coverImagePath', e);
      }
    } else if (!kIsWeb) {
      // Mobile: Read from file system
      try {
        final file = File(coverImagePath);
        if (await file.exists()) {
          return await file.readAsBytes();
        }
        return null;
      } catch (e) {
        throw StorageException('Failed to get cover image data: $coverImagePath', e);
      }
    }
    
    return null;
  }

  /// Delete a cover image
  Future<void> deleteCoverImage(String? coverImagePath) async {
    _ensureInitialized();
    
    if (coverImagePath == null) {
      return;
    }
    
    if (kIsWeb && coverImagePath.startsWith('web://covers/')) {
      // Web: Delete from IndexedDB
      try {
        final bookId = coverImagePath.replaceFirst('web://covers/', '').replaceAll('.jpg', '');
        await _webCoversBox!.delete(bookId);
      } catch (e) {
        throw StorageException('Failed to delete cover image on web: $coverImagePath', e);
      }
    } else if (!kIsWeb) {
      // Mobile: Delete from file system
      try {
        final file = File(coverImagePath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        throw StorageException('Failed to delete cover image: $coverImagePath', e);
      }
    }
  }

  // ==================== Translation Cache Operations ====================
  
  /// Save a translation cache entry
  /// On mobile: saves to translations directory
  /// On web: stores in IndexedDB
  /// 
  /// [cacheKey] - Unique cache key (must not be empty)
  /// [translation] - Translation data to cache (must not be empty)
  /// 
  /// Throws [ArgumentError] if cacheKey or translation is empty
  /// Throws [StorageException] if file operations fail
  Future<void> saveTranslationCache(String cacheKey, String translation) async {
    _ensureInitialized();
    
    // Validate inputs
    if (cacheKey.isEmpty) {
      throw ArgumentError('cacheKey cannot be empty');
    }
    if (translation.isEmpty) {
      throw ArgumentError('translation cannot be empty');
    }
    
    if (kIsWeb) {
      // Web: Store in IndexedDB
      try {
        await _webTranslationsBox!.put(cacheKey, translation);
      } catch (e) {
        throw StorageException('Failed to save translation cache on web: $cacheKey', e);
      }
    } else {
      // Mobile: Save to file system
      try {
        final translationsDir = await getTranslationsDirectory();
        final cachePath = path.join(translationsDir, '$cacheKey.json');
        final file = File(cachePath);
        await file.writeAsString(translation);
      } catch (e) {
        throw StorageException('Failed to save translation cache: $cacheKey', e);
      }
    }
  }

  /// Get a translation cache entry
  /// Returns cached translation, or null if not found
  Future<String?> getTranslationCache(String cacheKey) async {
    _ensureInitialized();
    
    if (kIsWeb) {
      // Web: Read from IndexedDB
      try {
        return _webTranslationsBox!.get(cacheKey);
      } catch (e) {
        throw StorageException('Failed to get translation cache on web: $cacheKey', e);
      }
    } else {
      // Mobile: Read from file system
      try {
        final translationsDir = await getTranslationsDirectory();
        final cachePath = path.join(translationsDir, '$cacheKey.json');
        final file = File(cachePath);
        if (await file.exists()) {
          return await file.readAsString();
        }
        return null;
      } catch (e) {
        throw StorageException('Failed to get translation cache: $cacheKey', e);
      }
    }
  }

  /// Delete a translation cache entry
  Future<void> deleteTranslationCache(String cacheKey) async {
    _ensureInitialized();
    
    if (kIsWeb) {
      // Web: Delete from IndexedDB
      try {
        await _webTranslationsBox!.delete(cacheKey);
      } catch (e) {
        throw StorageException('Failed to delete translation cache on web: $cacheKey', e);
      }
    } else {
      // Mobile: Delete from file system
      try {
        final translationsDir = await getTranslationsDirectory();
        final cachePath = path.join(translationsDir, '$cacheKey.json');
        final file = File(cachePath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        throw StorageException('Failed to delete translation cache: $cacheKey', e);
      }
    }
  }

  /// Clear all translation cache
  Future<void> clearTranslationCache() async {
    _ensureInitialized();
    
    if (kIsWeb) {
      // Web: Clear IndexedDB box
      try {
        await _webTranslationsBox!.clear();
      } catch (e) {
        throw StorageException('Failed to clear translation cache on web', e);
      }
    } else {
      // Mobile: Delete all files in translations directory
      try {
        final translationsDir = await getTranslationsDirectory();
        final dir = Directory(translationsDir);
        if (await dir.exists()) {
          await for (var entity in dir.list()) {
            if (entity is File) {
              await entity.delete();
            }
          }
        }
      } catch (e) {
        throw StorageException('Failed to clear translation cache', e);
      }
    }
  }

  // ==================== Utility Methods ====================
  
  /// Get storage statistics
  Future<Map<String, dynamic>> getStorageStats() async {
    _ensureInitialized();
    
    try {
      final stats = <String, dynamic>{
        'booksCount': _booksBox!.length,
        'progressCount': _progressBox!.length,
        'bookmarksCount': _bookmarksBox!.length,
        'platform': kIsWeb ? 'web' : 'mobile',
      };
      
      if (kIsWeb) {
        stats['webBookFilesCount'] = _webBookFilesBox!.length;
        stats['webCoversCount'] = _webCoversBox!.length;
        stats['webTranslationsCount'] = _webTranslationsBox!.length;
      }
      
      return stats;
    } catch (e) {
      throw StorageException('Failed to get storage stats', e);
    }
  }

  /// Get total storage size in bytes
  /// Returns the total size of all stored files
  Future<int> getStorageSize() async {
    _ensureInitialized();
    
    try {
      int totalSize = 0;
      
      if (kIsWeb) {
        // On web, calculate size from Hive boxes
        // Note: Base64 encoding increases size by ~33%, but we'll use the stored size
        for (var key in _webBookFilesBox!.keys) {
          final data = _webBookFilesBox!.get(key);
          if (data != null) {
            // Base64 string size (approximate original size is 3/4 of base64 size)
            totalSize += (data.length * 3) ~/ 4;
          }
        }
        
        for (var key in _webCoversBox!.keys) {
          final data = _webCoversBox!.get(key);
          if (data != null) {
            totalSize += (data.length * 3) ~/ 4;
          }
        }
        
        for (var key in _webTranslationsBox!.keys) {
          final data = _webTranslationsBox!.get(key);
          if (data != null) {
            totalSize += data.length;
          }
        }
      } else {
        // On mobile, calculate size from file system
        totalSize += await _getDirectorySize(_booksDirectory);
        totalSize += await _getDirectorySize(_coversDirectory);
        totalSize += await _getDirectorySize(_translationsDirectory);
        totalSize += await _getDirectorySize(_cacheDirectory);
      }
      
      return totalSize;
    } catch (e) {
      throw StorageException('Failed to get storage size', e);
    }
  }
  
  /// Get the size of a directory in bytes
  Future<int> _getDirectorySize(String? dirPath) async {
    if (dirPath == null) return 0;
    
    try {
      final dir = Directory(dirPath);
      if (!await dir.exists()) {
        return 0;
      }
      
      int totalSize = 0;
      await for (var entity in dir.list(recursive: true)) {
        if (entity is File) {
          try {
            totalSize += await entity.length();
          } catch (e) {
            // Ignore errors for individual files
          }
        }
      }
      
      return totalSize;
    } catch (e) {
      // Return 0 if we can't calculate size
      return 0;
    }
  }

  /// Clear all storage (use with caution!)
  Future<void> clearAllStorage() async {
    _ensureInitialized();
    
    try {
      await _booksBox!.clear();
      await _progressBox!.clear();
      await _bookmarksBox!.clear();
      
      if (kIsWeb) {
        await _webBookFilesBox!.clear();
        await _webCoversBox!.clear();
        await _webTranslationsBox!.clear();
      } else {
        // Delete all files in directories
        await _clearDirectory(_booksDirectory);
        await _clearDirectory(_coversDirectory);
        await _clearDirectory(_translationsDirectory);
        await _clearDirectory(_cacheDirectory);
      }
    } catch (e) {
      throw StorageException('Failed to clear all storage', e);
    }
  }
  
  /// Clear a directory
  Future<void> _clearDirectory(String? dirPath) async {
    if (dirPath == null) return;
    
    try {
      final dir = Directory(dirPath);
      if (await dir.exists()) {
        await for (var entity in dir.list()) {
          if (entity is File) {
            await entity.delete();
          } else if (entity is Directory) {
            await entity.delete(recursive: true);
          }
        }
      }
    } catch (e) {
      // Ignore errors when clearing directories
    }
  }
  
  /// Dispose resources
  Future<void> dispose() async {
    try {
      await _booksBox?.close();
      await _progressBox?.close();
      await _bookmarksBox?.close();
      await _settingsBox?.close();
      await _webBookFilesBox?.close();
      await _webCoversBox?.close();
      await _webTranslationsBox?.close();
      
      _isInitialized = false;
    } catch (e) {
      // Ignore errors during disposal
    }
  }
}
