import 'package:flutter/material.dart';
import '../models/book.dart';
import '../models/reading_progress.dart';
import '../utils/image_loader.dart';
import '../services/help_service.dart';

/// A reusable BookCard widget that displays book information with Material Design 3 styling.
/// 
/// Features:
/// - Displays book cover image with placeholder
/// - Shows title and author
/// - Shows reading progress indicator
/// - Handles tap to open book
/// - Material Design 3 styling
/// - Responsive to screen size
/// - Full accessibility support
class BookCard extends StatelessWidget {
  final Book book;
  final ReadingProgress? progress;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  
  /// Optional layout mode: 'list' (default) or 'grid'
  final String? layoutMode;

  const BookCard({
    super.key,
    required this.book,
    this.progress,
    required this.onTap,
    this.onDelete,
    this.layoutMode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final isSmallScreen = mediaQuery.size.width < 600;
    final isTablet = mediaQuery.size.width >= 600 && mediaQuery.size.width < 1200;
    final isDesktop = mediaQuery.size.width >= 1200;
    
    // Determine layout mode
    final effectiveLayoutMode = layoutMode ?? (isSmallScreen ? 'list' : 'list');
    
    // Responsive cover dimensions
    final coverWidth = _getCoverWidth(isSmallScreen, isTablet, isDesktop, effectiveLayoutMode);
    final coverHeight = _getCoverHeight(isSmallScreen, isTablet, isDesktop, effectiveLayoutMode);
    
    final progressPercent = progress?.progress ?? 0.0;
    final progressText = progress != null
        ? '${(progressPercent * 100).toStringAsFixed(0)}% complete, Page ${progress!.currentPage} of ${progress!.totalPages}'
        : 'Not started';

    return Semantics(
      label: '${book.title} by ${book.author}. $progressText',
      button: true,
      child: Card(
        elevation: 1,
        margin: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 16 : 24,
          vertical: isSmallScreen ? 8 : 12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Tooltip(
          message: HelpService.getTooltip('book_card'),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
            padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cover image with Material Design 3 styling
                _buildCoverImage(
                  context: context,
                  theme: theme,
                  width: coverWidth,
                  height: coverHeight,
                ),
                SizedBox(width: isSmallScreen ? 16 : 20),
                // Book info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Title
                      Text(
                        book.title.isEmpty ? 'Untitled' : book.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.15,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: isSmallScreen ? 4 : 6),
                      // Author
                      Text(
                        book.author.isEmpty ? 'Unknown Author' : book.author,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          letterSpacing: 0.25,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: isSmallScreen ? 8 : 12),
                      // Progress indicator
                      _buildProgressIndicator(theme, progressPercent),
                    ],
                  ),
                ),
                // Delete button
                if (onDelete != null)
                  Semantics(
                    label: 'Delete ${book.title}',
                    button: true,
                    child: IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        size: isSmallScreen ? 20 : 24,
                      ),
                      onPressed: onDelete,
                      tooltip: HelpService.getTooltip('delete_book'),
                      style: IconButton.styleFrom(
                        foregroundColor: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
          ),
      ),
    );
  }

  /// Builds the cover image with placeholder support
  Widget _buildCoverImage({
    required BuildContext context,
    required ThemeData theme,
    required double width,
    required double height,
  }) {
    return Semantics(
      label: 'Book cover for ${book.title}',
      image: true,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: width,
            height: height,
            child: loadCoverImage(book.coverImagePath, theme),
          ),
        ),
      ),
    );
  }

  /// Builds the progress indicator section
  Widget _buildProgressIndicator(ThemeData theme, double progressPercent) {
    if (progress != null) {
      return Semantics(
        label: 'Reading progress: ${(progressPercent * 100).toStringAsFixed(0)}% complete',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progress bar with Material Design 3 styling
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progressPercent.clamp(0.0, 1.0),
                backgroundColor: theme.colorScheme.surfaceVariant,
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.colorScheme.primary,
                ),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 6),
            // Progress text
            Row(
              children: [
                Icon(
                  Icons.bookmark_outline,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    '${(progressPercent * 100).toStringAsFixed(0)}% • Page ${progress!.currentPage}/${progress!.totalPages}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    } else {
      return Semantics(
        label: 'Reading not started',
        child: Row(
          children: [
            Icon(
              Icons.book_outlined,
              size: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              'Not started',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }
  }

  /// Gets responsive cover width based on screen size
  double _getCoverWidth(bool isSmallScreen, bool isTablet, bool isDesktop, String layoutMode) {
    if (layoutMode == 'grid') {
      return isSmallScreen ? 100 : isTablet ? 120 : 140;
    }
    return isSmallScreen ? 80 : isTablet ? 100 : 120;
  }

  /// Gets responsive cover height based on screen size
  double _getCoverHeight(bool isSmallScreen, bool isTablet, bool isDesktop, String layoutMode) {
    if (layoutMode == 'grid') {
      return isSmallScreen ? 150 : isTablet ? 180 : 210;
    }
    return isSmallScreen ? 120 : isTablet ? 150 : 180;
  }
}
