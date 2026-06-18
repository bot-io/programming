package com.dualreader.app.domain.usecases

import com.dualreader.app.domain.entities.Book
import com.dualreader.app.domain.entities.Page
import com.dualreader.app.domain.entities.PaginationStatus
import com.dualreader.app.domain.repositories.BookRepository
import com.dualreader.app.domain.services.EpubParserService
import javax.inject.Inject

/**
 * Extract paragraphs from an EPUB and store them as Page entities (one paragraph per Page).
 *
 * This replaces the old pagination approach. Each "page" is now a single paragraph,
 * which enables:
 * - Per-paragraph translation (exact, no alignment heuristics)
 * - Per-paragraph TTS
 * - Scrollable reader UI (no page-flip navigation)
 *
 * Translations from previous extractions are preserved by content matching.
 */
class PaginateBookUseCase @Inject constructor(
    private val bookRepository: BookRepository,
    private val epubParser: EpubParserService,
) {
    suspend operator fun invoke(
        book: Book,
        screenWidth: Int = 0,  // Ignored — kept for backward compat
        screenHeight: Int = 0, // Ignored — kept for backward compat
        fontSize: Float = 16f, // Ignored
        lineHeight: Float = 1.5f, // Ignored
        margins: Int = 16, // Ignored
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
                // Extract paragraphs from EPUB
                val extractedParagraphs = epubParser.extractParagraphs(book.filePath)

                if (extractedParagraphs.isEmpty()) {
                    throw IllegalStateException("No paragraphs found in book: ${book.filePath}")
                }

                // Load existing pages to preserve translations across re-extraction
                val existingPages = bookRepository.getPagesForBook(book.id)
                val existingByContent = existingPages
                    .filter { it.translations.isNotEmpty() }
                    .associateBy { it.originalText }

                // Create one Page per paragraph, carrying over translations by content match
                val pageEntities = extractedParagraphs.mapIndexed { index, para ->
                    val existing = existingByContent[para.text]
                    if (existing != null) {
                        existing.copy(index = index, chapterIndex = para.chapterIndex)
                    } else {
                        Page(
                            index = index,
                            bookId = book.id,
                            chapterIndex = para.chapterIndex,
                            originalText = para.text,
                        )
                    }
                }
                bookRepository.savePages(pageEntities)

                // Mark as completed
                bookRepository.updateBook(
                    book.copy(
                        totalPages = pageEntities.size,
                        paginationStatus = PaginationStatus.COMPLETED,
                        paginationProgress = 1f,
                    )
                )
            } catch (e: Exception) {
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
