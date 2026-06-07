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
     * Extract full text of the book for pagination.
     */
    suspend fun extractFullText(filePath: String): String
}

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
