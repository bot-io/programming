package com.dualreader.app.domain.entities

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class LibraryEntitiesTest {

    @Test
    fun `BookTag holds bookId and tag`() {
        val tag = BookTag(bookId = "book-1", tag = "fiction")
        assertEquals("book-1", tag.bookId)
        assertEquals("fiction", tag.tag)
    }

    @Test
    fun `BookCollection defaults`() {
        val collection = BookCollection(name = "Favorites")
        assertEquals(0L, collection.id)
        assertEquals("Favorites", collection.name)
        assertTrue(collection.bookIds.isEmpty())
    }

    @Test
    fun `BookCollection with all fields`() {
        val collection = BookCollection(
            id = 5,
            name = "Sci-Fi",
            createdAt = 1700000000000L,
            bookIds = listOf("b1", "b2"),
        )
        assertEquals(5L, collection.id)
        assertEquals("Sci-Fi", collection.name)
        assertEquals(1700000000000L, collection.createdAt)
        assertEquals(listOf("b1", "b2"), collection.bookIds)
    }

    @Test
    fun `SortOrder has all expected values`() {
        val orders = SortOrder.entries
        assertEquals(5, orders.size)
        assertTrue(orders.contains(SortOrder.LAST_READ))
        assertTrue(orders.contains(SortOrder.TITLE))
        assertTrue(orders.contains(SortOrder.AUTHOR))
        assertTrue(orders.contains(SortOrder.DATE_ADDED))
        assertTrue(orders.contains(SortOrder.PROGRESS))
    }

    @Test
    fun `BookTag data class equality`() {
        val tag1 = BookTag("b1", "fiction")
        val tag2 = BookTag("b1", "fiction")
        val tag3 = BookTag("b2", "fiction")
        assertEquals(tag1, tag2)
        assertTrue(tag1 != tag3)
    }

    @Test
    fun `BookCollection data class equality`() {
        val c1 = BookCollection(id = 1, name = "A", createdAt = 100, bookIds = listOf("b1"))
        val c2 = BookCollection(id = 1, name = "A", createdAt = 100, bookIds = listOf("b1"))
        assertEquals(c1, c2)
    }
}
