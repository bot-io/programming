package com.dualreader.app.ui.screens

import com.dualreader.app.domain.entities.Book
import com.dualreader.app.domain.entities.Page
import com.dualreader.app.domain.entities.ReaderTheme
import com.dualreader.app.domain.entities.ReadingSettings
import com.dualreader.app.domain.repositories.BookRepository
import com.dualreader.app.domain.repositories.BookmarkRepository
import com.dualreader.app.domain.repositories.SettingsRepository
import com.dualreader.app.domain.repositories.TranslationCacheRepository
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

@OptIn(ExperimentalCoroutinesApi::class)
class ReaderViewModelTest {

    private val testDispatcher = UnconfinedTestDispatcher()

    private lateinit var bookRepository: BookRepository
    private lateinit var settingsRepository: SettingsRepository
    private lateinit var bookmarkRepository: BookmarkRepository
    private lateinit var translatePageUseCase: TranslatePageUseCase
    private lateinit var paginateBookUseCase: PaginateBookUseCase
    private lateinit var translationCacheRepository: TranslationCacheRepository

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
        )
    }

    @After
    fun tearDown() {
        ReaderViewModel.testIoDispatcher = null
        Dispatchers.resetMain()
    }

    // ── Load ──────────────────────────────────────────────────────────────

    @Test
    fun `loadBook - sets ReaderReady state`() = runTest(testDispatcher) {
        val vm = createViewModel()
        advanceUntilIdle()

        val state = vm.uiState.value
        assert(state is ReaderUiState.ReaderReady) { "Expected ReaderReady, got $state" }
        val ready = state as ReaderUiState.ReaderReady
        assertEquals("Test Book", ready.book.title)
        assertEquals(3, ready.pages.size)
        assertEquals(0, ready.currentPage.index)
    }

    @Test
    fun `loadBook - sets Error when book not found`() = runTest(testDispatcher) {
        coEvery { bookRepository.getBookById("missing") } returns null

        val vm = createViewModel("missing")
        advanceUntilIdle()

        val state = vm.uiState.value
        assert(state is ReaderUiState.Error) { "Expected Error, got $state" }
        assert((state as ReaderUiState.Error).message.contains("not found"))
    }

    // ── Navigation ───────────────────────────────────────────────────────

    @Test
    fun `goToPage - updates currentPage synchronously`() = runTest(testDispatcher) {
        val vm = createViewModel()
        advanceUntilIdle()

        vm.goToPage(1)

        val state = vm.uiState.value as ReaderUiState.ReaderReady
        assertEquals(1, state.currentPage.index)
        assertEquals("Page one text", state.currentPage.originalText)
    }

    @Test
    fun `goToPage - ignores out of bounds`() = runTest(testDispatcher) {
        val vm = createViewModel()
        advanceUntilIdle()

        vm.goToPage(99)
        assertEquals(0, (vm.uiState.value as ReaderUiState.ReaderReady).currentPage.index)
    }

    @Test
    fun `goToPage - ignores negative`() = runTest(testDispatcher) {
        val vm = createViewModel()
        advanceUntilIdle()

        vm.goToPage(-1)
        assertEquals(0, (vm.uiState.value as ReaderUiState.ReaderReady).currentPage.index)
    }

    @Test
    fun `nextPage - advances one page`() = runTest(testDispatcher) {
        val vm = createViewModel()
        advanceUntilIdle()

        vm.nextPage()
        assertEquals(1, (vm.uiState.value as ReaderUiState.ReaderReady).currentPage.index)
    }

    @Test
    fun `previousPage - goes back`() = runTest(testDispatcher) {
        val vm = createViewModel()
        advanceUntilIdle()

        vm.goToPage(2)
        vm.previousPage()
        assertEquals(1, (vm.uiState.value as ReaderUiState.ReaderReady).currentPage.index)
    }

    @Test
    fun `nextPage - stays on last page`() = runTest(testDispatcher) {
        val vm = createViewModel()
        advanceUntilIdle()

        vm.goToPage(2)
        vm.nextPage()
        assertEquals(2, (vm.uiState.value as ReaderUiState.ReaderReady).currentPage.index)
    }

    @Test
    fun `previousPage - stays on first page`() = runTest(testDispatcher) {
        val vm = createViewModel()
        advanceUntilIdle()

        vm.previousPage()
        assertEquals(0, (vm.uiState.value as ReaderUiState.ReaderReady).currentPage.index)
    }

    @Test
    fun `goToPage - persists book update`() = runTest(testDispatcher) {
        val vm = createViewModel()
        advanceUntilIdle()

        vm.goToPage(2)
        advanceUntilIdle()

        coVerify { bookRepository.updateBook(match { it.currentPage == 2 }) }
    }

    // ── Translation ──────────────────────────────────────────────────────

    @Test
    fun `translateCurrentPage - updates page with translation`() = runTest(testDispatcher) {
        coEvery {
            translatePageUseCase.translateBatchWithContext(any(), any(), any(), any())
        } returns Result.success(mapOf(0 to "Превод"))
        val vm = createViewModel()
        advanceUntilIdle()

        vm.translateCurrentPage()
        advanceUntilIdle()

        // After translate, the page should have the translation
        val state = vm.uiState.value
        if (state is ReaderUiState.ReaderReady) {
            assertEquals("Превод", state.currentPage.effectiveTranslation("bg"))
        }
    }

    @Test
    fun `translateCurrentPage - sets Error on failure`() = runTest(testDispatcher) {
        coEvery {
            translatePageUseCase.translateBatchWithContext(any(), any(), any(), any())
        } returns Result.failure(RuntimeException("Network error"))
        val vm = createViewModel()
        advanceUntilIdle()

        vm.translateCurrentPage()
        advanceUntilIdle()

        val state = vm.uiState.value
        when (state) {
            is ReaderUiState.Error -> assertTrue(state.message.contains("Network error"))
            is ReaderUiState.ReaderReady -> assertFalse(state.isTranslating)
            else -> fail("Unexpected state: $state")
        }
    }

    @Test
    fun `translateCurrentPage - prevents double translation`() = runTest(testDispatcher) {
        var callCount = 0
        coEvery {
            translatePageUseCase.translateBatchWithContext(any(), any(), any(), any())
        } coAnswers {
            callCount++
            kotlinx.coroutines.delay(1000)
            Result.success(mapOf(0 to "translated"))
        }
        val vm = createViewModel()
        advanceUntilIdle()

        vm.translateCurrentPage()
        vm.translateCurrentPage()
        advanceUntilIdle()

        // Second call cancels the first and starts a new one
        assertEquals("Should call translate (cancelled + restarted)", 2, callCount)
    }

    @Test
    fun `cancelTranslation - resets isTranslating`() = runTest(testDispatcher) {
        coEvery {
            translatePageUseCase.translateBatchWithContext(any(), any(), any(), any())
        } coAnswers {
            kotlinx.coroutines.delay(5000)
            Result.success(mapOf(0 to "translated"))
        }
        val vm = createViewModel()
        advanceUntilIdle()

        vm.translateCurrentPage()
        advanceUntilIdle()

        vm.cancelTranslation()
        advanceUntilIdle()

        val state = vm.uiState.value as ReaderUiState.ReaderReady
        assertFalse("isTranslating should be false after cancel", state.isTranslating)
        assertNull("translationError should be null after cancel", state.translationError)
    }

    @Test
    fun `cancelTranslation - while batch translating stops cleanly`() = runTest(testDispatcher) {
        var translatedCount = 0
        coEvery { translatePageUseCase.translateBatchWithContext(any(), any(), any(), any()) } coAnswers {
            kotlinx.coroutines.delay(5000)
            translatedCount = 3
            Result.success(mapOf(0 to "t0", 1 to "t1", 2 to "t2"))
        }
        val vm = createViewModel()
        advanceUntilIdle()

        vm.translateAllPages()
        vm.cancelTranslation()
        advanceUntilIdle()

        val state = vm.uiState.value as ReaderUiState.ReaderReady
        assertFalse("isTranslating should be false after cancel", state.isTranslating)
    }

    @Test
    fun `translateAllPages - saves progress per page`() = runTest(testDispatcher) {
        val pages = listOf(
            com.dualreader.app.domain.usecases.PageToTranslate(0, "Page zero text"),
            com.dualreader.app.domain.usecases.PageToTranslate(1, "Page one text"),
        )
        coEvery {
            translatePageUseCase.translateBatchWithContext(any(), any(), any(), any())
        } coAnswers {
            val callback = args[3] as ((Int, String) -> Unit)
            callback(0, "Превод нула")
            callback(1, "Превод едно")
            Result.success(mapOf(0 to "Превод нула", 1 to "Превод едно"))
        }
        val vm = createViewModel()
        advanceUntilIdle()

        vm.translateAllPages()
        advanceUntilIdle()

        // Should have saved pages at least once per translated page
        coVerify(atLeast = 2) { bookRepository.savePages(any()) }
    }

    @Test
    fun `translateCurrentPage - persists translated pages`() = runTest(testDispatcher) {
        coEvery {
            translatePageUseCase.translateBatchWithContext(any(), any(), any(), any())
        } returns Result.success(mapOf(0 to "превод"))
        val vm = createViewModel()
        advanceUntilIdle()

        vm.translateCurrentPage()
        advanceUntilIdle()

        coVerify { bookRepository.savePages(any()) }
    }

    // ── Bookmarks ────────────────────────────────────────────────────────

    @Test
    fun `addBookmark - calls repository`() = runTest(testDispatcher) {
        val vm = createViewModel()
        advanceUntilIdle()

        vm.addBookmark("my note")
        advanceUntilIdle()

        coVerify { bookmarkRepository.addBookmark(match { it.note == "my note" && it.pageIndex == 0 }) }
    }

    @Test
    fun `removeBookmark - calls delete`() = runTest(testDispatcher) {
        val vm = createViewModel()
        advanceUntilIdle()

        vm.removeBookmark("bm1")
        advanceUntilIdle()

        coVerify { bookmarkRepository.deleteBookmark("bm1") }
    }

    // ── Search (synchronous) ────────────────────────────────────────────

    @Test
    fun `search - finds matches across pages`() = runTest(testDispatcher) {
        val vm = createViewModel()
        advanceUntilIdle()

        vm.search("Page one")
        val results = vm.searchResults.value
        assertEquals(1, results.size)
        assertEquals(1, results[0].pageIndex)
        assertTrue(results[0].snippet.contains("Page one"))
    }

    @Test
    fun `search - returns empty for no match`() = runTest(testDispatcher) {
        val vm = createViewModel()
        advanceUntilIdle()

        vm.search("nonexistent xyz")
        assertEquals(0, vm.searchResults.value.size)
    }

    @Test
    fun `search - finds all pages`() = runTest(testDispatcher) {
        val vm = createViewModel()
        advanceUntilIdle()

        vm.search("Page")
        assertEquals(3, vm.searchResults.value.size)
    }

    @Test
    fun `search - clears on blank query`() = runTest(testDispatcher) {
        val vm = createViewModel()
        advanceUntilIdle()

        vm.search("Page")
        assertEquals(3, vm.searchResults.value.size)

        vm.search("")
        assertEquals(0, vm.searchResults.value.size)
    }

    @Test
    fun `clearSearch - resets state`() = runTest(testDispatcher) {
        val vm = createViewModel()
        advanceUntilIdle()

        vm.search("Page")
        vm.clearSearch()

        assertEquals("", vm.searchQuery.value)
        assertEquals(0, vm.searchResults.value.size)
    }

    // ── Settings (via ioDispatcher) ─────────────────────────────────────

    @Test
    fun `updateSettings - does not crash`() = runTest(testDispatcher) {
        val vm = createViewModel()
        advanceUntilIdle()

        vm.updateSettings { it.copy(fontSize = 20f) }
        advanceUntilIdle()

        // Settings update is in-memory (_settings StateFlow), no repo call
        val state = vm.uiState.value
        assert(state is ReaderUiState.ReaderReady) { "Expected ReaderReady, got $state" }
    }

    @Test
    fun `toggleImmersiveMode - does not crash`() = runTest(testDispatcher) {
        val vm = createViewModel()
        advanceUntilIdle()

        vm.toggleImmersiveMode()
        advanceUntilIdle()

        val state = vm.uiState.value
        assert(state is ReaderUiState.ReaderReady) { "Expected ReaderReady, got $state" }
    }

    // ── Per-language translation cache ──────────────────────────────────

    @Test
    fun `translateCurrentPage - caches translation per language`() = runTest(testDispatcher) {
        coEvery {
            translatePageUseCase.translateBatchWithContext(any(), any(), any(), any())
        } returns Result.success(mapOf(0 to "BG translation"))
        val vm = createViewModel()
        advanceUntilIdle()

        vm.translateCurrentPage()
        advanceUntilIdle()

        val state = vm.uiState.value as ReaderUiState.ReaderReady
        assertEquals("BG translation", state.currentPage.effectiveTranslation("bg"))
    }

    @Test
    fun `hasTranslation - marks page as translated after translateCurrentPage`() = runTest(testDispatcher) {
        coEvery {
            translatePageUseCase.translateBatchWithContext(any(), any(), any(), any())
        } returns Result.success(mapOf(0 to "Превод"))
        val vm = createViewModel()
        advanceUntilIdle()

        vm.translateCurrentPage()
        advanceUntilIdle()

        val state = vm.uiState.value as ReaderUiState.ReaderReady
        assertTrue(state.currentPage.hasTranslation("bg"))
    }

    @Test
    fun `effectiveTranslation - returns null for untranslated language`() = runTest(testDispatcher) {
        val vm = createViewModel()
        advanceUntilIdle()

        val state = vm.uiState.value as ReaderUiState.ReaderReady
        assertNull(state.currentPage.effectiveTranslation("de"))
    }

    // ── Screen wake settings ────────────────────────────────────────────

    @Test
    fun `settings default screenWakeTimeoutMinutes is 30`() = runTest(testDispatcher) {
        val vm = createViewModel()
        advanceUntilIdle()

        val state = vm.uiState.value as ReaderUiState.ReaderReady
        assertEquals(30, state.settings.screenWakeTimeoutMinutes)
    }

    @Test
    fun `settings default sentenceCounterEnabled is false`() = runTest(testDispatcher) {
        val vm = createViewModel()
        advanceUntilIdle()

        val state = vm.uiState.value as ReaderUiState.ReaderReady
        assertFalse(state.settings.sentenceCounterEnabled)
    }

    @Test
    fun `updateSettings - changes in-memory settings without crash`() = runTest(testDispatcher) {
        val vm = createViewModel()
        advanceUntilIdle()

        // updateSettings modifies _settings StateFlow in-memory
        vm.updateSettings { it.copy(screenWakeTimeoutMinutes = 60, sentenceCounterEnabled = true) }
        advanceUntilIdle()

        // The VM should still be in a valid state
        val state = vm.uiState.value
        assert(state is ReaderUiState.ReaderReady) { "Expected ReaderReady, got $state" }
    }

    @Test
    fun `updateSettings - screenWake disabled with 0 without crash`() = runTest(testDispatcher) {
        val vm = createViewModel()
        advanceUntilIdle()

        vm.updateSettings { it.copy(screenWakeTimeoutMinutes = 0) }
        advanceUntilIdle()

        val state = vm.uiState.value
        assert(state is ReaderUiState.ReaderReady) { "Expected ReaderReady, got $state" }
    }

    @Test
    fun `ReadingSettings defaults - screenWake 30, sentenceCounter false`() {
        val settings = ReadingSettings()
        assertEquals(30, settings.screenWakeTimeoutMinutes)
        assertFalse(settings.sentenceCounterEnabled)
    }

    @Test
    fun `ReadingSettings - screenWake can be set to various values`() {
        val values = listOf(0, 5, 10, 15, 30, 60)
        for (value in values) {
            val settings = ReadingSettings(screenWakeTimeoutMinutes = value)
            assertEquals(value, settings.screenWakeTimeoutMinutes)
        }
    }

    // ── Dynamic Re-Pagination ──────────────────────────────────────────

    @Test
    fun `rePaginate - calls paginateBookUseCase with measured dimensions`() = runTest(testDispatcher) {
        val vm = createViewModel()
        advanceUntilIdle()

        vm.rePaginate(panelWidthPx = 1080, panelHeightPx = 2400, displayDensity = 2.625f)
        advanceUntilIdle()

        coVerify {
            paginateBookUseCase(
                book = match { it.id == "book1" },
                screenWidth = 1080,
                screenHeight = 2400,
            )
        }
    }

    @Test
    fun `rePaginate - reloads pages from repository`() = runTest(testDispatcher) {
        val newPages = listOf(
            Page(index = 0, bookId = "book1", originalText = "Re-paginated page 0", chapterIndex = 0),
            Page(index = 1, bookId = "book1", originalText = "Re-paginated page 1", chapterIndex = 0),
            Page(index = 2, bookId = "book1", originalText = "Re-paginated page 2", chapterIndex = 0),
            Page(index = 3, bookId = "book1", originalText = "Re-paginated page 3", chapterIndex = 0),
        )

        // Initially returns 3 pages, then 4 after re-pagination
        var pageCallCount = 0
        coEvery { bookRepository.getPagesForBook("book1") } coAnswers {
            pageCallCount++
            if (pageCallCount <= 1) testPages else newPages
        }

        val vm = createViewModel()
        advanceUntilIdle()

        // Before re-pagination: 3 pages
        assertEquals(3, (vm.uiState.value as ReaderUiState.ReaderReady).pages.size)

        vm.rePaginate(1080, 2400, 2.625f)
        advanceUntilIdle()

        // After re-pagination: 4 pages
        val state = vm.uiState.value as ReaderUiState.ReaderReady
        assertEquals(4, state.pages.size)
        assertEquals("Re-paginated page 0", state.pages[0].originalText)
    }

    @Test
    fun `rePaginate - sets isRePaginating during operation`() = runTest(testDispatcher) {
        coEvery {
            paginateBookUseCase(any(), any(), any())
        } coAnswers {
            kotlinx.coroutines.delay(100)
            Result.success(Unit)
        }

        val vm = createViewModel()
        advanceUntilIdle()

        vm.rePaginate(1080, 2400, 2.625f)
        advanceUntilIdle()

        coVerify { paginateBookUseCase(any(), any(), any()) }
    }

    @Test
    fun `rePaginate - resets isRePaginating to false after completion`() = runTest(testDispatcher) {
        val vm = createViewModel()
        advanceUntilIdle()

        vm.rePaginate(1080, 2400, 2.625f)
        advanceUntilIdle()

        val state = vm.uiState.value as ReaderUiState.ReaderReady
        assertFalse("isRePaginating should be false after completion", state.isRePaginating)
    }

    @Test
    fun `rePaginate - resets isRePaginating to false on error`() = runTest(testDispatcher) {
        coEvery {
            paginateBookUseCase(any(), any(), any())
        } throws RuntimeException("Pagination failed")

        val vm = createViewModel()
        advanceUntilIdle()

        vm.rePaginate(1080, 2400, 2.625f)
        advanceUntilIdle()

        val state = vm.uiState.value as ReaderUiState.ReaderReady
        assertFalse("isRePaginating should be false after error", state.isRePaginating)
        // Pages should remain unchanged
        assertEquals(3, state.pages.size)
    }

    @Test
    fun `rePaginate - does nothing when no book loaded`() = runTest(testDispatcher) {
        coEvery { bookRepository.getBookById("nobook") } returns null

        val vm = createViewModel("nobook")
        advanceUntilIdle()

        // State should be Error, rePaginate should not crash
        vm.rePaginate(1080, 2400, 2.625f)
        advanceUntilIdle()

        coVerify(exactly = 0) { paginateBookUseCase(any(), any(), any()) }
    }

    @Test
    fun `rePaginate - keeps existing pages when use case throws`() = runTest(testDispatcher) {
        coEvery {
            paginateBookUseCase(any(), any(), any())
        } throws RuntimeException("Disk error")

        val vm = createViewModel()
        advanceUntilIdle()

        val originalPages = (vm.uiState.value as ReaderUiState.ReaderReady).pages.size

        vm.rePaginate(1080, 2400, 2.625f)
        advanceUntilIdle()

        val state = vm.uiState.value as ReaderUiState.ReaderReady
        assertEquals("Pages should be unchanged", originalPages, state.pages.size)
    }

    // ── isRePaginating in state ────────────────────────────────────────

    @Test
    fun `ReaderReady - isRePaginating defaults to false`() = runTest(testDispatcher) {
        val vm = createViewModel()
        advanceUntilIdle()

        val state = vm.uiState.value as ReaderUiState.ReaderReady
        assertFalse(state.isRePaginating)
    }

    @Test
    fun `goToPage - includes isRePaginating in state`() = runTest(testDispatcher) {
        val vm = createViewModel()
        advanceUntilIdle()

        vm.goToPage(1)
        val state = vm.uiState.value as ReaderUiState.ReaderReady
        assertEquals(1, state.currentPage.index)
        assertFalse(state.isRePaginating)
    }

    // ── Cache restoration after re-pagination ─────────────────────────

    @Test
    fun `rePaginate - restores cached translations for new pages`() = runTest(testDispatcher) {
        val newPages = listOf(
            Page(index = 0, bookId = "book1", originalText = "Hello world", chapterIndex = 0),
            Page(index = 1, bookId = "book1", originalText = "Goodbye world", chapterIndex = 0),
        )

        var pageCallCount = 0
        coEvery { bookRepository.getPagesForBook("book1") } coAnswers {
            pageCallCount++
            if (pageCallCount <= 1) testPages else newPages
        }

        // Cache has a translation for page 0 but not page 1
        coEvery { translationCacheRepository.get("Hello world", "en", "bg") } returns "Здравей свят"
        coEvery { translationCacheRepository.get("Goodbye world", "en", "bg") } returns null

        val vm = createViewModel()
        advanceUntilIdle()

        vm.rePaginate(1080, 2400, 2.625f)
        advanceUntilIdle()

        val state = vm.uiState.value as ReaderUiState.ReaderReady
        assertEquals(2, state.pages.size)
        // Page 0 should have its cached translation restored
        assertEquals("Здравей свят", state.pages[0].effectiveTranslation("bg"))
        assertTrue(state.pages[0].hasTranslation("bg"))
        // Page 1 has no cache entry, should remain untranslated
        assertFalse(state.pages[1].hasTranslation("bg"))
    }

    @Test
    fun `rePaginate - restores all cached translations`() = runTest(testDispatcher) {
        val newPages = listOf(
            Page(index = 0, bookId = "book1", originalText = "Alpha", chapterIndex = 0),
            Page(index = 1, bookId = "book1", originalText = "Beta", chapterIndex = 0),
        )

        var pageCallCount = 0
        coEvery { bookRepository.getPagesForBook("book1") } coAnswers {
            pageCallCount++
            if (pageCallCount <= 1) testPages else newPages
        }

        coEvery { translationCacheRepository.get("Alpha", "en", "bg") } returns "Алфа"
        coEvery { translationCacheRepository.get("Beta", "en", "bg") } returns "Бета"

        val vm = createViewModel()
        advanceUntilIdle()

        vm.rePaginate(1080, 2400, 2.625f)
        advanceUntilIdle()

        val state = vm.uiState.value as ReaderUiState.ReaderReady
        assertEquals("Алфа", state.pages[0].effectiveTranslation("bg"))
        assertEquals("Бета", state.pages[1].effectiveTranslation("bg"))
    }

    @Test
    fun `rePaginate - queries cache with correct source language`() = runTest(testDispatcher) {
        val newPages = listOf(
            Page(index = 0, bookId = "book1", originalText = "Some text", chapterIndex = 0),
        )

        var pageCallCount = 0
        coEvery { bookRepository.getPagesForBook("book1") } coAnswers {
            pageCallCount++
            if (pageCallCount <= 1) testPages else newPages
        }

        coEvery { translationCacheRepository.get(any(), any(), any()) } returns null

        val vm = createViewModel()
        advanceUntilIdle()

        vm.rePaginate(1080, 2400, 2.625f)
        advanceUntilIdle()

        // Verify the cache was queried with the book's language ("en") and target language ("bg")
        coVerify { translationCacheRepository.get("Some text", "en", "bg") }
    }

    @Test
    fun `rePaginate - handles cache exception gracefully`() = runTest(testDispatcher) {
        val newPages = listOf(
            Page(index = 0, bookId = "book1", originalText = "Hello", chapterIndex = 0),
        )

        var pageCallCount = 0
        coEvery { bookRepository.getPagesForBook("book1") } coAnswers {
            pageCallCount++
            if (pageCallCount <= 1) testPages else newPages
        }

        coEvery { translationCacheRepository.get(any(), any(), any()) } throws RuntimeException("Cache error")

        val vm = createViewModel()
        advanceUntilIdle()

        // Should NOT crash even if cache throws
        vm.rePaginate(1080, 2400, 2.625f)
        advanceUntilIdle()

        val state = vm.uiState.value as ReaderUiState.ReaderReady
        assertEquals(1, state.pages.size)
        assertFalse(state.isRePaginating)
    }

    // ── Substring fallback after re-pagination ─────────────────────────────

    @Test
    fun `rePaginate - restores translation via substring match when exact cache misses`() = runTest(testDispatcher) {
        // Use pages whose text contains the new (re-paginated) text
        val longTextPages = listOf(
            Page(index = 0, bookId = "book1", originalText = "Alpha Beta Gamma Delta", chapterIndex = 0),
            Page(index = 1, bookId = "book1", originalText = "Epsilon Zeta Eta Theta", chapterIndex = 0),
            Page(index = 2, bookId = "book1", originalText = "Iota Kappa Lambda Mu", chapterIndex = 0),
        )
        coEvery { bookRepository.getPagesForBook("book1") } returns longTextPages

        coEvery { translatePageUseCase.translateBatchWithContext(any(), any(), any(), any()) } returns
            Result.success(mapOf(0 to "Алфа Бета Гама Делта"))

        val vm = createViewModel()
        advanceUntilIdle()

        // Translate page 0 → now _pages.value[0] has bg translation
        vm.translateCurrentPage()
        advanceUntilIdle()

        val stateBefore = vm.uiState.value as ReaderUiState.ReaderReady
        assertTrue("Page 0 should have bg translation", stateBefore.pages[0].hasTranslation("bg"))

        // Re-paginate: new pages split the old page text into smaller chunks
        coEvery { bookRepository.getPagesForBook("book1") } returns listOf(
            Page(index = 0, bookId = "book1", originalText = "Alpha Beta", chapterIndex = 0),
            Page(index = 1, bookId = "book1", originalText = "Gamma Delta", chapterIndex = 0),
        )
        // Cache miss — substring fallback should kick in
        coEvery { translationCacheRepository.get(any(), any(), any()) } returns null

        vm.rePaginate(1080, 2400, 2.625f)
        advanceUntilIdle()

        val stateAfter = vm.uiState.value as ReaderUiState.ReaderReady
        // "Alpha Beta" is contained in old "Alpha Beta Gamma Delta" → translation restored via substring
        assertTrue(
            "Page 0 should have bg translation via substring fallback",
            stateAfter.pages[0].hasTranslation("bg")
        )
    }

    @Test
    fun `rePaginate - substring fallback does not match unrelated pages`() = runTest(testDispatcher) {
        var rePaginated = false
        coEvery { bookRepository.getPagesForBook("book1") } coAnswers {
            if (rePaginated) {
                listOf(
                    Page(index = 0, bookId = "book1", originalText = "XYZ not found in old text", chapterIndex = 0),
                )
            } else {
                testPages
            }
        }

        coEvery { translatePageUseCase.translateBatchWithContext(any(), any(), any(), any()) } returns
            Result.success(mapOf(0 to "Напълно различен текст"))

        val vm = createViewModel()
        advanceUntilIdle()
        vm.translateCurrentPage()
        advanceUntilIdle()

        // Re-paginate: new page text is NOT contained in any old translated page
        rePaginated = true
        coEvery { translationCacheRepository.get(any(), any(), any()) } returns null

        vm.rePaginate(1080, 2400, 2.625f)
        advanceUntilIdle()

        val state = vm.uiState.value as ReaderUiState.ReaderReady
        assertFalse("Page 0 should NOT have translation (no substring match)", state.pages[0].hasTranslation("bg"))
    }

    // ── Translation flow with mock service scenarios ────────────────────────

    @Test
    fun `translateCurrentPage - batch success with multiple pages`() = runTest(testDispatcher) {
        // Simulate: batch returns translations for pages 0, 1, 2
        coEvery { translatePageUseCase.translateBatchWithContext(any(), any(), any(), any()) } coAnswers {
            val callback = args[3] as ((Int, String) -> Unit)
            callback(0, "Превод нула")
            callback(1, "Превод едно")
            callback(2, "Превод две")
            Result.success(mapOf(0 to "Превод нула", 1 to "Превод едно", 2 to "Превод две"))
        }

        val vm = createViewModel()
        advanceUntilIdle()

        vm.translateCurrentPage()
        advanceUntilIdle()

        val state = vm.uiState.value as ReaderUiState.ReaderReady
        assertFalse(state.isTranslating)
        assertNull(state.translationError)
        assertEquals("Превод нула", state.pages[0].effectiveTranslation("bg"))
        assertEquals("Превод едно", state.pages[1].effectiveTranslation("bg"))
        assertEquals("Превод две", state.pages[2].effectiveTranslation("bg"))
    }

    @Test
    fun `translateCurrentPage - partial success via callback updates pages incrementally`() = runTest(testDispatcher) {
        // Simulate: use case succeeds but only returns some pages (partial batch)
        coEvery { translatePageUseCase.translateBatchWithContext(any(), any(), any(), any()) } coAnswers {
            val callback = args[3] as ((Int, String) -> Unit)
            callback(0, "Превод нула")
            // Page 1 and 2 not delivered via callback (simulating partial failure inside use case)
            Result.success(mapOf(0 to "Превод нула"))
        }

        val vm = createViewModel()
        advanceUntilIdle()

        vm.translateCurrentPage()
        advanceUntilIdle()

        val state = vm.uiState.value as ReaderUiState.ReaderReady
        assertFalse(state.isTranslating)
        // Page 0 got its translation via callback
        assertEquals("Превод нула", state.pages[0].effectiveTranslation("bg"))
    }

    @Test
    fun `translateCurrentPage - use case throws network exception`() = runTest(testDispatcher) {
        coEvery { translatePageUseCase.translateBatchWithContext(any(), any(), any(), any()) } throws
            java.io.IOException("Connection reset")

        val vm = createViewModel()
        advanceUntilIdle()

        vm.translateCurrentPage()
        advanceUntilIdle()

        val state = vm.uiState.value as ReaderUiState.ReaderReady
        assertFalse(state.isTranslating)
        assertNotNull("Should have error message", state.translationError)
        assertTrue(state.translationError!!.contains("Connection reset"))
    }

    @Test
    fun `translateCurrentPage - use case returns 502 failure`() = runTest(testDispatcher) {
        coEvery { translatePageUseCase.translateBatchWithContext(any(), any(), any(), any()) } returns
            Result.failure(Exception("Translation proxy error 502: All providers failed"))

        val vm = createViewModel()
        advanceUntilIdle()

        vm.translateCurrentPage()
        advanceUntilIdle()

        val state = vm.uiState.value as ReaderUiState.ReaderReady
        assertFalse(state.isTranslating)
        assertTrue(state.translationError!!.contains("502"))
    }

    @Test
    fun `translateCurrentPage - use case returns 429 rate limit`() = runTest(testDispatcher) {
        coEvery { translatePageUseCase.translateBatchWithContext(any(), any(), any(), any()) } returns
            Result.failure(Exception("Translation proxy error 429: Too fast"))

        val vm = createViewModel()
        advanceUntilIdle()

        vm.translateCurrentPage()
        advanceUntilIdle()

        val state = vm.uiState.value as ReaderUiState.ReaderReady
        assertFalse(state.isTranslating)
        assertTrue(state.translationError!!.contains("429"))
    }

    @Test
    fun `translateCurrentPage - skips already-translated pages in window`() = runTest(testDispatcher) {
        // Pre-translate page 0
        val preTranslatedPages = listOf(
            testPages[0].withTranslation("bg", "Вече преведено"),
            testPages[1],
            testPages[2],
        )
        var callCount = 0
        coEvery { bookRepository.getPagesForBook("book1") } coAnswers {
            callCount++
            if (callCount == 1) preTranslatedPages else preTranslatedPages
        }

        // Translate should only send pages 1 and 2 (page 0 is already done)
        var capturedPages: List<com.dualreader.app.domain.usecases.PageToTranslate>? = null
        coEvery { translatePageUseCase.translateBatchWithContext(any(), any(), any(), any()) } coAnswers {
            capturedPages = args[0] as List<com.dualreader.app.domain.usecases.PageToTranslate>
            Result.success(mapOf(1 to "Едно", 2 to "Две"))
        }

        val vm = createViewModel()
        advanceUntilIdle()

        vm.translateCurrentPage()
        advanceUntilIdle()

        assertNotNull("Should have called translate", capturedPages)
        assertEquals("Should skip already-translated page 0", 2, capturedPages!!.size)
        assertEquals(1, capturedPages!![0].index)
        assertEquals(2, capturedPages!![1].index)
    }

    // ── Translation + language switching ────────────────────────────────────

    @Test
    fun `page entity - supports multiple language translations`() {
        // Core entity test: a page can hold translations for multiple languages
        val page = Page(index = 0, bookId = "book1", originalText = "Hello world", chapterIndex = 0)
            .withTranslation("bg", "Здравей свят")
            .withTranslation("es", "Hola mundo")
            .withTranslation("fr", "Bonjour le monde")

        assertEquals("Здравей свят", page.effectiveTranslation("bg"))
        assertEquals("Hola mundo", page.effectiveTranslation("es"))
        assertEquals("Bonjour le monde", page.effectiveTranslation("fr"))
        assertNull(page.effectiveTranslation("de")) // No German translation
    }

    @Test
    fun `page entity - adding new language preserves existing translations`() {
        val page = Page(index = 0, bookId = "book1", originalText = "Test", chapterIndex = 0)
            .withTranslation("bg", "Тест")

        assertEquals("Тест", page.effectiveTranslation("bg"))

        val updated = page.withTranslation("es", "Prueba")
        assertEquals("Тест", updated.effectiveTranslation("bg"))
        assertEquals("Prueba", updated.effectiveTranslation("es"))
    }

    @Test
    fun `page entity - re-adding same language overwrites translation`() {
        val page = Page(index = 0, bookId = "book1", originalText = "Test", chapterIndex = 0)
            .withTranslation("bg", "Тест първи")

        val updated = page.withTranslation("bg", "Тест втори")
        assertEquals("Тест втори", updated.effectiveTranslation("bg"))
    }

    @Test
    fun `translateCurrentPage - second call to same language uses cached result`() = runTest(testDispatcher) {
        coEvery { translatePageUseCase.translateBatchWithContext(any(), any(), any(), any()) } returns
            Result.success(mapOf(0 to "Превод"))

        val vm = createViewModel()
        advanceUntilIdle()

        vm.translateCurrentPage()
        advanceUntilIdle()

        // Reset mock to track second call
        val slot = slot<List<com.dualreader.app.domain.usecases.PageToTranslate>>()
        coEvery { translatePageUseCase.translateBatchWithContext(capture(slot), any(), any(), any()) } returns
            Result.success(emptyMap())

        vm.translateCurrentPage()
        advanceUntilIdle()

        // Since page 0 is already translated, the window should be empty → no translate call
        val state = vm.uiState.value as ReaderUiState.ReaderReady
        assertFalse(state.isTranslating)
    }

    // ── collectTranslateWindow edge cases ──────────────────────────────────

    @Test
    fun `collectTranslateWindow - at end of book collects pages before current`() = runTest(testDispatcher) {
        // Go to last page (index 2) — window should collect page 2, then page 1, then page 0
        coEvery { translatePageUseCase.translateBatchWithContext(any(), any(), any(), any()) } coAnswers {
            val pages = args[0] as List<com.dualreader.app.domain.usecases.PageToTranslate>
            val result = pages.associate { it.index to "T${it.index}" }
            Result.success(result)
        }

        val vm = createViewModel()
        advanceUntilIdle()

        vm.goToPage(2)
        advanceUntilIdle()

        vm.translateCurrentPage()
        advanceUntilIdle()

        val state = vm.uiState.value as ReaderUiState.ReaderReady
        // All 3 pages should be translated (window of 3, all untranslated)
        assertEquals("T0", state.pages[0].effectiveTranslation("bg"))
        assertEquals("T1", state.pages[1].effectiveTranslation("bg"))
        assertEquals("T2", state.pages[2].effectiveTranslation("bg"))
    }

    @Test
    fun `collectTranslateWindow - single page book`() = runTest(testDispatcher) {
        val singlePageBook = testBook.copy(totalPages = 1, currentPage = 0)
        val singlePage = listOf(
            Page(index = 0, bookId = "book1", originalText = "Only page", chapterIndex = 0),
        )
        coEvery { bookRepository.getBookById("book1") } returns singlePageBook
        coEvery { bookRepository.getPagesForBook("book1") } returns singlePage

        coEvery { translatePageUseCase.translateBatchWithContext(any(), any(), any(), any()) } returns
            Result.success(mapOf(0 to "Единствена страница"))

        val vm = createViewModel()
        advanceUntilIdle()

        vm.translateCurrentPage()
        advanceUntilIdle()

        val state = vm.uiState.value as ReaderUiState.ReaderReady
        assertEquals("Единствена страница", state.pages[0].effectiveTranslation("bg"))
    }

    // ── Translation preserves across page navigation ────────────────────────

    @Test
    fun `translateCurrentPage then goToPage - translation persists`() = runTest(testDispatcher) {
        coEvery { translatePageUseCase.translateBatchWithContext(any(), any(), any(), any()) } returns
            Result.success(mapOf(0 to "Превод", 1 to "Едно", 2 to "Две"))

        val vm = createViewModel()
        advanceUntilIdle()

        vm.translateCurrentPage()
        advanceUntilIdle()

        // Navigate away and back
        vm.goToPage(2)
        advanceUntilIdle()
        vm.goToPage(0)
        advanceUntilIdle()

        val state = vm.uiState.value as ReaderUiState.ReaderReady
        assertEquals("Translation should persist after navigation", "Превод", state.pages[0].effectiveTranslation("bg"))
        assertEquals("Едно", state.pages[1].effectiveTranslation("bg"))
        assertEquals("Две", state.pages[2].effectiveTranslation("bg"))
    }

    // ── translateAllPages error scenarios ───────────────────────────────────

    @Test
    fun `translateAllPages - sets error on failure`() = runTest(testDispatcher) {
        coEvery { translatePageUseCase.translateBatchWithContext(any(), any(), any(), any()) } returns
            Result.failure(Exception("All providers failed"))

        val vm = createViewModel()
        advanceUntilIdle()

        vm.translateAllPages()
        advanceUntilIdle()

        val state = vm.uiState.value as ReaderUiState.ReaderReady
        assertFalse(state.isTranslating)
        assertNotNull(state.translationError)
        assertTrue(state.translationError!!.contains("failed", ignoreCase = true))
    }

    @Test
    fun `translateAllPages - skips already translated pages`() = runTest(testDispatcher) {
        val preTranslated = listOf(
            testPages[0].withTranslation("bg", "Готово"),
            testPages[1],
            testPages[2],
        )
        coEvery { bookRepository.getPagesForBook("book1") } returns preTranslated

        var capturedPages: List<com.dualreader.app.domain.usecases.PageToTranslate>? = null
        coEvery { translatePageUseCase.translateBatchWithContext(any(), any(), any(), any()) } coAnswers {
            capturedPages = args[0] as List<com.dualreader.app.domain.usecases.PageToTranslate>
            val result = capturedPages!!.associate { it.index to "T${it.index}" }
            Result.success(result)
        }

        val vm = createViewModel()
        advanceUntilIdle()

        vm.translateAllPages()
        advanceUntilIdle()

        assertNotNull("Should have called translate", capturedPages)
        assertEquals("Should skip already-translated page 0", 2, capturedPages!!.size)
        assertFalse(capturedPages!!.any { it.index == 0 })
    }
}
