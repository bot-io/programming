import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/bookmark_provider.dart';
import '../providers/reader_provider.dart';
import '../models/bookmark.dart';
import '../services/help_service.dart';
import 'package:intl/intl.dart';

class BookmarksDialog extends StatelessWidget {
  final Function(int)? onBookmarkTap;

  const BookmarksDialog({
    Key? key,
    this.onBookmarkTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer2<BookmarkProvider, ReaderProvider>(
      builder: (context, bookmarkProvider, readerProvider, child) {
        if (bookmarkProvider.isLoading) {
          return const Dialog(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final bookmarks = bookmarkProvider.bookmarks;

        return Dialog(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.7,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Bookmarks',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Tooltip(
                          message: HelpService.getTooltip('bookmarks'),
                          child: IconButton(
                            icon: const Icon(Icons.help_outline),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Bookmarks Help'),
                                  content: Text(HelpService.getTooltip('bookmarks')),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Close'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(),
                if (bookmarks.isEmpty)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.bookmark_border,
                            size: 64,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No bookmarks yet',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap the bookmark icon to save your place',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      itemCount: bookmarks.length,
                      itemBuilder: (context, index) {
                        final bookmark = bookmarks[index];
                        return _BookmarkItem(
                          bookmark: bookmark,
                          currentPage: readerProvider.currentPageIndex + 1,
                          onTap: () {
                            if (onBookmarkTap != null) {
                              onBookmarkTap!(bookmark.page);
                            }
                            Navigator.pop(context);
                          },
                          onDelete: () {
                            bookmarkProvider.deleteBookmark(bookmark.id);
                          },
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add Bookmark'),
                  onPressed: () {
                    _showAddBookmarkDialog(
                      context,
                      bookmarkProvider,
                      readerProvider.currentPageIndex + 1,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddBookmarkDialog(
    BuildContext context,
    BookmarkProvider bookmarkProvider,
    int currentPage,
  ) {
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Bookmark'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Page $currentPage'),
            const SizedBox(height: 16),
            Tooltip(
              message: HelpService.getTooltip('bookmark_note'),
              child: TextField(
                controller: noteController,
                decoration: InputDecoration(
                  labelText: 'Note (optional)',
                  helperText: HelpService.getTooltip('bookmark_note'),
                  border: const OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              bookmarkProvider.addBookmark(
                currentPage,
                note: noteController.text.trim().isEmpty
                    ? null
                    : noteController.text.trim(),
              );
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _BookmarkItem extends StatelessWidget {
  final Bookmark bookmark;
  final int currentPage;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _BookmarkItem({
    Key? key,
    required this.bookmark,
    required this.currentPage,
    required this.onTap,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCurrentPage = bookmark.page == currentPage;
    final dateFormat = DateFormat('MMM d, y • h:mm a');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isCurrentPage
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surface,
      child: ListTile(
        leading: Icon(
          isCurrentPage ? Icons.bookmark : Icons.bookmark_border,
          color: isCurrentPage
              ? theme.colorScheme.onPrimaryContainer
              : theme.colorScheme.onSurface,
        ),
        title: Text(
          'Page ${bookmark.page}',
          style: TextStyle(
            fontWeight: isCurrentPage ? FontWeight.bold : FontWeight.normal,
            color: isCurrentPage
                ? theme.colorScheme.onPrimaryContainer
                : theme.colorScheme.onSurface,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (bookmark.note != null && bookmark.note!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                bookmark.note!,
                style: TextStyle(
                  color: isCurrentPage
                      ? theme.colorScheme.onPrimaryContainer.withOpacity(0.8)
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              dateFormat.format(bookmark.createdAt),
              style: TextStyle(
                fontSize: 12,
                color: isCurrentPage
                    ? theme.colorScheme.onPrimaryContainer.withOpacity(0.7)
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        trailing: Tooltip(
          message: HelpService.getTooltip('bookmark_delete'),
          child: IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete Bookmark'),
                  content: const Text('Are you sure you want to delete this bookmark?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        onDelete();
                        Navigator.pop(context);
                      },
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
