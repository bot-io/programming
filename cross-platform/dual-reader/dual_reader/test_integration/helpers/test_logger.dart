/// Comprehensive debug logging for E2E tests
///
/// Provides structured logging throughout test execution for debugging
/// and analysis.

library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import '../config/test_config.dart';

/// Log levels for test logging
enum LogLevel {
  debug,
  info,
  warning,
  error,
}

/// Log entry structure
class LogEntry {
  final LogLevel level;
  final String message;
  final DateTime timestamp;
  final String? category;
  final Map<String, dynamic>? metadata;

  LogEntry({
    required this.level,
    required this.message,
    DateTime? timestamp,
    this.category,
    this.metadata,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'level': level.name,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'category': category,
      if (metadata != null) 'metadata': metadata,
    };
  }

  @override
  String toString() {
    final timeStr = timestamp.toIso8601String();
    final levelStr = level.name.toUpperCase().padRight(7);
    final categoryStr = category != null ? '[$category] ' : '';
    return '$timeStr $levelStr $categoryStr$message';
  }
}

/// Test logger for comprehensive debug logging
class TestLogger {
  /// Singleton instance
  static final TestLogger instance = TestLogger._internal();

  factory TestLogger() => instance;

  TestLogger._internal();

  /// Log entries storage
  final List<LogEntry> _logs = [];

  /// Log controller for stream subscriptions
  final StreamController<LogEntry> _controller = StreamController<LogEntry>.broadcast();

  /// Stream of log entries
  Stream<LogEntry> get logStream => _controller.stream;

  /// Current test name
  String? _currentTest;

  /// Test start time
  DateTime? _testStartTime;

  /// Get all logs
  List<LogEntry> get logs => List.unmodifiable(_logs);

  /// Set current test context
  void setTestContext(String testName) {
    _currentTest = testName;
    _testStartTime = DateTime.now();
    info('Test started: $testName', category: 'test_lifecycle');
  }

  /// Clear current test context
  void clearTestContext() {
    if (_currentTest != null && _testStartTime != null) {
      final duration = DateTime.now().difference(_testStartTime!);
      info('Test completed: $_currentTest (duration: ${duration.inSeconds}s)',
          category: 'test_lifecycle');
    }
    _currentTest = null;
    _testStartTime = null;
  }

  /// Add a log entry
  void log(
    LogLevel level,
    String message, {
    String? category,
    Map<String, dynamic>? metadata,
  }) {
    final entry = LogEntry(
      level: level,
      message: message,
      category: category ?? _currentTest,
      metadata: metadata,
    );

    _logs.add(entry);
    _controller.add(entry);

    // Print to console based on level
    if (TestConfig.verboseLogging || level.index >= LogLevel.warning.index) {
      print(entry);
    }
  }

  /// Debug level log
  void debug(String message, {String? category, Map<String, dynamic>? metadata}) {
    log(LogLevel.debug, message, category: category, metadata: metadata);
  }

  /// Info level log
  void info(String message, {String? category, Map<String, dynamic>? metadata}) {
    log(LogLevel.info, message, category: category, metadata: metadata);
  }

  /// Warning level log
  void warning(String message, {String? category, Map<String, dynamic>? metadata}) {
    log(LogLevel.warning, message, category: category, metadata: metadata);
  }

  /// Error level log
  void error(String message, {String? category, Map<String, dynamic>? metadata}) {
    log(LogLevel.error, message, category: category, metadata: metadata);
  }

  /// Log UI rebuild
  void logRebuild(String widgetName, {Map<String, dynamic>? data}) {
    debug('UI Rebuild: $widgetName', category: 'ui_rebuild', metadata: data);
  }

  /// Log translation service call
  void logTranslation(String text, String from, String to) {
    info('Translation: $from → $to',
        category: 'translation',
        metadata: {
          'textLength': text.length,
          'textPreview': text.length > 50 ? '${text.substring(0, 50)}...' : text,
        });
  }

  /// Log settings change
  void logSettingsChange(String setting, dynamic oldValue, dynamic newValue) {
    info('Settings changed: $setting',
        category: 'settings',
        metadata: {
          'oldValue': oldValue,
          'newValue': newValue,
        });
  }

  /// Log navigation event
  void logNavigation(String from, String to) {
    info('Navigation: $from → $to', category: 'navigation');
  }

  /// Log API call
  void logApiCall(String endpoint, String method, {Map<String, dynamic>? params}) {
    debug('API Call: $method $endpoint',
        category: 'api',
        metadata: params);
  }

  /// Log user action
  void logUserAction(String action, {Map<String, dynamic>? data}) {
    info('User action: $action',
        category: 'user_action',
        metadata: data);
  }

  /// Get logs by category
  List<LogEntry> getLogsByCategory(String category) {
    return _logs.where((log) => log.category == category).toList();
  }

  /// Get logs by level
  List<LogEntry> getLogsByLevel(LogLevel level) {
    return _logs.where((log) => log.level == level).toList();
  }

  /// Get error logs
  List<LogEntry> get errorLogs => getLogsByLevel(LogLevel.error);

  /// Get warning logs
  List<LogEntry> get warningLogs => getLogsByLevel(LogLevel.warning);

  /// Export logs to file
  Future<File> exportLogs(String filePath) async {
    final file = File(filePath);
    final json = jsonEncode({
      'testRunId': TestConfig.testRunId,
      'platform': TestConfig.isAndroid
          ? 'Android'
          : TestConfig.isIOS
              ? 'iOS'
              : 'Web',
      'timestamp': DateTime.now().toIso8601String(),
      'logs': _logs.map((e) => e.toJson()).toList(),
    });
    await file.writeAsString(json);
    return file;
  }

  /// Export logs as human-readable text
  Future<File> exportLogsAsText(String filePath) async {
    final file = File(filePath);
    final buffer = StringBuffer();

    buffer.writeln('Dual Reader E2E Test Logs');
    buffer.writeln('Test Run ID: ${TestConfig.testRunId}');
    buffer.writeln('Platform: ${TestConfig.isAndroid ? "Android" : TestConfig.isIOS ? "iOS" : "Web"}');
    buffer.writeln('Timestamp: ${DateTime.now().toIso8601String()}');
    buffer.writeln('${'=' * 70}');
    buffer.writeln();

    for (final log in _logs) {
      buffer.writeln(log);
    }

    await file.writeAsString(buffer.toString());
    return file;
  }

  /// Clear all logs
  void clear() {
    _logs.clear();
  }

  /// Dispose the logger
  void dispose() {
    _controller.close();
  }
}

/// Mixin for test classes to add logging capabilities
mixin TestLogging {
  final TestLogger logger = TestLogger();

  /// Log test setup
  void logTestSetup(String testName) {
    logger.setTestContext(testName);
    logger.info('Setting up: $testName', category: 'test_setup');
  }

  /// Log test teardown
  void logTestTeardown(String testName) {
    logger.info('Tearing down: $testName', category: 'test_teardown');
    logger.clearTestContext();
  }

  /// Export logs on test failure
  Future<void> exportLogsOnFailure(String testName) async {
    try {
      await TestHelpers.ensureTestDirectory(TestConfig.logDir);
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final logPath = '${TestConfig.logDir}/$testName-$timestamp.log';
      await logger.exportLogsAsText(logPath);
      logger.info('Logs exported to: $logPath', category: 'test_export');
    } catch (e) {
      print('⚠️  Failed to export logs: $e');
    }
  }
}

/// Import TestHelpers for the exportLogsOnFailure method
import 'test_helpers.dart';
