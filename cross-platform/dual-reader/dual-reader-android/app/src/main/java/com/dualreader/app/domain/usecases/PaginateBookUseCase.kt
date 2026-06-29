package com.dualreader.app.domain.usecases

import com.dualreader.app.domain.entities.Book
import com.dualreader.app.domain.entities.Page
import com.dualreader.app.domain.entities.PaginationStatus
import com.dualreader.app.domain.repositories.BookRepository
import com.dualreader.app.domain.services.EpubParserService
import com.dualreader.app.util.AppLogger
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

                AppLogger.i("PaginateBookUseCase: Starting pagination for '${book.title}' (${extractedParagraphs.size} paragraphs)")

                // Load existing pages to preserve translations across re-extraction
                val existingPages = bookRepository.getPagesForBook(book.id)
                val existingByContent = existingPages
                    .filter { it.translations.isNotEmpty() }
                    .associateBy { it.originalText }
                val existingByIndex = existingPages.associateBy { it.index }

                AppLogger.i("PaginateBookUseCase: ${extractedParagraphs.size} paragraphs extracted, ${existingPages.size} existing pages, ${existingByContent.size} with translations")

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

                // If pages already exist, only update the ones that changed.
                // This avoids REPLACE strategy deleting + re-inserting rows,
                // which could lose translations due to race conditions.
                if (existingPages.isNotEmpty()) {
                    // Delete pages that no longer exist (e.g., different paragraph count)
                    val newIndexSet = pageEntities.map { it.index }.toSet()
                    val staleIndices = existingPages.map { it.index } - newIndexSet
                    if (staleIndices.isNotEmpty()) {
                        bookRepository.deletePagesForBook(book.id)
                        bookRepository.savePages(pageEntities)
                        AppLogger.i("PaginateBookUseCase: paragraph count changed, full re-save")
                    } else {
                        // Update each page individually, preserving translations
                        for (page in pageEntities) {
                            val old = existingByIndex[page.index]
                            if (old == null || old.originalText != page.originalText) {
                                // New or changed page — save it (preserves translations from content match)
                                bookRepository.savePages(listOf(page))
                            }
                            // If old page exists with same text, no need to save — translations are already there
                        }
                    }
                } else {
                    bookRepository.savePages(pageEntities)
                }

                // Mark as completed
                bookRepository.updateBook(
                    book.copy(
                        totalPages = pageEntities.size,
                        paginationStatus = PaginationStatus.COMPLETED,
                        paginationProgress = 1f,
                    )
                )
                AppLogger.i("PaginateBookUseCase: Pagination completed for '${book.title}' (${pageEntities.size} paragraphs)")
            } catch (e: kotlinx.coroutines.CancellationException) {
                throw e // Propagate cancellation — don't mark book as FAILED (DR-052)
            } catch (e: Exception) {
                AppLogger.e("PaginateBookUseCase: Pagination failed for '${book.title}': ${e.message}")
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
