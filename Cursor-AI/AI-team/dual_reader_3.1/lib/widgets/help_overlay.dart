import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/help_service.dart';
import 'package:go_router/go_router.dart';

/// An interactive help overlay that guides users through key features
class HelpOverlay extends StatefulWidget {
  final String featureKey;
  final Widget child;
  final String? customMessage;
  final bool showOnce;

  const HelpOverlay({
    Key? key,
    required this.featureKey,
    required this.child,
    this.customMessage,
    this.showOnce = false,
  }) : super(key: key);

  @override
  State<HelpOverlay> createState() => _HelpOverlayState();
}

class _HelpOverlayState extends State<HelpOverlay> {
  bool _showOverlay = false;
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    if (widget.showOnce) {
      _checkAndShow();
    }
  }

  Future<void> _checkAndShow() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'help_overlay_${widget.featureKey}';
    final hasSeen = prefs.getBool(key) ?? false;

    if (!hasSeen && mounted) {
      setState(() {
        _showOverlay = true;
      });
      _showHelpOverlay();
    }
  }

  void _showHelpOverlay() {
    if (!_showOverlay) return;

    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder: (context) => _HelpOverlayWidget(
        featureKey: widget.featureKey,
        customMessage: widget.customMessage,
        position: offset,
        size: size,
        onDismiss: _dismissOverlay,
        onLearnMore: () {
          _dismissOverlay();
          context.push('/help');
        },
      ),
    );

    overlay.insert(_overlayEntry!);
  }

  void _dismissOverlay() async {
    if (widget.showOnce) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('help_overlay_${widget.featureKey}', true);
    }

    setState(() {
      _showOverlay = false;
    });

    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class _HelpOverlayWidget extends StatelessWidget {
  final String featureKey;
  final String? customMessage;
  final Offset position;
  final Size size;
  final VoidCallback onDismiss;
  final VoidCallback onLearnMore;

  const _HelpOverlayWidget({
    required this.featureKey,
    this.customMessage,
    required this.position,
    required this.size,
    required this.onDismiss,
    required this.onLearnMore,
  });

  @override
  Widget build(BuildContext context) {
    final tooltip = customMessage ?? HelpService.getTooltip(featureKey);
    final screenSize = MediaQuery.of(context).size;
    
    // Determine overlay position (prefer above, fallback to below)
    final showAbove = position.dy > screenSize.height / 2;
    final overlayY = showAbove 
        ? position.dy - 8  // Above the widget
        : position.dy + size.height + 8;  // Below the widget

    return Stack(
      children: [
        // Dimmed background
        Positioned.fill(
          child: GestureDetector(
            onTap: onDismiss,
            child: Container(
              color: Colors.black.withOpacity(0.3),
            ),
          ),
        ),
        // Highlighted area
        Positioned(
          left: position.dx,
          top: position.dy,
          child: Container(
            width: size.width,
            height: size.height,
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.primary,
                width: 3,
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        ),
        // Help message
        Positioned(
          left: 16,
          right: 16,
          top: showAbove ? overlayY - 120 : overlayY,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            color: Theme.of(context).colorScheme.surface,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Help Tip',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: onDismiss,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tooltip,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: onDismiss,
                        child: const Text('Got it'),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: onLearnMore,
                        child: const Text('Learn More'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A widget that shows a help indicator badge
class HelpBadge extends StatelessWidget {
  final String featureKey;
  final VoidCallback? onTap;

  const HelpBadge({
    Key? key,
    required this.featureKey,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? () => context.push('/help'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.help_outline,
              size: 14,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: 4),
            Text(
              'Help',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
