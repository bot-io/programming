/// Route constants for Dual Reader application
///
/// All route paths are defined here to ensure consistency
/// across the application and enable type-safe navigation.
///
/// Usage:
/// ```dart
/// // Navigate to settings
/// context.go(AppRoutes.settings);
///
/// // Navigate to reader with book ID
/// context.go(AppRoutes.reader(bookId: 'abc123'));
/// ```
class AppRoutes {
  AppRoutes._(); // Private constructor to prevent instantiation

  // Base routes
  static const String home = '/';
  static const String library = '/';

  // Reader routes
  static const String readerPath = '/read';
  static String reader({required String bookId}) => '/read/$bookId';

  // Settings routes
  static const String settings = '/settings';
  static const String settingsLanguage = '/settings/language';
  static const String settingsDisplay = '/settings/display';
  static const String settingsAbout = '/settings/about';
  static const String settingsLanguageModels = '/settings/language-models';

  // Parameter names (for URL parsing)
  static const String bookIdParam = 'bookId';

  // Deep linking patterns (for external apps)
  static const String deepLinkBookScheme = 'dualreader';
  static const String deepLinkBookHost = 'book';
  static const String deepLinkBookPattern = 'dualreader://book/{bookId}';

  // Query parameter names
  static const String pageParam = 'page';
  static const String chapterParam = 'chapter';

  /// Build a reader route with optional page and chapter
  static String readerWithParams({
    required String bookId,
    int? page,
    String? chapter,
  }) {
    final buffer = StringBuffer('/read/$bookId');
    final params = <String, String>{};

    if (page != null) params[pageParam] = page.toString();
    if (chapter != null) params[chapterParam] = chapter;

    if (params.isNotEmpty) {
      buffer.write('?');
      buffer.writeAll(
        params.entries.map((e) => '${e.key}=${e.value}'),
        '&',
      );
    }

    return buffer.toString();
  }

  /// Extract book ID from a reader route path
  static String? extractBookId(String path) {
    final uri = Uri.tryParse(path);
    if (uri == null) return null;

    // Match /read/{bookId} pattern
    final segments = uri.pathSegments;
    if (segments.length >= 2 && segments[0] == 'read') {
      return segments[1];
    }

    return null;
  }

  /// Extract page number from query parameters
  static int? extractPage(Uri uri) {
    final pageStr = uri.queryParameters[pageParam];
    if (pageStr != null) {
      return int.tryParse(pageStr);
    }
    return null;
  }

  /// Extract chapter from query parameters
  static String? extractChapter(Uri uri) {
    return uri.queryParameters[chapterParam];
  }
}

/// Navigation state keys for state preservation
///
/// These keys are used to preserve navigation state
/// across app restarts and deep links.
class NavStateKeys {
  NavStateKeys._(); // Private constructor

  static const String lastBookId = 'last_book_id';
  static const String lastPage = 'last_page';
  static const String lastChapter = 'last_chapter';
  static const String scrollPosition = 'scroll_position';
  static const String selectedTab = 'selected_tab';
}

/// Route transition types
enum RouteTransition {
  /// Default platform transition
  systemDefault,

  /// No transition (instant)
  none,

  /// Material fade through
  fade,

  /// Material zoom
  zoom,

  /// iOS cupertino
  cupertino,
}
