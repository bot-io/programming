import 'package:flutter/material.dart';

/// Always-visible progress indicator for the dual reader.
///
/// Displays page number and percentage at the bottom of the screen,
/// remaining visible even when controls are hidden.
///
/// Features:
/// - Compact design to minimize screen space
/// - Semi-transparent background
/// - Always visible (not affected by controls toggle)
/// - Theme-aware styling
class AlwaysVisibleProgress extends StatelessWidget {
  /// Current page number (0-indexed)
  final int currentPage;

  /// Total number of pages
  final int totalPages;

  const AlwaysVisibleProgress({
    super.key,
    required this.currentPage,
    required this.totalPages,
  });

  /// Calculate the progress percentage (0-100)
  double get progressPercentage {
    if (totalPages <= 0) return 0.0;
    return ((currentPage + 1) / totalPages * 100);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return Positioned(
      left: 8,
      right: 8,
      bottom: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isDark
            ? colorScheme.surfaceContainerHighest.withOpacity(0.85)
            : colorScheme.surfaceContainerHighest.withOpacity(0.85),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          mainAxisSize: MainAxisSize.max,
          children: [
            Text(
              'Page ${currentPage + 1} of $totalPages',
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark ? colorScheme.onSurface : colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isDark
                  ? colorScheme.secondaryContainer.withOpacity(0.3)
                  : colorScheme.secondaryContainer.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${progressPercentage.toStringAsFixed(1)}%',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? colorScheme.onSurface : colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
