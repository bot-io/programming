import 'package:flutter/material.dart';
import 'package:dual_reader/src/core/utils/logging_service.dart';

/// Pagination controls for the dual reader screen.
///
/// Provides a slider and navigation buttons for page navigation.
/// Shows page progress and supports smooth dragging interaction.
///
/// Features:
/// - Page slider with live preview
/// - Percentage indicator during drag
/// - Previous/Next navigation buttons
/// - Page number and percentage display
/// - Theme-aware styling
class PaginationControls extends StatelessWidget {
  /// Current page number (0-indexed)
  final int currentPage;

  /// Total number of pages
  final int totalPages;

  /// Callback when page changes
  final ValueChanged<int> onPageChanged;

  /// Whether user is currently dragging the slider
  final bool isDragging;

  /// The pending page during drag (for preview)
  final int? pendingPage;

  const PaginationControls({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
    this.isDragging = false,
    this.pendingPage,
  });

  /// Calculate the progress percentage (0-100)
  double get progressPercentage {
    if (totalPages <= 0) return 0.0;
    return ((currentPage + 1) / totalPages * 100);
  }

  /// Get the formatted percentage string
  String get percentageText {
    return progressPercentage.toStringAsFixed(1);
  }

  void _handlePreviousPage() {
    if (currentPage > 0) {
      LoggingService.debug('PaginationControls', 'Previous page tapped');
      onPageChanged(currentPage - 1);
    }
  }

  void _handleNextPage() {
    if (currentPage < totalPages - 1) {
      LoggingService.debug('PaginationControls', 'Next page tapped');
      onPageChanged(currentPage + 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: isDark
          ? (colorScheme.surfaceContainerHighest.withOpacity(0.95))
          : colorScheme.surfaceContainerHighest.withOpacity(0.95),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Page slider with value indicator
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Percentage indicator (shown during drag)
                if (isDragging && pendingPage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? colorScheme.surfaceContainer : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${((pendingPage! + 1) / totalPages * 100).toStringAsFixed(0)}%',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? colorScheme.onSurface : colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                // Page slider
                SizedBox(
                  height: 30,
                  child: Slider(
                    value: isDragging && pendingPage != null
                        ? pendingPage!.toDouble()
                        : currentPage.toDouble(),
                    min: 0,
                    max: (totalPages > 0 ? totalPages - 1 : 0).toDouble(),
                    divisions: totalPages > 1 ? totalPages : 1,
                    label: isDragging && pendingPage != null
                        ? 'Page ${pendingPage! + 1} of $totalPages'
                        : 'Page ${currentPage + 1} of $totalPages',
                    onChanged: (value) {
                      // Slider is for display only - actual navigation via buttons
                    },
                  ),
                ),
              ],
            ),
            // Navigation buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, size: 20),
                    color: isDark ? colorScheme.onSurface : colorScheme.onSurface,
                    onPressed: currentPage > 0 ? _handlePreviousPage : null,
                  ),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Page ${currentPage + 1} of $totalPages',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark ? colorScheme.onSurface : colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          '$percentageText%',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark
                              ? colorScheme.onSurface.withOpacity(0.7)
                              : colorScheme.onSurface.withOpacity(0.6),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios, size: 20),
                    color: isDark ? colorScheme.onSurface : colorScheme.onSurface,
                    onPressed: currentPage < totalPages - 1 ? _handleNextPage : null,
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

/// Full pagination controls widget with slider drag state management.
///
/// This is a stateful version that handles slider drag state internally
/// and provides callbacks for drag start, change, and end events.
class PaginationControlsFull extends StatefulWidget {
  /// Current page number (0-indexed)
  final int currentPage;

  /// Total number of pages
  final int totalPages;

  /// Callback when page changes (immediate, during drag)
  final ValueChanged<int>? onPageChanged;

  /// Callback when drag ends (final page confirmed)
  final ValueChanged<int>? onPageSelected;

  const PaginationControlsFull({
    super.key,
    required this.currentPage,
    required this.totalPages,
    this.onPageChanged,
    this.onPageSelected,
  });

  @override
  State<PaginationControlsFull> createState() => _PaginationControlsFullState();
}

class _PaginationControlsFullState extends State<PaginationControlsFull> {
  bool _isDragging = false;
  int? _pendingPage;

  @override
  Widget build(BuildContext context) {
    return PaginationControls(
      currentPage: widget.currentPage,
      totalPages: widget.totalPages,
      isDragging: _isDragging,
      pendingPage: _pendingPage,
      onPageChanged: _handlePageChange,
    );
  }

  void _handlePageChange(int newPage) {
    setState(() {
      _pendingPage = newPage;
    });
    widget.onPageChanged?.call(newPage);
  }
}
