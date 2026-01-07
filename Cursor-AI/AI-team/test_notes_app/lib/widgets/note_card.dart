import 'package:flutter/material.dart';
import 'package:simplenotes/models/note.dart';
import 'package:simplenotes/models/category.dart';
import 'package:simplenotes/utils/responsive.dart';

/// A reusable widget for displaying notes in lists.
/// 
/// This widget displays a note's title, content preview, category, and timestamps
/// in a Material Design 3 styled card.
/// 
/// Example:
/// ```dart
/// NoteCard(
///   note: myNote,
///   category: myCategory,
///   onTap: () => Navigator.push(...),
/// )
/// ```
class NoteCard extends StatelessWidget {
  /// The note to display.
  final Note note;

  /// Optional category associated with the note.
  /// 
  /// If provided, the category name and color will be displayed.
  final Category? category;

  /// Callback when the card is tapped.
  final VoidCallback? onTap;

  /// Callback when the card is long-pressed.
  final VoidCallback? onLongPress;

  /// Maximum number of lines for the content preview.
  /// 
  /// Defaults to 2. Set to null for unlimited lines.
  final int? maxPreviewLines;

  /// Creates a [NoteCard] widget.
  /// 
  /// The [note] parameter is required.
  const NoteCard({
    super.key,
    required this.note,
    this.category,
    this.onTap,
    this.onLongPress,
    this.maxPreviewLines = 2,
  });

  /// Formats a DateTime to a human-readable string.
  /// 
  /// Shows relative time (e.g., "2 hours ago") for recent dates,
  /// otherwise shows the date (e.g., "Jan 15, 2024").
  String _formatTimestamp(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      // Format as "MMM dd, yyyy"
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year}';
    }
  }

  /// Gets the preview text from the note content.
  /// 
  /// Removes leading/trailing whitespace and newlines, and truncates if needed.
  String _getPreviewText() {
    final text = note.content.trim();
    if (text.isEmpty) {
      return 'No content';
    }
    // Remove multiple newlines and replace with space
    final cleaned = text.replaceAll(RegExp(r'\n+'), ' ');
    return cleaned;
  }

  /// Parses a hex color string to a Color object.
  /// 
  /// Supports formats: #RRGGBB or #AARRGGBB
  Color? _parseColor(String? colorString) {
    if (colorString == null || colorString.isEmpty) {
      return null;
    }

    try {
      // Remove # if present
      final hex = colorString.replaceFirst('#', '');
      
      if (hex.length == 6) {
        // RRGGBB format
        return Color(
          0xFF000000 +
              int.parse(hex.substring(0, 2), radix: 16) * 0x10000 +
              int.parse(hex.substring(2, 4), radix: 16) * 0x100 +
              int.parse(hex.substring(4, 6), radix: 16),
        );
      } else if (hex.length == 8) {
        // AARRGGBB format
        return Color(
          int.parse(hex.substring(0, 2), radix: 16) * 0x1000000 +
              int.parse(hex.substring(2, 4), radix: 16) * 0x10000 +
              int.parse(hex.substring(4, 6), radix: 16) * 0x100 +
              int.parse(hex.substring(6, 8), radix: 16),
        );
      }
    } catch (e) {
      // Invalid color format, return null
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isMobile = Responsive.isMobile(context);

    return Card(
      margin: EdgeInsets.symmetric(
        horizontal: isMobile ? 0 : Responsive.getSpacing(context),
        vertical: Responsive.getSpacing(context) / 2,
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: Responsive.getCardPadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title row with category chip
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Expanded(
                    child: Text(
                      note.title.isEmpty ? 'Untitled Note' : note.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                        fontSize: (theme.textTheme.titleMedium?.fontSize ?? 16) * Responsive.getFontSizeMultiplier(context),
                      ),
                      maxLines: Responsive.isMobile(context) ? 2 : 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Category chip
                  if (category != null) ...[
                    const SizedBox(width: 8),
                    _CategoryChip(
                      category: category!,
                      colorScheme: colorScheme,
                    ),
                  ],
                ],
              ),
              
              SizedBox(height: Responsive.getSpacing(context)),
              
              // Content preview
              Text(
                _getPreviewText(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: (theme.textTheme.bodyMedium?.fontSize ?? 14) * Responsive.getFontSizeMultiplier(context),
                ),
                maxLines: maxPreviewLines ?? (Responsive.isMobile(context) ? 2 : 3),
                overflow: TextOverflow.ellipsis,
              ),
              
              SizedBox(height: Responsive.getSpacing(context) * 1.5),
              
              // Timestamps row
              Row(
                children: [
                  // Updated timestamp
                  Icon(
                    Icons.access_time,
                    size: 14,
                    color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatTimestamp(note.updatedAt),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                    ),
                  ),
                  
                  // Show created timestamp if different from updated
                  if (note.createdAt.difference(note.updatedAt).abs().inDays > 0) ...[
                    const SizedBox(width: 12),
                    Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatTimestamp(note.createdAt),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Internal widget for displaying a category chip.
class _CategoryChip extends StatelessWidget {
  final Category category;
  final ColorScheme colorScheme;

  const _CategoryChip({
    required this.category,
    required this.colorScheme,
  });

  Color? _parseColor(String? colorString) {
    if (colorString == null || colorString.isEmpty) {
      return null;
    }

    try {
      final hex = colorString.replaceFirst('#', '');
      
      if (hex.length == 6) {
        return Color(
          0xFF000000 +
              int.parse(hex.substring(0, 2), radix: 16) * 0x10000 +
              int.parse(hex.substring(2, 4), radix: 16) * 0x100 +
              int.parse(hex.substring(4, 6), radix: 16),
        );
      } else if (hex.length == 8) {
        return Color(
          int.parse(hex.substring(0, 2), radix: 16) * 0x1000000 +
              int.parse(hex.substring(2, 4), radix: 16) * 0x10000 +
              int.parse(hex.substring(4, 6), radix: 16) * 0x100 +
              int.parse(hex.substring(6, 8), radix: 16),
        );
      }
    } catch (e) {
      // Invalid color format
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final categoryColor = _parseColor(category.color);
    final backgroundColor = categoryColor != null
        ? categoryColor.withOpacity(0.2)
        : colorScheme.surfaceVariant.withOpacity(0.5);
    final textColor = categoryColor != null
        ? categoryColor
        : colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        category.name,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w500,
            ),
      ),
    );
  }
}
