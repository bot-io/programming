# Mock Services and Test Fixtures

This directory contains comprehensive mock services and test fixtures for reliable testing.

## Mock Services

### MockTranslationService (`test/mocks/mock_translation_service.dart`)

Provides predictable word-replacement translation for testing.

**Features:**
- Configurable translation delay
- Simulated success/failure states
- Success rate control (0.0 to 1.0)
- Offline mode simulation
- Word-replacement translation (predictable output)
- Custom translation mapping
- Language detection simulation

**Usage:**
```dart
// Create mock with default config
final mockService = MockTranslationService();

// Create immediate response mock
final immediate = MockTranslationServiceFactory.createImmediate();

// Create delayed mock
final delayed = MockTranslationServiceFactory.createDelayed(
  Duration(milliseconds: 500),
);

// Create failing mock
final failing = MockTranslationServiceFactory.createFailing();

// Create offline mock
final offline = MockTranslationServiceFactory.createOffline();

// Use custom translations
final custom = MockTranslationServiceFactory.createWithCustomTranslations({
  'Hello': 'Hola',
  'World': 'Mundo',
});

// Translate
final result = await mockService.translate(
  text: 'Hello world',
  targetLanguage: 'es',
);
```

**Translation Output:**
- Word-replacement mode: `Hello world` → `Hello_es world_es`
- Custom mapping: Uses provided translations
- Default mode: `[es] Hello world`

**MockTranslationCache:**
```dart
final cache = MockTranslationCache();

// Get cached translation
final result = cache.get(key);

// Put translation in cache
cache.put(key, result);

// Get cache statistics
final stats = cache.stats;
print(stats); // CacheStats(size: 5, hits: 10, misses: 2, hitRate: 83.3%)
```

### MockBookRepository (`test/mocks/mock_book_repository.dart`)

Provides test books on demand with various formats.

**Features:**
- Predefined test books (small, medium, large, single-page, etc.)
- Simulated load delay
- Error condition simulation
- Chapter and content generation
- Progress tracking
- Book import simulation

**Available Test Books:**
- `smallBook` - 50 pages, 5 chapters
- `mediumBook` - 100 pages, 10 chapters
- `largeBook` - 500 pages, 50 chapters
- `singlePageBook` - 1 page, 1 chapter
- `multiChapterBook` - 200 pages, 20 chapters
- `bookWithImages` - 30 pages, with images
- `spanishBook` - Spanish language
- `chineseBook` - Chinese language (CJK)
- `rtlBook` - Arabic (RTL)
- `complexFormattingBook` - Complex HTML/CSS

**Usage:**
```dart
// Create repository with all test books
final repo = MockBookRepository(MockBookConfig.withTestBooks());

// Get all books
final books = await repo.getAllBooks();

// Get specific book
final book = await repo.getBookById('small-book');

// Import book
final imported = await repo.importBook('/path/to/book.epub');

// Get chapters
final chapters = await repo.getChapters('small-book');

// Get chapter content
final content = await repo.getChapterContent('small-book', 0);

// Delete book
await repo.deleteBook('small-book');
```

**Creating Custom Books:**
```dart
// Using MockBookFactory
final customBook = MockBookFactory.createCustom(
  id: 'my-book',
  title: 'My Custom Book',
  author: 'My Name',
  totalPages: 250,
  chapterCount: 25,
);

// Or create with specific characteristics
final largeBook = MockBookFactory.createWithPages(1000);
final manyChapters = MockBookFactory.createWithChapters(100);
```

### MockPaginationService (`test/mocks/mock_pagination_service.dart`)

Provides predictable pagination for testing.

**Features:**
- Configurable pagination delay
- Progress callback simulation
- Error condition simulation
- Word count calculation
- Repagination support

**Usage:**
```dart
// Create mock with default config
final mockService = MockPaginationService();

// Create instant pagination
final instant = MockPaginationServiceFactory.createInstant();

// Create slow pagination (for timeout testing)
final slow = MockPaginationServiceFactory.createSlow(
  Duration(seconds: 5),
);

// Create error-simulating mock
final withErrors = MockPaginationService.createWithErrors();

// Paginate a book
final result = await mockService.paginateBook(
  bookId: 'test-book',
  chapters: chapters,
  content: content,
  onProgress: (progress) {
    print('Pagination progress: ${(progress * 100).toInt()}%');
  },
);

// Get pagination call history
print(mockService.calls); // All pagination calls
print(mockService.progressUpdates); // All progress updates
```

## Test Data Builders

### BookBuilder
Creates Book entities with custom properties.

```dart
final book = BookBuilder()
    .withId('my-book')
    .withTitle('My Book')
    .withAuthor('Author Name')
    .withFormat('EPUB')
    .withTotalPages(250)
    .withCurrentPage(50)
    .withLanguage('es')
    .asLastRead()
    .build();
```

### ChapterBuilder
Creates Chapter entities.

```dart
final chapter = ChapterBuilder()
    .withId('chapter-1')
    .withBookId('my-book')
    .withTitle('Chapter 1')
    .withIndex(0)
    .build();

// Build multiple chapters
final chapters = ChapterBuilder.buildMany(10, bookId: 'my-book');
```

### BookContentBuilder
Creates BookContent entities.

```dart
final content = BookContentBuilder()
    .withBookId('my-book')
    .withChapterIndex(0)
    .withTitle('Chapter 1')
    .withParagraphs(20, wordsPerParagraph: 50)
    .build();
```

### TranslationResultBuilder
Creates TranslationResult entities.

```dart
final result = TranslationResultBuilder()
    .withOriginalText('Hello world')
    .withTranslatedText('Hola mundo')
    .withSourceLanguage('en')
    .withTargetLanguage('es')
    .withConfidence(0.95)
    .build();

// Create word-replacement result
final result = TranslationResultBuilder.createWordReplacement(
  'Hello world',
  'es',
);
```

### SettingsBuilder
Creates SettingsEntity with custom values.

```dart
final settings = SettingsBuilder()
    .withThemeMode(ThemeMode.dark)
    .withFontSize(20.0)
    .withLineHeight(1.8)
    .withMargins(24.0)
    .withTextAlign(TextAlign.justify)
    .build();

// Predefined configurations
final darkMode = SettingsBuilder.darkMode();
final largeFont = SettingsBuilder.largeFont();
final defaults = SettingsBuilder.defaultSettings();
```

## Test Actions (`test/helpers/test_actions.dart`)

Common widget interaction actions.

### Finder Helpers
```dart
// Find widgets
final finder = TestFinders.byType<TextWidget>();
final byKey = TestFinders.byKey('my-key');
final byText = TestFinders.byText('Submit');
final containing = TestFinders.byTextContaining('Hello');
```

### Widget Actions
```dart
// Tap with retry
await WidgetActions.tapWithRetry(tester, submitButton);

// Enter text
await WidgetActions.enterText(tester, nameField, 'John Doe');

// Drag
await WidgetActions.drag(tester, slider, Offset(100, 0));

// Long press
await WidgetActions.longPress(tester, item);

// Scroll until visible
await WidgetActions.scrollUntilVisible(tester, scrollable, target);

// Wait for widget
await WidgetActions.waitForWidget(tester, finder);

// Wait for widget to disappear
await WidgetActions.waitForWidgetToDisappear(tester, finder);

// Restart app
await WidgetActions.restartApp(tester, myApp);

// Change orientation
await WidgetActions.setOrientation(tester, Orientation.landscape);

// Capture screenshot
await WidgetActions.captureScreenshot(tester, 'screenshot-1');

// Tap back
await WidgetActions.tapBack(tester);

// Close keyboard
await WidgetActions.closeKeyboard(tester);

// Get text from Text widget
final text = WidgetActions.getText(finder);

// Check if widget exists
final exists = WidgetActions.exists(finder);
```

## Test Assertions (`test/helpers/assertions.dart`)

Common assertions for test verification.

### Widget Assertions
```dart
// Existence
TestAssertions.exists(finder);
TestAssertions.notExists(finder);
TestAssertions.existsOnce(finder);
TestAssertions.existsCount(finder, 3);

// Text assertions
TestAssertions.textEquals(finder, 'Expected Text');
TestAssertions.textContains(finder, 'Expected');

// Visibility
TestAssertions.isVisible(finder);
TestAssertions.isEnabled(finder);
TestAssertions.isDisabled(finder);

// Value assertions
TestAssertions.sliderValue(finder, 0.5, tolerance: 0.1);
TestAssertions.dropdownValue(finder, 'en');
TestAssertions.switchState(finder, true);
TestAssertions.textFieldText(finder, 'text');

// Layout assertions
TestAssertions.hasSize(finder, Size(100, 50));
TestAssertions.containsChild(parent, child);

// Special assertions
TestAssertions.progressIndicatorShown();
TestAssertions.progressIndicatorHidden();
TestAssertions.dialogShown();
TestAssertions.snackBarShown(message: 'Success!');
TestAssertions.errorMessageShown();
```

## Wait Helpers (`test/helpers/wait_helpers.dart`)

Async utilities for waiting in tests.

### Condition Waiting
```dart
// Wait for condition
await WaitHelpers.waitFor(() => someCondition());

// Wait for widget
await WaitHelpers.waitForWidget(tester, finder);
await WaitHelpers.waitForWidgetToDisappear(tester, finder);
await WaitHelpers.waitForWidgetCount(tester, finder, 3);

// Wait for animation
await WaitHelpers.waitForAnimation(tester);

// Wait for async operation
await WaitHelpers.waitForAsync(tester);

// Wait for visibility
await WaitHelpers.waitForVisible(tester, finder);
await WaitHelpers.waitForInvisible(tester, finder);

// Wait for scroll to settle
await WaitHelpers.waitForScrollToSettle(tester);

// Wait for app idle
await WaitHelpers.waitForIdle(tester);

// Wait with retry
final result = await WaitHelpers.waitForRetry(
  attempt: () => someAsyncOperation(),
  timeout: Duration(seconds: 5),
);

// Wait for multiple conditions
await WaitHelpers.waitForAll([condition1, condition2]);
await WaitHelpers.waitForAny([condition1, condition2]);
```

## Test Fixtures

### Sample Books

The `test/fixtures/books/` directory contains sample book files:

| File | Description | Use Case |
|------|-------------|----------|
| `small-book.epub` | 50 pages, basic content | Quick tests |
| `medium-book.epub` | 100 pages, multiple chapters | Standard tests |
| `large-book.epub` | 500 pages | Performance tests |
| `single-page.epub` | 1 page | Edge cases |
| `multi-chapter.epub` | 20 chapters | TOC tests |
| `with-images.epub` | Contains images | Image handling |
| `spanish.epub` | Spanish language | i18n tests |
| `chinese.epub` | Chinese (CJK) | CJK tests |
| `arabic.epub` | Arabic (RTL) | RTL tests |
| `complex.epub` | Complex formatting | Edge cases |
| `corrupted.epub` | Invalid format | Error handling |

**Note:** These files need to be created manually or generated as part of test setup.

## Golden Files

The `test/goldens/` directory contains visual regression snapshots.

### Golden File Organization
```
test/goldens/
├── library/
│   ├── list_view.png
│   └── grid_view.png
├── reader/
│   ├── portrait.png
│   ├── landscape.png
│   └── dual_panel.png
├── settings/
│   ├── light_theme.png
│   └── dark_theme.png
└── screenshots/
    ├── onboarding_1.png
    └── onboarding_2.png
```

### Running Golden Tests
```bash
# Generate golden files
flutter test --update-goldens

# Compare against goldens
flutter test test/golden/
```

## Best Practices

### Using Mocks

1. **Always reset mocks between tests:**
   ```dart
   setUp(() {
     mockService.clearCalls();
   });
   ```

2. **Use predictable values:**
   - Word-replacement translation gives consistent output
   - Mock books have known page counts
   - Mock pagination generates known results

3. **Simulate realistic delays:**
   ```dart
   final mock = MockTranslationServiceFactory.createDelayed(
     Duration(milliseconds: 500),
   );
   ```

### Using Builders

1. **Chain methods for clarity:**
   ```dart
   final book = BookBuilder()
       .withId('test')
       .withTitle('Test')
       .build();
   ```

2. **Use predefined builders:**
   ```dart
   final darkSettings = SettingsBuilder.darkMode();
   ```

3. **Create test-specific builders:**
   ```dart
   BookBuilder createBookWithProgress(double progress) {
     return BookBuilder().withProgress(progress);
   }
   ```

### Using Assertions

1. **Use descriptive assertion messages:**
   ```dart
   TestAssertions.exists(
     finder,
     reason: 'Submit button should appear after form is filled',
   );
   ```

2. **Chain with expect:**
   ```dart
   expect(finder, findsOneWidget);
   TestAssertions.textEquals(finder, 'Expected Text');
   ```

### Using Wait Helpers

1. **Always use timeouts:**
   ```dart
   await WaitHelpers.waitForWidget(
     tester,
     finder,
     timeout: Duration(seconds: 5),
   );
   ```

2. **Use specific wait methods:**
   ```dart
   // Instead of generic waitFor
   await WaitHelpers.waitForVisible(tester, finder);
   ```

## Test Data Isolation

Each test should use unique identifiers to avoid conflicts:

```dart
// Use timestamps for unique IDs
final uniqueId = 'book-${DateTime.now().millisecondsSinceEpoch}';

// Use test-specific prefixes
final bookId = '${testSuiteName}-test-book';
```

## Clean Up

Always clean up after tests:

```dart
tearDown(() async {
  // Clear mocks
  mockService.clearCalls();

  // Clear cache
  await mockCache.clear();

  // Reset test data
  await testData.reset();
});
```
