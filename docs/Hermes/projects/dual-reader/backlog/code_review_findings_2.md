## Code Review Findings (Continued)

Finding 10: ReaderViewModel loadBook silently returns null on missing data
- File: `app/src/main/java/com/dualreader/app/ui/screens/ReaderViewModel.kt`
- Lines 300-320: If `pagesFlow.getOrNull(bookFlow.currentPage)` and `pagesFlow.firstOrNull()` both return null, the function emits null. The `.filterNotNull()` downstream filters this out, but there's no logging.
- Impact: When a book is loaded but has no pages (corruption or edge case), the UI just stays in Loading state with no error message or log entry. User has no feedback why the book won't open.
- Recommendation: Log an error message when both page lookups fail.

Finding 11: BookContextExtractor may throw on malformed book chapters
- File: `app/src/main/java/com/dualreader/app/domain/usecases/BookContextExtractor.kt` (based on search results)
- Lines 35-42: Does `pages.sortedBy { it.index }.take(OPENING_PAGES_COUNT)` - assumes all pages have valid `originalText`. If a page has null text, calling `.trim()` on it would NPE.
- Impact: Crash when building context for malformed books.
- Recommendation: Add null-safety or filter to skip pages with null/empty text.

Finding 12: ImportBookUseCase.runCatching swallows all exceptions
- File: `app/src/main/java/com/dualreader/app/domain/usecases/ImportBookUseCase.kt`
- Lines 28-55: Entire import logic wrapped in `runCatching`. All errors (including NPEs, I/O errors) are wrapped in Result.
- Impact: Caller can't distinguish between different error types for targeted handling.
- Recommendation: This is acceptable design; use case returns Result and caller handles errors. No fix needed.

Finding 13: LibraryViewModel export bookmarks uses URI without existence check
- File: `app/src/main/java/com/dualreader/app/ui/navigation/NavHost.kt`
- Lines 119-135: `libraryExportLauncher` callback tries to write to URI without checking if URI is valid/writable. Falls back to exception handling.
- Impact: Silent failure if URI is invalid or permission denied (only logged). User has no UI feedback.
- Recommendation: Show error message to user on export failure.

Finding 14: PreInstalledBooksInitializer copies books without checksum verification
- File: `app/src/main/java/com/dualreader/app/data/initializer/PreInstalledBooksInitializer.kt`
- Lines 63-72: Copies assets to internal storage if file doesn't exist. No checksum verification to ensure asset integrity.
- Impact: If asset is corrupted on device, app will have corrupted book copy.
- Recommendation: This is acceptable for pre-installed assets (bundled with APK). No fix needed.

Finding 15: All CollectAsState without rememberSaveable
- File: Various Compose screens
- Issue: State collected via `collectAsState` is lost on process death and recreation.
- Impact: User reading position, selected tab, etc., lost on low-memory kill.
- Recommendation: This is by design for reading position (saved in DB). UI-only state loss is acceptable for this app type. No fix needed.

## Decision
Finding 10 (silent null in ReaderViewModel.loadBook) is a real issue that affects debugging.
Finding 11 needs verification - check if pages can have null text.
Finding 13 (export error UX) is enhancement not bug.
Findings 12, 14, 15 are acceptable design tradeoffs.

Next: Add DR-101 to backlog for ReaderViewModel logging, verify Finding 11 for actual bug.