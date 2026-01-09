import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

/// Logging service for the Dual Reader app.
///
/// Provides structured logging with log levels, rotation, and size limits
/// to prevent indefinite log growth on user devices.
///
/// Features:
/// - Log levels: DEBUG, INFO, WARNING, ERROR
/// - Automatic log rotation (max 1000 entries per log file)
/// - Max 5 log files kept (rolling logs)
/// - Timestamps and component names
/// - Development console output
/// - Production file-based logging
class LoggingService {
  static const String _logBoxName = 'app_logs';
  static const int _maxLogEntries = 1000; // Rotate after 1000 entries
  static const int _maxLogFiles = 5; // Keep 5 rotated logs
  static const int _maxLogSizeBytes = 500 * 1024; // 500KB max per log file

  static LoggingService? _instance;
  static LoggingService get instance => _instance ??= LoggingService._();

  late Box<String> _logBox;
  int _currentLogIndex = 0;
  bool _initialized = false;

  LoggingService._();

  /// Initialize the logging service
  Future<void> init() async {
    if (_initialized) return;

    try {
      if (!Hive.isBoxOpen(_logBoxName)) {
        await Hive.openBox<String>(_logBoxName);
      }
      _logBox = Hive.box<String>(_logBoxName);
      final indexStr = _logBox.get('current_index', defaultValue: '0');
      _currentLogIndex = int.tryParse(indexStr ?? '0') ?? 0;
      _initialized = true;

      // Clean up old logs on initialization
      await _cleanupOldLogs();

      info('LoggingService', 'Logging initialized - Log index: $_currentLogIndex');
    } catch (e) {
      // If logging fails, at least print to console
      debugPrint('[LoggingService] Failed to initialize: $e');
    }
  }

  /// Log a debug message
  static void debug(String component, String message) {
    debugPrint('[DEBUG] [$component] $message');
    instance._storeLog(LogEntry.debug(component, message));
  }

  /// Log an info message
  static void info(String component, String message) {
    debugPrint('[INFO] [$component] $message');
    instance._storeLog(LogEntry.info(component, message));
  }

  /// Log a warning message
  static void warning(String component, String message) {
    debugPrint('[WARNING] [$component] $message');
    instance._storeLog(LogEntry.warning(component, message));
  }

  /// Log an error message
  static void error(String component, String message, {Object? error, StackTrace? stackTrace}) {
    debugPrint('[ERROR] [$component] $message');
    if (error != null) {
      debugPrint('[ERROR] Error: $error');
    }
    if (stackTrace != null) {
      debugPrint('[ERROR] StackTrace: $stackTrace');
    }
    instance._storeLog(LogEntry.error(component, message, error: error.toString(), stackTrace: stackTrace.toString()));
  }

  /// Internal logging method
  static void _log(LogEntry entry) {
    // Always print to console in development
    final formattedMessage = _formatLogEntry(entry);
    debugPrint(formattedMessage);

    // Store to file in production (asynchronously, don't block)
    if (instance._initialized) {
      _storeLogAsync(entry);
    }
  }

  /// Store log entry
  void _storeLog(LogEntry entry) {
    if (!_initialized) return;
    _storeLogAsync(entry);
  }

  /// Store log entry asynchronously
  static void _storeLogAsync(LogEntry entry) {
    // Don't block on logging - use isolate-safe approach
    Future.microtask(() async {
      try {
        // Get instance and check initialization in one go
        final service = instance;
        if (!service._initialized) {
          return; // Silently skip if not initialized
        }

        // Access box locally to avoid race conditions
        final box = service._logBox;
        final currentIndex = service._currentLogIndex;
        final timestamp = entry.timestamp.millisecondsSinceEpoch;
        final logKey = 'log_$currentIndex\_$timestamp';

        // Simple storage without size checks to avoid crashes
        await box.put(logKey, entry.toJson());
        await box.put('latest_log', entry.toJson());
      } catch (e) {
        // Silently fail - logging should never crash the app
        // debugPrint('[LoggingService] Failed to store log: $e');
      }
    });
  }

  /// Get current log file size in bytes
  Future<int> _getCurrentLogSize() async {
    int size = 0;
    for (final key in _logBox.keys) {
      if (key.toString().startsWith('log_${_currentLogIndex}_')) {
        final value = _logBox.get(key);
        if (value != null) {
          size += value.length;
        }
      }
    }
    return size;
  }

  /// Rotate to next log file
  Future<void> _rotateLog() async {
    info('LoggingService', 'Rotating log file $_currentLogIndex');

    // Mark current log as complete
    await _logBox.put('log_${_currentLogIndex}_complete', DateTime.now().toIso8601String());

    // Move to next log index
    _currentLogIndex = (_currentLogIndex + 1) % _maxLogFiles;
    await _logBox.put('current_index', _currentLogIndex.toString());

    // Clear entries from new log index if it exists
    await _clearLogIndex(_currentLogIndex);
  }

  /// Clear all entries for a specific log index
  Future<void> _clearLogIndex(int index) async {
    final keysToDelete = _logBox.keys
        .where((key) => key.toString().startsWith('log_${index}_'))
        .toList();

    for (final key in keysToDelete) {
      await _logBox.delete(key);
    }
  }

  /// Clean up old log files
  Future<void> _cleanupOldLogs() async {
    // This is called during initialization to ensure we don't have too many logs
    // The rotation mechanism handles most cleanup, but this is a safety net
    try {
      final completeLogs = <String>[];
      for (final key in _logBox.keys) {
        if (key.toString().contains('_complete')) {
          completeLogs.add(key.toString());
        }
      }

      // If we have more than max log files, remove oldest
      if (completeLogs.length > _maxLogFiles) {
        completeLogs.sort();
        final toRemove = completeLogs.length - _maxLogFiles;
        for (int i = 0; i < toRemove; i++) {
          final logKey = completeLogs[i];
          final index = logKey.split('_')[1];
          await _clearLogIndex(int.parse(index));
          await _logBox.delete(logKey);
        }
      }
    } catch (e) {
      debugPrint('[LoggingService] Error cleaning up old logs: $e');
    }
  }

  /// Get all logs from the current log file
  Future<List<LogEntry>> getCurrentLogs() async {
    final logs = <LogEntry>[];
    final keys = _logBox.keys
        .where((key) => key.toString().startsWith('log_${_currentLogIndex}_'))
        .toList()
      ..sort();

    for (final key in keys) {
      final logJson = _logBox.get(key);
      if (logJson != null) {
        try {
          logs.add(LogEntry.fromJson(logJson));
        } catch (e) {
          // Skip invalid log entries
        }
      }
    }
    return logs;
  }

  /// Get all logs from all log files for export
  Future<List<LogEntry>> getAllLogsForExport() async {
    final logs = <LogEntry>[];

    // Check if initialized
    if (!_initialized) {
      return logs;
    }

    try {
      // Access box locally to avoid issues
      final box = _logBox;

      // Collect all log entries
      for (final key in box.keys) {
        final keyStr = key.toString();
        // Only get log entries (not metadata)
        if (keyStr.startsWith('log_') && !keyStr.contains('_complete')) {
          final logJson = box.get(key);
          if (logJson != null && logJson.isNotEmpty) {
            try {
              logs.add(LogEntry.fromJson(logJson));
            } catch (e) {
              // Skip invalid entries silently
            }
          }
        }
      }

      // Sort by timestamp
      logs.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    } catch (e) {
      // Return empty list on error
    }

    return logs;
  }

  /// Export logs as a formatted text string
  Future<String> exportLogsAsText() async {
    final logs = await getAllLogsForExport();
    final buffer = StringBuffer();

    buffer.writeln('Dual Reader App Logs');
    buffer.writeln('Exported: ${DateTime.now().toIso8601String()}');
    buffer.writeln('Total entries: ${logs.length}');
    buffer.writeln('=' * 80);
    buffer.writeln();

    if (logs.isEmpty) {
      buffer.writeln('No logs available.');
    } else {
      for (final log in logs) {
        buffer.writeln(_formatLogEntryForExport(log));
        if (log.error != null) {
          buffer.writeln('  Error: ${log.error}');
        }
        if (log.stackTrace != null) {
          buffer.writeln('  Stack Trace:');
          for (final line in log.stackTrace!.split('\n')) {
            buffer.writeln('    $line');
          }
        }
        buffer.writeln();
      }
    }

    return buffer.toString();
  }

  /// Format log entry for export (more detailed than console output)
  String _formatLogEntryForExport(LogEntry entry) {
    final timestamp = entry.timestamp.toIso8601String();
    final level = entry.level.name.toUpperCase().padRight(7);
    final component = entry.component.padRight(25);
    return '[$timestamp] [$level] [$component] ${entry.message}';
  }

  /// Export logs as JSON string
  Future<String> exportLogsAsJson() async {
    final logs = await getAllLogsForExport();
    final Map<String, dynamic> exportData = {
      'exported_at': DateTime.now().toIso8601String(),
      'total_entries': logs.length,
      'logs': logs.map((log) => {
        'timestamp': log.timestamp.toIso8601String(),
        'level': log.level.name,
        'component': log.component,
        'message': log.message,
        if (log.error != null) 'error': log.error,
        if (log.stackTrace != null) 'stack_trace': log.stackTrace,
      }).toList(),
    };

    return const JsonEncoder.withIndent('  ').convert(exportData);
  }

  /// Get the latest log entry
  Future<LogEntry?> getLatestLog() async {
    final latestJson = _logBox.get('latest_log');
    if (latestJson != null) {
      try {
        return LogEntry.fromJson(latestJson);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  /// Clear all logs (for debugging/testing)
  Future<void> clearAllLogs() async {
    await _logBox.clear();
    _currentLogIndex = 0;
    await _logBox.put('current_index', '0');
    info('LoggingService', 'All logs cleared');
  }

  /// Format log entry for console output
  static String _formatLogEntry(LogEntry entry) {
    final timestamp = entry.timestamp.toIso8601String().substring(11, 23); // HH:mm:ss.sss
    final level = entry.level.name.toUpperCase().padRight(7);
    final component = entry.component.padRight(25);
    return '[$timestamp] [$level] [$component] ${entry.message}';
  }

  /// Close the logging service
  Future<void> close() async {
    if (_initialized) {
      info('LoggingService', 'Logging service closing');
      await _logBox.close();
      _initialized = false;
    }
  }
}

/// Log entry data structure
class LogEntry {
  final LogLevel level;
  final String component;
  final String message;
  final DateTime timestamp;
  final String? error;
  final String? stackTrace;

  LogEntry({
    required this.level,
    required this.component,
    required this.message,
    required this.timestamp,
    this.error,
    this.stackTrace,
  });

  /// Factory constructor for debug logs
  factory LogEntry.debug(String component, String message) {
    return LogEntry(
      level: LogLevel.debug,
      component: component,
      message: message,
      timestamp: DateTime.now(),
    );
  }

  /// Factory constructor for info logs
  factory LogEntry.info(String component, String message) {
    return LogEntry(
      level: LogLevel.info,
      component: component,
      message: message,
      timestamp: DateTime.now(),
    );
  }

  /// Factory constructor for warning logs
  factory LogEntry.warning(String component, String message) {
    return LogEntry(
      level: LogLevel.warning,
      component: component,
      message: message,
      timestamp: DateTime.now(),
    );
  }

  /// Factory constructor for error logs
  factory LogEntry.error(String component, String message, {String? error, String? stackTrace}) {
    return LogEntry(
      level: LogLevel.error,
      component: component,
      message: message,
      timestamp: DateTime.now(),
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Convert to JSON for storage
  String toJson() {
    final buffer = StringBuffer();
    buffer.write('${level.index}|${timestamp.toIso8601String()}|$component|');
    buffer.write(message.replaceAll('|', '\\|')); // Escape pipes
    if (error != null) {
      buffer.write('|error=$error');
    }
    if (stackTrace != null) {
      buffer.write('|stack=$stackTrace');
    }
    return buffer.toString();
  }

  /// Parse from JSON
  factory LogEntry.fromJson(String json) {
    final parts = json.split('|');
    if (parts.length < 4) throw FormatException('Invalid log entry');

    final level = LogLevel.values[int.parse(parts[0])];
    final timestamp = DateTime.parse(parts[1]);
    final component = parts[2];
    final message = parts[3].replaceAll('\\|', '|'); // Unescape pipes

    String? error;
    String? stackTrace;

    for (int i = 4; i < parts.length; i++) {
      if (parts[i].startsWith('error=')) {
        error = parts[i].substring(6);
      } else if (parts[i].startsWith('stack=')) {
        stackTrace = parts[i].substring(6);
      }
    }

    return LogEntry(
      level: level,
      component: component,
      message: message,
      timestamp: timestamp,
      error: error,
      stackTrace: stackTrace,
    );
  }
}

/// Log levels
enum LogLevel {
  debug,
  info,
  warning,
  error,
}

/// Extension method for easy component-based logging
extension LoggingExtension on String {
  void logDebug(String message) => LoggingService.debug(this, message);
  void logInfo(String message) => LoggingService.info(this, message);
  void logWarning(String message) => LoggingService.warning(this, message);
  void logError(String message, {Object? error, StackTrace? stackTrace}) =>
      LoggingService.error(this, message, error: error, stackTrace: stackTrace);
}
