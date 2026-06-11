package com.dualreader.app.domain.entities

import java.time.LocalDateTime
import java.util.UUID

/**
 * Core book entity — represents an imported ebook in the library.
 *
 * Lesson from Flutter: keep this immutable with copy().
 * Room will persist it via BookEntity (data layer).
 */
data class Book(
    val id: String = UUID.randomUUID().toString(),
    val title: String,
    val author: String,
    val coverPath: String = "",
    val filePath: String,
    val format: BookFormat = BookFormat.EPUB,
    val language: String? = null,
    val importedAt: LocalDateTime = LocalDateTime.now(),
    val lastReadAt: LocalDateTime? = null,
    val currentPage: Int = 0,
    val totalPages: Int = 0,
    val paginationStatus: PaginationStatus = PaginationStatus.NOT_STARTED,
    val paginationProgress: Float = 0f,
    val chapters: List<BookChapter> = emptyList(),
) {
    val canBeOpened: Boolean
        get() = paginationStatus == PaginationStatus.COMPLETED && totalPages > 0

    /** Progress as a 0..1 fraction. */
    val progressPercent: Float
        get() = if (totalPages > 0) currentPage.toFloat() / totalPages else 0f

    /** Human-readable progress text, e.g. "45%" or "3/7". */
    val progressLabel: String
        get() = if (totalPages > 0) "${(progressPercent * 100).toInt()}%" else ""

    /** Whether this book has any reading progress (not on first page). */
    val hasProgress: Boolean
        get() = currentPage > 0 && totalPages > 0
}

enum class BookFormat {
    EPUB,
}

enum class PaginationStatus {
    NOT_STARTED,
    IN_PROGRESS,
    COMPLETED,
    FAILED,
}

/**
 * Lightweight chapter reference stored with the book.
 * Full chapter content is loaded on demand from the EPUB file.
 */
data class BookChapter(
    val index: Int,
    val title: String,
    val level: Int = 0,
    val startIndex: Int = 0,
    val endIndex: Int = 0,
)
