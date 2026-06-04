/// Core test helpers for E2E testing
///
/// Provides common utilities for test setup, teardown, and execution.

library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../config/test_config.dart';

/// Helper class for common test operations
class TestHelpers {
  /// Initialize the test framework
  static void initTests() {
    IntegrationTestWidgetsFlutterBinding.ensureInitialized();
    _printTestHeader();
  }

  /// Print test header with environment info
  static void _printTestHeader() {
    print('\n${'=' * 70}');
    print('DUAL READER E2E TESTS');
    print('${'=' * 70}');
    print('Platform: ${_getPlatformName()}');
    print('CI Environment: ${TestConfig.isCI ? "Yes" : "No"}');
    print('Test Run ID: ${TestConfig.testRunId}');
    print('Verbose Logging: ${TestConfig.verboseLogging ? "Enabled" : "Disabled"}');
    print('${'=' * 70}\n');
  }

  /// Get human-readable platform name
  static String _getPlatformName() {
    if (TestConfig.isAndroid) return 'Android';
    if (TestConfig.isIOS) return 'iOS';
    return 'Web';
  }

  /// Check if test should run based on platform
  static bool shouldRunTest({
    required List<String> platforms,
  }) {
    if (platforms.contains('web') && TestConfig.isWeb) return true;
    if (platforms.contains('mobile') && (TestConfig.isAndroid || TestConfig.isIOS)) {
      return true;
    }
    if (platforms.contains('android') && TestConfig.isAndroid) return true;
    if (platforms.contains('ios') && TestConfig.isIOS) return true;
    return false;
  }

  /// Skip test with message
  static void skipTest(String reason) {
    print('⏭️  Test skipped: $reason');
  }

  /// Log test start
  static void logTestStart(String testName) {
    print('\n▶️  Starting: $testName');
    if (TestConfig.verboseLogging) {
      print('   Timestamp: ${DateTime.now().toIso8601String()}');
    }
  }

  /// Log test completion
  static void logTestComplete(String testName, {Duration? duration}) {
    final durationText = duration != null
        ? ' (${duration.inSeconds}s ${duration.inMilliseconds % 1000}ms)'
        : '';
    print('✅ Completed: $testName$durationText');
  }

  /// Log test failure
  static void logTestFailure(String testName, dynamic error, [StackTrace? stackTrace]) {
    print('❌ Failed: $testName');
    print('   Error: $error');
    if (stackTrace != null && TestConfig.verboseLogging) {
      print('   Stack trace:\n$stackTrace');
    }
  }

  /// Create test directory if it doesn't exist
  static Future<void> ensureTestDirectory(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  /// Clean up test artifacts
  static Future<void> cleanupTestArtifacts() async {
    try {
      // Clean up screenshots older than 7 days
      final screenshotDir = Directory(TestConfig.screenshotDir);
      if (await screenshotDir.exists()) {
        final now = DateTime.now();
        await for (final entity in screenshotDir.list()) {
          if (entity is File) {
            final stat = await entity.stat();
            if (now.difference(stat.modified).inDays > 7) {
              await entity.delete();
            }
          }
        }
      }

      // Clean up old logs
      final logDir = Directory(TestConfig.logDir);
      if (await logDir.exists()) {
        final now = DateTime.now();
        await for (final entity in logDir.list()) {
          if (entity is File && entity.path.endsWith('.log')) {
            final stat = await entity.stat();
            if (now.difference(stat.modified).inDays > 7) {
              await entity.delete();
            }
          }
        }
      }
    } catch (e) {
      // Don't fail tests if cleanup fails
      print('⚠️  Cleanup warning: $e');
    }
  }

  /// Take screenshot for debugging
  static Future<void> takeScreenshot(WidgetTester tester, String name) async {
    try {
      await TestHelpers.ensureTestDirectory(TestConfig.screenshotDir);
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final path = '${TestConfig.screenshotDir}/$name-$timestamp.png';

      await binding.takeScreenshot(path);
      print('📸 Screenshot saved: $path');
    } catch (e) {
      print('⚠️  Failed to take screenshot: $e');
    }
  }

  /// Get the integration test binding
  static IntegrationTestWidgetsFlutterBinding get binding =>
      IntegrationTestWidgetsFlutterBinding.instance;

  /// Wait for app to settle
  static Future<void> waitForAppSettled(
    WidgetTester tester, {
    Duration timeout = TestConfig.uiTimeout,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      await tester.pumpAndSettle(timeout);
    } catch (e) {
      print('⚠️  App did not settle within ${timeout.inSeconds}s');
      rethrow;
    } finally {
      stopwatch.stop();
      if (TestConfig.verboseLogging) {
        print('   App settled in ${stopwatch.elapsedMilliseconds}ms');
      }
    }
  }

  /// Retry an operation with exponential backoff
  static Future<T> retry<T>(
    Future<T> Function() operation, {
    int maxAttempts = 3,
    Duration initialDelay = const Duration(seconds: 1),
  }) async {
    var attempt = 0;
    var delay = initialDelay;

    while (attempt < maxAttempts) {
      try {
        return await operation();
      } catch (e) {
        attempt++;
        if (attempt >= maxAttempts) rethrow;
        print('⚠️  Attempt $attempt failed, retrying in ${delay.inSeconds}s...');
        await Future.delayed(delay);
        delay *= 2;
      }
    }

    throw StateError('Unreachable');
  }

  /// Measure and log operation duration
  static Future<T> measure<T>(
    String operation,
    Future<T> Function() fn,
  ) async {
    final stopwatch = Stopwatch()..start();
    try {
      final result = await fn();
      stopwatch.stop();
      print('⏱️  $operation took ${stopwatch.elapsedMilliseconds}ms');
      return result;
    } catch (e) {
      stopwatch.stop();
      print('⏱️  $operation failed after ${stopwatch.elapsedMilliseconds}ms');
      rethrow;
    }
  }
}

/// Extension to add custom matchers
extension CustomMatchers on WidgetTester {
  /// Wait for a widget to appear
  Future<void> waitForWidget(
    Finder finder, {
    Duration timeout = TestConfig.maxWaitTime,
    String? description,
  }) async {
    final end = DateTime.now().add(timeout);
    final desc = description ?? 'widget';

    while (DateTime.now().isBefore(end)) {
      await pump(TestConfig.pollingInterval);
      if (finder.evaluate().isNotEmpty) return;
    }

    throw TestFailure('Timed out waiting for $desc');
  }

  /// Wait for a widget to disappear
  Future<void> waitForWidgetToDisappear(
    Finder finder, {
    Duration timeout = TestConfig.maxWaitTime,
    String? description,
  }) async {
    final end = DateTime.now().add(timeout);
    final desc = description ?? 'widget';

    while (DateTime.now().isBefore(end)) {
      await pump(TestConfig.pollingInterval);
      if (finder.evaluate().isEmpty) return;
    }

    throw TestFailure('Timed out waiting for $desc to disappear');
  }

  /// Tap a widget with retry
  Future<void> tapWithRetry(
    Finder finder, {
    int maxAttempts = 3,
    String? description,
  }) async {
    final desc = description ?? 'widget';
    var attempts = 0;

    while (attempts < maxAttempts) {
      try {
        await tap(finder);
        await pump();
        return;
      } catch (e) {
        attempts++;
        if (attempts >= maxAttempts) {
          throw TestFailure('Failed to tap $desc after $maxAttempts attempts: $e');
        }
        await pump(const Duration(milliseconds: 500));
      }
    }
  }
}
