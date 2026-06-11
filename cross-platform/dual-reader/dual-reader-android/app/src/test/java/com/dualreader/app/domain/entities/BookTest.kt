package com.dualreader.app.domain.entities

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class BookTest {

    @Test
    fun `canBeOpened - completed with pages returns true`() {
        val book = Book(
            title = "Test",
            author = "Author",
            filePath = "/test.epub",
            paginationStatus = PaginationStatus.COMPLETED,
            totalPages = 100,
        )
        assertTrue(book.canBeOpened)
    }

    @Test
    fun `canBeOpened - not started returns false`() {
        val book = Book(
            title = "Test",
            author = "Author",
            filePath = "/test.epub",
            paginationStatus = PaginationStatus.NOT_STARTED,
        )
        assertFalse(book.canBeOpened)
    }

    @Test
    fun `canBeOpened - completed but zero pages returns false`() {
        val book = Book(
            title = "Test",
            author = "Author",
            filePath = "/test.epub",
            paginationStatus = PaginationStatus.COMPLETED,
            totalPages = 0,
        )
        assertFalse(book.canBeOpened)
    }

    @Test
    fun `canBeOpened - in progress returns false`() {
        val book = Book(
            title = "Test",
            author = "Author",
            filePath = "/test.epub",
            paginationStatus = PaginationStatus.IN_PROGRESS,
            totalPages = 50,
        )
        assertFalse(book.canBeOpened)
    }

    @Test
    fun `progressPercent - calculates correctly`() {
        val book = Book(
            title = "Test",
            author = "Author",
            filePath = "/test.epub",
            currentPage = 25,
            totalPages = 100,
        )
        assertEquals(0.25f, book.progressPercent, 0.001f)
    }

    @Test
    fun `progressPercent - zero pages returns zero`() {
        val book = Book(
            title = "Test",
            author = "Author",
            filePath = "/test.epub",
            currentPage = 10,
            totalPages = 0,
        )
        assertEquals(0f, book.progressPercent, 0.001f)
    }

    @Test
    fun `progressPercent - last page returns 1`() {
        val book = Book(
            title = "Test",
            author = "Author",
            filePath = "/test.epub",
            currentPage = 100,
            totalPages = 100,
        )
        assertEquals(1f, book.progressPercent, 0.001f)
    }

    @Test
    fun `copy - creates new instance with updated fields`() {
        val original = Book(
            title = "Original",
            author = "Author",
            filePath = "/test.epub",
        )
        val updated = original.copy(
            currentPage = 50,
            totalPages = 200,
            paginationStatus = PaginationStatus.COMPLETED,
        )
        assertEquals("Original", updated.title)
        assertEquals(50, updated.currentPage)
        assertEquals(200, updated.totalPages)
        assertEquals(PaginationStatus.COMPLETED, updated.paginationStatus)
    }

    @Test
    fun `default values - sensible defaults`() {
        val book = Book(
            title = "Test",
            author = "Author",
            filePath = "/test.epub",
        )
        assertEquals(BookFormat.EPUB, book.format)
        assertEquals(PaginationStatus.NOT_STARTED, book.paginationStatus)
        assertEquals(0, book.currentPage)
        assertEquals(0, book.totalPages)
        assertEquals("", book.coverPath)
        assertEquals(0f, book.paginationProgress, 0.001f)
    }

    // ── progressLabel ──────────────────────────────────────────────────
    
    @Test
    fun `progressLabel - shows percentage`() {
        val book = Book(
            title = "Test",
            author = "Author",
            filePath = "/test.epub",
            currentPage = 45,
            totalPages = 100,
        )
        assertEquals("45%", book.progressLabel)
    }

    @Test
    fun `progressLabel - zero pages returns empty`() {
        val book = Book(
            title = "Test",
            author = "Author",
            filePath = "/test.epub",
            currentPage = 0,
            totalPages = 0,
        )
        assertEquals("", book.progressLabel)
    }

    @Test
    fun `progressLabel - first page shows 0%`() {
        val book = Book(
            title = "Test",
            author = "Author",
            filePath = "/test.epub",
            currentPage = 0,
            totalPages = 100,
        )
        assertEquals("0%", book.progressLabel)
    }

    @Test
    fun `progressLabel - last page shows 100%`() {
        val book = Book(
            title = "Test",
            author = "Author",
            filePath = "/test.epub",
            currentPage = 100,
            totalPages = 100,
        )
        assertEquals("100%", book.progressLabel)
    }

    @Test
    fun `progressLabel - rounds down`() {
        val book = Book(
            title = "Test",
            author = "Author",
            filePath = "/test.epub",
            currentPage = 1,
            totalPages = 3,
        )
        assertEquals("33%", book.progressLabel)
    }

    // ── hasProgress ────────────────────────────────────────────────────

    @Test
    fun `hasProgress - true when past first page`() {
        val book = Book(
            title = "Test",
            author = "Author",
            filePath = "/test.epub",
            currentPage = 5,
            totalPages = 100,
        )
        assertTrue(book.hasProgress)
    }

    @Test
    fun `hasProgress - false when on first page`() {
        val book = Book(
            title = "Test",
            author = "Author",
            filePath = "/test.epub",
            currentPage = 0,
            totalPages = 100,
        )
        assertFalse(book.hasProgress)
    }

    @Test
    fun `hasProgress - false when zero pages`() {
        val book = Book(
            title = "Test",
            author = "Author",
            filePath = "/test.epub",
            currentPage = 5,
            totalPages = 0,
        )
        assertFalse(book.hasProgress)
    }

    // ── lastReadAt ─────────────────────────────────────────────────────

    @Test
    fun `lastReadAt - default is null`() {
        val book = Book(
            title = "Test",
            author = "Author",
            filePath = "/test.epub",
        )
        assertNull(book.lastReadAt)
    }

    @Test
    fun `lastReadAt - can be set via copy`() {
        val now = java.time.LocalDateTime.now()
        val book = Book(
            title = "Test",
            author = "Author",
            filePath = "/test.epub",
            lastReadAt = now,
        )
        assertEquals(now, book.lastReadAt)
    }

    // ── Progress persistence round-trip ────────────────────────────────

    @Test
    fun `progress survives copy round-trip`() {
        val now = java.time.LocalDateTime.now()
        val original = Book(
            title = "Test",
            author = "Author",
            filePath = "/test.epub",
            currentPage = 42,
            totalPages = 200,
            lastReadAt = now,
        )
        val restored = original.copy()
        assertEquals(42, restored.currentPage)
        assertEquals(200, restored.totalPages)
        assertEquals(now, restored.lastReadAt)
        assertEquals("21%", restored.progressLabel)
        assertTrue(restored.hasProgress)
    }
}
