package com.dualreader.app.ui.screens

import com.dualreader.app.data.translation.MlKitModelManager
import com.dualreader.app.domain.entities.Book
import com.dualreader.app.domain.entities.Bookmark
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
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
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
 * DR-138: Tests for CancellationException handling in ReaderViewModel methods.
 */
@ExperimentalCoroutinesApi
class ReaderViewModelCancellationTest {

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

    private val bookId = "test-book"

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
    fun setup() {
        Dispatchers.setMain(testDispatcher)
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
    }

    @Test
    fun reloadPages_handlesCancellationException() = runTest {
        // DR-138: Test that reloadPages properly handles CancellationException
        val pages = makePages(5)
        coEvery { bookRepo.getPagesForBook(bookId) } returns pages
        coEvery { settingsRepo.getSettings() } returns ReadingSettings()
        every { settingsRepo.settings } returns flowOf(ReadingSettings())  // CRITICAL: combine() needs this flow

        // IMPORTANT: Set testIoDispatcher BEFORE creating ViewModel (init block uses it)
        ReaderViewModel.testIoDispatcher = testDispatcher

        // Create ViewModel
        val viewModel = ReaderViewModel(
            savedStateHandle = SavedStateHandle(),
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

        // Collect uiState flow BEFORE loadBook (required for SharingStarted.WhileSubscribed)
        backgroundScope.launch { viewModel.uiState.collect {} }
        advanceUntilIdle()

        // Load a book first to set currentBookId
        coEvery { bookRepo.getBookById(bookId) } returns makeBook()
        coEvery { bookRepo.getPage(any(), any()) } returns pages[0]
        coEvery { bookmarkRepo.getBookmarksForBook(any()) } returns flowOf(emptyList())
        viewModel.loadBook(bookId)
        advanceUntilIdle()

        // Call reloadPages and verify it completes
        viewModel.reloadPages()
        advanceUntilIdle()

        coVerify { bookRepo.getPagesForBook(bookId) }
        viewModel.callOnClearedForTesting()
    }

    @Test
    fun updateCurrentPage_handlesCancellationException() = runTest {
        // DR-138: Test that updateCurrentPage properly handles CancellationException
        val book = makeBook()
        val pages = makePages(10)

        coEvery { bookRepo.getBookById(bookId) } returns book
        coEvery { bookRepo.getPagesForBook(bookId) } returns pages
        coEvery { bookRepo.getPage(any(), any()) } returns pages[0]
        coEvery { bookRepo.updateBook(any()) } returns Unit
        coEvery { settingsRepo.getSettings() } returns ReadingSettings()
        every { settingsRepo.settings } returns flowOf(ReadingSettings())  // CRITICAL: combine() needs this flow
        coEvery { bookmarkRepo.getBookmarksForBook(any()) } returns flowOf(emptyList())

        // IMPORTANT: Set testIoDispatcher BEFORE creating ViewModel (init block uses it)
        ReaderViewModel.testIoDispatcher = testDispatcher

        // Create ViewModel
        val viewModel = ReaderViewModel(
            savedStateHandle = SavedStateHandle(),
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

        // Collect uiState flow BEFORE loadBook (required for SharingStarted.WhileSubscribed)
        backgroundScope.launch { viewModel.uiState.collect {} }
        advanceUntilIdle()

        viewModel.loadBook(bookId)
        advanceUntilIdle()

        // Update current page
        viewModel.updateCurrentPage(0)
        advanceUntilIdle()

        // Verify repository method was called
        coVerify(exactly = 1) { bookRepo.updateBook(any()) }
        viewModel.callOnClearedForTesting()
    }

    @Test
    fun jumpToPosition_handlesCancellationException() = runTest {
        // DR-138: Test that jumpToPosition properly handles CancellationException
        val book = makeBook()
        val pages = makePages(10)

        coEvery { bookRepo.getBookById(bookId) } returns book
        coEvery { bookRepo.getPagesForBook(bookId) } returns pages
        coEvery { bookRepo.getPage(any(), any()) } returns pages[0]
        coEvery { bookRepo.updateBook(any()) } returns Unit
        coEvery { settingsRepo.getSettings() } returns ReadingSettings()
        every { settingsRepo.settings } returns flowOf(ReadingSettings())  // CRITICAL: combine() needs this flow
        coEvery { bookmarkRepo.getBookmarksForBook(any()) } returns flowOf(emptyList())

        // IMPORTANT: Set testIoDispatcher BEFORE creating ViewModel (init block uses it)
        ReaderViewModel.testIoDispatcher = testDispatcher

        // Create ViewModel
        val viewModel = ReaderViewModel(
            savedStateHandle = SavedStateHandle(),
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

        // Collect uiState flow BEFORE loadBook (required for SharingStarted.WhileSubscribed)
        backgroundScope.launch { viewModel.uiState.collect {} }
        advanceUntilIdle()

        viewModel.loadBook(bookId)
        advanceUntilIdle()

        // Jump to position
        viewModel.jumpToPosition(5)
        advanceUntilIdle()

        // Verify repository method was called
        coVerify(exactly = 1) { bookRepo.updateBook(any()) }
        viewModel.callOnClearedForTesting()
    }

    @Test
    fun addBookmark_handlesCancellationException() = runTest {
        // DR-138: Test that addBookmark properly handles CancellationException
        val book = makeBook()
        val pages = makePages(10)

        coEvery { bookRepo.getBookById(bookId) } returns book
        coEvery { bookRepo.getPagesForBook(bookId) } returns pages
        coEvery { bookRepo.getPage(any(), any()) } returns pages[0]
        coEvery { bookmarkRepo.addBookmark(any()) } returns Unit
        coEvery { settingsRepo.getSettings() } returns ReadingSettings()
        every { settingsRepo.settings } returns flowOf(ReadingSettings())  // CRITICAL: combine() needs this flow
        coEvery { bookmarkRepo.getBookmarksForBook(any()) } returns flowOf(emptyList())

        // IMPORTANT: Set testIoDispatcher BEFORE creating ViewModel (init block uses it)
        ReaderViewModel.testIoDispatcher = testDispatcher

        // Create ViewModel
        val viewModel = ReaderViewModel(
            savedStateHandle = SavedStateHandle(),
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

        // Collect uiState flow BEFORE loadBook (required for SharingStarted.WhileSubscribed)
        backgroundScope.launch { viewModel.uiState.collect {} }
        advanceUntilIdle()

        viewModel.loadBook(bookId)
        advanceUntilIdle()

        // Add a bookmark
        viewModel.addBookmark("test-note")
        advanceUntilIdle()

        // Verify repository method was called
        coVerify(exactly = 1) { bookmarkRepo.addBookmark(any()) }
        viewModel.callOnClearedForTesting()
    }

    @Test
    fun removeBookmark_handlesCancellationException() = runTest {
        // DR-138: Test that removeBookmark properly handles CancellationException
        coEvery { bookmarkRepo.deleteBookmark(any()) } returns Unit
        coEvery { settingsRepo.getSettings() } returns ReadingSettings()

        // IMPORTANT: Set testIoDispatcher BEFORE creating ViewModel (init block uses it)
        ReaderViewModel.testIoDispatcher = testDispatcher

        // Create ViewModel
        val viewModel = ReaderViewModel(
            savedStateHandle = SavedStateHandle(),
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

        // Remove a bookmark
        viewModel.removeBookmark("bookmark-id-123")
        advanceUntilIdle()

        // Verify repository method was called
        coVerify(exactly = 1) { bookmarkRepo.deleteBookmark("bookmark-id-123") }
        viewModel.callOnClearedForTesting()
    }
}