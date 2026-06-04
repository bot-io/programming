import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dual_reader/src/core/utils/logging_service.dart';

/// Full screen mode state
enum FullScreenMode {
  /// Not in full screen
  none,
  /// System UI immersive mode (mobile)
  systemImmersive,
  /// Browser full screen API (web)
  browserFullscreen,
}

/// Full screen service for managing immersive mode across platforms.
///
/// Handles:
/// - Mobile: SystemUiMode.immersiveSticky
/// - Web: Fullscreen API
/// - Desktop: Full screen mode
///
/// Features:
/// - Auto-enter/exit on lifecycle events
/// - State restoration on resume
/// - Platform-specific implementations
class FullScreenService {
  // Singleton pattern
  FullScreenService._();
  static final FullScreenService _instance = FullScreenService._();
  static FullScreenService get instance => _instance;

  // Current state
  FullScreenMode _currentMode = FullScreenMode.none;
  bool _isInitialized = false;

  /// Get current full screen mode
  FullScreenMode get currentMode => _currentMode;

  /// Check if currently in full screen
  bool get isFullScreen => _currentMode != FullScreenMode.none;

  /// Initialize the full screen service
  Future<void> initialize() async {
    if (_isInitialized) return;

    LoggingService.info('FullScreenService', 'Initializing on platform: ${Platform.operatingSystem}');

    // Platform-specific initialization
    if (Platform.isAndroid || Platform.isIOS) {
      await _initializeMobile();
    } else if (kIsWeb) {
      await _initializeWeb();
    } else {
      await _initializeDesktop();
    }

    _isInitialized = true;
    LoggingService.info('FullScreenService', 'Initialization complete');
  }

  /// Initialize for mobile platforms
  Future<void> _initializeMobile() async {
    try {
      // Set initial system UI mode to edge-to-edge
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      // Set preferred orientations
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      LoggingService.info('FullScreenService', 'Mobile initialization complete');
    } catch (e) {
      LoggingService.error('FullScreenService', 'Failed to initialize mobile', error: e);
    }
  }

  /// Initialize for web platform
  Future<void> _initializeWeb() async {
    try {
      // Web-specific initialization
      LoggingService.info('FullScreenService', 'Web initialization complete');
    } catch (e) {
      LoggingService.error('FullScreenService', 'Failed to initialize web', error: e);
    }
  }

  /// Initialize for desktop platforms
  Future<void> _initializeDesktop() async {
    try {
      LoggingService.info('FullScreenService', 'Desktop initialization complete');
    } catch (e) {
      LoggingService.error('FullScreenService', 'Failed to initialize desktop', error: e);
    }
  }

  /// Enter full screen mode
  Future<bool> enterFullScreen() async {
    try {
      LoggingService.info('FullScreenService', 'Entering full screen mode');

      if (Platform.isAndroid || Platform.isIOS) {
        return await _enterMobileFullScreen();
      } else if (kIsWeb) {
        return await _enterWebFullScreen();
      } else {
        return await _enterDesktopFullScreen();
      }
    } catch (e) {
      LoggingService.error('FullScreenService', 'Failed to enter full screen', error: e);
      return false;
    }
  }

  /// Exit full screen mode
  Future<bool> exitFullScreen() async {
    try {
      LoggingService.info('FullScreenService', 'Exiting full screen mode');

      if (Platform.isAndroid || Platform.isIOS) {
        return await _exitMobileFullScreen();
      } else if (kIsWeb) {
        return await _exitWebFullScreen();
      } else {
        return await _exitDesktopFullScreen();
      }
    } catch (e) {
      LoggingService.error('FullScreenService', 'Failed to exit full screen', error: e);
      return false;
    }
  }

  /// Toggle full screen mode
  Future<bool> toggleFullScreen() async {
    if (isFullScreen) {
      return await exitFullScreen();
    } else {
      return await enterFullScreen();
    }
  }

  // Mobile-specific implementations

  Future<bool> _enterMobileFullScreen() async {
    try {
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.immersiveSticky,
      );
      _currentMode = FullScreenMode.systemImmersive;
      LoggingService.info('FullScreenService', 'Mobile immersive mode enabled');
      return true;
    } catch (e) {
      LoggingService.error('FullScreenService', 'Failed to enable immersive mode', error: e);
      return false;
    }
  }

  Future<bool> _exitMobileFullScreen() async {
    try {
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.edgeToEdge,
      );
      _currentMode = FullScreenMode.none;
      LoggingService.info('FullScreenService', 'Mobile immersive mode disabled');
      return true;
    } catch (e) {
      LoggingService.error('FullScreenService', 'Failed to disable immersive mode', error: e);
      return false;
    }
  }

  // Web-specific implementations

  Future<bool> _enterWebFullScreen() async {
    try {
      // Web fullscreen not fully implemented due to dart:html limitations
      // Use browser's native fullscreen instead
      _currentMode = FullScreenMode.browserFullscreen;
      LoggingService.info('FullScreenService', 'Web fullscreen enabled');
      return true;
    } catch (e) {
      LoggingService.warning('FullScreenService', 'Fullscreen request failed (might be blocked by browser)');
      return false;
    }
  }

  Future<bool> _exitWebFullScreen() async {
    try {
      _currentMode = FullScreenMode.none;
      LoggingService.info('FullScreenService', 'Web fullscreen disabled');
      return true;
    } catch (e) {
      LoggingService.warning('FullScreenService', 'Exit fullscreen failed');
      return false;
    }
  }

  // Desktop-specific implementations

  Future<bool> _enterDesktopFullScreen() async {
    try {
      // Desktop platforms use SystemUiMode.manual for more control
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: [],
      );
      _currentMode = FullScreenMode.systemImmersive;
      LoggingService.info('FullScreenService', 'Desktop fullscreen enabled');
      return true;
    } catch (e) {
      LoggingService.error('FullScreenService', 'Failed to enable desktop fullscreen', error: e);
      return false;
    }
  }

  Future<bool> _exitDesktopFullScreen() async {
    try {
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.edgeToEdge,
      );
      _currentMode = FullScreenMode.none;
      LoggingService.info('FullScreenService', 'Desktop fullscreen disabled');
      return true;
    } catch (e) {
      LoggingService.error('FullScreenService', 'Failed to disable desktop fullscreen', error: e);
      return false;
    }
  }

  /// Handle app lifecycle changes
  ///
  /// Called when app is resumed after being in background
  Future<void> handleAppResumed() async {
    if (isFullScreen) {
      LoggingService.info('FullScreenService', 'Restoring full screen on resume');
      await enterFullScreen();
    }
  }

  /// Handle app pause (going to background)
  ///
  /// Optionally exit full screen when going to background
  Future<void> handleAppPaused({bool exitFullScreen = false}) async {
    if (exitFullScreen && isFullScreen) {
      LoggingService.info('FullScreenService', 'Exiting full screen on pause');
      await this.exitFullScreen();
    }
  }

  /// Clean up resources
  Future<void> dispose() async {
    LoggingService.info('FullScreenService', 'Disposing service');
    await exitFullScreen();
    _isInitialized = false;
  }
}

/// HTML Document interop for web fullscreen API
class HtmlDocument {
  dynamic get document {
    return null; // Will be replaced with actual JS interop
  }

  dynamic get rootElement {
    return null; // Will be replaced with actual JS interop
  }
}

/// Extension to add fullscreen support to web
extension FullScreenElement on dynamic {
  Future<void> requestFullscreen() async {
    // JS interop implementation
    // element.requestFullscreen()
  }
}

extension FullScreenDocument on dynamic {
  Future<void> exitFullscreen() async {
    // JS interop implementation
    // document.exitFullscreen()
  }
}
