package com.dualreader.app.domain.entities

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
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
}
