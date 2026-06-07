package com.dualreader.app.domain.entities

/**
 * A single page of content — the unit of display in the reader.
 *
 * Content is plain text (HTML stripped during parsing).
 * The original HTML is NOT stored — lesson from Flutter where
 * trying to preserve HTML caused bugs with the text sanitizer.
 */
data class Page(
    val index: Int,
    val bookId: String,
    val chapterIndex: Int,
    val originalText: String,
    val translatedText: String? = null,
    val startCharOffset: Int = 0,
    val endCharOffset: Int = 0,
)
