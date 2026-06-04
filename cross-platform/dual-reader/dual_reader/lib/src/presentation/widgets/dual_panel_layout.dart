import 'package:flutter/material.dart';
import 'package:dual_reader/src/domain/entities/settings_entity.dart';
import 'package:dual_reader/src/presentation/widgets/original_text_panel.dart';
import 'package:dual_reader/src/presentation/widgets/translated_text_panel.dart';

/// Dual-panel layout widget for the reader screen.
///
/// Handles responsive layout:
/// - Portrait (width <= 700): Stacked panels (original top, translated bottom)
/// - Landscape (width > 700): Side-by-side panels with adjustable ratio
///
/// The layout uses the panelWidthRatio from settings to determine the
/// relative width of each panel in landscape mode.
///
/// Features:
/// - Responsive design for all screen sizes
/// - Configurable panel width ratio in landscape
/// - Theme-aware panel styling
/// - Language name display support
/// - Collapsible labels in full screen mode
class DualPanelLayout extends StatelessWidget {
  /// Original text content
  final String originalText;

  /// Translated text content
  final String translatedText;

  /// Reader settings (font, size, margins, etc.)
  final SettingsEntity settings;

  /// Original language code (for display)
  final String? originalLanguageCode;

  /// Target translation language code (for display)
  final String? targetLanguageCode;

  /// Whether labels should be shown
  final bool showLabels;

  /// Whether the translation is currently loading
  final bool isTranslationLoading;

  /// Scroll controller for the translated panel
  final ScrollController? translatedScrollController;

  const DualPanelLayout({
    super.key,
    required this.originalText,
    required this.translatedText,
    required this.settings,
    this.originalLanguageCode,
    this.targetLanguageCode,
    this.showLabels = true,
    this.isTranslationLoading = false,
    this.translatedScrollController,
  });

  /// Determine if the layout should be two-pane (landscape)
  static bool isTwoPane(BuildContext context) {
    return MediaQuery.of(context).size.width > 700;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isLandscape = isTwoPane(context);

        if (isLandscape) {
          return _buildLandscapeLayout(context);
        } else {
          return _buildPortraitLayout(context);
        }
      },
    );
  }

  /// Build side-by-side layout for landscape mode
  Widget _buildLandscapeLayout(BuildContext context) {
    // Clamp panel ratio between 0.3 and 0.7 to ensure both panels are usable
    final clampedRatio = settings.panelWidthRatio.clamp(0.3, 0.7);
    final leftFlex = (clampedRatio * 100).round();
    final rightFlex = 100 - leftFlex;

    return Row(
      children: [
        Expanded(
          flex: leftFlex,
          child: OriginalTextPanel(
            label: 'Original',
            languageName: originalLanguageCode,
            content: originalText,
            settings: settings,
            showLabel: showLabels,
          ),
        ),
        // Vertical divider between panels
        VerticalDivider(
          width: 1,
          thickness: 1,
          color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withOpacity(0.1)
            : Colors.black.withOpacity(0.1),
        ),
        Expanded(
          flex: rightFlex,
          child: TranslatedTextPanel(
            label: 'Translated',
            languageName: targetLanguageCode,
            content: translatedText,
            settings: settings,
            showLabel: showLabels,
            scrollController: translatedScrollController,
            isLoading: isTranslationLoading,
          ),
        ),
      ],
    );
  }

  /// Build stacked layout for portrait mode
  Widget _buildPortraitLayout(BuildContext context) {
    return Column(
      children: [
        Expanded(
          flex: 1,
          child: OriginalTextPanel(
            label: 'Original',
            languageName: originalLanguageCode,
            content: originalText,
            settings: settings,
            showLabel: showLabels,
          ),
        ),
        // Horizontal divider between panels
        Divider(
          height: 1,
          thickness: 1,
          color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withOpacity(0.1)
            : Colors.black.withOpacity(0.1),
        ),
        Expanded(
          flex: 1,
          child: TranslatedTextPanel(
            label: 'Translated',
            languageName: targetLanguageCode,
            content: translatedText,
            settings: settings,
            showLabel: showLabels,
            scrollController: translatedScrollController,
            isLoading: isTranslationLoading,
          ),
        ),
      ],
    );
  }
}
