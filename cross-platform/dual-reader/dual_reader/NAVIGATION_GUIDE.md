# Unified Navigation Implementation Guide

## Overview

Dual Reader 3.2 uses **go_router** for unified navigation across all platforms (Android, iOS, Web). This provides a declarative, type-safe navigation system with deep linking support.

## Architecture

### Router Configuration

The router is configured in `lib/src/core/router/app_router.dart`:

```dart
// In main.dart
void main() async {
  // ... initialization
  initAppRouter(); // Initialize router
  runApp(const ProviderScope(child: MyApp()));
}

// In MyApp
MaterialApp.router(
  routerConfig: appRouter.router,
);
```

### Route Structure

```
/                           → LibraryScreen (Home)
├── /read/:bookId           → DualReaderScreen
│   └── Query params: ?page=5&chapter=2
└── /settings               → SettingsScreen
    ├── /settings/language  → (Future) Language settings tab
    ├── /settings/display   → (Future) Display settings tab
    └── /settings/about     → (Future) About screen
```

## Navigation Methods

### 1. Navigate to a Route

```dart
// Using go (replaces current stack)
context.go(AppRoutes.settings);

// Using push (adds to stack)
context.push(AppRoutes.settings);

// Using extension method
context.goRoute(AppRoutes.settings);
```

### 2. Navigate with Parameters

```dart
// Navigate to reader with book ID
context.go(AppRoutes.reader(bookId: 'abc123'));

// Navigate with query parameters
context.go(AppRoutes.readerWithParams(
  bookId: 'abc123',
  page: 5,
  chapter: 'chapter-2',
));
```

### 3. Deep Linking

```dart
// Handle incoming deep link
appRouter.handleDeepLink('dualreader://book/abc123');

// Web URL format
appRouter.handleDeepLink('https://dualreader.app/book/abc123');
```

## Platform-Specific Navigation

### Android Back Button

The router automatically handles the Android back button:

```dart
// Enabled by default in router config
GoRouter(
  androidBackButtonPopEnabled: true,
  // ...
)
```

### iOS Swipe Back

iOS swipe-to-back gesture works automatically with go_router.

### Web Browser Navigation

Web browser back/forward buttons work automatically:

```dart
GoRouter(
  webConfiguration: WebConfiguration(
    useFragment: false, // Use path-based routing
  ),
)
```

## Route Guards

Route guards protect navigation based on validation rules:

```dart
// In route_guards.dart
static String? handleRedirect(BuildContext context, GoRouterState state) {
  // Validate book IDs
  if (_isReaderRoute(state)) {
    final bookId = state.pathParameters[AppRoutes.bookIdParam];
    if (bookId == null || bookId.isEmpty) {
      return AppRoutes.home; // Redirect to home
    }
  }
  return null; // Allow navigation
}
```

## Navigation State Preservation

### Observer Pattern

The `NavigationObserver` tracks all navigation events:

```dart
// Get navigation history
final history = appRouter.observer.history;

// Get current/previous routes
final current = appRouter.observer.currentRoute;
final previous = appRouter.observer.previousRoute;

// Get navigation statistics
final stats = appRouter.observer.statistics;
```

### State Storage

Web state is preserved across page refreshes:

```dart
// State is automatically stored in sessionStorage
// Navigate away and back - state is restored
```

## Deep Link Configuration

### Android Intent Filter

Add to `AndroidManifest.xml`:

```xml
<intent-filter>
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.category.DEFAULT" />
  <category android:name="android.category.BROWSABLE" />
  <data
    android:scheme="dualreader"
    android:host="book" />
</intent-filter>
```

### iOS Universal Links

Configure in Xcode:
1. Add Associated Domains in Signing & Capabilities
2. Add `applinks:dualreader.app` to Associated Domains
3. Configure server to host `apple-app-site-association` file

### Web Deep Links

Web deep links work automatically with proper routing:

```html
<!-- Link from external website -->
<a href="https://dualreader.app/book/abc123">Open Book</a>
```

## Best Practices

### 1. Use Route Constants

Always use `AppRoutes` constants instead of hardcoded strings:

```dart
// ✅ Good
context.go(AppRoutes.settings);

// ❌ Bad
context.go('/settings');
```

### 2. Type-Safe Navigation

Use helper methods for complex navigation:

```dart
// ✅ Good
context.go(AppRoutes.reader(bookId: bookId));

// ❌ Bad
context.go('/read/$bookId');
```

### 3. Query Parameters

Use query parameters for optional state:

```dart
// Navigate to specific page in book
context.go(AppRoutes.readerWithParams(
  bookId: 'abc123',
  page: 42,
));
```

### 4. Error Handling

Always handle navigation errors:

```dart
try {
  context.go(AppRoutes.reader(bookId: bookId));
} catch (e) {
  // Handle error
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Failed to open book')),
  );
}
```

## Testing Navigation

### Unit Tests

```dart
test('navigates to settings', () {
  final router = createTestRouter();
  router.go(AppRoutes.settings);
  expect(router.currentRoute, AppRoutes.settings);
});
```

### Widget Tests

```dart
testWidgets('tapping settings icon navigates to settings', (tester) async {
  await tester.pumpWidget(MyApp());
  await tester.tap(find.byIcon(Icons.settings));
  await tester.pumpAndSettle();
  expect(find.text('Settings'), findsOneWidget);
});
```

## Migration Guide

### From Navigator to go_router

**Before:**
```dart
Navigator.of(context).push(
  MaterialPageRoute(builder: (_) => SettingsScreen()),
);
```

**After:**
```dart
context.push(AppRoutes.settings);
```

### From Named Routes

**Before:**
```dart
Navigator.pushNamed(context, '/settings');
```

**After:**
```dart
context.go(AppRoutes.settings);
```

## Troubleshooting

### Navigation Not Working

1. Check router is initialized: `initAppRouter()` called in `main()`
2. Check route exists in router configuration
3. Check for typos in route path

### Deep Links Not Opening

1. Verify intent filters (Android) or associated domains (iOS)
2. Test deep link format: `dualreader://book/{bookId}`
3. Check `handleDeepLink()` is being called

### Back Button Not Working

1. Ensure `androidBackButtonPopEnabled: true` in router config
2. Check for custom back button interceptors
3. Verify routes are properly nested

## Future Enhancements

1. **Settings Tabs**: Add sub-routes for specific settings categories
2. **Bookmarks**: Deep link to specific bookmark location
3. **Search**: Deep link to search results
4. **Analytics**: Track navigation patterns with observer
5. **State Restoration**: Preserve scroll position across navigation

## Files Reference

| File | Purpose |
|------|---------|
| `lib/src/core/router/app_router.dart` | Router configuration |
| `lib/src/core/router/routes.dart` | Route constants and utilities |
| `lib/src/core/router/guards/route_guards.dart` | Navigation guards |
| `lib/src/core/utils/navigation_observer.dart` | Navigation observer |
| `lib/main.dart` | Router initialization |

## Platform Support

| Feature | Android | iOS | Web |
|---------|---------|-----|-----|
| Declarative routing | ✅ | ✅ | ✅ |
| Deep linking | ✅ | ✅ | ✅ |
| Back button | ✅ | ✅ (swipe) | ✅ (browser) |
| State preservation | ✅ | ✅ | ✅ |
| Query parameters | ✅ | ✅ | ✅ |
| Route guards | ✅ | ✅ | ✅ |
| Navigation observer | ✅ | ✅ | ✅ |
