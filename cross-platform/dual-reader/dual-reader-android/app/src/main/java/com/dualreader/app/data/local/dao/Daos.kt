package com.dualreader.app.data.local.dao

import androidx.room.*
import com.dualreader.app.data.local.entity.BookEntity
import com.dualreader.app.data.local.entity.BookTagEntity
import com.dualreader.app.data.local.entity.CollectionBookEntity
import com.dualreader.app.data.local.entity.CollectionEntity
import com.dualreader.app.data.local.entity.PageEntity
import com.dualreader.app.data.local.entity.BookmarkEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface BookDao {
    @Query("SELECT * FROM books ORDER BY lastReadAt DESC NULLS LAST, importedAt DESC")
    fun getAllBooks(): Flow<List<BookEntity>>

    @Query("SELECT * FROM books ORDER BY title COLLATE NOCASE ASC")
    fun getAllBooksByTitle(): Flow<List<BookEntity>>

    @Query("SELECT * FROM books ORDER BY author COLLATE NOCASE ASC, title COLLATE NOCASE ASC")
    fun getAllBooksByAuthor(): Flow<List<BookEntity>>

    @Query("SELECT * FROM books ORDER BY importedAt DESC")
    fun getAllBooksByDateAdded(): Flow<List<BookEntity>>

    @Query("SELECT * FROM books ORDER BY lastReadAt DESC NULLS LAST")
    fun getAllBooksByLastRead(): Flow<List<BookEntity>>

    @Query("SELECT * FROM books WHERE id = :id")
    suspend fun getById(id: String): BookEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(book: BookEntity)

    @Update
    suspend fun update(book: BookEntity)

    @Query("DELETE FROM books WHERE id = :id")
    suspend fun deleteById(id: String)

    @Query("SELECT COUNT(*) FROM pages WHERE bookId = :bookId")
    suspend fun getPageCount(bookId: String): Int
}

@Dao
interface PageDao {
    @Query("SELECT * FROM pages WHERE bookId = :bookId ORDER BY pageIndex ASC")
    suspend fun getPagesForBook(bookId: String): List<PageEntity>

    @Query("SELECT * FROM pages WHERE bookId = :bookId AND pageIndex = :pageIndex LIMIT 1")
    suspend fun getPage(bookId: String, pageIndex: Int): PageEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertAll(pages: List<PageEntity>)

    @Query("DELETE FROM pages WHERE bookId = :bookId")
    suspend fun deletePagesForBook(bookId: String)

    @Query("SELECT COUNT(*) FROM pages WHERE bookId = :bookId")
    suspend fun getPageCount(bookId: String): Int
}

@Dao
interface BookmarkDao {
    @Query("SELECT * FROM bookmarks WHERE bookId = :bookId ORDER BY createdAt DESC")
    fun getBookmarksForBook(bookId: String): Flow<List<BookmarkEntity>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(bookmark: BookmarkEntity)

    @Query("DELETE FROM bookmarks WHERE id = :id")
    suspend fun deleteById(id: String)

    @Query("DELETE FROM bookmarks WHERE bookId = :bookId")
    suspend fun deleteBookmarksForBook(bookId: String)
}

// ── Tags ──────────────────────────────────────────────────────────────────────

@Dao
interface BookTagDao {
    @Query("SELECT * FROM book_tags WHERE bookId = :bookId")
    suspend fun getTagsForBook(bookId: String): List<BookTagEntity>

    @Query("SELECT DISTINCT tag FROM book_tags ORDER BY tag COLLATE NOCASE ASC")
    fun getAllTags(): Flow<List<String>>

    @Query("SELECT DISTINCT tag FROM book_tags")
    suspend fun getAllTagsSync(): List<String>

    @Insert(onConflict = OnConflictStrategy.IGNORE)
    suspend fun insert(tag: BookTagEntity)

    @Query("DELETE FROM book_tags WHERE bookId = :bookId AND tag = :tag")
    suspend fun deleteTag(bookId: String, tag: String)

    @Query("DELETE FROM book_tags WHERE bookId = :bookId")
    suspend fun deleteTagsForBook(bookId: String)

    @Query("SELECT bookId FROM book_tags WHERE tag = :tag")
    suspend fun getBookIdsByTag(tag: String): List<String>
}

// ── Collections ──────────────────────────────────────────────────────────────

@Dao
interface CollectionDao {
    @Query("SELECT * FROM collections ORDER BY name COLLATE NOCASE ASC")
    fun getAllCollections(): Flow<List<CollectionEntity>>

    @Query("SELECT * FROM collections ORDER BY name COLLATE NOCASE ASC")
    suspend fun getAllCollectionsSync(): List<CollectionEntity>

    @Query("SELECT * FROM collections WHERE id = :id")
    suspend fun getById(id: Long): CollectionEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(collection: CollectionEntity): Long

    @Update
    suspend fun update(collection: CollectionEntity)

    @Query("DELETE FROM collections WHERE id = :id")
    suspend fun deleteById(id: Long)

    // ── Collection-Book junction ──

    @Insert(onConflict = OnConflictStrategy.IGNORE)
    suspend fun addBookToCollection(crossRef: CollectionBookEntity)

    @Query("DELETE FROM collection_books WHERE collectionId = :collectionId AND bookId = :bookId")
    suspend fun removeBookFromCollection(collectionId: Long, bookId: String)

    @Query("DELETE FROM collection_books WHERE collectionId = :collectionId")
    suspend fun removeBooksFromCollection(collectionId: Long)

    @Query("SELECT bookId FROM collection_books WHERE collectionId = :collectionId")
    suspend fun getBookIdsForCollection(collectionId: Long): List<String>

    @Query("SELECT COUNT(*) FROM collection_books WHERE collectionId = :collectionId")
    suspend fun getBookCountForCollection(collectionId: Long): Int
}
