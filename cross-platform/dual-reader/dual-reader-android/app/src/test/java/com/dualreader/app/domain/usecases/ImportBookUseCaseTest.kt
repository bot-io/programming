package com.dualreader.app.domain.usecases

import com.dualreader.app.domain.entities.Book
import com.dualreader.app.domain.entities.BookChapter
import com.dualreader.app.domain.entities.PaginationStatus
import com.dualreader.app.domain.repositories.BookRepository
import com.dualreader.app.domain.services.ExtractedParagraph
import com.dualreader.app.domain.services.EpubParserService
import com.dualreader.app.domain.services.ParsedEpub
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.mockk
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class ImportBookUseCaseTest {

    private lateinit var bookRepo: BookRepository
    private lateinit var epubParser: EpubParserService
    private lateinit var useCase: ImportBookUseCase

    @Before
    fun setUp() {
        bookRepo = mockk(relaxed = true)
        epubParser = mockk(relaxed = true)
        useCase = ImportBookUseCase(bookRepo, epubParser)
    }

    private val sampleParsed = ParsedEpub(
        title = "Test Book",
        author = "Test Author",
        language = "en",
        chapters = listOf(BookChapter(0, "Chapter 1")),
        coverImageBytes = null,
    )

    // ── Success path ──────────────────────────────────────────────

    @Test
    fun `invoke returns success with Book on valid EPUB`() = runTest {
        coEvery { epubParser.parseMetadata("/path/book.epub") } returns sampleParsed
        coEvery { bookRepo.insertBook(any()) } returns Unit

        val result = useCase("/path/book.epub")

        assertTrue(result.isSuccess)
        assertEquals("Test Book", result.getOrNull()?.title)
        assertEquals("Test Author", result.getOrNull()?.author)
    }

    @Test
    fun `invoke generates unique book ID`() = runTest {
        coEvery { epubParser.parseMetadata(any()) } returns sampleParsed

        val result1 = useCase("path1.epub")
        val result2 = useCase("path2.epub")

        assertNotEquals(result1.getOrNull()?.id, result2.getOrNull()?.id)
    }

    @Test
    fun `invoke sets paginationStatus to NOT_STARTED`() = runTest {
        coEvery { epubParser.parseMetadata(any()) } returns sampleParsed

        val result = useCase("book.epub")

        assertEquals(PaginationStatus.NOT_STARTED, result.getOrNull()?.paginationStatus)
    }

    @Test
    fun `invoke stores filePath`() = runTest {
        coEvery { epubParser.parseMetadata("/books/test.epub") } returns sampleParsed

        val result = useCase("/books/test.epub")

        assertEquals("/books/test.epub", result.getOrNull()?.filePath)
    }

    @Test
    fun `invoke saves book to repository`() = runTest {
        coEvery { epubParser.parseMetadata(any()) } returns sampleParsed

        useCase("book.epub")

        coVerify { bookRepo.insertBook(any()) }
    }

    // ── Cover image ───────────────────────────────────────────────

    @Test
    fun `invoke saves cover image when present`() = runTest {
        val coverBytes = byteArrayOf(1, 2, 3)
        val parsed = sampleParsed.copy(coverImageBytes = coverBytes)
        coEvery { epubParser.parseMetadata(any()) } returns parsed
        coEvery { bookRepo.saveCoverImage(coverBytes, any()) } returns "/covers/abc.png"

        val result = useCase("book.epub")

        assertEquals("/covers/abc.png", result.getOrNull()?.coverPath)
    }

    @Test
    fun `invoke sets empty coverPath when no cover image`() = runTest {
        coEvery { epubParser.parseMetadata(any()) } returns sampleParsed.copy(coverImageBytes = null)

        val result = useCase("book.epub")

        assertEquals("", result.getOrNull()?.coverPath)
    }

    @Test
    fun `invoke sets empty coverPath when saveCoverImage returns null`() = runTest {
        val parsed = sampleParsed.copy(coverImageBytes = byteArrayOf(1))
        coEvery { epubParser.parseMetadata(any()) } returns parsed
        coEvery { bookRepo.saveCoverImage(any(), any()) } returns null

        val result = useCase("book.epub")

        assertEquals("", result.getOrNull()?.coverPath)
    }

    // ── Language ──────────────────────────────────────────────────

    @Test
    fun `invoke stores language from parsed EPUB`() = runTest {
        coEvery { epubParser.parseMetadata(any()) } returns sampleParsed.copy(language = "fr")

        val result = useCase("book.epub")

        assertEquals("fr", result.getOrNull()?.language)
    }

    @Test
    fun `invoke stores null when language is null`() = runTest {
        coEvery { epubParser.parseMetadata(any()) } returns sampleParsed.copy(language = null)

        val result = useCase("book.epub")

        assertNull(result.getOrNull()?.language)
    }

    // ── Failure path ──────────────────────────────────────────────

    @Test
    fun `invoke returns failure when EPUB parsing fails`() = runTest {
        coEvery { epubParser.parseMetadata(any()) } throws RuntimeException("Corrupt EPUB")

        val result = useCase("bad.epub")

        assertTrue(result.isFailure)
        assertEquals("Corrupt EPUB", result.exceptionOrNull()?.message)
    }

    @Test
    fun `invoke returns failure when insertBook throws`() = runTest {
        coEvery { epubParser.parseMetadata(any()) } returns sampleParsed
        coEvery { bookRepo.insertBook(any()) } throws RuntimeException("DB error")

        val result = useCase("book.epub")

        assertTrue(result.isFailure)
    }

    // ── Chapters ──────────────────────────────────────────────────

    @Test
    fun `invoke stores chapters from parsed EPUB`() = runTest {
        val chapters = listOf(
            BookChapter(0, "Ch1"),
            BookChapter(1, "Ch2"),
        )
        coEvery { epubParser.parseMetadata(any()) } returns sampleParsed.copy(chapters = chapters)

        val result = useCase("book.epub")

        assertEquals(2, result.getOrNull()?.chapters?.size)
        assertEquals("Ch1", result.getOrNull()?.chapters?.first()?.title)
    }
}
