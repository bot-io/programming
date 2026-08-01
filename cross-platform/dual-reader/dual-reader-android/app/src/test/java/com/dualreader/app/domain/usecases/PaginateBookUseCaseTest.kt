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
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class PaginateBookUseCaseTest {

    private lateinit var bookRepo: BookRepository
    private lateinit var epubParser: EpubParserService
    private lateinit var useCase: PaginateBookUseCase

    @Before
    fun setUp() {
        bookRepo = mockk(relaxed = true)
        epubParser = mockk(relaxed = true)
        useCase = PaginateBookUseCase(bookRepo, epubParser)
    }

    private fun makeBook(id: String = "b1") = Book(
        id = id,
        title = "Test",
        author = "Author",
        filePath = "/path/book.epub",
        language = "en",
    )

    private val sampleParagraphs = listOf(
        ExtractedParagraph("First paragraph", 0),
        ExtractedParagraph("Second paragraph", 0),
        ExtractedParagraph("Third paragraph", 1),
    )

    // ── Success path ──────────────────────────────────────────────

    @Test
    fun `invoke returns success for valid book`() = runTest {
        coEvery { epubParser.extractParagraphs(any()) } returns sampleParagraphs
        coEvery { bookRepo.getPagesForBook(any()) } returns emptyList()

        val result = useCase(makeBook())

        assertTrue(result.isSuccess)
    }

    @Test
    fun `invoke marks book as IN_PROGRESS then COMPLETED`() = runTest {
        coEvery { epubParser.extractParagraphs(any()) } returns sampleParagraphs
        coEvery { bookRepo.getPagesForBook(any()) } returns emptyList()

        useCase(makeBook())

        coVerify {
            bookRepo.updateBook(match { it.paginationStatus == PaginationStatus.IN_PROGRESS })
        }
        coVerify {
            bookRepo.updateBook(match { it.paginationStatus == PaginationStatus.COMPLETED })
        }
    }

    @Test
    fun `invoke saves pages for new book`() = runTest {
        coEvery { epubParser.extractParagraphs(any()) } returns sampleParagraphs
        coEvery { bookRepo.getPagesForBook(any()) } returns emptyList()

        useCase(makeBook())

        coVerify { bookRepo.savePages(any()) }
    }

    @Test
    fun `invoke sets totalPages to paragraph count`() = runTest {
        coEvery { epubParser.extractParagraphs(any()) } returns sampleParagraphs
        coEvery { bookRepo.getPagesForBook(any()) } returns emptyList()

        useCase(makeBook())

        coVerify {
            bookRepo.updateBook(match { it.totalPages == 3 })
        }
    }

    // ── Empty paragraphs ──────────────────────────────────────────

    @Test
    fun `invoke fails when no paragraphs found`() = runTest {
        coEvery { epubParser.extractParagraphs(any()) } returns emptyList()

        val result = useCase(makeBook())

        assertTrue(result.isFailure)
    }

    @Test
    fun `invoke marks book as FAILED when no paragraphs`() = runTest {
        coEvery { epubParser.extractParagraphs(any()) } returns emptyList()

        useCase(makeBook())

        coVerify {
            bookRepo.updateBook(match { it.paginationStatus == PaginationStatus.FAILED })
        }
    }

    // ── Existing pages preservation ───────────────────────────────

    @Test
    fun `invoke preserves translations from existing pages by content match`() = runTest {
        val existingPage = Page(
            index = 99,
            bookId = "b1",
            chapterIndex = 0,
            originalText = "First paragraph",
            translations = mapOf("es" to "Primera párrafo"),
        )
        coEvery { epubParser.extractParagraphs(any()) } returns sampleParagraphs
        coEvery { bookRepo.getPagesForBook(any()) } returns listOf(existingPage)

        useCase(makeBook())

        // Should carry over the translation
        coVerify {
            bookRepo.savePages(match { pages ->
                pages.any { it.translations.containsKey("es") }
            })
        }
    }

    @Test
    fun `invoke marks FAILED on exception during extraction`() = runTest {
        coEvery { epubParser.extractParagraphs(any()) } throws RuntimeException("Parse error")

        val result = useCase(makeBook())

        assertTrue(result.isFailure)
        coVerify {
            bookRepo.updateBook(match { it.paginationStatus == PaginationStatus.FAILED })
        }
    }

    // ── Paragraph count change ────────────────────────────────────

    @Test
    fun `invoke does full re-save when paragraph count changes`() = runTest {
        val existingPages = listOf(
            Page(0, "b1", 0, "Old text 1"),
            Page(1, "b1", 0, "Old text 2"),
            Page(2, "b1", 0, "Old text 3"),
            Page(3, "b1", 0, "Old text 4"), // This index no longer exists
        )
        coEvery { epubParser.extractParagraphs(any()) } returns sampleParagraphs
        coEvery { bookRepo.getPagesForBook(any()) } returns existingPages

        useCase(makeBook())

        coVerify { bookRepo.deletePagesForBook(any()) }
    }

    // ── DR-052: CancellationException must propagate without marking book FAILED ──
    // ── DR-174: CancellationException must be rethrown (not wrapped in Result.failure()) ──

    @Test
    fun `cancellation propagates without marking book as FAILED`() = runTest {
        coEvery { epubParser.extractParagraphs(any()) } throws
            CancellationException("cancelled")

        // DR-174: CancellationException is rethrown, not wrapped in Result.failure()
        var caughtCancellation = false
        try {
            useCase(makeBook())
        } catch (e: CancellationException) {
            caughtCancellation = true
        }

        assertTrue("CancellationException should be rethrown", caughtCancellation)

        // Book must NOT be marked as FAILED on cancellation — it stays IN_PROGRESS
        coVerify(exactly = 0) {
            bookRepo.updateBook(match { it.paginationStatus == PaginationStatus.FAILED })
        }
    }
}
