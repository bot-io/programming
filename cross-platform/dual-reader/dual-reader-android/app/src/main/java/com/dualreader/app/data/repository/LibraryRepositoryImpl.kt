package com.dualreader.app.data.repository

import com.dualreader.app.data.local.dao.BookDao
import com.dualreader.app.data.local.dao.BookTagDao
import com.dualreader.app.data.local.dao.CollectionDao
import com.dualreader.app.data.local.entity.BookTagEntity
import com.dualreader.app.data.local.entity.CollectionBookEntity
import com.dualreader.app.data.local.entity.CollectionEntity
import com.dualreader.app.data.local.mapper.toDomain
import com.dualreader.app.domain.entities.Book
import com.dualreader.app.domain.entities.BookCollection
import com.dualreader.app.domain.entities.SortOrder
import com.dualreader.app.domain.repositories.LibraryRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class LibraryRepositoryImpl @Inject constructor(
    private val bookDao: BookDao,
    private val bookTagDao: BookTagDao,
    private val collectionDao: CollectionDao,
) : LibraryRepository {

    // ── Sorted books ──────────────────────────────────────────────────────────

    override fun getAllBooksSorted(sortOrder: SortOrder): Flow<List<Book>> {
        val flow = when (sortOrder) {
            SortOrder.TITLE -> bookDao.getAllBooksByTitle()
            SortOrder.AUTHOR -> bookDao.getAllBooksByAuthor()
            SortOrder.DATE_ADDED -> bookDao.getAllBooksByDateAdded()
            SortOrder.LAST_READ -> bookDao.getAllBooksByLastRead()
            SortOrder.PROGRESS -> {
                // Progress sorting is done in-memory after fetching all books
                // sorted by date added (as a base), then re-sorted by progress
                return bookDao.getAllBooksByDateAdded().map { list ->
                    list.map { it.toDomain() }.sortedByDescending { it.progressPercent }
                }
            }
        }
        return flow.map { list -> list.map { it.toDomain() } }
    }

    // ── Tags ──────────────────────────────────────────────────────────────────

    override fun getAllTags(): Flow<List<String>> =
        bookTagDao.getAllTags()

    override suspend fun getTagsForBook(bookId: String): List<String> =
        bookTagDao.getTagsForBook(bookId).map { it.tag }

    override suspend fun getAllBookTags(): Map<String, List<String>> =
        bookTagDao.getAllBookTagsSync()
            .groupBy { it.bookId }
            .mapValues { entry -> entry.value.map { it.tag } }

    override suspend fun addTag(bookId: String, tag: String) {
        // DR-100: Reject empty or whitespace-only tags
        val trimmedTag = tag.trim()
        if (trimmedTag.isNotEmpty()) {
            bookTagDao.insert(BookTagEntity(bookId = bookId, tag = trimmedTag))
        }
    }

    override suspend fun removeTag(bookId: String, tag: String) {
        bookTagDao.deleteTag(bookId, tag)
    }

    override suspend fun getBookIdsByTag(tag: String): List<String> =
        bookTagDao.getBookIdsByTag(tag)

    // ── Collections ───────────────────────────────────────────────────────────

    override fun getAllCollections(): Flow<List<BookCollection>> =
        collectionDao.getAllCollections().map { list ->
            list.map { it.toDomain() }
        }

    override suspend fun getCollection(id: Long): BookCollection? {
        val entity = collectionDao.getById(id) ?: return null
        val bookIds = collectionDao.getBookIdsForCollection(id)
        return entity.toDomain().copy(bookIds = bookIds)
    }

    override suspend fun createCollection(name: String): Long {
        val trimmedName = name.trim()
        if (trimmedName.isNotEmpty()) {
            return collectionDao.insert(CollectionEntity(name = trimmedName))
        }
        return -1L // Silent rejection - same pattern as addTag in DR-100
    }

    override suspend fun renameCollection(id: Long, newName: String) {
        val trimmedName = newName.trim()
        if (trimmedName.isEmpty()) {
            return // Silent rejection - same pattern as addTag in DR-100
        }
        val entity = collectionDao.getById(id) ?: return
        collectionDao.update(entity.copy(name = trimmedName))
    }

    override suspend fun deleteCollection(id: Long) {
        collectionDao.deleteById(id)
    }

    override suspend fun addBookToCollection(collectionId: Long, bookId: String) {
        collectionDao.addBookToCollection(CollectionBookEntity(collectionId, bookId))
    }

    override suspend fun removeBookFromCollection(collectionId: Long, bookId: String) {
        collectionDao.removeBookFromCollection(collectionId, bookId)
    }

    override suspend fun getBookIdsForCollection(collectionId: Long): List<String> =
        collectionDao.getBookIdsForCollection(collectionId)

    // ── Mapper extension ──────────────────────────────────────────────────────

    private fun CollectionEntity.toDomain() = BookCollection(
        id = id,
        name = name,
        createdAt = createdAt,
    )
}
