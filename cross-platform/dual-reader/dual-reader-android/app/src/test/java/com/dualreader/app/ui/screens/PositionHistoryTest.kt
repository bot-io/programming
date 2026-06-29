package com.dualreader.app.ui.screens

import com.dualreader.app.domain.entities.Book
import com.dualreader.app.domain.entities.Page
import com.dualreader.app.domain.entities.ReaderTheme
import com.dualreader.app.domain.entities.ReadingSettings
import com.dualreader.app.domain.repositories.BookRepository
import com.dualreader.app.domain.repositories.BookmarkRepository
import com.dualreader.app.domain.repositories.SettingsRepository
import com.dualreader.app.domain.repositories.TranslationCacheRepository
import com.dualreader.app.domain.services.TtsService
import com.dualreader.app.domain.services.TranslationService
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
 * DR-063: Tests for reading position history tracking and slider snap-to navigation.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class PositionHistoryTest {

    private val testDispatcher = UnconfinedTestDispatcher()

    private lateinit var bookRepository: BookRepository
    private lateinit var settingsRepository: SettingsRepository
    private lateinit var bookmarkRepository: BookmarkRepository
    private lateinit var translatePageUseCase: TranslatePageUseCase
    private lateinit var paginateBookUseCase: PaginateBookUseCase
    private lateinit var translationCacheRepository: TranslationCacheRepository
    private lateinit var ttsService: TtsService
    private lateinit var translationService: TranslationService
    private lateinit var mlKitModelManager: com.dualreader.app.data.translation.MlKitModelManager

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
        translationService = mockk(relaxed = true)
        mlKitModelManager = mockk(relaxed = true)
    }

    @After
    fun tearDown() {
        ReaderViewModel.testIoDispatcher = null
        Dispatchers.resetMain()
    }

    private fun makePages(count: Int, bookId: String = "book1"): List<Page> {
        return (0 until count).map {
            Page(index = it, bookId = bookId, originalText = "Paragraph $it text content here", chapterIndex = 0)
        }
    }

    private fun setupBook(
        pages: List<Page>,
        book: Book,
        settings: ReadingSettings = ReadingSettings(
            fontSize = 16f, lineHeight = 1.5f, targetLanguage = "bg", theme = ReaderTheme.DARK,
        ),
    ): ReaderViewModel {
        coEvery { bookRepository.getBookById(book.id) } returns book
        coEvery { bookRepository.getPagesForBook(book.id) } returns pages
        coEvery { bookRepository.getPage(book.id, any()) } returns pages.firstOrNull()
            ?: Page(index = 0, bookId = book.id, originalText = "", chapterIndex = 0)
        coEvery { settingsRepository.getSettings() } returns settings
        every { settingsRepository.settings } returns flowOf(settings)
        every { bookmarkRepository.getBookmarksForBook(book.id) } returns flowOf(emptyList())

        return ReaderViewModel(
            savedStateHandle = androidx.lifecycle.SavedStateHandle(mapOf("bookId" to book.id)),
            bookRepository = bookRepository,
            settingsRepository = settingsRepository,
            bookmarkRepository = bookmarkRepository,
            translatePageUseCase = translatePageUseCase,
            paginateBookUseCase = paginateBookUseCase,
            translationCacheRepository = translationCacheRepository,
            ttsService = ttsService,
            translationService = translationService,
            fallbackTranslationService = mockk(relaxed = true),
            mlKitModelManager = mlKitModelManager,
        )
    }

    private fun baseBook(totalPages: Int, currentPage: Int = 0) = Book(
        id = "book1", title = "Test Book", author = "Author",
        filePath = "/test.epub", language = "en", totalPages = totalPages, currentPage = currentPage,
    )

    // ═══════════════════════════════════════════════════════════════════════════
    // trackReadingPosition — basic tracking
    // ═══════════════════════════════════════════════════════════════════════════

    @Test
    fun `trackReadingPosition - adds first position to history`() = runTest(testDispatcher) {
        val pages = makePages(100)
        val vm = setupBook(pages, baseBook(100))
        advanceUntilIdle()

        vm.trackReadingPosition(10, 100)
        advanceUntilIdle()

        assertEquals(listOf(10), vm.positionHistory.value)
    }

    @Test
    fun `trackReadingPosition - positions kept in insertion order (FIFO)`() = runTest(testDispatcher) {
        val pages = makePages(200)
        val vm = setupBook(pages, baseBook(200))
        advanceUntilIdle()

        vm.trackReadingPosition(150, 200)
        vm.trackReadingPosition(10, 200)
        vm.trackReadingPosition(100, 200)
        advanceUntilIdle()

        assertEquals("FIFO order: 150 added first, then 10, then 100", listOf(150, 10, 100), vm.positionHistory.value)
    }

    @Test
    fun `trackReadingPosition - zero totalPages does nothing`() = runTest(testDispatcher) {
        val vm = setupBook(emptyList(), baseBook(0))
        advanceUntilIdle()

        vm.trackReadingPosition(0, 0)
        advanceUntilIdle()

        assertTrue(vm.positionHistory.value.isEmpty())
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // trackReadingPosition — deduplication
    // ═══════════════════════════════════════════════════════════════════════════

    @Test
    fun `trackReadingPosition - removes nearby marks within threshold`() = runTest(testDispatcher) {
        // 100 pages → 2% threshold = 2 pages minimum distance
        val pages = makePages(100)
        val vm = setupBook(pages, baseBook(100))
        advanceUntilIdle()

        vm.trackReadingPosition(10, 100)
        advanceUntilIdle()

        // Position 11 is within 2 pages of 10 → should replace
        vm.trackReadingPosition(11, 100)
        advanceUntilIdle()

        assertEquals("11 should replace 10 (within threshold)", listOf(11), vm.positionHistory.value)
    }

    @Test
    fun `trackReadingPosition - keeps marks far apart`() = runTest(testDispatcher) {
        val pages = makePages(100)
        val vm = setupBook(pages, baseBook(100))
        advanceUntilIdle()

        vm.trackReadingPosition(5, 100)
        vm.trackReadingPosition(50, 100)
        vm.trackReadingPosition(95, 100)
        advanceUntilIdle()

        assertEquals(listOf(5, 50, 95), vm.positionHistory.value)
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // trackReadingPosition — max history limit
    // ═══════════════════════════════════════════════════════════════════════════

    @Test
    fun `trackReadingPosition - evicts oldest when over MAX_POSITION_HISTORY`() = runTest(testDispatcher) {
        // Use 1000 pages so all positions are far apart (threshold = 20)
        val pages = makePages(1000)
        val vm = setupBook(pages, baseBook(1000))
        advanceUntilIdle()

        // Add MAX+1 positions, verify FIFO eviction (oldest removed first)
        for (i in 0..ReaderViewModel.MAX_POSITION_HISTORY) {
            vm.trackReadingPosition(i * 50, 1000) // each 50 apart, well beyond threshold of 20
        }
        advanceUntilIdle()

        assertEquals(
            "History should be exactly MAX (${ReaderViewModel.MAX_POSITION_HISTORY})",
            ReaderViewModel.MAX_POSITION_HISTORY,
            vm.positionHistory.value.size,
        )
    }

    @Test
    fun `trackReadingPosition - FIFO eviction removes oldest by time not lowest page`() = runTest(testDispatcher) {
        // 1000 pages → threshold = 20, positions 50 apart are all unique
        val pages = makePages(1000)
        val vm = setupBook(pages, baseBook(1000))
        advanceUntilIdle()

        // Track 5 positions (max), then add a 6th
        vm.trackReadingPosition(0, 1000)   // oldest — should be evicted
        vm.trackReadingPosition(100, 1000)
        vm.trackReadingPosition(200, 1000)
        vm.trackReadingPosition(300, 1000)
        vm.trackReadingPosition(400, 1000)
        advanceUntilIdle()
        assertEquals(5, vm.positionHistory.value.size)

        // Add 6th — oldest (0) must be evicted
        vm.trackReadingPosition(500, 1000)
        advanceUntilIdle()

        val history = vm.positionHistory.value
        assertEquals(5, history.size)
        assertFalse("Oldest position (0) should have been evicted (FIFO)", 0 in history)
        assertTrue("Newest position (500) should be present", 500 in history)
    }

    @Test
    fun `trackReadingPosition - FIFO eviction evicts by insertion time not page number`() = runTest(testDispatcher) {
        // Track out-of-order pages to prove eviction is by TIME not by page index
        val pages = makePages(1000)
        val vm = setupBook(pages, baseBook(1000))
        advanceUntilIdle()

        // Insert in order: 900, 100, 500, 300, 700 (5 = max)
        vm.trackReadingPosition(900, 1000)
        vm.trackReadingPosition(100, 1000)
        vm.trackReadingPosition(500, 1000)
        vm.trackReadingPosition(300, 1000)
        vm.trackReadingPosition(700, 1000)
        advanceUntilIdle()

        // Insert 6th: 50 — FIFO should evict 900 (oldest by TIME), not 50 (lowest page)
        vm.trackReadingPosition(50, 1000)
        advanceUntilIdle()

        val history = vm.positionHistory.value
        assertEquals(5, history.size)
        assertFalse("900 was inserted first (oldest by time), should be evicted", 900 in history)
        assertTrue("50 is newest, should be present", 50 in history)
        assertTrue("100 should still be present", 100 in history)
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // updateCurrentPage — integration with position tracking
    // ═══════════════════════════════════════════════════════════════════════════

    @Test
    fun `updateCurrentPage - tracks position in history`() = runTest(testDispatcher) {
        val pages = makePages(50)
        val vm = setupBook(pages, baseBook(50))
        advanceUntilIdle()

        vm.updateCurrentPage(25)
        advanceUntilIdle()

        assertTrue("Page 25 should be in position history", 25 in vm.positionHistory.value)
    }

    @Test
    fun `updateCurrentPage - multiple page changes create multiple snap points`() = runTest(testDispatcher) {
        val pages = makePages(500)
        val vm = setupBook(pages, baseBook(500))
        advanceUntilIdle()

        vm.updateCurrentPage(10)   // ~2%
        advanceUntilIdle()
        vm.updateCurrentPage(390)  // ~78%
        advanceUntilIdle()

        val history = vm.positionHistory.value
        assertTrue("Page 10 should be snap point", 10 in history)
        assertTrue("Page 390 should be snap point", 390 in history)
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // jumpToPosition — slider navigation
    // ═══════════════════════════════════════════════════════════════════════════

    @Test
    fun `jumpToPosition - updates book currentPage`() = runTest(testDispatcher) {
        val pages = makePages(100)
        val vm = setupBook(pages, baseBook(100, currentPage = 0))
        advanceUntilIdle()

        vm.jumpToPosition(50)
        advanceUntilIdle()

        val state = vm.uiState.value as ReaderUiState.ReaderReady
        assertEquals(50, state.book.currentPage)
    }

    @Test
    fun `jumpToPosition - persists to repository`() = runTest(testDispatcher) {
        val pages = makePages(100)
        val vm = setupBook(pages, baseBook(100))
        advanceUntilIdle()

        vm.jumpToPosition(75)
        advanceUntilIdle()

        coVerify { bookRepository.updateBook(any()) }
    }

    @Test
    fun `jumpToPosition - out of range index is ignored`() = runTest(testDispatcher) {
        val pages = makePages(10)
        val vm = setupBook(pages, baseBook(10))
        advanceUntilIdle()

        vm.jumpToPosition(99)
        advanceUntilIdle()

        val state = vm.uiState.value as ReaderUiState.ReaderReady
        assertEquals(0, state.book.currentPage)
    }

    @Test
    fun `jumpToPosition - does NOT add to position history`() = runTest(testDispatcher) {
        val pages = makePages(100)
        val vm = setupBook(pages, baseBook(100))
        advanceUntilIdle()

        vm.trackReadingPosition(10, 100)
        advanceUntilIdle()
        assertEquals(listOf(10), vm.positionHistory.value)

        // Jumping to a new position should NOT track it
        vm.jumpToPosition(50)
        advanceUntilIdle()

        // Position history should still only contain 10 (the tracked reading position)
        assertFalse(50 in vm.positionHistory.value)
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // User scenario: jump between reading positions
    // ═══════════════════════════════════════════════════════════════════════════

    @Test
    fun `scenario - user reads at 2pct, jumps to 78pct, both are snap points`() = runTest(testDispatcher) {
        val pages = makePages(500)
        val vm = setupBook(pages, baseBook(500))
        advanceUntilIdle()

        // User reads at ~2% (page 10)
        vm.updateCurrentPage(10)
        advanceUntilIdle()

        // User jumps to ~78% (page 390) via slider
        vm.jumpToPosition(390)
        advanceUntilIdle()

        // User reads at 390 — tracked as snap point
        vm.updateCurrentPage(390)
        advanceUntilIdle()

        // Both should be snap points
        val history = vm.positionHistory.value
        assertTrue("Page 10 (~2%) should be snap point", history.any { kotlin.math.abs(it - 10) <= 10 })
        assertTrue("Page 390 (~78%) should be snap point", history.any { kotlin.math.abs(it - 390) <= 10 })

        // User can now jump back to 10
        vm.jumpToPosition(10)
        advanceUntilIdle()
        assertEquals(10, (vm.uiState.value as ReaderUiState.ReaderReady).book.currentPage)

        // And jump back to 390
        vm.jumpToPosition(390)
        advanceUntilIdle()
        assertEquals(390, (vm.uiState.value as ReaderUiState.ReaderReady).book.currentPage)
    }

    @Test
    fun `scenario - reading nearby positions deduplicates to nearest`() = runTest(testDispatcher) {
        val pages = makePages(100)
        val vm = setupBook(pages, baseBook(100))
        advanceUntilIdle()

        // User reads at pages 10, 11, 12 (scrolling through a few pages)
        vm.updateCurrentPage(10)
        advanceUntilIdle()
        vm.updateCurrentPage(11)
        advanceUntilIdle()
        vm.updateCurrentPage(12)
        advanceUntilIdle()

        // Only one snap point should exist (all within 2% threshold of 100 pages = 2 pages)
        val history = vm.positionHistory.value
        assertEquals("Should deduplicate nearby positions", 1, history.size)
        assertEquals(12, history[0])
    }
}
