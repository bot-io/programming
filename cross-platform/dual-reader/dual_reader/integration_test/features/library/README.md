# Library Management E2E Tests

Comprehensive end-to-end tests for library management features in the Dual Reader application.

## Test Files

### `library_import_test.dart`
Tests for book import functionality:
- ✅ Import button accessibility
- ✅ Empty library state display
- ✅ Import success messaging
- ✅ Import cancellation handling
- ✅ Invalid file error handling
- ✅ Settings navigation
- ✅ Platform-specific file picker tests
- ✅ Multiple sequential imports

**Status**: 10 test cases, structural tests pass, file picker tests require mock setup

### `library_display_test.dart`
Tests for library display and UI:
- ✅ App bar with title
- ✅ Empty state message
- ✅ Grid layout for books
- ✅ Book title and author display
- ✅ Cover images and placeholders
- ✅ Pagination progress indicators
- ✅ Completed book page counts
- ✅ Not-paginated status display
- ✅ Language model download banners
- ✅ Responsive layout

**Status**: 15 test cases, UI verification tests pass

### `library_management_test.dart`
Tests for book management operations:
- ✅ Delete book with confirmation
- ✅ Cancel deletion
- ✅ Library updates after deletion
- ✅ Open book for reading
- ✅ Back navigation
- ✅ Long press context menu
- ✅ State persistence
- ✅ Pagination state display
- ✅ Error handling

**Status**: 20 test cases, interactive tests require test data

## Test Infrastructure

### Page Objects
**`LibraryPage`** (`test_integration/pages/library_page.dart`):
- Complete interaction methods for all library UI elements
- Verification methods for all display states
- Helper methods for book operations
- Pagination state verification

### Test Data Helpers
**`BookTestData`** (`test_integration/helpers/book_test_data.dart`):
- Test book entity creation with various states
- Sample book titles and authors
- Pagination state helpers
- Test file path management

## Running the Tests

```bash
# Run all library tests
flutter test integration_test/features/library

# Run specific test file
flutter test integration_test/features/library/library_import_test.dart

# Run with verbose logging
VERBOSE_LOGGING=true flutter test integration_test/features/library

# Run on specific platform
flutter test integration_test/features/library --device-id <device-id>
```

## Test Coverage

| Feature | Coverage | Notes |
|---------|----------|-------|
| EPUB Import | Structural | File picker mock needed |
| Empty State | Complete | Fully verified |
| Book Display | Complete | Grid layout verified |
| Pagination Display | Structural | Provider overrides needed |
| Delete Book | Interactive | Test data needed |
| Navigation | Structural | Reader page verification needed |
| State Persistence | Structural | Data persistence setup needed |

## Known Limitations

1. **File Picker Mock**: Actual file import tests require file picker mocking or real test files
2. **Provider Overrides**: Some tests need provider state override capabilities
3. **Test Data**: Pagination tests need books with different pagination states
4. **Platform-Specific**: Some tests skip on certain platforms (e.g., Linux file picker)

## Next Steps

1. **Create Test Books**: Add sample EPUB files to `test_integration/test_data/books/`
2. **File Picker Mock**: Implement file picker mocking for automated testing
3. **Provider Testing**: Add provider override utilities for state testing
4. **Real Device Testing**: Run on physical devices for file picker integration

## Test Data Structure

```
test_integration/test_data/books/
├── test_book.epub          # Standard test EPUB
├── small_test.epub         # Minimal EPUB for quick tests
├── invalid.epub            # Corrupted file for error testing
└── test_book.mobi          # MOBI format test
```

## CI/CD Integration

These tests are included in the E2E test workflow (`.github/workflows/e2e_tests.yml`):
- Android emulator tests
- iOS simulator tests
- Web browser tests (Chrome)

## Debugging

Enable verbose logging:
```bash
VERBOSE_LOGGING=true flutter test integration_test/features/library/library_import_test.dart
```

Export logs on failure:
Logs are automatically exported to `test_integration/logs/`

## Notes

- All tests use the Page Object Pattern for maintainability
- Tests are organized by feature (import, display, management)
- Each test has clear arrange/act/assert structure
- Comprehensive logging for debugging
- Platform-specific tests properly skipped when not applicable
