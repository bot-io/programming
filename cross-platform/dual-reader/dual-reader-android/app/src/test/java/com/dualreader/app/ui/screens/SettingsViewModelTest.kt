package com.dualreader.app.ui.screens

import com.dualreader.app.domain.entities.Book
import com.dualreader.app.domain.entities.Page
import com.dualreader.app.domain.entities.ReadingSettings
import com.dualreader.app.domain.repositories.BookRepository
import com.dualreader.app.domain.repositories.SettingsRepository
import com.dualreader.app.domain.repositories.TranslationCacheRepository
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class SettingsViewModelTest {

    private val testDispatcher = StandardTestDispatcher()

    private lateinit var settingsRepo: SettingsRepository
    private lateinit var cacheRepo: TranslationCacheRepository
    private lateinit var bookRepo: BookRepository
    private lateinit var vm: SettingsViewModel

    private val defaultSettings = ReadingSettings()

    @Before
    fun setUp() {
        Dispatchers.setMain(testDispatcher)

        settingsRepo = mockk(relaxed = true)
        cacheRepo = mockk(relaxed = true)
        bookRepo = mockk(relaxed = true)

        every { settingsRepo.settings } returns flowOf(defaultSettings)
        coEvery { bookRepo.getTranslatedPageCount() } returns 0
        every { bookRepo.getAllBooks() } returns flowOf(emptyList())

        vm = SettingsViewModel(settingsRepo, cacheRepo, bookRepo)
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    // ── Initial State ──────────────────────────────────────────────

    @Test
    fun `initial cachedCount is loaded from repository`() = runTest {
        coEvery { bookRepo.getTranslatedPageCount() } returns 42
        vm = SettingsViewModel(settingsRepo, cacheRepo, bookRepo)
        advanceUntilIdle()
        coVerify { bookRepo.getTranslatedPageCount() }
    }

    @Test
    fun `initial translationInfo is empty`() {
        assertTrue(vm.translationInfo.value.isEmpty())
    }

    @Test
    fun `settings flow reflects repository defaults`() = runTest {
        advanceUntilIdle()
        assertEquals(defaultSettings, vm.settings.value)
    }

    // ── updateSettings ─────────────────────────────────────────────

    @Test
    fun `updateSettings delegates to repository`() = runTest {
        val newSettings = defaultSettings.copy(fontSize = 20f)
        vm.updateSettings(newSettings)
        advanceUntilIdle()
        coVerify { settingsRepo.updateSettings(any()) }
    }

    @Test
    fun `updateSettings with different language`() = runTest {
        val newSettings = defaultSettings.copy(targetLanguage = "bg")
        vm.updateSettings(newSettings)
        advanceUntilIdle()
        coVerify { settingsRepo.updateSettings(any()) }
    }

    // ── clearAllTranslations ───────────────────────────────────────

    @Test
    fun `clearAllTranslations clears cache and db`() = runTest {
        vm.clearAllTranslations()
        advanceUntilIdle()
        coVerify { cacheRepo.clearAll() }
        coVerify { bookRepo.clearAllTranslations() }
    }

    @Test
    fun `clearAllTranslations refreshes cache count`() = runTest {
        vm.clearAllTranslations()
        advanceUntilIdle()
        coVerify(atLeast = 2) { bookRepo.getTranslatedPageCount() }
    }

    @Test
    fun `clearAllTranslations resets translationInfo`() = runTest {
        vm.clearAllTranslations()
        advanceUntilIdle()
        assertTrue(vm.translationInfo.value.isEmpty())
    }

    // ── loadTranslationInfo ────────────────────────────────────────

    @Test
    fun `loadTranslationInfo with no books produces empty list`() = runTest {
        vm.loadTranslationInfo()
        advanceUntilIdle()
        assertTrue(vm.translationInfo.value.isEmpty())
    }

    @Test
    fun `loadTranslationInfo with books but no translations produces empty list`() = runTest {
        val book = Book(id = "b1", title = "Test", author = "A", filePath = "/p.epub")
        every { bookRepo.getAllBooks() } returns flowOf(listOf(book))
        coEvery { bookRepo.getPagesForBook("b1") } returns listOf(
            Page(index = 0, bookId = "b1", chapterIndex = 0, originalText = "untranslated"),
        )

        vm.loadTranslationInfo()
        advanceUntilIdle()
        assertTrue(vm.translationInfo.value.isEmpty())
    }

    @Test
    fun `loadTranslationInfo finds translated pages`() = runTest {
        val book = Book(id = "b1", title = "Test", author = "A", filePath = "/p.epub")
        every { bookRepo.getAllBooks() } returns flowOf(listOf(book))
        coEvery { bookRepo.getPagesForBook("b1") } returns listOf(
            Page(
                index = 0, bookId = "b1", chapterIndex = 0, originalText = "Hello",
                translations = mapOf("bg" to "Здравей"),
                translationModels = mapOf("bg" to "gemini-2.5-flash"),
            ),
            Page(
                index = 1, bookId = "b1", chapterIndex = 0, originalText = "World",
                translations = mapOf("bg" to "Свят", "ru" to "Мир"),
            ),
        )

        vm.loadTranslationInfo()
        advanceUntilIdle()
        assertEquals(2, vm.translationInfo.value.size)
        assertEquals(0, vm.translationInfo.value[0].pageIndex)
        assertEquals("Здравей", vm.translationInfo.value[0].languages["bg"])
    }

    @Test
    fun `loadTranslationInfo truncates long translations to 80 chars`() = runTest {
        val longText = "A".repeat(200)
        val expectedSnippet = "A".repeat(80) + "…"

        val book = Book(id = "b1", title = "Test", author = "A", filePath = "/p.epub")
        every { bookRepo.getAllBooks() } returns flowOf(listOf(book))
        coEvery { bookRepo.getPagesForBook("b1") } returns listOf(
            Page(
                index = 0, bookId = "b1", chapterIndex = 0, originalText = "orig",
                translations = mapOf("bg" to longText),
            ),
        )

        vm.loadTranslationInfo()
        advanceUntilIdle()
        assertEquals(1, vm.translationInfo.value.size)
        val languages = vm.translationInfo.value[0].languages
        assertEquals(expectedSnippet, languages["bg"])
    }

    @Test
    fun `loadTranslationInfo handles multiple books`() = runTest {
        val b1 = Book(id = "b1", title = "Book1", author = "A", filePath = "/p1.epub")
        val b2 = Book(id = "b2", title = "Book2", author = "B", filePath = "/p2.epub")
        every { bookRepo.getAllBooks() } returns flowOf(listOf(b1, b2))
        coEvery { bookRepo.getPagesForBook("b1") } returns listOf(
            Page(
                index = 0, bookId = "b1", chapterIndex = 0, originalText = "a",
                translations = mapOf("bg" to "а"),
            ),
        )
        coEvery { bookRepo.getPagesForBook("b2") } returns listOf(
            Page(
                index = 0, bookId = "b2", chapterIndex = 0, originalText = "b",
                translations = mapOf("bg" to "б"),
            ),
            Page(
                index = 1, bookId = "b2", chapterIndex = 0, originalText = "c",
                translations = mapOf("bg" to "ц"),
            ),
        )

        vm.loadTranslationInfo()
        advanceUntilIdle()
        assertEquals(3, vm.translationInfo.value.size)
    }

    @Test
    fun `loadTranslationInfo skips pages without translations`() = runTest {
        val book = Book(id = "b1", title = "Test", author = "A", filePath = "/p.epub")
        every { bookRepo.getAllBooks() } returns flowOf(listOf(book))
        coEvery { bookRepo.getPagesForBook("b1") } returns listOf(
            Page(index = 0, bookId = "b1", chapterIndex = 0, originalText = "untranslated"),
            Page(
                index = 1, bookId = "b1", chapterIndex = 0, originalText = "Hello",
                translations = mapOf("bg" to "Здравей"),
            ),
            Page(index = 2, bookId = "b1", chapterIndex = 0, originalText = "also untranslated"),
        )

        vm.loadTranslationInfo()
        advanceUntilIdle()
        assertEquals(1, vm.translationInfo.value.size)
        assertEquals(1, vm.translationInfo.value[0].pageIndex)
    }
}
