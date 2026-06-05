# Dual Reader - Known Issues & Technical Debt

Last updated: 2025-06-05

## Active Issues

### 1. DualReaderScreen widget tests fail (12 tests skipped)
**Status:** Tests written but skipped
**Cause:** `DualReaderScreen` internally casts `TranslationService` to `ClientSideTranslationService`. Widget tests use `FakeTranslationService` which can't be cast.
**Fix needed:** Refactor `DualReaderScreen` to depend on the `TranslationService` interface instead of the concrete type. Use DI to inject the implementation.
**File:** `lib/src/presentation/screens/dual_reader_screen.dart`

### 2. _CacheManagementTile singleton (4 tests skipped)
**Status:** Tests written but skipped
**Cause:** `_CacheManagementTile` uses `EnhancedTranslationCacheService.instance` singleton instead of DI.
**Fix needed:** Refactor to accept the service via constructor injection or Riverpod provider.
**File:** `lib/src/presentation/screens/settings_screen.dart`

### 3. PaginateBookUseCase needs real EPUB bytes (10 tests skipped)
**Status:** Tests written but skipped
**Cause:** Some pagination tests need real EPUB binary data for full integration testing.
**Fix needed:** Add a small test EPUB fixture file to the test data directory.

### 4. Connectivity platform channel tests (6 tests skipped)
**Status:** Tests written but skipped
**Cause:** Platform channel tests require real device/emulator.
**Fix needed:** Run on device/emulator in CI.

### 5. LanguageModelDownloader mobile tests (7 tests skipped)
**Status:** Tests written but skipped
**Cause:** Mobile-specific download logic requires Android/iOS platform.
**Fix needed:** Run on device/emulator.

### 6. FilePicker null mock (1 test skipped)
**Status:** Test written but skipped
**Cause:** `FilePicker.platform.pickFiles()` returns null in test environment without proper mocking.
**Fix needed:** Mock FilePicker platform channel.

### 7. `flutter pub get` fails on MSYS/Git Bash
**Status:** Active
**Cause:** Flutter tries to create temp dirs with random names (`.hermes-tmp.*`) inside project directories. MSYS on Windows can't resolve these paths.
**Workaround:** Use CMD or PowerShell for `flutter pub get`.
**Impact:** Cannot add new dependencies from MSYS terminal. Existing dependencies work fine.

## Resolved Issues

### ~~ThemeMode adapter not registered~~ (RESOLVED)
**Fix:** ThemeMode adapter (typeId 100) is properly registered in `injection_container.dart`.

### ~~Auto-pagination not triggered after import~~ (RESOLVED in commit 04378cd)
**Fix:** Library screen now calls `PaginateBookUseCase` immediately after book import.

### ~~No library search/filter~~ (RESOLVED in commit 04378cd)
**Fix:** Search bar appears when library has more than 3 books.

### ~~No color theme presets~~ (RESOLVED in commit 94b6427)
**Fix:** Added 5 color theme presets: Standard, Sepia, Ocean, Forest, Midnight.

### ~~Limited language support~~ (RESOLVED in commit a904a63)
**Fix:** Expanded language selector from 12 to 57 languages with emoji flags.

### ~~No drag-and-drop import for web~~ (RESOLVED in commit 542a385)
**Fix:** Added HTML5 drag-and-drop handlers in index.html and FileDropZone widget.

### ~~PWA manifest is boilerplate~~ (RESOLVED in commit 04378cd)
**Fix:** Customized manifest.json with Dual Reader branding.

## Technical Debt

### `SettingsEntity.fontlFamily` typo
The field name has an extra 'l': `fontlFamily` instead of `fontFamily`.
This is stored in Hive as field index 1, so renaming would break existing stored settings.
Should be fixed with a migration when convenient.

### Deep coupling in DualReaderScreen
The screen directly references concrete types (ClientSideTranslationService) and
initializes Riverpod providers, GetIt DI, Hive, and epubx internally.
Should be refactored to accept dependencies via constructor/providers.

### Missing features from requirements
- Bookmarks for quick access
- Reading history (recently opened)
- Export/import settings
- About page (app version, credits, license)
