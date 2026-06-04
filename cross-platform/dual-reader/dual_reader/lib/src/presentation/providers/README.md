# State Management Architecture

This directory contains all Riverpod state management for Dual Reader 3.2.

## Architecture Overview

All state management is **100% platform-agnostic** and shared across Android, iOS, and Web.

### Design Principles

1. **Single Source of Truth**: Each piece of state has one designated provider
2. **Immutable State**: All state classes use immutable data with `copyWith` methods
3. **Dependency Injection**: Use GetIt service locator for dependencies
4. **Platform Abstraction**: State depends on abstract interfaces, not platform implementations
5. **Separation of Concerns**: State management independent of UI logic

## Provider Catalog

### Settings Provider

**Location**: `settings_notifier.dart`

**Purpose**: Manages all user settings and preferences

**State**: `SettingsEntity`
- Theme mode (light/dark)
- Font family, size, line height
- Margin size, text alignment
- Target translation language
- Panel width ratio

**Dependencies**:
- `GetSettingsUseCase` - Load settings from storage
- `UpdateSettingsUseCase` - Persist settings changes

**Usage**:
```dart
// Watch settings
final settings = ref.watch(settingsProvider);

// Update settings
ref.read(settingsProvider.notifier).updateSettings(newSettings);
```

**Persistence**: Settings automatically persist via `UpdateSettingsUseCase`

---

### Book List Provider

**Location**: `book_list_notifier.dart`

**Purpose**: Manages the list of all imported books

**State**: `List<BookEntity>`

**Dependencies**:
- `GetAllBooksUseCase` - Load books from storage

**Usage**:
```dart
// Watch book list
final books = ref.watch(bookListProvider);

// Refresh list after import/delete
await ref.read(bookListProvider.notifier).refreshBooks();
```

**Persistence**: Books stored in Hive via `BookRepository`

---

### Pagination Progress Provider

**Location**: `pagination_progress_notifier.dart`

**Purpose**: Tracks pagination status for all books

**State**: `Map<String, PaginationProgressState>`

**PaginationProgressState** contains:
- `bookId` - Book identifier
- `status` - `PaginationStatus` enum (notStarted, inProgress, completed, failed)
- `progress` - 0.0 to 1.0 completion percentage
- `errorMessage` - Error message if failed
- `totalPages` - Total pages after completion

**Dependencies**: None (pure state management)

**Usage**:
```dart
// Watch all pagination progress
final progressMap = ref.watch(paginationProgressProvider);

// Watch specific book progress
final bookProgress = ref.watch(bookPaginationProgressProvider(bookId));

// Check if book is paginating
final isPaginating = ref.read(paginationProgressProvider.notifier).isPaginating(bookId);

// Update progress from pagination service
ref.read(paginationProgressProvider.notifier).updateProgress(bookId, 0.5);
```

**Lifetime**: Progress state is in-memory only, resets on app restart

---

### Language Model Provider

**Location**: `language_model_notifier.dart`

**Purpose**: Manages translation model download state (mobile only)

**State**: `LanguageModelState`
- `status` - `ModelDownloadStatus` enum
- `progressMessage` - Current download status message
- `errorMessage` - Error message if failed
- `showNotification` - Controls banner visibility
- `languageCode` - Target language for model

**Dependencies**:
- `TranslationService` - Via GetIt (abstract interface)

**Usage**:
```dart
// Watch model download state
final modelState = ref.watch(languageModelProvider);

// Check and download if needed
final wasReady = await ref.read(languageModelProvider.notifier)
    .checkAndDownloadRequiredModel('es');

// Download model
await ref.read(languageModelProvider.notifier).downloadLanguageModel('es');

// Dismiss notification banner
ref.read(languageModelProvider.notifier).dismissNotification();
```

**Platform Behavior**:
- **Mobile (Android/iOS)**: Checks ML Kit model availability, downloads if needed
- **Web**: Automatically completes (no model needed, uses API)

**Persistence**: Model files persist in platform storage after download

---

## State Lifecycle

### Initialization

All providers are initialized when first accessed:
```dart
// SettingsProvider loads from Hive in constructor
SettingsNotifier(this._getSettingsUseCase, this._updateSettingsUseCase)
    : super(const SettingsEntity()) {
  _loadSettings(); // Async load
}
```

### Updates

State updates follow this pattern:
1. User action triggers notifier method
2. Notifier calls use case (business logic)
3. Use case updates repository (data layer)
4. Notifier updates state
5. UI rebuilds with new state

### Persistence

| Provider | Persistence | Mechanism |
|----------|-------------|-----------|
| Settings | ✅ Persistent | Hive |
| Book List | ✅ Persistent | Hive |
| Pagination Progress | ❌ In-memory | Runtime only |
| Language Model | ✅ Partial | Platform storage (ML Kit files) |

## Platform Abstraction

### Abstract Interfaces

State depends on abstract interfaces, not platform implementations:

```dart
// Domain layer - abstract interface
abstract class TranslationService {
  Future<String> translate({...});
  Future<bool> isLanguageModelReady(String languageCode);
  Future<bool> downloadLanguageModel(String languageCode, {...});
}

// State uses abstract interface
class LanguageModelNotifier extends StateNotifier<LanguageModelState> {
  Future<void> downloadLanguageModel(String languageCode) async {
    final translationService = sl<TranslationService>(); // Abstract type
    // Works on all platforms!
  }
}
```

### Platform-Specific Implementations

Platform-specific code isolated in data layer:
- `client_side_translation_service_mobile_hybrid.dart` - Mobile implementation
- `client_side_translation_service_web.dart` - Web implementation
- Conditional imports select correct implementation at compile time

## Best Practices

### 1. Always use `ref.read` for actions

```dart
// ✅ Correct
ref.read(settingsProvider.notifier).updateSettings(newSettings);

// ❌ Incorrect - don't watch for actions
ref.watch(settingsProvider.notifier).updateSettings(newSettings);
```

### 2. Use `ref.watch` for state

```dart
// ✅ Correct
final settings = ref.watch(settingsProvider);

// ❌ Incorrect - don't read for state
final settings = ref.read(settingsProvider);
```

### 3. Use family providers for parameterized state

```dart
// ✅ Correct - watch specific book progress
final bookProgress = ref.watch(bookPaginationProgressProvider(bookId));
```

### 4. Never store BuildContext in state

State should be serializable and platform-independent.

### 5. Keep notifiers focused

Each notifier should manage one piece of state. Don't combine unrelated state.

## Testing

State management is tested with:
- Unit tests for notifiers
- Widget tests for provider integration
- Mock use cases for isolation

Example test structure:
```dart
test('updates settings', () {
  // Arrange
  final mockUseCase = MockUpdateSettingsUseCase();
  final notifier = SettingsNotifier(mockGetSettings, mockUseCase);

  // Act
  notifier.updateSettings(testSettings);

  // Assert
  expect(mockUseCase.calledWith(testSettings));
  expect(notifier.state, testSettings);
});
```

## Adding New State

When adding new state:

1. Create state class with `copyWith` method
2. Create `StateNotifier` with business logic
3. Create provider
4. Add use case dependencies to DI container
5. Document in this file

Template:
```dart
// 1. State class
class MyState {
  final String data;
  MyState copyWith({String? data}) => MyState(data: data ?? this.data);
}

// 2. Notifier
class MyNotifier extends StateNotifier<MyState> {
  final MyUseCase _useCase;
  MyNotifier(this._useCase) : super(MyState(data: ''));

  Future<void> updateData(String newData) async {
    await _useCase.execute(newData);
    state = MyState(data: newData);
  }
}

// 3. Provider
final myProvider = StateNotifierProvider<MyNotifier, MyState>((ref) {
  return MyNotifier(sl<MyUseCase>());
});
```
