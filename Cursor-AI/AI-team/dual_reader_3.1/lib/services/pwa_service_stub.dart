import 'dart:async';
import 'package:flutter/foundation.dart';

/// Stub implementation of PwaService for non-web platforms
class PwaService {
  static final PwaService _instance = PwaService._internal();
  factory PwaService() => _instance;
  PwaService._internal();

  bool get isStandalone => false;
  bool get canInstall => false;
  Future<bool> showInstallPrompt() async => false;
  bool get isServiceWorkerSupported => false;
  Future<dynamic> getServiceWorkerRegistration() async => null;
  Future<bool> checkForUpdates() async => false;
  
  Stream<bool> get installPromptAvailable => const Stream<bool>.empty();
  Stream<void> get installed => const Stream<void>.empty();
  Stream<void> get serviceWorkerUpdated => const Stream<void>.empty();
  Stream<void> get serviceWorkerUpdateAvailable => const Stream<void>.empty();
}
