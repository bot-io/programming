package com.dualreader.app.domain.usecases

import com.dualreader.app.domain.entities.Book
import com.dualreader.app.domain.entities.PaginationStatus
import com.dualreader.app.domain.repositories.BookRepository
import com.dualreader.app.domain.services.EpubParserService
import java.util.UUID
import javax.inject.Inject

/**
 * Import an EPUB file into the library.
 *
 * Steps:
 * 1. Parse metadata (title, author, chapters, cover)
 * 2. Save book to repository
 * 3. Save cover image to internal storage
 *
 * Pagination is triggered separately (PaginateBookUseCase) because
 * it takes time and the user should see the book in the library immediately.
 *
 * Lesson from Flutter: pagination-on-import blocked the UI. Better to
 * import fast, show in library, paginate in background.
 */
class ImportBookUseCase @Inject constructor(
    private val bookRepository: BookRepository,
    private val epubParser: EpubParserService,
) {
    suspend operator fun invoke(filePath: String): Result<Book> {
        val result = runCatching {
            // Parse EPUB metadata
            val parsed = epubParser.parseMetadata(filePath)

            // Generate book ID upfront so cover file can use it
            val bookId = UUID.randomUUID().toString()

            // Save cover image to internal storage
            val coverPath = parsed.coverImageBytes?.let { bytes ->
                bookRepository.saveCoverImage(bytes, bookId) ?: ""
            } ?: ""

            val book = Book(
                id = bookId,
                title = parsed.title,
                author = parsed.author,
                coverPath = coverPath,
                filePath = filePath,
                language = parsed.language,
                chapters = parsed.chapters,
                paginationStatus = PaginationStatus.NOT_STARTED,
            )

            bookRepository.insertBook(book)
            book
        }

        // DR-170: Preserve cancellation semantics - don't wrap CancellationException in Result.failure
        result.exceptionOrNull()?.let { e ->
            if (e is kotlinx.coroutines.CancellationException) {
                throw e
            }
        }

        return result
    }
}
