package com.dualreader.app.data.repository

import com.dualreader.app.data.local.dao.BookmarkDao
import com.dualreader.app.data.local.entity.BookmarkEntity
import com.dualreader.app.data.local.mapper.toDomain
import com.dualreader.app.data.local.mapper.toEntity
import com.dualreader.app.domain.entities.Bookmark
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.mockk
import io.mockk.unmockkAll
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.time.LocalDateTime
import java.time.ZoneOffset

/**
 * Unit tests for [BookmarkRepositoryImpl].
 *
 * Covers DR-039 acceptance criteria:
 *  1. add / delete / get bookmarks
 *  2. bookmark "persistence across sessions" (repository forwards DAO emissions on re-read)
 *  3. DR-024 regression — addBookmark inserts even when bookmarks already exist (no-op bug)
 */
class BookmarkRepositoryImplTest {

    private lateinit var dao: BookmarkDao
    private lateinit var repository: BookmarkRepositoryImpl

    // Whole-second timestamp so the entity↔domain round-trip is exact
    // (mapper truncates to seconds via ofEpochSecond(millis/1000)).
    private val fixedTime: LocalDateTime = LocalDateTime.of(2026, 6, 20, 12, 30, 45)
    private val fixedTimeMillis: Long = fixedTime.atZone(ZoneOffset.UTC).toInstant().toEpochMilli()

    private fun sampleBookmark(
        id: String = "bm-1",
        bookId: String = "book-1",
    ) = Bookmark(
        id = id,
        bookId = bookId,
        pageIndex = 5,
        chapterIndex = 2,
        textSnippet = "It was the best of times",
        note = "memorable opening",
        createdAt = fixedTime,
    )

    private fun sampleEntity(
        id: String = "bm-1",
        bookId: String = "book-1",
    ) = BookmarkEntity(
        id = id,
        bookId = bookId,
        pageIndex = 5,
        chapterIndex = 2,
        textSnippet = "It was the best of times",
        note = "memorable opening",
        createdAt = fixedTimeMillis,
    )

    @Before
    fun setUp() {
        dao = mockk(relaxed = true)
        repository = BookmarkRepositoryImpl(dao)
    }

    @After
    fun tearDown() {
        unmockkAll()
    }

    // ─── getBookmarksForBook ───────────────────────────────────────────────

    @Test
    fun `getBookmarksForBook returns empty list when dao emits empty`() = runTest {
        every { dao.getBookmarksForBook("book-1") } returns flowOf(emptyList())

        val result = repository.getBookmarksForBook("book-1").first()

        assertTrue(result.isEmpty())
    }

    @Test
    fun `getBookmarksForBook maps entities to domain bookmarks`() = runTest {
        every { dao.getBookmarksForBook("book-1") } returns
            flowOf(listOf(sampleEntity("bm-1"), sampleEntity("bm-2").copy(pageIndex = 9)))

        val result = repository.getBookmarksForBook("book-1").first()

        assertEquals(2, result.size)
        assertEquals("bm-1", result[0].id)
        assertEquals("bm-2", result[1].id)
    }

    @Test
    fun `getBookmarksForBook maps all fields correctly`() = runTest {
        every { dao.getBookmarksForBook("book-1") } returns flowOf(listOf(sampleEntity()))

        val result = repository.getBookmarksForBook("book-1").first()

        val bm = result.single()
        assertEquals("bm-1", bm.id)
        assertEquals("book-1", bm.bookId)
        assertEquals(5, bm.pageIndex)
        assertEquals(2, bm.chapterIndex)
        assertEquals("It was the best of times", bm.textSnippet)
        assertEquals("memorable opening", bm.note)
        assertEquals(fixedTime, bm.createdAt)
    }

    @Test
    fun `getBookmarksForBook is scoped to the given bookId`() = runTest {
        every { dao.getBookmarksForBook("book-1") } returns flowOf(listOf(sampleEntity()))
        every { dao.getBookmarksForBook("book-2") } returns flowOf(emptyList())

        assertEquals(1, repository.getBookmarksForBook("book-1").first().size)
        assertTrue(repository.getBookmarksForBook("book-2").first().isEmpty())
    }

    // ─── Criterion 2: persistence across sessions ──────────────────────────
    // Repository is a thin wrapper; "persistence" is observable as: a value written
    // via addBookmark surfaces on a subsequent read of the DAO flow.

    @Test
    fun `addBookmark then read reflects the inserted bookmark`() = runTest {
        // Session 1: nothing yet
        every { dao.getBookmarksForBook("book-1") } returns flowOf(emptyList())
        assertTrue(repository.getBookmarksForBook("book-1").first().isEmpty())

        // Write
        coEvery { dao.insert(any()) } returns Unit
        repository.addBookmark(sampleBookmark())

        // Session 2: DAO now reports the stored entity
        every { dao.getBookmarksForBook("book-1") } returns flowOf(listOf(sampleEntity()))

        val result = repository.getBookmarksForBook("book-1").first()
        assertEquals(1, result.size)
        assertEquals("bm-1", result[0].id)
    }

    // ─── addBookmark ───────────────────────────────────────────────────────

    @Test
    fun `addBookmark inserts a mapped entity into the dao`() = runTest {
        coEvery { dao.insert(any()) } returns Unit

        repository.addBookmark(sampleBookmark())

        coVerify(exactly = 1) { dao.insert(any()) }
    }

    @Test
    fun `addBookmark maps every field onto the entity`() = runTest {
        coEvery { dao.insert(any()) } returns Unit
        val bookmark = sampleBookmark()

        repository.addBookmark(bookmark)

        coVerify {
            dao.insert(match { e ->
                e.id == "bm-1" &&
                    e.bookId == "book-1" &&
                    e.pageIndex == 5 &&
                    e.chapterIndex == 2 &&
                    e.textSnippet == "It was the best of times" &&
                    e.note == "memorable opening" &&
                    e.createdAt == fixedTimeMillis
            })
        }
    }

    @Test
    fun `addBookmark converts createdAt to epoch millis in UTC`() = runTest {
        coEvery { dao.insert(any()) } returns Unit
        val newTime = LocalDateTime.of(2020, 1, 1, 0, 0, 0)

        repository.addBookmark(sampleBookmark().copy(createdAt = newTime))

        val expected = newTime.atZone(ZoneOffset.UTC).toInstant().toEpochMilli()
        coVerify { dao.insert(match { it.createdAt == expected }) }
    }

    @Test
    fun `addBookmark preserves a caller-supplied id`() = runTest {
        coEvery { dao.insert(any()) } returns Unit

        repository.addBookmark(sampleBookmark(id = "custom-id-999"))

        coVerify { dao.insert(match { it.id == "custom-id-999" }) }
    }

    // ─── Criterion 3: DR-024 regression — add must not be a no-op when
    //     bookmarks already exist ────────────────────────────────────────────

    @Test
    fun `addBookmark inserts even when bookmarks already exist`() = runTest {
        // Simulate the sheet already showing bookmarks (DR-024 pre-fix condition)
        every { dao.getBookmarksForBook("book-1") } returns
            flowOf(listOf(sampleEntity("bm-existing")))
        coEvery { dao.insert(any()) } returns Unit

        repository.addBookmark(sampleBookmark(id = "bm-new"))

        // The whole point of the DR-024 fix: insert must still fire.
        coVerify(exactly = 1) { dao.insert(match { it.id == "bm-new" }) }
    }

    @Test
    fun `addBookmark does not delete existing bookmarks`() = runTest {
        coEvery { dao.insert(any()) } returns Unit

        repository.addBookmark(sampleBookmark())

        coVerify(exactly = 0) { dao.deleteById(any()) }
        coVerify(exactly = 0) { dao.deleteBookmarksForBook(any()) }
    }

    // ─── deleteBookmark ────────────────────────────────────────────────────

    @Test
    fun `deleteBookmark delegates to dao deleteById with the exact id`() = runTest {
        coEvery { dao.deleteById(any()) } returns Unit

        repository.deleteBookmark("bm-42")

        coVerify(exactly = 1) { dao.deleteById("bm-42") }
    }

    @Test
    fun `deleteBookmark does not touch other books bookmarks`() = runTest {
        coEvery { dao.deleteById(any()) } returns Unit

        repository.deleteBookmark("bm-42")

        coVerify(exactly = 0) { dao.deleteBookmarksForBook(any()) }
    }

    // ─── deleteBookmarksForBook ────────────────────────────────────────────

    @Test
    fun `deleteBookmarksForBook delegates to dao with the exact bookId`() = runTest {
        coEvery { dao.deleteBookmarksForBook(any()) } returns Unit

        repository.deleteBookmarksForBook("book-7")

        coVerify(exactly = 1) { dao.deleteBookmarksForBook("book-7") }
    }

    @Test
    fun `deleteBookmarksForBook does not call single deleteById`() = runTest {
        coEvery { dao.deleteBookmarksForBook(any()) } returns Unit

        repository.deleteBookmarksForBook("book-7")

        coVerify(exactly = 0) { dao.deleteById(any()) }
    }

    @Test
    fun `deleteBookmarksForBook does not insert anything`() = runTest {
        coEvery { dao.deleteBookmarksForBook(any()) } returns Unit

        repository.deleteBookmarksForBook("book-7")

        coVerify(exactly = 0) { dao.insert(any()) }
    }

    // ─── Mapper round-trip (entity ↔ domain) ───────────────────────────────

    @Test
    fun `Bookmark to entity to domain round-trips all fields`() {
        val original = sampleBookmark()

        val roundTripped = original.toEntity().toDomain()

        assertEquals(original.id, roundTripped.id)
        assertEquals(original.bookId, roundTripped.bookId)
        assertEquals(original.pageIndex, roundTripped.pageIndex)
        assertEquals(original.chapterIndex, roundTripped.chapterIndex)
        assertEquals(original.textSnippet, roundTripped.textSnippet)
        assertEquals(original.note, roundTripped.note)
        // Whole-second precision ⇒ exact round-trip
        assertEquals(original.createdAt, roundTripped.createdAt)
    }

    @Test
    fun `BookmarkEntity to domain to entity round-trips all fields`() {
        val original = sampleEntity()

        val roundTripped = original.toDomain().toEntity()

        assertEquals(original.id, roundTripped.id)
        assertEquals(original.bookId, roundTripped.bookId)
        assertEquals(original.pageIndex, roundTripped.pageIndex)
        assertEquals(original.chapterIndex, roundTripped.chapterIndex)
        assertEquals(original.textSnippet, roundTripped.textSnippet)
        assertEquals(original.note, roundTripped.note)
        assertEquals(original.createdAt, roundTripped.createdAt)
    }

    @Test
    fun `default-constructed Bookmark is still insertable`() = runTest {
        coEvery { dao.insert(any()) } returns Unit
        // Only required fields provided; id/createdAt/snippet/note default
        val bookmark = Bookmark(bookId = "book-1", pageIndex = 0, chapterIndex = 0)

        repository.addBookmark(bookmark)

        coVerify {
            dao.insert(match { e ->
                e.bookId == "book-1" &&
                    e.pageIndex == 0 &&
                    e.id.isNotEmpty() &&
                    e.createdAt > 0L
            })
        }
    }
}
