package com.dualreader.app.data.repository

import android.content.Context
import com.dualreader.app.data.local.dao.BookDao
import com.dualreader.app.data.local.dao.BookTagDao
import com.dualreader.app.data.local.dao.BookmarkDao
import com.dualreader.app.data.local.dao.PageDao
import com.dualreader.app.data.local.entity.BookEntity
import com.dualreader.app.data.local.entity.PageEntity
import com.dualreader.app.domain.entities.Book
import com.dualreader.app.domain.entities.Page
import com.dualreader.app.domain.repositories.TranslationCacheRepository
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.coVerifyOrder
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.flow.first
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.io.File

class BookRepositoryImplTest {

    private lateinit var context: Context
    private lateinit var bookDao: BookDao
    private lateinit var pageDao: PageDao
    private lateinit var bookmarkDao: BookmarkDao
    private lateinit var bookTagDao: BookTagDao
    private lateinit var translationCacheRepo: TranslationCacheRepository
    private lateinit var repo: BookRepositoryImpl
    private lateinit var tempDir: File

    @Before
    fun setUp() {
        tempDir = File(System.getProperty("user.home"), ".test-covers-${System.currentTimeMillis()}")
        tempDir.mkdirs()

        context = mockk(relaxed = true)
        every { context.filesDir } returns tempDir

        bookDao = mockk(relaxed = true)
        pageDao = mockk(relaxed = true)
        bookmarkDao = mockk(relaxed = true)
        bookTagDao = mockk(relaxed = true)
        translationCacheRepo = mockk(relaxed = true)
        repo = BookRepositoryImpl(context, bookDao, pageDao, bookmarkDao, bookTagDao, translationCacheRepo)
    }

    private fun makeBookEntity(id: String = "book-1") = BookEntity(
        id = id,
        title = "Test Book",
        author = "Author",
        filePath = "/path/book.epub",
        importedAt = 1_700_000_000_000L,
    )

    // ── getAllBooks ────────────────────────────────────────────────

    @Test
    fun `getAllBooks maps entities to domain`() = runTest {
        every { bookDao.getAllBooks() } returns flowOf(listOf(makeBookEntity("b1"), makeBookEntity("b2")))
        val books = repo.getAllBooks().first()
        assertEquals(2, books.size)
        assertEquals("b1", books[0].id)
        assertEquals("b2", books[1].id)
    }

    @Test
    fun `getAllBooks empty list`() = runTest {
        every { bookDao.getAllBooks() } returns flowOf(emptyList())
        assertTrue(repo.getAllBooks().first().isEmpty())
    }

    // ── getBookById ────────────────────────────────────────────────

    @Test
    fun `getBookById returns domain book when found`() = runTest {
        coEvery { bookDao.getById("book-1") } returns makeBookEntity("book-1")
        val book = repo.getBookById("book-1")
        assertNotNull(book)
        assertEquals("book-1", book!!.id)
    }

    @Test
    fun `getBookById returns null when not found`() = runTest {
        coEvery { bookDao.getById("missing") } returns null
        assertNull(repo.getBookById("missing"))
    }

    // ── insertBook ─────────────────────────────────────────────────

    @Test
    fun `insertBook calls dao insert with entity`() = runTest {
        val book = Book(id = "new-book", title = "New", author = "A", filePath = "/p.epub")
        repo.insertBook(book)
        coVerify { bookDao.insert(match { it.id == "new-book" && it.title == "New" }) }
    }

    // ── updateBook ─────────────────────────────────────────────────

    @Test
    fun `updateBook calls dao update with entity`() = runTest {
        val book = Book(id = "upd", title = "Updated", author = "B", filePath = "/u.epub")
        repo.updateBook(book)
        coVerify { bookDao.update(match { it.id == "upd" && it.title == "Updated" }) }
    }

    // ── deleteBook cascade ─────────────────────────────────────────

    @Test
    fun `deleteBook deletes pages bookmarks tags and book`() = runTest {
        val pages = listOf(
            PageEntity(bookId = "b1", pageIndex = 0, chapterIndex = 0, originalText = "page 0"),
            PageEntity(bookId = "b1", pageIndex = 1, chapterIndex = 0, originalText = "page 1"),
        )
        coEvery { pageDao.getPagesForBook("b1") } returns pages

        repo.deleteBook("b1")

        coVerifyOrder {
            pageDao.deletePagesForBook("b1")
            bookmarkDao.deleteBookmarksForBook("b1")
            bookTagDao.deleteTagsForBook("b1")
            bookDao.deleteById("b1")
        }
    }

    @Test
    fun `deleteBook clears translation cache for book pages`() = runTest {
        val pages = listOf(
            PageEntity(bookId = "b1", pageIndex = 0, chapterIndex = 0, originalText = "text1"),
        )
        coEvery { pageDao.getPagesForBook("b1") } returns pages

        repo.deleteBook("b1")

        coVerify { translationCacheRepo.deleteForTexts(listOf("text1")) }
    }

    @Test
    fun `deleteBook does not clear cache when no pages`() = runTest {
        coEvery { pageDao.getPagesForBook("b1") } returns emptyList()

        repo.deleteBook("b1")

        coVerify(exactly = 0) { translationCacheRepo.deleteForTexts(any()) }
    }

    @Test
    fun `deleteBook swallows cache cleanup errors`() = runTest {
        coEvery { pageDao.getPagesForBook("b1") } returns listOf(
            PageEntity(bookId = "b1", pageIndex = 0, chapterIndex = 0, originalText = "text"),
        )
        coEvery { translationCacheRepo.deleteForTexts(any()) } throws RuntimeException("cache error")

        // Should not throw
        repo.deleteBook("b1")
        coVerify { bookDao.deleteById("b1") }
    }

    // ── saveCoverImage ─────────────────────────────────────────────

    @Test
    fun `saveCoverImage saves jpg and returns path`() = runTest {
        val jpgBytes = byteArrayOf(0xFF.toByte(), 0xD8.toByte(), 0xFF.toByte(), 0xE0.toByte(), 0, 0, 0, 0)
        val path = repo.saveCoverImage(jpgBytes, "book-1")
        assertNotNull(path)
        assertTrue(path!!.endsWith("book-1.jpg"))
        assertTrue(File(path).exists())
    }

    @Test
    fun `saveCoverImage detects png from magic bytes`() = runTest {
        val pngBytes = byteArrayOf(0x89.toByte(), 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A)
        val path = repo.saveCoverImage(pngBytes, "book-png")
        assertNotNull(path)
        assertTrue(path!!.endsWith("book-png.png"))
        assertTrue(File(path).exists())
    }

    @Test
    fun `saveCoverImage defaults to jpg for unknown format`() = runTest {
        val unknownBytes = byteArrayOf(0x00, 0x01, 0x02)
        val path = repo.saveCoverImage(unknownBytes, "book-unk")
        assertNotNull(path)
        assertTrue(path!!.endsWith("book-unk.jpg"))
        assertTrue(File(path).exists())
    }

    // ── getPagesForBook ────────────────────────────────────────────

    @Test
    fun `getPagesForBook maps entities to domain`() = runTest {
        val entities = listOf(
            PageEntity(bookId = "b1", pageIndex = 0, chapterIndex = 0, originalText = "page 0"),
            PageEntity(bookId = "b1", pageIndex = 1, chapterIndex = 0, originalText = "page 1"),
        )
        coEvery { pageDao.getPagesForBook("b1") } returns entities

        val pages = repo.getPagesForBook("b1")
        assertEquals(2, pages.size)
        assertEquals(0, pages[0].index)
        assertEquals("page 1", pages[1].originalText)
    }

    @Test
    fun `getPagesForBook empty returns empty list`() = runTest {
        coEvery { pageDao.getPagesForBook("b1") } returns emptyList()
        assertTrue(repo.getPagesForBook("b1").isEmpty())
    }

    // ── getPage ────────────────────────────────────────────────────

    @Test
    fun `getPage returns domain page when found`() = runTest {
        coEvery { pageDao.getPage("b1", 5) } returns PageEntity(
            bookId = "b1", pageIndex = 5, chapterIndex = 1, originalText = "page 5",
        )
        val page = repo.getPage("b1", 5)
        assertNotNull(page)
        assertEquals(5, page!!.index)
    }

    @Test
    fun `getPage returns null when not found`() = runTest {
        coEvery { pageDao.getPage("b1", 99) } returns null
        assertNull(repo.getPage("b1", 99))
    }

    // ── savePages ──────────────────────────────────────────────────

    @Test
    fun `savePages calls dao insertAll with entities`() = runTest {
        val pages = listOf(
            Page(index = 0, bookId = "b1", chapterIndex = 0, originalText = "text 0"),
            Page(index = 1, bookId = "b1", chapterIndex = 0, originalText = "text 1"),
        )
        repo.savePages(pages)
        coVerify { pageDao.insertAll(match { it.size == 2 && it[0].pageIndex == 0 && it[1].pageIndex == 1 }) }
    }

    @Test
    fun `savePages empty list calls insertAll with empty list`() = runTest {
        repo.savePages(emptyList())
        coVerify { pageDao.insertAll(emptyList()) }
    }

    // ── deletePagesForBook ─────────────────────────────────────────

    @Test
    fun `deletePagesForBook delegates to dao`() = runTest {
        repo.deletePagesForBook("b1")
        coVerify { pageDao.deletePagesForBook("b1") }
    }

    // ── getPageCount ───────────────────────────────────────────────

    @Test
    fun `getPageCount returns count from dao`() = runTest {
        coEvery { pageDao.getPageCount("b1") } returns 42
        assertEquals(42, repo.getPageCount("b1"))
    }

    @Test
    fun `getPageCount returns zero for book with no pages`() = runTest {
        coEvery { pageDao.getPageCount("b1") } returns 0
        assertEquals(0, repo.getPageCount("b1"))
    }

    // ── clearAllTranslations ───────────────────────────────────────

    @Test
    fun `clearAllTranslations delegates to dao`() = runTest {
        repo.clearAllTranslations()
        coVerify { pageDao.clearAllTranslations() }
    }

    // ── updatePageTranslation ──────────────────────────────────────

    @Test
    fun `updatePageTranslation delegates to dao`() = runTest {
        repo.updatePageTranslation("b1", 5, """{"bg":"text"}""", """{"bg":"gemini"}""")
        coVerify { pageDao.updatePageTranslations("b1", 5, """{"bg":"text"}""", """{"bg":"gemini"}""") }
    }

    @Test
    fun `updatePageTranslation with null json`() = runTest {
        repo.updatePageTranslation("b1", 5, null, null)
        coVerify { pageDao.updatePageTranslations("b1", 5, null, null) }
    }

    // ── getTranslatedPageCount ─────────────────────────────────────

    @Test
    fun `getTranslatedPageCount returns count from dao`() = runTest {
        coEvery { pageDao.getTranslatedPageCount() } returns 15
        assertEquals(15, repo.getTranslatedPageCount())
    }

    @Test
    fun `getTranslatedPageCount zero when none translated`() = runTest {
        coEvery { pageDao.getTranslatedPageCount() } returns 0
        assertEquals(0, repo.getTranslatedPageCount())
    }
}
