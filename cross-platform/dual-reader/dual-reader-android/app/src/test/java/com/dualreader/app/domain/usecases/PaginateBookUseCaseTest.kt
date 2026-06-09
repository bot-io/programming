package com.dualreader.app.domain.usecases

import com.dualreader.app.domain.entities.Book
import com.dualreader.app.domain.entities.BookChapter
import com.dualreader.app.domain.entities.PaginationStatus
import com.dualreader.app.domain.repositories.BookRepository
import com.dualreader.app.domain.services.EpubParserService
import com.dualreader.app.domain.services.PaginationService
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.mockk
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class PaginateBookUseCaseTest {

    private lateinit var bookRepository: BookRepository
    private lateinit var epubParser: EpubParserService
    private lateinit var paginationService: PaginationService
    private lateinit var useCase: PaginateBookUseCase

    private val testBook = Book(
        id = "book-1",
        title = "Test Book",
        author = "Author",
        filePath = "/test.epub",
        chapters = listOf(BookChapter(index = 0, title = "Ch 1")),
    )

    @Before
    fun setUp() {
        bookRepository = mockk(relaxed = true)
        epubParser = mockk()
        paginationService = mockk()
        useCase = PaginateBookUseCase(bookRepository, epubParser, paginationService)
    }

    @Test
    fun `invoke - sets status to IN_PROGRESS at start`() = runTest {
        // Given
        coEvery { epubParser.extractFullText(any()) } returns "Hello world"
        coEvery { paginationService.paginate(any(), any(), any(), any()) } returns listOf("Hello world")

        // When
        useCase(testBook, screenWidth = 1080, screenHeight = 1920)

        // Then
        coVerify {
            bookRepository.updateBook(match { it.paginationStatus == PaginationStatus.IN_PROGRESS })
        }
    }

    @Test
    fun `invoke - successful pagination marks COMPLETED`() = runTest {
        // Given
        val pages = listOf("Page 1 text", "Page 2 text", "Page 3 text")
        coEvery { epubParser.extractFullText(any()) } returns "Full text"
        coEvery { paginationService.paginate(any(), any(), any(), any()) } returns pages

        // When
        val result = useCase(testBook, screenWidth = 1080, screenHeight = 1920)

        // Then
        assertTrue(result.isSuccess)
        coVerify {
            bookRepository.updateBook(match {
                it.paginationStatus == PaginationStatus.COMPLETED &&
                it.totalPages == 3 &&
                it.paginationProgress == 1f
            })
        }
    }

    @Test
    fun `invoke - saves paginated pages to repository`() = runTest {
        // Given
        val pages = listOf("Page 1", "Page 2")
        coEvery { epubParser.extractFullText(any()) } returns "Text"
        coEvery { paginationService.paginate(any(), any(), any(), any()) } returns pages

        // When
        useCase(testBook, screenWidth = 1080, screenHeight = 1920)

        // Then
        coVerify { bookRepository.savePages(match { it.size == 2 }) }
    }

    @Test
    fun `invoke - pagination failure marks book as FAILED`() = runTest {
        // Given
        coEvery { epubParser.extractFullText(any()) } throws RuntimeException("Parse error")

        // When
        val result = useCase(testBook, screenWidth = 1080, screenHeight = 1920)

        // Then
        assertTrue(result.isFailure)
        coVerify {
            bookRepository.updateBook(match { it.paginationStatus == PaginationStatus.FAILED })
        }
    }

    @Test
    fun `invoke - passes correct pagination parameters`() = runTest {
        // Given
        coEvery { epubParser.extractFullText(any()) } returns "Text"
        coEvery {
            paginationService.paginate(
                text = "Text",
                availableWidth = 1080,
                availableHeight = 1920,
                fontSize = 18f,
                lineHeight = 1.8f,
                margins = 24,
            )
        } returns listOf("Page 1")

        // When
        useCase(testBook, screenWidth = 1080, screenHeight = 1920, fontSize = 18f, lineHeight = 1.8f, margins = 24)

        // Then
        coVerify {
            paginationService.paginate(
                text = "Text",
                availableWidth = 1080,
                availableHeight = 1920,
                fontSize = 18f,
                lineHeight = 1.8f,
                margins = 24,
            )
        }
    }

    @Test
    fun `re-pagination preserves translations by content matching`() = runTest {
        // Given: existing pages with translations
        val existingPages = listOf(
            com.dualreader.app.domain.entities.Page(
                index = 0, bookId = "book-1", chapterIndex = 0, originalText = "Hello world",
                translations = mapOf("es" to "Hola mundo"),
            ),
            com.dualreader.app.domain.entities.Page(
                index = 1, bookId = "book-1", chapterIndex = 0, originalText = "Goodbye world",
                translations = mapOf("es" to "Adiós mundo"),
            ),
        )
        coEvery { bookRepository.getPagesForBook("book-1") } returns existingPages
        coEvery { epubParser.extractFullText(any()) } returns "Full text"
        // Re-pagination with different screen size — same content, different order
        coEvery { paginationService.paginate(any(), any(), any(), any()) } returns
            listOf("Goodbye world", "Hello world")

        // When
        useCase(testBook, screenWidth = 800, screenHeight = 1200)

        // Then: translations are preserved, indices updated
        coVerify {
            bookRepository.savePages(match { saved ->
                saved.size == 2 &&
                saved[0].originalText == "Goodbye world" &&
                saved[0].index == 0 &&
                saved[0].translations["es"] == "Adiós mundo" &&
                saved[1].originalText == "Hello world" &&
                saved[1].index == 1 &&
                saved[1].translations["es"] == "Hola mundo"
            })
        }
    }

    @Test
    fun `re-pagination preserves translations even when content moves to different index`() = runTest {
        // Given: page 5 has a translation
        val existingPages = listOf(
            com.dualreader.app.domain.entities.Page(
                index = 5, bookId = "book-1", chapterIndex = 0, originalText = "Chapter two begins here",
                translations = mapOf("es" to "El capítulo dos comienza aquí", "fr" to "Le chapitre deux commence ici"),
            ),
        )
        coEvery { bookRepository.getPagesForBook("book-1") } returns existingPages
        coEvery { epubParser.extractFullText(any()) } returns "Full text"
        // After re-paginating with fullscreen, the same content now lands at index 2
        coEvery { paginationService.paginate(any(), any(), any(), any()) } returns
            listOf("Some text", "More text", "Chapter two begins here")

        // When
        useCase(testBook, screenWidth = 1256, screenHeight = 1268)

        // Then: translation carried over with BOTH languages, new index
        coVerify {
            bookRepository.savePages(match { saved ->
                val page2 = saved[2]
                page2.index == 2 &&
                page2.originalText == "Chapter two begins here" &&
                page2.translations["es"] == "El capítulo dos comienza aquí" &&
                page2.translations["fr"] == "Le chapitre deux commence ici"
            })
        }
    }

    @Test
    fun `re-pagination creates fresh pages for content without translations`() = runTest {
        // Given: existing pages have no translations
        val existingPages = listOf(
            com.dualreader.app.domain.entities.Page(
                index = 0, bookId = "book-1", chapterIndex = 0, originalText = "Hello world",
                translations = emptyMap(),
            ),
        )
        coEvery { bookRepository.getPagesForBook("book-1") } returns existingPages
        coEvery { epubParser.extractFullText(any()) } returns "Full text"
        coEvery { paginationService.paginate(any(), any(), any(), any()) } returns
            listOf("Hello world", "New page")

        // When
        useCase(testBook, screenWidth = 800, screenHeight = 1200)

        // Then: no translations carried over, new pages created normally
        coVerify {
            bookRepository.savePages(match { saved ->
                saved.size == 2 &&
                saved.all { it.translations.isEmpty() }
            })
        }
    }
}
