# Help System Quick Reference

## For Users

### Accessing Help

1. **From Library Screen**: Tap the help icon (ℹ️) in the top-right corner
2. **From Settings Screen**: Tap the help icon (ℹ️) in the top-right corner
3. **From Reader Screen**: Tap the help icon in the app bar or controls
4. **From Welcome Dialog**: Tap "View Help" button
5. **From Quick Tips Banner**: Tap "More Help" button

### Help Sections

- **Quick Tips**: Rotating tips for first-time users
- **Getting Started**: Step-by-step guide for new users
- **Features**: Complete feature documentation
- **FAQ**: Answers to common questions
- **User Manual**: Comprehensive guide to all features

### Using Tooltips

- **Hover** over elements with help icons (desktop/web)
- **Long-press** elements with help icons (mobile)
- **Tap** help icons to see more information

### Search Documentation

- Tap the search icon in the help screen
- Enter keywords to search across all documentation
- Results show matching content with context

## For Developers

### Adding Help to a Feature

1. **Add Tooltip**:
```dart
import '../services/help_service.dart';

Tooltip(
  message: HelpService.getTooltip('feature_key'),
  child: YourWidget(),
)
```

2. **Add Help Icon**:
```dart
import '../widgets/help_icon.dart';

HelpIcon(
  featureKey: 'feature_key',
  showDialog: false, // Set to true to show dialog instead of snackbar
)
```

3. **Add Tooltip Key** to `lib/services/help_service.dart`:
```dart
const tooltips = {
  'feature_key': 'Help text for this feature',
  // ...
};
```

### Help Service Methods

- `HelpService.getTooltip(String key)` - Get tooltip text
- `HelpService.loadGettingStarted()` - Load getting started guide
- `HelpService.loadFeatures()` - Load features documentation
- `HelpService.loadFAQ()` - Load FAQ
- `HelpService.loadUserManual()` - Load user manual
- `HelpService.getQuickTips()` - Get list of quick tips
- `HelpService.searchDocumentation(String query)` - Search documentation

### Help Widgets

- `HelpIcon` - Reusable help icon widget
- `HelpDialogIcon` - Help icon that shows dialog
- `ContextualHelp` - Wrapper for contextual help
- `HelpBanner` - Informational banner
- `HelpButton` - Button that opens help screen

### Navigation to Help

```dart
import 'package:go_router/go_router.dart';

context.push('/help');
```

### Documentation Files

- `docs/getting_started.md` - Getting started guide
- `docs/features.md` - Feature documentation
- `docs/faq.md` - FAQ section
- `docs/user_manual.md` - User manual

### Adding New Documentation

1. Create/update markdown file in `docs/` directory
2. Add to `pubspec.yaml` assets:
```yaml
assets:
  - docs/your_file.md
```
3. Add loading method to `HelpService`
4. Add section to `HelpScreen` if needed

## Best Practices

1. **Always provide tooltips** for settings and features
2. **Use consistent help icons** throughout the app
3. **Link to help** from error messages and dialogs
4. **Keep documentation updated** when features change
5. **Test help system** on all platforms
6. **Use clear, user-friendly language** in documentation

## Troubleshooting

### Documentation Not Loading

- Check `pubspec.yaml` has correct asset paths
- Verify markdown files exist in `docs/` directory
- Check for syntax errors in markdown files
- Fallback content will be shown if assets fail

### Tooltips Not Showing

- Verify tooltip key exists in `HelpService.getTooltip()`
- Check widget is wrapped with `Tooltip` widget
- Test on different platforms (hover vs long-press)

### Help Screen Not Accessible

- Verify route `/help` exists in `AppRouter`
- Check navigation is using `context.push('/help')`
- Ensure `HelpScreen` is properly imported

---

*For more information, see the main documentation files or the help system implementation.*
