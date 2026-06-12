package com.dualreader.app.domain.usecases

import com.dualreader.app.domain.entities.Book
import com.dualreader.app.domain.entities.BookFormat
import com.dualreader.app.domain.entities.Page
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class BookContextExtractorTest {

    private fun makeBook(
        title: String = "Test Book",
        author: String = "Test Author",
        language: String? = "en",
    ) = Book(
        title = title,
        author = author,
        filePath = "/test.epub",
        format = BookFormat.EPUB,
        language = language,
    )

    private fun makePage(index: Int, text: String) = Page(
        index = index,
        bookId = "test-book",
        originalText = text,
        chapterIndex = 0,
    )

    // ── extract ─────────────────────────────────────────────────────────────

    @Test
    fun `extract returns context with title and author`() {
        val book = makeBook(title = "War and Peace", author = "Tolstoy")
        val pages = listOf(makePage(0, "First page text."))

        val ctx = BookContextExtractor.extract(book, pages)

        assertEquals("War and Peace", ctx.title)
        assertEquals("Tolstoy", ctx.author)
    }

    @Test
    fun `extract includes language from book`() {
        val book = makeBook(language = "fr")
        val pages = listOf(makePage(0, "Text"))

        val ctx = BookContextExtractor.extract(book, pages)

        assertEquals("fr", ctx.language)
    }

    @Test
    fun `extract handles null language`() {
        val book = makeBook(language = null)
        val pages = listOf(makePage(0, "Text"))

        val ctx = BookContextExtractor.extract(book, pages)

        assertNull(ctx.language)
    }

    @Test
    fun `extract takes first 3 pages as opening text`() {
        val book = makeBook()
        val pages = listOf(
            makePage(0, "Page zero content."),
            makePage(1, "Page one content."),
            makePage(2, "Page two content."),
            makePage(3, "Page three content."),
            makePage(4, "Page four content."),
        )

        val ctx = BookContextExtractor.extract(book, pages)

        assertTrue(ctx.openingText.contains("Page zero content."))
        assertTrue(ctx.openingText.contains("Page one content."))
        assertTrue(ctx.openingText.contains("Page two content."))
        assertTrue("Should NOT contain page 3", !ctx.openingText.contains("Page three"))
    }

    @Test
    fun `extract works with fewer than 3 pages`() {
        val book = makeBook()
        val pages = listOf(
            makePage(0, "Only page."),
        )

        val ctx = BookContextExtractor.extract(book, pages)

        assertEquals("Only page.", ctx.openingText)
    }

    @Test
    fun `extract joins pages with double newline`() {
        val book = makeBook()
        val pages = listOf(
            makePage(0, "Para one."),
            makePage(1, "Para two."),
        )

        val ctx = BookContextExtractor.extract(book, pages)

        assertEquals("Para one.\n\nPara two.", ctx.openingText)
    }

    @Test
    fun `extract truncates opening text to MAX_OPENING_CHARS`() {
        val book = makeBook()
        val longText = "A".repeat(BookContextExtractor.MAX_OPENING_CHARS + 500)
        val pages = listOf(
            makePage(0, longText),
        )

        val ctx = BookContextExtractor.extract(book, pages)

        assertEquals(BookContextExtractor.MAX_OPENING_CHARS, ctx.openingText.length)
    }

    @Test
    fun `extract filters empty pages`() {
        val book = makeBook()
        val pages = listOf(
            makePage(0, "Good page."),
            makePage(1, "   "),
            makePage(2, "Another good page."),
        )

        val ctx = BookContextExtractor.extract(book, pages)

        assertEquals("Good page.\n\nAnother good page.", ctx.openingText)
    }

    @Test
    fun `extract sorts pages by index`() {
        val book = makeBook()
        val pages = listOf(
            makePage(2, "Third page."),
            makePage(0, "First page."),
            makePage(1, "Second page."),
        )

        val ctx = BookContextExtractor.extract(book, pages)

        assertEquals("First page.\n\nSecond page.\n\nThird page.", ctx.openingText)
    }

    @Test
    fun `extract with empty pages list returns empty opening text`() {
        val book = makeBook()
        val ctx = BookContextExtractor.extract(book, emptyList())

        assertEquals("", ctx.openingText)
    }

    @Test
    fun `extract with all empty pages returns empty opening text`() {
        val book = makeBook()
        val pages = listOf(
            makePage(0, "  "),
            makePage(1, ""),
            makePage(2, "\n"),
        )

        val ctx = BookContextExtractor.extract(book, pages)

        assertEquals("", ctx.openingText)
    }

    // ── BookContext data class ──────────────────────────────────────────────

    @Test
    fun `BookContext is a data class with proper equality`() {
        val ctx1 = BookContext("Title", "Author", "en", "Opening")
        val ctx2 = BookContext("Title", "Author", "en", "Opening")

        assertEquals(ctx1, ctx2)
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
