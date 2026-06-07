package com.dualreader.app.domain.usecases

import com.dualreader.app.domain.entities.Book
import com.dualreader.app.domain.entities.Page
import com.dualreader.app.domain.entities.PaginationStatus
import com.dualreader.app.domain.repositories.BookRepository
import com.dualreader.app.domain.services.EpubParserService
import com.dualreader.app.domain.services.PaginationService
import javax.inject.Inject

/**
 * Paginate a book's full text into screen-sized pages.
 *
 * This is a long-running operation — should be called from a background
 * coroutine. Progress is tracked via book.paginationProgress (0f to 1f).
 *
 * Lesson from Flutter: pagination took too long on the main thread.
 * In Kotlin, we use coroutines with Dispatchers.Default.
 */
class PaginateBookUseCase @Inject constructor(
    private val bookRepository: BookRepository,
    private val epubParser: EpubParserService,
    private val paginationService: PaginationService,
) {
    suspend operator fun invoke(
        book: Book,
        screenWidth: Int,
        screenHeight: Int,
        fontSize: Float = 16f,
        lineHeight: Float = 1.5f,
        margins: Int = 16,
    ): Result<Unit> {
        return runCatching {
            // Mark as in-progress
            bookRepository.updateBook(
                book.copy(
                    paginationStatus = PaginationStatus.IN_PROGRESS,
                    paginationProgress = 0f,
                )
            )

            try {
                // Extract full text
                val fullText = epubParser.extractFullText(book.filePath)

                // Split into paragraphs, then chapters for better page boundaries
                val pages = paginationService.paginate(
                    text = fullText,
                    availableWidth = screenWidth,
                    availableHeight = screenHeight,
                    fontSize = fontSize,
                    lineHeight = lineHeight,
                    margins = margins,
                )

                // Save pages to repository
                val pageEntities = pages.mapIndexed { index, text ->
                    Page(
                        index = index,
                        bookId = book.id,
                        chapterIndex = 0, // TODO: track chapter boundaries
                        originalText = text,
                    )
                }
                bookRepository.savePages(pageEntities)

                // Mark as completed
                bookRepository.updateBook(
                    book.copy(
                        totalPages = pages.size,
                        paginationStatus = PaginationStatus.COMPLETED,
                        paginationProgress = 1f,
                    )
                )
            } catch (e: Exception) {
                // Mark as failed
                bookRepository.updateBook(
                    book.copy(
                        paginationStatus = PaginationStatus.FAILED,
                        paginationProgress = 0f,
                    )
                )
                throw e
            }
        }
    }
}
