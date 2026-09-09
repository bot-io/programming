## Code Review Findings

Finding 1: Empty tag insertion possible in LibraryRepositoryImpl.addTag()
- File: `app/src/main/java/com/dualreader/app/data/repository/LibraryRepositoryImpl.kt`
- Line 59: `bookTagDao.insert(BookTagEntity(bookId = bookId, tag = tag.trim()))`
- Issue: If `tag` is whitespace-only, `tag.trim()` returns an empty string. Empty tags are inserted into the database.
- Impact: Database pollution with empty strings; UI may show empty tag chips or list items.
- Recommendation: Validate tag is not empty after trimming; reject or silently skip empty tags.

Finding 2: NullPointerException risk when coverImageBytes.saveCoverImage returns null
- File: `app/src/main/java/com/dualreader/app/domain/usecases/ImportBookUseCase.kt`
- Lines 37-39: Uses `?: ""` as fallback, but downstream code doesn't robustly distinguish between valid cover path and missing cover.
- Impact: Book entity created with empty coverPath; BookRepositoryImpl.deleteBook() searches for cover files matching `id.*` and may delete unintended files if empty path used elsewhere.
- Recommendation: Explicitly handle missing cover; treat empty string as 'no cover' and ensure deleteBook doesn't match unintended files.

Finding 3: ML Kit translator and language detector are created per-request but may not close on cancellation
- File: `app/src/main/java/com/dualreader/app/data/translation/MlKitTranslationServiceImpl.kt`
- Lines 47-77: `translator = Translation.getClient(options)` created inside translate(), and `detector = LanguageIdentification.getClient()` inside detectLanguage(). CancellationException is propagated, but finally blocks only attempt close; if thrown close logs warning and proceeds. This is acceptable behavior, but repeated rapid cancellations may leak resources.
- Impact: Under high concurrency or cancellation storms, temporary ML Kit resources may not be fully released promptly.
- Recommendation: Current behavior is acceptable; no fix needed.

Finding 4: Paginated books list sorted in-memory for SortOrder.PROGRESS
- File: `app/src/main/java/com/dualreader/app/data/repository/LibraryRepositoryImpl.kt`
- Lines 34-39: Fetches all books by date added first, then sorts in-memory by progressPercent. For large libraries (>1000 books), this could cause performance lag.
- Impact: UI may freeze briefly on library screen with many books.
- Recommendation: Consider DB-level sorting with computed progress column or pagination for large libraries.

Finding 5: SettingsScreen sliders use local state with LaunchedEffect sync
- File: `app/src/main/java/com/dualreader/app/ui/screens/SettingsScreen.kt`
- Lines 52-62: Uses localMutableState and LaunchedEffect(settings) to sync when external settings change. If settings update rapidly, LaunchedEffect may restart but current implementation with if-checks prevents thrashing. Good design.

Finding 6: NavHost copyEpubToInternalStorage returns null on null URI or error
- File: `app/src/main/java/com/dualreader/app/ui/navigation/NavHost.kt`
- Lines 44-57: Returns null on null URI or any Exception. Caller at line 113 checks null before calling viewModel.importBook(savedPath). This is correct null-safety.

Finding 7: MainActivity injects dependencies with @Inject lateinit var
- File: `app/src/main/java/com/dualreader/app/ui/MainActivity.kt`
- Lines 29-32: All injected fields are used after onCreate, which is correct for Hilt lifecycle. No lateinit access before initialization risk.

Finding 8: File outputStream in copyEpubToInternalStorage not closed on null input stream
- File: `app/src/main/java/com/dualreader/app/ui/navigation/NavHost.kt`
- Lines 49-51: `destFile.outputStream().use { output -> input.copyTo(output) }` is inside the inputStream use block. If inputStream is null, output stream is not opened ( Elvis returns null). No leak.

Finding 9: AppLogger e() truncates stackTrace to 500 chars
- File: `app/src/main/java/com/dualreader/app/util/AppLogger.kt`
- Line 52: `stackTraceToString().take(500)` limits exception details. This may hide important stack information in deep call stacks.
- Impact: Debugging difficult for complex exceptions; truncated stack may lose root cause.
- Recommendation: Increase limit or log full stack to file and truncated to console.

## Decision
Focus on Finding 1 (empty tag insertion) as it's a concrete bug with clear regression test path.
Findings 2, 3, 4 are edge cases or acceptable tradeoffs.
Finding 9 is enhancement (better logging) not a bug.

Next: Add DR-099 to backlog for empty tag validation fix.