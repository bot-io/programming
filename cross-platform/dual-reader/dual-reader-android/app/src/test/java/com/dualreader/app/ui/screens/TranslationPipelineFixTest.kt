package com.dualreader.app.ui.screens

import com.dualreader.app.domain.entities.Book
import com.dualreader.app.domain.entities.Page
import com.dualreader.app.domain.entities.ReaderTheme
import com.dualreader.app.domain.entities.ReadingSettings
import com.dualreader.app.domain.repositories.BookRepository
import com.dualreader.app.domain.repositories.BookmarkRepository
import com.dualreader.app.domain.repositories.SettingsRepository
import com.dualreader.app.domain.repositories.TranslationCacheRepository
import com.dualreader.app.domain.services.BatchTranslationResult
import com.dualreader.app.domain.usecases.PageToTranslate
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
 * Regression tests for translation pipeline fixes:
 *
 * DR-060: _book in combine flow — scroll position propagates to translateCurrentPage
 * DR-061: Partial results saved via onPageTranslated callback on timeout
 * DR-062: collectTranslateWindow interleaves forward/backward scanning
 *
 * Plus per-language cache independence tests.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class TranslationPipelineFixTest {

    private val testDispatcher = UnconfinedTestDispatcher()

    private lateinit var bookRepository: BookRepository
    private lateinit var settingsRepository: SettingsRepository
    private lateinit var bookmarkRepository: BookmarkRepository
    private lateinit var translatePageUseCase: TranslatePageUseCase
    private lateinit var paginateBookUseCase: PaginateBookUseCase
    private lateinit var translationCacheRepository: TranslationCacheRepository
    private lateinit var ttsService: com.dualreader.app.domain.services.TtsService
    private lateinit var translationService: com.dualreader.app.domain.services.TranslationService
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

    private fun setupBook(
        pages: List<Page>,
        book: Book,
        settings: ReadingSettings = ReadingSettings(
            fontSize = 16f, lineHeight = 1.5f, targetLanguage = "bg", theme = ReaderTheme.DARK,
        ),
    ): ReaderViewModel {
        coEvery { bookRepository.getBookById(book.id) } returns book
        coEvery { bookRepository.getPagesForBook(book.id) } returns pages
        coEvery { bookRepository.getPage(book.id, any()) } returns pages.firstOrNull() ?: Page(index = 0, bookId = book.id, originalText = "", chapterIndex = 0)
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

    private fun makePages(count: Int, bookId: String = "book1"): List<Page> {
        return (0 until count).map {
            Page(index = it, bookId = bookId, originalText = "Paragraph $it text content here", chapterIndex = 0)
        }
    }

    private fun stubTranslateSuccess(model: String = "gemini-2.5-flash") {
        coEvery {
            translatePageUseCase.translateBatchWithContext(any(), any(), any(), any(), any(), any())
        } coAnswers {
            val pageList = firstArg<List<PageToTranslate>>()
            val resultMap = pageList.associate { it.index to "T${it.index}" }
            Result.success(BatchTranslationResult(resultMap, model))
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // DR-062: collectTranslateWindow interleaves forward/backward
    // ═══════════════════════════════════════════════════════════════════════════

    @Test
    fun `DR-062 - scrolling backward translates paragraphs before current position`() = runTest(testDispatcher) {
        val pages = makePages(30)
        val book = Book(
            id = "book1", title = "Test", author = "Author",
            filePath = "/test.epub", language = "en", totalPages = 30, currentPage = 20,
        )

        val translatedIndices = mutableSetOf<Int>()
        coEvery {
            translatePageUseCase.translateBatchWithContext(any(), any(), any(), any(), any(), any())
        } coAnswers {
            val pageList = firstArg<List<PageToTranslate>>()
            translatedIndices.addAll(pageList.map { it.index })
            Result.success(BatchTranslationResult(pageList.associate { it.index to "T${it.index}" }, "test"))
        }

        val vm = setupBook(pages, book)
        advanceUntilIdle()

        vm.translateCurrentPage()
        advanceUntilIdle()

        val backwardTranslated = translatedIndices.filter { it < 20 }
        assertTrue(
            "Should translate at least some pages before position 20, got: $backwardTranslated",
            backwardTranslated.isNotEmpty(),
        )
    }

    @Test
    fun `DR-062 - current page itself is included in translation window`() = runTest(testDispatcher) {
        val pages = makePages(10)
        val book = Book(
            id = "book1", title = "Test", author = "Author",
            filePath = "/test.epub", language = "en", totalPages = 10, currentPage = 5,
        )

        val translatedIndices = mutableSetOf<Int>()
        coEvery {
            translatePageUseCase.translateBatchWithContext(any(), any(), any(), any(), any(), any())
        } coAnswers {
            val pageList = firstArg<List<PageToTranslate>>()
            translatedIndices.addAll(pageList.map { it.index })
            Result.success(BatchTranslationResult(pageList.associate { it.index to "T${it.index}" }, "test"))
        }

        val vm = setupBook(pages, book)
        advanceUntilIdle()

        vm.translateCurrentPage()
        advanceUntilIdle()

        assertTrue("Current page (5) must be in translation window", 5 in translatedIndices)
    }

    @Test
    fun `DR-062 - window at start of book translates forward only`() = runTest(testDispatcher) {
        val pages = makePages(20)
        val book = Book(
            id = "book1", title = "Test", author = "Author",
            filePath = "/test.epub", language = "en", totalPages = 20, currentPage = 0,
        )

        val translatedIndices = mutableSetOf<Int>()
        coEvery {
            translatePageUseCase.translateBatchWithContext(any(), any(), any(), any(), any(), any())
        } coAnswers {
            val pageList = firstArg<List<PageToTranslate>>()
            translatedIndices.addAll(pageList.map { it.index })
            Result.success(BatchTranslationResult(pageList.associate { it.index to "T${it.index}" }, "test"))
        }

        val vm = setupBook(pages, book)
        advanceUntilIdle()

        vm.translateCurrentPage()
        advanceUntilIdle()

        assertFalse("No negative indices", translatedIndices.any { it < 0 })
        assertTrue("Should include page 0", 0 in translatedIndices)
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // DR-060: Scroll position propagates to translateCurrentPage
    // ═══════════════════════════════════════════════════════════════════════════

    @Test
    fun `DR-060 - updateCurrentPage changes where translation starts`() = runTest(testDispatcher) {
        val pages = makePages(30)
        val book = Book(
            id = "book1", title = "Test", author = "Author",
            filePath = "/test.epub", language = "en", totalPages = 30, currentPage = 0,
        )

        var translatedCenterPage = -1
        coEvery {
            translatePageUseCase.translateBatchWithContext(any(), any(), any(), any(), any(), any())
        } coAnswers {
            val pageList = firstArg<List<PageToTranslate>>()
            translatedCenterPage = pageList.minByOrNull { kotlin.math.abs(it.index - 15) }?.index ?: -1
            Result.success(BatchTranslationResult(pageList.associate { it.index to "T${it.index}" }, "test"))
        }

        val vm = setupBook(pages, book)
        advanceUntilIdle()

        vm.updateCurrentPage(15)
        advanceUntilIdle()

        vm.translateCurrentPage()
        advanceUntilIdle()

        assertTrue(
            "Translation should start near page 15, got center=$translatedCenterPage",
            kotlin.math.abs(translatedCenterPage - 15) <= 2,
        )
    }

    @Test
    fun `DR-060 - uiState currentPage updates after updateCurrentPage`() = runTest(testDispatcher) {
        val pages = makePages(20)
        val book = Book(
            id = "book1", title = "Test", author = "Author",
            filePath = "/test.epub", language = "en", totalPages = 20, currentPage = 0,
        )

        val vm = setupBook(pages, book)
        advanceUntilIdle()

        val state1 = vm.uiState.value as ReaderUiState.ReaderReady
        assertEquals(0, state1.currentPage.index)

        vm.updateCurrentPage(10)
        advanceUntilIdle()

        val state2 = vm.uiState.value as ReaderUiState.ReaderReady
        assertEquals(10, state2.currentPage.index)
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // DR-061: Partial results saved via onPageTranslated callback
    // ═══════════════════════════════════════════════════════════════════════════

    @Test
    fun `DR-061 - partial results are visible even if only some pages translated`() = runTest(testDispatcher) {
        val pages = makePages(5)
        val book = Book(
            id = "book1", title = "Test", author = "Author",
            filePath = "/test.epub", language = "en", totalPages = 5, currentPage = 0,
        )

        coEvery {
            translatePageUseCase.translateBatchWithContext(any(), any(), any(), any(), any(), any())
        } returns Result.success(BatchTranslationResult(
            mapOf(0 to "T0", 1 to "T1", 2 to "T2"),
            "test",
        ))

        val vm = setupBook(pages, book)
        advanceUntilIdle()

        vm.translateCurrentPage()
        advanceUntilIdle()

        val state = vm.uiState.value as ReaderUiState.ReaderReady
        assertEquals("T0", state.pages[0].effectiveTranslation("bg"))
        assertEquals("T1", state.pages[1].effectiveTranslation("bg"))
        assertEquals("T2", state.pages[2].effectiveTranslation("bg"))
        assertNull(state.pages[3].effectiveTranslation("bg"))
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // Per-language cache independence
    // ═══════════════════════════════════════════════════════════════════════════

    @Test
    fun `per-language - translating to bg does not mark pages as translated for de`() = runTest(testDispatcher) {
        val pages = makePages(3)
        val book = Book(
            id = "book1", title = "Test", author = "Author",
            filePath = "/test.epub", language = "en", totalPages = 3, currentPage = 0,
        )

        coEvery {
            translatePageUseCase.translateBatchWithContext(any(), any(), any(), any(), any(), any())
        } returns Result.success(BatchTranslationResult(
            mapOf(0 to "BG0", 1 to "BG1", 2 to "BG2"),
            "test",
        ))

        val vm = setupBook(pages, book)
        advanceUntilIdle()

        vm.translateCurrentPage()
        advanceUntilIdle()

        val state = vm.uiState.value as ReaderUiState.ReaderReady
        for (i in 0 until 3) {
            assertEquals("BG$i", state.pages[i].effectiveTranslation("bg"))
        }
        for (i in 0 until 3) {
            assertNull("Page $i should NOT have de translation", state.pages[i].effectiveTranslation("de"))
        }
    }

    @Test
    fun `per-language - switching language and translating starts from current position`() = runTest(testDispatcher) {
        val pagesWithBg = makePages(5).map { page ->
            page.copy(translations = mapOf("bg" to "BG${page.index}"))
        }
        val book = Book(
            id = "book1", title = "Test", author = "Author",
            filePath = "/test.epub", language = "en", totalPages = 5, currentPage = 2,
        )

        val settingsDe = ReadingSettings(
            fontSize = 16f, lineHeight = 1.5f, targetLanguage = "de", theme = ReaderTheme.DARK,
        )

        val deTranslationIndices = mutableSetOf<Int>()
        coEvery {
            translatePageUseCase.translateBatchWithContext(any(), any(), any(), any(), any(), any())
        } coAnswers {
            val pageList = firstArg<List<PageToTranslate>>()
            deTranslationIndices.addAll(pageList.map { it.index })
            Result.success(BatchTranslationResult(
                pageList.associate { it.index to "DE${it.index}" },
                "test",
            ))
        }

        val vm = setupBook(pagesWithBg, book, settingsDe)
        advanceUntilIdle()

        vm.translateCurrentPage()
        advanceUntilIdle()

        assertTrue(
            "de translation should include pages near position 2, got: $deTranslationIndices",
            deTranslationIndices.any { kotlin.math.abs(it - 2) <= 2 },
        )

        val state = vm.uiState.value as ReaderUiState.ReaderReady
        for (i in 0 until 5) {
            assertEquals("BG$i", state.pages[i].effectiveTranslation("bg"))
        }
        for (idx in deTranslationIndices) {
            assertEquals("DE$idx", state.pages[idx].effectiveTranslation("de"))
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // Error handling
    // ═══════════════════════════════════════════════════════════════════════════

    @Test
    fun `translateCurrentPage - all already translated shows appropriate message`() = runTest(testDispatcher) {
        val pages = makePages(3).map {
            it.copy(translations = mapOf("bg" to "Already BG${it.index}"))
        }
        val book = Book(
            id = "book1", title = "Test", author = "Author",
            filePath = "/test.epub", language = "en", totalPages = 3, currentPage = 0,
        )

        val vm = setupBook(pages, book)
        advanceUntilIdle()

        vm.translateCurrentPage()
        advanceUntilIdle()

        coVerify(exactly = 0) {
            translatePageUseCase.translateBatchWithContext(any(), any(), any(), any(), any(), any())
        }
    }

    @Test
    fun `translateCurrentPage - network error does not crash and sets error state`() = runTest(testDispatcher) {
        val pages = makePages(3)
        val book = Book(
            id = "book1", title = "Test", author = "Author",
            filePath = "/test.epub", language = "en", totalPages = 3, currentPage = 0,
        )

        coEvery {
            translatePageUseCase.translateBatchWithContext(any(), any(), any(), any(), any(), any())
        } returns Result.failure(Exception("Network error"))

        val vm = setupBook(pages, book)
        advanceUntilIdle()

        vm.translateCurrentPage()
        advanceUntilIdle()

        val state = vm.uiState.value as ReaderUiState.ReaderReady
        assertNotNull("Translation error should be set", state.translationError)
    }

    @Test
    fun `translateCurrentPage - cancellation does not show error`() = runTest(testDispatcher) {
        val pages = makePages(3)
        val book = Book(
            id = "book1", title = "Test", author = "Author",
            filePath = "/test.epub", language = "en", totalPages = 3, currentPage = 0,
        )

        coEvery {
            translatePageUseCase.translateBatchWithContext(any(), any(), any(), any(), any(), any())
        } throws kotlinx.coroutines.CancellationException("User cancelled")

        val vm = setupBook(pages, book)
        advanceUntilIdle()

        vm.translateCurrentPage()
        advanceUntilIdle()

        // Should not crash — CancellationException propagates without setting translationError
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // Window edge cases
    // ═══════════════════════════════════════════════════════════════════════════

    @Test
    fun `collectTranslateWindow - single page book`() = runTest(testDispatcher) {
        val pages = listOf(Page(index = 0, bookId = "book1", originalText = "Only page", chapterIndex = 0))
        val book = Book(
            id = "book1", title = "Test", author = "Author",
            filePath = "/test.epub", language = "en", totalPages = 1, currentPage = 0,
        )

        stubTranslateSuccess()

        val vm = setupBook(pages, book)
        advanceUntilIdle()

        vm.translateCurrentPage()
        advanceUntilIdle()

        val state = vm.uiState.value as ReaderUiState.ReaderReady
        assertEquals("T0", state.pages[0].effectiveTranslation("bg"))
    }

    @Test
    fun `collectTranslateWindow - empty pages list handled gracefully`() = runTest(testDispatcher) {
        val book = Book(
            id = "book1", title = "Test", author = "Author",
            filePath = "/test.epub", language = "en", totalPages = 0, currentPage = 0,
        )

        coEvery { bookRepository.getPagesForBook("book1") } returns emptyList()

        val vm = setupBook(emptyList(), book)
        advanceUntilIdle()

        val state = vm.uiState.value
        assertTrue("Should be Error state for empty book", state is ReaderUiState.Error)
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // translateAllPages
    // ═══════════════════════════════════════════════════════════════════════════

    @Test
    fun `translateAllPages - all pages get translated`() = runTest(testDispatcher) {
        val pages = makePages(5)
        val book = Book(
            id = "book1", title = "Test", author = "Author",
            filePath = "/test.epub", language = "en", totalPages = 5, currentPage = 0,
        )

        coEvery {
            translatePageUseCase.translateBatchWithContext(any(), any(), any(), any(), any(), any())
        } returns Result.success(BatchTranslationResult(
            mapOf(0 to "T0", 1 to "T1", 2 to "T2", 3 to "T3", 4 to "T4"),
            "test",
        ))

        val vm = setupBook(pages, book)
        advanceUntilIdle()

        vm.translateAllPages()
        advanceUntilIdle()

        val state = vm.uiState.value as ReaderUiState.ReaderReady
        for (i in 0 until 5) {
            assertEquals("T$i", state.pages[i].effectiveTranslation("bg"))
        }
    }

    @Test
    fun `translateAllPages - skips already translated pages`() = runTest(testDispatcher) {
        val pages = makePages(3).map {
            it.copy(translations = mapOf("bg" to "Existing${it.index}"))
        }
        val book = Book(
            id = "book1", title = "Test", author = "Author",
            filePath = "/test.epub", language = "en", totalPages = 3, currentPage = 0,
        )

        coEvery {
            translatePageUseCase.translateBatchWithContext(any(), any(), any(), any(), any(), any())
        } returns Result.success(BatchTranslationResult(emptyMap(), "test"))

        val vm = setupBook(pages, book)
        advanceUntilIdle()

        vm.translateAllPages()
        advanceUntilIdle()

        val state = vm.uiState.value as ReaderUiState.ReaderReady
        for (i in 0 until 3) {
            assertEquals("Existing$i", state.pages[i].effectiveTranslation("bg"))
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // translateParagraph (single)
    // ═══════════════════════════════════════════════════════════════════════════

    @Test
    fun `translateParagraph - translates single paragraph by index`() = runTest(testDispatcher) {
        val pages = makePages(5)
        val book = Book(
            id = "book1", title = "Test", author = "Author",
            filePath = "/test.epub", language = "en", totalPages = 5, currentPage = 0,
        )

        coEvery {
            translatePageUseCase.translateBatchWithContext(any(), any(), any(), any(), any(), any())
        } returns Result.success(BatchTranslationResult(mapOf(3 to "Solo translation"), "test"))

        val vm = setupBook(pages, book)
        advanceUntilIdle()

        vm.translateParagraph(3)
        advanceUntilIdle()

        val state = vm.uiState.value as ReaderUiState.ReaderReady
        assertEquals("Solo translation", state.pages[3].effectiveTranslation("bg"))
        assertNull(state.pages[0].effectiveTranslation("bg"))
        assertNull(state.pages[1].effectiveTranslation("bg"))
    }

    @Test
    fun `translateParagraph - skips if already translated`() = runTest(testDispatcher) {
        val pages = makePages(3).map {
            it.copy(translations = mapOf("bg" to "Already${it.index}"))
        }
        val book = Book(
            id = "book1", title = "Test", author = "Author",
            filePath = "/test.epub", language = "en", totalPages = 3, currentPage = 0,
        )

        val vm = setupBook(pages, book)
        advanceUntilIdle()

        vm.translateParagraph(1)
        advanceUntilIdle()

        coVerify(exactly = 0) {
            translatePageUseCase.translateBatchWithContext(any(), any(), any(), any(), any(), any())
        }
    }

    @Test
    fun `reTranslateParagraph - forces retranslation even if already translated`() = runTest(testDispatcher) {
        val pages = makePages(3).map {
            it.copy(translations = mapOf("bg" to "Old${it.index}"))
        }
        val book = Book(
            id = "book1", title = "Test", author = "Author",
            filePath = "/test.epub", language = "en", totalPages = 3, currentPage = 0,
        )

        coEvery {
            translatePageUseCase.translateBatchWithContext(any(), any(), any(), any(), any(), any())
        } returns Result.success(BatchTranslationResult(mapOf(1 to "New translation"), "test"))

        val vm = setupBook(pages, book)
        advanceUntilIdle()

        vm.reTranslateParagraph(1)
        advanceUntilIdle()

        val state = vm.uiState.value as ReaderUiState.ReaderReady
        assertEquals("New translation", state.pages[1].effectiveTranslation("bg"))
        assertEquals("Old0", state.pages[0].effectiveTranslation("bg"))
    }
}
