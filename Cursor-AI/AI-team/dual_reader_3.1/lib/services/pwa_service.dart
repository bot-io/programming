import 'package:flutter/foundation.dart';

// Conditional imports for web platform
import 'pwa_service_stub.dart'
    if (dart.library.html) 'pwa_service_web.dart' as impl;

/// Service for handling PWA (Progressive Web App) functionality
/// including install prompts, standalone mode detection, and service worker updates
class PwaService {
  static final PwaService _instance = PwaService._internal();
  factory PwaService() => _instance;
  PwaService._internal();

  final _impl = impl.PwaService();

  /// Check if the app is running in standalone mode (installed as PWA)
  bool get isStandalone => _impl.isStandalone;

  /// Check if the app can be installed (install prompt is available)
  bool get canInstall => _impl.canInstall;

  /// Show the PWA install prompt
  /// Returns true if the prompt was shown, false otherwise
  Future<bool> showInstallPrompt() => _impl.showInstallPrompt();

  /// Check if service worker is supported
  bool get isServiceWorkerSupported => _impl.isServiceWorkerSupported;

  /// Get service worker registration if available
  Future<dynamic> getServiceWorkerRegistration() => _impl.getServiceWorkerRegistration();

  /// Check for service worker updates
  Future<bool> checkForUpdates() => _impl.checkForUpdates();

  /// Listen for PWA install prompt availability
  Stream<bool> get installPromptAvailable => _impl.installPromptAvailable;

  /// Listen for PWA installation events
  Stream<void> get installed => _impl.installed;

  /// Listen for service worker controller changes (updates)
  Stream<void> get serviceWorkerUpdated => _impl.serviceWorkerUpdated;

  /// Listen for service worker update availability
  Stream<void> get serviceWorkerUpdateAvailable => _impl.serviceWorkerUpdateAvailable;
}
