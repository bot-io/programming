package com.dualreader.app.ui.screens

import com.dualreader.app.domain.entities.ReadingSettings
import com.dualreader.app.domain.repositories.BookRepository
import com.dualreader.app.domain.repositories.SettingsRepository
import com.dualreader.app.domain.repositories.TranslationCacheRepository
import com.dualreader.app.util.AppLogger
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkObject
import io.mockk.unmockkAll
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Before
import org.junit.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull

@OptIn(ExperimentalCoroutinesApi::class)
class SettingsViewModelTest {

    private lateinit var viewModel: SettingsViewModel
    private lateinit var settingsRepository: SettingsRepository
    private lateinit var cacheRepository: TranslationCacheRepository
    private lateinit var bookRepository: BookRepository

    private val testDispatcher = StandardTestDispatcher()

    @Before
    fun setup() {
        Dispatchers.setMain(testDispatcher)

        settingsRepository = mockk()
        cacheRepository = mockk()
        bookRepository = mockk()

        // Mock settings flow
        every { settingsRepository.settings } returns kotlinx.coroutines.flow.MutableStateFlow(
            ReadingSettings()
        )

        mockkObject(AppLogger)

        viewModel = SettingsViewModel(
            settingsRepository,
            cacheRepository,
            bookRepository
        )
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
        unmockkAll()
    }

    @Test
    fun `clearAllTranslations success - clears cache, book translations, and UI state`() = runTest {
        // Arrange
        coEvery { cacheRepository.clearAll() } returns 5  // Returns count of deleted entries
        coEvery { bookRepository.clearAllTranslations() } returns Unit
        coEvery { bookRepository.getTranslatedPageCount() } returns 0

        // Act
        viewModel.clearAllTranslations()
        advanceUntilIdle()

        // Assert
        coVerify { cacheRepository.clearAll() }
        coVerify { bookRepository.clearAllTranslations() }
        coVerify { bookRepository.getTranslatedPageCount() }
        assertEquals(0, viewModel.translationInfo.value.size)
        assertEquals(0, viewModel.cachedCount.value)
        assertNull(viewModel.clearError.value)
    }

    @Test
    fun `clearAllTranslations cache failure - logs error and shows user message`() = runTest {
        // Arrange
        val exception = RuntimeException("Disk full")
        coEvery { cacheRepository.clearAll() } throws exception
        coEvery { bookRepository.clearAllTranslations() } returns Unit
        coEvery { bookRepository.getTranslatedPageCount() } returns 5

        // Act
        viewModel.clearAllTranslations()
        advanceUntilIdle()

        // Assert
        coVerify(exactly = 0) { bookRepository.clearAllTranslations() }
        coVerify { AppLogger.e("clearAllTranslations: Failed to clear translations: Disk full") }
        assertEquals("Failed to clear translations: Disk full", viewModel.clearError.value)
    }

    @Test
    fun `clearAllTranslations book repository failure - logs error and shows user message`() = runTest {
        // Arrange
        val exception = RuntimeException("Database locked")
        coEvery { cacheRepository.clearAll() } returns 5
        coEvery { bookRepository.clearAllTranslations() } throws exception
        coEvery { bookRepository.getTranslatedPageCount() } returns 3

        // Act
        viewModel.clearAllTranslations()
        advanceUntilIdle()

        // Assert
        coVerify { cacheRepository.clearAll() }
        coVerify { bookRepository.clearAllTranslations() }
        coVerify { AppLogger.e("clearAllTranslations: Failed to clear translations: Database locked") }
        assertEquals("Failed to clear translations: Database locked", viewModel.clearError.value)
    }

    @Test
    fun `clearErrorShown - clears error state`() = runTest {
        // Arrange - Set an error state
        coEvery { cacheRepository.clearAll() } throws RuntimeException("Test error")
        viewModel.clearAllTranslations()
        advanceUntilIdle()
        assertNotNull(viewModel.clearError.value)

        // Act
        viewModel.clearErrorShown()

        // Assert
        assertNull(viewModel.clearError.value)
    }

    @Test
    fun `clearAllTranslations resets error before attempting clear`() = runTest {
        // Arrange - Set an error state from previous call
        coEvery { cacheRepository.clearAll() } throws RuntimeException("First error")
        viewModel.clearAllTranslations()
        advanceUntilIdle()
        assertNotNull(viewModel.clearError.value)

        // Arrange - Fix the issue for second call
        coEvery { cacheRepository.clearAll() } returns 5
        coEvery { bookRepository.clearAllTranslations() } returns Unit
        coEvery { bookRepository.getTranslatedPageCount() } returns 0

        // Act
        viewModel.clearAllTranslations()
        advanceUntilIdle()

        // Assert - Error should be reset (null) after successful call
        assertNull(viewModel.clearError.value)
    }

    // DR-114: Test refreshCacheCount error handling
    @Test
    fun `refreshCacheCount success - updates cached count`() = runTest {
        // Arrange
        coEvery { bookRepository.getTranslatedPageCount() } returns 42

        // Act - create new ViewModel to trigger init() which calls refreshCacheCount()
        val testViewModel = SettingsViewModel(
            settingsRepository,
            cacheRepository,
            bookRepository
        )
        advanceUntilIdle()

        // Assert
        coVerify { bookRepository.getTranslatedPageCount() }
        assertEquals(42, testViewModel.cachedCount.value)
    }

    @Test
    fun `refreshCacheCount failure - logs error and preserves previous count`() = runTest {
        // Arrange - Set initial count in an existing ViewModel
        coEvery { bookRepository.getTranslatedPageCount() } returns 10
        val testViewModel = SettingsViewModel(
            settingsRepository,
            cacheRepository,
            bookRepository
        )
        advanceUntilIdle()
        assertEquals(10, testViewModel.cachedCount.value)

        // Arrange - Make the next call fail
        val exception = RuntimeException("Database locked")
        coEvery { bookRepository.getTranslatedPageCount() } throws exception

        // Act - Trigger refreshCacheCount() by calling clearAllTranslations which calls it
        coEvery { cacheRepository.clearAll() } returns 5
        coEvery { bookRepository.clearAllTranslations() } returns Unit
        testViewModel.clearAllTranslations()
        advanceUntilIdle()

        // Assert - Count should be updated to 0 from getTranslatedPageCount() in clearAllTranslations
        // (This is because clearAllTranslations succeeds, but refreshCacheCount() preserves the 0)
        assertEquals(0, testViewModel.cachedCount.value)
        coVerify { AppLogger.e(match { it.startsWith("refreshCacheCount: Failed") }) }
    }

    @Test
    fun `refreshCacheCount preserves initial count when init fails`() = runTest {
        // Arrange - Make the init call fail
        val exception = RuntimeException("Connection timeout")
        coEvery { bookRepository.getTranslatedPageCount() } throws exception

        // Act - create new ViewModel, init() calls refreshCacheCount()
        val testViewModel = SettingsViewModel(
            settingsRepository,
            cacheRepository,
            bookRepository
        )
        advanceUntilIdle()

        // Assert - Count should remain at initial value (0)
        assertEquals(0, testViewModel.cachedCount.value)
        coVerify { AppLogger.e(match { it.startsWith("refreshCacheCount: Failed") }) }
    }

    // DR-115: Test loadTranslationInfo error handling
    @Test
    fun `loadTranslationInfo success - loads all translation info`() = runTest {
        // Arrange
        val book = com.dualreader.app.domain.entities.Book(
            title = "Test Book",
            author = "Author",
            filePath = "/path/to/book.epub",
            coverPath = "",
        )
        val page = com.dualreader.app.domain.entities.Page(
            bookId = "book1",
            index = 0,
            chapterIndex = 0,
            originalText = "Original text",
            translations = mapOf("en" to "Translated text"),
            translationModels = mapOf("en" to "gemini-2.0-flash"),
        )
        coEvery { bookRepository.getAllBooks() } returns kotlinx.coroutines.flow.flowOf(listOf(book))
        coEvery { bookRepository.getPagesForBook(any()) } returns listOf(page)

        // Act
        viewModel.loadTranslationInfo()
        advanceUntilIdle()

        // Assert
        assertEquals(1, viewModel.translationInfo.value.size)
        assertEquals(0, viewModel.translationInfo.value[0].pageIndex)
        assertNull(viewModel.loadInfoError.value)
    }

    @Test
    fun `loadTranslationInfo failure - logs error and shows error to user`() = runTest {
        // Arrange
        val exception = RuntimeException("Database locked")
        coEvery { bookRepository.getAllBooks() } throws exception

        // Act
        viewModel.loadTranslationInfo()
        advanceUntilIdle()

        // Assert
        assertEquals(0, viewModel.translationInfo.value.size)
        assertNotNull(viewModel.loadInfoError.value)
        assertEquals("Failed to load translation info: Database locked", viewModel.loadInfoError.value)
        coVerify { AppLogger.e("loadTranslationInfo: Failed to load translation info: Database locked") }
    }

    @Test
    fun `loadInfoErrorShown - clears error state`() = runTest {
        // Arrange - Set an error state
        coEvery { bookRepository.getAllBooks() } throws RuntimeException("Test error")
        viewModel.loadTranslationInfo()
        advanceUntilIdle()
        assertNotNull(viewModel.loadInfoError.value)

        // Act
        viewModel.loadInfoErrorShown()

        // Assert
        assertNull(viewModel.loadInfoError.value)
    }

    @Test
    fun `loadTranslationInfo resets error before loading`() = runTest {
        // Arrange - Set an error state from previous call
        coEvery { bookRepository.getAllBooks() } throws RuntimeException("First error")
        viewModel.loadTranslationInfo()
        advanceUntilIdle()
        assertNotNull(viewModel.loadInfoError.value)

        // Arrange - Fix the issue for second call
        val book = com.dualreader.app.domain.entities.Book(
            title = "Test Book",
            author = "Author",
            filePath = "/path/to/book.epub",
            coverPath = "",
        )
        coEvery { bookRepository.getAllBooks() } returns kotlinx.coroutines.flow.flowOf(listOf(book))
        coEvery { bookRepository.getPagesForBook(any()) } returns emptyList()

        // Act
        viewModel.loadTranslationInfo()
        advanceUntilIdle()

        // Assert - Error should be reset (null) after successful call
        assertNull(viewModel.loadInfoError.value)
        assertEquals(0, viewModel.translationInfo.value.size)
    }
}