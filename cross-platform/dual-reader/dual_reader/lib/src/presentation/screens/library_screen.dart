import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dual_reader/src/core/di/injection_container.dart';
import 'package:dual_reader/src/domain/usecases/import_book_usecase.dart';
import 'package:dual_reader/src/domain/usecases/paginate_book_usecase.dart';
import 'package:dual_reader/src/domain/entities/book_entity.dart';
import 'package:dual_reader/src/domain/entities/settings_entity.dart';
import 'package:go_router/go_router.dart';
import 'package:dual_reader/src/domain/usecases/delete_book_usecase.dart';
import 'package:dual_reader/src/presentation/providers/book_list_notifier.dart';
import 'package:dual_reader/src/presentation/providers/language_model_notifier.dart';
import 'package:dual_reader/src/presentation/providers/settings_notifier.dart';
import 'package:dual_reader/src/presentation/providers/pagination_progress_notifier.dart';
import 'package:dual_reader/src/presentation/widgets/file_drop_zone.dart';
import 'package:dual_reader/src/core/utils/language_utils.dart';
import 'package:dual_reader/src/core/platform/platform_features.dart';
import 'package:file_picker/file_picker.dart';
import 'package:universal_io/io.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  String _searchQuery = '';

  List<BookEntity> _filterBooks(List<BookEntity> books) {
    if (_searchQuery.isEmpty) return books;
    final q = _searchQuery.toLowerCase();
    return books.where((b) =>
      b.title.toLowerCase().contains(q) ||
      b.author.toLowerCase().contains(q)
    ).toList();
  }

  /// Start background pagination for a newly imported book
  Future<void> _startAutoPagination(BookEntity book) async {
    final settings = ref.read(settingsProvider);
    final screenSize = MediaQuery.of(context).size;
    final paginateBook = sl<PaginateBookUseCase>();
    final progressNotifier = ref.read(paginationProgressProvider.notifier);

    // Run pagination in the background
    paginateBook(
      book,
      settings: settings,
      screenSize: screenSize,
      progressNotifier: progressNotifier,
    ).then((totalPages) {
      if (totalPages > 0) {
        debugPrint('[Library] Auto-pagination completed: $totalPages pages');
      } else {
        debugPrint('[Library] Auto-pagination failed for: ${book.title}');
      }
      // Refresh book list to show updated status
      if (mounted) {
        ref.read(bookListProvider.notifier).refreshBooks();
      }
    }).catchError((e) {
      debugPrint('[Library] Auto-pagination error: $e');
      if (mounted) {
        ref.read(bookListProvider.notifier).refreshBooks();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final books = ref.watch(bookListProvider);
    final settings = ref.watch(settingsProvider);
    final modelState = ref.watch(languageModelProvider);
    final paginationProgress = ref.watch(paginationProgressProvider);
    final targetLanguage = settings.targetTranslationLanguageCode;
    final filteredBooks = _filterBooks(books);

    // Trigger language model download check on platforms that support it
    if (platformFeatures.supportsModelDownload) {
      ref.listen(languageModelProvider, (previous, next) {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final notifier = ref.read(languageModelProvider.notifier);
        final currentState = ref.read(languageModelProvider);
        if (currentState.status == ModelDownloadStatus.notStarted) {
          notifier.checkAndDownloadRequiredModel(targetLanguage);
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Library'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.go('/settings'),
            tooltip: 'Settings',
          ),
          IconButton(
            icon: const Icon(Icons.add_box_outlined),
            onPressed: () async {
              try {
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['epub', 'mobi'],
                  withData: true,
                );

                if (result != null) {
                  final importBook = sl<ImportBookUseCase>();
                  final book = await importBook(pickResult: result);

                  if (book != null && context.mounted) {
                    // Refresh books to show the newly imported book
                    ref.read(bookListProvider.notifier).refreshBooks();

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Book imported. Preparing pages...')),
                    );

                    // Start auto-pagination in background
                    _startAutoPagination(book);
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to import book: $e')),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: FileDropZone(
        onFilesDropped: (filePaths) async {
          // Handled via JS interop on web; no-op here as the actual
          // import logic goes through the ImportBookUseCase
        },
        child: Column(
        children: [
          // Language model download progress banner
          if (modelState.status == ModelDownloadStatus.inProgress)
            _ModelDownloadBanner(modelState: modelState),
          // Download success banner
          if (modelState.status == ModelDownloadStatus.completed && modelState.showNotification)
            _ModelSuccessBanner(modelState: modelState, onDismiss: () {
              ref.read(languageModelProvider.notifier).dismissNotification();
            }),
          // Download error banner
          if (modelState.status == ModelDownloadStatus.failed && modelState.showNotification)
            _ModelErrorBanner(
              modelState: modelState,
              onRetry: () {
                ref.read(languageModelProvider.notifier).downloadLanguageModel(modelState.languageCode);
              },
            ),
          // Search bar
          if (books.length > 3)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search books...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  isDense: true,
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),
          // Book grid
          Expanded(
            child: filteredBooks.isEmpty
                ? Center(
                    child: Text(books.isEmpty
                        ? 'No books imported yet. Click the + icon to import a book.'
                        : 'No books match your search.'),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(16.0),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16.0,
                      mainAxisSpacing: 16.0,
                      childAspectRatio: 0.65,
                    ),
                    itemCount: filteredBooks.length,
                    itemBuilder: (context, index) {
                      final book = filteredBooks[index];
                      final bookProgress = paginationProgress[book.id];
                      final isPaginating = book.isPaginating ||
                          bookProgress?.status == PaginationStatus.inProgress;
                      final isReady = book.isPaginated ||
                          bookProgress?.status == PaginationStatus.completed;
                      final paginationFailed = book.status == PaginationStatus.failed ||
                          bookProgress?.status == PaginationStatus.failed;
                      final progress = bookProgress?.progress ?? book.paginationProgress ?? 0.0;

                      return _BookCard(
                        book: book,
                        isPaginating: isPaginating,
                        isReady: isReady,
                        paginationFailed: paginationFailed,
                        progress: progress,
                        onTap: isReady
                            ? () => context.go('/read/${book.id}')
                            : null,
                        onLongPress: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Delete Book'),
                              content: Text('Are you sure you want to delete "${book.title}"?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    final deleteBook = sl<DeleteBookUseCase>();
                                    await deleteBook(book.id);
                                    ref.read(bookListProvider.notifier).refreshBooks();
                                    ref.read(paginationProgressProvider.notifier).removeBook(book.id);
                                    if (context.mounted) Navigator.of(context).pop();
                                  },
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      ),
    );
  }
}

/// Book card with pagination status overlay
class _BookCard extends StatelessWidget {
  final BookEntity book;
  final bool isPaginating;
  final bool isReady;
  final bool paginationFailed;
  final double progress;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _BookCard({
    required this.book,
    required this.isPaginating,
    required this.isReady,
    required this.paginationFailed,
    required this.progress,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Card(
        elevation: 4.0,
        color: isReady ? null : Theme.of(context).disabledColor.withValues(alpha: 0.1),
        child: Column(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Cover image or placeholder
                  book.coverPath.isNotEmpty && platformFeatures.supportsFileAccess
                      ? Image.file(
                          File(book.coverPath),
                          fit: BoxFit.cover,
                          width: double.infinity,
                        )
                      : Container(
                          color: Colors.grey[300],
                          child: const Icon(Icons.book, size: 50, color: Colors.grey),
                        ),
                  // Pagination in progress overlay
                  if (isPaginating)
                    Container(
                      color: Colors.black.withValues(alpha: 0.6),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Preparing... ${(progress * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Not ready label
                  if (!isReady && !isPaginating && !paginationFailed)
                    Container(
                      color: Colors.black.withValues(alpha: 0.5),
                      child: const Center(
                        child: Text(
                          'Not ready',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ),
                    ),
                  // Pagination failed label
                  if (paginationFailed)
                    Container(
                      color: Colors.red.withValues(alpha: 0.4),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline, color: Colors.white, size: 28),
                            SizedBox(height: 4),
                            Text(
                              'Failed',
                              style: TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Progress bar during pagination
            if (isPaginating)
              LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                backgroundColor: Colors.grey[300],
              ),
            // Normal progress bar for completed books
            if (isReady && book.totalPages > 0)
              LinearProgressIndicator(
                value: (book.currentPage / book.totalPages).clamp(0.0, 1.0),
                backgroundColor: Colors.grey[300],
              ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isReady ? null : Colors.grey,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    book.author,
                    style: TextStyle(
                      color: isReady ? Colors.grey : Colors.grey[400],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (isReady && book.totalPages > 0)
                    Text(
                      '${book.currentPage}/${book.totalPages} pages',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Banner widgets for model download states
class _ModelDownloadBanner extends StatelessWidget {
  final LanguageModelState modelState;
  const _ModelDownloadBanner({required this.modelState});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: Colors.deepPurple.shade50,
        child: Row(
          children: [
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Downloading ${LanguageUtils.getLanguageName(modelState.languageCode)} translation model...',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  if (modelState.progressMessage != null)
                    Text(modelState.progressMessage!, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModelSuccessBanner extends StatelessWidget {
  final LanguageModelState modelState;
  final VoidCallback onDismiss;
  const _ModelSuccessBanner({required this.modelState, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: Colors.green.shade50,
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${LanguageUtils.getLanguageName(modelState.languageCode)} model ready! Translations will be faster.',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.green),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(icon: const Icon(Icons.close, size: 16), color: Colors.grey, onPressed: onDismiss),
          ],
        ),
      ),
    );
  }
}

class _ModelErrorBanner extends StatelessWidget {
  final LanguageModelState modelState;
  final VoidCallback onRetry;
  const _ModelErrorBanner({required this.modelState, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: Colors.red.shade50,
        child: Row(
          children: [
            const Icon(Icons.error, color: Colors.red, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Model download failed', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.red)),
                  if (modelState.errorMessage != null)
                    Text(modelState.errorMessage!, style: TextStyle(fontSize: 12, color: Colors.grey.shade700), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
