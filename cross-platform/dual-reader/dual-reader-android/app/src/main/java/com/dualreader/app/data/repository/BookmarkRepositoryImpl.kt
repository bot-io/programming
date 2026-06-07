package com.dualreader.app.data.repository

import com.dualreader.app.data.local.dao.BookmarkDao
import com.dualreader.app.data.local.mapper.toDomain
import com.dualreader.app.data.local.mapper.toEntity
import com.dualreader.app.domain.entities.Bookmark
import com.dualreader.app.domain.repositories.BookmarkRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class BookmarkRepositoryImpl @Inject constructor(
    private val bookmarkDao: BookmarkDao,
) : BookmarkRepository {

    override fun getBookmarksForBook(bookId: String): Flow<List<Bookmark>> =
        bookmarkDao.getBookmarksForBook(bookId).map { list -> list.map { it.toDomain() } }

    override suspend fun addBookmark(bookmark: Bookmark) =
        bookmarkDao.insert(bookmark.toEntity())

    override suspend fun deleteBookmark(id: String) =
        bookmarkDao.deleteById(id)

    override suspend fun deleteBookmarksForBook(bookId: String) =
        bookmarkDao.deleteBookmarksForBook(bookId)
}
