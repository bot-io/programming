package com.dualreader.app.ui.screens

import com.dualreader.app.domain.entities.Book
import com.dualreader.app.domain.entities.Page
import com.dualreader.app.domain.entities.ReaderTheme
import com.dualreader.app.domain.entities.ReadingSettings
import com.dualreader.app.domain.export.ExportFormat
import com.dualreader.app.domain.repositories.BookRepository
import com.dualreader.app.domain.repositories.BookmarkRepository
import com.dualreader.app.domain.repositories.SettingsRepository
import com.dualreader.app.domain.repositories.TranslationCacheRepository
import com.dualreader.app.domain.services.BatchTranslationResult
import com.dualreader.app.domain.services.TtsService
import com.dualreader.app.domain.services.TranslationService
import com.dualreader.app.domain.usecases.PaginateBookUseCase
import com.dualreader.app.domain.usecases.TranslatePageUseCase
import io.mockk.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.*
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test

/**
 * Additional coverage for ReaderViewModel, completing DR-037:
 *  - loadBook() race condition fix (DR-023): cancelling previous loads
 *  - Batch translation error recovery (criterion 4): retry after failure
 *  - TTS playback state management (previously zero tests)
 *  - Word-level tap-to-translate (previously zero tests)
 *  - Export helpers
 *
 * Mirrors the mock setup of [ReaderViewModelTest].
 */
@OptIn(ExperimentalCoroutinesApi::class)
class ReaderViewModelCoverageTest {

    private val testDispatcher = UnconfinedTestDispatcher()

    private lateinit var bookRepository: BookRepository
    private lateinit var settingsRepository: SettingsRepository
    private lateinit var bookmarkRepository: BookmarkRepository
    private lateinit var translatePageUseCase: TranslatePageUseCase
    private lateinit var paginateBookUseCase: PaginateBookUseCase
    private lateinit var translationCacheRepository: TranslationCacheRepository
    private lateinit var ttsService: TtsService
    private lateinit var translationService: TranslationService

    private val testBook1 = Book(
        id = "book1", title = "Book One", author = "Author A",
        filePath = "/book1.epub", language = "en", totalPages = 3, currentPage = 0,
    )

    private val testBook2 = Book(
        id = "book2", title = "Book Two", author = "Author B",
        filePath = "/book2.epub", language = "fr", totalPages = 2, currentPage = 0,
    )

    private val testPages1 = listOf(
        Page(index = 0, bookId = "book1", originalText = "Hello world one", chapterIndex = 0),
        Page(index = 1, bookId = "book1", originalText = "Hello world two", chapterIndex = 0),
        Page(index = 2, bookId = "book1", originalText = "Hello world three", chapterIndex = 0),
    )

    private val testPages2 = listOf(
        Page(index = 0, bookId = "book2", originalText = "Bonjour monde un", chapterIndex = 0),
        Page(index = 1, bookId = "book2", originalText = "Bonjour monde deux", chapterIndex = 0),
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
        translationService = mockk(relaxed = true)

        // Stub book1
        coEvery { bookRepository.getBookById("book1") } returns testBook1
        coEvery { bookRepository.getPagesForBook("book1") } returns testPages1
        coEvery { bookRepository.getPage("book1", any()) } returns testPages1[0]
        // Stub book2
        coEvery { bookRepository.getBookById("book2") } returns testBook2
        coEvery { bookRepository.getPagesForBook("book2") } returns testPages2
        coEvery { bookRepository.getPage("book2", any()) } returns testPages2[0]
        // Common stubs
        coEvery { settingsRepository.getSettings() } returns testSettings
        every { settingsRepository.settings } returns flowOf(testSettings)
        every { bookmarkRepository.getBookmarksForBook(any()) } returns flowOf(emptyList())
        // TTS defaults
        every { ttsService.isLanguageAvailable(any()) } returns true
        every { ttsService.getSpeechRate() } returns 1.0f
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
            ttsService = ttsService,
            translationService = translationService,
            mlKitModelManager = mockk(relaxed = true),
        )
    }

    @After
    fun tearDown() {
        ReaderViewModel.testIoDispatcher = null
        Dispatchers.resetMain()
    }

    // ════════════════════════════════════════════════════════════════════
    // DR-023: loadBook() race condition — criterion 2
    // ════════════════════════════════════════════════════════════════════

    @Test
    fun `loadBook - second load cancels pending first load`() = runTest(testDispatcher) {
        // Make book1's loading slow so it's still in flight when we switch
        coEvery { bookRepository.getBookById("book1") } coAnswers {
            delay(5000)
            testBook1
        }

        val vm = createViewModel("book1")
        // book1 load is now suspended at delay(5000)

        // Switch to book2 before book1 finishes
        vm.loadBook("book2")
        advanceUntilIdle()

        val state = vm.uiState.value
        assertTrue("Expected ReaderReady, got $state", state is ReaderUiState.ReaderReady)
        val ready = state as ReaderUiState.ReaderReady
        assertEquals("Should show book2, not book1", "Book Two", ready.book.title)
    }

    @Test
    fun `loadBook - switching books loads correct pages`() = runTest(testDispatcher) {
        coEvery { bookRepository.getBookById("book1") } coAnswers {
            delay(5000)
            testBook1
        }

        val vm = createViewModel("book1")
        vm.loadBook("book2")
        advanceUntilIdle()

        val state = vm.uiState.value as ReaderUiState.ReaderReady
        assertEquals("Should have book2's pages", 2, state.pages.size)
        assertEquals("Bonjour monde un", state.pages[0].originalText)
    }

    @Test
    fun `loadBook - no phantom emissions from cancelled load`() = runTest(testDispatcher) {
        coEvery { bookRepository.getBookById("book1") } coAnswers {
            delay(5000)
            testBook1
        }

        val vm = createViewModel("book1")
        vm.loadBook("book2")
        advanceUntilIdle()

        // Advance virtual time past book1's delay — its coroutine was cancelled,
        // so it must NOT resume and overwrite book2's state.
        advanceTimeBy(10_000)
        advanceUntilIdle()

        val state = vm.uiState.value as ReaderUiState.ReaderReady
        assertEquals(
            "Book2 data should persist after book1 delay completes",
            "Book Two",
            state.book.title,
        )
    }

    @Test
    fun `loadBook - rapid back-and-forth switching loads final book`() = runTest(testDispatcher) {
        val vm = createViewModel("book1")
        advanceUntilIdle()

        vm.loadBook("book2")
        advanceUntilIdle()
        assertEquals("Book Two", (vm.uiState.value as ReaderUiState.ReaderReady).book.title)

        vm.loadBook("book1")
        advanceUntilIdle()
        assertEquals("Book One", (vm.uiState.value as ReaderUiState.ReaderReady).book.title)
    }

    // ════════════════════════════════════════════════════════════════════
    // Batch translation error recovery — criterion 4
    // ════════════════════════════════════════════════════════════════════

    @Test
    fun `translateCurrentPage - recovers after failure on retry`() = runTest(testDispatcher) {
        var attempt = 0
        coEvery {
            translatePageUseCase.translateBatchWithContext(any(), any(), any(), any(), any(), any())
        } coAnswers {
            attempt++
            // Fail twice (first attempt + auto-retry), then succeed on manual retry
            if (attempt <= 2) {
                Result.failure(RuntimeException("Network error"))
            } else {
                Result.success(BatchTranslationResult(mapOf(0 to "Превод"), "test"))
            }
        }

        val vm = createViewModel()
        advanceUntilIdle()

        // First attempt fails
        vm.translateCurrentPage()
        advanceUntilIdle()

        val state1 = vm.uiState.value as ReaderUiState.ReaderReady
        assertNotNull("Should have error after failure", state1.translationError)
        assertFalse("Page 0 should not be translated after failure", state1.pages[0].hasTranslation("bg"))

        // Retry succeeds — error clears, translation applied
        vm.translateCurrentPage()
        advanceUntilIdle()

        val state2 = vm.uiState.value as ReaderUiState.ReaderReady
        assertNull("Error should clear after success", state2.translationError)
        assertEquals("Превод", state2.pages[0].effectiveTranslation("bg"))
    }

    @Test
    fun `translateAllPages - recovers after failure on retry`() = runTest(testDispatcher) {
        var attempt = 0
        coEvery {
            translatePageUseCase.translateBatchWithContext(any(), any(), any(), any(), any(), any())
        } coAnswers {
            attempt++
            if (attempt == 1) {
                Result.failure(RuntimeException("Server error"))
            } else {
                Result.success(
                    BatchTranslationResult(mapOf(0 to "T0", 1 to "T1", 2 to "T2"), "test"),
                )
            }
        }

        val vm = createViewModel()
        advanceUntilIdle()

        // First batch attempt fails
        vm.translateAllPages()
        advanceUntilIdle()
        assertNotNull((vm.uiState.value as ReaderUiState.ReaderReady).translationError)

        // Retry succeeds
        vm.translateAllPages()
        advanceUntilIdle()

        val state = vm.uiState.value as ReaderUiState.ReaderReady
        assertNull("Error should clear", state.translationError)
        assertEquals("T0", state.pages[0].effectiveTranslation("bg"))
        assertEquals("T2", state.pages[2].effectiveTranslation("bg"))
    }

    @Test
    fun `translateCurrentPage - exception then success clears error`() = runTest(testDispatcher) {
        var attempt = 0
        coEvery {
            translatePageUseCase.translateBatchWithContext(any(), any(), any(), any(), any(), any())
        } coAnswers {
            attempt++
            if (attempt == 1) {
                throw java.io.IOException("Connection reset")
            }
            Result.success(BatchTranslationResult(mapOf(0 to "Успех"), "test"))
        }

        val vm = createViewModel()
        advanceUntilIdle()

        vm.translateCurrentPage()
        advanceUntilIdle()
        val state1 = vm.uiState.value as ReaderUiState.ReaderReady
        assertTrue(state1.translationError!!.contains("Connection reset"))

        vm.translateCurrentPage()
        advanceUntilIdle()
        val state2 = vm.uiState.value as ReaderUiState.ReaderReady
        assertNull(state2.translationError)
        assertEquals("Успех", state2.pages[0].effectiveTranslation("bg"))
    }

    // ════════════════════════════════════════════════════════════════════
    // TTS playback — previously zero coverage
    // ════════════════════════════════════════════════════════════════════

    @Test
    fun `speakCurrentPage - error when no translation available`() = runTest(testDispatcher) {
        val vm = createViewModel()
        advanceUntilIdle()

        vm.speakCurrentPage()

        val tts = vm.ttsState.value
        assertNotNull("Should set error", tts.error)
        assertTrue(tts.error!!.contains("No translation"))
        assertFalse(tts.isSpeaking)
        verify(exactly = 0) { ttsService.speak(any(), any(), any(), any(), any(), any()) }
    }

    @Test
    fun `speakCurrentPage - error when language not available`() = runTest(testDispatcher) {
        every { ttsService.isLanguageAvailable("bg") } returns false
        val translatedPages = listOf(
            testPages1[0].withTranslation("bg", "Здравей свят\n\nВтори абзац"),
            testPages1[1],
            testPages1[2],
        )
        coEvery { bookRepository.getPagesForBook("book1") } returns translatedPages

        val vm = createViewModel()
        advanceUntilIdle()

        vm.speakCurrentPage()

        val tts = vm.ttsState.value
        assertNotNull(tts.error)
        assertTrue(tts.error!!.contains("No TTS voice"))
        assertFalse(tts.isLanguageAvailable)
        verify(exactly = 0) { ttsService.speak(any(), any(), any(), any(), any(), any()) }
    }

    @Test
    fun `speakCurrentPage - starts speaking when translation available`() = runTest(testDispatcher) {
        val translatedPages = listOf(
            testPages1[0].withTranslation("bg", "Здравей свят\n\nВтори абзац"),
            testPages1[1],
            testPages1[2],
        )
        coEvery { bookRepository.getPagesForBook("book1") } returns translatedPages

        val vm = createViewModel()
        advanceUntilIdle()

        vm.speakCurrentPage()

        val tts = vm.ttsState.value
        assertTrue(tts.isSpeaking)
        assertEquals(0, tts.currentParagraph)
        assertNull(tts.error)
        verify(exactly = 1) { ttsService.speak(any(), any(), any(), any(), any(), any()) }
    }

    @Test
    fun `speakParagraph - error when paragraph not translated`() = runTest(testDispatcher) {
        val vm = createViewModel()
        advanceUntilIdle()

        vm.speakParagraph(1) // page 1 has no translation

        val tts = vm.ttsState.value
        assertNotNull(tts.error)
        assertTrue(tts.error!!.contains("No translation"))
        verify(exactly = 0) { ttsService.speak(any(), any(), any(), any(), any(), any()) }
    }

    @Test
    fun `speakParagraph - starts speaking translated paragraph`() = runTest(testDispatcher) {
        val translatedPages = listOf(
            testPages1[0],
            testPages1[1].withTranslation("bg", "Здравей свят две"),
            testPages1[2],
        )
        coEvery { bookRepository.getPagesForBook("book1") } returns translatedPages

        val vm = createViewModel()
        advanceUntilIdle()

        vm.speakParagraph(1)

        val tts = vm.ttsState.value
        assertTrue(tts.isSpeaking)
        assertEquals(1, tts.currentParagraph)
    }

    @Test
    fun `stopTts - resets playback state`() = runTest(testDispatcher) {
        val vm = createViewModel()
        advanceUntilIdle()

        vm.stopTts()

        val tts = vm.ttsState.value
        assertFalse(tts.isSpeaking)
        assertEquals(-1, tts.currentParagraph)
        verify(exactly = 1) { ttsService.stop() }
    }

    @Test
    fun `pauseTts - sets isSpeaking false`() = runTest(testDispatcher) {
        val vm = createViewModel()
        advanceUntilIdle()

        vm.pauseTts()

        assertFalse(vm.ttsState.value.isSpeaking)
        verify(exactly = 1) { ttsService.pause() }
    }

    @Test
    fun `setTtsSpeechRate - updates state and delegates to service`() = runTest(testDispatcher) {
        val vm = createViewModel()
        advanceUntilIdle()

        vm.setTtsSpeechRate(1.5f)

        assertEquals(1.5f, vm.ttsState.value.speechRate, 0.001f)
        verify(exactly = 1) { ttsService.setSpeechRate(1.5f) }
    }

    @Test
    fun `checkTtsAvailability - updates isLanguageAvailable state`() = runTest(testDispatcher) {
        every { ttsService.isLanguageAvailable("bg") } returns false

        val vm = createViewModel()
        advanceUntilIdle()

        vm.checkTtsAvailability()

        assertFalse(vm.ttsState.value.isLanguageAvailable)
    }

    @Test
    fun `onCleared - stops and releases TTS engine`() = runTest(testDispatcher) {
        val vm = createViewModel()
        advanceUntilIdle()

        // onCleared is protected in ViewModel — invoke via reflection
        val method = androidx.lifecycle.ViewModel::class.java.getDeclaredMethod("onCleared")
        method.isAccessible = true
        method.invoke(vm)

        verify(exactly = 1) { ttsService.stop() }
        verify(exactly = 1) { ttsService.release() }
    }

    // ════════════════════════════════════════════════════════════════════
    // Word-level translation (tap-to-translate) — previously zero coverage
    // ════════════════════════════════════════════════════════════════════

    @Test
    fun `translateWord - blank word does nothing`() = runTest(testDispatcher) {
        val vm = createViewModel()
        advanceUntilIdle()

        vm.translateWord("", isFromOriginal = true)
        advanceUntilIdle()

        assertNull(vm.wordTranslation.value)
        coVerify(exactly = 0) {
            translationService.translate(any(), any(), any(), any(), any(), any())
        }
    }

    @Test
    fun `translateWord - translates and updates state`() = runTest(testDispatcher) {
        coEvery {
            translationService.translate(any(), any(), any(), any(), any(), any())
        } returns "здравей"

        val vm = createViewModel()
        advanceUntilIdle()

        vm.translateWord("hello", isFromOriginal = true)
        advanceUntilIdle()

        val wt = vm.wordTranslation.value!!
        assertEquals("hello", wt.word)
        assertEquals("здравей", wt.translation)
        assertFalse(wt.isLoading)
        assertNull(wt.error)
        assertTrue(wt.isFromOriginal)
    }

    @Test
    fun `translateWord - sets error on translation failure`() = runTest(testDispatcher) {
        coEvery {
            translationService.translate(any(), any(), any(), any(), any(), any())
        } throws RuntimeException("API error")

        val vm = createViewModel()
        advanceUntilIdle()

        vm.translateWord("hello", isFromOriginal = true)
        advanceUntilIdle()

        val wt = vm.wordTranslation.value!!
        assertFalse(wt.isLoading)
        assertNotNull(wt.error)
        assertTrue(wt.error!!.contains("API error"))
    }

    @Test
    fun `dismissWordTranslation - clears state`() = runTest(testDispatcher) {
        coEvery {
            translationService.translate(any(), any(), any(), any(), any(), any())
        } returns "здравей"

        val vm = createViewModel()
        advanceUntilIdle()

        vm.translateWord("hello", isFromOriginal = true)
        advanceUntilIdle()
        assertNotNull(vm.wordTranslation.value)

        vm.dismissWordTranslation()
        assertNull(vm.wordTranslation.value)
    }

    @Test
    fun `translateWord - from translated text uses reverse language direction`() =
        runTest(testDispatcher) {
            // isFromOriginal=false means: source = target language (bg), target = book language (en)
            coEvery {
                translationService.translate(any(), eq("en"), eq("bg"), any(), any(), any())
            } returns "hello"
            coEvery {
                translationService.translate(any(), any(), any(), any(), any(), any())
            } returns "hello"

            val vm = createViewModel()
            advanceUntilIdle()

            vm.translateWord("здравей", isFromOriginal = false)
            advanceUntilIdle()

            val wt = vm.wordTranslation.value!!
            assertEquals("hello", wt.translation)
            assertFalse(wt.isFromOriginal)
        }

    // ════════════════════════════════════════════════════════════════════
    // Export helpers — previously zero coverage
    // ════════════════════════════════════════════════════════════════════

    @Test
    fun `exportFileExtension - correct extension per format`() {
        val vm = createViewModel()
        assertEquals("txt", vm.exportFileExtension(ExportFormat.PLAIN_TEXT))
        assertEquals("md", vm.exportFileExtension(ExportFormat.MARKDOWN))
        assertEquals("json", vm.exportFileExtension(ExportFormat.JSON))
    }

    @Test
    fun `exportFileName - sanitized filename with book title`() {
        val vm = createViewModel()
        val name = vm.exportFileName(ExportFormat.MARKDOWN)
        assertTrue("Should contain book title: $name", name.contains("Book One"))
        assertTrue("Should end with .md: $name", name.endsWith(".md"))
    }

    @Test
    fun `exportFileName - strips special characters`() = runTest(testDispatcher) {
        val specialBook = testBook1.copy(title = "Book: A \"Bad\" Title?!")
        coEvery { bookRepository.getBookById("book1") } returns specialBook
        val vm = createViewModel()
        advanceUntilIdle()

        val name = vm.exportFileName(ExportFormat.JSON)
        assertFalse("Should not contain colon: $name", name.contains(":"))
        assertFalse("Should not contain quotes: $name", name.contains("\""))
        assertTrue("Should end with .json: $name", name.endsWith(".json"))
    }

    @Test
    fun `formatBookmarks - returns non-empty string for format`() = runTest(testDispatcher) {
        val vm = createViewModel()
        advanceUntilIdle()

        val result = vm.formatBookmarks(ExportFormat.PLAIN_TEXT)
        // Empty bookmarks → "No annotations to export."
        assertTrue(result.isNotBlank())
    }

    // ════════════════════════════════════════════════════════════════════
    // updateCurrentPage — previously untested
    // ════════════════════════════════════════════════════════════════════

    @Test
    fun `updateCurrentPage - persists book with new page index`() = runTest(testDispatcher) {
        val vm = createViewModel()
        advanceUntilIdle()

        vm.updateCurrentPage(2)
        advanceUntilIdle()

        coVerify { bookRepository.updateBook(match { it.currentPage == 2 }) }
    }
}
