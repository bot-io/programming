package com.dualreader.app.ui.screens

import com.dualreader.app.domain.entities.Book
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
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Before
import org.junit.Test
import kotlin.test.assertTrue

@OptIn(ExperimentalCoroutinesApi::class)
class LibraryViewModelCancellationTest {

    private lateinit var viewModel: LibraryViewModel
    private val bookRepository: BookRepository = mockk(relaxed = true)
    private val bookmarkRepository: BookmarkRepository = mockk(relaxed = true)
    private val libraryRepository: LibraryRepository = mockk(relaxed = true)
    private val importBookUseCase: ImportBookUseCase = mockk(relaxed = true)
    private val paginateBookUseCase: PaginateBookUseCase = mockk(relaxed = true)

    private val testDispatcher = StandardTestDispatcher()

    @Before
    fun setup() {
        Dispatchers.setMain(testDispatcher)
    }

    @After
    fun teardown() {
        Dispatchers.resetMain()
    }

    @Test
    fun `uiState Flow does not emit Error when getAllBooksSorted throws CancellationException`() = runTest {
        // Given: libraryRepository Flow throws CancellationException
        val cancellingFlow: Flow<List<Book>> = kotlinx.coroutines.flow.flow {
            throw kotlinx.coroutines.CancellationException("Flow cancelled")
        }
        every { libraryRepository.getAllBooksSorted(any()) } returns cancellingFlow
        coEvery { libraryRepository.getAllBookTags() } returns emptyMap()

        // When: ViewModel is created and Flow is collected
        viewModel = LibraryViewModel(
            savedStateHandle = mockk(),
            bookRepository = bookRepository,
            bookmarkRepository = bookmarkRepository,
            libraryRepository = libraryRepository,
            importBookUseCase = importBookUseCase,
            paginateBookUseCase = paginateBookUseCase
        )

        // Collect the Flow in background scope to trigger emission (WhileSubscribed pattern)
        backgroundScope.launch {
            viewModel.uiState.collect {}
        }

        testDispatcher.scheduler.advanceUntilIdle()

        // Then: uiState should NOT be Error (CancellationException should propagate, not be caught)
        val finalState = viewModel.uiState.value
        // The state should NOT be Error - CancellationException should have propagated through .catch
        if (finalState is LibraryUiState.Error) {
            throw AssertionError("CancellationException was converted to Error state - this is the bug! Error: ${finalState.message}")
        }
        // Success: CancellationException propagated correctly
        // State may be Loading or remain in whatever state it was before cancellation
    }

    @Test
    fun `uiState Flow emits Error for non-cancellation exceptions in getAllBooksSorted`() = runTest {
        // Given: libraryRepository Flow throws IOException (simulating DB error)
        val errorFlow: Flow<List<Book>> = kotlinx.coroutines.flow.flow {
            throw java.io.IOException("DB connection failed")
        }
        every { libraryRepository.getAllBooksSorted(any()) } returns errorFlow
        coEvery { libraryRepository.getAllBookTags() } returns emptyMap()

        // When: ViewModel is created and Flow is collected
        viewModel = LibraryViewModel(
            savedStateHandle = mockk(),
            bookRepository = bookRepository,
            bookmarkRepository = bookmarkRepository,
            libraryRepository = libraryRepository,
            importBookUseCase = importBookUseCase,
            paginateBookUseCase = paginateBookUseCase
        )

        // Collect the Flow in background scope to trigger emission (WhileSubscribed pattern)
        backgroundScope.launch {
            viewModel.uiState.collect {}
        }

        testDispatcher.scheduler.advanceUntilIdle()

        // Then: uiState should emit Error for the IOException
        val finalState = viewModel.uiState.value
        assertTrue(finalState is LibraryUiState.Error, "Expected Error state for IOException, got $finalState")
    }

    @Test
    fun `uiState Flow handles successful book loading`() = runTest {
        // Given: libraryRepository returns books successfully
        val testBooks = listOf(
            Book(
                id = "book1",
                title = "Test Book",
                author = "Test Author",
                coverPath = "",
                filePath = "/test/path/book1.epub",
                language = "en"
            )
        )
        every { libraryRepository.getAllBooksSorted(any()) } returns flowOf(testBooks)
        coEvery { libraryRepository.getAllBookTags() } returns emptyMap()

        // When: ViewModel is created and Flow is collected
        viewModel = LibraryViewModel(
            savedStateHandle = mockk(),
            bookRepository = bookRepository,
            bookmarkRepository = bookmarkRepository,
            libraryRepository = libraryRepository,
            importBookUseCase = importBookUseCase,
            paginateBookUseCase = paginateBookUseCase
        )

        // Collect the Flow in background scope to trigger emission (WhileSubscribed pattern)
        backgroundScope.launch {
            viewModel.uiState.collect {}
        }

        testDispatcher.scheduler.advanceUntilIdle()

        // Then: uiState should be Success
        val finalState = viewModel.uiState.value
        assertTrue(finalState is LibraryUiState.Success, "Expected Success state, got $finalState")
    }
}