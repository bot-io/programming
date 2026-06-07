package com.dualreader.app.domain.entities

import java.time.LocalDateTime

/**
 * A user-created bookmark in a book.
 */
data class Bookmark(
    val id: String = java.util.UUID.randomUUID().toString(),
    val bookId: String,
    val pageIndex: Int,
    val chapterIndex: Int,
    val textSnippet: String = "",
    val note: String = "",
    val createdAt: LocalDateTime = LocalDateTime.now(),
)
