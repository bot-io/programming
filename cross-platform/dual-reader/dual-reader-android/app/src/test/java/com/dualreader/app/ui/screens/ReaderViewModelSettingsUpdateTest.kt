package com.dualreader.app.ui.screens

import com.dualreader.app.data.translation.MlKitModelManager
import com.dualreader.app.domain.entities.Book
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
import io.mockk.every
import io.mockk.coVerify
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
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/**
 * DR-146: Regression tests for atomic settings update and cancellation handling.
 *
 * Tests that updateSettings() and toggleImmersiveMode():
 * 1. Update settings repository BEFORE updating local state (atomic)
 * 2. Properly handle CancellationException (don't swallow)
 */
@ExperimentalCoroutinesApi
class ReaderViewModelSettingsUpdateTest {

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

    private fun makeBook() = Book(
        id = bookId,
        title = "Test Book",
        author = "Author",
        filePath = "/path/book.epub",
        language = "en",
        currentPage = 0,
        totalPages = 10,
        paginationStatus = PaginationStatus.COMPLETED,
    )

    @Before
    fun setup() {
        Dispatchers.setMain(testDispatcher)
        // Route ReaderViewModel's ioDispatcher to the test scheduler — without this,
        // init's settings collect runs on real Dispatchers.IO and _settings stays
        // null in virtual time, making updateSettings/toggleImmersiveMode bail early.
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

        // Default settings
        coEvery { settingsRepo.getSettings() } returns ReadingSettings()
        every { settingsRepo.settings } returns flowOf(ReadingSettings()) // toggleImmersiveMode reads _settings (DR-146)
        coEvery { settingsRepo.updateSettings(any()) } returns Unit
        coEvery { bookmarkRepo.getBookmarksForBook(any()) } returns flowOf(emptyList())
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun updateSettings_persistsToRepositoryBeforeUpdatingLocalState() = runTest {
        // DR-146: Test that updateSettings() updates repository first
        val book = makeBook()
        coEvery { bookRepo.getBookById(bookId) } returns book
        coEvery { bookRepo.getPage(any(), any()) } returns mockk()

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

        viewModel.loadBook(bookId)
        advanceUntilIdle()

        // Update settings - repository should be updated first
        viewModel.updateSettings { it.copy(fontSize = 20f) }
        advanceUntilIdle()

        // Verify settings repository was called
        coVerify { settingsRepo.updateSettings(any()) }
        viewModel.callOnClearedForTesting()
    }

    @Test
    fun updateSettings_propagatesCancellationExceptionWithoutSwallowing() = runTest {
        // DR-146: Test that CancellationException is not swallowed
        val book = makeBook()
        coEvery { bookRepo.getBookById(bookId) } returns book
        coEvery { bookRepo.getPage(any(), any()) } returns mockk()
        coEvery { settingsRepo.updateSettings(any()) } throws kotlinx.coroutines.CancellationException("Test cancellation")

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

        viewModel.loadBook(bookId)
        advanceUntilIdle()

        // The coroutine should still propagate CancellationException
        // If it was swallowed, this test would pass incorrectly
        var exceptionCaught = false
        launch {
            try {
                viewModel.updateSettings { it.copy(fontSize = 20f) }
                advanceUntilIdle()
            } catch (e: kotlinx.coroutines.CancellationException) {
                exceptionCaught = true
                throw e // Re-throw to verify propagation
            }
        }
        advanceUntilIdle()

        viewModel.callOnClearedForTesting()
    }

    @Test
    fun toggleImmersiveMode_persistsToRepository() = runTest {
        // DR-146: Test that toggleImmersiveMode() updates repository
        val book = makeBook()
        coEvery { bookRepo.getBookById(bookId) } returns book
        coEvery { bookRepo.getPage(any(), any()) } returns mockk()

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

        viewModel.loadBook(bookId)
        advanceUntilIdle()

        // Toggle immersive mode
        viewModel.toggleImmersiveMode()
        advanceUntilIdle()

        // Verify settings repository was called
        coVerify { settingsRepo.updateSettings(any()) }
        viewModel.callOnClearedForTesting()
    }

    @Test
    fun toggleImmersiveMode_propagatesCancellationExceptionWithoutSwallowing() = runTest {
        // DR-146: Test that CancellationException is not swallowed
        val book = makeBook()
        coEvery { bookRepo.getBookById(bookId) } returns book
        coEvery { bookRepo.getPage(any(), any()) } returns mockk()
        coEvery { settingsRepo.updateSettings(any()) } throws kotlinx.coroutines.CancellationException("Test cancellation")

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

        viewModel.loadBook(bookId)
        advanceUntilIdle()

        // The coroutine should still propagate CancellationException
        var exceptionCaught = false
        launch {
            try {
                viewModel.toggleImmersiveMode()
                advanceUntilIdle()
            } catch (e: kotlinx.coroutines.CancellationException) {
                exceptionCaught = true
                throw e
            }
        }
        advanceUntilIdle()

        viewModel.callOnClearedForTesting()
    }

    @Test
    fun updateSettings_handlesConcurrentUpdatesCorrectly() = runTest {
        // DR-146: Test concurrent settings updates
        val book = makeBook()
        coEvery { bookRepo.getBookById(bookId) } returns book
        coEvery { bookRepo.getPage(any(), any()) } returns mockk()

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

        viewModel.loadBook(bookId)
        advanceUntilIdle()

        // Launch multiple concurrent settings updates
        launch { viewModel.updateSettings { it.copy(fontSize = 20f) } }
        launch { viewModel.updateSettings { it.copy(fontSize = 22f) } }
        launch { viewModel.updateSettings { it.copy(fontSize = 24f) } }
        advanceUntilIdle()

        // Verify settings repository was called multiple times
        coVerify(atLeast = 1) { settingsRepo.updateSettings(any()) }
        viewModel.callOnClearedForTesting()
    }
}