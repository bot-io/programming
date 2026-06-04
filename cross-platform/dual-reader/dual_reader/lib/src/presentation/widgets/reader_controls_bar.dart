import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dual_reader/src/core/utils/logging_service.dart';

/// Reader controls bar widget.
///
/// Provides a comprehensive controls bar for the reader screen with:
/// - Previous/Next navigation buttons
/// - Page slider with percentage display
/// - Page number input field
/// - Settings button
/// - Chapter/TOC button
/// - Close book button
///
/// Features:
/// - Smooth slide-in/slide-out animation
/// - Theme-aware styling
/// - Haptic feedback on tap (mobile)
/// - Page input validation
class ReaderControlsBar extends StatefulWidget {
  /// Current page number (0-indexed)
  final int currentPage;

  /// Total number of pages
  final int totalPages;

  /// Callback when previous page is requested
  final VoidCallback? onPreviousPage;

  /// Callback when next page is requested
  final VoidCallback? onNextPage;

  /// Callback when page is changed via slider
  final ValueChanged<int>? onPageChanged;

  /// Callback when settings is requested
  final VoidCallback? onSettings;

  /// Callback when chapter drawer is requested
  final VoidCallback? onChapterDrawer;

  /// Callback when close book is requested
  final VoidCallback? onClose;

  /// Whether the controls bar is visible
  final bool visible;

  /// Whether chapters are available
  final bool hasChapters;

  const ReaderControlsBar({
    super.key,
    required this.currentPage,
    required this.totalPages,
    this.onPreviousPage,
    this.onNextPage,
    this.onPageChanged,
    this.onSettings,
    this.onChapterDrawer,
    this.onClose,
    this.visible = true,
    this.hasChapters = false,
  });

  @override
  State<ReaderControlsBar> createState() => _ReaderControlsBarState();
}

class _ReaderControlsBarState extends State<ReaderControlsBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  // Page input controller
  final TextEditingController _pageInputController = TextEditingController();
  final FocusNode _pageInputFocusNode = FocusNode();

  // Slider drag state
  bool _isSliderDragging = false;
  int? _pendingPageDuringDrag;

  @override
  void initState() {
    super.initState();

    // Initialize animation controller
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );

    // Create slide animation (from bottom)
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1), // Start from bottom
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    // Create fade animation
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    // Start visible if widget is visible
    if (widget.visible) {
      _animationController.forward();
    }
  }

  @override
  void didUpdateWidget(ReaderControlsBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update animation based on visibility
    if (widget.visible != oldWidget.visible) {
      if (widget.visible) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }

    // Update page input when current page changes externally
    if (widget.currentPage != oldWidget.currentPage && !_pageInputFocusNode.hasFocus) {
      _pageInputController.text = (widget.currentPage + 1).toString();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pageInputController.dispose();
    _pageInputFocusNode.dispose();
    super.dispose();
  }

  /// Trigger haptic feedback (light impact)
  void _triggerHapticFeedback() {
    try {
      HapticFeedback.lightImpact();
    } catch (e) {
      LoggingService.warning('ReaderControlsBar', 'Haptic feedback not available: $e');
    }
  }

  /// Handle previous page button press
  void _handlePreviousPage() {
    _triggerHapticFeedback();
    LoggingService.debug('ReaderControlsBar', 'Previous page pressed');
    widget.onPreviousPage?.call();
  }

  /// Handle next page button press
  void _handleNextPage() {
    _triggerHapticFeedback();
    LoggingService.debug('ReaderControlsBar', 'Next page pressed');
    widget.onNextPage?.call();
  }

  /// Handle settings button press
  void _handleSettings() {
    _triggerHapticFeedback();
    LoggingService.debug('ReaderControlsBar', 'Settings pressed');
    widget.onSettings?.call();
  }

  /// Handle chapter drawer button press
  void _handleChapterDrawer() {
    _triggerHapticFeedback();
    LoggingService.debug('ReaderControlsBar', 'Chapter drawer pressed');
    widget.onChapterDrawer?.call();
  }

  /// Handle close button press
  void _handleClose() {
    _triggerHapticFeedback();
    LoggingService.debug('ReaderControlsBar', 'Close pressed');
    widget.onClose?.call();
  }

  /// Handle slider drag start
  void _handleSliderStart(double value) {
    LoggingService.debug('ReaderControlsBar', 'Slider drag started');
    setState(() {
      _isSliderDragging = true;
      _pendingPageDuringDrag = value.round();
    });
  }

  /// Handle slider drag change
  void _handleSliderChange(double value) {
    final newPage = value.round();
    LoggingService.debug('ReaderControlsBar', 'Slider dragging to page $newPage');
    setState(() {
      _pendingPageDuringDrag = newPage;
    });
    widget.onPageChanged?.call(newPage);
  }

  /// Handle slider drag end
  void _handleSliderEnd(double value) {
    final finalPage = value.round();
    LoggingService.info('ReaderControlsBar', 'Slider drag ended at page $finalPage');
    _triggerHapticFeedback();
    setState(() {
      _isSliderDragging = false;
      _pendingPageDuringDrag = null;
    });
    widget.onPageChanged?.call(finalPage);
  }

  /// Handle page input submission
  void _handlePageInputSubmit(String value) {
    final pageNum = int.tryParse(value);
    if (pageNum != null && pageNum >= 1 && pageNum <= widget.totalPages) {
      LoggingService.info('ReaderControlsBar', 'Page input submitted: $pageNum');
      _triggerHapticFeedback();
      widget.onPageChanged?.call(pageNum - 1); // Convert to 0-indexed
      _pageInputFocusNode.unfocus();
    } else {
      LoggingService.warning('ReaderControlsBar', 'Invalid page input: $value');
      // Reset to current page
      _pageInputController.text = (widget.currentPage + 1).toString();
      _triggerHapticFeedback();
    }
  }

  /// Calculate progress percentage
  double get progressPercentage {
    if (widget.totalPages <= 0) return 0.0;
    final displayPage = _isSliderDragging && _pendingPageDuringDrag != null
        ? _pendingPageDuringDrag!
        : widget.currentPage;
    return ((displayPage + 1) / widget.totalPages * 100);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          decoration: BoxDecoration(
            color: isDark
              ? colorScheme.surfaceContainerHighest.withOpacity(0.95)
              : colorScheme.surfaceContainerHighest.withOpacity(0.95),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Page slider section
                _buildSliderSection(context, colorScheme, isDark),
                // Controls buttons section
                _buildControlsSection(context, colorScheme, isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSliderSection(BuildContext context, ColorScheme colorScheme, bool isDark) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Percentage indicator (shown during drag)
        if (_isSliderDragging && _pendingPageDuringDrag != null)
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? colorScheme.surfaceContainer : colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${progressPercentage.toStringAsFixed(0)}%',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? colorScheme.onSurface : colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        // Page slider
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              // Page input field
              SizedBox(
                width: 50,
                child: TextField(
                  controller: _pageInputController,
                  focusNode: _pageInputFocusNode,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? colorScheme.onSurface : colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDark ? colorScheme.outline : colorScheme.outline,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: colorScheme.primary,
                        width: 2,
                      ),
                    ),
                  ),
                  onSubmitted: _handlePageInputSubmit,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '/ ${widget.totalPages}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark ? colorScheme.onSurface : colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 16),
              // Slider
              Expanded(
                child: Slider(
                  value: _isSliderDragging && _pendingPageDuringDrag != null
                      ? _pendingPageDuringDrag!.toDouble()
                      : widget.currentPage.toDouble(),
                  min: 0,
                  max: (widget.totalPages > 0 ? widget.totalPages - 1 : 0).toDouble(),
                  divisions: widget.totalPages > 1 ? widget.totalPages : 1,
                  label: 'Page ${(_isSliderDragging && _pendingPageDuringDrag != null ? _pendingPageDuringDrag! : widget.currentPage) + 1} of ${widget.totalPages}',
                  onChangeStart: _handleSliderStart,
                  onChanged: _handleSliderChange,
                  onChangeEnd: _handleSliderEnd,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildControlsSection(BuildContext context, ColorScheme colorScheme, bool isDark) {
    final theme = Theme.of(context);
    final currentPage = _isSliderDragging && _pendingPageDuringDrag != null
        ? _pendingPageDuringDrag!
        : widget.currentPage;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Previous page button
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 20),
            color: currentPage > 0
              ? (isDark ? colorScheme.onSurface : colorScheme.onSurface)
              : (isDark ? colorScheme.onSurface.withOpacity(0.3) : colorScheme.onSurface.withOpacity(0.3)),
            onPressed: currentPage > 0 ? _handlePreviousPage : null,
          ),
          // Page info display
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Page ${currentPage + 1} of ${widget.totalPages}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? colorScheme.onSurface : colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${progressPercentage.toStringAsFixed(1)}%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark
                      ? colorScheme.onSurface.withOpacity(0.7)
                      : colorScheme.onSurface.withOpacity(0.6),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          // Next page button
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios, size: 20),
            color: currentPage < widget.totalPages - 1
              ? (isDark ? colorScheme.onSurface : colorScheme.onSurface)
              : (isDark ? colorScheme.onSurface.withOpacity(0.3) : colorScheme.onSurface.withOpacity(0.3)),
            onPressed: currentPage < widget.totalPages - 1 ? _handleNextPage : null,
          ),
          // Settings button
          IconButton(
            icon: const Icon(Icons.settings),
            color: isDark ? colorScheme.onSurface : colorScheme.onSurface,
            onPressed: _handleSettings,
            tooltip: 'Settings',
          ),
          // Chapter drawer button
          if (widget.hasChapters)
            IconButton(
              icon: const Icon(Icons.list_alt),
              color: isDark ? colorScheme.onSurface : colorScheme.onSurface,
              onPressed: _handleChapterDrawer,
              tooltip: 'Table of Contents',
            ),
          // Close button
          IconButton(
            icon: const Icon(Icons.close),
            color: isDark ? colorScheme.onSurface : colorScheme.onSurface,
            onPressed: _handleClose,
            tooltip: 'Close Book',
          ),
        ],
      ),
    );
  }
}

/// Compact version of the reader controls bar.
///
/// Shows minimal controls with smaller footprint for mobile devices.
class ReaderControlsBarCompact extends StatelessWidget {
  /// Current page number (0-indexed)
  final int currentPage;

  /// Total number of pages
  final int totalPages;

  /// Callback when previous page is requested
  final VoidCallback? onPreviousPage;

  /// Callback when next page is requested
  final VoidCallback? onNextPage;

  /// Callback when page is changed via slider
  final ValueChanged<int>? onPageChanged;

  /// Callback when settings is requested
  final VoidCallback? onSettings;

  /// Callback when chapter drawer is requested
  final VoidCallback? onChapterDrawer;

  /// Callback when close book is requested
  final VoidCallback? onClose;

  /// Whether chapters are available
  final bool hasChapters;

  const ReaderControlsBarCompact({
    super.key,
    required this.currentPage,
    required this.totalPages,
    this.onPreviousPage,
    this.onNextPage,
    this.onPageChanged,
    this.onSettings,
    this.onChapterDrawer,
    this.onClose,
    this.hasChapters = false,
  });

  @override
  Widget build(BuildContext context) {
    // Use the full controls bar for now
    // Can be customized for a more compact layout later
    return ReaderControlsBar(
      currentPage: currentPage,
      totalPages: totalPages,
      onPreviousPage: onPreviousPage,
      onNextPage: onNextPage,
      onPageChanged: onPageChanged,
      onSettings: onSettings,
      onChapterDrawer: onChapterDrawer,
      onClose: onClose,
      hasChapters: hasChapters,
      visible: true,
    );
  }
}
