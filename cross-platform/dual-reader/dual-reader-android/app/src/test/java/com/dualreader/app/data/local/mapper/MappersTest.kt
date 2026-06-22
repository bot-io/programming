package com.dualreader.app.data.local.mapper

import com.dualreader.app.data.local.entity.BookEntity
import com.dualreader.app.data.local.entity.BookmarkEntity
import com.dualreader.app.data.local.entity.PageEntity
import com.dualreader.app.domain.entities.Book
import com.dualreader.app.domain.entities.BookChapter
import com.dualreader.app.domain.entities.Bookmark
import com.dualreader.app.domain.entities.Page
import com.dualreader.app.domain.entities.PaginationStatus
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDateTime
import java.time.ZoneOffset

class MappersTest {

    // ── Book Entity ↔ Domain ───────────────────────────────────────

    @Test
    fun `BookEntity toDomain maps all fields`() {
        val entity = BookEntity(
            id = "book-1",
            title = "Test Book",
            author = "Author",
            coverPath = "/path/cover.jpg",
            filePath = "/path/book.epub",
            language = "en",
            importedAt = 1_700_000_000_000L,
            lastReadAt = 1_700_000_001_000L,
            currentPage = 5,
            totalPages = 100,
            paginationStatus = "COMPLETED",
            paginationProgress = 0.5f,
            chaptersJson = """[{"index":0,"title":"Ch1","level":0,"startIndex":0,"endIndex":10}]""",
        )
        val domain = entity.toDomain()

        assertEquals("book-1", domain.id)
        assertEquals("Test Book", domain.title)
        assertEquals("Author", domain.author)
        assertEquals("/path/cover.jpg", domain.coverPath)
        assertEquals("/path/book.epub", domain.filePath)
        assertEquals("en", domain.language)
        assertEquals(
            LocalDateTime.ofEpochSecond(1_700_000_000_000L / 1000, 0, ZoneOffset.UTC),
            domain.importedAt,
        )
        assertEquals(
            LocalDateTime.ofEpochSecond(1_700_000_001_000L / 1000, 0, ZoneOffset.UTC),
            domain.lastReadAt,
        )
        assertEquals(5, domain.currentPage)
        assertEquals(100, domain.totalPages)
        assertEquals(PaginationStatus.COMPLETED, domain.paginationStatus)
        assertEquals(0.5f, domain.paginationProgress)
        assertEquals(1, domain.chapters.size)
        assertEquals("Ch1", domain.chapters[0].title)
    }

    @Test
    fun `BookEntity toDomain null lastReadAt maps to null`() {
        val entity = BookEntity(
            id = "book-1",
            title = "Test",
            author = "Author",
            filePath = "/path.epub",
            importedAt = 1_700_000_000_000L,
            lastReadAt = null,
        )
        assertNull(entity.toDomain().lastReadAt)
    }

    @Test
    fun `BookEntity toDomain invalid paginationStatus defaults to NOT_STARTED`() {
        val entity = BookEntity(
            id = "b",
            title = "T",
            author = "A",
            filePath = "/p.epub",
            importedAt = 0L,
            paginationStatus = "INVALID",
        )
        assertEquals(PaginationStatus.NOT_STARTED, entity.toDomain().paginationStatus)
    }

    @Test
    fun `BookEntity toDomain empty chapters maps to empty list`() {
        val entity = BookEntity(
            id = "b",
            title = "T",
            author = "A",
            filePath = "/p.epub",
            importedAt = 0L,
            chaptersJson = "[]",
        )
        assertEquals(0, entity.toDomain().chapters.size)
    }

    @Test
    fun `Book toEntity maps all fields`() {
        val domain = Book(
            id = "book-1",
            title = "Test Book",
            author = "Author",
            coverPath = "/cover.jpg",
            filePath = "/book.epub",
            language = "en",
            importedAt = LocalDateTime.of(2024, 1, 1, 0, 0),
            lastReadAt = LocalDateTime.of(2024, 6, 1, 12, 0),
            currentPage = 10,
            totalPages = 200,
            paginationStatus = PaginationStatus.COMPLETED,
            paginationProgress = 0.75f,
            chapters = listOf(BookChapter(0, "Chapter 1", 0, 0, 5)),
        )
        val entity = domain.toEntity()

        assertEquals("book-1", entity.id)
        assertEquals("Test Book", entity.title)
        assertEquals("Author", entity.author)
        assertEquals("/cover.jpg", entity.coverPath)
        assertEquals("/book.epub", entity.filePath)
        assertEquals("en", entity.language)
        assertEquals(10, entity.currentPage)
        assertEquals(200, entity.totalPages)
        assertEquals("COMPLETED", entity.paginationStatus)
        assertEquals(0.75f, entity.paginationProgress)
        assertEquals(true, entity.chaptersJson.contains("Chapter 1"))
    }

    @Test
    fun `Book toEntity null lastReadAt maps to null`() {
        val domain = Book(
            id = "b",
            title = "T",
            author = "A",
            filePath = "/p.epub",
            lastReadAt = null,
        )
        assertNull(domain.toEntity().lastReadAt)
    }

    @Test
    fun `Book round trip preserves all fields`() {
        val original = Book(
            id = "round-trip-id",
            title = "Round Trip Book",
            author = "Test Author",
            coverPath = "/covers/1.jpg",
            filePath = "/books/1.epub",
            language = "en",
            importedAt = LocalDateTime.of(2024, 3, 15, 10, 30, 45),
            lastReadAt = LocalDateTime.of(2024, 6, 20, 14, 0, 0),
            currentPage = 42,
            totalPages = 350,
            paginationStatus = PaginationStatus.IN_PROGRESS,
            paginationProgress = 0.12f,
            chapters = listOf(
                BookChapter(0, "Introduction", 0, 0, 10),
                BookChapter(1, "Chapter One", 1, 11, 50),
                BookChapter(2, "Chapter Two", 1, 51, 100),
            ),
        )
        val restored = original.toEntity().toDomain()

        assertEquals(original.id, restored.id)
        assertEquals(original.title, restored.title)
        assertEquals(original.author, restored.author)
        assertEquals(original.coverPath, restored.coverPath)
        assertEquals(original.filePath, restored.filePath)
        assertEquals(original.language, restored.language)
        assertEquals(original.importedAt, restored.importedAt)
        assertEquals(original.lastReadAt, restored.lastReadAt)
        assertEquals(original.currentPage, restored.currentPage)
        assertEquals(original.totalPages, restored.totalPages)
        assertEquals(original.paginationStatus, restored.paginationStatus)
        assertEquals(original.paginationProgress, restored.paginationProgress, 0.001f)
        assertEquals(original.chapters, restored.chapters)
    }

    @Test
    fun `Book round trip with null lastReadAt`() {
        val original = Book(
            id = "b",
            title = "T",
            author = "A",
            filePath = "/p",
            lastReadAt = null,
        )
        val restored = original.toEntity().toDomain()
        assertNull(restored.lastReadAt)
    }

    @Test
    fun `Book round trip with empty chapters`() {
        val original = Book(
            id = "b",
            title = "T",
            author = "A",
            filePath = "/p",
            chapters = emptyList(),
        )
        val restored = original.toEntity().toDomain()
        assertTrue(restored.chapters.isEmpty())
    }

    // ── Page Entity ↔ Domain ───────────────────────────────────────

    @Test
    fun `PageEntity toDomain maps all fields`() {
        val entity = PageEntity(
            id = 1L,
            bookId = "book-1",
            pageIndex = 5,
            chapterIndex = 2,
            originalText = "Hello world",
            translationsJson = """{"bg":"Здравей свят"}""",
            translationModelsJson = """{"bg":"gemini-2.5-flash"}""",
            translationTimestampsJson = """{"bg":1700000000000}""",
            startCharOffset = 100,
            endCharOffset = 200,
        )
        val domain = entity.toDomain()

        assertEquals(5, domain.index)
        assertEquals("book-1", domain.bookId)
        assertEquals(2, domain.chapterIndex)
        assertEquals("Hello world", domain.originalText)
        assertEquals("Здравей свят", domain.translations["bg"])
        assertEquals("gemini-2.5-flash", domain.translationModels["bg"])
        assertEquals(1_700_000_000_000L, domain.translationTimestamps["bg"])
        assertEquals(100, domain.startCharOffset)
        assertEquals(200, domain.endCharOffset)
    }

    @Test
    fun `PageEntity toDomain null translations maps to empty map`() {
        val entity = PageEntity(
            bookId = "b",
            pageIndex = 0,
            chapterIndex = 0,
            originalText = "text",
            translationsJson = null,
            translationModelsJson = null,
            translationTimestampsJson = null,
        )
        val domain = entity.toDomain()
        assertTrue(domain.translations.isEmpty())
        assertTrue(domain.translationModels.isEmpty())
        assertTrue(domain.translationTimestamps.isEmpty())
    }

    @Test
    fun `Page toEntity maps all fields`() {
        val domain = Page(
            index = 3,
            bookId = "book-1",
            chapterIndex = 1,
            originalText = "Some text",
            translations = mapOf("bg" to "Някакъв текст"),
            translationModels = mapOf("bg" to "gemini-2.5-flash"),
            translationTimestamps = mapOf("bg" to 1_700_000_000_000L),
            startCharOffset = 50,
            endCharOffset = 150,
        )
        val entity = domain.toEntity(existingId = 42L)

        assertEquals(42L, entity.id)
        assertEquals("book-1", entity.bookId)
        assertEquals(3, entity.pageIndex)
        assertEquals(1, entity.chapterIndex)
        assertEquals("Some text", entity.originalText)
        assertEquals(true, entity.translationsJson!!.contains("Някакъв текст"))
        assertEquals(true, entity.translationModelsJson!!.contains("gemini-2.5-flash"))
        assertEquals(true, entity.translationTimestampsJson!!.contains("1700000000000"))
        assertEquals(50, entity.startCharOffset)
        assertEquals(150, entity.endCharOffset)
    }

    @Test
    fun `Page toEntity defaults existingId to zero`() {
        val domain = Page(
            index = 0,
            bookId = "b",
            chapterIndex = 0,
            originalText = "text",
        )
        val entity = domain.toEntity()
        assertEquals(0L, entity.id)
    }

    @Test
    fun `Page round trip preserves all fields`() {
        val original = Page(
            index = 7,
            bookId = "round-trip-book",
            chapterIndex = 3,
            originalText = "The quick brown fox.",
            translations = mapOf("bg" to "Бързата кафява лисица.", "ru" to "Быстрая бурая лиса."),
            translationModels = mapOf("bg" to "gemini-2.5-flash", "ru" to "ml-kit"),
            translationTimestamps = mapOf("bg" to 1_700_000_000_000L, "ru" to 1_700_000_001_000L),
            startCharOffset = 500,
            endCharOffset = 600,
        )
        val restored = original.toEntity(existingId = 99L).toDomain()

        assertEquals(original.index, restored.index)
        assertEquals(original.bookId, restored.bookId)
        assertEquals(original.chapterIndex, restored.chapterIndex)
        assertEquals(original.originalText, restored.originalText)
        assertEquals(original.translations, restored.translations)
        assertEquals(original.translationModels, restored.translationModels)
        assertEquals(original.translationTimestamps, restored.translationTimestamps)
        assertEquals(original.startCharOffset, restored.startCharOffset)
        assertEquals(original.endCharOffset, restored.endCharOffset)
    }

    @Test
    fun `Page round trip with empty translations`() {
        val original = Page(
            index = 0,
            bookId = "b",
            chapterIndex = 0,
            originalText = "untranslated",
        )
        val restored = original.toEntity().toDomain()
        assertTrue(restored.translations.isEmpty())
        assertTrue(restored.translationModels.isEmpty())
        assertTrue(restored.translationTimestamps.isEmpty())
    }

    // ── Bookmark Entity ↔ Domain ───────────────────────────────────

    @Test
    fun `BookmarkEntity toDomain maps all fields`() {
        val entity = BookmarkEntity(
            id = "bm-1",
            bookId = "book-1",
            pageIndex = 5,
            chapterIndex = 2,
            textSnippet = "Some highlighted text",
            note = "Important note",
            createdAt = 1_700_000_000_000L,
        )
        val domain = entity.toDomain()

        assertEquals("bm-1", domain.id)
        assertEquals("book-1", domain.bookId)
        assertEquals(5, domain.pageIndex)
        assertEquals(2, domain.chapterIndex)
        assertEquals("Some highlighted text", domain.textSnippet)
        assertEquals("Important note", domain.note)
        assertEquals(
            LocalDateTime.ofEpochSecond(1_700_000_000_000L / 1000, 0, ZoneOffset.UTC),
            domain.createdAt,
        )
    }

    @Test
    fun `BookmarkEntity toDomain with empty fields`() {
        val entity = BookmarkEntity(
            id = "bm-2",
            bookId = "b",
            pageIndex = 0,
            chapterIndex = 0,
            textSnippet = "",
            note = "",
            createdAt = 0L,
        )
        val domain = entity.toDomain()
        assertEquals("", domain.textSnippet)
        assertEquals("", domain.note)
    }

    @Test
    fun `Bookmark toEntity maps all fields`() {
        val domain = Bookmark(
            id = "bm-3",
            bookId = "book-1",
            pageIndex = 10,
            chapterIndex = 3,
            textSnippet = "Highlighted passage",
            note = "My note",
            createdAt = LocalDateTime.of(2024, 5, 15, 8, 30, 0),
        )
        val entity = domain.toEntity()

        assertEquals("bm-3", entity.id)
        assertEquals("book-1", entity.bookId)
        assertEquals(10, entity.pageIndex)
        assertEquals(3, entity.chapterIndex)
        assertEquals("Highlighted passage", entity.textSnippet)
        assertEquals("My note", entity.note)
        assertEquals(
            domain.createdAt.atZone(ZoneOffset.UTC).toInstant().toEpochMilli(),
            entity.createdAt,
        )
    }

    @Test
    fun `Bookmark round trip preserves all fields`() {
        val original = Bookmark(
            id = "round-trip-bm",
            bookId = "book-rt",
            pageIndex = 42,
            chapterIndex = 7,
            textSnippet = "A memorable quote from the book",
            note = "This reminds me of something important",
            createdAt = LocalDateTime.of(2024, 12, 25, 18, 0, 30),
        )
        val restored = original.toEntity().toDomain()

        assertEquals(original.id, restored.id)
        assertEquals(original.bookId, restored.bookId)
        assertEquals(original.pageIndex, restored.pageIndex)
        assertEquals(original.chapterIndex, restored.chapterIndex)
        assertEquals(original.textSnippet, restored.textSnippet)
        assertEquals(original.note, restored.note)
        assertEquals(original.createdAt, restored.createdAt)
    }

    @Test
    fun `Bookmark round trip with empty strings`() {
        val original = Bookmark(
            id = "bm-empty",
            bookId = "b",
            pageIndex = 0,
            chapterIndex = 0,
            textSnippet = "",
            note = "",
        )
        val restored = original.toEntity().toDomain()
        assertEquals("", restored.textSnippet)
        assertEquals("", restored.note)
    }
}
