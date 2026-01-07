import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/foundation.dart';

/// Web implementation of PWA service
class PwaService {
  static final PwaService _instance = PwaService._internal();
  factory PwaService() => _instance;
  PwaService._internal();

  /// Check if the app is running in standalone mode (installed as PWA)
  bool get isStandalone {
    try {
      // Check if running in standalone mode using MediaQuery
      final mediaQuery = html.window.matchMedia('(display-mode: standalone)');
      if (mediaQuery.matches) {
        return true;
      }
      
      // Check for iOS standalone mode
      final navigator = html.window.navigator;
      final userAgent = navigator.userAgent?.toLowerCase() ?? '';
      if (userAgent.contains('iphone') || userAgent.contains('ipad')) {
        // iOS Safari standalone mode
        final standalone = html.window.navigator.standalone;
        if (standalone == true) {
          return true;
        }
      }
      
      // Check referrer for Android app mode
      final referrer = html.window.document.referrer;
      if (referrer.contains('android-app://')) {
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('Error checking standalone mode: $e');
      return false;
    }
  }

  /// Check if the app can be installed (install prompt is available)
  bool get canInstall {
    try {
      // Check if the install prompt function is available
      final context = html.window;
      final isInstallable = context.callMethod('isPWAInstallable', []);
      return isInstallable == true;
    } catch (e) {
      // Function not available, return false
      return false;
    }
  }

  /// Show the PWA install prompt
  /// Returns true if the prompt was shown, false otherwise
  Future<bool> showInstallPrompt() async {
    if (canInstall) {
      try {
        html.window.callMethod('showInstallPrompt', []);
        return true;
      } catch (e) {
        debugPrint('Error showing install prompt: $e');
        return false;
      }
    }
    return false;
  }

  /// Check if service worker is supported
  bool get isServiceWorkerSupported {
    try {
      return html.window.navigator.serviceWorker != null;
    } catch (e) {
      return false;
    }
  }

  /// Get service worker registration if available
  Future<html.ServiceWorkerRegistration?> getServiceWorkerRegistration() async {
    if (isServiceWorkerSupported) {
      try {
        return await html.window.navigator.serviceWorker?.ready;
      } catch (e) {
        debugPrint('Error getting service worker registration: $e');
        return null;
      }
    }
    return null;
  }

  /// Check for service worker updates
  Future<bool> checkForUpdates() async {
    if (isServiceWorkerSupported) {
      try {
        final registration = await html.window.navigator.serviceWorker?.getRegistration();
        if (registration != null) {
          await registration.update();
          return true;
        }
      } catch (e) {
        debugPrint('Error checking for updates: $e');
      }
    }
    return false;
  }

  /// Listen for PWA install prompt availability
  Stream<bool> get installPromptAvailable {
    final controller = StreamController<bool>.broadcast();
    
    html.window.addEventListener('pwa-install-available', (event) {
      controller.add(true);
    });
    
    // Check initial state
    Future.microtask(() {
      if (canInstall) {
        controller.add(true);
      }
    });
    
    return controller.stream;
  }

  /// Listen for PWA installation events
  Stream<void> get installed {
    final controller = StreamController<void>.broadcast();
    
    html.window.addEventListener('appinstalled', (event) {
      controller.add(null);
    });
    
    return controller.stream;
  }

  /// Listen for service worker controller changes (updates)
  Stream<void> get serviceWorkerUpdated {
    final controller = StreamController<void>.broadcast();
    
    html.window.addEventListener('sw-controller-change', (event) {
      controller.add(null);
    });
    
    return controller.stream;
  }

  /// Listen for service worker update availability
  Stream<void> get serviceWorkerUpdateAvailable {
    final controller = StreamController<void>.broadcast();
    
    html.window.addEventListener('sw-update-available', (event) {
      controller.add(null);
    });
    
    return controller.stream;
  }
}
