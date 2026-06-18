package com.dualreader.app.domain.services

import com.dualreader.app.domain.entities.Book
import com.dualreader.app.domain.entities.BookChapter

/**
 * EPUB parsing service interface.
 *
 * Lesson from Flutter: the epubx library was fragile and kept breaking
 * on API changes. In Kotlin, epub4j-kotlin is much more stable, but
 * we still hide it behind this interface for testability.
 *
 * The implementation is in the data layer. The domain layer only
 * knows about this interface.
 */
interface EpubParserService {
    /**
     * Parse an EPUB file and extract metadata + chapter structure.
     * Does NOT extract full chapter content — that's done lazily.
     */
    suspend fun parseMetadata(filePath: String): ParsedEpub

    /**
     * Extract the full text of a specific chapter.
     * Called lazily when the user navigates to that chapter.
     */
    suspend fun extractChapterText(filePath: String, chapterIndex: Int): String

    /**
     * Extract cover image bytes, or null if none found.
     */
    suspend fun extractCoverImage(filePath: String): ByteArray?

    /**
     * Extract full text of the book as a single string (legacy, for compatibility).
     */
    suspend fun extractFullText(filePath: String): String

    /**
     * Extract the book's content as individual paragraphs, preserving chapter boundaries.
     *
     * Each paragraph is a self-contained block of text (typically a <p> tag from the EPUB).
     * This replaces the old extractFullText + paginate pipeline.
     */
    suspend fun extractParagraphs(filePath: String): List<ExtractedParagraph>
}

/**
 * A single paragraph extracted from an EPUB, with its chapter context.
 */
data class ExtractedParagraph(
    val text: String,
    val chapterIndex: Int,
)

data class ParsedEpub(
    val title: String,
    val author: String,
    val language: String? = null,
    val publisher: String? = null,
    val description: String? = null,
    val chapters: List<BookChapter>,
    val coverImageBytes: ByteArray? = null,
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is ParsedEpub) return false
        return title == other.title && author == other.author
    }

    override fun hashCode(): Int = 31 * title.hashCode() + author.hashCode()
}
