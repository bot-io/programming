import 'package:epubx/epubx.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dual_reader/src/domain/entities/book_entity.dart';
import 'package:dual_reader/src/domain/repositories/book_repository.dart';
import 'package:dual_reader/src/domain/services/epub_parser_service.dart';
import 'package:dual_reader/src/domain/services/mobi_parser_service.dart';
import 'package:universal_io/io.dart';
import 'package:path_provider/path_provider.dart';

/// Supported ebook formats
enum EbookFormat { epub, mobi, unknown }

/// Use case for importing books (EPUB and MOBI formats)
class ImportBookUseCase {
  final BookRepository _bookRepository;
  final EpubParserService _epubParserService;
  final MobiParserService _mobiParserService;

  ImportBookUseCase(
    this._bookRepository,
    this._epubParserService,
    this._mobiParserService,
  );

  Future<BookEntity?> call({FilePickerResult? pickResult}) async {
    FilePickerResult? result = pickResult;
    if (result == null) {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['epub', 'mobi', 'azw', 'azw3', 'prc'],
        withData: true,
      );
    }

    if (result == null || result.files.isEmpty) {
      return null;
    }

    final platformFile = result.files.first;
    final fileBytes = platformFile.bytes;
    final fileName = platformFile.name;

    if (fileBytes == null) {
      if (!kIsWeb && platformFile.path != null) {
        final bytes = await File(platformFile.path!).readAsBytes();
        return await _processBook(bytes, fileName);
      } else {
        throw Exception('File data not available');
      }
    } else {
      return await _processBook(fileBytes, fileName);
    }
  }

  /// Determine the format of the ebook file
  EbookFormat _detectFormat(List<int> bytes, String fileName) {
    final fileNameLower = fileName.toLowerCase();

    // Check by file extension first
    if (fileNameLower.endsWith('.epub')) {
      return EbookFormat.epub;
    } else if (fileNameLower.endsWith('.mobi') ||
        fileNameLower.endsWith('.azw') ||
        fileNameLower.endsWith('.azw3') ||
        fileNameLower.endsWith('.prc')) {
      return EbookFormat.mobi;
    }

    // Check by magic numbers
    if (bytes.length >= 4) {
      // EPUB starts with PK (ZIP archive)
      if (bytes[0] == 0x50 && bytes[1] == 0x4B) {
        return EbookFormat.epub;
      }
      // MOBI starts with Palm DB header (usually "TPZ" or "BOOK" in first bytes)
      // Palm DB magic is typically 0x4F4B5354 (little-endian "TSKO")
      final magic = (bytes[0] & 0xFF) |
                   ((bytes[1] & 0xFF) << 8) |
                   ((bytes[2] & 0xFF) << 16) |
                   ((bytes[3] & 0xFF) << 24);

      // Common Palm DB identifiers
      if (magic == 0x4F4B5354 || // "TSKO"
          magic == 0x54424F4F || // "OOBT" (BOOK)
          magic == 0x54505A54) { // "TZPT" (TPZ)
        return EbookFormat.mobi;
      }
    }

    return EbookFormat.unknown;
  }

  Future<BookEntity?> _processBook(List<int> bytes, String fileName) async {
    final format = _detectFormat(bytes, fileName);

    debugPrint('[ImportBook] Detected format: $format for file: $fileName');

    switch (format) {
      case EbookFormat.epub:
        return await _processEpub(bytes, fileName);
      case EbookFormat.mobi:
        return await _processMobi(bytes, fileName);
      case EbookFormat.unknown:
        throw Exception('Unsupported ebook format. Please use EPUB or MOBI files.');
    }
  }

  Future<BookEntity?> _processEpub(List<int> bytes, String fileName) async {
    try {
      // Parse EPUB to get our enhanced entity
      final epubBookEntity = await _epubParserService.parseEpub(bytes);

      // Also parse with epubx to get the raw book for cover extraction
      // This is a temporary approach - ideally we'd refactor to avoid double parsing
      final rawEpubBook = await EpubReader.readBook(bytes);

      final uniqueId = const Uuid().v4();

      // Always save bytes to Hive for cross-platform retrieval
      await _bookRepository.saveBookBytes(uniqueId, bytes);

      String filePath = fileName;
      if (!kIsWeb) {
        final appDocDir = await getApplicationDocumentsDirectory();
        final booksDir = Directory('${appDocDir.path}/books');
        if (!await booksDir.exists()) {
          await booksDir.create(recursive: true);
        }
        final newFilePath = '${booksDir.path}/$uniqueId.epub';
        await File(newFilePath).writeAsBytes(bytes);
        filePath = newFilePath;
      }

      // Extract cover image
      final coverPath = await _epubParserService.extractCoverImage(
        rawEpubBook,
        uniqueId,
      );

      final book = BookEntity(
        id: uniqueId,
        title: epubBookEntity.title,
        author: epubBookEntity.author,
        coverPath: coverPath,
        filePath: filePath,
        importedDate: DateTime.now(),
        paginationStatus: PaginationStatus.notStarted.index,
        paginationProgress: 0.0,
      );

      await _bookRepository.addBook(book);
      debugPrint('[ImportBook] EPUB imported: ${book.id} - ${book.title}');

      // Log additional metadata
      if (epubBookEntity.publisher != null) {
        debugPrint('[ImportBook] Publisher: ${epubBookEntity.publisher}');
      }
      if (epubBookEntity.isbn != null) {
        debugPrint('[ImportBook] ISBN: ${epubBookEntity.isbn}');
      }
      if (epubBookEntity.chapters.isNotEmpty) {
        debugPrint('[ImportBook] Chapters: ${epubBookEntity.chapters.length}');
      }

      return book;
    } on EpubDrmException catch (e) {
      debugPrint('[ImportBook] DRM Error: $e');
      rethrow;
    } on EpubParseException catch (e) {
      debugPrint('[ImportBook] Parse Error: $e');
      rethrow;
    } catch (e) {
      debugPrint('[ImportBook] Error: $e');
      rethrow;
    }
  }

  Future<BookEntity?> _processMobi(List<int> bytes, String fileName) async {
    try {
      // Parse MOBI
      final mobiBookEntity = await _mobiParserService.parseMobi(bytes);

      final uniqueId = const Uuid().v4();

      // Always save bytes to Hive for cross-platform retrieval
      await _bookRepository.saveBookBytes(uniqueId, bytes);

      String filePath = fileName;
      if (!kIsWeb) {
        final appDocDir = await getApplicationDocumentsDirectory();
        final booksDir = Directory('${appDocDir.path}/books');
        if (!await booksDir.exists()) {
          await booksDir.create(recursive: true);
        }
        // Get the original extension
        final ext = fileName.contains('.') ? fileName.split('.').last : 'mobi';
        final newFilePath = '${booksDir.path}/$uniqueId.$ext';
        await File(newFilePath).writeAsBytes(bytes);
        filePath = newFilePath;
      }

      // Extract cover image
      final coverPath = await _mobiParserService.extractCoverImage(bytes, uniqueId);

      final book = BookEntity(
        id: uniqueId,
        title: mobiBookEntity.title,
        author: mobiBookEntity.author,
        coverPath: coverPath,
        filePath: filePath,
        importedDate: DateTime.now(),
        paginationStatus: PaginationStatus.notStarted.index,
        paginationProgress: 0.0,
      );

      await _bookRepository.addBook(book);
      debugPrint('[ImportBook] MOBI imported: ${book.id} - ${book.title}');

      // Log additional metadata
      if (mobiBookEntity.publisher != null) {
        debugPrint('[ImportBook] Publisher: ${mobiBookEntity.publisher}');
      }
      if (mobiBookEntity.isbn != null) {
        debugPrint('[ImportBook] ISBN: ${mobiBookEntity.isbn}');
      }
      if (mobiBookEntity.chapters.isNotEmpty) {
        debugPrint('[ImportBook] Chapters: ${mobiBookEntity.chapters.length}');
      }

      return book;
    } on MobiDrmException catch (e) {
      debugPrint('[ImportBook] DRM Error: $e');
      rethrow;
    } on MobiParseException catch (e) {
      debugPrint('[ImportBook] Parse Error: $e');
      rethrow;
    } on MobiFormatException catch (e) {
      debugPrint('[ImportBook] Format Error: $e');
      rethrow;
    } catch (e) {
      debugPrint('[ImportBook] Error: $e');
      rethrow;
    }
  }
}
