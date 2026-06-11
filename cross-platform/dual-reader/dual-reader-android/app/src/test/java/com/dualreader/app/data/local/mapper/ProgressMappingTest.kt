package com.dualreader.app.data.local.mapper

import com.dualreader.app.data.local.entity.BookEntity
import com.dualreader.app.domain.entities.Book
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertFalse
import org.junit.Test
import java.time.LocalDateTime
import java.time.ZoneOffset

class ProgressMappingTest {

    @Test
    fun `BookEntity toDomain preserves progress fields`() {
        val now = System.currentTimeMillis()
        val entity = BookEntity(
            id = "book1",
            title = "Test Book",
            author = "Author",
            filePath = "/test.epub",
            currentPage = 42,
            totalPages = 200,
            lastReadAt = now,
            importedAt = now - 100_000,
            paginationStatus = "COMPLETED",
        )

        val domain = entity.toDomain()
        assertEquals(42, domain.currentPage)
        assertEquals(200, domain.totalPages)
        assertNotNull(domain.lastReadAt)
        assertEquals("21%", domain.progressLabel)
        assertEquals(0.21f, domain.progressPercent, 0.01f)
        assert(domain.hasProgress)
    }

    @Test
    fun `Book toEntity preserves progress fields`() {
        val now = LocalDateTime.now()
        val domain = Book(
            id = "book1",
            title = "Test Book",
            author = "Author",
            filePath = "/test.epub",
            currentPage = 75,
            totalPages = 150,
            lastReadAt = now,
        )

        val entity = domain.toEntity()
        assertEquals("book1", entity.id)
        assertEquals(75, entity.currentPage)
        assertEquals(150, entity.totalPages)
        assertNotNull(entity.lastReadAt)
        // Verify the timestamp is roughly now (within 1 second)
        val diff = Math.abs(entity.lastReadAt!! - now.atZone(ZoneOffset.UTC).toInstant().toEpochMilli())
        assert(diff < 1000) { "Timestamp should match, diff=$diff ms" }
    }

    @Test
    fun `progress round-trips through entity mapping`() {
        val now = LocalDateTime.now()
        val original = Book(
            id = "book42",
            title = "Round Trip",
            author = "Author",
            filePath = "/test.epub",
            currentPage = 33,
            totalPages = 100,
            lastReadAt = now,
        )

        val entity = original.toEntity()
        val restored = entity.toDomain()

        assertEquals(33, restored.currentPage)
        assertEquals(100, restored.totalPages)
        assertNotNull(restored.lastReadAt)
        assertEquals("33%", restored.progressLabel)
        assertEquals(0.33f, restored.progressPercent, 0.01f)
        assert(restored.hasProgress)
    }

    @Test
    fun `null lastReadAt round-trips correctly`() {
        val original = Book(
            id = "book99",
            title = "Unread Book",
            author = "Author",
            filePath = "/test.epub",
            currentPage = 0,
            totalPages = 100,
            lastReadAt = null,
        )

        val entity = original.toEntity()
        assertNull(entity.lastReadAt)

        val restored = entity.toDomain()
        assertNull(restored.lastReadAt)
        assertEquals(0, restored.currentPage)
        assertFalse(restored.hasProgress)
    }

    @Test
    fun `progressPercent and label work after entity round-trip`() {
        val book = Book(
            id = "b1",
            title = "Test",
            author = "Author",
            filePath = "/test.epub",
            currentPage = 50,
            totalPages = 200,
        )

        val entity = book.toEntity()
        val restored = entity.toDomain()

        assertEquals("25%", restored.progressLabel)
        assertEquals(0.25f, restored.progressPercent, 0.001f)
        assert(restored.hasProgress)
    }
}
