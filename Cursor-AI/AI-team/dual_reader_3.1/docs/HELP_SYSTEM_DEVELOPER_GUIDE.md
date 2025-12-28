# Help System Developer Guide

## Overview

The Dual Reader 3.1 help system provides comprehensive user documentation and contextual help throughout the app. This guide explains how to use and extend the help system.

## Architecture

### Components

1. **HelpService** (`lib/services/help_service.dart`)
   - Loads documentation from assets
   - Provides tooltips for features
   - Manages quick tips
   - Handles documentation search

2. **HelpScreen** (`lib/screens/help_screen.dart`)
   - Main help screen with tabs
   - Search functionality
   - Markdown rendering
   - Responsive design

3. **Help Widgets** (`lib/widgets/`)
   - `HelpIcon` - Reusable help icon
   - `ContextualHelp` - Contextual help wrapper
   - `HelpButton` - Help button widget
   - `HelpBanner` - Help banner widget

4. **Documentation Files** (`docs/`)
   - `getting_started.md` - Getting started guide
   - `features.md` - Feature documentation
   - `faq.md` - FAQ section
   - `user_manual.md` - User manual
   - `README.md` - Documentation index

## Usage Examples

### Adding a Help Icon

```dart
import '../services/help_service.dart';
import '../widgets/help_icon.dart';

// Simple help icon with tooltip
HelpIcon(
  featureKey: 'import_book',
  tooltip: HelpService.getTooltip('import_book'),
)

// Help icon that shows dialog
HelpDialogIcon(
  featureKey: 'translation_language',
)

// Custom help icon
HelpIcon(
  featureKey: 'theme',
  icon: Icons.info_outline,
  iconSize: 20,
  iconColor: Colors.blue,
  showDialog: true,
)
```

### Adding Tooltips

```dart
import '../services/help_service.dart';

// Tooltip on a widget
Tooltip(
  message: HelpService.getTooltip('library_search'),
  child: TextField(...),
)

// Tooltip on IconButton
IconButton(
  icon: Icon(Icons.help_outline),
  tooltip: HelpService.getTooltip('settings'),
  onPressed: () => context.push('/help'),
)
```

### Adding Contextual Help

```dart
import '../widgets/contextual_help.dart';

ContextualHelp(
  featureKey: 'font_size',
  showIcon: true,
  child: Slider(...),
)
```

### Navigating to Help Screen

```dart
import 'package:go_router/go_router.dart';

// Navigate to help screen
context.push('/help');

// Navigate to help with specific section (future enhancement)
// context.push('/help?section=faq');
```

### Getting Tooltip Text

```dart
import '../services/help_service.dart';

// Get tooltip for a feature
final tooltip = HelpService.getTooltip('bookmark');

// Get quick tips
final tips = HelpService.getQuickTips();

// Get random tip
final randomTip = HelpService.getRandomTip();
```

## Adding New Tooltips

### Step 1: Add Tooltip to HelpService

Edit `lib/services/help_service.dart`:

```dart
static String getTooltip(String featureKey) {
  const tooltips = {
    // ... existing tooltips ...
    'your_new_feature': 'Description of your new feature and how to use it.',
  };
  
  return tooltips[featureKey] ?? 'Help information not available for this feature.';
}
```

### Step 2: Use Tooltip in UI

```dart
HelpIcon(
  featureKey: 'your_new_feature',
)
```

## Adding New Documentation Sections

### Step 1: Create Documentation File

Create `docs/your_section.md`:

```markdown
# Your Section Title

Content here...
```

### Step 2: Add to Assets

Edit `pubspec.yaml`:

```yaml
flutter:
  assets:
    - docs/your_section.md
```

### Step 3: Add Loading Method to HelpService

Edit `lib/services/help_service.dart`:

```dart
static const String _yourSectionPath = 'docs/your_section.md';

static Future<String> loadYourSection() async {
  try {
    final content = await rootBundle.loadString(_yourSectionPath);
    if (content.trim().isEmpty) {
      return _getDefaultYourSection();
    }
    return content;
  } catch (e) {
    debugPrint('Warning: Could not load your_section.md: $e');
    return _getDefaultYourSection();
  }
}

static String _getDefaultYourSection() {
  return '''# Your Section Title
  
Default content here...
''';
}
```

### Step 4: Add to HelpScreen

Edit `lib/screens/help_screen.dart`:

```dart
final Map<String, String> _sections = {
  'quick_tips': 'Quick Tips',
  'getting_started': 'Getting Started',
  'features': 'Features',
  'faq': 'FAQ',
  'user_manual': 'User Manual',
  'your_section': 'Your Section', // Add here
};

// Add to switch statement
case 'your_section':
  content = await HelpService.loadYourSection();
  break;
```

## Best Practices

### 1. Tooltip Guidelines
- Keep tooltips concise (1-2 sentences)
- Explain what the feature does and how to use it
- Use clear, user-friendly language
- Include platform-specific information when relevant

### 2. Documentation Guidelines
- Use Markdown formatting
- Include examples when helpful
- Structure content with headers
- Add platform-specific sections when needed
- Keep language clear and accessible

### 3. Help Icon Placement
- Place help icons next to settings or features that need explanation
- Use consistent icon style (Icons.help_outline)
- Ensure tooltips are accessible (hover on desktop, long-press on mobile)

### 4. Documentation Updates
- Update documentation when features change
- Keep FAQ updated with common questions
- Add new tooltips for new features
- Test help system after changes

## Testing

### Manual Testing Checklist

- [ ] Help screen loads all sections
- [ ] Search functionality works
- [ ] Tooltips appear on hover/long-press
- [ ] Help icons navigate to help screen
- [ ] Welcome dialog appears on first launch
- [ ] Quick tips banner appears for new users
- [ ] Documentation files load correctly
- [ ] Fallback content works if assets fail
- [ ] Responsive design works on mobile and desktop

### Testing Help Service

```dart
// Test tooltip loading
final tooltip = HelpService.getTooltip('import_book');
assert(tooltip.isNotEmpty);

// Test documentation loading
final content = await HelpService.loadGettingStarted();
assert(content.isNotEmpty);

// Test quick tips
final tips = HelpService.getQuickTips();
assert(tips.isNotEmpty);
```

## Troubleshooting

### Documentation Not Loading

1. Check `pubspec.yaml` includes the file in assets
2. Verify file exists in `docs/` directory
3. Check file name matches exactly (case-sensitive)
4. Run `flutter clean` and rebuild
5. Check console for error messages

### Tooltips Not Showing

1. Verify tooltip key exists in `HelpService.getTooltip()`
2. Check widget has proper tooltip implementation
3. Test on both mobile (long-press) and desktop (hover)
4. Verify Material Design is enabled

### Help Screen Not Accessible

1. Check route is configured in `app_router.dart`
2. Verify navigation code uses `context.push('/help')`
3. Check help icon is visible in app bar
4. Test navigation from different screens

## Future Enhancements

Potential improvements:

1. **Deep Linking:** Navigate to specific documentation sections
   ```dart
   context.push('/help?section=faq&topic=translation');
   ```

2. **Video Tutorials:** Embed video tutorials in help screen

3. **Interactive Guides:** Step-by-step interactive tutorials

4. **Help Analytics:** Track which help sections are most viewed

5. **User Feedback:** Allow users to rate help content

6. **Multi-language Support:** Translate documentation and tooltips

7. **Help Search Improvements:** Better search with highlighting

8. **Offline Documentation:** Ensure docs work fully offline

## Resources

- **Help Service:** `lib/services/help_service.dart`
- **Help Screen:** `lib/screens/help_screen.dart`
- **Help Widgets:** `lib/widgets/contextual_help.dart`, `lib/widgets/help_icon.dart`
- **Documentation:** `docs/` directory
- **Assets:** `pubspec.yaml` flutter.assets section

## Support

For questions or issues with the help system:
1. Check this guide
2. Review existing help system code
3. Check documentation files for examples
4. Test with existing implementations

---

**Last Updated:** Version 3.1.0
