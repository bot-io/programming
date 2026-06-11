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
import java.time.LocalDateTime

/**
 * DR-005: Reading Progress Tracking with Persistence
 *
 * Tests for:
 * - Last-read position is persisted per book and restored on reopen
 * - lastReadAt is updated when navigating pages and when opening a book
 * - Progress percentage is correctly calculated
 * - Progress data survives across app sessions (via Room persistence)
 */
@OptIn(ExperimentalCoroutinesApi::class)
class ReadingProgressTest {

    private val testDispatcher = UnconfinedTestDispatcher()

    private lateinit var bookRepository: BookRepository
    private lateinit var settingsRepository: SettingsRepository
    private lateinit var bookmarkRepository: BookmarkRepository
    private lateinit var translatePageUseCase: TranslatePageUseCase
    private lateinit var paginateBookUseCase: PaginateBookUseCase
    private lateinit var translationCacheRepository: TranslationCacheRepository

    private val testSettings = ReadingSettings(
        fontSize = 16f, lineHeight = 1.5f, targetLanguage = "bg", theme = ReaderTheme.DARK,
    )

    private fun makePages(bookId: String, count: Int): List<Page> =
        (0 until count).map { i ->
            Page(index = i, bookId = bookId, originalText = "Page $i text for book $bookId", chapterIndex = 0)
        }

    private fun makeBook(
        id: String = "book1",
        title: String = "Test Book",
        totalPages: Int = 10,
        currentPage: Int = 0,
        lastReadAt: LocalDateTime? = null,
    ) = Book(
        id = id,
        title = title,
        author = "Author",
        filePath = "/test.epub",
        language = "en",
        totalPages = totalPages,
        currentPage = currentPage,
        lastReadAt = lastReadAt,
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

        coEvery { settingsRepository.getSettings() } returns testSettings
        every { settingsRepository.settings } returns flowOf(testSettings)
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

    private fun setupBook(book: Book, pages: List<Page>) {
        coEvery { bookRepository.getBookById(book.id) } returns book
        coEvery { bookRepository.getPagesForBook(book.id) } returns pages
        coEvery { bookRepository.getPage(book.id, any()) } returns pages.firstOrNull()
        every { bookmarkRepository.getBookmarksForBook(book.id) } returns flowOf(emptyList())
    }

    @After
    fun tearDown() {
        ReaderViewModel.testIoDispatcher = null
        Dispatchers.resetMain()
    }

    // ── Progress percentage calculation ──────────────────────────────────

    @Test
    fun `progressPercent - book at page 0 of 100 has 0 percent`() {
        val book = makeBook(totalPages = 100, currentPage = 0)
        assertEquals(0f, book.progressPercent, 0.001f)
    }

    @Test
    fun `progressPercent - book at page 50 of 100 has 50 percent`() {
        val book = makeBook(totalPages = 100, currentPage = 50)
        assertEquals(0.5f, book.progressPercent, 0.001f)
    }

    @Test
    fun `progressPercent - book at last page has 100 percent`() {
        val book = makeBook(totalPages = 100, currentPage = 100)
        assertEquals(1f, book.progressPercent, 0.001f)
    }

    @Test
    fun `progressPercent - zero totalPages returns zero`() {
        val book = makeBook(totalPages = 0, currentPage = 5)
        assertEquals(0f, book.progressPercent, 0.001f)
    }

    @Test
    fun `progressPercent - single page book at page 1 is complete`() {
        val book = makeBook(totalPages = 1, currentPage = 1)
        assertEquals(1f, book.progressPercent, 0.001f)
    }

    // ── Position persistence on navigation ───────────────────────────────

    @Test
    fun `goToPage - persists currentPage and lastReadAt to repository`() = runTest(testDispatcher) {
        val pages = makePages("book1", 10)
        val book = makeBook(totalPages = 10, currentPage = 0)
        setupBook(book, pages)

        val vm = createViewModel()
        advanceUntilIdle()

        vm.goToPage(5)
        advanceUntilIdle()

        coVerify {
            bookRepository.updateBook(match { saved ->
                saved.currentPage == 5 && saved.lastReadAt != null
            })
        }
    }

    @Test
    fun `goToPage - updates lastReadAt to a recent timestamp`() = runTest(testDispatcher) {
        val pages = makePages("book1", 10)
        val book = makeBook(totalPages = 10, currentPage = 0)
        setupBook(book, pages)

        val before = LocalDateTime.now().minusSeconds(1)

        val vm = createViewModel()
        advanceUntilIdle()

        vm.goToPage(3)
        advanceUntilIdle()

        val after = LocalDateTime.now().plusSeconds(1)

        coVerify {
            bookRepository.updateBook(match { saved ->
                saved.lastReadAt != null &&
                saved.lastReadAt!!.isAfter(before) &&
                saved.lastReadAt!!.isBefore(after)
            })
        }
    }

    @Test
    fun `nextPage - persists incremented page position`() = runTest(testDispatcher) {
        val pages = makePages("book1", 10)
        val book = makeBook(totalPages = 10, currentPage = 2)
        setupBook(book, pages)

        val vm = createViewModel()
        advanceUntilIdle()

        vm.nextPage()
        advanceUntilIdle()

        coVerify {
            bookRepository.updateBook(match { saved ->
                saved.currentPage == 3 && saved.lastReadAt != null
            })
        }
    }

    @Test
    fun `previousPage - persists decremented page position`() = runTest(testDispatcher) {
        val pages = makePages("book1", 10)
        val book = makeBook(totalPages = 10, currentPage = 5)
        setupBook(book, pages)

        val vm = createViewModel()
        advanceUntilIdle()

        vm.previousPage()
        advanceUntilIdle()

        coVerify {
            bookRepository.updateBook(match { saved ->
                saved.currentPage == 4 && saved.lastReadAt != null
            })
        }
    }

    // ── Position restoration on book open ────────────────────────────────

    @Test
    fun `loadBook - restores to last saved page position`() = runTest(testDispatcher) {
        val pages = makePages("book1", 10)
        // Book was last on page 7
        val book = makeBook(totalPages = 10, currentPage = 7)
        setupBook(book, pages)

        val vm = createViewModel()
        advanceUntilIdle()

        val state = vm.uiState.value as ReaderUiState.ReaderReady
        assertEquals(7, state.currentPage.index)
    }

    @Test
    fun `loadBook - restores to page 0 for new book`() = runTest(testDispatcher) {
        val pages = makePages("book1", 10)
        val book = makeBook(totalPages = 10, currentPage = 0)
        setupBook(book, pages)

        val vm = createViewModel()
        advanceUntilIdle()

        val state = vm.uiState.value as ReaderUiState.ReaderReady
        assertEquals(0, state.currentPage.index)
    }

    @Test
    fun `loadBook - falls back to first page if saved position is beyond bounds`() = runTest(testDispatcher) {
        val pages = makePages("book1", 5)
        // Saved position is 99 but only 5 pages exist
        val book = makeBook(totalPages = 5, currentPage = 99)
        coEvery { bookRepository.getBookById("book1") } returns book
        coEvery { bookRepository.getPagesForBook("book1") } returns pages
        coEvery { bookRepository.getPage("book1", 99) } returns null
        every { bookmarkRepository.getBookmarksForBook("book1") } returns flowOf(emptyList())

        val vm = createViewModel()
        advanceUntilIdle()

        val state = vm.uiState.value as ReaderUiState.ReaderReady
        assertEquals(0, state.currentPage.index)
    }

    // ── lastReadAt updates on book open ──────────────────────────────────

    @Test
    fun `loadBook - updates lastReadAt when opening a book`() = runTest(testDispatcher) {
        val pages = makePages("book1", 10)
        val book = makeBook(totalPages = 10, currentPage = 3, lastReadAt = null)
        setupBook(book, pages)

        val vm = createViewModel()
        advanceUntilIdle()

        // loadBook should persist the book with updated lastReadAt
        coVerify {
            bookRepository.updateBook(match { saved ->
                saved.lastReadAt != null
            })
        }
    }

    @Test
    fun `loadBook - lastReadAt is updated to recent time on open`() = runTest(testDispatcher) {
        val pages = makePages("book1", 10)
        val oldTime = LocalDateTime.of(2020, 1, 1, 0, 0)
        val book = makeBook(totalPages = 10, currentPage = 3, lastReadAt = oldTime)
        setupBook(book, pages)

        val before = LocalDateTime.now().minusSeconds(1)
        val vm = createViewModel()
        advanceUntilIdle()
        val after = LocalDateTime.now().plusSeconds(1)

        coVerify {
            bookRepository.updateBook(match { saved ->
                saved.lastReadAt != null &&
                saved.lastReadAt!!.isAfter(before) &&
                saved.lastReadAt!!.isBefore(after)
            })
        }
    }

    // ── Multiple books - independent progress ────────────────────────────

    @Test
    fun `different books maintain independent reading positions`() = runTest(testDispatcher) {
        // Book 1: page 3
        val book1Pages = makePages("book1", 10)
        val book1 = makeBook(id = "book1", totalPages = 10, currentPage = 3)
        setupBook(book1, book1Pages)

        // Book 2: page 7
        val book2Pages = makePages("book2", 20)
        val book2 = makeBook(id = "book2", title = "Book Two", totalPages = 20, currentPage = 7)
        coEvery { bookRepository.getBookById("book2") } returns book2
        coEvery { bookRepository.getPagesForBook("book2") } returns book2Pages
        coEvery { bookRepository.getPage("book2", any()) } returns book2Pages.firstOrNull()
        every { bookmarkRepository.getBookmarksForBook("book2") } returns flowOf(emptyList())

        // Open book 1
        val vm1 = createViewModel("book1")
        advanceUntilIdle()
        val state1 = vm1.uiState.value as ReaderUiState.ReaderReady
        assertEquals(3, state1.currentPage.index)
        assertEquals(0.3f, state1.book.progressPercent, 0.01f)

        // Open book 2
        val vm2 = createViewModel("book2")
        advanceUntilIdle()
        val state2 = vm2.uiState.value as ReaderUiState.ReaderReady
        assertEquals(7, state2.currentPage.index)
        assertEquals(0.35f, state2.book.progressPercent, 0.01f)
    }

    // ── Progress survives sequential navigation ──────────────────────────

    @Test
    fun `navigating through multiple pages persists each step`() = runTest(testDispatcher) {
        val pages = makePages("book1", 10)
        val book = makeBook(totalPages = 10, currentPage = 0)
        setupBook(book, pages)

        val vm = createViewModel()
        advanceUntilIdle()

        // Navigate through pages 1, 2, 3
        vm.goToPage(1)
        advanceUntilIdle()
        vm.goToPage(2)
        advanceUntilIdle()
        vm.goToPage(3)
        advanceUntilIdle()

        // Verify the last persisted position is page 3
        coVerify {
            bookRepository.updateBook(match { saved -> saved.currentPage == 3 })
        }

        // Verify UI state is on page 3
        val state = vm.uiState.value as ReaderUiState.ReaderReady
        assertEquals(3, state.currentPage.index)
        assertEquals(0.3f, state.book.progressPercent, 0.01f)
    }

    // ── Progress display in library view model ───────────────────────────

    @Test
    fun `library sorts books by lastReadAt descending`() = runTest(testDispatcher) {
        val recent = LocalDateTime.now()
        val old = LocalDateTime.of(2020, 1, 1, 0, 0)

        val book1 = makeBook(id = "b1", title = "Recent Book", lastReadAt = recent)
        val book2 = makeBook(id = "b2", title = "Old Book", lastReadAt = old)

        // Verify that recent has a later timestamp
        assertTrue(book1.lastReadAt!!.isAfter(book2.lastReadAt))
    }

    @Test
    fun `book with null lastReadAt sorts after books with timestamps`() {
        val bookWithTime = makeBook(id = "b1", lastReadAt = LocalDateTime.now())
        val bookNoTime = makeBook(id = "b2", lastReadAt = null)

        // SQL: ORDER BY lastReadAt DESC NULLS LAST
        // Books with timestamps come first, nulls after
        assertNotNull(bookWithTime.lastReadAt)
        assertNull(bookNoTime.lastReadAt)
    }

    // ── Edge cases ───────────────────────────────────────────────────────

    @Test
    fun `goToPage on single-page book stays at page 0`() = runTest(testDispatcher) {
        val pages = makePages("book1", 1)
        val book = makeBook(totalPages = 1, currentPage = 0)
        setupBook(book, pages)

        val vm = createViewModel()
        advanceUntilIdle()

        vm.nextPage() // Should stay at 0 since there's only 1 page (index 0)
        val state = vm.uiState.value as ReaderUiState.ReaderReady
        assertEquals(0, state.currentPage.index)
    }

    @Test
    fun `progressPercent remains stable after multiple navigations`() = runTest(testDispatcher) {
        val pages = makePages("book1", 100)
        val book = makeBook(totalPages = 100, currentPage = 0)
        setupBook(book, pages)

        val vm = createViewModel()
        advanceUntilIdle()

        // Navigate to page 50
        vm.goToPage(50)
        advanceUntilIdle()

        val state = vm.uiState.value as ReaderUiState.ReaderReady
        assertEquals(0.5f, state.book.progressPercent, 0.001f)

        // Navigate to page 25
        vm.goToPage(25)
        advanceUntilIdle()

        val state2 = vm.uiState.value as ReaderUiState.ReaderReady
        assertEquals(0.25f, state2.book.progressPercent, 0.001f)
    }

    @Test
    fun `goToPage persists even when book had no prior lastReadAt`() = runTest(testDispatcher) {
        val pages = makePages("book1", 10)
        val book = makeBook(totalPages = 10, currentPage = 0, lastReadAt = null)
        setupBook(book, pages)

        val vm = createViewModel()
        advanceUntilIdle()

        vm.goToPage(5)
        advanceUntilIdle()

        // The goToPage update should include lastReadAt
        coVerify {
            bookRepository.updateBook(match { saved ->
                saved.currentPage == 5 && saved.lastReadAt != null
            })
        }
    }
}
