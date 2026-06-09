package com.dualreader.app.ui.screens

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.dualreader.app.domain.entities.Book
import com.dualreader.app.domain.repositories.BookRepository
import com.dualreader.app.domain.usecases.ImportBookUseCase
import com.dualreader.app.domain.usecases.PaginateBookUseCase
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

sealed class LibraryUiState {
    data object Loading : LibraryUiState()
    data object Empty : LibraryUiState()
    data class Success(val books: List<Book>) : LibraryUiState()
    data class Error(val message: String) : LibraryUiState()
}

@HiltViewModel
class LibraryViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val bookRepository: BookRepository,
    private val importBookUseCase: ImportBookUseCase,
    private val paginateBookUseCase: PaginateBookUseCase
) : ViewModel() {

    val uiState: StateFlow<LibraryUiState> = bookRepository.getAllBooks()
        .map { books ->
            if (books.isEmpty()) {
                LibraryUiState.Empty
            } else {
                LibraryUiState.Success(books)
            }
        }
        .catch { e ->
            emit(LibraryUiState.Error(e.localizedMessage ?: "Failed to load books"))
        }
        .stateIn(
            scope = viewModelScope,
            started = SharingStarted.WhileSubscribed(stopTimeoutMillis = 5_000),
            initialValue = LibraryUiState.Loading
        )

    fun importBook(filePath: String) {
        viewModelScope.launch {
            importBookUseCase(filePath)
                .onSuccess { book ->
                    triggerPagination(book)
                }
                .onFailure { e ->
                    // Import failure is reflected through the flow;
                    // the book simply won't appear in the library.
                    // If a dedicated error event is needed, emit here.
                }
        }
    }

    fun deleteBook(id: String) {
        viewModelScope.launch {
            bookRepository.deleteBook(id)
        }
    }

    fun retryPagination(book: Book, screenWidth: Int, screenHeight: Int) {
        viewModelScope.launch {
            paginateBookUseCase(
                book = book,
                screenWidth = screenWidth,
                screenHeight = screenHeight
            )
        }
    }

    companion object {
        // Default dimensions for initial background pagination.
        // These are only used at import time — the reader re-paginates with
        // actual measured dimensions when opened, so these don't need to be
        // exact. They just need to be roughly right so the book has pages.
        private const val DEFAULT_SCREEN_WIDTH = 1080
        private const val DEFAULT_PAGE_HEIGHT = 1000  // rough estimate; reader fixes it
    }

    private fun triggerPagination(book: Book) {
        viewModelScope.launch {
            paginateBookUseCase(
                book = book,
                screenWidth = DEFAULT_SCREEN_WIDTH,
                screenHeight = DEFAULT_PAGE_HEIGHT
            )
        }
    }
}
