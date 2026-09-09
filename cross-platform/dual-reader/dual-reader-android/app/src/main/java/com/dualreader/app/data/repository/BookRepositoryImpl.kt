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
    private val bookTagDao: com.dualreader.app.data.local.dao.BookTagDao,
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
        // Cascade: get book first to get source language for cache cleanup
        val book = bookDao.getById(id)
        val sourceLang = book?.language
        
        // Get page texts before deleting (for cache cleanup)
        val pages = pageDao.getPagesForBook(id)
        val pageTexts = pages.map { it.originalText }

        // Delete cascade: pages, bookmarks, tags, book
        pageDao.deletePagesForBook(id)
        bookmarkDao.deleteBookmarksForBook(id)
        bookTagDao.deleteTagsForBook(id)
        bookDao.deleteById(id)

        // Clear translation cache for this book's pages (DR-203: Use source language for composite key)
        if (pageTexts.isNotEmpty() && sourceLang != null) {
            try {
                translationCacheRepository.deleteForTexts(pageTexts, sourceLang)
            } catch (e: kotlinx.coroutines.CancellationException) {
                throw e // Propagate cancellation - don't swallow it (DR-110)
            } catch (e: Exception) {
                com.dualreader.app.util.AppLogger.e("deleteBook: Failed to clear translation cache for book $id: ${e.message}", e)
            }
        }

        // Delete cover file
        withContext(Dispatchers.IO) {
            try {
                val coversDir = File(context.filesDir, "covers")
                coversDir.listFiles()?.filter { it.name.startsWith(id) }?.forEach { it.delete() }
            } catch (e: kotlinx.coroutines.CancellationException) {
                throw e // Propagate cancellation - don't swallow it (DR-110)
            } catch (e: Exception) {
                com.dualreader.app.util.AppLogger.e("deleteBook: Failed to delete cover file for book $id: ${e.message}", e)
            }
        }
    }

    override suspend fun saveCoverImage(bytes: ByteArray, bookId: String): String? {
        return withContext(Dispatchers.IO) {
            try {
                val coversDir = File(context.filesDir, "covers").also { it.mkdirs() }
                // Detect format from magic bytes; fall back to .jpg
                // PNG magic: 89 50 4E 47 0D 0A 1A 0A
                // JPEG magic: FF D8 FF
                val extension = when {
                    bytes.size >= 8 &&
                        bytes[0] == 0x89.toByte() &&
                        bytes[1] == 0x50.toByte() &&
                        bytes[2] == 0x4E.toByte() &&
                        bytes[3] == 0x47.toByte() &&
                        bytes[4] == 0x0D.toByte() &&
                        bytes[5] == 0x0A.toByte() &&
                        bytes[6] == 0x1A.toByte() &&
                        bytes[7] == 0x0A.toByte() -> "png"
                    bytes.size >= 3 &&
                        bytes[0] == 0xFF.toByte() &&
                        bytes[1] == 0xD8.toByte() &&
                        bytes[2] == 0xFF.toByte() -> "jpg"
                    else -> "jpg"
                }
                val file = File(coversDir, "$bookId.$extension")
                file.writeBytes(bytes)
                file.absolutePath
            } catch (e: kotlinx.coroutines.CancellationException) {
                throw e // Propagate cancellation - don't swallow it (DR-131)
            } catch (e: Exception) {
                com.dualreader.app.util.AppLogger.e("saveCoverImage: Failed to save cover for book $bookId: ${e.message}", e)
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

    override suspend fun clearAllTranslations() =
        pageDao.clearAllTranslations()

    override suspend fun updatePageTranslation(bookId: String, pageIndex: Int, translationsJson: String?, modelsJson: String?) =
        pageDao.updatePageTranslations(bookId, pageIndex, translationsJson, modelsJson)

    override suspend fun getTranslatedPageCount(): Int =
        pageDao.getTranslatedPageCount()
}
