package com.dualreader.app.ui.screens

import com.dualreader.app.domain.entities.Book
import com.dualreader.app.domain.entities.Page
import com.dualreader.app.domain.entities.ReaderTheme
import com.dualreader.app.domain.entities.ReadingSettings
import com.dualreader.app.domain.repositories.BookRepository
import com.dualreader.app.domain.repositories.BookmarkRepository
import com.dualreader.app.domain.repositories.SettingsRepository
import com.dualreader.app.domain.repositories.TranslationCacheRepository
import com.dualreader.app.domain.services.BatchTranslationResult
import com.dualreader.app.domain.usecases.PageToTranslate
import com.dualreader.app.domain.usecases.PaginateBookUseCase
import com.dualreader.app.domain.usecases.TranslatePageUseCase
import io.mockk.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.*
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test

/**
 * Unit tests for ReaderViewModel per-paragraph translation features:
 *  - translateParagraph() / reTranslateParagraph()
 *  - paragraphsTranslating state tracking
 *  - error handling and persistence
 *  - batch (sequential) translation
 *  - duplicate-work protection
 *
 * Mirrors the fake/mock setup of [ReaderViewModelTest].
 */
@OptIn(ExperimentalCoroutinesApi::class)
class ReaderViewModelTranslationTest {

    private val testDispatcher = UnconfinedTestDispatcher()

    private lateinit var bookRepository: BookRepository
    private lateinit var settingsRepository: SettingsRepository
    private lateinit var bookmarkRepository: BookmarkRepository
    private lateinit var translatePageUseCase: TranslatePageUseCase
    private lateinit var paginateBookUseCase: PaginateBookUseCase
    private lateinit var translationCacheRepository: TranslationCacheRepository
    private lateinit var ttsService: com.dualreader.app.domain.services.TtsService

    private val testBook = Book(
        id = "book1", title = "Test Book", author = "Author",
        filePath = "/test.epub", language = "en", totalPages = 3, currentPage = 0,
    )

    private val testPages = listOf(
        Page(index = 0, bookId = "book1", originalText = "Page zero text", chapterIndex = 0),
        Page(index = 1, bookId = "book1", originalText = "Page one text", chapterIndex = 0),
        Page(index = 2, bookId = "book1", originalText = "Page two text", chapterIndex = 0),
    )

    private val testSettings = ReadingSettings(
        fontSize = 16f, lineHeight = 1.5f, targetLanguage = "bg", theme = ReaderTheme.DARK,
    )

    @Before
    fun setUp() {
        Dispatchers.setMain(testDispatcher)
        ReaderViewModel.testIoDispatcher = testDispatcher

        bookRepository = mockk(relaxed = true)
        settingsRepository = mockk(relaxed = true)
        bookmarkRepository = mockk(relaxed = true)
        translatePageUseCase = mockk()
        paginateBookUseCase = mockk(relaxed = true)
        translationCacheRepository = mockk(relaxed = true)
        ttsService = mockk(relaxed = true)

        coEvery { bookRepository.getBookById("book1") } returns testBook
        coEvery { bookRepository.getPagesForBook("book1") } returns testPages
        coEvery { bookRepository.getPage("book1", any()) } returns testPages[0]
        coEvery { settingsRepository.getSettings() } returns testSettings
        every { settingsRepository.settings } returns flowOf(testSettings)
        every { bookmarkRepository.getBookmarksForBook("book1") } returns flowOf(emptyList())
    }

    private fun createViewModel(bookId: String = "book1"): ReaderViewModel {
        return ReaderViewModel(
            savedStateHandle = androidx.lifecycle.SavedStateHandle(mapOf("bookId" to bookId)),
            bookRepository = bookRepository,
            settingsRepository = settingsRepository,
            bookmarkRepository = bookmarkRepository,
            translatePageUseCase = translatePageUseCase,
            paginateBookUseCase = paginateBookUseCase,
            translationCacheRepository = translationCacheRepository,
            ttsService = ttsService,
            translationService = mockk(relaxed = true),
            mlKitModelManager = mockk(relaxed = true),
        )
    }

    /** Helper to stub the per-paragraph translation call. */
    private fun stubTranslate(result: Result<BatchTranslationResult>) {
        coEvery {
            translatePageUseCase.translateBatchWithContext(
                any(), any(), any(), any(), any(), any(),
            )
        } returns result
    }

    @After
    fun tearDown() {
        ReaderViewModel.testIoDispatcher = null
        Dispatchers.resetMain()
    }

    // ── translateParagraph: happy path ────────────────────────────────────

    @Test
    fun `translateParagraph - updates the target page with the translation`() = runTest(testDispatcher) {
        stubTranslate(Result.success(BatchTranslationResult(mapOf(1 to "Превод едно"), "test-model")))

        val vm = createViewModel()
        advanceUntilIdle()

        vm.translateParagraph(1)
        advanceUntilIdle()

        val state = vm.uiState.value as ReaderUiState.ReaderReady
        assertEquals("Превод едно", state.pages[1].effectiveTranslation("bg"))
        assertTrue(state.pages[1].hasTranslation("bg"))
    }

    @Test
    fun `translateParagraph - sends exactly one page to the use case`() = runTest(testDispatcher) {
        var capturedPages: List<PageToTranslate>? = null
        coEvery {
            translatePageUseCase.translateBatchWithContext(any(), any(), any(), any(), any(), any())
        } coAnswers {
            capturedPages = args[0] as List<PageToTranslate>
            Result.success(BatchTranslationResult(mapOf(1 to "T1"), "test"))
        }

        val vm = createViewModel()
        advanceUntilIdle()

        vm.translateParagraph(1)
        advanceUntilIdle()

        assertNotNull("Should have called the use case", capturedPages)
        assertEquals("Should send exactly one page", 1, capturedPages!!.size)
        assertEquals(1, capturedPages!![0].index)
        assertEquals("Page one text", capturedPages!![0].text)
    }

    @Test
    fun `translateParagraph - persists the translated page via updatePageTranslation`() =
        runTest(testDispatcher) {
            stubTranslate(Result.success(BatchTranslationResult(mapOf(1 to "Превод едно"), "test")))

            val vm = createViewModel()
            advanceUntilIdle()

            vm.translateParagraph(1)
            advanceUntilIdle()

            coVerify {
                bookRepository.updatePageTranslation(
                    bookId = "book1",
                    pageIndex = 1,
                    translationsJson = any(),
                    modelsJson = any(),
                )
            }
        }

    @Test
    fun `translateParagraph - leaves error null and isTranslating false on success`() =
        runTest(testDispatcher) {
            stubTranslate(Result.success(BatchTranslationResult(mapOf(1 to "Превод едно"), "test")))

            val vm = createViewModel()
            advanceUntilIdle()

            vm.translateParagraph(1)
            advanceUntilIdle()

            val state = vm.uiState.value as ReaderUiState.ReaderReady
            assertNull(state.translationError)
            assertFalse(state.isTranslating)
        }

    // ── translateParagraph: skip / guard clauses ─────────────────────────

    @Test
    fun `translateParagraph - skips an already translated paragraph`() = runTest(testDispatcher) {
        val preTranslated = listOf(
            testPages[0].withTranslation("bg", "Вече преведено"),
            testPages[1],
            testPages[2],
        )
        coEvery { bookRepository.getPagesForBook("book1") } returns preTranslated

        var callCount = 0
        coEvery {
            translatePageUseCase.translateBatchWithContext(any(), any(), any(), any(), any(), any())
        } coAnswers {
            callCount++
            Result.success(BatchTranslationResult(emptyMap<Int, String>(), "test"))
        }

        val vm = createViewModel()
        advanceUntilIdle()

        vm.translateParagraph(0)
        advanceUntilIdle()

        assertEquals("Already-translated paragraph should be skipped", 0, callCount)
        assertEquals("Вече преведено", (vm.uiState.value as ReaderUiState.ReaderReady).pages[0].effectiveTranslation("bg"))
        // The paragraph id should never have entered the translating set.
        assertTrue(vm.paragraphsTranslating.value.isEmpty())
    }

    @Test
    fun `translateParagraph - does nothing when book failed to load`() = runTest(testDispatcher) {
        coEvery { bookRepository.getBookById("missing") } returns null

        val vm = createViewModel("missing")
        advanceUntilIdle()

        assertTrue(vm.uiState.value is ReaderUiState.Error)

        vm.translateParagraph(0)
        advanceUntilIdle()

        coVerify(exactly = 0) {
            translatePageUseCase.translateBatchWithContext(any(), any(), any(), any(), any(), any())
        }
        assertTrue(vm.paragraphsTranslating.value.isEmpty())
    }

    // ── reTranslateParagraph ─────────────────────────────────────────────

    @Test
    fun `reTranslateParagraph - passes forceRetranslate = true to the use case`() =
        runTest(testDispatcher) {
            var capturedForce: Boolean? = null
            coEvery {
                translatePageUseCase.translateBatchWithContext(any(), any(), any(), any(), any(), any())
            } coAnswers {
                capturedForce = args[4] as Boolean
                Result.success(BatchTranslationResult(mapOf(1 to "Нов превод"), "test"))
            }

            val vm = createViewModel()
            advanceUntilIdle()

            vm.reTranslateParagraph(1)
            advanceUntilIdle()

            assertEquals("reTranslateParagraph must force the translation", true, capturedForce)
        }

    @Test
    fun `reTranslateParagraph - retranslates an already translated paragraph`() =
        runTest(testDispatcher) {
            val preTranslated = listOf(
                testPages[0],
                testPages[1].withTranslation("bg", "Стар превод"),
                testPages[2],
            )
            coEvery { bookRepository.getPagesForBook("book1") } returns preTranslated

            var callCount = 0
            coEvery {
                translatePageUseCase.translateBatchWithContext(any(), any(), any(), any(), any(), any())
            } coAnswers {
                callCount++
                Result.success(BatchTranslationResult(mapOf(1 to "Освежен превод"), "test"))
            }

            val vm = createViewModel()
            advanceUntilIdle()

            vm.reTranslateParagraph(1)
            advanceUntilIdle()

            assertEquals("Force re-translate should call the use case", 1, callCount)
            val state = vm.uiState.value as ReaderUiState.ReaderReady
            assertEquals("Освежен превод", state.pages[1].effectiveTranslation("bg"))
        }

    @Test
    fun `reTranslateParagraph - persists the refreshed translation`() = runTest(testDispatcher) {
        stubTranslate(Result.success(BatchTranslationResult(mapOf(1 to "Нов превод"), "test")))

        val vm = createViewModel()
        advanceUntilIdle()

        vm.reTranslateParagraph(1)
        advanceUntilIdle()

        coVerify {
            bookRepository.updatePageTranslation(
                bookId = "book1", pageIndex = 1, translationsJson = any(), modelsJson = any(),
            )
        }
    }

    // ── paragraphsTranslating state tracking ─────────────────────────────

    @Test
    fun `paragraphsTranslating - contains the paragraph id while translating and is cleared after`() =
        runTest(testDispatcher) {
            coEvery {
                translatePageUseCase.translateBatchWithContext(any(), any(), any(), any(), any(), any())
            } coAnswers {
                // Keep the coroutine suspended so we can observe the "translating" state.
                kotlinx.coroutines.delay(1_000)
                Result.success(BatchTranslationResult(mapOf(1 to "Превод едно"), "test"))
            }

            val vm = createViewModel()
            advanceUntilIdle()

            assertTrue("No paragraphs translating before start", vm.paragraphsTranslating.value.isEmpty())

            vm.translateParagraph(1)

            // The coroutine is suspended inside delay(); the id must be tracked now.
            assertEquals(
                "Paragraph id should be tracked while translating",
                setOf(1),
                vm.paragraphsTranslating.value,
            )

            advanceUntilIdle()

            assertTrue(
                "Translating set should be empty after completion",
                vm.paragraphsTranslating.value.isEmpty(),
            )
        }

    @Test
    fun `paragraphsTranslating - empty by default after book loads`() = runTest(testDispatcher) {
        val vm = createViewModel()
        advanceUntilIdle()

        assertTrue(vm.paragraphsTranslating.value.isEmpty())
    }

    // ── Error handling ───────────────────────────────────────────────────

    @Test
    fun `translateParagraph - sets error and removes id from translating set when use case throws`() =
        runTest(testDispatcher) {
            coEvery {
                translatePageUseCase.translateBatchWithContext(any(), any(), any(), any(), any(), any())
            } throws java.io.IOException("Connection reset")

            val vm = createViewModel()
            advanceUntilIdle()

            vm.translateParagraph(1)
            advanceUntilIdle()

            val state = vm.uiState.value as ReaderUiState.ReaderReady
            assertNotNull("Should surface an error", state.translationError)
            assertTrue(state.translationError!!.contains("Connection reset"))
            assertFalse(state.isTranslating)
            assertTrue(
                "Paragraph id must be removed from translating set on failure",
                vm.paragraphsTranslating.value.isEmpty(),
            )
        }

    @Test
    fun `translateParagraph - sets error and clears translating set on Result failure`() =
        runTest(testDispatcher) {
            stubTranslate(Result.failure(RuntimeException("Translation proxy error 502")))

            val vm = createViewModel()
            advanceUntilIdle()

            vm.translateParagraph(1)
            advanceUntilIdle()

            val state = vm.uiState.value as ReaderUiState.ReaderReady
            assertNotNull(state.translationError)
            assertTrue(state.translationError!!.contains("502"))
            assertTrue(vm.paragraphsTranslating.value.isEmpty())
        }

    @Test
    fun `translateParagraph - successful retry after failure clears the previous error`() =
        runTest(testDispatcher) {
            var attempt = 0
            coEvery {
                translatePageUseCase.translateBatchWithContext(any(), any(), any(), any(), any(), any())
            } coAnswers {
                attempt++
                if (attempt == 1) throw RuntimeException("first attempt failed")
                Result.success(BatchTranslationResult(mapOf(1 to "Успешен превод"), "test"))
            }

            val vm = createViewModel()
            advanceUntilIdle()

            // First attempt fails.
            vm.translateParagraph(1)
            advanceUntilIdle()
            val stateAfterFailure = vm.uiState.value as ReaderUiState.ReaderReady
            assertNotNull(stateAfterFailure.translationError)
            assertTrue(stateAfterFailure.translationError!!.contains("first attempt failed"))

            // Second attempt succeeds and should clear the error.
            vm.translateParagraph(1)
            advanceUntilIdle()

            val stateAfterSuccess = vm.uiState.value as ReaderUiState.ReaderReady
            assertNull("Error should be cleared after success", stateAfterSuccess.translationError)
            assertEquals("Успешен превод", stateAfterSuccess.pages[1].effectiveTranslation("bg"))
        }

    // ── Batch / sequential translation ───────────────────────────────────

    @Test
    fun `translateParagraph - translates multiple paragraphs in sequence`() =
        runTest(testDispatcher) {
            coEvery {
                translatePageUseCase.translateBatchWithContext(any(), any(), any(), any(), any(), any())
            } coAnswers {
                val pages = args[0] as List<PageToTranslate>
                val idx = pages.first().index
                Result.success(BatchTranslationResult(mapOf(idx to "T$idx"), "test"))
            }

            val vm = createViewModel()
            advanceUntilIdle()

            // Translate every paragraph one by one.
            for (i in testPages.indices) {
                vm.translateParagraph(i)
                advanceUntilIdle()
            }

            val state = vm.uiState.value as ReaderUiState.ReaderReady
            assertEquals("T0", state.pages[0].effectiveTranslation("bg"))
            assertEquals("T1", state.pages[1].effectiveTranslation("bg"))
            assertEquals("T2", state.pages[2].effectiveTranslation("bg"))
        }

    @Test
    fun `translateParagraph in sequence - persists each translated paragraph`() =
        runTest(testDispatcher) {
            coEvery {
                translatePageUseCase.translateBatchWithContext(any(), any(), any(), any(), any(), any())
            } coAnswers {
                val pages = args[0] as List<PageToTranslate>
                val idx = pages.first().index
                Result.success(BatchTranslationResult(mapOf(idx to "T$idx"), "test"))
            }

            val vm = createViewModel()
            advanceUntilIdle()

            for (i in testPages.indices) {
                vm.translateParagraph(i)
                advanceUntilIdle()
            }

            coVerify(atLeast = 1) {
                bookRepository.updatePageTranslation("book1", 0, any(), any())
            }
            coVerify(atLeast = 1) {
                bookRepository.updatePageTranslation("book1", 1, any(), any())
            }
            coVerify(atLeast = 1) {
                bookRepository.updatePageTranslation("book1", 2, any(), any())
            }
        }

    // ── Duplicate-work / concurrent protection ───────────────────────────

    @Test
    fun `translateParagraph called twice on same paragraph - does not duplicate work`() =
        runTest(testDispatcher) {
            var callCount = 0
            coEvery {
                translatePageUseCase.translateBatchWithContext(any(), any(), any(), any(), any(), any())
            } coAnswers {
                callCount++
                val pages = args[0] as List<PageToTranslate>
                val idx = pages.first().index
                Result.success(BatchTranslationResult(mapOf(idx to "T$idx"), "test"))
            }

            val vm = createViewModel()
            advanceUntilIdle()

            vm.translateParagraph(0)
            advanceUntilIdle()

            // Second call: page 0 is now translated, so the skip-guard prevents rework.
            vm.translateParagraph(0)
            advanceUntilIdle()

            assertEquals("Should only translate the paragraph once", 1, callCount)
            assertTrue(vm.paragraphsTranslating.value.isEmpty())
        }

    @Test
    fun `reTranslateParagraph can force duplicate work that translateParagraph prevents`() =
        runTest(testDispatcher) {
            var callCount = 0
            coEvery {
                translatePageUseCase.translateBatchWithContext(any(), any(), any(), any(), any(), any())
            } coAnswers {
                callCount++
                val pages = args[0] as List<PageToTranslate>
                val idx = pages.first().index
                Result.success(BatchTranslationResult(mapOf(idx to "T$idx"), "test"))
            }

            val vm = createViewModel()
            advanceUntilIdle()

            vm.translateParagraph(0)
            advanceUntilIdle()
            vm.translateParagraph(0) // skipped (already translated)
            advanceUntilIdle()
            vm.reTranslateParagraph(0) // forced → actually re-translates
            advanceUntilIdle()

            assertEquals("translate skipped, reTranslate forced", 2, callCount)
        }

    // ── DR-049: translateParagraphInternal job tracking + single-apply ────

    @Test
    fun `translateParagraph - persists exactly once, not double`() = runTest(testDispatcher) {
        stubTranslate(Result.success(BatchTranslationResult(mapOf(1 to "Превод"), "test")))

        val vm = createViewModel()
        advanceUntilIdle()

        vm.translateParagraph(1)
        advanceUntilIdle()

        // Before DR-049 the onPageTranslated callback AND the fold both called
        // applyTranslation → updatePageTranslation was invoked twice.
        coVerify(exactly = 1) {
            bookRepository.updatePageTranslation("book1", 1, any(), any())
        }
    }

    @Test
    fun `cancelTranslation cancels a running paragraph translation`() = runTest(testDispatcher) {
        coEvery {
            translatePageUseCase.translateBatchWithContext(any(), any(), any(), any(), any(), any())
        } coAnswers {
            kotlinx.coroutines.delay(10_000) // keep the coroutine suspended
            Result.success(BatchTranslationResult(mapOf(1 to "T1"), "test"))
        }

        val vm = createViewModel()
        advanceUntilIdle()

        vm.translateParagraph(1)
        // Coroutine is suspended inside delay(); the id must be tracked now.
        assertEquals(setOf(1), vm.paragraphsTranslating.value)

        vm.cancelTranslation()
        advanceUntilIdle()

        // Before DR-049 the job was never stored in translationJob, so cancel()
        // was a no-op and the translation completed → updatePageTranslation was called.
        coVerify(exactly = 0) {
            bookRepository.updatePageTranslation("book1", 1, any(), any())
        }
        // The translating set should be cleaned up by the finally block.
        assertTrue(vm.paragraphsTranslating.value.isEmpty())
    }

    @Test
    fun `translating paragraph A then B cancels A before B starts`() = runTest(testDispatcher) {
        var translatedIndices = mutableListOf<Int>()
        coEvery {
            translatePageUseCase.translateBatchWithContext(any(), any(), any(), any(), any(), any())
        } coAnswers {
            kotlinx.coroutines.delay(10_000)
            val pages = args[0] as List<PageToTranslate>
            val idx = pages.first().index
            translatedIndices.add(idx)
            Result.success(BatchTranslationResult(mapOf(idx to "T$idx"), "test"))
        }

        val vm = createViewModel()
        advanceUntilIdle()

        vm.translateParagraph(0) // suspended in delay
        assertEquals(setOf(0), vm.paragraphsTranslating.value)

        vm.translateParagraph(1) // should cancel paragraph 0's job
        advanceUntilIdle()

        // Before DR-049 both coroutines ran because the job was never tracked.
        // After the fix, only paragraph 1 should complete.
        assertEquals(listOf(1), translatedIndices)
    }
}
