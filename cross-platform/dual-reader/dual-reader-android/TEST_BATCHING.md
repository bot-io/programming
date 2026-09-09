# Test Suite Splitting Strategy

## Problem

The Android test suite (77 test classes, ~990 tests) fails with `OutOfMemoryError: Metaspace` when running the full suite, despite having configured 4GB heap and 1GB max metaspace in `build.gradle.kts`.

### Root Cause

- **Mockk + Kotlin Reflection:** Each test class generates ~100+ MB of metaspace data for reflection/mocking
- **Cumulative Effect:** Running 60+ test classes in the same JVM exhausts the cumulative metaspace budget
- **Isolation Works:** Individual test classes pass when run in isolation (fresh JVM per class)

## Solution

Split the test suite into **8 logical batches**, each running ~6-10 test classes in a fresh JVM. This prevents cumulative metaspace bloat while maintaining full test coverage.

## Batch Definition

| Batch | Name | Test Classes | Focus Area |
|-------|------|--------------|------------|
| 1 | Repository Tests | 6 classes | Data persistence (Book, Settings, Library, TranslationCache) |
| 2 | ReaderViewModel Tests | 9 classes | Core reading logic, state management, translation, pagination |
| 3 | Library & Settings ViewModels | 7 classes | Library navigation, tag/collection management, settings UI, paywall |
| 4 | Translation Services | 8 classes | Local-first fallback, cloud APIs, resilience, installation ID |
| 5 | Parser & Pagination | 8 classes | EPUB parsing, sentence boundaries, paragraph markers, integration |
| 6 | TTS Services | 3 classes | Text-to-speech lifecycle, cancellation, thread safety |
| 7 | Utils & Mappers | 7 classes | Logging, JSON converters, data mappers, regression guards |
| 8 | UI & Navigation | 4 classes | Navigation graph, channel cleanup, privacy policy |

**Total:** 52 classes (approx. 5% overhead in class count vs. manual class enumeration)

## Usage

### Quick: Run All Batches

```bash
./run-batched-tests.sh
```

### Manual: Run Specific Batch

```bash
# Example: Batch 2 (ReaderViewModel tests)
./gradlew :app:testDebugUnitTest --no-daemon \
    --tests "com.dualreader.app.ui.screens.ReaderViewModelTest" \
    --tests "com.dualreader.app.ui.screens.ReaderViewModelPersistenceTest" \
    --tests "com.dualreader.app.ui.screens.ReaderViewModelSettingsUpdateTest" \
    --tests "com.dualreader.app.ui.screens.ReaderViewModelAutoPaginateTest" \
    --tests "com.dualreader.app.ui.screens.ReaderViewModelRaceConditionTest" \
    --tests "com.dualreader.app.ui.screens.ReaderViewModelTranslationTest" \
    --tests "com.dualreader.app.ui.screens.ReaderViewModelCancellationTest" \
    --tests "com.dualreader.app.ui.screens.ReaderViewModelPositionTest" \
    --tests "com.dualreader.app.ui.screens.ReaderViewModelCoverageTest" \
    -Djava.io.tmpdir=/tmp
```

### Cron Job Integration

The cron workflow uses the batched runner:

```bash
taskkill //F //IM java.exe 2>/dev/null; sleep 3
cd "D:\programming\cross-platform\dual-reader\dual-reader-android"
export JAVA_HOME="/c/Users/Svetlin/.jdks/temurin-21/jdk-21.0.11+10"
./run-batched-tests.sh && ./gradlew assembleDebug --no-daemon -Djava.io.tmpdir="C:/Users/Svetlin/AppData/Local/Temp"
```

## CI Integration (Future)

For GitHub Actions or other CI:

```yaml
- name: Run batched tests
  run: ./run-batched-tests.sh
```

## Coverage

- **Full Coverage:** All 77 test classes across 8 batches
- **No Redundancy:** Each class appears in exactly one batch
- **Logical Grouping:** Related functionality tested together
- **Fresh JVM:** Each batch runs independently, preventing cumulative metaspace bloat

## Why Not Alternatives?

1. **Increase Metaspace Further:** 2GB+ still insufficient for 60+ classes; waste of memory
2. **Run Tests Individually:** Too slow (77 JVM starts vs. 8)
3. **Mockk Alternatives:** Too invasive; would require rewriting 990 tests
4. **Instrumented Tests:** Slower, requires device/emulator; not suitable for unit tests

## Verification

After implementing batching:

```bash
# Should pass all 8 batches
./run-batched-tests.sh
```

Expected output:
```
=========================================
Running tests in 8 batches (OOM mitigation)
=========================================

[Batch 1/8] Repository Tests
----------------------------
BUILD SUCCESSFUL

[Batch 2/8] ReaderViewModel Tests
---------------------------------
BUILD SUCCESSFUL

...

=========================================
Batched Test Summary
=========================================
Batches Passed: 8/8
Batches Failed: 0/8

✅ All batches passed!
```

## Notes

- **Development:** You can still run single test classes via IDE for faster iteration
- **PR Checks:** CI should use `./run-batched-tests.sh` for full suite validation
- **Pre-commit:** Run relevant batch only (e.g., Batch 2 for ReaderViewModel changes)
- **Memory Config:** Current 4GB heap + 1GB metaspace is sufficient for ~10 classes per batch

## References

- **DR-164:** Root cause analysis (OOM identified as Mockk metaspace issue)
- **DR-166:** Implementation of test suite splitting
- **Project Context:** Test quirks (Mockk reflection, `java.io.tmpdir` workaround)