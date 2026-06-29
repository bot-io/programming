package com.dualreader.app.ui.screens

import androidx.lifecycle.SavedStateHandle
import com.dualreader.app.domain.entities.Book
import com.dualreader.app.domain.entities.Bookmark
import com.dualreader.app.domain.entities.SortOrder
import com.dualreader.app.domain.export.ExportFormat
import com.dualreader.app.domain.repositories.BookRepository
import com.dualreader.app.domain.repositories.BookmarkRepository
import com.dualreader.app.domain.repositories.LibraryRepository
import com.dualreader.app.domain.usecases.ImportBookUseCase
import com.dualreader.app.domain.usecases.PaginateBookUseCase
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class LibraryViewModelTest {

    private lateinit var savedStateHandle: SavedStateHandle
    private lateinit var bookRepo: BookRepository
    private lateinit var bookmarkRepo: BookmarkRepository
    private lateinit var libraryRepo: LibraryRepository
    private lateinit var importUseCase: ImportBookUseCase
    private lateinit var paginateUseCase: PaginateBookUseCase
    private lateinit var vm: LibraryViewModel

    private val testDispatcher = StandardTestDispatcher()

    @Before
    fun setUp() {
        Dispatchers.setMain(testDispatcher)

        savedStateHandle = SavedStateHandle()
        bookRepo = mockk(relaxed = true)
        bookmarkRepo = mockk(relaxed = true)
        libraryRepo = mockk(relaxed = true)
        importUseCase = mockk(relaxed = true)
        paginateUseCase = mockk(relaxed = true)

        every { libraryRepo.getAllBooksSorted(any()) } returns flowOf(emptyList())
        every { libraryRepo.getAllTags() } returns flowOf(emptyList())
        every { libraryRepo.getAllCollections() } returns flowOf(emptyList())
        coEvery { libraryRepo.getTagsForBook(any()) } returns emptyList()
        coEvery { libraryRepo.getAllBookTags() } returns emptyMap()

        vm = LibraryViewModel(savedStateHandle, bookRepo, bookmarkRepo, libraryRepo, importUseCase, paginateUseCase)
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    private fun makeBook(id: String = "b1", title: String = "Test") = Book(
        id = id,
        title = title,
        author = "Author",
        filePath = "/path.epub",
    )

    // ── Initial State ──────────────────────────────────────────────

    @Test
    fun `initial uiState is Loading`() = runTest {
        assertEquals(LibraryUiState.Loading, vm.uiState.value)
    }

    @Test
    fun `default sort order is LAST_READ`() {
        assertEquals(SortOrder.LAST_READ, vm.currentSortOrder)
    }

    @Test
    fun `default selectedTag is null`() {
        assertNull(vm.selectedTag)
    }

    // ── UI State Emission ──────────────────────────────────────────

    @Test
    fun `empty books emits Empty state`() = runTest {
        val job = launch { vm.uiState.collect {} }
        advanceUntilIdle()
        assertEquals(LibraryUiState.Empty, vm.uiState.value)
        job.cancel()
    }

    @Test
    fun `books present emits Success state`() = runTest {
        val books = listOf(makeBook("b1"), makeBook("b2"))
        every { libraryRepo.getAllBooksSorted(any()) } returns flowOf(books)

        vm = LibraryViewModel(savedStateHandle, bookRepo, bookmarkRepo, libraryRepo, importUseCase, paginateUseCase)
        val job = launch { vm.uiState.collect {} }
        advanceUntilIdle()
        assertTrue(vm.uiState.value is LibraryUiState.Success)
        assertEquals(2, (vm.uiState.value as LibraryUiState.Success).books.size)
        job.cancel()
    }

    // ── Sort Order ─────────────────────────────────────────────────

    @Test
    fun `setSortOrder updates currentSortOrder`() {
        vm.setSortOrder(SortOrder.TITLE)
        assertEquals(SortOrder.TITLE, vm.currentSortOrder)
    }

    @Test
    fun `setSortOrder to AUTHOR`() {
        vm.setSortOrder(SortOrder.AUTHOR)
        assertEquals(SortOrder.AUTHOR, vm.currentSortOrder)
    }

    @Test
    fun `setSortOrder to DATE_ADDED`() {
        vm.setSortOrder(SortOrder.DATE_ADDED)
        assertEquals(SortOrder.DATE_ADDED, vm.currentSortOrder)
    }

    @Test
    fun `setSortOrder to PROGRESS`() {
        vm.setSortOrder(SortOrder.PROGRESS)
        assertEquals(SortOrder.PROGRESS, vm.currentSortOrder)
    }

    @Test
    fun `setSortOrder back to LAST_READ after change`() {
        vm.setSortOrder(SortOrder.TITLE)
        vm.setSortOrder(SortOrder.LAST_READ)
        assertEquals(SortOrder.LAST_READ, vm.currentSortOrder)
    }

    // ── Tag Selection ──────────────────────────────────────────────

    @Test
    fun `setSelectedTag updates selectedTag`() {
        vm.setSelectedTag("favorites")
        assertEquals("favorites", vm.selectedTag)
    }

    @Test
    fun `setSelectedTag to null clears tag`() {
        vm.setSelectedTag("favorites")
        vm.setSelectedTag(null)
        assertNull(vm.selectedTag)
    }

    // ── Tag Operations ─────────────────────────────────────────────

    @Test
    fun `addTagToBook delegates to libraryRepository`() = runTest {
        vm.addTagToBook("b1", "sci-fi")
        advanceUntilIdle()
        coVerify { libraryRepo.addTag("b1", "sci-fi") }
    }

    @Test
    fun `removeTagFromBook delegates to libraryRepository`() = runTest {
        vm.removeTagFromBook("b1", "sci-fi")
        advanceUntilIdle()
        coVerify { libraryRepo.removeTag("b1", "sci-fi") }
    }

    // ── Tag Filtering (criterion 8) ─────────────────────────────────

    @Test
    fun `tag filter shows only books with the selected tag`() = runTest {
        val books = listOf(makeBook("b1"), makeBook("b2"), makeBook("b3"))
        every { libraryRepo.getAllBooksSorted(any()) } returns flowOf(books)
        coEvery { libraryRepo.getAllBookTags() } returns mapOf(
            "b1" to listOf("sci-fi"),
            "b2" to listOf("fantasy"),
            "b3" to listOf("sci-fi", "fantasy"),
        )

        vm = LibraryViewModel(savedStateHandle, bookRepo, bookmarkRepo, libraryRepo, importUseCase, paginateUseCase)
        val job = launch { vm.uiState.collect {} }
        advanceUntilIdle()

        // Before filtering, all three books should be visible.
        assertEquals(3, (vm.uiState.value as LibraryUiState.Success).books.size)

        vm.setSelectedTag("sci-fi")
        advanceUntilIdle()

        val state = vm.uiState.value as LibraryUiState.Success
        val ids = state.books.map { it.id }
        assertTrue("b1 and b3 carry the sci-fi tag", ids.containsAll(listOf("b1", "b3")))
        assertFalse("b2 does not carry the sci-fi tag", ids.contains("b2"))
        assertEquals("sci-fi", state.selectedTag)
        job.cancel()
    }

    @Test
    fun `clearing the tag filter restores all books`() = runTest {
        val books = listOf(makeBook("b1"), makeBook("b2"))
        every { libraryRepo.getAllBooksSorted(any()) } returns flowOf(books)
        coEvery { libraryRepo.getAllBookTags() } returns mapOf(
            "b1" to listOf("sci-fi"),
            "b2" to listOf("fantasy"),
        )

        vm = LibraryViewModel(savedStateHandle, bookRepo, bookmarkRepo, libraryRepo, importUseCase, paginateUseCase)
        val job = launch { vm.uiState.collect {} }
        advanceUntilIdle()

        vm.setSelectedTag("sci-fi")
        advanceUntilIdle()
        assertEquals(1, (vm.uiState.value as LibraryUiState.Success).books.size)

        vm.setSelectedTag(null)
        advanceUntilIdle()

        val state = vm.uiState.value as LibraryUiState.Success
        assertEquals(2, state.books.size)
        assertNull(state.selectedTag)
        job.cancel()
    }

    @Test
    fun `tag filter with no matching books shows empty Success with tag context`() = runTest {
        val books = listOf(makeBook("b1"), makeBook("b2"))
        every { libraryRepo.getAllBooksSorted(any()) } returns flowOf(books)
        coEvery { libraryRepo.getTagsForBook("b1") } returns listOf("sci-fi")
        coEvery { libraryRepo.getTagsForBook("b2") } returns listOf("fantasy")

        vm = LibraryViewModel(savedStateHandle, bookRepo, bookmarkRepo, libraryRepo, importUseCase, paginateUseCase)
        val job = launch { vm.uiState.collect {} }
        advanceUntilIdle()

        vm.setSelectedTag("nonexistent-tag")
        advanceUntilIdle()

        val state = vm.uiState.value as LibraryUiState.Success
        // No books match — but because a tag is selected it must NOT collapse to Empty.
        assertTrue("Filtered-out list should be empty", state.books.isEmpty())
        assertEquals("nonexistent-tag", state.selectedTag)
        job.cancel()
    }

    @Test
    fun `bookTags map is populated for all books`() = runTest {
        val books = listOf(makeBook("b1"), makeBook("b2"))
        every { libraryRepo.getAllBooksSorted(any()) } returns flowOf(books)
        coEvery { libraryRepo.getAllBookTags() } returns mapOf(
            "b1" to listOf("sci-fi", "fav"),
            "b2" to listOf("fantasy"),
        )

        vm = LibraryViewModel(savedStateHandle, bookRepo, bookmarkRepo, libraryRepo, importUseCase, paginateUseCase)
        val job = launch { vm.uiState.collect {} }
        advanceUntilIdle()

        val state = vm.uiState.value as LibraryUiState.Success
        assertEquals(listOf("sci-fi", "fav"), state.bookTags["b1"])
        assertEquals(listOf("fantasy"), state.bookTags["b2"])
        job.cancel()
    }

    // ── Collection Operations ──────────────────────────────────────

    @Test
    fun `createCollection delegates to libraryRepository`() = runTest {
        vm.createCollection("My Collection")
        advanceUntilIdle()
        coVerify { libraryRepo.createCollection("My Collection") }
    }

    @Test
    fun `deleteCollection delegates to libraryRepository`() = runTest {
        vm.deleteCollection(42L)
        advanceUntilIdle()
        coVerify { libraryRepo.deleteCollection(42L) }
    }

    @Test
    fun `renameCollection delegates to libraryRepository`() = runTest {
        vm.renameCollection(5L, "New Name")
        advanceUntilIdle()
        coVerify { libraryRepo.renameCollection(5L, "New Name") }
    }

    @Test
    fun `addBookToCollection delegates to libraryRepository`() = runTest {
        vm.addBookToCollection(1L, "b1")
        advanceUntilIdle()
        coVerify { libraryRepo.addBookToCollection(1L, "b1") }
    }

    @Test
    fun `removeBookFromCollection delegates to libraryRepository`() = runTest {
        vm.removeBookFromCollection(1L, "b1")
        advanceUntilIdle()
        coVerify { libraryRepo.removeBookFromCollection(1L, "b1") }
    }

    // ── CancellationException Handling (DR-135) ───────────────────

    @Test
    fun `addBookToCollection calls repository and handles CancellationException`() = runTest {
        coEvery { libraryRepo.addBookToCollection(any(), any()) } throws kotlinx.coroutines.CancellationException()
        vm.addBookToCollection(1L, "b1")
        advanceUntilIdle()
        // Verify repository was called despite cancellation (exception handled properly)
        coVerify { libraryRepo.addBookToCollection(1L, "b1") }
    }

    @Test
    fun `addBookToCollection handles non-cancellation exceptions gracefully`() = runTest {
        coEvery { libraryRepo.addBookToCollection(any(), any()) } throws RuntimeException("DB error")
        val errorMessages = mutableListOf<String>()
        val job = launch {
            vm.errorEvents.collect { errorMsg ->
                errorMessages.add(errorMsg)
            }
        }
        vm.addBookToCollection(1L, "b1")
        advanceUntilIdle()
        assertEquals(1, errorMessages.size)
        assertTrue(errorMessages[0].contains("Failed to add book to collection"))
        job.cancel()
    }

    // ── Import Book ────────────────────────────────────────────────

    @Test
    fun `importBook calls useCase and triggers pagination on success`() = runTest {
        val book = makeBook("imported-1")
        coEvery { importUseCase(any()) } returns Result.success(book)

        vm.importBook("/path/to/book.epub")
        advanceUntilIdle()

        coVerify { importUseCase("/path/to/book.epub") }
        coVerify { paginateUseCase(book = book, screenWidth = 1080, screenHeight = 1000) }
    }

    @Test
    fun `importBook does not paginate on failure`() = runTest {
        coEvery { importUseCase(any()) } returns Result.failure(RuntimeException("parse error"))

        vm.importBook("/bad.epub")
        advanceUntilIdle()

        coVerify { importUseCase("/bad.epub") }
        coVerify(exactly = 0) { paginateUseCase(any(), any(), any()) }
    }

    @Test
    fun `importBook emits error event on failure`() = runTest {
        val exception = RuntimeException("Invalid EPUB format")
        coEvery { importUseCase(any()) } returns Result.failure(exception)

        val errorMessages = mutableListOf<String>()
        val job = launch {
            vm.errorEvents.collect { errorMsg ->
                errorMessages.add(errorMsg)
            }
        }

        vm.importBook("/bad.epub")
        advanceUntilIdle()

        assertEquals(1, errorMessages.size)
        assertEquals("Import failed: Invalid EPUB format", errorMessages[0])
        job.cancel()
    }

    // ── Delete Book ────────────────────────────────────────────────

    @Test
    fun `deleteBook delegates to bookRepository`() = runTest {
        vm.deleteBook("b1")
        advanceUntilIdle()
        coVerify { bookRepo.deleteBook("b1") }
    }

    // ── Retry Pagination ───────────────────────────────────────────

    @Test
    fun `retryPagination calls paginateBookUseCase with screen dimensions`() = runTest {
        val book = makeBook("b1")
        vm.retryPagination(book, 1080, 2000)
        advanceUntilIdle()
        coVerify { paginateUseCase(book = book, screenWidth = 1080, screenHeight = 2000) }
    }

    // ── Export Bookmarks ───────────────────────────────────────────

    @Test
    fun `formatBookmarksForExport returns null when book not found`() = runTest {
        coEvery { bookRepo.getBookById("b1") } returns null
        val result = vm.formatBookmarksForExport("b1", ExportFormat.JSON)
        assertNull(result)
    }

    @Test
    fun `formatBookmarksForExport returns null when no bookmarks`() = runTest {
        val book = makeBook("b1", "My Book")
        coEvery { bookRepo.getBookById("b1") } returns book
        every { bookmarkRepo.getBookmarksForBook("b1") } returns flowOf(emptyList())

        val result = vm.formatBookmarksForExport("b1", ExportFormat.JSON)
        assertNull(result)
    }

    @Test
    fun `formatBookmarksForExport returns content and filename for JSON`() = runTest {
        val book = makeBook("b1", "My Book")
        coEvery { bookRepo.getBookById("b1") } returns book
        val bookmark = Bookmark(
            id = "bm1", bookId = "b1", pageIndex = 5, chapterIndex = 2,
            textSnippet = "A quote", note = "A note",
        )
        every { bookmarkRepo.getBookmarksForBook("b1") } returns flowOf(listOf(bookmark))

        val result = vm.formatBookmarksForExport("b1", ExportFormat.JSON)
        assertNotNull(result)
        assertTrue(result!!.first.isNotEmpty())
        assertTrue(result.second.endsWith(".json"))
    }

    @Test
    fun `formatBookmarksForExport returns txt extension for PLAIN_TEXT format`() = runTest {
        val book = makeBook("b1", "My Book")
        coEvery { bookRepo.getBookById("b1") } returns book
        val bookmark = Bookmark(
            id = "bm1", bookId = "b1", pageIndex = 0, chapterIndex = 0,
            textSnippet = "text", note = "note",
        )
        every { bookmarkRepo.getBookmarksForBook("b1") } returns flowOf(listOf(bookmark))

        val result = vm.formatBookmarksForExport("b1", ExportFormat.PLAIN_TEXT)
        assertNotNull(result)
        assertTrue(result!!.second.endsWith(".txt"))
    }

    @Test
    fun `formatBookmarksForExport returns md extension for MARKDOWN format`() = runTest {
        val book = makeBook("b1", "My Book")
        coEvery { bookRepo.getBookById("b1") } returns book
        val bookmark = Bookmark(
            id = "bm1", bookId = "b1", pageIndex = 0, chapterIndex = 0,
            textSnippet = "text", note = "note",
        )
        every { bookmarkRepo.getBookmarksForBook("b1") } returns flowOf(listOf(bookmark))

        val result = vm.formatBookmarksForExport("b1", ExportFormat.MARKDOWN)
        assertNotNull(result)
        assertTrue(result!!.second.endsWith(".md"))
    }

    @Test
    fun `formatBookmarksForExport sanitizes title in filename`() = runTest {
        val book = makeBook("b1", "Book: A \"Weird\" Title!!!")
        coEvery { bookRepo.getBookById("b1") } returns book
        val bookmark = Bookmark(
            id = "bm1", bookId = "b1", pageIndex = 0, chapterIndex = 0,
            textSnippet = "text", note = "",
        )
        every { bookmarkRepo.getBookmarksForBook("b1") } returns flowOf(listOf(bookmark))

        val result = vm.formatBookmarksForExport("b1", ExportFormat.JSON)
        assertNotNull(result)
        assertTrue(!result!!.second.contains(":"))
        assertTrue(!result.second.contains("!"))
        assertTrue(!result.second.contains("\""))
    }

    @Test
    fun `formatBookmarksForExport truncates long title in filename`() = runTest {
        val longTitle = "A".repeat(100)
        val book = makeBook("b1", longTitle)
        coEvery { bookRepo.getBookById("b1") } returns book
        val bookmark = Bookmark(
            id = "bm1", bookId = "b1", pageIndex = 0, chapterIndex = 0,
            textSnippet = "text", note = "",
        )
        every { bookmarkRepo.getBookmarksForBook("b1") } returns flowOf(listOf(bookmark))

        val result = vm.formatBookmarksForExport("b1", ExportFormat.JSON)
        assertNotNull(result)
        assertTrue(result!!.second.length < 80)
    }
}
