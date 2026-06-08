package com.dualreader.app.data.local.entity

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(tableName = "books")
data class BookEntity(
    @PrimaryKey
    val id: String,
    val title: String,
    val author: String,
    val coverPath: String = "",
    val filePath: String,
    val format: String = "EPUB",
    val language: String? = null,
    val importedAt: Long = System.currentTimeMillis(),
    val lastReadAt: Long? = null,
    val currentPage: Int = 0,
    val totalPages: Int = 0,
    val paginationStatus: String = "NOT_STARTED",
    val paginationProgress: Float = 0f,
    val chaptersJson: String = "[]",
)

@Entity(
    tableName = "pages",
    foreignKeys = [
        ForeignKey(
            entity = BookEntity::class,
            parentColumns = ["id"],
            childColumns = ["bookId"],
            onDelete = ForeignKey.CASCADE,
        ),
    ],
    indices = [Index(value = ["bookId", "pageIndex"], unique = true)],
)
data class PageEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    val bookId: String,
    val pageIndex: Int,
    val chapterIndex: Int,
    val originalText: String,
    val translationsJson: String? = null,
    val startCharOffset: Int = 0,
    val endCharOffset: Int = 0,
)

@Entity(
    tableName = "bookmarks",
    foreignKeys = [
        ForeignKey(
            entity = BookEntity::class,
            parentColumns = ["id"],
            childColumns = ["bookId"],
            onDelete = ForeignKey.CASCADE,
        ),
    ],
    indices = [Index(value = ["bookId"])],
)
data class BookmarkEntity(
    @PrimaryKey
    val id: String,
    val bookId: String,
    val pageIndex: Int,
    val chapterIndex: Int,
    val textSnippet: String = "",
    val note: String = "",
    val createdAt: Long = System.currentTimeMillis(),
)
