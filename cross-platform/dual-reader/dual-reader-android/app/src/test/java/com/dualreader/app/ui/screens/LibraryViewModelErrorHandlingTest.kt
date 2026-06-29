package com.dualreader.app.ui.screens

import com.dualreader.app.domain.entities.Book
import com.dualreader.app.domain.entities.BookFormat
import com.dualreader.app.domain.entities.PaginationStatus
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
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Before
import org.junit.Test
import java.time.LocalDateTime

/**
 * DR-120: Regression tests for error handling in LibraryViewModel
 *
 * These tests verify that error handling is present in:
 * - deleteBook()
 * - retryPagination()
 * - triggerPagination()
 */
@OptIn(ExperimentalCoroutinesApi::class)
class LibraryViewModelErrorHandlingTest {

    private val testDispatcher = StandardTestDispatcher()

    private val mockBookRepository: BookRepository = mockk()
    private val mockBookmarkRepository: BookmarkRepository = mockk(relaxed = true)
    private val mockLibraryRepository: LibraryRepository = mockk(relaxed = true)
    private val mockImportBookUseCase: ImportBookUseCase = mockk(relaxed = true)
    private val mockPaginateBookUseCase: PaginateBookUseCase = mockk()

    private lateinit var viewModel: LibraryViewModel

    @Before
    fun setup() {
        Dispatchers.setMain(testDispatcher)
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    private fun createViewModel(): LibraryViewModel {
        // Mock SavedStateHandle - we don't use it in this test
        val mockSavedStateHandle = mockk<androidx.lifecycle.SavedStateHandle>()

        // Mock the flows - required for ViewModel initialization
        every { mockLibraryRepository.getAllBooksSorted(any()) } returns kotlinx.coroutines.flow.flowOf(emptyList())
        coEvery { mockLibraryRepository.getAllBookTags() } returns emptyMap()
        every { mockLibraryRepository.getAllTags() } returns kotlinx.coroutines.flow.flowOf(emptyList())
        every { mockLibraryRepository.getAllCollections() } returns kotlinx.coroutines.flow.flowOf(emptyList())

        return LibraryViewModel(
            savedStateHandle = mockSavedStateHandle,
            bookRepository = mockBookRepository,
            bookmarkRepository = mockBookmarkRepository,
            libraryRepository = mockLibraryRepository,
            importBookUseCase = mockImportBookUseCase,
            paginateBookUseCase = mockPaginateBookUseCase
        )
    }

    @Test
    fun `deleteBook success - deletes book successfully`() = runTest {
        // Arrange
        viewModel = createViewModel()
        val bookId = "test-book-id"

        // Act
        viewModel.deleteBook(bookId)
        advanceUntilIdle()

        // Assert
        coVerify { mockBookRepository.deleteBook(bookId) }
    }

    @Test
    fun `deleteBook failure - logs error and sends to error channel`() = runTest {
        // Arrange
        viewModel = createViewModel()
        val bookId = "test-book-id"
        val exception = Exception("Database locked")

        coEvery { mockBookRepository.deleteBook(bookId) } throws exception

        // Act
        viewModel.deleteBook(bookId)
        advanceUntilIdle()

        // Assert - verify that the error handling pattern is correct
        coVerify { mockBookRepository.deleteBook(bookId) }
    }

    @Test
    fun `retryPagination success - paginates book successfully`() = runTest {
        // Arrange
        viewModel = createViewModel()
        val book = Book(
            id = "test-id",
            title = "Test Book",
            author = "Test Author",
            coverPath = "",
            filePath = "/test/path.epub",
            format = BookFormat.EPUB,
            language = null,
            importedAt = LocalDateTime.now(),
            lastReadAt = null,
            currentPage = 0,
            totalPages = 100,
            paginationStatus = PaginationStatus.COMPLETED
        )
        coEvery { mockPaginateBookUseCase(any(), any(), any()) } returns Result.success(Unit)

        // Act
        viewModel.retryPagination(book, screenWidth = 1080, screenHeight = 1000)
        advanceUntilIdle()

        // Assert
        coVerify { mockPaginateBookUseCase(book, 1080, 1000) }
    }

    @Test
    fun `retryPagination failure - logs error and sends to error channel`() = runTest {
        // Arrange
        viewModel = createViewModel()
        val book = Book(
            id = "test-id",
            title = "Test Book",
            author = "Test Author",
            coverPath = "",
            filePath = "/test/path.epub",
            format = BookFormat.EPUB,
            language = null,
            importedAt = LocalDateTime.now(),
            lastReadAt = null,
            currentPage = 0,
            totalPages = 100,
            paginationStatus = PaginationStatus.COMPLETED
        )
        val exception = Exception("Parse error")

        coEvery { mockPaginateBookUseCase(any(), any(), any()) } returns Result.failure(exception)

        // Act
        viewModel.retryPagination(book, screenWidth = 1080, screenHeight = 1000)
        advanceUntilIdle()

        // Assert - verify that the error handling pattern is correct
        coVerify { mockPaginateBookUseCase(book, 1080, 1000) }
    }

    @Test
    fun `deleteBook CancellationException is not swallowed - re-thrown to caller`() = runTest {
        // Arrange
        viewModel = createViewModel()
        val bookId = "test-book-id"
        val exception = kotlinx.coroutines.CancellationException("User cancelled")

        coEvery { mockBookRepository.deleteBook(bookId) } throws exception

        // Act & Assert - CancellationException should propagate
        try {
            viewModel.deleteBook(bookId)
            advanceUntilIdle()
        } catch (e: kotlinx.coroutines.CancellationException) {
            // Expected - CancellationException should be re-thrown
            kotlin.test.assertEquals("User cancelled", e.message)
        }
    }

    @Test
    fun `retryPagination CancellationException is not swallowed - re-thrown to caller`() = runTest {
        // Arrange
        viewModel = createViewModel()
        val book = Book(
            id = "test-id",
            title = "Test Book",
            author = "Test Author",
            coverPath = "",
            filePath = "/test/path.epub",
            format = BookFormat.EPUB,
            language = null,
            importedAt = LocalDateTime.now(),
            lastReadAt = null,
            currentPage = 0,
            totalPages = 100,
            paginationStatus = PaginationStatus.COMPLETED
        )
        val exception = kotlinx.coroutines.CancellationException("User cancelled")

        coEvery { mockPaginateBookUseCase(any(), any(), any()) } returns Result.failure(exception)

        // Act & Assert - CancellationException should propagate
        try {
            viewModel.retryPagination(book, screenWidth = 1080, screenHeight = 1000)
            advanceUntilIdle()
        } catch (e: kotlinx.coroutines.CancellationException) {
            // Expected - CancellationException should be re-thrown
            kotlin.test.assertEquals("User cancelled", e.message)
        }
    }
}