package com.dualreader.app.data.repository

import android.content.Context
import com.dualreader.app.data.local.dao.BookDao
import com.dualreader.app.data.local.dao.BookmarkDao
import com.dualreader.app.data.local.dao.PageDao
import com.dualreader.app.data.local.mapper.toDomain
import com.dualreader.app.data.local.mapper.toEntity
import com.dualreader.app.domain.entities.Book
import com.dualreader.app.domain.entities.Page
import com.dualreader.app.domain.repositories.BookRepository
import com.dualreader.app.domain.repositories.TranslationCacheRepository
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.withContext
import java.io.File
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class BookRepositoryImpl @Inject constructor(
    @ApplicationContext private val context: Context,
    private val bookDao: BookDao,
    private val pageDao: PageDao,
    private val bookmarkDao: BookmarkDao,
    private val translationCacheRepository: TranslationCacheRepository,
) : BookRepository {

    override fun getAllBooks(): Flow<List<Book>> =
        bookDao.getAllBooks().map { list -> list.map { it.toDomain() } }

    override suspend fun getBookById(id: String): Book? =
        bookDao.getById(id)?.toDomain()

    override suspend fun insertBook(book: Book) =
        bookDao.insert(book.toEntity())

    override suspend fun updateBook(book: Book) =
        bookDao.update(book.toEntity())

    override suspend fun deleteBook(id: String) {
        // Cascade: get page texts first (for cache cleanup), then delete everything
        val pages = pageDao.getPagesForBook(id)
        val pageTexts = pages.map { it.originalText }

        pageDao.deletePagesForBook(id)
        bookmarkDao.deleteBookmarksForBook(id)
        bookDao.deleteById(id)

        // Clear translation cache for this book's pages
        if (pageTexts.isNotEmpty()) {
            try {
                translationCacheRepository.deleteForTexts(pageTexts)
            } catch (_: Exception) { }
        }

        // Delete cover file
        withContext(Dispatchers.IO) {
            val coversDir = File(context.filesDir, "covers")
            coversDir.listFiles()?.filter { it.name.startsWith(id) }?.forEach { it.delete() }
        }
    }

    override suspend fun saveCoverImage(bytes: ByteArray, bookId: String): String? {
        return withContext(Dispatchers.IO) {
            try {
                val coversDir = File(context.filesDir, "covers").also { it.mkdirs() }
                // Detect format from magic bytes; fall back to .jpg
                val extension = when {
                    bytes.size >= 8 && String(bytes, 0, 8).contains("PNG") -> "png"
                    bytes.size >= 3 && bytes[0] == 0xFF.toByte() && bytes[1] == 0xD8.toByte() -> "jpg"
                    else -> "jpg"
                }
                val file = File(coversDir, "$bookId.$extension")
                file.writeBytes(bytes)
                file.absolutePath
            } catch (_: Exception) {
                null
            }
        }
    }

    override suspend fun getPagesForBook(bookId: String): List<Page> =
        pageDao.getPagesForBook(bookId).map { it.toDomain() }

    override suspend fun getPage(bookId: String, pageIndex: Int): Page? =
        pageDao.getPage(bookId, pageIndex)?.toDomain()

    override suspend fun savePages(pages: List<Page>) =
        pageDao.insertAll(pages.map { it.toEntity() })

    override suspend fun deletePagesForBook(bookId: String) =
        pageDao.deletePagesForBook(bookId)

    override suspend fun getPageCount(bookId: String): Int =
        pageDao.getPageCount(bookId)
}
