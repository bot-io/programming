import 'package:flutter/material.dart';
import 'package:dual_reader/src/core/utils/logging_service.dart';
import 'package:dual_reader/src/presentation/widgets/full_screen_toggle.dart';

/// Top navigation controls for the dual reader screen.
///
/// Provides back button, title, refresh translation, settings, table of contents,
/// and full screen toggle. Animates in/out based on visibility state.
///
/// Features:
/// - Animated slide-in/slide-out transition
/// - Back navigation
/// - Book title display
/// - Refresh translation button
/// - Settings button
/// - Table of contents button (when chapters available)
/// - Full screen toggle button
/// - Theme-aware styling
class ReaderTopControls extends StatelessWidget {
  /// The book title to display
  final String? bookTitle;

  /// Whether the controls are currently visible
  final bool visible;

  /// Callback when back button is pressed
  final VoidCallback? onBack;

  /// Callback when refresh button is pressed
  final VoidCallback? onRefresh;

  /// Callback when settings button is pressed
  final VoidCallback? onSettings;

  /// Callback when table of contents button is pressed
  final VoidCallback? onTableOfContents;

  /// Whether chapters are available for table of contents
  final bool hasChapters;

  /// Whether to show the full screen toggle button
  final bool showFullScreenToggle;

  /// Callback when bookmark button is pressed
  final VoidCallback? onBookmark;

  /// Whether the current page is bookmarked
  final bool isBookmarked;

  const ReaderTopControls({
    super.key,
    this.bookTitle,
    this.visible = true,
    this.onBack,
    this.onRefresh,
    this.onSettings,
    this.onTableOfContents,
    this.hasChapters = false,
    this.showFullScreenToggle = true,
    this.onBookmark,
    this.isBookmarked = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      top: visible ? 0 : -kToolbarHeight,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: isDark
            ? (colorScheme.surface.withOpacity(0.95))
            : colorScheme.surface.withOpacity(0.95),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: Row(
            children: [
              IconButton(
                icon: Icon(
                  Icons.arrow_back,
                  color: isDark ? colorScheme.onSurface : colorScheme.onSurface,
                ),
                onPressed: () {
                  LoggingService.debug('ReaderTopControls', 'Back button pressed');
                  onBack?.call();
                },
              ),
              Expanded(
                child: Text(
                  bookTitle ?? 'Dual Reader',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: isDark ? colorScheme.onSurface : colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.refresh,
                  color: isDark ? colorScheme.onSurface : colorScheme.onSurface,
                ),
                onPressed: () {
                  LoggingService.debug('ReaderTopControls', 'Refresh button pressed');
                  onRefresh?.call();
                },
                tooltip: 'Refresh Translation',
              ),
              IconButton(
                icon: Icon(
                  isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                  color: isBookmarked
                      ? Colors.amber
                      : (isDark ? colorScheme.onSurface : colorScheme.onSurface),
                ),
                onPressed: () {
                  LoggingService.debug('ReaderTopControls', 'Bookmark button pressed');
                  onBookmark?.call();
                },
                tooltip: isBookmarked ? 'Remove Bookmark' : 'Add Bookmark',
              ),
              IconButton(
                icon: Icon(
                  Icons.settings,
                  color: isDark ? colorScheme.onSurface : colorScheme.onSurface,
                ),
                onPressed: () {
                  LoggingService.debug('ReaderTopControls', 'Settings button pressed');
                  onSettings?.call();
                },
                tooltip: 'Settings',
              ),
              if (hasChapters)
                IconButton(
                  icon: Icon(
                    Icons.list_alt,
                    color: isDark ? colorScheme.onSurface : colorScheme.onSurface,
                  ),
                  onPressed: () {
                    LoggingService.debug('ReaderTopControls', 'Table of Contents button pressed');
                    onTableOfContents?.call();
                  },
                  tooltip: 'Table of Contents',
                ),
              // Full screen toggle button
              if (showFullScreenToggle) const FullScreenToggle(),
            ],
          ),
        ),
      ),
    );
  }
}
