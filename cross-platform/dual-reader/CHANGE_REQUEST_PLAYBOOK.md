# Change Request Playbook

**Version:** 1.1
**Last Updated:** 2025-01-08
**App:** Dual Reader - Dual-Language Ebook Reader

This playbook defines the standardized process for implementing any change, improvement, or fix to the Dual Reader app.

---

## 📋 Table of Contents

1. [Pre-Implementation Checklist](#pre-implementation-checklist)
2. [Implementation Phase](#implementation-phase)
3. [Logging Guidelines](#logging-guidelines)
4. [Testing Phase](#testing-phase)
5. [Verification Phase](#verification-phase)
6. [Documentation Phase](#documentation-phase)
7. [Post-Deployment Checklist](#post-deployment-checklist)

---

## 🎯 Pre-Implementation Checklist

**BEFORE making any changes:**

- [ ] **Understand the Request**: Clarify requirements with the user if needed
- [ ] **Review Current Code**: Examine relevant files using `Glob` and `Read` tools
- [ ] **Check Existing Tests**: Review current test coverage for the affected module
- [ ] **Identify Impact Areas**: Determine which files/modules will be affected
- [ ] **Create Branch** (if using Git): Ensure clean working state

---

## 🔨 Implementation Phase

### Step 1: Implement the Change

**Actions:**
1. Make necessary code changes to implement the requested feature/fix
2. Follow existing code patterns and conventions
3. Ensure proper error handling
4. Add appropriate comments for complex logic
5. **Check for dependencies:** Does this change require new packages?

**Best Practices:**
- Follow Clean Architecture principles (Domain → Data → Presentation)
- Use existing service patterns (e.g., TranslationService, BookRepository)
- Maintain consistency with similar features
- Don't break existing functionality
- **Add comprehensive logging** (see [Logging Guidelines](#logging-guidelines))

### Step 2: Update Requirements Documentation

**File:** `requirements.md`

**When to Update:**
- ✅ New feature added
- ✅ Existing requirement modified/changed
- ✅ Bug fix that affects user-facing behavior
- ✅ Performance improvement
- ❌ Simple refactor (no user impact)
- ❌ Test-only changes

**How to Update:**
```markdown
## [Feature Category]

### Feature: [Feature Name]
**Status:** ✅ Implemented | 🔄 In Progress | 📋 Planned
**Last Updated:** YYYY-MM-DD

**Description:** [Clear description of what the feature does]

**Requirements:**
- [ ] Requirement 1
- [ ] Requirement 2

**Implementation Notes:**
- [File](:line) - Brief note about implementation
```

---

## 📊 Logging Guidelines

### Step 3: Add Comprehensive Logging

**Why Logging Matters:**
- Enables comprehensive analysis of app functioning
- Facilitates debugging in production
- Tracks user behavior and feature usage
- Monitors performance and identifies bottlenecks
- Provides context for error reports

### Log Level Standards

Use Flutter's `debugPrint()` for development logging. In production, consider using a logging package like `logger` or `flutter_flogger`.

**Log Levels:**

| Level | When to Use | Example |
|-------|-------------|---------|
| **DEBUG** | Detailed diagnostic information | `debugPrint('[BookRepository] Adding book: ${book.id}')` |
| **INFO** | Normal operation, significant events | `debugPrint('[TranslationService] Translation complete: ${result.length} chars')` |
| **WARNING** | Unexpected but recoverable situations | `debugPrint('[CacheService] Cache miss for key: $key')` |
| **ERROR** | Error conditions that prevent functionality | `debugPrint('[MLKit] Translation failed: $error')` |

### What to Log

**✅ Always Log:**
1. **Service Entry/Exit**: Method calls with parameters
   ```dart
   debugPrint('[TranslationService] translate() called - text: "${text.substring(0, 20)}...", target: $targetLanguage');
   ```

2. **State Changes**: Important state transitions
   ```dart
   debugPrint('[BookNotifier] Loading books... found ${books.length} books');
   debugPrint('[BookNotifier] Book added: ${book.id} - ${book.title}');
   ```

3. **Cache Operations**: Cache hits, misses, updates
   ```dart
   debugPrint('[TranslationCache] Cache HIT for book:$bookId page:$page lang:$language');
   debugPrint('[TranslationCache] Cache MISS - storing translation (${result.length} chars)');
   ```

4. **Performance Metrics**: Operation timings
   ```dart
   final stopwatch = Stopwatch()..start();
   // ... operation ...
   stopwatch.stop();
   debugPrint('[TranslationService] Translation completed in ${stopwatch.elapsed.inMilliseconds}ms');
   ```

5. **Errors**: All errors with context
   ```dart
   } catch (e, stackTrace) {
   debugPrint('[ERROR] BookRepository.addBook() failed: $e');
   debugPrint('[ERROR] Stack trace: $stackTrace');
   debugPrint('[ERROR] Book details: id=${book.id}, title=${book.title}');
   rethrow;
   }
   ```

6. **User Actions**: Key user interactions
   ```dart
   debugPrint('[LibraryScreen] User tapped book: ${book.id}');
   debugPrint('[SettingsScreen] User changed target language: $newLanguage');
   ```

7. **Data Operations**: CRUD operations
   ```dart
   debugPrint('[BookRepository] getAllBooks() - returned ${books.length} books');
   debugPrint('[ProgressTracker] Updated progress for book:$bookId to page:$page (${progressPercent.toStringAsFixed(1)}%)');
   ```

8. **Platform-Specific Operations**: Mobile/desktop differences
   ```dart
   if (Platform.isAndroid) {
   debugPrint('[MLKit] Initializing on-device translator for $targetLanguage');
   } else {
   debugPrint('[TranslationService] Using web translation service');
   }
   ```

**❌ Don't Log:**
- Sensitive user data (passwords, tokens, personal info)
- Extremely large data payloads (full book contents)
- Trivial getter/setter calls
- Repetitive loop iterations (log summary instead)

### Log Format Standards

**Consistent Format:**
```dart
debugPrint('[ComponentName] Action description - details');
```

**Examples:**
```dart
// Good - Consistent, informative
debugPrint('[TranslationService] Starting translation - text length: ${text.length}, target: $targetLanguage');
debugPrint('[TranslationService] Translation complete - result length: ${result.length}, duration: ${duration}ms');

// Good - Error with context
debugPrint('[ERROR] BookRepository.deleteBook() failed - bookId: $bookId, error: $e');

// Good - Performance tracking
debugPrint('[CacheService] Cache cleared - removed $count entries');

// Bad - Inconsistent
print('translating...');  // No component, no context
debugPrint('done');  // Too vague
```

### Performance Logging Guidelines

**Always Log Performance For:**
- Translation operations (especially ML Kit)
- Cache operations (hits/misses)
- Database operations (read/write)
- Large text processing
- Network requests

**Template:**
```dart
final stopwatch = Stopwatch()..start();

try {
  // Perform operation
  final result = await expensiveOperation();

  stopwatch.stop();
  debugPrint('[ComponentName] Operation completed in ${stopwatch.elapsed.inMilliseconds}ms - input: ${input.length}, output: ${result.length}');

  return result;
} catch (e) {
  stopwatch.stop();
  debugPrint('[ERROR] ComponentName - Operation failed after ${stopwatch.elapsed.inMilliseconds}ms: $e');
  rethrow;
}
```

### Error Logging Guidelines

**Comprehensive Error Logging:**
```dart
try {
  await riskyOperation();
} catch (e, stackTrace) {
  // Log the error
  debugPrint('[ERROR] ServiceName - Operation failed: $e');
  debugPrint('[ERROR] Context - userId: $userId, bookId: $bookId, action: $action');

  // Log stack trace for debugging
  debugPrint('[ERROR] Stack trace:\n$stackTrace');

  // Log state at time of error
  debugPrint('[ERROR] Current state - isLoading: $isLoading, data: ${data.length} items');

  // Consider user-friendly error message
  debugPrint('[ERROR] User message: "Unable to complete operation. Please try again."');

  rethrow;
}
```

### Debugging Session Logs

**When Investigating Issues:**
1. Add temporary detailed logs around the problem area
2. Log all method parameters and return values
3. Log state before/after operations
4. Use unique markers to find logs easily:
   ```dart
   debugPrint('=== DEBUG START: Issue with translation ===');
   debugPrint('[DEBUG] Current state: $state');
   debugPrint('[DEBUG] Input: $input');
   // ... operation ...
   debugPrint('[DEBUG] Output: $output');
   debugPrint('=== DEBUG END ===');
   ```

### Production Logging

**For Production Builds:**
- Consider using a logging package with remote logging (e.g., Sentry, Firebase Crashlytics)
- Reduce DEBUG level logs
- Keep ERROR and WARNING logs
- Don't log sensitive data
- Use log aggregation for analysis

### Logging Checklist

**When implementing a feature, ensure you log:**
- [ ] All public method calls (entry point)
- [ ] Return values or completion (exit point)
- [ ] Error conditions with full context
- [ ] Performance metrics for operations >100ms
- [ ] State changes
- [ ] Cache operations
- [ ] User interactions (significant ones)
- [ ] Platform-specific behavior
- [ ] Data validation failures
- [ ] Network operations

### Log Analysis Guidelines

**When Analyzing Logs:**
1. **Follow the Flow**: Trace user action from UI to service to data
2. **Check Timestamps**: Identify slow operations
3. **Look for Errors**: Find first error in sequence
4. **Verify State**: Check if state changes are logged correctly
5. **Correlate Events**: Match related log entries by ID/timestamp

**Example Log Sequence for Translation:**
```log
[DualReaderScreen] User tapped translate button - page: 5, language: es
[TranslationService] translate() called - text: "The quick brown...", target: es, source: en
[TranslationCache] Checking cache for book:test-book page:5 lang:es
[TranslationCache] Cache MISS - translation not found
[ClientSideTranslation] Starting ML Kit translation - target: es
[ClientSideTranslation] ML Kit translator created (cached)
[ClientSideTranslation] Translation completed - result: "El rápido brown...", duration: 245ms
[TranslationCache] Caching translation - book:test-book page:5 lang:es (18 chars)
[TranslationService] Translation complete - result length: 18, total duration: 247ms
[DualReaderScreen] Translation applied - updating UI
```

---

## 🧪 Testing Phase

### Step 3a: Write Unit Tests (if applicable)

**When to Write Unit Tests:**
- New domain entity or value object
- New use case
- New service implementation
- Utility/helper functions
- Business logic changes

**Test Locations:**
- Domain entities: `test/src/domain/entities/`
- Use cases: `test/src/domain/usecases/`
- Services: `test/src/data/services/`
- Repositories: `test/src/data/repositories/`

**Unit Test Template:**
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dual_reader/src/...';

void main() {
  group('[FeatureName] Tests', () {
    setUp(() {
      // Setup
    });

    test('should [expected behavior]', () {
      // Arrange
      // Act
      // Assert
    });
  });
}
```

### Step 3b: Write Widget Tests (if applicable)

**When to Write Widget Tests:**
- New screen or widget
- UI changes to existing screens
- User interaction changes
- State management changes

**Test Locations:**
- Screens: `test/src/presentation/screens/`
- Widgets: `test/src/presentation/widgets/`

**Widget Test Template:**
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dual_reader/src/presentation/screens/[screen_name].dart';

void main() {
  group('[ScreenName] Widget Tests', () {
    testWidgets('should show [element]', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // Override providers if needed
          ],
          child: const MaterialApp(
            home: [ScreenName](),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Expected Text'), findsOneWidget);
    });
  });
}
```

### Step 3c: Write Integration Tests (if applicable)

**When to Write Integration Tests:**
- End-to-end user flows
- Multi-component interactions
- Database operations
- Translation flows
- Progress tracking

**Test Locations:**
- `test/integration/` for unit integration tests
- `integration_test/` for device integration tests

**Integration Test Template:**
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_test/hive_test.dart';

void main() {
  group('[FeatureName] Integration Tests', () {
    setUp(() async {
      await setUpHive();
      // Setup
    });

    tearDown(() async {
      // Cleanup
      await tearDownHive();
    });

    test('should [complete flow]', () async {
      // Test complete flow
    });
  });
}
```

### Step 3d: Update Existing Tests (if applicable)

**When to Update:**
- Changes break existing tests
- Feature removal/renaming
- Test data structure changes

**Actions:**
- Run existing tests to identify failures
- Update test expectations to match new behavior
- Ensure test coverage doesn't decrease

---

## ✅ Verification Phase

### Step 4a: Run All Tests

**Command:**
```bash
cd dual_reader
flutter test --reporter compact
```

**Expected Outcome:**
- All existing tests still pass
- New tests pass
- No new test failures introduced

**If Tests Fail:**
1. Analyze failure messages
2. Fix the issue (app code or test code)
3. Re-run tests until all pass
4. Document any intentional test changes

### Step 4b: Fix Any Issues

**Common Issues & Solutions:**

| Issue | Solution |
|-------|----------|
| Compilation error | Check imports, syntax, type mismatches |
| Test assertion fails | Update expectation or fix implementation |
| Hive initialization error | Use `hive_test` package, proper setup/teardown |
| ProviderScope missing | Wrap test widget in ProviderScope |
| Platform-specific code | Add platform checks or use conditional imports |
| GetIt registration conflict | Use proper reset in setUp, check registration logic |

**Debug Commands:**
```bash
# Run specific test file
flutter test test/path/to/test_file.dart

# Run with verbose output
flutter test --verbose

# Run specific test
flutter test --name "test name"
```

---

## 🚀 Deployment Phase

### Step 5a: Build the App

**Command:**
```bash
cd dual_reader
flutter clean
flutter pub get
flutter build apk --debug
```

**Expected Outcome:**
- Clean build completes successfully
- APK generated: `build/app/outputs/flutter-apk/app-debug.apk`
- No compilation errors or critical warnings

### Step 5b: Install on Emulator

**Check Devices:**
```bash
flutter devices
```

**Install & Run:**
```bash
# Install APK (preserves app data and imported books)
flutter install -d emulator-5554

# OR directly run
flutter run -d emulator-5554 --debug
```

**⚠️ IMPORTANT: Use `flutter install` instead of full reinstall**
- `flutter install` updates the app while preserving all app data, including imported books
- Full reinstall (`flutter install` after uninstalling) will delete all imported books
- Only do a full reinstall if specifically testing the book import flow

**Expected Outcome:**
- App installs successfully
- App launches without crashes
- Home screen displays correctly
- Previously imported books are still available

### Step 5c: Manual Testing Checklist

**On Emulator, Verify:**

- [ ] **App Launches**: No crash on startup
- [ ] **UI Renders**: Screens display correctly
- [ ] **New Feature**: Test the new/changed functionality
- [ ] **Navigation**: Navigate between screens
- [ ] **Existing Features**: Test related existing features still work
- [ ] **Settings**: Changes in settings persist
- [ ] **Translation**: If translation-related, test translation works
- [ ] **Progress**: If progress-related, test progress tracking works
- [ ] **Book Import**: Test importing a book (if book-related)
- [ ] **Error Handling**: Try to trigger errors, verify graceful handling

---

## 📚 Documentation Phase

### Step 6: Update Documentation

**Files to Update:**

1. **requirements.md** (if applicable - see Step 2)
2. **README.md** (if user-facing feature)
3. **Code Comments** (for complex logic)
4. **CHANGELOG.md** (optional - for release notes)

**When to Update README:**
- New user-facing feature
- New installation requirements
- New configuration options
- Breaking changes

---

## 🎯 Post-Deployment Checklist

**After deployment, verify:**

- [ ] All tests pass: `flutter test --reporter compact`
- [ ] App runs on emulator without crashes
- [ ] New feature works as expected
- [ ] No regression in existing features
- [ ] Settings persist correctly
- [ ] Translation works (if applicable)
- [ ] Progress tracking works (if applicable)
- [ ] Documentation updated

---

## 🔄 Quick Reference Commands

### Testing Commands

```bash
# Run all tests
flutter test

# Run with compact reporter
flutter test --reporter compact

# Run specific test file
flutter test test/path/to/test.dart

# Run integration tests only
flutter test test/integration/

# Run widget tests only
flutter test test/src/presentation/

# Run on device
flutter test test/integration/mlkit_translation_test.dart --device-id emulator-5554

# Run device integration tests
flutter test integration_test/ --device-id emulator-5554
```

### Build Commands

```bash
# Clean build
flutter clean

# Get dependencies
flutter pub get

# Build debug APK
flutter build apk --debug

# Build release APK
flutter build apk --release

# Install on emulator
flutter install -d emulator-5554

# Run on emulator
flutter run -d emulator-5554 --debug
```

### Code Generation

```bash
# Run build runner (if needed)
flutter pub run build_runner build --delete-conflicting-outputs
```

---

## 📝 Change Request Template

**When requesting changes, provide:**

1. **Description**: Clear description of what needs to change
2. **Reason**: Why this change is needed
3. **Acceptance Criteria**: How to verify the change works
4. **Priority**: Critical / High / Medium / Low
5. **Related Files**: (Optional) Any files you know need changes

---

## ⚠️ Common Pitfalls to Avoid

1. **Skipping Tests**: Always write/update tests for changes
2. **Breaking Existing Tests**: Ensure all tests pass, not just new ones
3. **Forgetting Platform Checks**: ML Kit only works on Android/iOS
4. **Hive Initialization**: Always use `hive_test` for test setup
5. **ProviderScope Missing**: Widget tests need ProviderScope for Riverpod
6. **Not Cleaning Up**: Integration tests need proper tearDown
7. **Hard-coded Values**: Use constants or configuration
8. **Ignoring Error Handling**: Always handle potential errors gracefully
9. **Insufficient Logging**: Always add comprehensive logging for debugging and analysis
10. **Logging Sensitive Data**: Never log passwords, tokens, or personal information

---

## 🎓 Testing Guidelines

### What to Test:

✅ **DO Test:**
- User-facing features
- Business logic
- State management changes
- UI interactions
- Data persistence
- Translation functionality
- Progress tracking
- Error conditions

❌ **DON'T Test:**
- Third-party library internals
- Flutter framework itself
- Trivial getters/setters
- Constant values

### Test Coverage Goals:

- **Domain Layer**: 90%+ coverage
- **Data Layer**: 80%+ coverage
- **Presentation Layer**: 70%+ coverage (widget tests)
- **Critical User Flows**: 100% coverage (integration tests)

---

## 📞 Escalation

**If stuck on:**
1. **Compilation Errors**: Check imports, dependencies, syntax
2. **Test Failures**: Verify test setup, mock data, expectations
3. **Platform Issues**: Check platform-specific code, conditional imports
4. **Build Issues**: Try `flutter clean`, check dependencies
5. **Runtime Errors**: Check logs, add debug print statements

---

## ✨ Success Criteria

A change request is **COMPLETE** when:

1. ✅ Code implements the requested feature/fix
2. ✅ All tests pass (existing + new)
3. ✅ App runs on emulator without crashes
4. ✅ New feature works as expected
5. ✅ No regression in existing features
6. ✅ Documentation updated (if applicable)
7. ✅ Comprehensive logging added for debugging and analysis

---

**Remember**: This playbook ensures consistent, high-quality changes to the Dual Reader app. Following these steps minimizes bugs, ensures test coverage, and maintains code quality.
