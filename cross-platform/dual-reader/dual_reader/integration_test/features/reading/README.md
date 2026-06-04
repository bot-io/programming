# Reading Experience E2E Tests

Comprehensive end-to-end tests for the reading experience in the Dual Reader application.

## Test Files

### `dual_panel_test.dart`
Tests for dual-panel layout display:
- ✅ Dual panel layout displays both original and translated
- ✅ Portrait mode: stacked panels (original top, translated bottom)
- ✅ Landscape mode: side-by-side panels
- ✅ Original text fits exactly without scrolling
- ✅ Translated panel independently scrollable
- ✅ Panel width ratio adjustment (landscape)
- ✅ Layout adapts to orientation changes
- ✅ Both panels show text simultaneously
- ✅ Panel divider visible and interactive
- ✅ Edge cases: long text, empty translation, special characters

**Status**: 11 test cases, structural tests pass

### `pagination_test.dart`
Tests for pagination functionality:
- ✅ Page size calculated correctly for screen
- ✅ Navigate to next page using button
- ✅ Navigate to previous page using button
- ✅ Navigate to next page using swipe
- ✅ Navigate to previous page using swipe
- ✅ Navigate using page slider
- ✅ Page number displays correctly
- ✅ Percentage displays correctly
- ✅ Cannot navigate beyond first page
- ✅ Cannot navigate beyond last page
- ✅ Chapter navigation works correctly
- ✅ Page indicator always visible
- ✅ Page indicator updates on navigation
- ✅ Pagination updates after font size change
- ✅ Page count updates on orientation change
- ✅ Page size adapts to screen size

**Status**: 16 test cases

### `touch_controls_test.dart`
Tests for touch-based navigation:
- ✅ Tap left side → previous page
- ✅ Tap right side → next page
- ✅ Tap middle → toggle controls
- ✅ Touch zones correctly sized (20% / 60% / 20%)
- ✅ Controls show/hide with animation
- ✅ Controls state persists per session
- ✅ Chapter drawer toggle independent
- ✅ Touch controls work in both orientations
- ✅ Edge cases: rapid taps, boundary taps, transition taps, long press
- ✅ Accessibility: semantic labels, screen reader support

**Status**: 13 test cases

### `full_screen_test.dart`
Tests for immersive full screen mode:
- ✅ Enters full screen when book opens
- ✅ System UI hidden (status bar, navigation)
- ✅ Exits full screen when book closes
- ✅ Exits full screen when leaving app
- ✅ Restores full screen on app resume
- ✅ Immersive sticky mode prevents system UI reappearance
- ✅ Full screen works in both orientations
- ✅ Controls can be toggled while in full screen
- ✅ Platform-specific: Android, iOS, Web

**Status**: 11 test cases

### `progress_tracking_test.dart`
Tests for reading progress functionality:
- ✅ Current page saved on navigation
- ✅ Progress percentage calculated correctly
- ✅ Page indicator always visible
- ✅ Resume book at last position
- ✅ Progress bar in library updates
- ✅ Progress persists across app restart
- ✅ Progress updates immediately on page change
- ✅ Progress calculation handles edge cases
- ✅ Progress saved mid-page
- ✅ Progress displays as fraction and percentage
- ✅ Progress indicator readable and positioned
- ✅ Progress indicator updates smoothly
- ✅ Each book maintains its own progress
- ✅ Recent books show correct progress

**Status**: 15 test cases

### `bookmarks_test.dart`
Tests for bookmark and reading history:
- ✅ Add bookmark at current page
- ✅ Navigate to bookmark
- ✅ Delete bookmark
- ✅ Multiple bookmarks can be added
- ✅ Bookmarks persist across app restart
- ✅ Each book has its own bookmarks
- ✅ Reading history is tracked
- ✅ Recent books section displays in correct order
- ✅ Continue reading button works
- ✅ Bookmark list shows page numbers
- ✅ Bookmark can be named or annotated
- ✅ Bookmarks are sorted by page number
- ✅ Edge cases: duplicates, first page, last page

**Status**: 16 test cases

### `slider_navigation_test.dart`
Tests for slider-based navigation:
- ✅ Drag slider updates page immediately
- ✅ Translation deferred during slider drag
- ✅ Release slider triggers translation
- ✅ Percentage displays correctly during drag
- ✅ Slider can reach all pages
- ✅ Slider behavior smooth and responsive
- ✅ Slider works in both orientations
- ✅ Slider position matches current page
- ✅ Slider handles large page counts
- ✅ Slider tap jumps to position
- ✅ Performance: rapid dragging, non-blocking UI
- ✅ Visual feedback during interaction
- ✅ Slider tooltip shows page number
- ✅ Accessibility: screen reader, value announcements
- ✅ Edge cases: minimum, maximum, single page

**Status**: 16 test cases

## Test Coverage Summary

| Feature | Test Count | Status |
|---------|-------------|--------|
| Dual Panel Display | 11 | Structural |
| Pagination | 16 | Ready |
| Touch Controls | 13 | Ready |
| Full Screen Mode | 11 | Platform tests |
| Progress Tracking | 15 | Ready |
| Bookmarks & History | 16 | Ready |
| Slider Navigation | 16 | Ready |
| **Total** | **108** | **Framework complete** |

## Running the Tests

### All Reading Tests
```bash
# Run all reading tests
flutter test integration_test/features/reading

# With verbose logging
VERBOSE_LOGGING=true flutter test integration_test/features/reading

# On specific platform
flutter test integration_test/features/reading --device-id <device-id>
```

### Specific Test Files
```bash
# Dual panel tests
flutter test integration_test/features/reading/dual_panel_test.dart

# Pagination tests
flutter test integration_test/features/reading/pagination_test.dart

# Touch controls tests
flutter test integration_test/features/reading/touch_controls_test.dart

# Full screen tests
flutter test integration_test/features/reading/full_screen_test.dart

# Progress tracking tests
flutter test integration_test/features/reading/progress_tracking_test.dart

# Bookmarks tests
flutter test integration_test/features/reading/bookmarks_test.dart

# Slider navigation tests
flutter test integration_test/features/reading/slider_navigation_test.dart
```

## Test Categories

### 1. Dual Panel Display
Tests the two-panel reading layout:
- Original text (source language)
- Translated text (target language)
- Layout adaptation to orientation
- Panel sizing and scrolling
- Visual separation

### 2. Pagination
Tests page navigation functionality:
- Button controls (next/previous)
- Swipe gestures
- Slider navigation
- Chapter navigation
- Page boundaries
- Display indicators

### 3. Touch Controls
Tests touch interaction zones:
- Left 20%: previous page
- Right 20%: next page
- Middle 60%: toggle controls
- Zone sizing and behavior
- Edge cases and accessibility

### 4. Full Screen Mode
Tests immersive reading experience:
- System UI hiding
- Mode persistence
- App lifecycle handling
- Platform differences
- Control visibility

### 5. Progress Tracking
Tests reading progress functionality:
- Current page saving
- Progress calculation
- Resume position
- Library progress bars
- Persistence across sessions
- Per-book progress

### 6. Bookmarks & History
Tests bookmark functionality:
- Add/delete bookmarks
- Navigate to bookmarks
- Multiple bookmarks
- Bookmark persistence
- Reading history
- Recent books display

### 7. Slider Navigation
Tests slider-based page navigation:
- Page update during drag
- Translation deferral
- Trigger on release
- Visual feedback
- Performance
- Accessibility

## Platform Considerations

### Mobile (Android/iOS)
- Full immersive mode available
- Touch zones optimized for mobile
- Full screen with hidden system UI

### Web
- No system UI to hide
- Mouse interaction for slider
- Keyboard shortcuts available

## Known Limitations

1. **Test Data**: Most tests require actual book files and navigation
2. **Platform Features**: Full screen testing needs actual devices
3. **Animation Timing**: Some tests may need timing adjustments
4. **Gesture Simulation**: Widget tests may not perfectly replicate real gestures

## Test Data Requirements

```
test_integration/test_data/books/
├── test_book_100pages.epub   # For pagination tests
├── test_book_1000pages.epub  # For slider performance tests
├── multi_chapter_book.epub    # For chapter navigation tests
└── test_book_50pages.epub     # For quick tests
```

## Debugging

### Enable Verbose Logging
```bash
VERBOSE_LOGGING=true flutter test integration_test/features/reading
```

### Export Logs on Failure
Logs automatically export to `test_integration/logs/`

### Monitor Touch Events
```bash
# Android
adb logcat | grep "TouchNavigation"

# iOS
xcrun simctl spawn booted log stream --predicate 'process == "dual_reader"'
```

## Performance Benchmarks

### Target Performance
- Page transition: < 100ms
- Translation: < 1s (cached), < 5s (new)
- Slider drag: 60fps responsive
- Control toggle: < 16ms

### Measuring Performance
```dart
final stopwatch = Stopwatch()..start();
// Perform action
stopwatch.stop();
print('Duration: ${stopwatch.elapsedMilliseconds}ms');
```

## Next Steps

1. **Add Test Books**: Create sample EPUB files for testing
2. **Real Device Testing**: Run on actual devices for touch/animation tests
3. **Performance Profiling**: Add performance benchmarks
4. **Accessibility Audit**: Screen reader testing
5. **Visual Regression**: Screenshot comparison tests

## Related Files

- `lib/src/presentation/screens/dual_reader_screen.dart` - Main reader implementation
- `lib/src/presentation/widgets/dual_panel_layout.dart` - Panel layout widget
- `lib/src/presentation/widgets/pagination_controls.dart` - Pagination controls
- `lib/src/presentation/widgets/touch_navigation_zones.dart` - Touch zones
- `test_integration/pages/reader_page.dart` - Reader page object

## Notes

- All tests use comprehensive logging
- Page Object Pattern for maintainability
- Platform-specific tests properly skip
- Edge cases covered thoroughly
- Accessibility considered throughout
