import 'package:flutter/material.dart';
import 'package:simplenotes/utils/responsive.dart';

/// A reusable widget for displaying empty list states.
/// 
/// This widget displays an icon, a message, and optionally an action button
/// to help users understand what to do when a list is empty.
class EmptyState extends StatelessWidget {
  /// The icon to display above the message.
  final IconData icon;

  /// The main message to display.
  final String message;

  /// Optional subtitle text displayed below the main message.
  final String? subtitle;

  /// Optional action button widget.
  /// 
  /// If provided, this button will be displayed below the message.
  /// Typically used for actions like "Create Note" or "Add Category".
  final Widget? actionButton;

  /// Optional callback for when the action button is pressed.
  /// 
  /// If both [actionButton] and [onActionPressed] are provided,
  /// [actionButton] takes precedence.
  final VoidCallback? onActionPressed;

  /// Optional text for the action button.
  /// 
  /// If provided along with [onActionPressed], a default button will be created.
  final String? actionText;

  /// The size of the icon. If null, uses responsive sizing.
  final double? iconSize;

  /// The spacing between elements. If null, uses responsive spacing.
  final double? spacing;

  /// Creates an [EmptyState] widget.
  /// 
  /// The [icon] and [message] parameters are required.
  /// 
  /// Example:
  /// ```dart
  /// EmptyState(
  ///   icon: Icons.note_outlined,
  ///   message: 'No notes yet',
  ///   subtitle: 'Create your first note to get started',
  ///   actionText: 'Create Note',
  ///   onActionPressed: () => Navigator.push(...),
  /// )
  /// ```
  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.subtitle,
    this.actionButton,
    this.onActionPressed,
    this.actionText,
    this.iconSize,
    this.spacing,
  }) : assert(
          actionButton == null || onActionPressed == null,
          'Cannot provide both actionButton and onActionPressed',
        );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final responsiveIconSize = iconSize ?? Responsive.getEmptyStateIconSize(context);
    final responsiveSpacing = spacing ?? Responsive.getEmptyStateSpacing(context);
    final padding = Responsive.getPadding(context);
    final fontSizeMultiplier = Responsive.getFontSizeMultiplier(context);

    return Center(
      child: Padding(
        padding: padding,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: Responsive.getMaxContentWidth(context),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: responsiveIconSize,
                color: colorScheme.onSurfaceVariant,
              ),
              SizedBox(height: responsiveSpacing),
              Text(
                message,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                  fontSize: theme.textTheme.titleMedium?.fontSize != null
                      ? theme.textTheme.titleMedium!.fontSize! * fontSizeMultiplier
                      : null,
                ),
                textAlign: TextAlign.center,
              ),
              if (subtitle != null) ...[
                SizedBox(height: responsiveSpacing / 2),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                    fontSize: theme.textTheme.bodyMedium?.fontSize != null
                        ? theme.textTheme.bodyMedium!.fontSize! * fontSizeMultiplier
                        : null,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (actionButton != null) ...[
                SizedBox(height: responsiveSpacing * 1.5),
                actionButton!,
              ] else if (onActionPressed != null && actionText != null) ...[
                SizedBox(height: responsiveSpacing * 1.5),
                FilledButton.icon(
                  onPressed: onActionPressed,
                  icon: Icon(Icons.add, size: Responsive.getIconSize(context, baseSize: 20)),
                  label: Text(actionText!),
                  style: FilledButton.styleFrom(
                    padding: Responsive.getButtonPadding(context),
                  ),
                ),
              ] else if (onActionPressed != null) ...[
                SizedBox(height: responsiveSpacing * 1.5),
                FilledButton(
                  onPressed: onActionPressed,
                  style: FilledButton.styleFrom(
                    padding: Responsive.getButtonPadding(context),
                  ),
                  child: Icon(Icons.add, size: Responsive.getIconSize(context, baseSize: 20)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
