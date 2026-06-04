# E2E Test Framework for Dual Reader

Comprehensive end-to-end testing infrastructure for the Dual Reader application across Android, iOS, and Web platforms.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Directory Structure](#directory-structure)
- [Setup](#setup)
- [Running Tests](#running-tests)
- [Writing Tests](#writing-tests)
- [CI/CD Integration](#cicd-integration)
- [Debugging](#debugging)

## Overview

This E2E test framework provides:

- **Multi-platform support**: Android, iOS, and Web
- **Page Object Pattern**: Reusable page objects for common screens
- **Comprehensive Logging**: Debug logging with export capabilities
- **Test Fixtures**: Reusable test data builders
- **CI/CD Integration**: GitHub Actions workflows
- **Device Scripts**: Automated emulator/simulator setup

## Architecture

The framework follows these principles:

1. **Page Object Pattern**: Screen interactions encapsulated in page objects
2. **Test Helpers**: Reusable utilities for common operations
3. **Configuration Centralized**: All test configuration in one place
4. **Logging**: Comprehensive debug logging throughout
5. **Fixture Management**: Consistent test data across tests

## Directory Structure

```
test_integration/
├── config/              # Test configuration
│   └── test_config.dart
├── helpers/             # Test utilities and helpers
│   ├── test_helpers.dart
│   ├── test_logger.dart
│   └── test_fixtures.dart
├── pages/               # Page objects for screens
│   ├── library_page.dart
│   ├── reader_page.dart
│   └── settings_page.dart
├── test_data/           # Test fixtures and data
│   ├── books/           # Test ebook files
│   ├── fixtures/        # Test data fixtures
│   └── README.md
├── scripts/             # Setup scripts
│   ├── android_setup.sh
│   ├── ios_setup.sh
│   └── web_setup.sh
└── README.md
```

## Setup

### Prerequisites

1. **Flutter SDK** (3.24.5+)
2. **Android Studio** (for Android testing)
3. **Xcode** (for iOS testing, macOS only)
4. **Chrome** (for web testing)

### Installation

```bash
cd dual_reader
flutter pub get
```

### Device Setup

#### Android

```bash
# Make script executable
chmod +x test_integration/scripts/android_setup.sh

# Run setup
./test_integration/scripts/android_setup.sh
```

#### iOS (macOS only)

```bash
# Make script executable
chmod +x test_integration/scripts/ios_setup.sh

# Run setup
./test_integration/scripts/ios_setup.sh
```

#### Web

```bash
# Make script executable
chmod +x test_integration/scripts/web_setup.sh

# Run setup
./test_integration/scripts/web_setup.sh
```

## Running Tests

### All Tests

```bash
# Run all integration tests
flutter test integration_test

# With verbose logging
VERBOSE_LOGGING=true flutter test integration_test
```

### Platform-Specific

```bash
# Android only
flutter test integration_test --device-id <emulator-id>

# iOS only (macOS)
flutter test integration_test --device-id <simulator-id>

# Web only
flutter test integration_test --platform chrome
```

### Specific Test File

```bash
flutter test integration_test/app_lifecycle_test.dart
```

### With Coverage

```bash
flutter test --coverage integration_test
```

## Writing Tests

### Basic Test Structure

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dual_reader/main.dart' as app;
import '../test_integration/helpers/test_helpers.dart';
import '../test_integration/pages/library_page.dart';

void main() {
  TestHelpers.initTests();

  group('My Feature Tests', () {
    testWidgets('Test description', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettled(tester);

      // Act
      final libraryPage = LibraryPage(tester);
      await libraryPage.waitForLoad();

      // Assert
      await libraryPage.verifyDisplayed();
    });
  });
}
```

### Using Page Objects

```dart
final libraryPage = LibraryPage(tester);
await libraryPage.waitForLoad();
await libraryPage.tapImport();
await libraryPage.verifyBookVisible('My Book');
```

### Logging

```dart
import '../test_integration/helpers/test_logger.dart';

void main() {
  late TestLogger logger;

  setUpAll(() {
    logger = TestLogger();
  });

  testWidgets('My test', (WidgetTester tester) async {
    logger.logTestSetup('My Test');
    logger.info('Starting test execution', category: 'test');
    // ... test code ...
    logger.logTestTeardown('My Test');
  });
}
```

### Test Fixtures

```dart
import '../test_integration/helpers/test_fixtures.dart';

final testBook = TestFixtures.createTestBook(
  title: 'My Test Book',
  author: 'Test Author',
);

final settings = TestFixtures.createCustomSettings(
  fontSize: 20.0,
  targetLanguage: 'bg',
);
```

## CI/CD Integration

### GitHub Actions

The framework includes a GitHub Actions workflow (`.github/workflows/e2e_tests.yml`) that:

- Runs unit and widget tests with coverage
- Executes E2E tests on all platforms
- Generates test reports
- Uploads test artifacts

### Workflow Triggers

- Push to `master`, `main`, or `develop` branches
- Pull requests to `master`, `main`, or `develop` branches
- Nightly schedule (2 AM UTC)
- Manual trigger with platform selection

### Test Reports

After workflow completion:

1. Download artifacts from the Actions page
2. Review test logs in `test_integration/logs/`
3. View screenshots in `test_integration/screenshots/`

## Debugging

### Enable Verbose Logging

```bash
VERBOSE_LOGGING=true flutter test integration_test
```

### Export Logs on Failure

Tests automatically export logs on failure. Logs are saved to:
- `test_integration/logs/<test-name>-<timestamp>.log`

### Screenshots

Screenshots are captured on test failures:
- `test_integration/screenshots/<test-name>-<timestamp>.png`

### Manual Screenshot

```dart
await TestHelpers.takeScreenshot(tester, 'my-screen');
```

### Debugging in VS Code

Create `.vscode/launch.json`:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Debug E2E Tests",
      "type": "dart",
      "request": "launch",
      "program": "integration_test/app_lifecycle_test.dart",
      "args": ["--dart-define=TEST_MODE=true"]
    }
  ]
}
```

## Test Categories

### Smoke Tests
Quick tests that verify critical paths work:
- App launches
- Main screens accessible
- Core features functional

### Integration Tests
Tests that verify features work together:
- Book import → Display → Read
- Settings changes → Applied → Persisted
- Translation flow

### Regression Tests
Tests for known fixed bugs:
- Previous issues that should not reoccur

### Performance Tests
Tests for performance characteristics:
- Translation speed
- Page load time
- Memory usage

## Best Practices

1. **Keep tests independent**: Each test should be able to run alone
2. **Use page objects**: Don't repeat widget finders
3. **Add logging**: Log important actions for debugging
4. **Use fixtures**: Consistent test data
5. **Wait properly**: Use `waitForAppSettled()` after actions
6. **Clean up**: Clean up test data in `tearDown`
7. **Timeouts**: Set appropriate timeouts for network operations
8. **Platform checks**: Skip tests appropriately with `shouldRunTest()`

## Troubleshooting

### Emulator won't start
```bash
# Kill existing emulators
adb devices | grep emulator | awk '{print $1}' | xargs -I {} adb -s {} emu kill

# Restart adb
adb kill-server
adb start-server
```

### Tests timeout
- Increase timeout in `TestConfig`
- Check device performance
- Verify network connectivity

### Translation fails on CI
- Use mock translation for web tests
- Pre-download models on mobile emulators
- Check CORS settings for external services

## Contributing

When adding new tests:

1. Create page objects for new screens
2. Add test fixtures for new data
3. Update this README with new patterns
4. Ensure tests run on all applicable platforms
5. Add logging for debugging

## Resources

- [Flutter Testing Documentation](https://docs.flutter.dev/testing/integration-tests)
- [Page Object Pattern](https://www.selenium.dev/documentation/test_practices/encouraged_page_object_models/)
- [Integration Test Package](https://pub.dev/packages/integration_test)
