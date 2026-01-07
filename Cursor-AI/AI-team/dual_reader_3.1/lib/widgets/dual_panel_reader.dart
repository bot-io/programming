import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/page_content.dart';
import '../models/app_settings.dart';
import '../services/help_service.dart';
import 'rich_text_renderer.dart';

class DualPanelReader extends StatefulWidget {
  final PageContent page;
  final AppSettings settings;
  final VoidCallback? onNextPage;
  final VoidCallback? onPreviousPage;
  final Function(int)? onPageChanged;
  final ScrollController? originalScrollController;
  final ScrollController? translatedScrollController;

  const DualPanelReader({
    Key? key,
    required this.page,
    required this.settings,
    this.onNextPage,
    this.onPreviousPage,
    this.onPageChanged,
    this.originalScrollController,
    this.translatedScrollController,
  }) : super(key: key);

  @override
  State<DualPanelReader> createState() => _DualPanelReaderState();
}

class _DualPanelReaderState extends State<DualPanelReader> {
  late ScrollController _originalController;
  late ScrollController _translatedController;
  bool _isPortrait = true;

  @override
  void initState() {
    super.initState();
    _originalController = widget.originalScrollController ?? ScrollController();
    _translatedController = widget.translatedScrollController ?? ScrollController();
    
    if (widget.settings.syncScrolling) {
      _originalController.addListener(_syncOriginalScroll);
      _translatedController.addListener(_syncTranslatedScroll);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final orientation = MediaQuery.of(context).orientation;
    _isPortrait = orientation == Orientation.portrait;
  }

  @override
  void dispose() {
    if (widget.settings.syncScrolling) {
      _originalController.removeListener(_syncOriginalScroll);
      _translatedController.removeListener(_syncTranslatedScroll);
    }
    if (widget.originalScrollController == null) {
      _originalController.dispose();
    }
    if (widget.translatedScrollController == null) {
      _translatedController.dispose();
    }
    super.dispose();
  }

  void _syncOriginalScroll() {
    if (!_translatedController.hasClients) return;
    final ratio = _translatedController.position.maxScrollExtent / 
                  _originalController.position.maxScrollExtent;
    if (ratio > 0) {
      _translatedController.jumpTo(_originalController.offset * ratio);
    }
  }

  void _syncTranslatedScroll() {
    if (!_originalController.hasClients) return;
    final ratio = _originalController.position.maxScrollExtent / 
                  _translatedController.position.maxScrollExtent;
    if (ratio > 0) {
      _originalController.jumpTo(_translatedController.offset * ratio);
    }
  }

  Widget _buildTextContent(String text, Color textColor, bool isOriginal) {
    // Check if we have HTML content for this page
    final htmlContent = isOriginal 
        ? widget.page.originalHtml 
        : widget.page.translatedHtml;
    
    final baseStyle = TextStyle(
      fontFamily: widget.settings.fontFamily,
      fontSize: widget.settings.fontSize.toDouble(),
      height: widget.settings.lineHeight,
      color: textColor,
    );
    
    if (htmlContent != null && htmlContent.isNotEmpty) {
      // Use rich text renderer for HTML content
      return RichTextRenderer(
        htmlContent: htmlContent,
        baseStyle: baseStyle,
        textAlign: _getTextAlign(widget.settings.textAlignment),
      );
    } else {
      // Fallback to plain text with basic formatting support
      return FormattedTextRenderer(
        text: text,
        baseStyle: baseStyle,
        textAlign: _getTextAlign(widget.settings.textAlignment),
      );
    }
  }

  Widget _buildTextPanel({
    required String text,
    required String label,
    required Color backgroundColor,
    required Color textColor,
    required ScrollController scrollController,
    required bool isOriginal,
  }) {
    return Container(
      color: backgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Tooltip(
              message: label == 'Original' 
                  ? HelpService.getTooltip('dual_panel')
                  : HelpService.getTooltip('reading_mode'),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: textColor.withOpacity(0.7),
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: scrollController,
              padding: EdgeInsets.all(_getMarginSize(widget.settings.marginSize)),
              child: _buildTextContent(text, textColor, isOriginal),
            ),
          ),
        ],
      ),
    );
  }

  TextAlign _getTextAlign(String alignment) {
    switch (alignment) {
      case 'center':
        return TextAlign.center;
      case 'justify':
        return TextAlign.justify;
      case 'left':
      default:
        return TextAlign.left;
    }
  }

  double _getMarginSize(int marginSize) {
    switch (marginSize) {
      case 0:
        return 8.0;
      case 1:
        return 16.0;
      case 2:
        return 24.0;
      case 3:
        return 32.0;
      case 4:
        return 40.0;
      default:
        return 24.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final originalBg = theme.colorScheme.surface;
    final translatedBg = theme.colorScheme.surfaceVariant;
    final textColor = theme.colorScheme.onSurface;

    if (_isPortrait) {
      // Stacked layout for portrait
      return Column(
        children: [
          Expanded(
            flex: 1,
            child: _buildTextPanel(
              text: widget.page.originalText,
              label: 'Original',
              backgroundColor: originalBg,
              textColor: textColor,
              scrollController: _originalController,
              isOriginal: true,
            ),
          ),
          Container(
            height: 1,
            color: theme.colorScheme.outline,
          ),
          Expanded(
            flex: 1,
            child: _buildTextPanel(
              text: widget.page.translatedText ?? 'Translating...',
              label: 'Translated',
              backgroundColor: translatedBg,
              textColor: textColor,
              scrollController: _translatedController,
              isOriginal: false,
            ),
          ),
        ],
      );
    } else {
      // Side-by-side layout for landscape
      return Row(
        children: [
          Expanded(
            flex: (widget.settings.panelRatio * 10).round(),
            child: _buildTextPanel(
              text: widget.page.originalText,
              label: 'Original',
              backgroundColor: originalBg,
              textColor: textColor,
              scrollController: _originalController,
              isOriginal: true,
            ),
          ),
          Container(
            width: 1,
            color: theme.colorScheme.outline,
          ),
          Expanded(
            flex: ((1 - widget.settings.panelRatio) * 10).round(),
            child: _buildTextPanel(
              text: widget.page.translatedText ?? 'Translating...',
              label: 'Translated',
              backgroundColor: translatedBg,
              textColor: textColor,
              scrollController: _translatedController,
              isOriginal: false,
            ),
          ),
        ],
      );
    }
  }
}
