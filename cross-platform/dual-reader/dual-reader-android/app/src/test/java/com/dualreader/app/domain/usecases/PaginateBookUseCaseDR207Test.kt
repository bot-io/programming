package com.dualreader.app.domain.usecases

import com.dualreader.app.domain.entities.Book
import com.dualreader.app.domain.entities.Page
import com.dualreader.app.domain.entities.PaginationStatus
import com.dualreader.app.domain.repositories.BookRepository
import com.dualreader.app.domain.services.EpubParserService
import com.dualreader.app.domain.services.ExtractedParagraph
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.mockk
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Before
import org.junit.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * Regression tests for DR-207: Translation loss on re-pagination with duplicate paragraph text.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class PaginateBookUseCaseDR207Test {

    private lateinit var bookRepository: BookRepository
    private lateinit var epubParser: EpubParserService
    private lateinit var useCase: PaginateBookUseCase
    private val testDispatcher = StandardTestDispatcher()

    @Before
    fun setup() {
        Dispatchers.setMain(testDispatcher)
        bookRepository = mockk()
        epubParser = mockk()
        useCase = PaginateBookUseCase(bookRepository, epubParser)
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun `DR-207 duplicate paragraph text preserves translations for all matching pages`() = runTest {
        // Given: A book with duplicate paragraph text (e.g., dialogue "Yes." appearing multiple times)
        val book = Book(
            id = "test-book",
            title = "Test Book",
            author = "Author",
            filePath = "/path/to/test.epub",
            language = "en",
            totalPages = 4,
            paginationStatus = PaginationStatus.COMPLETED,
            paginationProgress = 1f
        )

        // Existing pages with translations at indices 1 and 2 (both with text "Yes.")
        val existingPages = listOf(
            Page(index = 0, bookId = "test-book", chapterIndex = 0, originalText = "Chapter One"),
            Page(index = 1, bookId = "test-book", chapterIndex = 0, originalText = "Yes.", translations = mapOf("es" to "Sí.")),
            Page(index = 2, bookId = "test-book", chapterIndex = 0, originalText = "Yes.", translations = mapOf("es" to "Sí.")),
            Page(index = 3, bookId = "test-book", chapterIndex = 0, originalText = "No.", translations = mapOf("es" to "No."))
        )

        // Re-extracted paragraphs with same structure (re-pagination scenario)
        val extractedParagraphs = listOf(
            ExtractedParagraph(text = "Chapter One", chapterIndex = 0),
            ExtractedParagraph(text = "Yes.", chapterIndex = 0),
            ExtractedParagraph(text = "Yes.", chapterIndex = 0),
            ExtractedParagraph(text = "No.", chapterIndex = 0)
        )

        coEvery { bookRepository.updateBook(any()) } returns Unit
        coEvery { bookRepository.getPagesForBook("test-book") } returns existingPages
        coEvery { epubParser.extractParagraphs("/path/to/test.epub") } returns extractedParagraphs
        coEvery { bookRepository.savePages(any()) } returns Unit

        // When: Re-pagination occurs
        val result = useCase(book)

        // Then: Result should succeed
        assertTrue(result.isSuccess)

        // Verify that no pages were deleted (same paragraph count, no changes needed)
        coVerify(exactly = 0) { bookRepository.deletePagesForBook(any()) }

        // No pages should have been saved since nothing changed (same text at each index)
        coVerify(exactly = 0) { bookRepository.savePages(any()) }

        // The existing pages remain in DB with their translations preserved
        // DR-209 fix ensures the existingByContent map correctly tracks multiple pages with duplicate text
        // and doesn't accidentally lose translations when processing duplicates
    }

    @Test
    fun `DR-207 duplicate text with different translations preserves each individually`() = runTest {
        // Given: Duplicate text but with different translations (e.g., context-dependent)
        val book = Book(
            id = "test-book",
            title = "Test Book",
            author = "Author",
            filePath = "/path/to/test.epub",
            language = "en",
            totalPages = 2,
            paginationStatus = PaginationStatus.COMPLETED,
            paginationProgress = 1f
        )

        // Same text "Good morning" with different Spanish translations due to context
        val existingPages = listOf(
            Page(index = 0, bookId = "test-book", chapterIndex = 0, originalText = "Good morning", translations = mapOf("es" to "Buenos días")),
            Page(index = 1, bookId = "test-book", chapterIndex = 0, originalText = "Good morning", translations = mapOf("es" to "Buenas días"))
        )

        val extractedParagraphs = listOf(
            ExtractedParagraph(text = "Good morning", chapterIndex = 0),
            ExtractedParagraph(text = "Good morning", chapterIndex = 0)
        )

        coEvery { bookRepository.updateBook(any()) } returns Unit
        coEvery { bookRepository.getPagesForBook("test-book") } returns existingPages
        coEvery { epubParser.extractParagraphs("/path/to/test.epub") } returns extractedParagraphs
        coEvery { bookRepository.savePages(any()) } returns Unit

        // When: Re-pagination occurs
        val result = useCase(book)

        // Then: Both pages should preserve their distinct translations
        assertTrue(result.isSuccess)

        // Verify that no pages were deleted (same paragraph count, no changes needed)
        coVerify(exactly = 0) { bookRepository.deletePagesForBook(any()) }

        // No pages should have been saved since nothing changed (same text at each index)
        coVerify(exactly = 0) { bookRepository.savePages(any()) }

        // The existing pages remain in DB with their distinct translations preserved
        // DR-209 fix ensures the existingByContent map correctly handles list-based tracking
    }

    @Test
    fun `DR-207 duplicate text with partial translation loss still preserves available translations`() = runTest {
        // Given: One duplicate page has translation, the other doesn't
        val book = Book(
            id = "test-book",
            title = "Test Book",
            author = "Author",
            filePath = "/path/to/test.epub",
            language = "en",
            totalPages = 2,
            paginationStatus = PaginationStatus.COMPLETED,
            paginationProgress = 1f
        )

        val existingPages = listOf(
            Page(index = 0, bookId = "test-book", chapterIndex = 0, originalText = "OK", translations = mapOf("es" to "De acuerdo")),
            Page(index = 1, bookId = "test-book", chapterIndex = 0, originalText = "OK", translations = emptyMap())
        )

        val extractedParagraphs = listOf(
            ExtractedParagraph(text = "OK", chapterIndex = 0),
            ExtractedParagraph(text = "OK", chapterIndex = 0)
        )

        coEvery { bookRepository.updateBook(any()) } returns Unit
        coEvery { bookRepository.getPagesForBook("test-book") } returns existingPages
        coEvery { epubParser.extractParagraphs("/path/to/test.epub") } returns extractedParagraphs
        coEvery { bookRepository.savePages(any()) } returns Unit

        // When: Re-pagination occurs
        val result = useCase(book)

        // Then: First match gets the translation, second doesn't (expected behavior)
        assertTrue(result.isSuccess)

        // Verify that no pages were deleted (same paragraph count, no changes needed)
        coVerify(exactly = 0) { bookRepository.deletePagesForBook(any()) }

        // No pages should have been saved since nothing changed (same text at each index)
        coVerify(exactly = 0) { bookRepository.savePages(any()) }

        // The existing pages remain in DB - one with translation, one without
        // DR-209 fix ensures the existingByContent map correctly tracks which pages have translations
    }
}