package com.dualreader.app.data.local.mapper

import com.dualreader.app.data.local.entity.BookEntity
import com.dualreader.app.data.local.entity.BookmarkEntity
import com.dualreader.app.data.local.entity.PageEntity
import com.dualreader.app.domain.entities.Book
import com.dualreader.app.domain.entities.Bookmark
import com.dualreader.app.domain.entities.PaginationStatus
import com.dualreader.app.domain.entities.Page
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import java.time.LocalDateTime

/**
 * Tests for the entity ↔ domain mappers.
 *
 * Focuses on timestamp precision (DR-056): sub-second milliseconds were
 * silently dropped by the old `ofEpochSecond(millis / 1000, 0, UTC)` calls.
 */
class MappersTest {

    // ── Book round-trip ────────────────────────────────────────────

    @Test
    fun `Book round trip preserves importedAt millisecond precision`() {
        val original = Book(
            id = "book-1",
            title = "Test Book",
            author = "Author",
            filePath = "/path/to/book.epub",
            importedAt = LocalDateTime.of(2024, 3, 10, 14, 30, 0, 456_000_000),
            totalPages = 10,
            paginationStatus = PaginationStatus.COMPLETED,
        )
        val restored = original.toEntity().toDomain()
        assertEquals(original.importedAt, restored.importedAt)
    }

    @Test
    fun `Book round trip preserves lastReadAt millisecond precision`() {
        val original = Book(
            id = "book-2",
            title = "Test Book",
            author = "Author",
            filePath = "/path/to/book.epub",
            importedAt = LocalDateTime.of(2024, 3, 10, 14, 30, 0),
            lastReadAt = LocalDateTime.of(2024, 6, 20, 8, 15, 30, 999_000_000),
            totalPages = 5,
            paginationStatus = PaginationStatus.COMPLETED,
        )
        val restored = original.toEntity().toDomain()
        assertEquals(original.lastReadAt, restored.lastReadAt)
    }

    @Test
    fun `Book round trip with null lastReadAt`() {
        val original = Book(
            id = "book-3",
            title = "Unread Book",
            author = "Nobody",
            filePath = "/path",
            importedAt = LocalDateTime.of(2024, 1, 1, 0, 0),
            lastReadAt = null,
            totalPages = 1,
            paginationStatus = PaginationStatus.COMPLETED,
        )
        val restored = original.toEntity().toDomain()
        assertNull(restored.lastReadAt)
    }

    @Test
    fun `Book round trip preserves core fields`() {
        val original = Book(
            id = "book-fields",
            title = "Title",
            author = "Author",
            coverPath = "/cover.png",
            filePath = "/path",
            language = "en",
            currentPage = 3,
            totalPages = 10,
            paginationStatus = PaginationStatus.COMPLETED,
            paginationProgress = 0.5f,
        )
        val restored = original.toEntity().toDomain()
        assertEquals(original.id, restored.id)
        assertEquals(original.title, restored.title)
        assertEquals(original.author, restored.author)
        assertEquals(original.coverPath, restored.coverPath)
        assertEquals(original.filePath, restored.filePath)
        assertEquals(original.language, restored.language)
        assertEquals(original.currentPage, restored.currentPage)
        assertEquals(original.totalPages, restored.totalPages)
        assertEquals(original.paginationStatus, restored.paginationStatus)
        assertEquals(original.paginationProgress, restored.paginationProgress, 0.001f)
    }

    // ── Bookmark round-trip ────────────────────────────────────────

    @Test
    fun `Bookmark round trip preserves createdAt millisecond precision`() {
        val original = Bookmark(
            id = "bm-1",
            bookId = "book-1",
            pageIndex = 5,
            chapterIndex = 2,
            textSnippet = "highlighted text",
            note = "my note",
            createdAt = LocalDateTime.of(2024, 7, 4, 12, 0, 0, 123_000_000),
        )
        val restored = original.toEntity().toDomain()
        assertEquals(original.createdAt, restored.createdAt)
    }

    @Test
    fun `Bookmark round trip preserves core fields`() {
        val original = Bookmark(
            id = "bm-2",
            bookId = "book-1",
            pageIndex = 10,
            chapterIndex = 3,
            textSnippet = "snippet",
            note = "note",
            createdAt = LocalDateTime.of(2024, 1, 1, 0, 0, 0, 500_000_000),
        )
        val restored = original.toEntity().toDomain()
        assertEquals(original.id, restored.id)
        assertEquals(original.bookId, restored.bookId)
        assertEquals(original.pageIndex, restored.pageIndex)
        assertEquals(original.chapterIndex, restored.chapterIndex)
        assertEquals(original.textSnippet, restored.textSnippet)
        assertEquals(original.note, restored.note)
    }

    // ── Page round-trip ────────────────────────────────────────────

    @Test
    fun `Page round trip preserves translations`() {
        val original = Page(
            index = 0,
            bookId = "book-1",
            chapterIndex = 0,
            originalText = "Hello world",
            translations = mapOf("es" to "Hola mundo"),
            startCharOffset = 0,
            endCharOffset = 11,
        )
        val restored = original.toEntity().toDomain()
        assertEquals(original.originalText, restored.originalText)
        assertEquals(original.translations, restored.translations)
        assertEquals(original.index, restored.index)
        assertEquals(original.bookId, restored.bookId)
    }

    @Test
    fun `Page round trip preserves translation models and timestamps`() {
        val original = Page(
            index = 1,
            bookId = "book-1",
            chapterIndex = 0,
            originalText = "Test",
            translations = mapOf("fr" to "Test"),
            translationModels = mapOf("fr" to "gemini-2.5-flash"),
            translationTimestamps = mapOf("fr" to 1_700_000_000_123L),
            startCharOffset = 0,
            endCharOffset = 4,
        )
        val restored = original.toEntity().toDomain()
        assertEquals(original.translationModels, restored.translationModels)
        assertEquals(original.translationTimestamps, restored.translationTimestamps)
    }

    @Test
    fun `Page round trip with empty translations`() {
        val original = Page(
            index = 0,
            bookId = "book-1",
            chapterIndex = 0,
            originalText = "Untranslated",
            startCharOffset = 0,
            endCharOffset = 12,
        )
        val restored = original.toEntity().toDomain()
        assertEquals(original.translations, restored.translations)
    }

    // ── Edge cases ─────────────────────────────────────────────────

    @Test
    fun `epoch millis with zero milliseconds round trips correctly`() {
        val original = Book(
            id = "book-zero-ms",
            title = "Exact Second",
            author = "Author",
            filePath = "/path",
            importedAt = LocalDateTime.of(2024, 1, 1, 0, 0, 0, 0),
            totalPages = 1,
            paginationStatus = PaginationStatus.COMPLETED,
        )
        val restored = original.toEntity().toDomain()
        assertEquals(original.importedAt, restored.importedAt)
    }

    @Test
    fun `epoch millis with 999 milliseconds round trips correctly`() {
        val original = Book(
            id = "book-max-ms",
            title = "Max Millis",
            author = "Author",
            filePath = "/path",
            importedAt = LocalDateTime.of(2024, 12, 31, 23, 59, 59, 999_000_000),
            totalPages = 1,
            paginationStatus = PaginationStatus.COMPLETED,
        )
        val restored = original.toEntity().toDomain()
        assertEquals(original.importedAt, restored.importedAt)
    }
}
