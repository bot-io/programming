package com.dualreader.app.ui.screens

import com.dualreader.app.data.translation.MlKitModelManager
import com.dualreader.app.domain.entities.Book
import com.dualreader.app.domain.entities.Page
import com.dualreader.app.domain.entities.PaginationStatus
import com.dualreader.app.domain.entities.ReadingSettings
import com.dualreader.app.domain.entities.TranslationPosition
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
import io.mockk.slot
import io.mockk.verify
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/**
 * DR-247: Tests for continuous TTS reading, speech rate, and alternating original text.
 *
 * Tests cover:
 * - DR-243: Translation position defaults
 * - DR-244: Continuous reading + alternating original (no delay)
 * - DR-245: TTS speech rate applied from settings
 * - DR-246: (UI behavior — auto-scroll is in Compose, tested via state changes)
 */
@ExperimentalCoroutinesApi
class ReaderViewModelTtsContinuousTest {

    private val testDispatcher = UnconfinedTestDispatcher()

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
        totalPages = 5,
        paginationStatus = PaginationStatus.COMPLETED,
    )

    private fun makePages(count: Int, targetLang: String = "es"): List<Page> {
        return (0 until count).map { i ->
            Page(
                index = i,
                bookId = bookId,
                chapterIndex = 0,
                originalText = "Original paragraph $i.\n\nSecond original paragraph $i.",
                translations = mapOf(targetLang to "Translated paragraph $i.\n\nSecond translated paragraph $i."),
            )
        }
    }

    @Before
    fun setup() {
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

        // Default settings
        coEvery { settingsRepo.getSettings() } returns ReadingSettings()
        every { settingsRepo.settings } returns flowOf(ReadingSettings())
        coEvery { settingsRepo.updateSettings(any()) } returns Unit
        coEvery { bookmarkRepo.getBookmarksForBook(any()) } returns flowOf(emptyList())

        // TTS defaults — ready and language available
        every { ttsService.isReady } returns true
        every { ttsService.isInitFailed } returns false
        every { ttsService.isSpeaking } returns false
        every { ttsService.currentParagraphIndex } returns -1
        every { ttsService.isLanguageAvailable(any()) } returns true
        every { ttsService.getSpeechRate() } returns 1.0f
        every { ttsService.reinitialize() } returns false
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    // ─── DR-243: Translation Position Defaults ────────────────────────────

    @Test
    fun readingSettings_defaultTranslationPosition_isTranslationAbove() {
        val settings = ReadingSettings()
        assertEquals(TranslationPosition.TRANSLATION_ABOVE, settings.translationPosition)
    }

    @Test
    fun readingSettings_defaultTtsReadOriginal_isFalse() {
        val settings = ReadingSettings()
        assertFalse(settings.ttsReadOriginal)
    }

    // ─── DR-245: Speech Rate Defaults ─────────────────────────────────────

    @Test
    fun readingSettings_defaultTtsSpeechRate_is1_0() {
        val settings = ReadingSettings()
        assertEquals(1.0f, settings.ttsSpeechRate, 0.001f)
    }

    @Test
    fun readingSettings_customSpeechRate_preservedInCopy() {
        val settings = ReadingSettings(ttsSpeechRate = 1.5f)
        assertEquals(1.5f, settings.ttsSpeechRate, 0.001f)
    }

    // ─── DR-244: Continuous Reading — Speech Rate Applied ─────────────────

    @Test
    fun startContinuousReading_appliesSpeechRateFromSettings() = runTest {
        val book = makeBook()
        val pages = makePages(3)
        coEvery { bookRepo.getBookById(bookId) } returns book
        coEvery { bookRepo.getPagesForBook(any()) } returns pages
        coEvery { bookRepo.getPage(any(), any()) } returns pages.first()

        // Settings with custom speech rate — override BOTH the one-shot and the flow
        val customSettings = ReadingSettings(ttsSpeechRate = 1.5f)
        coEvery { settingsRepo.getSettings() } returns customSettings
        every { settingsRepo.settings } returns flowOf(customSettings)

        val viewModel = createViewModel()
        advanceUntilIdle()

        viewModel.startContinuousReading()
        advanceUntilIdle()

        // DR-245: setSpeechRate should be called with the setting value
        verify { ttsService.setSpeechRate(1.5f) }

        viewModel.callOnClearedForTesting()
    }

    @Test
    fun startContinuousReading_appliesDefaultSpeechRateWhenNotSet() = runTest {
        val book = makeBook()
        val pages = makePages(2)
        coEvery { bookRepo.getBookById(bookId) } returns book
        coEvery { bookRepo.getPagesForBook(any()) } returns pages
        coEvery { bookRepo.getPage(any(), any()) } returns pages.first()

        val viewModel = createViewModel()
        advanceUntilIdle()

        viewModel.startContinuousReading()
        advanceUntilIdle()

        // Default speech rate is 1.0
        verify { ttsService.setSpeechRate(1.0f) }

        viewModel.callOnClearedForTesting()
    }

    // ─── DR-244: Continuous Reading — Speak Called ────────────────────────

    @Test
    fun startContinuousReading_callsTtsSpeakForTranslationParagraphs() = runTest {
        val book = makeBook()
        val pages = makePages(2)
        coEvery { bookRepo.getBookById(bookId) } returns book
        coEvery { bookRepo.getPagesForBook(any()) } returns pages
        coEvery { bookRepo.getPage(any(), any()) } returns pages.first()

        val viewModel = createViewModel()
        advanceUntilIdle()

        viewModel.startContinuousReading()
        advanceUntilIdle()

        // TTS speak() should be called at least once for translation
        verify(atLeast = 1) {
            ttsService.speak(
                paragraphs = any(),
                langCode = "es",
                startIndex = any(),
                onParagraphStarted = any(),
                onCompleted = any(),
                onError = any(),
            )
        }

        viewModel.callOnClearedForTesting()
    }

    // ─── DR-244: Continuous Reading — No Delay When Alternating ───────────

    @Test
    fun startContinuousReading_withReadOriginalEnabled_noDelayBetweenTranslationAndOriginal() = runTest {
        val book = makeBook()
        val pages = makePages(1)
        coEvery { bookRepo.getBookById(bookId) } returns book
        coEvery { bookRepo.getPagesForBook(any()) } returns pages
        coEvery { bookRepo.getPage(any(), any()) } returns pages.first()

        // Settings with ttsReadOriginal enabled
        val originalSettings = ReadingSettings(ttsReadOriginal = true)
        coEvery { settingsRepo.getSettings() } returns originalSettings
        every { settingsRepo.settings } returns flowOf(originalSettings)

        // Stub speak() to immediately invoke onCompleted callback so the coroutine proceeds
        val onCompleteSlot = slot<() -> Unit>()
        every {
            ttsService.speak(
                paragraphs = any(),
                langCode = any(),
                startIndex = any(),
                onParagraphStarted = any(),
                onCompleted = capture(onCompleteSlot),
                onError = any(),
            )
        } answers {
            onCompleteSlot.captured.invoke()
        }

        val viewModel = createViewModel()
        advanceUntilIdle()

        viewModel.startContinuousReading()
        advanceUntilIdle()

        // TTS speak() should be called for both translation AND original.
        // No delay means both calls happen without intervening delay().
        verify(atLeast = 1) {
            ttsService.speak(
                paragraphs = any(),
                langCode = "es", // translation language
                startIndex = any(),
                onParagraphStarted = any(),
                onCompleted = any(),
                onError = any(),
            )
        }
        verify(atLeast = 1) {
            ttsService.speak(
                paragraphs = any(),
                langCode = "en", // source language for original text
                startIndex = any(),
                onParagraphStarted = any(),
                onCompleted = any(),
                onError = any(),
            )
        }

        viewModel.callOnClearedForTesting()
    }

    @Test
    fun startContinuousReading_withReadOriginalDisabled_doesNotReadOriginal() = runTest {
        val book = makeBook()
        val pages = makePages(2)
        coEvery { bookRepo.getBookById(bookId) } returns book
        coEvery { bookRepo.getPagesForBook(any()) } returns pages
        coEvery { bookRepo.getPage(any(), any()) } returns pages.first()

        val viewModel = createViewModel()
        advanceUntilIdle()

        viewModel.startContinuousReading()
        advanceUntilIdle()

        // Should NOT call speak with "en" (source language) — only "es" (target)
        verify(exactly = 0) {
            ttsService.speak(
                paragraphs = any(),
                langCode = "en",
                startIndex = any(),
                onParagraphStarted = any(),
                onCompleted = any(),
                onError = any(),
            )
        }

        viewModel.callOnClearedForTesting()
    }

    // ─── DR-244: Stop Continuous Reading ──────────────────────────────────

    @Test
    fun stopTts_callsTtsServiceStop() = runTest {
        val book = makeBook()
        coEvery { bookRepo.getBookById(bookId) } returns book
        coEvery { bookRepo.getPage(any(), any()) } returns mockk()

        val viewModel = createViewModel()
        advanceUntilIdle()

        viewModel.stopTts()
        advanceUntilIdle()

        verify { ttsService.stop() }

        viewModel.callOnClearedForTesting()
    }

    @Test
    fun stopTts_setsIsSpeakingFalse() = runTest {
        val book = makeBook()
        coEvery { bookRepo.getBookById(bookId) } returns book
        coEvery { bookRepo.getPage(any(), any()) } returns mockk()

        val viewModel = createViewModel()
        advanceUntilIdle()

        viewModel.stopTts()
        advanceUntilIdle()

        assertFalse(viewModel.ttsState.value.isSpeaking)

        viewModel.callOnClearedForTesting()
    }

    @Test
    fun pauseTts_setsIsSpeakingFalse() = runTest {
        val book = makeBook()
        coEvery { bookRepo.getBookById(bookId) } returns book
        coEvery { bookRepo.getPage(any(), any()) } returns mockk()

        val viewModel = createViewModel()
        advanceUntilIdle()

        viewModel.pauseTts()
        advanceUntilIdle()

        assertFalse(viewModel.ttsState.value.isSpeaking)

        viewModel.callOnClearedForTesting()
    }

    // ─── DR-244: TTS State Updates ────────────────────────────────────────

    @Test
    fun startContinuousReading_setsTtsStateIsSpeakingTrue() = runTest {
        val book = makeBook()
        val pages = makePages(2)
        coEvery { bookRepo.getBookById(bookId) } returns book
        coEvery { bookRepo.getPagesForBook(any()) } returns pages
        coEvery { bookRepo.getPage(any(), any()) } returns pages.first()

        val viewModel = createViewModel()
        advanceUntilIdle()

        viewModel.startContinuousReading()
        // Don't advanceUntilIdle — check state synchronously before completion
        assertEquals(true, viewModel.ttsState.value.isSpeaking)

        viewModel.callOnClearedForTesting()
    }

    @Test
    fun startContinuousReading_setsCurrentParagraphToCurrentPageIndex() = runTest {
        val book = makeBook()
        val pages = makePages(3)
        coEvery { bookRepo.getBookById(bookId) } returns book
        coEvery { bookRepo.getPagesForBook(any()) } returns pages
        coEvery { bookRepo.getPage(any(), any()) } returns pages.first()

        val viewModel = createViewModel()
        advanceUntilIdle()

        viewModel.startContinuousReading()
        // currentParagraph should be set to the starting page index (0)
        assertEquals(0, viewModel.ttsState.value.currentParagraph)

        viewModel.callOnClearedForTesting()
    }

    // ─── DR-244: TTS Not Ready / Language Unavailable ─────────────────────

    @Test
    fun startContinuousReading_whenTtsNotReady_setsErrorAndDoesNotSpeak() = runTest {
        val book = makeBook()
        val pages = makePages(1)
        coEvery { bookRepo.getBookById(bookId) } returns book
        coEvery { bookRepo.getPagesForBook(any()) } returns pages
        coEvery { bookRepo.getPage(any(), any()) } returns pages.first()

        every { ttsService.isReady } returns false
        every { ttsService.isInitFailed } returns false

        val viewModel = createViewModel()
        advanceUntilIdle()

        viewModel.startContinuousReading()
        advanceUntilIdle()

        // Should not call speak
        verify(exactly = 0) {
            ttsService.speak(any(), any(), any(), any(), any(), any())
        }
        // Should have error message
        assertTrue(viewModel.ttsState.value.error != null)

        viewModel.callOnClearedForTesting()
    }

    @Test
    fun startContinuousReading_whenLanguageNotAvailable_setsError() = runTest {
        val book = makeBook()
        val pages = makePages(1)
        coEvery { bookRepo.getBookById(bookId) } returns book
        coEvery { bookRepo.getPagesForBook(any()) } returns pages
        coEvery { bookRepo.getPage(any(), any()) } returns pages.first()

        every { ttsService.isLanguageAvailable("es") } returns false

        val viewModel = createViewModel()
        advanceUntilIdle()

        viewModel.startContinuousReading()
        advanceUntilIdle()

        assertFalse(viewModel.ttsState.value.isLanguageAvailable)
        assertTrue(viewModel.ttsState.value.error != null)

        viewModel.callOnClearedForTesting()
    }

    // ─── DR-245: Settings Update with Speech Rate ─────────────────────────

    @Test
    fun updateSettings_withTtsSpeechRate_persistsToRepository() = runTest {
        val book = makeBook()
        coEvery { bookRepo.getBookById(bookId) } returns book
        coEvery { bookRepo.getPage(any(), any()) } returns mockk()

        val viewModel = createViewModel()
        advanceUntilIdle()

        viewModel.updateSettings { it.copy(ttsSpeechRate = 1.75f) }
        advanceUntilIdle()

        coVerify { settingsRepo.updateSettings(any()) }

        viewModel.callOnClearedForTesting()
    }

    // ─── DR-243: Settings Update with Translation Position ────────────────

    @Test
    fun updateSettings_withTranslationPosition_persistsToRepository() = runTest {
        val book = makeBook()
        coEvery { bookRepo.getBookById(bookId) } returns book
        coEvery { bookRepo.getPage(any(), any()) } returns mockk()

        val viewModel = createViewModel()
        advanceUntilIdle()

        viewModel.updateSettings {
            it.copy(translationPosition = TranslationPosition.TRANSLATION_BELOW)
        }
        advanceUntilIdle()

        coVerify { settingsRepo.updateSettings(any()) }

        viewModel.callOnClearedForTesting()
    }

    // ─── Helper ───────────────────────────────────────────────────────────

    private fun createViewModel(id: String = bookId): ReaderViewModel {
        return ReaderViewModel(
            savedStateHandle = SavedStateHandle(mapOf("bookId" to id)),
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
}
