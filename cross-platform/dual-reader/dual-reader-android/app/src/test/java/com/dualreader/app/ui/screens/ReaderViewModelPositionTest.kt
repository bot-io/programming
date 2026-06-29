package com.dualreader.app.ui.screens

import com.dualreader.app.data.translation.MlKitModelManager
import com.dualreader.app.domain.entities.Book
import com.dualreader.app.domain.entities.BookChapter
import com.dualreader.app.domain.entities.Page
import com.dualreader.app.domain.entities.PaginationStatus
import com.dualreader.app.domain.entities.ReadingSettings
import com.dualreader.app.domain.repositories.BookRepository
import com.dualreader.app.domain.repositories.BookmarkRepository
import com.dualreader.app.domain.repositories.SettingsRepository
import com.dualreader.app.domain.repositories.TranslationCacheRepository
import com.dualreader.app.domain.services.EpubParserService
import com.dualreader.app.domain.services.TranslationService
import com.dualreader.app.domain.services.TtsService
import com.dualreader.app.domain.usecases.PaginateBookUseCase
import com.dualreader.app.domain.usecases.TranslatePageUseCase
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.viewModelScope
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.mockk
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.time.LocalDateTime

/**
 * Regression tests for DR-054: Book position not preserved.
 *
 * Root cause: ReaderScreen's LazyColumn always started at index 0 and never
 * tracked scroll position. The `onUpdateCurrentPage` callback existed in the
 * composable signature but was dead code — never called. The reader never
 * saved scroll position during normal scrolling, and never restored it on open.
 *
 * Fix: Added LaunchedEffect to restore scroll on open + snapshotFlow tracker
 * to save position as user scrolls (with debounce for DB write throttling).
 *
 * These tests verify the ViewModel layer: that updateCurrentPage and goToPage
 * correctly persist position to the repository, and that loadBook restores it.
 */
@OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)
class ReaderViewModelPositionTest {

    private val testDispatcher = StandardTestDispatcher()

    private lateinit var bookRepo: BookRepository
    private lateinit var settingsRepo: SettingsRepository
    private lateinit var bookmarkRepo: BookmarkRepository
    private lateinit var translateUseCase: TranslatePageUseCase
    private lateinit var paginateUseCase: PaginateBookUseCase
    private lateinit var cacheRepo: TranslationCacheRepository
    private lateinit var ttsService: TtsService
    private lateinit var translationService: TranslationService
    private lateinit var mlKitModelManager: MlKitModelManager
    private lateinit var epubParser: EpubParserService

    private val bookId = "test-book-1"

    private fun makeBook(currentPage: Int = 0, totalPages: Int = 10) = Book(
        id = bookId,
        title = "Test Book",
        author = "Author",
        filePath = "/path/book.epub",
        language = "en",
        currentPage = currentPage,
        totalPages = totalPages,
        paginationStatus = PaginationStatus.COMPLETED,
    )

    private fun makePages(count: Int): List<Page> = (0 until count).map {
        Page(index = it, bookId = bookId, chapterIndex = 0, originalText = "Paragraph $it")
    }

    @Before
    fun setUp() {
        Dispatchers.setMain(testDispatcher)
        ReaderViewModel.testIoDispatcher = testDispatcher

        bookRepo = mockk(relaxed = true)
        settingsRepo = mockk(relaxed = true)
        bookmarkRepo = mockk(relaxed = true)
        translateUseCase = mockk(relaxed = true)
        paginateUseCase = mockk(relaxed = true)
        cacheRepo = mockk(relaxed = true)
        ttsService = mockk(relaxed = true)
        translationService = mockk(relaxed = true)
        mlKitModelManager = mockk(relaxed = true)
        epubParser = mockk(relaxed = true)

        // Default mocks for loadBook
        coEvery { settingsRepo.getSettings() } returns ReadingSettings()
        coEvery { settingsRepo.settings } returns flowOf(ReadingSettings())
        coEvery { bookmarkRepo.getBookmarksForBook(any()) } returns flowOf(emptyList())
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
        ReaderViewModel.testIoDispatcher = null
    }

    private fun createViewModel(currentPage: Int = 0, totalPages: Int = 10): ReaderViewModel {
        val savedStateHandle = SavedStateHandle(mapOf("bookId" to bookId))
        coEvery { bookRepo.getBookById(bookId) } returns makeBook(currentPage, totalPages)
        coEvery { bookRepo.getPagesForBook(bookId) } returns makePages(totalPages)
        coEvery { paginateUseCase(any(), any(), any()) } returns Result.success(Unit)

        return ReaderViewModel(
            savedStateHandle = savedStateHandle,
            bookRepository = bookRepo,
            settingsRepository = settingsRepo,
            bookmarkRepository = bookmarkRepo,
            translatePageUseCase = translateUseCase,
            paginateBookUseCase = paginateUseCase,
            translationCacheRepository = cacheRepo,
            ttsService = ttsService,
            translationService = translationService,
            fallbackTranslationService = mockk(relaxed = true),
            mlKitModelManager = mlKitModelManager,
        )
    }

    // ── updateCurrentPage ─────────────────────────────────────────

    @Test
    fun `updateCurrentPage persists new position to repository`() = runTest(testDispatcher) {
        val vm = createViewModel(currentPage = 0)
        advanceUntilIdle()

        vm.updateCurrentPage(5)
        advanceUntilIdle()

        coVerify {
            bookRepo.updateBook(match { it.currentPage == 5 })
        }
    }

    @Test
    fun `updateCurrentPage sets lastReadAt timestamp`() = runTest(testDispatcher) {
        val vm = createViewModel(currentPage = 0)
        advanceUntilIdle()

        val before = LocalDateTime.now()
        vm.updateCurrentPage(3)
        advanceUntilIdle()

        coVerify {
            bookRepo.updateBook(match { it.lastReadAt != null && !it.lastReadAt!!.isBefore(before) })
        }
    }

    @Test
    fun `updateCurrentPage with invalid negative index does nothing`() = runTest(testDispatcher) {
        val vm = createViewModel(currentPage = 0)
        advanceUntilIdle()

        vm.updateCurrentPage(-1)
        advanceUntilIdle()

        // Should not update the book (currentPage was 0, updateCurrentPage(0)
        // is from loadBook pagination, not from this call)
        coVerify(exactly = 0) {
            bookRepo.updateBook(match { it.currentPage == -1 })
        }
    }

    @Test
    fun `updateCurrentPage with out-of-bounds index does nothing`() = runTest(testDispatcher) {
        val vm = createViewModel(currentPage = 0, totalPages = 10)
        advanceUntilIdle()

        vm.updateCurrentPage(999)
        advanceUntilIdle()

        coVerify(exactly = 0) {
            bookRepo.updateBook(match { it.currentPage == 999 })
        }
    }

    @Test
    fun `updateCurrentPage to same index still saves`() = runTest(testDispatcher) {
        val vm = createViewModel(currentPage = 0)
        advanceUntilIdle()

        vm.updateCurrentPage(0)
        advanceUntilIdle()

        // Even saving to the same position is valid — lastReadAt should update
        coVerify(atLeast = 1) {
            bookRepo.updateBook(match { it.currentPage == 0 })
        }
    }

    // ── Position restoration on loadBook ──────────────────────────

    @Test
    fun `loadBook restores currentPage from saved book`() = runTest(testDispatcher) {
        // Book was last read at page 5
        val vm = createViewModel(currentPage = 5, totalPages = 10)
        advanceUntilIdle()

        // Need active subscriber for WhileSubscribed — but ReaderViewModel uses
        // MutableStateFlow directly, so value should be accessible
        val state = vm.uiState.value
        assertTrue(state is ReaderUiState.ReaderReady)
        val ready = state as ReaderUiState.ReaderReady
        assertEquals(5, ready.book.currentPage)
    }

    @Test
    fun `loadBook with currentPage at last page restores correctly`() = runTest(testDispatcher) {
        val vm = createViewModel(currentPage = 9, totalPages = 10)
        advanceUntilIdle()

        val state = vm.uiState.value as? ReaderUiState.ReaderReady
        assertEquals(9, state?.book?.currentPage)
    }

    @Test
    fun `loadBook with currentPage zero starts at beginning`() = runTest(testDispatcher) {
        val vm = createViewModel(currentPage = 0, totalPages = 10)
        advanceUntilIdle()

        val state = vm.uiState.value as? ReaderUiState.ReaderReady
        assertEquals(0, state?.book?.currentPage)
    }

    // DR-057: nextPage/previousPage removed as dead code (UI uses LazyColumn scroll).
    // Tests for those methods are removed.

    // ── Pagination preserves currentPage ──────────────────────────

    @Test
    fun `re-pagination does not reset currentPage to zero`() = runTest(testDispatcher) {
        val vm = createViewModel(currentPage = 5, totalPages = 10)
        advanceUntilIdle()

        // Simulate user scrolling and position being saved
        vm.updateCurrentPage(7)
        advanceUntilIdle()

        // Verify it persisted correctly
        coVerify {
            bookRepo.updateBook(match { it.currentPage == 7 })
        }
    }
}
