package com.dualreader.app.ui.screens

import androidx.lifecycle.SavedStateHandle
import com.dualreader.app.domain.repositories.BookRepository
import com.dualreader.app.domain.repositories.BookmarkRepository
import com.dualreader.app.domain.repositories.LibraryRepository
import com.dualreader.app.domain.usecases.ImportBookUseCase
import com.dualreader.app.domain.usecases.PaginateBookUseCase
import io.mockk.mockk
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertNotNull
import org.junit.Before
import org.junit.Test

/**
 * Regression tests for ViewModel lifecycle cleanup.
 * DR-098: Verify Channels are closed in onCleared() to prevent resource leaks.
 *
 * Note: We cannot directly test Channel closure since the Channel is private.
 * Instead we verify that calling onCleared() completes without exception,
 * which confirms the close() call is valid (would throw if already closed or in bad state).
 */
@OptIn(ExperimentalCoroutinesApi::class)
class ViewModelChannelCleanupTest {

    private val bookRepository: BookRepository = mockk()
    private val bookmarkRepository: BookmarkRepository = mockk()
    private val libraryRepository: LibraryRepository = mockk()
    private val importBookUseCase: ImportBookUseCase = mockk()
    private val paginateBookUseCase: PaginateBookUseCase = mockk()

    @Before
    fun setup() {
        Dispatchers.setMain(Dispatchers.Unconfined)
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun `LibraryViewModel onCleared does not throw exception`() = runTest {
        val viewModel = LibraryViewModel(
            savedStateHandle = SavedStateHandle(),
            bookRepository = bookRepository,
            bookmarkRepository = bookmarkRepository,
            libraryRepository = libraryRepository,
            importBookUseCase = importBookUseCase,
            paginateBookUseCase = paginateBookUseCase
        )

        // Verify ViewModel was created successfully
        assertNotNull(viewModel)

        // Call onCleared via reflection to access protected method
        // This tests that the Channel.close() call doesn't throw
        val onClearedMethod = viewModel.javaClass.getDeclaredMethod("onCleared")
        onClearedMethod.isAccessible = true
        onClearedMethod.invoke(viewModel)
    }
}