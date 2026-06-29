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

/**
 * Tests for ReaderViewModel auto-pagination fallback.
 *
 * Regression test: when a book has no pages (e.g. imported by an older version
 * of PreInstalledBooksInitializer that didn't paginate), opening it should
 * auto-paginate instead of showing "No pages found".
 */
@OptIn(ExperimentalCoroutinesApi::class)
class ReaderViewModelAutoPaginateTest {

    private val testDispatcher = UnconfinedTestDispatcher()

    private lateinit var bookRepository: BookRepository
    private lateinit var settingsRepository: SettingsRepository
    private lateinit var bookmarkRepository: BookmarkRepository
    private lateinit var translatePageUseCase: TranslatePageUseCase
    private lateinit var paginateBookUseCase: PaginateBookUseCase
    private lateinit var translationCacheRepository: TranslationCacheRepository
    private lateinit var ttsService: com.dualreader.app.domain.services.TtsService

    private val unpagedBook = Book(
        id = "book-nopages", title = "Unpaged Book", author = "Author",
        filePath = "/test.epub", language = "en", totalPages = 0, currentPage = 0,
    )

    private val generatedPages = listOf(
        Page(index = 0, bookId = "book-nopages", originalText = "Generated page 0", chapterIndex = 0),
        Page(index = 1, bookId = "book-nopages", originalText = "Generated page 1", chapterIndex = 0),
        Page(index = 2, bookId = "book-nopages", originalText = "Generated page 2", chapterIndex = 0),
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

        // Book exists but has NO pages initially
        coEvery { bookRepository.getBookById("book-nopages") } returns unpagedBook
        coEvery { bookRepository.getPagesForBook("book-nopages") } returns emptyList()
        coEvery { bookRepository.getPage("book-nopages", any()) } returns null
        coEvery { settingsRepository.getSettings() } returns testSettings
        every { settingsRepository.settings } returns flowOf(testSettings)
        every { bookmarkRepository.getBookmarksForBook("book-nopages") } returns flowOf(emptyList())
    }

    private fun createViewModel(bookId: String = "book-nopages"): ReaderViewModel {
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
            fallbackTranslationService = mockk(relaxed = true),
            mlKitModelManager = mockk(relaxed = true),
        )
    }

    @Test
    fun `book with no pages triggers auto-pagination`() = runTest {
        // Given: pagination succeeds and returns pages
        coEvery {
            paginateBookUseCase(any(), any(), any())
        } returns Result.success(Unit)
        // Second call to getPagesForBook returns the generated pages
        coEvery {
            bookRepository.getPagesForBook("book-nopages")
        } returns emptyList() andThen generatedPages

        // When
        createViewModel()

        // Then: paginateBookUseCase was called
        coVerify { paginateBookUseCase(any(), any(), any()) }
    }

    @Test
    fun `auto-pagination success shows content instead of error`() = runTest {
        // Given
        coEvery { paginateBookUseCase(any(), any(), any()) } returns Result.success(Unit)
        coEvery { bookRepository.getPagesForBook("book-nopages") } returns emptyList() andThen generatedPages

        // When
        val vm = createViewModel()

        // Then: should not be in Error state
        assertFalse("Should not show error after auto-pagination", vm.uiState.value is ReaderUiState.Error)
    }

    @Test
    fun `auto-pagination failure shows error`() = runTest {
        // Given: pagination fails
        coEvery {
            paginateBookUseCase(any(), any(), any())
        } returns Result.failure(RuntimeException("Pagination failed"))
        coEvery { bookRepository.getPagesForBook("book-nopages") } returns emptyList()

        // When
        val vm = createViewModel()

        // Then: should show error
        // Give coroutines time to settle
        advanceTimeBy(100)
        val state = vm.uiState.value
        assertTrue("Should show error when pagination fails. State: $state", state is ReaderUiState.Error)
    }

    @Test
    fun `book with existing pages does not trigger auto-pagination`() = runTest {
        // Given: book HAS pages
        coEvery { bookRepository.getBookById("book-haspages") } returns unpagedBook.copy(id = "book-haspages", totalPages = 2)
        coEvery { bookRepository.getPagesForBook("book-haspages") } returns generatedPages.take(2)
        coEvery { bookRepository.getPage("book-haspages", any()) } returns generatedPages[0]

        // When
        createViewModel("book-haspages")

        // Then: loadBook calls paginateBookUseCase once for re-extraction, not for auto-pagination
        coVerify(exactly = 1) { paginateBookUseCase(any(), any(), any()) }
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
        ReaderViewModel.testIoDispatcher = null
    }
}
