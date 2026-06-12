package com.dualreader.app.domain.export

import java.time.LocalDateTime

/**
 * A bookmark/annotation enriched with book metadata for export.
 */
data class ExportableBookmark(
    val bookTitle: String,
    val bookAuthor: String,
    val pageIndex: Int,
    val chapterIndex: Int = 0,
    val textSnippet: String,
    val note: String,
    val createdAt: LocalDateTime,
)
