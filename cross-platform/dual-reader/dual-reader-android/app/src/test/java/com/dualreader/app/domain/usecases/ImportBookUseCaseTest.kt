package com.dualreader.app.domain.usecases

import com.dualreader.app.domain.entities.Book
import com.dualreader.app.domain.entities.BookChapter
import com.dualreader.app.domain.entities.PaginationStatus
import com.dualreader.app.domain.repositories.BookRepository
import com.dualreader.app.domain.services.EpubParserService
import com.dualreader.app.domain.services.ParsedEpub
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.mockk
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class ImportBookUseCaseTest {

    private lateinit var bookRepository: BookRepository
    private lateinit var epubParser: EpubParserService
    private lateinit var useCase: ImportBookUseCase

    @Before
    fun setUp() {
        bookRepository = mockk(relaxed = true)
        epubParser = mockk()
        useCase = ImportBookUseCase(bookRepository, epubParser)
    }

    @Test
    fun `invoke - successful import returns book with parsed metadata`() = runTest {
        // Given
        val parsedEpub = ParsedEpub(
            title = "The Great Gatsby",
            author = "F. Scott Fitzgerald",
            language = "en",
            chapters = listOf(
                BookChapter(index = 0, title = "Chapter 1"),
                BookChapter(index = 1, title = "Chapter 2"),
            ),
        )
        coEvery { epubParser.parseMetadata("/books/gatsby.epub") } returns parsedEpub

        // When
        val result = useCase("/books/gatsby.epub")

        // Then
        assertTrue(result.isSuccess)
        val book = result.getOrThrow()
        assertEquals("The Great Gatsby", book.title)
        assertEquals("F. Scott Fitzgerald", book.author)
        assertEquals("en", book.language)
        assertEquals(2, book.chapters.size)
        assertEquals(PaginationStatus.NOT_STARTED, book.paginationStatus)
        assertEquals("/books/gatsby.epub", book.filePath)
    }

    @Test
    fun `invoke - persists book to repository`() = runTest {
        // Given
        coEvery { epubParser.parseMetadata(any()) } returns ParsedEpub(
            title = "Test Book",
            author = "Test Author",
            chapters = emptyList(),
        )

        // When
        useCase("/test.epub")

        // Then
        coVerify { bookRepository.insertBook(match { it.title == "Test Book" }) }
    }

    @Test
    fun `invoke - parser failure returns failure result`() = runTest {
        // Given
        coEvery { epubParser.parseMetadata(any()) } throws RuntimeException("Corrupt EPUB")

        // When
        val result = useCase("/corrupt.epub")

        // Then
        assertTrue(result.isFailure)
        assertTrue(result.exceptionOrNull()!!.message!!.contains("Corrupt EPUB"))
    }

    @Test
    fun `invoke - book without cover has empty coverPath`() = runTest {
        // Given
        coEvery { epubParser.parseMetadata(any()) } returns ParsedEpub(
            title = "No Cover Book",
            author = "Author",
            coverImageBytes = null,
            chapters = emptyList(),
        )

        // When
        val book = useCase("/nocover.epub").getOrThrow()

        // Then
        assertEquals("", book.coverPath)
    }

    @Test
    fun `invoke - book with chapters preserves chapter structure`() = runTest {
        // Given
        val chapters = (1..5).map { i ->
            BookChapter(index = i - 1, title = "Chapter $i")
        }
        coEvery { epubParser.parseMetadata(any()) } returns ParsedEpub(
            title = "Big Book",
            author = "Author",
            chapters = chapters,
        )

        // When
        val book = useCase("/big.epub").getOrThrow()

        // Then
        assertEquals(5, book.chapters.size)
        assertEquals("Chapter 3", book.chapters[2].title)
    }
}
