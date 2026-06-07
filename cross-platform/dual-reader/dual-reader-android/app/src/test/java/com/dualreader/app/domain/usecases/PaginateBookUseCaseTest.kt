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
}
