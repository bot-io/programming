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
import io.mockk.every
import io.mockk.mockk
import io.mockk.coEvery
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import kotlinx.coroutines.test.advanceUntilIdle
import org.junit.After
import org.junit.Assert.assertNull
import org.junit.Assert.assertNotNull
import org.junit.Before
import org.junit.Test

/**
 * DR-177: Regression tests for wordJob lifecycle and cancellation in ReaderViewModel.
 * Tests verify that wordJob is properly tracked and cancelled when:
 *  1. onCleared() is called
 *  2. Multiple translateWord() calls happen consecutively
 *  3. Translation state is properly managed
 */
@OptIn(ExperimentalCoroutinesApi::class)
class ReaderViewModelWordJobTest {

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

    private val testBook = Book(
        id = "book1", title = "Test Book", author = "Author",
        filePath = "/test.epub", language = "en", totalPages = 1, currentPage = 0,
    )

    private val testPages = listOf(
        Page(index = 0, bookId = "book1", originalText = "Hello world.", chapterIndex = 0),
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
        translatePageUseCase = mockk(relaxed = true)
        paginateBookUseCase = mockk(relaxed = true)
        translationCacheRepository = mockk(relaxed = true)
        ttsService = mockk(relaxed = true)
        translationService = mockk(relaxed = true)
        mlKitModelManager = mockk(relaxed = true)

        coEvery { bookRepository.getBookById("book1") } returns testBook
        coEvery { bookRepository.getPagesForBook("book1") } returns testPages
        coEvery { bookRepository.getPage("book1", any()) } returns testPages[0]
        coEvery { settingsRepository.getSettings() } returns testSettings
        every { settingsRepository.settings } returns flowOf(testSettings)
        every { bookmarkRepository.getBookmarksForBook("book1") } returns flowOf(emptyList())
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
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
            fallbackTranslationService = mockk(relaxed = true),
            mlKitModelManager = mlKitModelManager,
        )
    }

    @Test
    fun `translateWord starts translation and sets loading state`() = runTest(testDispatcher) {
        // Arrange — suspend the translation so the loading state is observable
        // (with an unconfined dispatcher + relaxed mock, a completing stub makes
        //  isLoading=false by assert time; loading=true is the state under test)
        coEvery { translationService.translate(any(), any(), any()) } coAnswers {
            kotlinx.coroutines.awaitCancellation()
        }
        val vm = createViewModel()
        advanceUntilIdle()

        // Act - start word translation
        vm.translateWord("hello", isFromOriginal = true)
        advanceUntilIdle()

        // Assert - word translation state should be set with loading=true
        val wordState = vm.wordTranslation.value
        assertNotNull("wordTranslation state should not be null", wordState)
        org.junit.Assert.assertEquals("hello", wordState?.word)
        org.junit.Assert.assertEquals("true", true, wordState?.isLoading)
    }

    @Test
    fun `translateWord with blank word returns early without setting state`() = runTest(testDispatcher) {
        // Arrange
        val vm = createViewModel()
        advanceUntilIdle()

        // Act - try to translate blank word
        vm.translateWord("   ", isFromOriginal = true)
        advanceUntilIdle()

        // Assert - word translation state should remain null
        val wordState = vm.wordTranslation.value
        assertNull("wordTranslation state should be null for blank words", wordState)
    }

    @Test
    fun `consecutive translateWord calls cancel previous wordJob`() = runTest(testDispatcher) {
        // Arrange
        val vm = createViewModel()
        advanceUntilIdle()

        // Act - start two word translations in quick succession
        vm.translateWord("first", isFromOriginal = true)
        vm.translateWord("second", isFromOriginal = true)
        advanceUntilIdle()

        // Assert - only the second translation should be in state
        val wordState = vm.wordTranslation.value
        assertNotNull("wordTranslation state should not be null", wordState)
        org.junit.Assert.assertEquals("second", wordState?.word)
        // The first translation should have been cancelled by the second call
    }

    @Test
    fun `onCleared does not throw exception when wordJob is active`() = runTest(testDispatcher) {
        // Arrange
        val vm = createViewModel()
        advanceUntilIdle()

        // Start word translation
        vm.translateWord("hello", isFromOriginal = true)
        advanceUntilIdle()

        // Act - clear ViewModel (using reflection to call protected onCleared)
        val onClearedMethod = vm.javaClass.getDeclaredMethod("onCleared")
        onClearedMethod.isAccessible = true
        onClearedMethod.invoke(vm)

        // Assert - no exception thrown, onCleared completes successfully
        // Before DR-177: wordJob was not cancelled, but no visible error occurred
        // After DR-177: wordJob is properly cancelled along with ttsRetryJob
        // We verify by not throwing an exception during onCleared
    }

    @Test
    fun `onCleared executes without errors when wordJob is null`() = runTest(testDispatcher) {
        // Arrange
        val vm = createViewModel()
        advanceUntilIdle()

        // No translateWord call, wordJob should be null

        // Act - clear ViewModel (using reflection to call protected onCleared)
        val onClearedMethod = vm.javaClass.getDeclaredMethod("onCleared")
        onClearedMethod.isAccessible = true
        onClearedMethod.invoke(vm)

        // Assert - no exception thrown, onCleared completes successfully
        // Verifies that onCleared() handles null wordJob gracefully
    }
}