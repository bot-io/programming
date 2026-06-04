import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dual_reader/src/data/services/full_screen_service.dart';
import 'package:dual_reader/src/core/utils/logging_service.dart';

/// Full screen state
class FullScreenState {
  /// Whether full screen mode is active
  final bool isFullScreen;

  /// The current full screen mode
  final FullScreenMode mode;

  /// Whether full screen is available on this platform
  final bool isAvailable;

  /// Whether there's an active operation in progress
  final bool isBusy;

  const FullScreenState({
    this.isFullScreen = false,
    this.mode = FullScreenMode.none,
    this.isAvailable = true,
    this.isBusy = false,
  });

  FullScreenState copyWith({
    bool? isFullScreen,
    FullScreenMode? mode,
    bool? isAvailable,
    bool? isBusy,
  }) {
    return FullScreenState(
      isFullScreen: isFullScreen ?? this.isFullScreen,
      mode: mode ?? this.mode,
      isAvailable: isAvailable ?? this.isAvailable,
      isBusy: isBusy ?? this.isBusy,
    );
  }

  @override
  String toString() {
    return 'FullScreenState(isFullScreen: $isFullScreen, mode: $mode, isAvailable: $isAvailable, isBusy: $isBusy)';
  }
}

/// Full screen notifier for managing full screen state
class FullScreenNotifier extends StateNotifier<FullScreenState> {
  final FullScreenService _service;

  FullScreenNotifier(this._service)
      : super(const FullScreenState()) {
    _initialize();
  }

  /// Initialize the full screen service
  Future<void> _initialize() async {
    LoggingService.info('FullScreenNotifier', 'Initializing');

    try {
      await _service.initialize();

      // Update initial state based on service
      state = state.copyWith(
        isFullScreen: _service.isFullScreen,
        mode: _service.currentMode,
      );

      LoggingService.info('FullScreenNotifier', 'Initialized with state: $state');
    } catch (e) {
      LoggingService.error('FullScreenNotifier', 'Initialization failed', error: e);
      state = state.copyWith(isAvailable: false);
    }
  }

  /// Enter full screen mode
  Future<bool> enterFullScreen() async {
    if (state.isBusy) {
      LoggingService.warning('FullScreenNotifier', 'Cannot enter full screen: busy');
      return false;
    }

    LoggingService.info('FullScreenNotifier', 'Entering full screen mode');
    state = state.copyWith(isBusy: true);

    try {
      final success = await _service.enterFullScreen();

      if (success) {
        state = state.copyWith(
          isFullScreen: true,
          mode: _service.currentMode,
          isBusy: false,
        );
        LoggingService.info('FullScreenNotifier', 'Full screen enabled: ${state.mode}');
      } else {
        state = state.copyWith(isBusy: false);
        LoggingService.warning('FullScreenNotifier', 'Failed to enter full screen');
      }

      return success;
    } catch (e) {
      LoggingService.error('FullScreenNotifier', 'Error entering full screen', error: e);
      state = state.copyWith(isBusy: false);
      return false;
    }
  }

  /// Exit full screen mode
  Future<bool> exitFullScreen() async {
    if (state.isBusy) {
      LoggingService.warning('FullScreenNotifier', 'Cannot exit full screen: busy');
      return false;
    }

    LoggingService.info('FullScreenNotifier', 'Exiting full screen mode');
    state = state.copyWith(isBusy: true);

    try {
      final success = await _service.exitFullScreen();

      if (success) {
        state = state.copyWith(
          isFullScreen: false,
          mode: FullScreenMode.none,
          isBusy: false,
        );
        LoggingService.info('FullScreenNotifier', 'Full screen disabled');
      } else {
        state = state.copyWith(isBusy: false);
        LoggingService.warning('FullScreenNotifier', 'Failed to exit full screen');
      }

      return success;
    } catch (e) {
      LoggingService.error('FullScreenNotifier', 'Error exiting full screen', error: e);
      state = state.copyWith(isBusy: false);
      return false;
    }
  }

  /// Toggle full screen mode
  Future<bool> toggleFullScreen() async {
    if (state.isFullScreen) {
      return await exitFullScreen();
    } else {
      return await enterFullScreen();
    }
  }

  /// Handle app lifecycle resumed event
  Future<void> handleAppResumed() async {
    LoggingService.info('FullScreenNotifier', 'App resumed - restoring full screen state');
    await _service.handleAppResumed();

    state = state.copyWith(
      isFullScreen: _service.isFullScreen,
      mode: _service.currentMode,
    );
  }

  /// Handle app lifecycle paused event
  Future<void> handleAppPaused({bool exitFullScreen = false}) async {
    LoggingService.info('FullScreenNotifier', 'App paused - full screen: $exitFullScreen');
    await _service.handleAppPaused(exitFullScreen: exitFullScreen);

    if (exitFullScreen) {
      state = state.copyWith(
        isFullScreen: false,
        mode: FullScreenMode.none,
      );
    }
  }

  /// Update state from external source
  void updateFromService() {
    state = state.copyWith(
      isFullScreen: _service.isFullScreen,
      mode: _service.currentMode,
    );
  }

  @override
  void dispose() {
    LoggingService.info('FullScreenNotifier', 'Disposing notifier');
    _service.dispose();
    super.dispose();
  }
}

/// Provider for the full screen service
final fullScreenServiceProvider = Provider<FullScreenService>((ref) {
  final service = FullScreenService.instance;

  // Dispose when provider is disposed
  ref.onDispose(() {
    service.dispose();
  });

  return service;
});

/// Provider for the full screen state notifier
final fullScreenProvider = StateNotifierProvider<FullScreenNotifier, FullScreenState>((ref) {
  final service = ref.watch(fullScreenServiceProvider);
  return FullScreenNotifier(service);
});

/// Convenience provider to check if full screen is active
final isFullScreenProvider = Provider<bool>((ref) {
  return ref.watch(fullScreenProvider).isFullScreen;
});

/// Convenience provider to get the current full screen mode
final fullScreenModeProvider = Provider<FullScreenMode>((ref) {
  return ref.watch(fullScreenProvider).mode;
});
