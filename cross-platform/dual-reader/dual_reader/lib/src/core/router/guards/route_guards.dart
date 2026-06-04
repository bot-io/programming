import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dual_reader/src/core/router/routes.dart';
import 'package:dual_reader/src/core/utils/logging_service.dart';

/// Route guards for navigation protection
///
/// Route guards can redirect navigation based on:
/// - Authentication state (future)
/// - Onboarding completion (future)
/// - Data validation
/// - Platform capabilities
class RouteGuards {
  RouteGuards._(); // Private constructor

  /// Handle all route guards
  ///
  /// Returns a redirect path if navigation should be redirected,
  /// or null if navigation should proceed normally.
  static String? handleRedirect(BuildContext context, GoRouterState state) {
    // Validate book ID for reader route
    if (_isReaderRoute(state)) {
      final bookId = state.pathParameters[AppRoutes.bookIdParam];
      if (bookId == null || bookId.isEmpty) {
        LoggingService.warning(
          'RouteGuards',
          'Invalid book ID, redirecting to home',
        );
        return AppRoutes.home;
      }

      // Validate book ID format (basic UUID or slug check)
      if (!_isValidBookId(bookId)) {
        LoggingService.warning(
          'RouteGuards',
          'Invalid book ID format: $bookId',
        );
        return AppRoutes.home;
      }
    }

    // No redirect needed
    return null;
  }

  /// Check if current route is the reader route
  static bool _isReaderRoute(GoRouterState state) {
    return state.uri.path.startsWith(AppRoutes.readerPath);
  }

  /// Validate book ID format
  ///
  /// Book IDs should be UUIDs or valid slugs
  static bool _isValidBookId(String bookId) {
    // UUID format (v4): xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
    final uuidRegex = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      caseSensitive: false,
    );

    // Slug format: lowercase letters, numbers, hyphens
    final slugRegex = RegExp(r'^[a-z0-9-]+$');

    return uuidRegex.hasMatch(bookId) || slugRegex.hasMatch(bookId);
  }

  /// Guard: Check if user has completed onboarding
  ///
  /// Redirects to onboarding if not completed
  static String? requireOnboarding(GoRouterState state) {
    // TODO: Implement when onboarding is added
    return null;
  }

  /// Guard: Check if user is authenticated
  ///
  /// Redirects to login if not authenticated
  static String? requireAuth(GoRouterState state) {
    // TODO: Implement when auth is added
    return null;
  }

  /// Guard: Check platform capabilities
  ///
  /// Redirects if platform doesn't support required features
  static String? checkPlatformCapabilities(GoRouterState state) {
    // TODO: Implement when platform features are available
    return null;
  }
}

/// Navigation guard result
///
/// Represents the result of a guard check
class GuardResult {
  const GuardResult({
    this.redirect,
    this.reason,
  });

  /// Redirect path if navigation should be redirected
  final String? redirect;

  /// Reason for redirect (for logging/debugging)
  final String? reason;

  /// Create a guard result that allows navigation
  const GuardResult.allow() : redirect = null, reason = null;

  /// Create a guard result that redirects navigation
  const GuardResult.redirect(String path, {String? reason})
      : redirect = path,
        reason = reason;

  /// Check if navigation is allowed
  bool get isAllowed => redirect == null;

  /// Check if navigation should be redirected
  bool get shouldRedirect => redirect != null;
}
