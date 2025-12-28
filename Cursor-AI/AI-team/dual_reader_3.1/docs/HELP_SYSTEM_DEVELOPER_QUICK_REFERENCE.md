# Help System Developer Quick Reference

Quick reference guide for developers working with the Dual Reader 3.1 help system.

## Quick Access

### Adding Help Icon to Screen
```dart
AppBar(
  actions: [
    IconButton(
      icon: const Icon(Icons.help_outline),
      onPressed: () => context.push('/help'),
      tooltip: HelpService.getTooltip('help'),
    ),
  ],
)
```

### Adding Tooltip to Widget
```dart
Tooltip(
  message: HelpService.getTooltip('feature_key'),
  child: YourWidget(),
)
```

### Adding Help Icon Next to Setting
```dart
Row(
  children: [
    Expanded(child: SettingWidget()),
    IconButton(
      icon: const Icon(Icons.help_outline),
      onPressed: () => _showHelpTooltip(context, 'setting_key'),
      tooltip: HelpService.getTooltip('setting_key'),
    ),
  ],
)
```

### Using HelpIcon Widget
```dart
HelpIcon(
  featureKey: 'bookmark',
  showDialog: false, // Set to true to show dialog instead of navigating
)
```

### Using ContextualHelp Wrapper
```dart
ContextualHelp(
  featureKey: 'translation_language',
  child: YourWidget(),
)
```

## Available Tooltip Keys

### Library & Import
- `import_book` - Import button
- `library_search` - Search bar
- `library_sort` - Sort options
- `delete_book` - Delete book

### Translation
- `translation_language` - Language selector
- `auto_translate` - Auto-translate toggle
- `sync_scrolling` - Synchronized scrolling
- `translation_indicator` - Translation status

### Appearance
- `theme` - Theme selector
- `font_family` - Font family selector
- `font_size` - Font size slider
- `line_height` - Line height slider
- `margin_size` - Margin size selector
- `text_alignment` - Text alignment selector
- `panel_ratio` - Panel ratio slider

### Navigation & Reading
- `bookmark` - Bookmark button
- `bookmarks` - Bookmarks list
- `chapters` - Chapters navigation
- `page_navigation` - Page navigation
- `page_slider` - Page slider
- `page_input` - Page input field
- `previous_page` - Previous page button
- `next_page` - Next page button
- `back_to_library` - Back button

### Settings
- `settings` - Settings screen
- `export_settings` - Export settings
- `import_settings` - Import settings

### Reader Interface
- `dual_panel` - Dual panel display
- `toggle_controls` - Toggle controls
- `reading_progress` - Reading progress
- `resume_reading` - Resume reading

### Help & Documentation
- `help` - Help screen
- `documentation` - Documentation

## Help Service Methods

### Loading Documentation
```dart
// Quick tips
final tips = await HelpService.loadQuickTips();

// Getting started
final content = await HelpService.loadGettingStarted();

// Features
final content = await HelpService.loadFeatures();

// FAQ
final content = await HelpService.loadFAQ();

// User manual
final content = await HelpService.loadUserManual();
```

### Getting Tooltips
```dart
// Get tooltip for feature
final tooltip = HelpService.getTooltip('bookmark');

// Get quick tips list
final tips = HelpService.getQuickTips();

// Get random tip
final tip = HelpService.getRandomTip();
```

### Searching Documentation
```dart
final results = await HelpService.searchDocumentation('translation');
```

## Navigation to Help Screen

```dart
// Using go_router
context.push('/help');

// Direct navigation
Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => const HelpScreen()),
);
```

## Adding New Tooltips

Edit `lib/services/help_service.dart`:

```dart
static String getTooltip(String featureKey) {
  const tooltips = {
    // ... existing tooltips
    'new_feature': 'Description of new feature',
  };
  return tooltips[featureKey] ?? 'Help information not available.';
}
```

## Updating Documentation

1. Edit markdown files in `docs/` folder:
   - `docs/getting_started.md`
   - `docs/features.md`
   - `docs/faq.md`
   - `docs/user_manual.md`

2. Files are automatically loaded as assets (configured in `pubspec.yaml`)

3. Changes take effect after app restart (or hot reload for tooltips)

## Help Widgets Overview

### HelpIcon
- Simple help icon button
- Shows tooltip or navigates to help
- Can show dialog

### ContextualHelp
- Wraps widget with help tooltip
- Shows help icon overlay
- Opens help dialog

### HelpOverlay
- Interactive overlay highlighting features
- "Show once" functionality
- Links to full help

### HelpBanner
- Banner for help messages
- Dismissible
- Links to more help

### WelcomeDialog
- First-time user welcome
- Shows on app launch
- Links to help

### QuickTipsBanner
- Rotating tips for new users
- Previous/Next navigation
- Dismissible

## Best Practices

1. **Always add tooltips** to interactive elements
2. **Use consistent tooltip keys** from the help service
3. **Add help icons** next to complex settings
4. **Link to help** from error messages when appropriate
5. **Keep tooltips concise** but informative
6. **Update documentation** when adding new features
7. **Test help** on all platforms (mobile, tablet, desktop)

## Testing Help Features

```dart
// Test tooltip display
final tooltip = HelpService.getTooltip('bookmark');
expect(tooltip, isNotEmpty);

// Test documentation loading
final content = await HelpService.loadGettingStarted();
expect(content, isNotEmpty);

// Test help screen navigation
await tester.tap(find.byIcon(Icons.help_outline));
await tester.pumpAndSettle();
expect(find.text('Help & Documentation'), findsOneWidget);
```

## Common Patterns

### Pattern 1: Setting with Help Icon
```dart
Row(
  children: [
    Expanded(
      child: DropdownButton<String>(
        value: currentValue,
        items: items,
        onChanged: onChanged,
      ),
    ),
    IconButton(
      icon: const Icon(Icons.help_outline),
      onPressed: () => _showHelpTooltip(context, 'setting_key'),
      tooltip: HelpService.getTooltip('setting_key'),
    ),
  ],
)
```

### Pattern 2: Button with Tooltip
```dart
Tooltip(
  message: HelpService.getTooltip('bookmark'),
  child: IconButton(
    icon: const Icon(Icons.bookmark_border),
    onPressed: onPressed,
  ),
)
```

### Pattern 3: Help Icon in AppBar
```dart
AppBar(
  actions: [
    IconButton(
      icon: const Icon(Icons.help_outline),
      onPressed: () => context.push('/help'),
      tooltip: HelpService.getTooltip('help'),
    ),
  ],
)
```

## Troubleshooting

### Tooltip not showing
- Check if tooltip key exists in `HelpService.getTooltip()`
- Verify widget is wrapped with `Tooltip` widget
- Check if tooltip message is not empty

### Documentation not loading
- Verify file exists in `docs/` folder
- Check `pubspec.yaml` includes file in assets
- Ensure file is not empty
- Check for markdown syntax errors

### Help screen not navigating
- Verify route `/help` exists in `AppRouter`
- Check `go_router` is properly configured
- Ensure `HelpScreen` is imported

---

*For detailed information, see the full Help System Developer Guide.*
