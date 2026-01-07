import 'package:flutter/material.dart';
import 'package:simplenotes/models/category.dart';
import 'package:simplenotes/utils/responsive.dart';

/// A reusable widget for displaying and selecting categories.
/// 
/// This widget displays a category name, color indicator, and supports
/// selection state. It can be used in filter lists, category selection
/// dialogs, and category management screens.
/// 
/// Example:
/// ```dart
/// CategoryChip(
///   category: myCategory,
///   isSelected: true,
///   onTap: () => print('Category tapped'),
/// )
/// ```
class CategoryChip extends StatelessWidget {
  /// The category to display.
  final Category category;

  /// Whether this chip is currently selected.
  final bool isSelected;

  /// Callback invoked when the chip is tapped.
  final VoidCallback? onTap;

  /// Whether the chip should be deletable.
  /// 
  /// If true, displays a delete icon that can be used to remove the category.
  final bool deletable;

  /// Callback invoked when the delete button is pressed.
  /// 
  /// Only used if [deletable] is true.
  final VoidCallback? onDelete;

  /// The size of the color indicator. Defaults to 12.0.
  final double colorIndicatorSize;

  /// Creates a [CategoryChip] widget.
  /// 
  /// The [category] parameter is required.
  /// 
  /// Example:
  /// ```dart
  /// CategoryChip(
  ///   category: Category(
  ///     id: '1',
  ///     name: 'Work',
  ///     color: '#FF5722',
  ///     createdAt: DateTime.now(),
  ///   ),
  ///   isSelected: false,
  ///   onTap: () => handleCategoryTap(),
  /// )
  /// ```
  const CategoryChip({
    super.key,
    required this.category,
    this.isSelected = false,
    this.onTap,
    this.deletable = false,
    this.onDelete,
    this.colorIndicatorSize = 12.0,
  });

  /// Parses a hex color string to a Color object.
  /// 
  /// Supports formats: #RRGGBB or #AARRGGBB
  /// Returns null if the color string is invalid.
  Color? _parseColor(String? colorString) {
    if (colorString == null || colorString.isEmpty) {
      return null;
    }

    try {
      // Remove the # if present
      String hex = colorString.replaceFirst('#', '');
      
      // Handle 6-digit hex (RRGGBB)
      if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      }
      
      // Handle 8-digit hex (AARRGGBB)
      if (hex.length == 8) {
        return Color(int.parse(hex, radix: 16));
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final chipTheme = theme.chipTheme;

    // Parse category color
    final categoryColor = _parseColor(category.color);

    // Determine background color based on selection state
    final backgroundColor = isSelected
        ? chipTheme.selectedColor ?? colorScheme.primaryContainer
        : chipTheme.backgroundColor ?? colorScheme.surfaceVariant.withOpacity(0.5);

    // Determine text color based on selection state
    final textColor = isSelected
        ? chipTheme.secondaryLabelStyle?.color ?? colorScheme.onPrimaryContainer
        : chipTheme.labelStyle?.color ?? colorScheme.onSurfaceVariant;

    final responsivePadding = Responsive.isMobile(context)
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
        : EdgeInsets.symmetric(
            horizontal: Responsive.getSpacing(context) * 1.5,
            vertical: Responsive.getSpacing(context),
          );
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: chipTheme.padding ?? responsivePadding,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: chipTheme.shape is RoundedRectangleBorder
              ? (chipTheme.shape as RoundedRectangleBorder).borderRadius
              : BorderRadius.circular(8),
          border: isSelected
              ? Border.all(
                  color: colorScheme.primary,
                  width: 1.5,
                )
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Color indicator
            if (categoryColor != null) ...[
              Container(
                width: colorIndicatorSize * Responsive.getFontSizeMultiplier(context),
                height: colorIndicatorSize * Responsive.getFontSizeMultiplier(context),
                decoration: BoxDecoration(
                  color: categoryColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: textColor.withOpacity(0.3),
                    width: 1,
                  ),
                ),
              ),
              SizedBox(width: Responsive.getSpacing(context)),
            ],
            // Category name
            Flexible(
              child: Text(
                category.name,
                style: chipTheme.labelStyle?.copyWith(
                  color: textColor,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: (chipTheme.labelStyle?.fontSize ?? 12) * Responsive.getFontSizeMultiplier(context),
                ) ?? TextStyle(
                  color: textColor,
                  fontSize: 12 * Responsive.getFontSizeMultiplier(context),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Delete button
            if (deletable && onDelete != null) ...[
              SizedBox(width: Responsive.getSpacing(context) / 2),
              GestureDetector(
                onTap: onDelete,
                child: Icon(
                  Icons.close,
                  size: Responsive.getIconSize(context, baseSize: 16),
                  color: textColor.withOpacity(0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
