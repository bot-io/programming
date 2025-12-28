# Dual Reader 3.1 - Test Suite

This directory contains the test suite for the Dual Reader 3.1 application.

## Test Structure

```
test/
├── helpers/
│   └── test_helpers.dart      # Test utility functions and helpers
├── models/                     # Model unit tests
│   ├── app_settings_test.dart
│   ├── bookmark_test.dart
│   ├── chapter_test.dart
│   ├── page_content_test.dart
│   └── reading_progress_test.dart
├── services/                   # Service unit tests
│   ├── ebook_parser_test.dart
│   ├── storage_service_test.dart
│   └── translation_service_test.dart
├── providers/                  # Provider unit tests
│   └── reader_provider_test.dart
└── utils/                      # Utility unit tests
    └── pagination_test.dart
```

## Running Tests

### Run all tests
```bash
flutter test
```

### Run specific test file
```bash
flutter test test/models/app_settings_test.dart
```

### Run tests with coverage
```bash
flutter test --coverage
```

### Generate coverage report
```bash
genhtml coverage/lcov.info -o coverage/html
```

## Test Categories

### Unit Tests
- **Models**: Test data models, copyWith methods, and validation
- **Services**: Test business logic, error handling, and edge cases
- **Utils**: Test utility functions like pagination calculations
- **Providers**: Test state management logic

### Integration Tests
Integration tests are planned for:
- Book import flow
- Reading flow with pagination
- Translation flow
- Settings persistence
- Progress tracking

### E2E Tests
End-to-end tests are planned for:
- Complete user workflows
- Cross-platform compatibility
- Performance benchmarks

## Test Coverage Goals

- **Unit Tests**: 80%+ coverage for core business logic
- **Integration Tests**: Cover all major user flows
- **E2E Tests**: Cover critical paths and cross-platform scenarios

## Writing New Tests

1. **Follow naming convention**: `*_test.dart`
2. **Use descriptive test names**: `test('should do something when condition')`
3. **Group related tests**: Use `group()` to organize tests
4. **Use setUp/tearDown**: For test initialization and cleanup
5. **Mock external dependencies**: Use mocks for services, network calls, etc.
6. **Test edge cases**: Empty inputs, null values, boundary conditions

## Mocking

The test suite uses:
- `mockito` for creating mocks
- `http_mock_adapter` for HTTP request mocking
- `SharedPreferences.setMockInitialValues()` for preference mocking

## Test Data

Test data helpers are available in `test/helpers/test_helpers.dart`:
- `createTestSettings()` - Creates test AppSettings
- `createTestWidget()` - Creates test widgets with MediaQuery
- `generateTestText()` - Generates test text of specified length
- `generateTestTextWithParagraphs()` - Generates paragraph-formatted text

## Notes

- Tests use `flutter_test` framework
- Hive boxes are cleaned up in `tearDown()` to avoid test interference
- Some tests require mocked dependencies (StorageService, TranslationService)
- Integration tests will require actual EPUB files or mocked EPUB data
