package com.dualreader.app.domain.entities

/**
 * A tag assigned to a book. Tags are flat strings — no hierarchy.
 */
data class BookTag(
    val bookId: String,
    val tag: String,
)

/**
 * A named collection of books. Collections allow grouping books
 * by user-defined criteria (e.g., "Sci-Fi", "To Read").
 */
data class BookCollection(
    val id: Long = 0,
    val name: String,
    val createdAt: Long = System.currentTimeMillis(),
    val bookIds: List<String> = emptyList(),
)

/**
 * Sort order options for the library.
 */
enum class SortOrder {
    LAST_READ,
    TITLE,
    AUTHOR,
    DATE_ADDED,
    PROGRESS,
}
