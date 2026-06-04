import 'package:flutter/material.dart';
import 'package:dual_reader/src/domain/entities/settings_entity.dart';

/// Original text panel widget.
///
/// This panel displays the original text content in a NON-SCROLLABLE format.
/// The text fits exactly within the available space and uses the provided
/// settings for styling (font, size, margins, alignment).
///
/// Features:
/// - Non-scrollable text display
/// - Theme-aware colors (dark/light mode)
/// - Configurable font family, size, line height, and margins
/// - Text alignment support (justified default)
/// - Selectable text for copy functionality
/// - Panel label with collapsible option
class OriginalTextPanel extends StatelessWidget {
  /// The label/title displayed above the text content
  final String label;

  /// The original language name (optional, for display)
  final String? languageName;

  /// The text content to display
  final String content;

  /// The settings entity containing font, size, and layout preferences
  final SettingsEntity settings;

  /// Whether to show the panel label
  final bool showLabel;

  const OriginalTextPanel({
    super.key,
    required this.label,
    this.languageName,
    required this.content,
    required this.settings,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    // Build the text style with settings
    final textStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
      fontSize: settings.fontSize,
      height: settings.lineHeight,
      fontFamily: settings.fontlFamily,
      color: isDark ? colorScheme.onSurface : null,
    );

    // Label text style
    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: isDark
        ? colorScheme.onSurface.withOpacity(0.6)
        : colorScheme.onSurface.withOpacity(0.5),
      fontSize: 11,
    );

    return Container(
      padding: EdgeInsets.all(settings.margin),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: showLabel
          ? Border(
              bottom: BorderSide(
                color: isDark
                  ? colorScheme.outlineVariant.withOpacity(0.3)
                  : colorScheme.outlineVariant.withOpacity(0.5),
                width: 1,
              ),
            )
          : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.max,
        children: [
          // Panel label
          if (showLabel)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  Text(
                    label,
                    style: labelStyle,
                  ),
                  if (languageName != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      '($languageName)',
                      style: labelStyle,
                    ),
                  ],
                ],
              ),
            ),
          // Non-scrollable content that fits exactly
          Expanded(
            child: Align(
              alignment: Alignment.topLeft,
              child: SelectableText(
                content,
                textAlign: settings.textAlign,
                style: textStyle,
                maxLines: null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
