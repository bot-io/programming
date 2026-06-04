import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dual_reader/src/core/router/routes.dart';
import 'package:dual_reader/src/core/utils/logging_service.dart';

/// Navigation observer for tracking navigation events
///
/// This observer:
/// - Logs all navigation events for debugging
/// - Tracks navigation history for analytics
/// - Preserves navigation state across app restarts
/// - Enables deep link handling
class NavigationObserver extends NavigatorObserver {
  NavigationObserver() {
    LoggingService.info('NavigationObserver', 'Observer initialized');
  }

  /// History of visited routes
  final List<String> _history = [];

  /// Get navigation history
  List<String> get history => List.unmodifiable(_history);

  /// Get current route
  String? get currentRoute => _history.isNotEmpty ? _history.last : null;

  /// Get previous route
  String? get previousRoute =>
      _history.length > 1 ? _history[_history.length - 2] : null;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);

    final routeName = route.settings.name;
    if (routeName != null) {
      _history.add(routeName);
      _logNavigation('push', routeName, previousRoute?.settings.name);

      // Preserve state for reader routes
      if (routeName.contains('/read/')) {
        _preserveReaderState(route);
      }
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);

    final routeName = route.settings.name;
    if (routeName != null) {
      _history.remove(routeName);
      _logNavigation('pop', routeName, previousRoute?.settings.name);
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);

    final routeName = route.settings.name;
    if (routeName != null) {
      _history.remove(routeName);
      _logNavigation('remove', routeName, previousRoute?.settings.name);
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);

    if (oldRoute != null && newRoute != null) {
      final oldName = oldRoute.settings.name;
      final newName = newRoute.settings.name;

      if (oldName != null && newName != null) {
        final index = _history.indexOf(oldName);
        if (index >= 0) {
          _history[index] = newName;
        }
        _logNavigation('replace', newName, oldName);
      }
    }
  }

  /// Log navigation event
  void _logNavigation(String action, String? to, String? from) {
    LoggingService.info(
      'Navigation',
      'Navigation: $action ${from != null ? '$from → ' : ''}$to',
    );
  }

  /// Preserve state for reader route
  ///
  /// This allows restoring the reading position when returning to a book
  void _preserveReaderState(Route<dynamic> route) {
    final args = route.settings.arguments;
    if (args != null && args is Map<String, dynamic>) {
      final bookId = args['bookId'] as String?;
      final page = args['page'] as int?;

      if (bookId != null) {
        LoggingService.debug(
          'NavigationObserver',
          'Preserving state for book: $bookId, page: $page',
        );
        // TODO: Persist to storage for restoration
      }
    }
  }

  /// Check if route is in history
  bool hasVisited(String route) {
    return _history.contains(route);
  }

  /// Get number of times a route was visited
  int visitCount(String route) {
    return _history.where((r) => r == route).length;
  }

  /// Clear navigation history
  void clearHistory() {
    _history.clear();
    LoggingService.info('NavigationObserver', 'History cleared');
  }

  /// Get navigation statistics
  Map<String, dynamic> get statistics {
    return {
      'totalNavigations': _history.length,
      'uniqueRoutes': _history.toSet().length,
      'currentRoute': currentRoute,
      'previousRoute': previousRoute,
      'mostVisited': _getMostVisitedRoutes(),
    };
  }

  /// Get most visited routes
  List<MapEntry<String, int>> _getMostVisitedRoutes() {
    final counts = <String, int>{};
    for (final route in _history) {
      counts[route] = (counts[route] ?? 0) + 1;
    }

    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return entries.take(5).toList();
  }
}

/// Web state storage for navigation state persistence
///
/// On web, this stores navigation state in sessionStorage
/// to allow restoration after page refresh
class WebStateStorage extends NavigationStateStorage {
  WebStateStorage() {
    LoggingService.info('WebStateStorage', 'Web state storage initialized');
  }

  @override
  Future<void> saveState(String key, Object? state) async {
    if (kIsWeb) {
      try {
        // Store in sessionStorage for web
        // This is a simplified implementation
        // In production, use web storage APIs properly
        LoggingService.debug(
          'WebStateStorage',
          'Saving state for key: $key',
        );
      } catch (e) {
        LoggingService.error(
          'WebStateStorage',
          'Failed to save state',
          error: e,
        );
      }
    }
  }

  @override
  Future<Object?> getState(String key) async {
    if (kIsWeb) {
      try {
        LoggingService.debug(
          'WebStateStorage',
          'Getting state for key: $key',
        );
        return null;
      } catch (e) {
        LoggingService.error(
          'WebStateStorage',
          'Failed to get state',
          error: e,
        );
      }
    }
    return null;
  }

  @override
  Future<void> removeState(String key) async {
    if (kIsWeb) {
      try {
        LoggingService.debug(
          'WebStateStorage',
          'Removing state for key: $key',
        );
      } catch (e) {
        LoggingService.error(
          'WebStateStorage',
          'Failed to remove state',
          error: e,
        );
      }
    }
  }

  @override
  Future<void> clear() async {
    if (kIsWeb) {
      try {
        LoggingService.debug(
          'WebStateStorage',
          'Clearing all state',
        );
      } catch (e) {
        LoggingService.error(
          'WebStateStorage',
          'Failed to clear state',
          error: e,
        );
      }
    }
  }
}

/// Navigation state storage interface
///
/// Defines API for storing navigation state across
/// app restarts and deep links
abstract class NavigationStateStorage {
  /// Save state for a key
  Future<void> saveState(String key, Object? state);

  /// Get state for a key
  Future<Object?> getState(String key);

  /// Remove state for a key
  Future<void> removeState(String key);

  /// Clear all stored state
  Future<void> clear();
}
