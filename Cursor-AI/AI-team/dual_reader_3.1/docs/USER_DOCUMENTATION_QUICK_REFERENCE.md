# User Documentation Quick Reference

## How to Access Help in Dual Reader 3.1

### Quick Access Methods

1. **Help Icon** (ℹ️)
   - Located in the AppBar of all screens
   - Tap to open the Help & Documentation screen
   - Available on: Library, Settings, and Reader screens

2. **Help Screen Route**
   - Navigate to `/help` from anywhere in the app
   - Access via: `context.push('/help')`

3. **Tooltips**
   - Hover over or tap help icons (ℹ️) next to features
   - Quick tooltips appear with feature explanations
   - Available throughout the app

4. **Welcome Dialog**
   - Appears automatically for first-time users
   - Includes "View Help" button
   - Can be accessed again via Settings → Help

5. **Quick Tips Banner**
   - Shown to first-time users in Library screen
   - Rotating tips with navigation to full help
   - Dismissible

## Documentation Sections

### 1. Quick Tips
- 15 helpful tips for getting started
- Rotating tips in banner
- Quick reference for common tasks

### 2. Getting Started
- Step-by-step guide for new users
- Platform-specific instructions
- Import and setup guide
- Basic reading tips

### 3. Features
- Complete feature documentation
- Core features explanation
- Customization options
- Advanced features guide

### 4. FAQ
- Frequently asked questions
- Troubleshooting guide
- Common issues and solutions
- Technical questions answered

### 5. User Manual
- Comprehensive guide
- Complete reference documentation
- Detailed feature explanations
- Tips & tricks

## Help Widgets Available

### For Developers

1. **HelpIcon**
   ```dart
   HelpIcon(
     featureKey: 'import_book',
     showDialog: false,
   )
   ```

2. **HelpButton**
   ```dart
   HelpButton(
     customTooltip: 'Custom help text',
   )
   ```

3. **ContextualHelp**
   ```dart
   ContextualHelp(
     featureKey: 'translation_language',
     child: YourWidget(),
   )
   ```

4. **HelpOverlay**
   ```dart
   HelpOverlay(
     featureKey: 'bookmark',
     showOnce: true,
     child: YourWidget(),
   )
   ```

5. **HelpBanner**
   ```dart
   HelpBanner(
     message: 'Helpful message',
     onLearnMore: () => context.push('/help'),
   )
   ```

## Adding New Help Content

### Adding a Tooltip

Edit `lib/services/help_service.dart`:

```dart
static String getTooltip(String featureKey) {
  const tooltips = {
    // ... existing tooltips
    'new_feature': 'Your tooltip text here',
  };
  return tooltips[featureKey] ?? 'Help information not available.';
}
```

### Adding Documentation

1. Create or edit markdown file in `docs/` directory
2. Ensure file is listed in `pubspec.yaml` assets
3. Add loading method in `HelpService`
4. Add section to `HelpScreen` if needed

### Adding Quick Tips

Edit `lib/services/help_service.dart`:

```dart
static List<String> getQuickTips() {
  return [
    // ... existing tips
    'Your new tip here',
  ];
}
```

## Help Feature Keys

Common feature keys used throughout the app:

- `import_book` - Book import feature
- `library_search` - Library search
- `translation_language` - Translation language selection
- `theme` - Theme selection
- `font_family` - Font family selection
- `font_size` - Font size adjustment
- `bookmark` - Bookmark feature
- `chapters` - Chapter navigation
- `settings` - Settings screen
- `help` - Help & Documentation

See `HelpService.getAllTooltipKeys()` for complete list.

## Best Practices

1. **Always provide tooltips** for new features
2. **Use consistent feature keys** across the app
3. **Keep tooltips concise** but informative
4. **Link to full documentation** when appropriate
5. **Test help content** on all platforms
6. **Update documentation** when features change

## Troubleshooting

### Help Screen Not Loading
- Check `pubspec.yaml` assets configuration
- Verify markdown files exist in `docs/` directory
- Check console for loading errors

### Tooltips Not Showing
- Verify feature key exists in `HelpService.getTooltip()`
- Check widget is properly wrapped
- Ensure tooltip text is not empty

### Documentation Not Updating
- Run `flutter clean` and rebuild
- Verify assets are properly included
- Check file paths are correct

---

**For Users:** Use the Help icon (ℹ️) in any screen to access comprehensive documentation.

**For Developers:** See `HELP_SYSTEM_DEVELOPER_GUIDE.md` for detailed implementation guide.
