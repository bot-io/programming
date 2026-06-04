import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dual_reader/src/core/utils/logging_service.dart';

/// Tap zone configuration
class TapZoneConfig {
  /// Width percentage for left zone (default 0.2 = 20%)
  final double leftZonePercentage;

  /// Width percentage for right zone (default 0.2 = 20%)
  final double rightZonePercentage;

  /// Minimum tap duration to consider as tap (vs long press)
  final Duration minTapDuration;

  /// Maximum tap duration to consider as tap (vs long press)
  final Duration maxTapDuration;

  /// Maximum movement allowed during tap (in pixels)
  final double maxTapMovement;

  /// Whether to enable haptic feedback
  final bool hapticFeedbackEnabled;

  /// Whether to enable debug visualization
  final bool debugMode;

  const TapZoneConfig({
    this.leftZonePercentage = 0.2,
    this.rightZonePercentage = 0.2,
    this.minTapDuration = const Duration(milliseconds: 50),
    this.maxTapDuration = const Duration(milliseconds: 300),
    this.maxTapMovement = 20.0,
    this.hapticFeedbackEnabled = true,
    this.debugMode = false,
  });
}

/// Tap zone type enumeration
enum TapZone {
  left,
  middle,
  right,
}

/// Tap zone detector widget.
///
/// Provides advanced tap zone detection with:
/// - Distinguishing tap from drag/long press
/// - Multi-touch scenario handling
/// - Preventing accidental page turns
/// - Haptic feedback on tap (mobile)
/// - Debug visualization
///
/// Zones:
/// - Left zone (default 20%): Previous page
/// - Middle zone (default 60%): Toggle controls
/// - Right zone (default 20%): Next page
class TapZoneDetector extends StatefulWidget {
  /// Callback when left zone is tapped
  final VoidCallback? onLeftZoneTap;

  /// Callback when middle zone is tapped
  final VoidCallback? onMiddleZoneTap;

  /// Callback when right zone is tapped
  final VoidCallback? onRightZoneTap;

  /// Child widget (the content underneath)
  final Widget? child;

  /// Tap zone configuration
  final TapZoneConfig config;

  const TapZoneDetector({
    super.key,
    this.onLeftZoneTap,
    this.onMiddleZoneTap,
    this.onRightZoneTap,
    this.child,
    this.config = const TapZoneConfig(),
  });

  @override
  State<TapZoneDetector> createState() => _TapZoneDetectorState();
}

class _TapZoneDetectorState extends State<TapZoneDetector> {
  // Tap tracking state
  TapDownDetails? _tapDownDetails;
  DateTime? _tapStartTime;

  // Multi-touch tracking
  final Set<int> _activePointers = {};

  // Current zone being touched
  TapZone? _currentZone;

  /// Trigger haptic feedback
  void _triggerHapticFeedback() {
    if (!widget.config.hapticFeedbackEnabled) return;

    try {
      HapticFeedback.lightImpact();
    } catch (e) {
      LoggingService.warning('TapZoneDetector', 'Haptic feedback not available: $e');
    }
  }

  /// Determine which zone was tapped based on x position
  TapZone _getZoneForPosition(double x, double screenWidth) {
    final leftThreshold = screenWidth * widget.config.leftZonePercentage;
    final rightThreshold = screenWidth * (1 - widget.config.rightZonePercentage);

    if (x < leftThreshold) {
      return TapZone.left;
    } else if (x > rightThreshold) {
      return TapZone.right;
    } else {
      return TapZone.middle;
    }
  }

  /// Handle tap down event
  void _handleTapDown(TapDownDetails details) {
    _tapDownDetails = details;
    _tapStartTime = DateTime.now();
    _currentZone = _getZoneForPosition(
      details.globalPosition.dx,
      MediaQuery.of(context).size.width,
    );
  }

  /// Handle tap up event
  void _handleTapUp(TapUpDetails details) {
    if (_tapDownDetails == null || _tapStartTime == null) return;

    final tapDuration = DateTime.now().difference(_tapStartTime!);
    final movement = (details.globalPosition - _tapDownDetails!.globalPosition).distance;

    // Check if this is a valid tap (not a drag or long press)
    if (tapDuration >= widget.config.minTapDuration &&
        tapDuration <= widget.config.maxTapDuration &&
        movement <= widget.config.maxTapMovement) {

      final zone = _getZoneForPosition(
        details.globalPosition.dx,
        MediaQuery.of(context).size.width,
      );

      _handleZoneTap(zone);
    }

    // Reset state
    _tapDownDetails = null;
    _tapStartTime = null;
    _currentZone = null;
  }

  /// Handle tap cancel event
  void _handleTapCancel() {
    _tapDownDetails = null;
    _tapStartTime = null;
    _currentZone = null;
  }

  /// Handle zone tap
  void _handleZoneTap(TapZone zone) {
    _triggerHapticFeedback();

    switch (zone) {
      case TapZone.left:
        LoggingService.debug('TapZoneDetector', 'Left zone tapped');
        widget.onLeftZoneTap?.call();
        break;
      case TapZone.middle:
        LoggingService.debug('TapZoneDetector', 'Middle zone tapped');
        widget.onMiddleZoneTap?.call();
        break;
      case TapZone.right:
        LoggingService.debug('TapZoneDetector', 'Right zone tapped');
        widget.onRightZoneTap?.call();
        break;
    }
  }

  /// Handle pointer down (for multi-touch support)
  void _handlePointerDown(PointerDownEvent event) {
    setState(() {
      _activePointers.add(event.pointer);
    });
  }

  /// Handle pointer up (for multi-touch support)
  void _handlePointerUp(PointerUpEvent event) {
    setState(() {
      _activePointers.remove(event.pointer);
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Stack(
      children: [
        // Child widget (content)
        if (widget.child != null) widget.child!,

        // Debug visualization
        if (widget.config.debugMode)
          Stack(
            children: [
              // Left zone
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: screenWidth * widget.config.leftZonePercentage,
                child: Container(
                  color: Colors.red.withOpacity(0.2),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.arrow_back_ios, color: Colors.black, size: 32),
                        Text(
                          'PREV\n${(widget.config.leftZonePercentage * 100).toInt()}%',
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Middle zone
              Positioned(
                left: screenWidth * widget.config.leftZonePercentage,
                right: screenWidth * widget.config.rightZonePercentage,
                top: 0,
                bottom: 0,
                child: Container(
                  color: Colors.yellow.withOpacity(0.1),
                  child: Center(
                    child: Text(
                      'TOGGLE\n${((1 - widget.config.leftZonePercentage - widget.config.rightZonePercentage) * 100).toInt()}%',
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
              // Right zone
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: screenWidth * widget.config.rightZonePercentage,
                child: Container(
                  color: Colors.green.withOpacity(0.2),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.arrow_forward_ios, color: Colors.black, size: 32),
                        Text(
                          'NEXT\n${(widget.config.rightZonePercentage * 100).toInt()}%',
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

        // Zone detectors
        // Left zone - opaque behavior for reliable tap detection
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: screenWidth * widget.config.leftZonePercentage,
          child: GestureDetector(
            onTap: () => _handleZoneTap(TapZone.left),
            behavior: HitTestBehavior.opaque,
            // Prevent text selection interference
            excludeFromSemantics: true,
          ),
        ),

        // Right zone - opaque behavior for reliable tap detection
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          width: screenWidth * widget.config.rightZonePercentage,
          child: GestureDetector(
            onTap: () => _handleZoneTap(TapZone.right),
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
          ),
        ),

        // Middle zone - translucent to allow text selection
        Positioned(
          left: screenWidth * widget.config.leftZonePercentage,
          right: screenWidth * widget.config.rightZonePercentage,
          top: 0,
          bottom: 0,
          child: Listener(
            onPointerDown: _handlePointerDown,
            onPointerUp: _handlePointerUp,
            behavior: HitTestBehavior.translucent,
            child: GestureDetector(
              onTapDown: _handleTapDown,
              onTapUp: _handleTapUp,
              onTapCancel: _handleTapCancel,
              // Only tap in middle zone toggles controls
              behavior: HitTestBehavior.translucent,
              excludeFromSemantics: true,
            ),
          ),
        ),

        // Multi-touch indicator (debug)
        if (widget.config.debugMode && _activePointers.isNotEmpty)
          Positioned(
            top: 100,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Active pointers: ${_activePointers.length}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Keyboard handler for web/desktop platforms.
///
/// Provides keyboard shortcuts:
/// - Arrow Left/Up: Previous page
/// - Arrow Right/Down: Next page
/// - Space: Next page
/// - Escape: Exit full screen / close book
class KeyboardHandler extends StatelessWidget {
  /// Callback when previous page is requested
  final VoidCallback? onPreviousPage;

  /// Callback when next page is requested
  final VoidCallback? onNextPage;

  /// Callback when escape is pressed
  final VoidCallback? onEscape;

  /// Child widget
  final Widget child;

  const KeyboardHandler({
    super.key,
    this.onPreviousPage,
    this.onNextPage,
    this.onEscape,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // Only enable on web/desktop platforms
    if (Platform.isAndroid || Platform.isIOS) {
      return child;
    }

    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      autofocus: true,
      onKeyEvent: (event) {
        // Only handle key down events
        if (event is! KeyDownEvent) return;

        switch (event.logicalKey) {
          case LogicalKeyboardKey.arrowLeft:
          case LogicalKeyboardKey.arrowUp:
            LoggingService.debug('KeyboardHandler', 'Previous page via keyboard');
            onPreviousPage?.call();
            break;

          case LogicalKeyboardKey.arrowRight:
          case LogicalKeyboardKey.arrowDown:
          case LogicalKeyboardKey.space:
            LoggingService.debug('KeyboardHandler', 'Next page via keyboard');
            onNextPage?.call();
            break;

          case LogicalKeyboardKey.escape:
            LoggingService.debug('KeyboardHandler', 'Escape pressed');
            onEscape?.call();
            break;
        }
      },
      child: child,
    );
  }
}
