import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dual_reader/src/domain/entities/book_entity.dart';
import 'package:dual_reader/src/domain/repositories/book_repository.dart';
import 'package:dual_reader/src/domain/services/epub_parser_service.dart';
import 'package:dual_reader/src/domain/services/epub_parser_service.dart' show EpubDrmException, EpubParseException;
import 'package:universal_io/io.dart';
import 'package:path_provider/path_provider.dart';

/// Supported ebook formats
enum EbookFormat { epub, unknown }

/// Use case for importing books (EPUB format only)
class ImportBookUseCase {
  final BookRepository _bookRepository;
  final EpubParserService _epubParserService;

  ImportBookUseCase(
    this._bookRepository,
    this._epubParserService,
  );

  Future<BookEntity?> call({FilePickerResult? pickResult}) async {
    FilePickerResult? result = pickResult;
    if (result == null) {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['epub'],
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
        return await _processEpub(bytes, fileName);
      } else {
        throw Exception('File data not available');
      }
    } else {
      return await _processEpub(fileBytes, fileName);
    }
  }


  Future<BookEntity?> _processEpub(List<int> bytes, String fileName) async {
    try {
      // Parse EPUB to get our enhanced entity
      final epubBookEntity = await _epubParserService.parseEpub(bytes);

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
        bytes,
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
}
