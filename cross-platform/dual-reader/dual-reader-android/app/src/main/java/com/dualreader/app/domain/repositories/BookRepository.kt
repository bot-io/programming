package com.dualreader.app.domain.repositories

import com.dualreader.app.domain.entities.Book
import com.dualreader.app.domain.entities.Page
import kotlinx.coroutines.flow.Flow

/**
 * Book repository — the single source of truth for book data.
 *
 * Lesson from Flutter: keep the repository interface in domain layer.
 * Implementation lives in data layer. This allows testing use cases
 * with a fake repository without touching Android framework.
 */
interface BookRepository {
    fun getAllBooks(): Flow<List<Book>>
    suspend fun getBookById(id: String): Book?
    suspend fun insertBook(book: Book)
    suspend fun updateBook(book: Book)
    suspend fun deleteBook(id: String)

    // Cover image storage
    suspend fun saveCoverImage(bytes: ByteArray, bookId: String): String?

    // Pagination data
    suspend fun getPagesForBook(bookId: String): List<Page>
    suspend fun getPage(bookId: String, pageIndex: Int): Page?
    suspend fun savePages(pages: List<Page>)
    suspend fun deletePagesForBook(bookId: String)
    suspend fun getPageCount(bookId: String): Int
}
