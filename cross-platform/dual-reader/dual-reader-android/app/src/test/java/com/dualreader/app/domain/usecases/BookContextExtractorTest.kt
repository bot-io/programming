package com.dualreader.app.domain.usecases

import com.dualreader.app.domain.entities.Book
import com.dualreader.app.domain.entities.BookChapter
import com.dualreader.app.domain.entities.Page
import com.dualreader.app.domain.entities.PaginationStatus
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class BookContextExtractorTest {

    private fun makeBook(title: String = "Test Book", author: String = "Test Author") = Book(
        id = "b1",
        title = title,
        author = author,
        filePath = "/path/book.epub",
        language = "en",
    )

    private fun makePage(index: Int, text: String, bookId: String = "b1") = Page(
        index = index,
        bookId = bookId,
        chapterIndex = 0,
        originalText = text,
    )

    // ── extract ───────────────────────────────────────────────────

    @Test
    fun `extract returns BookContext with title and author from book`() {
        val ctx = BookContextExtractor.extract(makeBook("My Novel", "Jane Doe"), emptyList())
        assertEquals("My Novel", ctx.title)
        assertEquals("Jane Doe", ctx.author)
    }

    @Test
    fun `extract returns language from book`() {
        val ctx = BookContextExtractor.extract(makeBook(), emptyList())
        assertEquals("en", ctx.language)
    }

    @Test
    fun `extract with no pages returns empty openingText`() {
        val ctx = BookContextExtractor.extract(makeBook(), emptyList())
        assertEquals("", ctx.openingText)
    }

    @Test
    fun `extract takes first OPENING_PAGES_COUNT pages`() {
        val pages = (0..9).map { makePage(it, "Paragraph $it") }
        val ctx = BookContextExtractor.extract(makeBook(), pages)
        val paragraphs = ctx.openingText.split("\n\n")
        assertEquals(BookContextExtractor.OPENING_PAGES_COUNT, paragraphs.size)
        assertTrue(ctx.openingText.contains("Paragraph 0"))
        assertTrue(ctx.openingText.contains("Paragraph 2"))
        assertTrue(!ctx.openingText.contains("Paragraph 3"))
    }

    @Test
    fun `extract sorts pages by index before taking`() {
        val pages = listOf(
            makePage(2, "Third"),
            makePage(0, "First"),
            makePage(1, "Second"),
        )
        val ctx = BookContextExtractor.extract(makeBook(), pages)
        val paragraphs = ctx.openingText.split("\n\n")
        assertEquals("First", paragraphs[0])
        assertEquals("Second", paragraphs[1])
        assertEquals("Third", paragraphs[2])
    }

    @Test
    fun `extract truncates opening text to MAX_OPENING_CHARS`() {
        val longText = "a".repeat(BookContextExtractor.MAX_OPENING_CHARS + 500)
        val pages = listOf(makePage(0, longText))
        val ctx = BookContextExtractor.extract(makeBook(), pages)
        assertTrue(ctx.openingText.length <= BookContextExtractor.MAX_OPENING_CHARS)
    }

    @Test
    fun `extract filters out empty paragraphs`() {
        val pages = listOf(
            makePage(0, "Real content"),
            makePage(1, ""),
            makePage(2, "   "),
        )
        val ctx = BookContextExtractor.extract(makeBook(), pages)
        assertEquals("Real content", ctx.openingText.trim())
    }

    @Test
    fun `extract with fewer pages than OPENING_PAGES_COUNT uses all`() {
        val pages = listOf(makePage(0, "Only page"))
        val ctx = BookContextExtractor.extract(makeBook(), pages)
        assertEquals("Only page", ctx.openingText.trim())
    }

    @Test
    fun `extract with null language`() {
        val book = makeBook().copy(language = null)
        val ctx = BookContextExtractor.extract(book, emptyList())
        assertEquals(null, ctx.language)
    }

    @Test
    fun `OPENING_PAGES_COUNT is 3`() {
        assertEquals(3, BookContextExtractor.OPENING_PAGES_COUNT)
    }

    @Test
    fun `MAX_OPENING_CHARS is 2000`() {
        assertEquals(2000, BookContextExtractor.MAX_OPENING_CHARS)
    }
}
