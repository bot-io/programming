import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

/// Test helper functions for Hive initialization in integration tests
///
/// These functions are needed because hive_test package doesn't provide
/// top-level setup/teardown functions.
///
/// Usage:
/// ```dart
/// import 'package:dual_reader/test/helper/test_helpers.dart';
///
/// setUpAll(() async {
///   await setUpHive();
/// });
///
/// tearDownAll(() async {
///   await tearDownHive();
/// });
/// ```

/// Initializes Hive for testing
///
/// This sets up Hive with a test directory for storage.
/// Must be called in setUpAll() before any Hive operations.
Future<void> setUpHive() async {
  // Initialize Hive
  Hive.init((await getTemporaryDirectory()).path);

  // Register any adapters if needed
  // Hive.registerAdapter(CustomAdapter());
}

/// Tears down Hive after testing
///
/// Closes all open Hive boxes and cleans up.
/// Must be called in tearDownAll() after all tests complete.
Future<void> tearDownHive() async {
  // Close all open boxes
  await Hive.close();
}
