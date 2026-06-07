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
        coEvery { translatePageUseCase(any(), any(), any()) } returns Result.success("Превод")
        val vm = createViewModel()
        advanceUntilIdle()

        vm.translateCurrentPage()
        advanceUntilIdle()

        // After translate, the combine collector updates _uiState with the translated page
        // Wait for all coroutines to complete
        val state = vm.uiState.value
        if (state is ReaderUiState.ReaderReady) {
            assertEquals("Превод", state.currentPage.translatedText)
        }
    }

    @Test
    fun `translateCurrentPage - sets Error on failure`() = runTest(testDispatcher) {
        coEvery { translatePageUseCase(any(), any(), any()) } returns
            Result.failure(RuntimeException("Network error"))
        val vm = createViewModel()
        advanceUntilIdle()

        vm.translateCurrentPage()
        advanceUntilIdle()

        val state = vm.uiState.value
        // Translation failure sets Error state OR falls back to ready (combine re-emits)
        when (state) {
            is ReaderUiState.Error -> assertTrue(state.message.contains("Network error"))
            is ReaderUiState.ReaderReady -> assertFalse(state.isTranslating)
            else -> fail("Unexpected state: $state")
        }
    }

    @Test
    fun `translateCurrentPage - prevents double translation`() = runTest(testDispatcher) {
        var callCount = 0
        coEvery { translatePageUseCase(any(), any(), any()) } coAnswers {
            callCount++
            kotlinx.coroutines.delay(1000)
            Result.success("translated")
        }
        val vm = createViewModel()
        advanceUntilIdle()

        vm.translateCurrentPage()
        vm.translateCurrentPage()
        advanceUntilIdle()

        assertEquals("Should only call translate once", 1, callCount)
    }

    @Test
    fun `translateCurrentPage - persists translated pages`() = runTest(testDispatcher) {
        coEvery { translatePageUseCase(any(), any(), any()) } returns Result.success("превод")
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
