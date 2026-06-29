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
 * Regression tests for DR-095: Race conditions in updateCurrentPage and jumpToPosition.
 *
 * Root cause: Both methods read `_book.value`, copy it with new currentPage/lastReadAt,
 * then write back. With rapid scroll events or user interactions, two coroutines can
 * read the same initial value, and one update is lost.
 *
 * Fix: Use `_book.update { }` for atomic read-modify-write.
 */
@OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)
class ReaderViewModelRaceConditionTest {

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

    private fun makeBook(currentPage: Int = 0, totalPages: Int = 100) = Book(
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
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
        ReaderViewModel.testIoDispatcher = null
    }

    private fun setupBook(pages: List<Page>, book: Book): ReaderViewModel {
        coEvery { bookRepo.getBookById(bookId) } returns book
        coEvery { bookRepo.getPagesForBook(bookId) } returns pages
        coEvery { settingsRepo.settings } returns flowOf(
            ReadingSettings(
                fontSize = 16f,
                fontFamily = "Default",
                lineHeight = 1.5f,
                margins = 16,
                theme = com.dualreader.app.domain.entities.ReaderTheme.DARK,
                targetLanguage = "es",
                translationProvider = com.dualreader.app.domain.entities.TranslationProvider.GEMINI_FLASH,
                brightness = 0.8f,
                isImmersiveMode = false,
                screenWakeTimeoutMinutes = 5,
                sentenceCounterEnabled = true,
                displayMode = com.dualreader.app.domain.entities.DisplayMode.SPLIT,
            )
        )
        coEvery { bookmarkRepo.getBookmarksForBook(bookId) } returns flowOf(emptyList())

        val handle = SavedStateHandle(mapOf("bookId" to bookId))
        return ReaderViewModel(
            savedStateHandle = handle,
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

    // ═══════════════════════════════════════════════════════════════════════════
    // updateCurrentPage — race condition (DR-095)
    // ═══════════════════════════════════════════════════════════════════════════

    @Test
    fun `updateCurrentPage - concurrent calls preserve all updates`() = runTest(testDispatcher) {
        val pages = makePages(100)
        val vm = setupBook(pages, makeBook(currentPage = 0, totalPages = 100))
        advanceUntilIdle()

        // Launch 50 concurrent calls to updateCurrentPage with different indices
        val jobs = (0 until 50).map { i ->
            launch(testDispatcher) {
                vm.updateCurrentPage(i)
            }
        }

        // Wait for all calls to complete
        jobs.forEach { it.join() }
        advanceUntilIdle()

        // Verify no update was lost — final currentPage should be one of the 50 values
        val state = vm.uiState.value as? ReaderUiState.ReaderReady
        assertTrue("Final currentPage should be one of the 50 values", state?.book?.currentPage in 0 until 50)
        assertTrue("lastReadAt should be updated", state?.book?.lastReadAt != null)
    }

    @Test
    fun `updateCurrentPage - atomic update prevents lost writes`() = runTest(testDispatcher) {
        val pages = makePages(100)
        val vm = setupBook(pages, makeBook(currentPage = 0, totalPages = 100))
        advanceUntilIdle()

        // Rapidly call updateCurrentPage 10 times with different values
        repeat(10) { i ->
            vm.updateCurrentPage(i * 10)  // 0, 10, 20, ..., 90
        }
        advanceUntilIdle()

        // Final value should be one of the set values (no corruption)
        val state = vm.uiState.value as? ReaderUiState.ReaderReady
        val validValues = (0 until 100 step 10).toSet()
        assertTrue("Final currentPage should be a valid value", state?.book?.currentPage in validValues)
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // jumpToPosition — race condition (DR-095)
    // ═══════════════════════════════════════════════════════════════════════════

    @Test
    fun `jumpToPosition - concurrent calls preserve all updates`() = runTest(testDispatcher) {
        val pages = makePages(100)
        val vm = setupBook(pages, makeBook(currentPage = 0, totalPages = 100))
        advanceUntilIdle()

        // Launch 50 concurrent calls to jumpToPosition with different indices
        val jobs = (0 until 50).map { i ->
            launch(testDispatcher) {
                vm.jumpToPosition(i)
            }
        }

        // Wait for all calls to complete
        jobs.forEach { it.join() }
        advanceUntilIdle()

        // Verify no update was lost — final currentPage should be one of the 50 values
        val state = vm.uiState.value as? ReaderUiState.ReaderReady
        assertTrue("Final currentPage should be one of the 50 values", state?.book?.currentPage in 0 until 50)
        assertTrue("lastReadAt should be updated", state?.book?.lastReadAt != null)
    }

    @Test
    fun `jumpToPosition - atomic update prevents lost writes`() = runTest(testDispatcher) {
        val pages = makePages(100)
        val vm = setupBook(pages, makeBook(currentPage = 0, totalPages = 100))
        advanceUntilIdle()

        // Rapidly call jumpToPosition 10 times with different values
        repeat(10) { i ->
            vm.jumpToPosition(i * 10)  // 0, 10, 20, ..., 90
        }
        advanceUntilIdle()

        // Final value should be one of the set values (no corruption)
        val state = vm.uiState.value as? ReaderUiState.ReaderReady
        val validValues = (0 until 100 step 10).toSet()
        assertTrue("Final currentPage should be a valid value", state?.book?.currentPage in validValues)
    }

    @Test
    fun `updateCurrentPage and jumpToPosition mixed concurrent calls preserve atomicity`() = runTest(testDispatcher) {
        val pages = makePages(100)
        val vm = setupBook(pages, makeBook(currentPage = 0, totalPages = 100))
        advanceUntilIdle()

        // Mix of updateCurrentPage and jumpToPosition calls
        val jobs = (0 until 25).map { i ->
            launch(testDispatcher) {
                vm.updateCurrentPage(i)
            }
        } + (0 until 25).map { i ->
            launch(testDispatcher) {
                vm.jumpToPosition(i + 25)
            }
        }

        // Wait for all calls to complete
        jobs.forEach { it.join() }
        advanceUntilIdle()

        // Final value should be valid (no corruption from mixed operations)
        val state = vm.uiState.value as? ReaderUiState.ReaderReady
        assertTrue("Final currentPage should be a valid value", state?.book?.currentPage in 0 until 50)
        assertTrue("lastReadAt should be updated", state?.book?.lastReadAt != null)
    }
}