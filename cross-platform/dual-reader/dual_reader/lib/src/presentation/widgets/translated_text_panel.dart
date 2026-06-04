import 'package:flutter/material.dart';
import 'package:dual_reader/src/domain/entities/settings_entity.dart';

/// Translated text panel widget.
///
/// This panel displays the translated text content in a SCROLLABLE format.
/// The translation can be longer than the original text, so this panel
/// has independent scrolling capability.
///
/// Features:
/// - Independently scrollable text display
/// - Theme-aware colors (dark/light mode)
/// - Configurable font, size, line height, and margins
/// - Text alignment support
/// - Selectable text for copy functionality
/// - Panel label with target language name
/// - Loading state support
class TranslatedTextPanel extends StatelessWidget {
  /// The label/title displayed above the text content
  final String label;

  /// The target language name for display
  final String? languageName;

  /// The translated text content to display
  final String content;

  /// The settings entity containing font, size, and layout preferences
  final SettingsEntity settings;

  /// Whether to show the panel label
  final bool showLabel;

  /// Scroll controller for the panel
  final ScrollController? scrollController;

  /// Whether the content is currently loading
  final bool isLoading;

  const TranslatedTextPanel({
    super.key,
    required this.label,
    this.languageName,
    required this.content,
    required this.settings,
    this.showLabel = true,
    this.scrollController,
    this.isLoading = false,
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
                  const SizedBox(width: 8),
                  if (isLoading)
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: isDark ? colorScheme.primary : colorScheme.primary,
                      ),
                    ),
                ],
              ),
            ),
          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              controller: scrollController,
              child: Align(
                alignment: Alignment.topLeft,
                child: SelectableText(
                  isLoading ? 'Translating...' : content,
                  textAlign: settings.textAlign,
                  style: textStyle?.copyWith(
                    color: isLoading
                      ? (isDark ? colorScheme.onSurface.withOpacity(0.4) : colorScheme.onSurface.withOpacity(0.4))
                      : null,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
