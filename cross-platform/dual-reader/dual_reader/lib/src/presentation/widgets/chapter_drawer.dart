import 'package:flutter/material.dart';
import 'package:dual_reader/src/core/utils/logging_service.dart';

/// Chapter data for display in the table of contents
class ChapterItem {
  /// Display title of the chapter
  final String title;

  /// Starting page index for this chapter
  final int startingPageIndex;

  const ChapterItem({
    required this.title,
    required this.startingPageIndex,
  });
}

/// Chapter drawer/table of contents overlay for the dual reader screen.
///
/// Displays a slide-out drawer with the table of contents.
/// Tap outside to close, tap chapter to navigate.
///
/// Features:
/// - Slide-in animation from right
/// - Overlay background
/// - Chapter list with tap navigation
/// - Close button
/// - Theme-aware styling
/// - Takes up 70% of screen width
class ChapterDrawer extends StatelessWidget {
  /// List of chapters to display
  final List<ChapterItem> chapters;

  /// Current page index (for highlighting)
  final int? currentPage;

  /// Callback when a chapter is selected
  final ValueChanged<int> onChapterSelected;

  /// Callback when drawer is closed
  final VoidCallback? onClose;

  const ChapterDrawer({
    super.key,
    required this.chapters,
    this.currentPage,
    required this.onChapterSelected,
    this.onClose,
  });

  /// Find the current chapter index based on current page
  int? _findCurrentChapterIndex() {
    if (currentPage == null) return null;
    for (int i = chapters.length - 1; i >= 0; i--) {
      if (chapters[i].startingPageIndex <= currentPage!) {
        return i;
      }
    }
    return null;
  }

  void _handleChapterTap(int index, ChapterItem chapter) {
    LoggingService.info('ChapterDrawer', 'Chapter selected: ${chapter.title} (page ${chapter.startingPageIndex})');
    onChapterSelected(chapter.startingPageIndex);
    onClose?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final currentChapterIndex = _findCurrentChapterIndex();

    return GestureDetector(
      onTap: onClose,
      child: Container(
        color: isDark
          ? Colors.black.withOpacity(0.5)
          : Colors.black.withOpacity(0.3),
        child: Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: () {}, // Prevent tap from closing immediately
            child: Container(
              width: screenWidth * 0.7,
              decoration: BoxDecoration(
                color: isDark
                  ? (colorScheme.surface)
                  : colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(-2, 0),
                  ),
                ],
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Table of Contents',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: isDark ? colorScheme.onSurface : colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.close,
                              color: isDark ? colorScheme.onSurface : colorScheme.onSurface,
                            ),
                            onPressed: () {
                              LoggingService.debug('ChapterDrawer', 'Close button pressed');
                              onClose?.call();
                            },
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    // Chapter list
                    Expanded(
                      child: ListView.builder(
                        itemCount: chapters.length,
                        itemBuilder: (context, index) {
                          final chapter = chapters[index];
                          final isCurrentChapter = currentChapterIndex == index;

                          return ListTile(
                            title: Text(
                              chapter.title,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: isCurrentChapter
                                  ? (isDark ? colorScheme.primary : colorScheme.primary)
                                  : (isDark ? colorScheme.onSurface : colorScheme.onSurface),
                                fontWeight: isCurrentChapter ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            subtitle: Text(
                              'Page ${chapter.startingPageIndex + 1}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isDark
                                  ? colorScheme.onSurface.withOpacity(0.6)
                                  : colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                            leading: isCurrentChapter
                              ? Icon(
                                  Icons.bookmark,
                                  color: isDark ? colorScheme.primary : colorScheme.primary,
                                  size: 20,
                                )
                              : null,
                            onTap: () => _handleChapterTap(index, chapter),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
