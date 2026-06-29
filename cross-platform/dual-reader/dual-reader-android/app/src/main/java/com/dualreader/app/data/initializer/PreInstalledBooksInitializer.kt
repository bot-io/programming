package com.dualreader.app.data.initializer

import android.content.Context
import com.dualreader.app.domain.usecases.ImportBookUseCase
import com.dualreader.app.domain.usecases.PaginateBookUseCase
import com.dualreader.app.util.AppLogger
import java.io.File

/**
 * Copies pre-installed public domain eBooks from assets to internal storage
 * and imports them into the library on first launch.
 *
 * Import + pagination are both done here so books are immediately readable.
 *
 * Not Hilt-injectable — created manually with dependencies from the activity.
 */
class PreInstalledBooksInitializer(
    private val context: Context,
    private val importBookUseCase: ImportBookUseCase,
    private val paginateBookUseCase: PaginateBookUseCase,
) {

    companion object {
        private const val BOOKS_DIR = "books"
        private const val ASSETS_DIR = "books"

        // Default screen dimensions for initial pagination.
        // Books will be re-paginated when the user opens them with real dimensions.
        private const val DEFAULT_SCREEN_WIDTH = 1080
        private const val DEFAULT_PAGE_HEIGHT = 1800

        /** [filename, title] pairs for pre-installed books */
        val PRE_INSTALLED_BOOKS = listOf(
            "tom_sawyer.epub" to "The Adventures of Tom Sawyer",
            "treasure_island.epub" to "Treasure Island",
            "moby_dick.epub" to "Moby Dick",
            "alice_wonderland.epub" to "Alice's Adventures in Wonderland",
            "pride_prejudice.epub" to "Pride and Prejudice",
            "tale_two_cities.epub" to "A Tale of Two Cities",
            "dorian_gray.epub" to "The Picture of Dorian Gray",
        )
    }

    private fun isInitialized(): Boolean =
        File(context.filesDir, ".pre_installed_books_v3").exists()

    private fun markInitialized() {
        try {
            File(context.filesDir, ".pre_installed_books_v3").createNewFile()
        } catch (e: Exception) {
            AppLogger.w("[PreInstalledBooks] Failed to create initialization marker file: ${e.message}")
        }
    }

    suspend fun importPreInstalledBooks() {
        if (isInitialized()) {
            AppLogger.d("[PreInstalledBooks] Already imported, skipping")
            return
        }

        val booksDir = File(context.filesDir, BOOKS_DIR).apply { mkdirs() }

        var successCount = 0
        val successfulBooks = mutableListOf<String>()
        val failedBooks = mutableListOf<Pair<String, String>>()  // (filename, error)

        for ((filename, expectedTitle) in PRE_INSTALLED_BOOKS) {
            try {
                val destFile = File(booksDir, filename)
                if (!destFile.exists()) {
                    context.assets.open("$ASSETS_DIR/$filename").use { input ->
                        destFile.outputStream().use { output ->
                            input.copyTo(output)
                        }
                    }
                }

                val result = importBookUseCase(destFile.absolutePath)
                if (result.isSuccess) {
                    val book = result.getOrThrow()
                    AppLogger.i("[PreInstalledBooks] Successfully imported: $expectedTitle (id=${book.id})")

                    // Paginate immediately so the book is readable
                    val paginateResult = paginateBookUseCase(
                        book = book,
                        screenWidth = DEFAULT_SCREEN_WIDTH,
                        screenHeight = DEFAULT_PAGE_HEIGHT,
                    )
                    if (paginateResult.isSuccess) {
                        AppLogger.i("[PreInstalledBooks] Successfully paginated: $expectedTitle (${book.totalPages} pages)")
                        successCount++
                        successfulBooks.add(expectedTitle)
                    } else {
                        AppLogger.e("[PreInstalledBooks] Failed to paginate $expectedTitle: ${paginateResult.exceptionOrNull()?.message}")
                        // Still count as success since the book is imported — pagination can retry on open
                        successCount++
                        successfulBooks.add(expectedTitle + " (pagination failed)")
                    }
                } else {
                    val error = result.exceptionOrNull()?.message ?: "Unknown error"
                    AppLogger.e("[PreInstalledBooks] Failed to import $expectedTitle ($filename): $error")
                    failedBooks.add(filename to error)
                }
            } catch (e: kotlinx.coroutines.CancellationException) {
                throw e // Propagate cancellation — don't continue importing remaining books (DR-053)
            } catch (e: Exception) {
                val error = e.message ?: "Unknown error"
                AppLogger.e("[PreInstalledBooks] Error importing $expectedTitle ($filename): $error", e)
                failedBooks.add(filename to error)
            }
        }

        AppLogger.i("[PreInstalledBooks] Summary: $successCount/${PRE_INSTALLED_BOOKS.size} books imported")
        if (successfulBooks.isNotEmpty()) {
            AppLogger.i("[PreInstalledBooks] Success: ${successfulBooks.joinToString(", ")}")
        }
        if (failedBooks.isNotEmpty()) {
            AppLogger.e("[PreInstalledBooks] Failures: ${failedBooks.joinToString(", ") { "(filename=$it.first, error=$it.second)" }}")
        }

        if (successCount > 0) {
            markInitialized()
            AppLogger.i("[PreInstalledBooks] Marked as initialized (partial success allowed)")
        } else {
            AppLogger.w("[PreInstalledBooks] 0 books succeeded; not marking as initialized (will retry on next launch)")
        }
    }
}
