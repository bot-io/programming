package com.dualreader.app.data.repository

import com.dualreader.app.data.local.dao.BookDao
import com.dualreader.app.data.local.dao.BookTagDao
import com.dualreader.app.data.local.dao.CollectionDao
import com.dualreader.app.data.local.entity.BookEntity
import com.dualreader.app.data.local.entity.BookTagEntity
import com.dualreader.app.data.local.entity.CollectionBookEntity
import com.dualreader.app.data.local.entity.CollectionEntity
import com.dualreader.app.domain.entities.SortOrder
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.flowOf
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class LibraryRepositoryImplTest {

    private lateinit var bookDao: BookDao
    private lateinit var bookTagDao: BookTagDao
    private lateinit var collectionDao: CollectionDao
    private lateinit var repository: LibraryRepositoryImpl

    private val testBooks = listOf(
        BookEntity(id = "1", title = "Alpha", author = "Smith", filePath = "/a.epub", importedAt = 1000),
        BookEntity(id = "2", title = "Beta", author = "Jones", filePath = "/b.epub", importedAt = 2000),
        BookEntity(id = "3", title = "Gamma", author = "Adams", filePath = "/c.epub", importedAt = 3000),
    )

    @Before
    fun setUp() {
        bookDao = mockk(relaxed = true)
        bookTagDao = mockk(relaxed = true)
        collectionDao = mockk(relaxed = true)
        repository = LibraryRepositoryImpl(bookDao, bookTagDao, collectionDao)
    }

    // ── Sorted Books ──────────────────────────────────────────────────────────

    @Test
    fun `getAllBooksSorted by title returns books from bookDao`() = runTest {
        every { bookDao.getAllBooksByTitle() } returns flowOf(testBooks)

        val books = repository.getAllBooksSorted(SortOrder.TITLE).first()
        assertEquals(3, books.size)
        assertEquals("Alpha", books[0].title)
    }

    @Test
    fun `getAllBooksSorted by author returns books from bookDao`() = runTest {
        every { bookDao.getAllBooksByAuthor() } returns flowOf(testBooks)

        val books = repository.getAllBooksSorted(SortOrder.AUTHOR).first()
        assertEquals(3, books.size)
    }

    @Test
    fun `getAllBooksSorted by date added returns books from bookDao`() = runTest {
        every { bookDao.getAllBooksByDateAdded() } returns flowOf(testBooks)

        val books = repository.getAllBooksSorted(SortOrder.DATE_ADDED).first()
        assertEquals(3, books.size)
    }

    @Test
    fun `getAllBooksSorted by last read returns books from bookDao`() = runTest {
        every { bookDao.getAllBooksByLastRead() } returns flowOf(testBooks)

        val books = repository.getAllBooksSorted(SortOrder.LAST_READ).first()
        assertEquals(3, books.size)
    }

    @Test
    fun `getAllBooksSorted by progress sorts in memory`() = runTest {
        // Books with different progress
        val booksWithProgress = listOf(
            BookEntity(id = "1", title = "Low", author = "A", filePath = "/a", totalPages = 100, currentPage = 10),
            BookEntity(id = "2", title = "High", author = "B", filePath = "/b", totalPages = 100, currentPage = 80),
            BookEntity(id = "3", title = "Mid", author = "C", filePath = "/c", totalPages = 100, currentPage = 50),
        )
        every { bookDao.getAllBooksByDateAdded() } returns flowOf(booksWithProgress)

        val books = repository.getAllBooksSorted(SortOrder.PROGRESS).first()
        assertEquals(3, books.size)
        assertEquals("High", books[0].title) // 80%
        assertEquals("Mid", books[1].title)  // 50%
        assertEquals("Low", books[2].title)  // 10%
    }

    @Test
    fun `getAllBooksSorted converts entities to domain correctly`() = runTest {
        every { bookDao.getAllBooksByTitle() } returns flowOf(testBooks)

        val books = repository.getAllBooksSorted(SortOrder.TITLE).first()
        assertEquals("1", books[0].id)
        assertEquals("Smith", books[0].author)
    }

    // ── Tags ──────────────────────────────────────────────────────────────────

    @Test
    fun `getAllTags returns distinct tags from dao`() = runTest {
        every { bookTagDao.getAllTags() } returns flowOf(listOf("fiction", "sci-fi"))

        val tags = repository.getAllTags().first()
        assertEquals(listOf("fiction", "sci-fi"), tags)
    }

    @Test
    fun `getTagsForBook returns tag names`() = runTest {
        coEvery { bookTagDao.getTagsForBook("book1") } returns listOf(
            BookTagEntity("book1", "fiction"),
            BookTagEntity("book1", "sci-fi"),
        )

        val tags = repository.getTagsForBook("book1")
        assertEquals(listOf("fiction", "sci-fi"), tags)
    }

    @Test
    fun `addTag inserts BookTagEntity with trimmed tag`() = runTest {
        repository.addTag("book1", "  Fiction  ")

        coVerify { bookTagDao.insert(BookTagEntity("book1", "Fiction")) }
    }

    @Test
    fun `removeTag delegates to dao`() = runTest {
        repository.removeTag("book1", "fiction")

        coVerify { bookTagDao.deleteTag("book1", "fiction") }
    }

    @Test
    fun `getBookIdsByTag returns list of book IDs`() = runTest {
        coEvery { bookTagDao.getBookIdsByTag("fiction") } returns listOf("b1", "b2")

        val ids = repository.getBookIdsByTag("fiction")
        assertEquals(listOf("b1", "b2"), ids)
    }

    @Test
    fun `addTag with empty tag is still inserted but trimmed`() = runTest {
        repository.addTag("book1", "  ")

        coVerify { bookTagDao.insert(BookTagEntity("book1", "")) }
    }

    // ── Collections ───────────────────────────────────────────────────────────

    @Test
    fun `getAllCollections returns mapped domain objects`() = runTest {
        every { collectionDao.getAllCollections() } returns flowOf(
            listOf(CollectionEntity(id = 1, name = "Favorites", createdAt = 1000))
        )

        val collections = repository.getAllCollections().first()
        assertEquals(1, collections.size)
        assertEquals("Favorites", collections[0].name)
        assertEquals(1L, collections[0].id)
    }

    @Test
    fun `getCollection returns null for non-existent id`() = runTest {
        coEvery { collectionDao.getById(999L) } returns null

        val result = repository.getCollection(999L)
        assertNull(result)
    }

    @Test
    fun `getCollection returns collection with book IDs`() = runTest {
        coEvery { collectionDao.getById(1L) } returns CollectionEntity(id = 1, name = "Sci-Fi", createdAt = 1000)
        coEvery { collectionDao.getBookIdsForCollection(1L) } returns listOf("b1", "b2")

        val result = repository.getCollection(1L)
        assertNotNull(result)
        assertEquals("Sci-Fi", result!!.name)
        assertEquals(listOf("b1", "b2"), result.bookIds)
    }

    @Test
    fun `createCollection inserts with trimmed name`() = runTest {
        coEvery { collectionDao.insert(any()) } returns 5L

        val id = repository.createCollection("  My Books  ")
        assertEquals(5L, id)

        coVerify { collectionDao.insert(match { it.name == "My Books" }) }
    }

    @Test
    fun `renameCollection updates name`() = runTest {
        coEvery { collectionDao.getById(1L) } returns CollectionEntity(id = 1, name = "Old", createdAt = 1000)

        repository.renameCollection(1L, "  New Name  ")

        coVerify { collectionDao.update(CollectionEntity(id = 1, name = "New Name", createdAt = 1000)) }
    }

    @Test
    fun `renameCollection does nothing if collection not found`() = runTest {
        coEvery { collectionDao.getById(999L) } returns null

        repository.renameCollection(999L, "New")

        coVerify(exactly = 0) { collectionDao.update(any()) }
    }

    @Test
    fun `deleteCollection delegates to dao`() = runTest {
        repository.deleteCollection(1L)

        coVerify { collectionDao.deleteById(1L) }
    }

    @Test
    fun `addBookToCollection delegates to dao`() = runTest {
        repository.addBookToCollection(1L, "book1")

        coVerify { collectionDao.addBookToCollection(CollectionBookEntity(1L, "book1")) }
    }

    @Test
    fun `removeBookFromCollection delegates to dao`() = runTest {
        repository.removeBookFromCollection(1L, "book1")

        coVerify { collectionDao.removeBookFromCollection(1L, "book1") }
    }

    @Test
    fun `getBookIdsForCollection delegates to dao`() = runTest {
        coEvery { collectionDao.getBookIdsForCollection(1L) } returns listOf("b1")

        val ids = repository.getBookIdsForCollection(1L)
        assertEquals(listOf("b1"), ids)
    }

    // ── Edge cases ────────────────────────────────────────────────────────────

    @Test
    fun `getAllTags returns empty when no tags exist`() = runTest {
        every { bookTagDao.getAllTags() } returns flowOf(emptyList())

        val tags = repository.getAllTags().first()
        assertTrue(tags.isEmpty())
    }

    @Test
    fun `getAllCollections returns empty when no collections exist`() = runTest {
        every { collectionDao.getAllCollections() } returns flowOf(emptyList())

        val collections = repository.getAllCollections().first()
        assertTrue(collections.isEmpty())
    }

    @Test
    fun `getTagsForBook returns empty when book has no tags`() = runTest {
        coEvery { bookTagDao.getTagsForBook("nobook") } returns emptyList()

        val tags = repository.getTagsForBook("nobook")
        assertTrue(tags.isEmpty())
    }
}
