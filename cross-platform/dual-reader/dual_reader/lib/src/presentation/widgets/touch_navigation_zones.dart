import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:dual_reader/src/core/utils/logging_service.dart';

/// Touch navigation zones overlay for the dual reader screen.
///
/// Provides invisible touch zones for navigation:
/// - Left 20%: Previous page
/// - Right 20%: Next page
/// - Middle 60%: Toggle controls (passed through callback)
///
/// The middle zone uses translucent behavior to allow text selection
/// while the outer zones use opaque behavior for reliable tap detection.
///
/// Features:
/// - Configurable zone percentages (default 20/60/20)
/// - Visual feedback on tap (optional)
/// - Debug mode for zone visualization
/// - Prevents interference with text selection in middle zone
class TouchNavigationZones extends StatelessWidget {
  /// Callback when previous page zone is tapped
  final VoidCallback? onPreviousPage;

  /// Callback when next page zone is tapped
  final VoidCallback? onNextPage;

  /// Callback when middle zone is tapped
  final VoidCallback? onToggleControls;

  /// Width percentage for left zone (default 0.2 = 20%)
  final double leftZonePercentage;

  /// Width percentage for right zone (default 0.2 = 20%)
  final double rightZonePercentage;

  /// Whether to show debug overlays for zones
  final bool debugMode;

  const TouchNavigationZones({
    super.key,
    this.onPreviousPage,
    this.onNextPage,
    this.onToggleControls,
    this.leftZonePercentage = 0.2,
    this.rightZonePercentage = 0.2,
    this.debugMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Stack(
      children: [
        // Middle zone (for toggling controls) - translucent to allow text selection
        Positioned(
          left: screenWidth * leftZonePercentage,
          right: screenWidth * rightZonePercentage,
          top: 0,
          bottom: 0,
          child: GestureDetector(
            onTap: () {
              LoggingService.debug('TouchNavigationZones', 'Middle area tapped - toggling controls');
              onToggleControls?.call();
            },
            behavior: HitTestBehavior.translucent,
            child: debugMode
              ? Container(
                  color: Colors.yellow.withOpacity(0.1),
                  child: const Center(
                    child: Text(
                      'TOGGLE\n(60%)',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : null,
          ),
        ),
        // Left margin zone for previous page navigation
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: screenWidth * leftZonePercentage,
          child: GestureDetector(
            onTap: () {
              LoggingService.debug('TouchNavigationZones', 'Left margin tapped - previous page');
              onPreviousPage?.call();
            },
            behavior: HitTestBehavior.opaque,
            child: debugMode
              ? Container(
                  color: Colors.red.withOpacity(0.2),
                  child: const Center(
                    child: Icon(
                      Icons.arrow_back_ios,
                      color: Colors.black,
                      size: 32,
                    ),
                  ),
                )
              : null,
          ),
        ),
        // Right margin zone for next page navigation
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          width: screenWidth * rightZonePercentage,
          child: GestureDetector(
            onTap: () {
              LoggingService.debug('TouchNavigationZones', 'Right margin tapped - next page');
              onNextPage?.call();
            },
            behavior: HitTestBehavior.opaque,
            child: debugMode
              ? Container(
                  color: Colors.green.withOpacity(0.2),
                  child: const Center(
                    child: Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.black,
                      size: 32,
                    ),
                  ),
                )
              : null,
          ),
        ),
      ],
    );
  }
}

/// Alternative implementation using TapDownDetails for more precise control.
///
/// This version uses a single GestureDetector and calculates tap position
/// to determine which zone was tapped.
class TouchNavigationZonesUnified extends StatelessWidget {
  /// Callback when previous page zone is tapped
  final VoidCallback? onPreviousPage;

  /// Callback when next page zone is tapped
  final VoidCallback? onNextPage;

  /// Callback when middle zone is tapped
  final VoidCallback? onToggleControls;

  /// Width percentage for left zone (default 0.2 = 20%)
  final double leftZonePercentage;

  /// Width percentage for right zone (default 0.2 = 20%)
  final double rightZonePercentage;

  const TouchNavigationZonesUnified({
    super.key,
    this.onPreviousPage,
    this.onNextPage,
    this.onToggleControls,
    this.leftZonePercentage = 0.2,
    this.rightZonePercentage = 0.2,
  });

  void _handleTapDown(TapDownDetails details) {
    final screenWidth = details.globalPosition.dx; // Use screen width
    final position = details.globalPosition.dx;
    final totalWidth = MediaQuery.of(NavigationService.navigatorKey.currentContext!).size.width;

    // Left 20% - previous page
    // Right 20% - next page
    // Middle 60% - toggle controls
    if (position < totalWidth * leftZonePercentage) {
      LoggingService.debug('TouchNavigationZonesUnified', 'Left zone tapped');
      onPreviousPage?.call();
    } else if (position > totalWidth * (1 - rightZonePercentage)) {
      LoggingService.debug('TouchNavigationZonesUnified', 'Right zone tapped');
      onNextPage?.call();
    } else {
      LoggingService.debug('TouchNavigationZonesUnified', 'Middle zone tapped');
      onToggleControls?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width,
      height: MediaQuery.of(context).size.height,
      child: GestureDetector(
        onTapDown: _handleTapDown,
        behavior: HitTestBehavior.opaque,
      ),
    );
  }
}

/// Helper class for accessing navigator context
class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
}
