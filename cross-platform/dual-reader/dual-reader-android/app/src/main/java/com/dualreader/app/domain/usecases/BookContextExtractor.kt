package com.dualreader.app.domain.usecases

import com.dualreader.app.domain.entities.Book
import com.dualreader.app.domain.entities.Page

/**
 * Extracts book-level context from the first few pages of a book.
 *
 * This context is injected into translation prompts so the LLM knows the
 * book's title, author, and opening text.  This dramatically improves
 * consistency of character names, setting descriptions, and tone across
 * the entire translation — especially for the first few pages where the
 * LLM has no prior context to work with.
 *
 * The extracted context is cached per-book (in the ViewModel) so that
 * re-translation of individual pages doesn't need to re-extract it.
 */
object BookContextExtractor {

    /** Number of opening pages to include in the context. */
    const val OPENING_PAGES_COUNT = 3

    /** Maximum total characters for the opening text (keeps prompt small). */
    const val MAX_OPENING_CHARS = 2000

    /**
     * Extract a [BookContext] from a book's metadata and its paginated content.
     *
     * @param book  The book entity (provides title, author, language).
     * @param pages All paginated pages for the book (must be pre-sorted by index).
     * @return A [BookContext] with opening text from the first few pages.
     */
    fun extract(book: Book, pages: List<Page>): BookContext {
        val openingPages = pages
            .sortedBy { it.index }
            .take(OPENING_PAGES_COUNT)
            .map { it.originalText.trim() }
            .filter { it.isNotEmpty() }

        val openingText = openingPages
            .joinToString("\n\n")
            .take(MAX_OPENING_CHARS)

        return BookContext(
            title = book.title,
            author = book.author,
            language = book.language,
            openingText = openingText,
        )
    }
}

/**
 * Immutable snapshot of book-level context used to improve translation quality.
 *
 * Passed through the translation pipeline and injected into the system prompt
 * on the Worker side so the LLM has knowledge of the book's identity and tone.
 */
data class BookContext(
    /** Book title — helps the LLM understand genre and register. */
    val title: String,
    /** Book author — helps the LLM match the author's style. */
    val author: String,
    /** Source language of the book (ISO 639-1), or null if unknown. */
    val language: String?,
    /** Opening text from the first few pages (truncated to [BookContextExtractor.MAX_OPENING_CHARS]). */
    val openingText: String,
)
