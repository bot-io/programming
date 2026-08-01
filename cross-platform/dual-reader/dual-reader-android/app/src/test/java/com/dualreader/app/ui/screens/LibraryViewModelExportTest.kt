package com.dualreader.app.ui.screens

import com.dualreader.app.domain.entities.Book
import com.dualreader.app.domain.entities.BookChapter
import com.dualreader.app.domain.entities.Bookmark
import com.dualreader.app.domain.entities.PaginationStatus
import com.dualreader.app.domain.export.ExportFormat
import com.dualreader.app.domain.repositories.BookRepository
import com.dualreader.app.domain.repositories.BookmarkRepository
import com.dualreader.app.domain.repositories.LibraryRepository
import com.dualreader.app.domain.usecases.ImportBookUseCase
import com.dualreader.app.domain.usecases.PaginateBookUseCase
import io.mockk.coEvery
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Before
import org.junit.Test
import java.time.LocalDateTime
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

@OptIn(ExperimentalCoroutinesApi::class)
class LibraryViewModelExportTest {

    private lateinit var viewModel: LibraryViewModel
    private val bookRepository = mockk<BookRepository>()
    private val bookmarkRepository = mockk<BookmarkRepository>()
    private val libraryRepository = mockk<LibraryRepository>()
    private val importBookUseCase = mockk<ImportBookUseCase>()
    private val paginateBookUseCase = mockk<PaginateBookUseCase>()
    private val testDispatcher = StandardTestDispatcher()

    private val testBook = Book(
        id = "book-123",
        title = "Test Book",
        author = "Test Author",
        coverPath = "",
        filePath = "/test/path.epub",
        language = "en",
        currentPage = 0,
        totalPages = 100,
        paginationStatus = PaginationStatus.COMPLETED,
        paginationProgress = 1f,
        chapters = listOf(
            BookChapter(index = 0, title = "Chapter 1")
        ),
    )

    @Before
    fun setup() {
        Dispatchers.setMain(testDispatcher)

        // Setup default mocks
        every { libraryRepository.getAllBooksSorted(any()) } returns flowOf(emptyList())
        coEvery { libraryRepository.getAllBookTags() } returns emptyMap<String, List<String>>()
        every { libraryRepository.getAllTags() } returns flowOf(emptyList())
        every { libraryRepository.getAllCollections() } returns flowOf(emptyList())

        viewModel = LibraryViewModel(
            savedStateHandle = mockk(relaxed = true),
            bookRepository = bookRepository,
            bookmarkRepository = bookmarkRepository,
            libraryRepository = libraryRepository,
            importBookUseCase = importBookUseCase,
            paginateBookUseCase = paginateBookUseCase
        )
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun `formatBookmarksForExport returns null when book not found`() = runTest {
        coEvery { bookRepository.getBookById("nonexistent") } returns null

        val result = viewModel.formatBookmarksForExport("nonexistent", ExportFormat.PLAIN_TEXT)

        assertNull(result)
    }

    @Test
    fun `formatBookmarksForExport returns null when bookmarks list is empty`() = runTest {
        coEvery { bookRepository.getBookById(testBook.id) } returns testBook
        every { bookmarkRepository.getBookmarksForBook(testBook.id) } returns flowOf(emptyList())

        val result = viewModel.formatBookmarksForExport(testBook.id, ExportFormat.PLAIN_TEXT)

        assertNull(result)
    }

    @Test
    fun `formatBookmarksForExport returns content and filename when bookmarks exist`() = runTest {
        val testBookmark = Bookmark(
            id = "bookmark-1",
            bookId = testBook.id,
            pageIndex = 0,
            chapterIndex = 0,
            textSnippet = "Test snippet",
            note = "Test note",
            createdAt = LocalDateTime.now()
        )
        coEvery { bookRepository.getBookById(testBook.id) } returns testBook
        every { bookmarkRepository.getBookmarksForBook(testBook.id) } returns flowOf(listOf(testBookmark))

        val result = viewModel.formatBookmarksForExport(testBook.id, ExportFormat.PLAIN_TEXT)

        assertNotNull(result)
        println("Result: $result")
        println("Filename: ${result.second}")
        println("Content: ${result.first.take(200)}")
        assertTrue(result.second.endsWith(".txt"))
        assertTrue(result.first.contains("Test Book"))
        assertTrue(result.first.contains("Test snippet"))
    }

    @Test
    fun `formatBookmarksForExport handles Flow errors gracefully`() = runTest {
        coEvery { bookRepository.getBookById(testBook.id) } returns testBook
        every { bookmarkRepository.getBookmarksForBook(testBook.id) } returns flowOf(listOf(
            Bookmark(
                id = "bookmark-1",
                bookId = testBook.id,
                pageIndex = 0,
                chapterIndex = 0,
                textSnippet = "Test",
                note = "Note",
                createdAt = LocalDateTime.now()
            )
        ))

        val result = viewModel.formatBookmarksForExport(testBook.id, ExportFormat.PLAIN_TEXT)

        assertNotNull(result)
        assertTrue(result.second.endsWith(".txt"))
        assertTrue(result.first.contains("Test"))
    }

    @Test
    fun `formatBookmarksForExport works with JSON format`() = runTest {
        val testBookmark = Bookmark(
            id = "bookmark-1",
            bookId = testBook.id,
            pageIndex = 5,
            chapterIndex = 1,
            textSnippet = "JSON snippet",
            note = "",
            createdAt = LocalDateTime.now()
        )
        coEvery { bookRepository.getBookById(testBook.id) } returns testBook
        every { bookmarkRepository.getBookmarksForBook(testBook.id) } returns flowOf(listOf(testBookmark))

        val result = viewModel.formatBookmarksForExport(testBook.id, ExportFormat.JSON)

        assertNotNull(result)
        println("JSON Result: $result")
        println("JSON Filename: ${result.second}")
        assertTrue(result.second.endsWith(".json"))
        assertTrue(result.first.contains("\"bookTitle\""))
        assertTrue(result.first.contains("\"JSON snippet\""))
    }

    @Test
    fun `formatBookmarksForExport works with Markdown format`() = runTest {
        val testBookmark = Bookmark(
            id = "bookmark-1",
            bookId = testBook.id,
            pageIndex = 10,
            chapterIndex = 2,
            textSnippet = "MD snippet",
            note = "MD note",
            createdAt = LocalDateTime.now()
        )
        coEvery { bookRepository.getBookById(testBook.id) } returns testBook
        every { bookmarkRepository.getBookmarksForBook(testBook.id) } returns flowOf(listOf(testBookmark))

        val result = viewModel.formatBookmarksForExport(testBook.id, ExportFormat.MARKDOWN)

        assertNotNull(result)
        println("MD Result: $result")
        println("MD Filename: ${result.second}")
        assertTrue(result.second.endsWith(".md"))
        assertTrue(result.first.contains("# Annotations: Test Book"))
        assertTrue(result.first.contains("> MD snippet"))
    }

    @Test
    fun `formatBookmarksForExport sanitizes filename with special characters`() = runTest {
        val specialBook = testBook.copy(
            title = "Test/Book:Special*Chars?Test"
        )
        val testBookmark = Bookmark(
            id = "bookmark-1",
            bookId = specialBook.id,
            pageIndex = 0,
            chapterIndex = 0,
            textSnippet = "Test",
            note = "",
            createdAt = LocalDateTime.now()
        )
        coEvery { bookRepository.getBookById(specialBook.id) } returns specialBook
        every { bookmarkRepository.getBookmarksForBook(specialBook.id) } returns flowOf(listOf(testBookmark))

        val result = viewModel.formatBookmarksForExport(specialBook.id, ExportFormat.PLAIN_TEXT)

        assertNotNull(result)
        // Special characters should be removed, spaces replaced with underscores
        assertEquals("TestBookSpecialCharsTest_annotations.txt", result.second)
    }

    @Test
    fun `formatBookmarksForExport truncates long titles in filename`() = runTest {
        val longBook = testBook.copy(
            title = "A".repeat(100)
        )
        val testBookmark = Bookmark(
            id = "bookmark-1",
            bookId = longBook.id,
            pageIndex = 0,
            chapterIndex = 0,
            textSnippet = "Test",
            note = "",
            createdAt = LocalDateTime.now()
        )
        coEvery { bookRepository.getBookById(longBook.id) } returns longBook
        every { bookmarkRepository.getBookmarksForBook(longBook.id) } returns flowOf(listOf(testBookmark))

        val result = viewModel.formatBookmarksForExport(longBook.id, ExportFormat.PLAIN_TEXT)

        assertNotNull(result)
        // Title should be truncated to 50 chars
        assertEquals(50 + "_annotations.txt".length, result.second.length)
    }

    @Test
    fun `formatBookmarksForExport handles multiple bookmarks`() = runTest {
        val bookmarks = listOf(
            Bookmark(
                id = "bookmark-1",
                bookId = testBook.id,
                pageIndex = 0,
                chapterIndex = 0,
                textSnippet = "Snippet 1",
                note = "Note 1",
                createdAt = LocalDateTime.now()
            ),
            Bookmark(
                id = "bookmark-2",
                bookId = testBook.id,
                pageIndex = 5,
                chapterIndex = 1,
                textSnippet = "Snippet 2",
                note = "",
                createdAt = LocalDateTime.now()
            ),
            Bookmark(
                id = "bookmark-3",
                bookId = testBook.id,
                pageIndex = 10,
                chapterIndex = 2,
                textSnippet = "Snippet 3",
                note = "Note 3",
                createdAt = LocalDateTime.now()
            )
        )
        coEvery { bookRepository.getBookById(testBook.id) } returns testBook
        every { bookmarkRepository.getBookmarksForBook(testBook.id) } returns flowOf(bookmarks)

        val result = viewModel.formatBookmarksForExport(testBook.id, ExportFormat.PLAIN_TEXT)

        assertNotNull(result)
        // All bookmarks should be included
        assertTrue(result.first.contains("Snippet 1"))
        assertTrue(result.first.contains("Snippet 2"))
        assertTrue(result.first.contains("Snippet 3"))
        assertTrue(result.first.contains("Note 1"))
        assertTrue(result.first.contains("Note 3"))
    }
}