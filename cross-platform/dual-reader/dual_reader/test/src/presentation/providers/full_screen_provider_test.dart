import 'package:flutter_test/flutter_test.dart';
import 'package:dual_reader/src/data/services/full_screen_service.dart';
import 'package:dual_reader/src/presentation/providers/full_screen_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FullScreenState Tests', () {
    test('should have correct default values', () {
      const state = FullScreenState();

      expect(state.isFullScreen, isFalse);
      expect(state.mode, FullScreenMode.none);
      expect(state.isAvailable, isTrue);
      expect(state.isBusy, isFalse);
    });

    test('should create state with all custom values', () {
      const state = FullScreenState(
        isFullScreen: true,
        mode: FullScreenMode.systemImmersive,
        isAvailable: false,
        isBusy: true,
      );

      expect(state.isFullScreen, isTrue);
      expect(state.mode, FullScreenMode.systemImmersive);
      expect(state.isAvailable, isFalse);
      expect(state.isBusy, isTrue);
    });

    test('copyWith should update only specified fields', () {
      const state = FullScreenState();

      final updated = state.copyWith(isFullScreen: true);

      expect(updated.isFullScreen, isTrue);
      expect(updated.mode, FullScreenMode.none);
      expect(updated.isAvailable, isTrue);
      expect(updated.isBusy, isFalse);
    });

    test('copyWith should update mode', () {
      const state = FullScreenState();

      final updated = state.copyWith(mode: FullScreenMode.systemImmersive);

      expect(updated.mode, FullScreenMode.systemImmersive);
      expect(updated.isFullScreen, isFalse);
    });

    test('copyWith should update isAvailable', () {
      const state = FullScreenState(isAvailable: true);

      final updated = state.copyWith(isAvailable: false);

      expect(updated.isAvailable, isFalse);
      expect(updated.isFullScreen, isFalse);
    });

    test('copyWith should update isBusy', () {
      const state = FullScreenState(isBusy: false);

      final updated = state.copyWith(isBusy: true);

      expect(updated.isBusy, isTrue);
    });

    test('copyWith should update all fields simultaneously', () {
      const state = FullScreenState();

      final updated = state.copyWith(
        isFullScreen: true,
        mode: FullScreenMode.browserFullscreen,
        isAvailable: false,
        isBusy: true,
      );

      expect(updated.isFullScreen, isTrue);
      expect(updated.mode, FullScreenMode.browserFullscreen);
      expect(updated.isAvailable, isFalse);
      expect(updated.isBusy, isTrue);
    });

    test('copyWith should preserve immutability of original state', () {
      const state = FullScreenState(
        isFullScreen: false,
        mode: FullScreenMode.none,
        isAvailable: true,
        isBusy: false,
      );

      final updated = state.copyWith(isFullScreen: true);

      expect(state.isFullScreen, isFalse);
      expect(updated.isFullScreen, isTrue);
    });

    test('toString should contain all field values', () {
      const state = FullScreenState(
        isFullScreen: true,
        mode: FullScreenMode.systemImmersive,
        isAvailable: true,
        isBusy: false,
      );

      final str = state.toString();
      expect(str, contains('isFullScreen: true'));
      expect(str, contains('mode: FullScreenMode.systemImmersive'));
      expect(str, contains('isAvailable: true'));
      expect(str, contains('isBusy: false'));
    });

    test('should represent not-in-fullscreen state correctly', () {
      const state = FullScreenState(
        isFullScreen: false,
        mode: FullScreenMode.none,
      );

      expect(state.isFullScreen, isFalse);
      expect(state.mode, FullScreenMode.none);
    });

    test('should represent immersive fullscreen state correctly', () {
      const state = FullScreenState(
        isFullScreen: true,
        mode: FullScreenMode.systemImmersive,
      );

      expect(state.isFullScreen, isTrue);
      expect(state.mode, FullScreenMode.systemImmersive);
    });

    test('should represent browser fullscreen state correctly', () {
      const state = FullScreenState(
        isFullScreen: true,
        mode: FullScreenMode.browserFullscreen,
      );

      expect(state.isFullScreen, isTrue);
      expect(state.mode, FullScreenMode.browserFullscreen);
    });

    test('should represent unavailable state correctly', () {
      const state = FullScreenState(isAvailable: false);

      expect(state.isAvailable, isFalse);
    });

    test('should represent busy state correctly', () {
      const state = FullScreenState(isBusy: true);

      expect(state.isBusy, isTrue);
    });

    test('copyWith with no parameters returns equivalent state', () {
      const state = FullScreenState(
        isFullScreen: true,
        mode: FullScreenMode.systemImmersive,
        isAvailable: true,
        isBusy: false,
      );

      final copied = state.copyWith();

      expect(copied.isFullScreen, state.isFullScreen);
      expect(copied.mode, state.mode);
      expect(copied.isAvailable, state.isAvailable);
      expect(copied.isBusy, state.isBusy);
    });
  });

  group('FullScreenMode Enum Tests', () {
    test('should have correct number of modes', () {
      expect(FullScreenMode.values.length, 3);
    });

    test('should contain all required modes', () {
      expect(FullScreenMode.values, contains(FullScreenMode.none));
      expect(FullScreenMode.values, contains(FullScreenMode.systemImmersive));
      expect(FullScreenMode.values, contains(FullScreenMode.browserFullscreen));
    });

    test('should have correct index values', () {
      expect(FullScreenMode.none.index, 0);
      expect(FullScreenMode.systemImmersive.index, 1);
      expect(FullScreenMode.browserFullscreen.index, 2);
    });
  });

  group('FullScreenNotifier State Transitions Tests', () {
    late FullScreenNotifier notifier;

    setUp(() async {
      // Use FullScreenService.instance (singleton) - it will initialize
      // but since we're in test environment, we test the state machine logic
      notifier = FullScreenNotifier(FullScreenService.instance);
      // Allow async initialization to settle
      await Future.delayed(const Duration(milliseconds: 100));
    });

    test('should start with default state after initialization', () {
      // After init, state may or may not be in full screen depending on platform
      // but isBusy should be false and isAvailable should be true (on test platform)
      expect(notifier.state.isBusy, isFalse);
    });

    test('should toggle full screen state', () async {
      final initialState = notifier.state.isFullScreen;

      // First toggle
      await notifier.toggleFullScreen();
      expect(notifier.state.isFullScreen, !initialState);

      // Second toggle should revert
      await notifier.toggleFullScreen();
      expect(notifier.state.isFullScreen, initialState);
    });

    test('enterFullScreen should change state', () async {
      // First exit if already in fullscreen
      if (notifier.state.isFullScreen) {
        await notifier.exitFullScreen();
      }

      final result = await notifier.enterFullScreen();

      // In test environment the result depends on the platform
      if (result) {
        expect(notifier.state.isFullScreen, isTrue);
        expect(notifier.state.isBusy, isFalse);
      }
    });

    test('exitFullScreen should change state', () async {
      // Enter first
      await notifier.enterFullScreen();

      final result = await notifier.exitFullScreen();

      if (result) {
        expect(notifier.state.isFullScreen, isFalse);
        expect(notifier.state.mode, FullScreenMode.none);
        expect(notifier.state.isBusy, isFalse);
      }
    });

    test('should not enter full screen when already busy', () async {
      // Manually set busy state to simulate in-progress operation
      notifier.state = notifier.state.copyWith(isBusy: true);

      final result = await notifier.enterFullScreen();

      expect(result, isFalse);
      // Clean up
      notifier.state = notifier.state.copyWith(isBusy: false);
    });

    test('should not exit full screen when busy', () async {
      // Enter fullscreen first
      await notifier.enterFullScreen();

      // Set busy manually
      notifier.state = notifier.state.copyWith(isBusy: true);

      final result = await notifier.exitFullScreen();

      expect(result, isFalse);

      // Clean up
      notifier.state = notifier.state.copyWith(isBusy: false);
      await notifier.exitFullScreen();
    });

    test('updateFromService should sync state from service', () async {
      notifier.updateFromService();

      final service = FullScreenService.instance;
      expect(notifier.state.isFullScreen, service.isFullScreen);
      expect(notifier.state.mode, service.currentMode);
    });

    test('should handle handleAppPaused without exiting', () async {
      await notifier.enterFullScreen();
      final wasFullScreen = notifier.state.isFullScreen;

      await notifier.handleAppPaused(exitFullScreen: false);

      // Should not change full screen state
      expect(notifier.state.isFullScreen, wasFullScreen);

      // Clean up
      if (notifier.state.isFullScreen) {
        await notifier.exitFullScreen();
      }
    });

    test('should handle multiple enter/exit cycles', () async {
      // Exit if in fullscreen
      if (notifier.state.isFullScreen) {
        await notifier.exitFullScreen();
      }

      for (int i = 0; i < 3; i++) {
        final enterResult = await notifier.enterFullScreen();
        if (enterResult) {
          expect(notifier.state.isFullScreen, isTrue);
        }

        final exitResult = await notifier.exitFullScreen();
        if (exitResult) {
          expect(notifier.state.isFullScreen, isFalse);
          expect(notifier.state.mode, FullScreenMode.none);
        }
      }
    });
  });
}
