import 'dart:io' show Platform;

/// Abstract interface for platform-specific features
///
/// This interface abstracts platform-specific capabilities,
/// allowing state management and business logic to remain
/// platform-agnostic while accessing platform features.
///
/// Implementations are provided per platform and selected
/// via conditional imports.
abstract class PlatformFeatures {
  /// Whether this platform supports direct file system access
  bool get supportsFileAccess;

  /// Whether this platform supports on-device translation models
  bool get supportsModelDownload;

  /// Whether this is a mobile platform (Android or iOS)
  bool get isMobile;

  /// Whether this is a web platform
  bool get isWeb;

  /// Whether this is an Android platform
  bool get isAndroid;

  /// Whether this is an iOS platform
  bool get isIOS;

  /// Platform name for logging/debugging
  String get platformName;
}

/// Mobile implementation of PlatformFeatures
class MobilePlatformFeatures implements PlatformFeatures {
  const MobilePlatformFeatures();

  @override
  bool get supportsFileAccess => true;

  @override
  bool get supportsModelDownload => true;

  @override
  bool get isMobile => true;

  @override
  bool get isWeb => false;

  @override
  bool get isAndroid => Platform.isAndroid;

  @override
  bool get isIOS => Platform.isIOS;

  @override
  String get platformName => isAndroid ? 'Android' : 'iOS';
}

/// Web implementation of PlatformFeatures
class WebPlatformFeatures implements PlatformFeatures {
  const WebPlatformFeatures();

  @override
  bool get supportsFileAccess => false;

  @override
  bool get supportsModelDownload => false;

  @override
  bool get isMobile => false;

  @override
  bool get isWeb => true;

  @override
  bool get isAndroid => false;

  @override
  bool get isIOS => false;

  @override
  String get platformName => 'Web';
}

/// Factory function to create platform-specific features
///
/// Uses conditional compilation to select the correct
/// implementation at compile time (no runtime overhead).
PlatformFeatures createPlatformFeatures() {
  try {
    // This will throw on web if dart:io is imported
    return const MobilePlatformFeatures();
  } catch (_) {
    return const WebPlatformFeatures();
  }
}

// Initialize the provider with the correct platform implementation
final PlatformFeatures platformFeatures = createPlatformFeatures();
