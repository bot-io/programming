# Settings and Customization E2E Tests

This directory contains comprehensive E2E tests for the settings and customization features of the Dual Reader app.

## Test Files

### Theme Settings (`theme_test.dart`)
Tests for theme customization functionality:
- Switching to dark, light, and system themes
- Theme persistence across app restarts
- Dark mode text readability
- Immediate theme application
- Rapid theme switching
- Platform-specific theme support

**Total test cases**: 11

### Font Settings (`font_settings_test.dart`)
Tests for font customization functionality:
- Font size range (minimum 12 to maximum 32)
- Incremental font size changes
- Font size persistence
- Line height adjustment
- Immediate font application to reader
- Slider granularity
- Font size labels
- Small/large font readability

**Total test cases**: 10

### Layout Settings (`layout_settings_test.dart`)
Tests for layout customization functionality:
- Margin size changes (0-48)
- Text alignment options (left, center, right, justify)
- Panel width ratio in landscape
- Layout settings persistence
- Margin-triggered repagination
- Alignment-triggered repagination
- Layout readability at extremes

**Total test cases**: 15

### Repagination (`repagination_test.dart`)
Tests for repagination triggers when settings change:
- Font size increase/decrease triggers repagination
- Margin change triggers repagination
- Line height change triggers repagination
- Font family change triggers repagination
- Reading position restoration after repagination
- Current page retranslation after repagination
- Cache invalidation for affected book
- Batched repagination optimization
- Bookmark preservation during repagination
- Repagination progress indicator
- Cancelable repagination
- Performance tests

**Total test cases**: 14

### In-Context Settings (`in_context_settings_test.dart`)
Tests for settings access while reading:
- Opening settings while reading
- Changing language while reading
- Changing font size while reading
- Settings apply without closing book
- Return to reading after settings
- Theme change while reading
- Line height change while reading
- Margins change while reading
- Multiple setting changes while reading
- Settings preserve translation state
- Settings animation smoothness

**Total test cases**: 10

### Export/Import (`export_import_test.dart`)
Tests for settings backup and restore:
- Export settings to file
- Exported file contains all settings
- Import settings from file
- Import applies changes immediately
- Invalid JSON error handling
- Missing fields use defaults
- Unknown fields are ignored
- Restore default settings
- Restore requires confirmation
- Export includes version information
- Import validates version compatibility
- Empty/corrupt file handling
- Platform-specific export/import

**Total test cases**: 14

### Translation Settings (`translation_settings_test.dart`)
Tests for translation-related settings:
- Clear translation cache
- Cache clear confirmation
- Export translation cache
- Cache statistics display
- Target language selection
- All languages accessible
- Language preference persistence
- Downloaded languages management
- Language model download/deletion
- Cache hit rate statistics
- Platform-specific translation settings
- Common language availability
- Error handling (cache clear, download failure)

**Total test cases**: 15

### About Screen (`about_screen_test.dart`)
Tests for the about/information screen:
- App version display
- Build number display
- Credits display
- License information
- Open source licenses listing
- License details view
- GitHub repository link
- Report issue link
- Privacy policy link
- About screen accessibility from settings
- Back navigation
- Platform-specific styling
- App description
- Contact information

**Total test cases**: 13

## Test Coverage Summary

| Feature | Test Files | Test Cases |
|---------|------------|------------|
| Theme Settings | 1 | 11 |
| Font Settings | 1 | 10 |
| Layout Settings | 1 | 15 |
| Repagination | 1 | 14 |
| In-Context Settings | 1 | 10 |
| Export/Import | 1 | 14 |
| Translation Settings | 1 | 15 |
| About Screen | 1 | 13 |
| **Total** | **8** | **102** |

## Running the Tests

### Run all settings tests:
```bash
flutter test integration_test/features/settings/
```

### Run specific test file:
```bash
flutter test integration_test/features/settings/theme_test.dart
```

### Run with verbose output:
```bash
flutter test integration_test/features/settings/ --verbose
```

## Test Structure

All tests follow the Arrange-Act-Assert pattern:
1. **Arrange**: Set up the app and navigate to the appropriate screen
2. **Act**: Perform the action being tested
3. **Assert**: Verify the expected outcome

## Dependencies

- `flutter_test` - Core Flutter testing framework
- `integration_test` - Integration test support
- `flutter_riverpod` - State management
- Test helpers from `test_integration/`

## Page Object Model

Tests use the `SettingsPage` page object which provides:
- Consistent element finding
- Reusable interaction methods
- Centralized maintenance

## Skipping Tests

Many tests are marked with `skip: true` because they require:
1. Actual test books in the library
2. Full navigation implementation
3. Reader screen access from settings
4. Platform-specific features (file pickers, URL launchers)

These tests can be enabled as the features are implemented.

## Known Limitations

1. **Navigation**: Tests assume ability to navigate between screens, which may not be fully implemented
2. **Test Data**: No actual test books are provided
3. **Platform Features**: Some features (file pickers, URL launchers) require platform-specific setup
4. **Async Operations**: Long-running operations (model downloads) may need timeout adjustments

## Test Data

Tests use the `TestConfig` class for:
- Platform detection (Android, iOS, Web)
- Timeout configuration
- Test data paths

## Logging

Tests use `TestLogger` for comprehensive debug output:
- Test start/complete markers
- Settings changes
- Validation results
- Performance metrics

## Future Enhancements

1. Add visual regression tests for theme changes
2. Add performance benchmarks for repagination
3. Add accessibility tests for all settings
4. Add localization tests for settings UI
5. Add tests for custom theme creation
6. Add tests for settings synchronization across devices
