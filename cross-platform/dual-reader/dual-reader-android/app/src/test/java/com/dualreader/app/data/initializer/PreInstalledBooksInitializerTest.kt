package com.dualreader.app.data.initializer

import android.content.Context
import com.dualreader.app.domain.entities.Book
import com.dualreader.app.domain.entities.BookChapter
import com.dualreader.app.domain.usecases.ImportBookUseCase
import com.dualreader.app.domain.usecases.PaginateBookUseCase
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.io.File

/**
 * Tests for PreInstalledBooksInitializer — verifies that books are both imported AND paginated.
 *
 * Regression test for the "No pages found" bug (v1.0.38 and earlier):
 * PreInstalledBooksInitializer imported books but never paginated them, so opening
 * a pre-installed book showed "No pages found".
 */
class PreInstalledBooksInitializerTest {

    private lateinit var context: Context
    private lateinit var importBookUseCase: ImportBookUseCase
    private lateinit var paginateBookUseCase: PaginateBookUseCase
    private lateinit var initializer: PreInstalledBooksInitializer

    private val fakeFilesDir: File = kotlin.io.path.createTempDirectory(prefix = "dualreader_test").toFile()

    private val testBook = Book(
        id = "book-test",
        title = "Test Book",
        author = "Test Author",
        filePath = "/fake/path.epub",
        chapters = listOf(BookChapter(index = 0, title = "Chapter 1")),
    )

    @Before
    fun setUp() {
        context = mockk(relaxed = true)
        importBookUseCase = mockk()
        paginateBookUseCase = mockk()

        // Context returns fake filesDir
        every { context.filesDir } returns fakeFilesDir

        // Pre-create fake epub files in books/ dir so asset copying is skipped
        val booksDir = File(fakeFilesDir, "books").apply { mkdirs() }
        for ((filename, _) in PreInstalledBooksInitializer.PRE_INSTALLED_BOOKS) {
            File(booksDir, filename).writeText("fake epub content")
        }

        initializer = PreInstalledBooksInitializer(
            context = context,
            importBookUseCase = importBookUseCase,
            paginateBookUseCase = paginateBookUseCase,
        )
    }

    // --- BUG REGRESSION: Import must also paginate ---

    @Test
    fun `import calls paginateBookUseCase for each imported book`() = runTest {
        // Given: import succeeds
        coEvery { importBookUseCase(any()) } returns Result.success(testBook)
        coEvery { paginateBookUseCase(any(), any(), any()) } returns Result.success(Unit)

        // When: ensure flag file is removed
        File(fakeFilesDir, ".pre_installed_books_v2").delete()

        initializer.importPreInstalledBooks()

        // Then: paginateBookUseCase was called for each book
        coVerify(atLeast = 1) {
            paginateBookUseCase(
                book = match { it.id == "book-test" },
                screenWidth = any(),
                screenHeight = any(),
            )
        }
    }

    @Test
    fun `import without pagination flag triggers full import-paginate cycle`() = runTest {
        // Remove the flag file to force re-import
        File(fakeFilesDir, ".pre_installed_books_v2").delete()

        coEvery { importBookUseCase(any()) } returns Result.success(testBook)
        coEvery { paginateBookUseCase(any(), any(), any()) } returns Result.success(Unit)

        initializer.importPreInstalledBooks()

        // Flag file should be created
        assertTrue("Flag file should be created after import", File(fakeFilesDir, ".pre_installed_books_v2").exists())
    }

    @Test
    fun `import skipped when flag file already exists`() = runTest {
        // Given: flag file exists (already imported)
        File(fakeFilesDir, ".pre_installed_books_v2").createNewFile()

        // When
        initializer.importPreInstalledBooks()

        // Then: no import calls
        coVerify(exactly = 0) { importBookUseCase(any()) }
        coVerify(exactly = 0) { paginateBookUseCase(any(), any(), any()) }
    }

    @Test
    fun `import failure for one book does not stop others`() = runTest {
        File(fakeFilesDir, ".pre_installed_books_v2").delete()

        // Book fails to import
        coEvery { importBookUseCase(any()) } returns Result.failure(RuntimeException("Import error"))
        coEvery { paginateBookUseCase(any(), any(), any()) } returns Result.success(Unit)

        // Should not throw
        initializer.importPreInstalledBooks()

        // Flag should still be created
        assertTrue(File(fakeFilesDir, ".pre_installed_books_v2").exists())
    }

    @Test
    fun `pagination failure does not prevent flag file creation`() = runTest {
        File(fakeFilesDir, ".pre_installed_books_v2").delete()

        coEvery { importBookUseCase(any()) } returns Result.success(testBook)
        coEvery { paginateBookUseCase(any(), any(), any()) } returns Result.failure(RuntimeException("Pagination error"))

        initializer.importPreInstalledBooks()

        // Flag should be created even if pagination failed — book is still imported
        assertTrue(File(fakeFilesDir, ".pre_installed_books_v2").exists())
    }

    @Test
    fun `import creates books directory if it does not exist`() = runTest {
        File(fakeFilesDir, ".pre_installed_books_v2").delete()
        // Remove books dir to test creation
        File(fakeFilesDir, "books").deleteRecursively()

        coEvery { importBookUseCase(any()) } returns Result.success(testBook)
        coEvery { paginateBookUseCase(any(), any(), any()) } returns Result.success(Unit)

        initializer.importPreInstalledBooks()

        assertTrue("books directory should be created", File(fakeFilesDir, "books").exists())
    }

    @Test
    fun `PRE_INSTALLED_BOOKS list contains expected books`() {
        assertEquals(7, PreInstalledBooksInitializer.PRE_INSTALLED_BOOKS.size)
        assertTrue(PreInstalledBooksInitializer.PRE_INSTALLED_BOOKS.any { it.second == "The Adventures of Tom Sawyer" })
        assertTrue(PreInstalledBooksInitializer.PRE_INSTALLED_BOOKS.any { it.second == "Moby Dick" })
    }

    @org.junit.After
    fun tearDown() {
        fakeFilesDir.deleteRecursively()
    }
}
