import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/reader_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/bookmark_provider.dart';
import '../services/storage_service.dart';
import '../widgets/dual_panel_reader.dart';
import '../widgets/reader_controls.dart';
import '../widgets/bookmarks_dialog.dart';
import '../widgets/chapters_dialog.dart';
import '../services/help_service.dart';

class ReaderScreen extends StatefulWidget {
  final String bookId;

  const ReaderScreen({
    Key? key,
    required this.bookId,
  }) : super(key: key);

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  bool _showControls = true;
  late BookmarkProvider _bookmarkProvider;

  @override
  void initState() {
    super.initState();
    final storageService = Provider.of<StorageService>(context, listen: false);
    _bookmarkProvider = BookmarkProvider(storageService, widget.bookId);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBook();
    });
  }

  void _loadBook() {
    final readerProvider = Provider.of<ReaderProvider>(context, listen: false);
    readerProvider.loadBook(widget.bookId, context);
  }

  void _showBookmarks() {
    showDialog(
      context: context,
      builder: (context) => ChangeNotifierProvider.value(
        value: _bookmarkProvider,
        child: BookmarksDialog(
          onBookmarkTap: (page) {
            final readerProvider = Provider.of<ReaderProvider>(context, listen: false);
            readerProvider.goToPage(page - 1);
          },
        ),
      ),
    );
  }

  void _addBookmark() {
    final readerProvider = Provider.of<ReaderProvider>(context, listen: false);
    final currentPage = readerProvider.currentPageIndex + 1;
    
    if (_bookmarkProvider.hasBookmarkOnPage(currentPage)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bookmark already exists on this page')),
      );
      return;
    }

    _bookmarkProvider.addBookmark(currentPage);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Bookmark added to page $currentPage'),
        action: SnackBarAction(
          label: 'View',
          onPressed: _showBookmarks,
        ),
      ),
    );
  }

  void _showChapters() {
    showDialog(
      context: context,
      builder: (context) => const ChaptersDialog(),
    );
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ReaderProvider, SettingsProvider>(
      builder: (context, readerProvider, settingsProvider, child) {
        if (readerProvider.isLoading) {
          return Scaffold(
            appBar: AppBar(
              title: Text(readerProvider.currentBook?.title ?? 'Loading...'),
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (readerProvider.error != null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Error'),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    readerProvider.error!,
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.pop(),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            ),
          );
        }

        final currentPage = readerProvider.currentPage;
        if (currentPage == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('No Content'),
            ),
            body: const Center(child: Text('No content available')),
          );
        }

        return Scaffold(
          appBar: _showControls
              ? AppBar(
                  title: Text(
                    readerProvider.currentBook?.title ?? 'Reader',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  actions: [
                    Consumer<BookmarkProvider>(
                      builder: (context, bookmarkProvider, child) {
                        return Tooltip(
                          message: HelpService.getTooltip('bookmark'),
                          child: IconButton(
                            icon: Icon(
                              bookmarkProvider.hasBookmarkOnPage(currentPage.pageNumber)
                                  ? Icons.bookmark
                                  : Icons.bookmark_border,
                            ),
                            onPressed: _addBookmark,
                            tooltip: HelpService.getTooltip('bookmark'),
                          ),
                        );
                      },
                    ),
                    if (readerProvider.isTranslating)
                      Tooltip(
                        message: HelpService.getTooltip('translation_indicator'),
                        child: const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                    IconButton(
                      icon: const Icon(Icons.help_outline),
                      onPressed: () {
                        context.push('/help');
                      },
                      tooltip: HelpService.getTooltip('help'),
                    ),
                  ],
                )
              : null,
          body: ChangeNotifierProvider.value(
            value: _bookmarkProvider,
            child: Tooltip(
              message: HelpService.getTooltip('toggle_controls'),
              child: GestureDetector(
                onTap: _toggleControls,
                child: Stack(
                children: [
                  DualPanelReader(
                    page: currentPage,
                    settings: settingsProvider.settings,
                  ),
                  if (_showControls)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: ReaderControls(
                        currentPage: currentPage.pageNumber,
                        totalPages: currentPage.totalPages,
                        onPreviousPage: readerProvider.hasPreviousPage
                            ? () => readerProvider.previousPage()
                            : null,
                        onNextPage: readerProvider.hasNextPage
                            ? () => readerProvider.nextPage()
                            : null,
                        onPageChanged: (page) {
                          readerProvider.goToPage(page - 1);
                        },
                        onSettings: () {
                          context.push('/settings').then((_) {
                            // Refresh pages when settings change
                            readerProvider.refreshPages(context);
                          });
                        },
                        onBookmarks: _showBookmarks,
                        onChapters: readerProvider.chapters.isNotEmpty ? _showChapters : null,
                        onBack: () => context.pop(),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      },
    );
  }

  @override
  void dispose() {
    _bookmarkProvider.dispose();
    super.dispose();
  }
}
