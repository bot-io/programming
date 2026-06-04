import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dual_reader/src/presentation/providers/full_screen_provider.dart';
import 'package:dual_reader/src/core/utils/logging_service.dart';

/// Full screen toggle button widget.
///
/// Displays a button to toggle full screen mode with visual feedback.
/// Shows different icons based on current full screen state.
///
/// Features:
/// - Animated icon transition
/// - Tooltip with current state
/// - Theme-aware styling
/// - Optional label text
class FullScreenToggle extends ConsumerWidget {
  /// Callback when full screen is toggled
  final ValueChanged<bool>? onToggle;

  /// Whether to show a label next to the icon
  final bool showLabel;

  /// Button size
  final double? iconSize;

  const FullScreenToggle({
    super.key,
    this.onToggle,
    this.showLabel = false,
    this.iconSize,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(fullScreenProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return IconButton(
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (child, animation) {
          return RotationTransition(
            turns: Tween<double>(begin: 0.5, end: 0).animate(animation),
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          );
        },
        child: state.isFullScreen
          ? Icon(
              Icons.fullscreen_exit,
              key: const ValueKey('exit'),
              size: iconSize,
              color: isDark ? colorScheme.onSurface : colorScheme.onSurface,
            )
          : Icon(
              Icons.fullscreen,
              key: const ValueKey('enter'),
              size: iconSize,
              color: isDark ? colorScheme.onSurface : colorScheme.onSurface,
            ),
      ),
      onPressed: state.isBusy ? null : () => _handleToggle(context, ref),
      tooltip: state.isFullScreen ? 'Exit Full Screen' : 'Enter Full Screen',
    );
  }

  void _handleToggle(BuildContext context, WidgetRef ref) {
    final state = ref.read(fullScreenProvider);

    LoggingService.debug('FullScreenToggle', 'Toggle pressed - current: ${state.isFullScreen}');

    // Toggle full screen
    ref.read(fullScreenProvider.notifier).toggleFullScreen().then((success) {
      if (success) {
        onToggle?.call(!state.isFullScreen);
      }
    });
  }
}

/// Full screen indicator badge.
///
/// Shows a small indicator when in full screen mode.
/// Can be positioned anywhere in the UI.
class FullScreenIndicator extends ConsumerWidget {
  /// Position of the indicator
  final Alignment alignment;

  /// Distance from edge
  final double distance;

  const FullScreenIndicator({
    super.key,
    this.alignment = Alignment.topRight,
    this.distance = 16,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(fullScreenProvider);

    if (!state.isFullScreen) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return Align(
      alignment: alignment,
      child: Padding(
        padding: EdgeInsets.all(distance),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isDark
              ? colorScheme.surfaceContainerHighest.withOpacity(0.9)
              : colorScheme.surfaceContainerHighest.withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colorScheme.primary.withOpacity(0.5),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.fullscreen,
                size: 12,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 4),
              Text(
                'Full Screen',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full screen mode indicator for controls bar.
///
/// Shows the current full screen mode as a compact icon.
class FullScreenModeIcon extends ConsumerWidget {
  const FullScreenModeIcon({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(fullScreenProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    IconData getIcon() {
      switch (state.mode) {
        case FullScreenMode.systemImmersive:
          return Icons.smartphone;
        case FullScreenMode.browserFullscreen:
          return Icons.web;
        case FullScreenMode.none:
          return Icons.fullscreen;
      }
    }

    if (!state.isFullScreen) {
      return const SizedBox.shrink();
    }

    return Icon(
      getIcon(),
      size: 16,
      color: colorScheme.primary,
    );
  }
}

/// Full screen wrapper widget.
///
/// Automatically manages full screen mode when the widget is mounted/disposed.
/// Useful for reader screens that should auto-enter full screen.
class FullScreenWrapper extends ConsumerStatefulWidget {
  /// Child widget to display
  final Widget child;

  /// Whether to auto-enter full screen on mount
  final bool autoEnter;

  /// Whether to exit full screen on dispose
  final bool exitOnDispose;

  /// Callback when full screen state changes
  final ValueChanged<bool>? onFullScreenChanged;

  const FullScreenWrapper({
    super.key,
    required this.child,
    this.autoEnter = true,
    this.exitOnDispose = true,
    this.onFullScreenChanged,
  });

  @override
  ConsumerState<FullScreenWrapper> createState() => _FullScreenWrapperState();
}

class _FullScreenWrapperState extends ConsumerState<FullScreenWrapper>
    with WidgetsBindingObserver {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Auto-enter full screen if requested
    if (widget.autoEnter) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await ref.read(fullScreenProvider.notifier).enterFullScreen();
      });
    }

    // Listen to state changes
    ref.listen<FullScreenState>(fullScreenProvider, (previous, next) {
      if (previous.isFullScreen != next.isFullScreen) {
        widget.onFullScreenChanged?.call(next.isFullScreen);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    // Exit full screen on dispose if requested
    if (widget.exitOnDispose) {
      ref.read(fullScreenProvider.notifier).exitFullScreen();
    }

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    switch (lifecycleState) {
      case AppLifecycleState.resumed:
        // Restore full screen when app is resumed
        ref.read(fullScreenProvider.notifier).handleAppResumed();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // Handle other lifecycle events if needed
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
