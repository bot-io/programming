package com.dualreader.app.domain.repositories

import com.dualreader.app.domain.entities.Book
import com.dualreader.app.domain.entities.BookCollection
import com.dualreader.app.domain.entities.SortOrder
import kotlinx.coroutines.flow.Flow

/**
 * Library repository — manages tags, collections, and sorted book queries.
 * Extends the basic book listing with library management features.
 */
interface LibraryRepository {

    // ── Sorted books ──────────────────────────────────────────────────────────

    fun getAllBooksSorted(sortOrder: SortOrder): Flow<List<Book>>

    // ── Tags ──────────────────────────────────────────────────────────────────

    fun getAllTags(): Flow<List<String>>

    suspend fun getTagsForBook(bookId: String): List<String>

    suspend fun addTag(bookId: String, tag: String)

    suspend fun removeTag(bookId: String, tag: String)

    suspend fun getBookIdsByTag(tag: String): List<String>

    // ── Collections ───────────────────────────────────────────────────────────

    fun getAllCollections(): Flow<List<BookCollection>>

    suspend fun getCollection(id: Long): BookCollection?

    suspend fun createCollection(name: String): Long

    suspend fun renameCollection(id: Long, newName: String)

    suspend fun deleteCollection(id: Long)

    suspend fun addBookToCollection(collectionId: Long, bookId: String)

    suspend fun removeBookFromCollection(collectionId: Long, bookId: String)

    suspend fun getBookIdsForCollection(collectionId: Long): List<String>
}
