import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dual_reader/src/core/router/routes.dart';
import 'package:dual_reader/src/core/router/guards/route_guards.dart';
import 'package:dual_reader/src/presentation/screens/library_screen.dart';
import 'package:dual_reader/src/presentation/screens/dual_reader_screen.dart';
import 'package:dual_reader/src/presentation/screens/settings_screen.dart';
import 'package:dual_reader/src/core/utils/navigation_observer.dart';
import 'package:dual_reader/src/core/utils/logging_service.dart';

/// Application router configuration
///
/// This router handles all navigation in the Dual Reader app.
/// It supports:
/// - Deep linking from external apps
/// - State preservation across restarts
/// - Platform-specific navigation (Android back button, iOS swipe back)
/// - Web browser history integration
///
/// Usage:
/// ```dart
/// // In MaterialApp.router
/// routerConfig: appRouter.router
///
/// // Navigate programmatically
/// context.go(AppRoutes.settings);
/// ```
class AppRouter {
  AppRouter._(); // Private constructor

  static final AppRouter _instance = AppRouter._();
  factory AppRouter() => _instance;

  /// The GoRouter instance
  late final GoRouter router;

  /// Navigation observer for analytics and state preservation
  final NavigationObserver _navigationObserver = NavigationObserver();

  /// Initialize the router with configuration
  ///
  /// Call this in main() before runApp()
  void init() {
    router = GoRouter(
      debugLogDiagnostics: kDebugMode,
      initialLocation: AppRoutes.home,
      observers: [
        _navigationObserver,
      ],
      redirect: _handleRedirect,
      errorBuilder: _handleError,
      routes: _routes,
      // Platform-specific configuration
      androidBackButtonPopEnabled: true, // Handle Android back button
      // Web-specific configuration
      webConfiguration: const WebConfiguration(
        // Use URL hash for web routing
        useFragment: false,
      ),
    );

    LoggingService.info('AppRouter', 'Router initialized');
  }

  /// Handle redirects and route guards
  String? _handleRedirect(BuildContext context, GoRouterState state) {
    // Apply route guards
    final redirect = RouteGuards.handleRedirect(context, state);
    if (redirect != null) {
      return redirect;
    }

    // No redirect needed
    return null;
  }

  /// Handle navigation errors
  Widget _handleError(BuildContext context, GoRouterState state) {
    LoggingService.warning(
      'AppRouter',
      'Navigation error: ${state.uri}',
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Page Not Found'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            const Text(
              'Page not found',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'The page ${state.uri} does not exist.',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.home),
              child: const Text('Go to Library'),
            ),
          ],
        ),
      ),
    );
  }

  /// Define all application routes
  List<RouteBase> get _routes => [
        /// Main route branch
        GoRoute(
          path: AppRoutes.home,
          name: 'home',
          builder: (context, state) => const LibraryScreen(),
          routes: [
            /// Reader route - displays a book for reading
            GoRoute(
              path: AppRoutes.readerPath.split('/').last, // 'read'
              name: 'reader',
              builder: (context, state) {
                final bookId = state.pathParameters[AppRoutes.bookIdParam]!;
                LoggingService.info(
                  'AppRouter',
                  'Navigating to reader for book: $bookId',
                );
                return DualReaderScreen(bookId: bookId);
              },
              // Optional: Query parameters for page/chapter
              // Example: /read/book123?page=5&chapter=2
            ),

            /// Settings route
            GoRoute(
              path: 'settings',
              name: 'settings',
              builder: (context, state) => const SettingsScreen(),
              // Future: Add sub-routes for specific settings tabs
              // routes: [
              //   GoRoute(
              //     path: 'language',
              //     name: 'language_settings',
              //     builder: (context, state) => const SettingsScreen(initialTab: SettingsTab.language),
              //   ),
              // ],
            ),
          ],
        ),
      ];

  /// Get the current route path
  String? get currentLocation => router.routeInformationProvider.value.uri.path;

  /// Check if we're at the home screen
  bool get isAtHome => currentLocation == AppRoutes.home;

  /// Get navigation observer for analytics
  NavigationObserver get observer => _navigationObserver;

  /// Handle deep link
  ///
  /// Call this when app receives a deep link from external source
  void handleDeepLink(String link) {
    LoggingService.info('AppRouter', 'Handling deep link: $link');

    try {
      final uri = Uri.parse(link);

      // Handle dualreader://book/{bookId} pattern
      if (uri.scheme == AppRoutes.deepLinkBookScheme) {
        if (uri.host == AppRoutes.deepLinkBookHost) {
          final bookId = uri.pathSegments.isNotEmpty
              ? uri.pathSegments.first
              : '';
          if (bookId.isNotEmpty) {
            router.go(AppRoutes.reader(bookId: bookId));
          }
        }
        return;
      }

      // Handle https://dualreader.app/book/{bookId} pattern (web)
      if (uri.scheme == 'https' || uri.scheme == 'http') {
        final segments = uri.pathSegments;
        if (segments.isNotEmpty && segments[0] == 'book') {
          final bookId = segments.length > 1 ? segments[1] : '';
          if (bookId.isNotEmpty) {
            router.go(AppRoutes.reader(bookId: bookId));
          }
        }
      }
    } catch (e) {
      LoggingService.error('AppRouter', 'Failed to handle deep link', error: e);
    }
  }
}

/// Global router instance
///
/// Usage in MaterialApp.router:
/// ```dart
/// routerConfig: appRouter.router
/// ```
final appRouter = AppRouter();

/// Initialize router (call in main())
void initAppRouter() => appRouter.init();

/// Extension to add go_router convenience methods to BuildContext
extension AppRouterContext on BuildContext {
  /// Navigate to a new location
  void goRoute(String location) {
    go(location);
  }

  /// Push a new location onto the navigation stack
  void pushRoute(String location) {
    push(location);
  }

  /// Replace the current location
  void replaceRoute(String location) {
    replace(location);
  }

  /// Check if a route matches the current location
  bool isRoute(String route) {
    return GoRouterState.of(this).uri.path == route;
  }

  /// Check if current location matches a pattern
  bool matchesRoute(String pattern) {
    final uri = GoRouterState.of(this).uri;
    return uri.path.startsWith(pattern);
  }
}
