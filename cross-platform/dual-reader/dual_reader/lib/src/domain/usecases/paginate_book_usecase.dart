import 'package:flutter/foundation.dart';
import 'package:dual_reader/src/domain/entities/book_entity.dart';
import 'package:dual_reader/src/domain/repositories/book_repository.dart';
import 'package:dual_reader/src/domain/services/epub_parser_service.dart';
import 'package:dual_reader/src/domain/services/pagination_service.dart';
import 'package:dual_reader/src/domain/entities/settings_entity.dart';
import 'package:dual_reader/src/presentation/providers/pagination_progress_notifier.dart';
import 'package:flutter/widgets.dart';

/// Use case for paginating a book in the background
///
/// This handles the full pagination process:
/// 1. Retrieves book bytes from storage
/// 2. Detects format (EPUB) and extracts text
/// 3. Strips chapter titles from content (to avoid duplication)
/// 4. Paginates text using PaginationService
/// 5. Updates book entity with total pages
/// 6. Reports progress through PaginationProgressNotifier (optional)
class PaginateBookUseCase {
  final BookRepository _bookRepository;
  final EpubParserService _epubParserService;
  final PaginationService _paginationService;

  PaginateBookUseCase(
    this._bookRepository,
    this._epubParserService,
    this._paginationService,
  );

  /// Detect book format from file path
  EbookFormat _detectFormat(String filePath) {
    final lowerPath = filePath.toLowerCase();
    if (lowerPath.endsWith('.epub')) {
      return EbookFormat.epub;
    }
    return EbookFormat.unknown;
  }

  /// Paginate a book with the given settings
  ///
  /// Returns the total number of pages, or 0 if pagination failed
  Future<int> call(
    BookEntity book, {
    required SettingsEntity settings,
    required Size screenSize,
    PaginationProgressNotifier? progressNotifier,
    void Function(double progress)? onProgress,
  }) async {
    debugPrint('[PaginateBook] Starting pagination for book: ${book.id} (${book.title})');
    debugPrint('[PaginateBook] Screen size: ${screenSize.width.toInt()}x${screenSize.height.toInt()}');
    progressNotifier?.startPagination(book.id);

    // Update status to in progress
    final inProgressBook = book.copyWith(
      paginationStatus: PaginationStatus.inProgress.index,
      paginationProgress: 0.0,
    );
    await _bookRepository.updateBook(inProgressBook);

    try {
      // Step 1: Retrieve book bytes
      debugPrint('[PaginateBook] Retrieving book bytes...');
      _updateProgress(0.1, book.id, progressNotifier, onProgress);

      final bookBytes = await _bookRepository.getBookBytes(book.id);
      if (bookBytes == null) {
        throw Exception('Book bytes not found for ${book.id}');
      }

      // Detect format
      final format = _detectFormat(book.filePath);
      debugPrint('[PaginateBook] Detected format: $format');

      // Step 2: Extract text based on format
      debugPrint('[PaginateBook] Extracting text content...');
      _updateProgress(0.2, book.id, progressNotifier, onProgress);

      final fullText = await _extractFullText(bookBytes, format);
      debugPrint('[PaginateBook] Extracted ${fullText.length} characters');

      if (fullText.isEmpty) {
        throw Exception('No text content found in book');
      }

      // Step 3: Setup pagination constraints
      // Use the same calculations as DualReaderScreen for consistency
      const appBarHeight = 56.0; // kToolbarHeight
      const bottomNavHeight = 80.0; // Approximate height for pagination controls
      const panelLabelHeight = 40.0; // Height for "Original"/"Translated" label + spacing

      // For simplicity, assume portrait mode (panels stacked vertically)
      // Each panel gets half the available height minus panel label
      final totalAvailableHeight = screenSize.height - appBarHeight - bottomNavHeight;
      final availableHeight = (totalAvailableHeight / 2) - panelLabelHeight;

      final pageSize = Size(
        screenSize.width - (settings.margin * 2), // Screen width minus margins
        availableHeight, // Half screen height minus panel label
      );

      debugPrint('[PaginateBook] Pagination area: ${pageSize.width.toInt()}x${pageSize.height.toInt()}');

      final textStyle = TextStyle(
        fontSize: settings.fontSize,
        fontFamily: settings.fontlFamily,
        height: settings.lineHeight,
      );

      final padding = EdgeInsets.all(settings.margin);

      // Step 4: Paginate the text with progress tracking
      debugPrint('[PaginateBook] Paginating text...');
      _updateProgress(0.3, book.id, progressNotifier, onProgress);

      final result = _paginationService.paginateWithProgress(
        text: fullText,
        constraints: BoxConstraints.tight(pageSize),
        textStyle: textStyle,
        lineHeight: settings.lineHeight,
        padding: padding,
        config: const PaginationConfig(
          timeoutMs: 5000, // 5 second timeout as specified
          progressInterval: 25, // Report progress every 25 pages
        ),
        progressCallback: (current, estimated) {
          // Update progress during pagination (0.3 to 0.8)
          final paginationProgress = 0.3 + (0.5 * (current / estimated.clamp(1, double.infinity)));
          _updateProgress(
            paginationProgress.clamp(0.3, 0.8),
            book.id,
            progressNotifier,
            onProgress,
          );
        },
      );

      final totalPages = result.pages.length;

      // Check if pagination timed out
      if (result.timedOut) {
        debugPrint('[PaginateBook] WARNING: Pagination timed out after ${result.elapsedMs}ms');
        debugPrint('[PaginateBook] Generated $totalPages pages (may be incomplete)');
      } else {
        debugPrint('[PaginateBook] Pagination complete: $totalPages pages in ${result.elapsedMs}ms');
      }

      // Step 5: Update book with total pages
      _updateProgress(0.9, book.id, progressNotifier, onProgress);

      final updatedBook = book.copyWith(
        totalPages: totalPages,
        paginationStatus: result.timedOut
            ? PaginationStatus.failed.index // Mark as failed if timed out
            : PaginationStatus.completed.index,
        paginationProgress: 1.0,
      );

      await _bookRepository.updateBook(updatedBook);

      // Step 6: Mark as completed or failed
      if (result.timedOut) {
        progressNotifier?.failPagination(book.id, 'Pagination timed out after 5 seconds');
        debugPrint('[PaginateBook] Failed due to timeout: ${book.title}');
        return 0;
      } else {
        _updateProgress(1.0, book.id, progressNotifier, onProgress);
        progressNotifier?.completePagination(book.id, totalPages);
        debugPrint('[PaginateBook] Successfully paginated ${book.title}: $totalPages pages');
        return totalPages;
      }

    } on EpubDrmException catch (e) {
      debugPrint('[PaginateBook] DRM Error: $e');
      progressNotifier?.failPagination(book.id, 'DRM Protected: $e');
      final failedBook = book.copyWith(
        paginationStatus: PaginationStatus.failed.index,
      );
      await _bookRepository.updateBook(failedBook);
      return 0;
    } on EpubParseException catch (e) {
      debugPrint('[PaginateBook] Parse Error: $e');
      progressNotifier?.failPagination(book.id, e.toString());
      final failedBook = book.copyWith(
        paginationStatus: PaginationStatus.failed.index,
      );
      await _bookRepository.updateBook(failedBook);
      return 0;
    } catch (e, stackTrace) {
      debugPrint('[PaginateBook] Error paginating ${book.id}: $e');
      debugPrint('[PaginateBook] Stack trace: $stackTrace');

      // Mark as failed
      progressNotifier?.failPagination(book.id, e.toString());

      // Update book with failed status
      final failedBook = book.copyWith(
        paginationStatus: PaginationStatus.failed.index,
      );
      await _bookRepository.updateBook(failedBook);

      return 0;
    }
  }

  /// Update progress via multiple channels
  void _updateProgress(
    double progress,
    String bookId,
    PaginationProgressNotifier? progressNotifier,
    void Function(double)? onProgress,
  ) {
    onProgress?.call(progress);
    progressNotifier?.updateProgress(bookId, progress);
  }

  /// Extract all text content based on format
  Future<String> _extractFullText(List<int> bytes, EbookFormat format) async {
    switch (format) {
      case EbookFormat.epub:
        final epubBookEntity = await _epubParserService.parseEpub(bytes);
        return await _extractEpubText(bytes, epubBookEntity);

      case EbookFormat.unknown:
        // Try EPUB
        try {
          final epubBookEntity = await _epubParserService.parseEpub(bytes);
          return await _extractEpubText(bytes, epubBookEntity);
        } catch (_) {
          throw Exception('Unsupported book format (only EPUB supported)');
        }
    }
  }

  /// Extract all text content from EPUB chapters
  /// Strips chapter titles from content to avoid duplication in pagination
  Future<String> _extractEpubText(
    List<int> bytes,
    epubBookEntity,
  ) async {
    final buffer = StringBuffer();

    try {
      // Get chapters from the parsed entity
      final chapters = epubBookEntity.chapters;

      if (chapters.isEmpty) {
        debugPrint('[PaginateBook] No chapters found in entity, using raw extraction');
        // Fallback to raw extraction
        return await _epubParserService.extractFullText(bytes);
      }

      // Combine content from all chapters
      for (final chapter in chapters) {
        final content = chapter.content;

        if (content.isNotEmpty) {
          // Add chapter title as a header (optional, for structure)
          // buffer.writeln(chapter.title);
          // buffer.writeln();

          // Add the content (already stripped of its title by the parser)
          buffer.write(content);
          buffer.write('\n\n');
        }
      }

      final text = buffer.toString().trim();
      return text.isEmpty ? '' : text;
    } catch (e) {
      debugPrint('[PaginateBook] Error extracting chapters: $e');
      // Fallback to using the service method
      return await _epubParserService.extractFullText(bytes);
    }
  }
}

/// Supported ebook formats (internal use)
enum EbookFormat { epub, unknown }
