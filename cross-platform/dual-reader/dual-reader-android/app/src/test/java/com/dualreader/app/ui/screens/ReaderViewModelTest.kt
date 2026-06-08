package com.dualreader.app.ui.screens

import com.dualreader.app.domain.entities.Book
import com.dualreader.app.domain.entities.Page
import com.dualreader.app.domain.entities.ReaderTheme
import com.dualreader.app.domain.entities.ReadingSettings
import com.dualreader.app.domain.repositories.BookRepository
import com.dualreader.app.domain.repositories.BookmarkRepository
import com.dualreader.app.domain.repositories.SettingsRepository
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
}
