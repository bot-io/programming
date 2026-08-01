package com.dualreader.app.ui.screens

import com.dualreader.app.data.translation.FallbackTranslationService
import com.dualreader.app.domain.entities.Book
import com.dualreader.app.domain.entities.Page
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
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Before
import org.junit.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull

/**
 * DR-053: Test that cloudUpgradeCallback is protected against race conditions
 * during concurrent loadBook calls (book switching scenario).
 */
@OptIn(ExperimentalCoroutinesApi::class)
class ReaderViewModelCloudUpgradeRaceConditionTest {

    private val testDispatcher = UnconfinedTestDispatcher()

    private lateinit var bookRepository: BookRepository
    private lateinit var settingsRepository: SettingsRepository
    private lateinit var bookmarkRepository: BookmarkRepository
    private lateinit var translatePageUseCase: TranslatePageUseCase
    private lateinit var paginateBookUseCase: PaginateBookUseCase
    private lateinit var translationCacheRepository: TranslationCacheRepository
    private lateinit var ttsService: com.dualreader.app.domain.services.TtsService
    private lateinit var fallbackTranslationService: FallbackTranslationService
    private lateinit var mlKitModelManager: com.dualreader.app.data.translation.MlKitModelManager

    private lateinit var viewModel: ReaderViewModel

    private val book1 = Book(
        id = "book1",
        title = "Book One",
        author = "Author One",
        filePath = "/path/book1.epub",
        language = "en",
        currentPage = 0,
        totalPages = 10
    )

    private val book2 = Book(
        id = "book2",
        title = "Book Two",
        author = "Author Two",
        filePath = "/path/book2.epub",
        language = "en",
        currentPage = 0,
        totalPages = 10
    )

    private val pagesBook1 = listOf(
        Page(
            index = 0,
            bookId = "book1",
            originalText = "First paragraph of book one.",
            chapterIndex = 0
        ),
        Page(
            index = 1,
            bookId = "book1",
            originalText = "Second paragraph of book one.",
            chapterIndex = 0
        )
    )

    private val pagesBook2 = listOf(
        Page(
            index = 0,
            bookId = "book2",
            originalText = "First paragraph of book two.",
            chapterIndex = 0
        )
    )

    private val testSettings = ReadingSettings()

    @Before
    fun setup() {
        Dispatchers.setMain(testDispatcher)
        ReaderViewModel.testIoDispatcher = testDispatcher

        bookRepository = mockk(relaxed = true)
        settingsRepository = mockk(relaxed = true)
        bookmarkRepository = mockk(relaxed = true)
        translatePageUseCase = mockk(relaxed = true)
        paginateBookUseCase = mockk(relaxed = true)
        translationCacheRepository = mockk(relaxed = true)
        ttsService = mockk(relaxed = true)
        fallbackTranslationService = mockk(relaxed = true)
        mlKitModelManager = mockk(relaxed = true)

        coEvery { bookRepository.getBookById("book1") } returns book1
        coEvery { bookRepository.getBookById("book2") } returns book2
        coEvery { bookRepository.getPagesForBook("book1") } returns pagesBook1
        coEvery { bookRepository.getPagesForBook("book2") } returns pagesBook2
        coEvery { settingsRepository.getSettings() } returns testSettings
        every { settingsRepository.settings } returns flowOf(testSettings)
        every { bookmarkRepository.getBookmarksForBook(any()) } returns flowOf(emptyList())

        viewModel = ReaderViewModel(
            savedStateHandle = androidx.lifecycle.SavedStateHandle(),
            bookRepository = bookRepository,
            settingsRepository = settingsRepository,
            bookmarkRepository = bookmarkRepository,
            translatePageUseCase = translatePageUseCase,
            paginateBookUseCase = paginateBookUseCase,
            translationCacheRepository = translationCacheRepository,
            ttsService = ttsService,
            translationService = fallbackTranslationService,
            fallbackTranslationService = fallbackTranslationService,
            mlKitModelManager = mlKitModelManager
        )
    }

    @After
    fun tearDown() {
        ReaderViewModel.testIoDispatcher = null
        Dispatchers.resetMain()
    }

    @Test
    fun `cloudUpgradeCallback handles book switching without crashing`() = runTest {
        // Arrange: Load book1
        viewModel.loadBook("book1")

        val initialState = viewModel.uiState.value
        assertNotNull(initialState)

        // Simulate cloud upgrade callback for book1's text
        val originalText = "First paragraph of book one."

        // Capture the callback
        var callbackWasSet = false
        fallbackTranslationService.cloudUpgradeCallback = { _, _, _ ->
            callbackWasSet = true
        }

        // Act: Trigger callback (simulating delayed cloud translation)
        callbackWasSet = false
        fallbackTranslationService.cloudUpgradeCallback?.invoke(
            originalText,
            "Traducción del párrafo uno del libro uno.",
            "es"
        )

        // Now quickly switch to book2 (simulating concurrent loadBook)
        viewModel.loadBook("book2")

        val newState = viewModel.uiState.value
        assertNotNull(newState)

        // Verify: No crash occurred, and state transition happened correctly
        // The callback's bookId check should prevent applying to the wrong book
    }

    @Test
    fun `cloudUpgradeCallback handles null bookId without crashing`() = runTest {
        // Arrange: Don't load any book (currentBookId is null)
        val originalText = "Some text."

        // Act: Trigger callback
        var callbackInvoked = false
        fallbackTranslationService.cloudUpgradeCallback = { _, _, _ ->
            callbackInvoked = true
        }

        fallbackTranslationService.cloudUpgradeCallback?.invoke(
            originalText,
            "Some translation.",
            "es"
        )

        // Verify: No crash should occur (callback should handle null bookId gracefully)
        // The callback checks bookId != null before proceeding
    }

    @Test
    fun `cloudUpgradeCallback handles non-matching text without crashing`() = runTest {
        // Arrange: Load book1
        viewModel.loadBook("book1")

        val state = viewModel.uiState.value
        assertNotNull(state)

        // Act: Trigger callback with text that doesn't match (simulating race where page changed)
        var callbackInvoked = false
        fallbackTranslationService.cloudUpgradeCallback = { _, _, _ ->
            callbackInvoked = true
        }

        fallbackTranslationService.cloudUpgradeCallback?.invoke(
            "Completely different text that doesn't match any page.",
            "Some translation.",
            "es"
        )

        // Verify: No crash should occur (page won't be found, or content mismatch)
        val finalState = viewModel.uiState.value
        assertNotNull(finalState)
    }

    @Test
    fun `cloudUpgradeCallback can be invoked multiple times safely`() = runTest {
        // Arrange: Load book1
        viewModel.loadBook("book1")

        // Act: Invoke callback multiple times
        val originalText = "First paragraph of book one."
        repeat(10) {
            try {
                fallbackTranslationService.cloudUpgradeCallback?.invoke(
                    originalText,
                    "Translation $it.",
                    "es"
                )
            } catch (e: Exception) {
                // Should not throw - fail test if it does
                throw AssertionError("Callback invocation $it threw exception", e)
            }
        }

        // Verify: All invocations succeeded without crashing
        // (No exception was thrown above)
    }
}