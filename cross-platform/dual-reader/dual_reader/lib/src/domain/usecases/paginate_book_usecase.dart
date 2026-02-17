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
/// 2. Parses EPUB and extracts text
/// 3. Paginates text using PaginationService
/// 4. Updates book entity with total pages
/// 5. Reports progress through PaginationProgressNotifier (optional)
class PaginateBookUseCase {
  final BookRepository _bookRepository;
  final EpubParserService _epubParserService;
  final PaginationService _paginationService;

  PaginateBookUseCase(
    this._bookRepository,
    this._epubParserService,
    this._paginationService,
  );

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

    try {
      // Step 1: Retrieve book bytes
      debugPrint('[PaginateBook] Retrieving book bytes...');
      onProgress?.call(0.1);
      progressNotifier?.updateProgress(book.id, 0.1);

      final bookBytes = await _bookRepository.getBookBytes(book.id);
      if (bookBytes == null) {
        throw Exception('Book bytes not found for ${book.id}');
      }

      // Step 2: Parse EPUB
      debugPrint('[PaginateBook] Parsing EPUB...');
      onProgress?.call(0.2);
      progressNotifier?.updateProgress(book.id, 0.2);

      final epubBook = await _epubParserService.parseEpub(bookBytes);

      // Step 3: Extract all text content
      debugPrint('[PaginateBook] Extracting text content...');
      onProgress?.call(0.3);
      progressNotifier?.updateProgress(book.id, 0.3);

      final fullText = _extractAllText(epubBook);
      debugPrint('[PaginateBook] Extracted ${fullText.length} characters');

      // Step 4: Setup pagination constraints
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

      // Step 5: Paginate the text
      debugPrint('[PaginateBook] Paginating text...');
      onProgress?.call(0.5);
      progressNotifier?.updateProgress(book.id, 0.5);

      final pages = _paginationService.paginateText(
        text: fullText,
        constraints: BoxConstraints.tight(pageSize),
        textStyle: textStyle,
        lineHeight: settings.lineHeight,
        padding: padding,
      );

      final totalPages = pages.length;
      debugPrint('[PaginateBook] Pagination complete: $totalPages pages');

      // Step 6: Update book with total pages
      onProgress?.call(0.9);
      progressNotifier?.updateProgress(book.id, 0.9);

      final updatedBook = book.copyWith(
        totalPages: totalPages,
        paginationStatus: PaginationStatus.completed.index,
        paginationProgress: 1.0,
      );

      await _bookRepository.updateBook(updatedBook);

      // Step 7: Mark as completed
      onProgress?.call(1.0);
      progressNotifier?.completePagination(book.id, totalPages);

      debugPrint('[PaginateBook] Successfully paginated ${book.title}: $totalPages pages');
      return totalPages;

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

  /// Extract all text content from EPUB chapters
  String _extractAllText(dynamic epubBook) {
    final buffer = StringBuffer();

    // Try to access chapters/content
    try {
      // The epubBook structure depends on the EpubParserService implementation
      // Assuming it has a Chapters list or similar
      if (epubBook.Chapters != null) {
        for (final chapter in epubBook.Chapters) {
          if (chapter.Content != null) {
            buffer.write(chapter.Content);
            buffer.write('\n\n');
          }
        }
      }
    } catch (e) {
      debugPrint('[PaginateBook] Error extracting chapters: $e');
    }

    final text = buffer.toString().trim();
    return text.isEmpty ? '' : text;
  }
}
