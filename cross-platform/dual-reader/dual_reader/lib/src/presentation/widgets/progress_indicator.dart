import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Always-visible reading progress indicator.
///
/// Displays the current page number, total pages, and percentage progress.
/// Supports both compact and full display modes.
///
/// Features:
/// - Always-visible page number and percentage
/// - Compact mode for minimal UI footprint
/// - Full mode with linear progress bar
/// - Theme-aware styling
class ReadingProgressIndicator extends StatelessWidget {
  /// Current page number (0-indexed)
  final int currentPage;

  /// Total number of pages
  final int totalPages;

  /// Whether to show in compact mode (smaller, no bar)
  final bool isCompact;

  /// Background color (optional, defaults to theme)
  final Color? backgroundColor;

  /// Text color (optional, defaults to theme)
  final Color? textColor;

  const ReadingProgressIndicator({
    super.key,
    required this.currentPage,
    required this.totalPages,
    this.isCompact = false,
    this.backgroundColor,
    this.textColor,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    final effectiveBackgroundColor = backgroundColor ??
      (isDark
        ? colorScheme.surfaceContainerHighest.withOpacity(0.9)
        : colorScheme.surfaceContainerHighest.withOpacity(0.95));

    final effectiveTextColor = textColor ??
      (isDark ? colorScheme.onSurface : colorScheme.onSurface);

    if (isCompact) {
      return _buildCompactIndicator(context, effectiveTextColor);
    }

    return _buildFullIndicator(context, effectiveBackgroundColor, effectiveTextColor);
  }

  Widget _buildCompactIndicator(BuildContext context, Color textColor) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Page ${currentPage + 1}/$totalPages',
            style: theme.textTheme.bodySmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$percentageText%',
            style: theme.textTheme.bodySmall?.copyWith(
              color: textColor.withOpacity(0.7),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullIndicator(BuildContext context, Color backgroundColor, Color textColor) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          top: BorderSide(
            color: isDark
              ? colorScheme.outlineVariant.withOpacity(0.2)
              : colorScheme.outlineVariant.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Linear progress bar
            if (totalPages > 0)
              LinearProgressIndicator(
                value: (currentPage + 1) / totalPages,
                backgroundColor: isDark
                  ? colorScheme.surfaceContainerHighest
                  : colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isDark ? colorScheme.primary : colorScheme.primary,
                ),
                minHeight: 3,
              ),
            // Page info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Page ${currentPage + 1} of $totalPages',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark
                        ? colorScheme.secondaryContainer.withOpacity(0.3)
                        : colorScheme.secondaryContainer.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$percentageText%',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
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
