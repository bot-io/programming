package com.dualreader.app.ui.screens

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.dualreader.app.domain.entities.Book
import com.dualreader.app.domain.entities.BookCollection
import com.dualreader.app.domain.entities.SortOrder
import com.dualreader.app.domain.export.BookmarkExporter
import com.dualreader.app.domain.export.ExportFormat
import com.dualreader.app.domain.export.ExportableBookmark
import com.dualreader.app.domain.repositories.BookRepository
import com.dualreader.app.domain.repositories.BookmarkRepository
import com.dualreader.app.domain.repositories.LibraryRepository
import com.dualreader.app.domain.usecases.ImportBookUseCase
import com.dualreader.app.domain.usecases.PaginateBookUseCase
import com.dualreader.app.util.AppLogger
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

sealed class LibraryUiState {
    data object Loading : LibraryUiState()
    data object Empty : LibraryUiState()
    data class Success(
        val books: List<Book>,
        val bookTags: Map<String, List<String>> = emptyMap(),
        val selectedTag: String? = null,
    ) : LibraryUiState()
    data class Error(val message: String) : LibraryUiState()
}

data class LibrarySortState(
    val sortOrder: SortOrder = SortOrder.LAST_READ,
    val selectedTag: String? = null,
)

@HiltViewModel
class LibraryViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val bookRepository: BookRepository,
    private val bookmarkRepository: BookmarkRepository,
    private val libraryRepository: LibraryRepository,
    private val importBookUseCase: ImportBookUseCase,
    private val paginateBookUseCase: PaginateBookUseCase
) : ViewModel() {

    // Error events for user-facing notifications
    private val _errorEvents = Channel<String>()
    val errorEvents = _errorEvents.receiveAsFlow()

    private val sortState = MutableStateFlow(LibrarySortState())

    val uiState: StateFlow<LibraryUiState> = sortState
        .flatMapLatest { state ->
            combine(
                libraryRepository.getAllBooksSorted(state.sortOrder),
                flow { emit(libraryRepository.getAllBookTags()) }
            ) { books, bookTagsMap ->
                // Filter by selected tag using pre-loaded tag map
                val currentTag = state.selectedTag
                val filteredBooks = if (currentTag != null) {
                    books.filter { book ->
                        bookTagsMap[book.id]?.contains(currentTag) == true
                    }
                } else {
                    books
                }

                if (filteredBooks.isEmpty() && books.isNotEmpty() && currentTag != null) {
                    // Tag selected but no books have it — show empty with context
                    LibraryUiState.Success(
                        books = emptyList(),
                        bookTags = bookTagsMap,
                        selectedTag = currentTag,
                    )
                } else if (filteredBooks.isEmpty()) {
                    LibraryUiState.Empty
                } else {
                    LibraryUiState.Success(
                        books = filteredBooks,
                        bookTags = bookTagsMap,
                        selectedTag = currentTag,
                    )
                }
            }
        }
        .catch { if (it is kotlinx.coroutines.CancellationException) throw it else emit(LibraryUiState.Error(it.localizedMessage ?: "Failed to load books")) }
        .stateIn(
            scope = viewModelScope,
            started = SharingStarted.WhileSubscribed(stopTimeoutMillis = 5_000),
            initialValue = LibraryUiState.Loading
        )

    val allTags: StateFlow<List<String>> = libraryRepository.getAllTags()
        .stateIn(
            scope = viewModelScope,
            started = SharingStarted.WhileSubscribed(stopTimeoutMillis = 5_000),
            initialValue = emptyList()
        )

    val collections: StateFlow<List<BookCollection>> = libraryRepository.getAllCollections()
        .stateIn(
            scope = viewModelScope,
            started = SharingStarted.WhileSubscribed(stopTimeoutMillis = 5_000),
            initialValue = emptyList()
        )

    val currentSortOrder: SortOrder
        get() = sortState.value.sortOrder

    val selectedTag: String?
        get() = sortState.value.selectedTag

    fun setSortOrder(order: SortOrder) {
        sortState.value = sortState.value.copy(sortOrder = order)
    }

    fun setSelectedTag(tag: String?) {
        sortState.value = sortState.value.copy(selectedTag = tag)
    }

    fun addTagToBook(bookId: String, tag: String) {
        viewModelScope.launch {
            try {
                libraryRepository.addTag(bookId, tag)
            } catch (e: kotlinx.coroutines.CancellationException) {
                throw e // Preserve coroutine cancellation semantics (DR-133)
            } catch (e: Exception) {
                AppLogger.e("addTagToBook: Failed to add tag '$tag' to book $bookId: ${e.message}", e)
                _errorEvents.trySend("Failed to add tag: ${e.message}")
            }
        }
    }

    fun removeTagFromBook(bookId: String, tag: String) {
        viewModelScope.launch {
            try {
                libraryRepository.removeTag(bookId, tag)
            } catch (e: kotlinx.coroutines.CancellationException) {
                throw e // Preserve coroutine cancellation semantics (DR-133)
            } catch (e: Exception) {
                AppLogger.e("removeTagFromBook: Failed to remove tag '$tag' from book $bookId: ${e.message}", e)
                _errorEvents.trySend("Failed to remove tag: ${e.message}")
            }
        }
    }

    fun createCollection(name: String) {
        viewModelScope.launch {
            try {
                libraryRepository.createCollection(name)
            } catch (e: kotlinx.coroutines.CancellationException) {
                throw e // Preserve coroutine cancellation semantics (DR-133)
            } catch (e: Exception) {
                AppLogger.e("createCollection: Failed to create collection '$name': ${e.message}", e)
                _errorEvents.trySend("Failed to create collection: ${e.message}")
            }
        }
    }

    fun deleteCollection(id: Long) {
        viewModelScope.launch {
            try {
                libraryRepository.deleteCollection(id)
            } catch (e: kotlinx.coroutines.CancellationException) {
                throw e // Preserve coroutine cancellation semantics (DR-133)
            } catch (e: Exception) {
                AppLogger.e("deleteCollection: Failed to delete collection $id: ${e.message}", e)
                _errorEvents.trySend("Failed to delete collection: ${e.message}")
            }
        }
    }

    fun renameCollection(id: Long, newName: String) {
        viewModelScope.launch {
            try {
                libraryRepository.renameCollection(id, newName)
            } catch (e: kotlinx.coroutines.CancellationException) {
                throw e // Preserve coroutine cancellation semantics (DR-133)
            } catch (e: Exception) {
                AppLogger.e("renameCollection: Failed to rename collection $id to '$newName': ${e.message}", e)
                _errorEvents.trySend("Failed to rename collection: ${e.message}")
            }
        }
    }

    fun addBookToCollection(collectionId: Long, bookId: String) {
        viewModelScope.launch {
            try {
                libraryRepository.addBookToCollection(collectionId, bookId)
            } catch (e: kotlinx.coroutines.CancellationException) {
                throw e // Preserve coroutine cancellation semantics (DR-135)
            } catch (e: Exception) {
                AppLogger.e("addBookToCollection: Failed to add book $bookId to collection $collectionId: ${e.message}", e)
                _errorEvents.trySend("Failed to add book to collection: ${e.message}")
            }
        }
    }

    fun removeBookFromCollection(collectionId: Long, bookId: String) {
        viewModelScope.launch {
            try {
                libraryRepository.removeBookFromCollection(collectionId, bookId)
            } catch (e: kotlinx.coroutines.CancellationException) {
                throw e // Preserve coroutine cancellation semantics (DR-133)
            } catch (e: Exception) {
                AppLogger.e("removeBookFromCollection: Failed to remove book $bookId from collection $collectionId: ${e.message}", e)
                _errorEvents.trySend("Failed to remove book from collection: ${e.message}")
            }
        }
    }

    fun importBook(filePath: String) {
        viewModelScope.launch {
            importBookUseCase(filePath)
                .onSuccess { book ->
                    triggerPagination(book)
                }
                .onFailure { e ->
                    AppLogger.e("Book import failed: ${e.message}")
                    _errorEvents.trySend("Import failed: ${e.message}")
                }
        }
    }

    fun deleteBook(id: String) {
        viewModelScope.launch {
            try {
                bookRepository.deleteBook(id)
            } catch (e: kotlinx.coroutines.CancellationException) {
                throw e // Preserve coroutine cancellation semantics (DR-133)
            } catch (e: Exception) {
                AppLogger.e("deleteBook: Failed to delete book $id: ${e.message}", e)
                _errorEvents.trySend("Failed to delete book: ${e.message}")
            }
        }
    }

    fun retryPagination(book: Book, screenWidth: Int, screenHeight: Int) {
        viewModelScope.launch {
            try {
                paginateBookUseCase(
                    book = book,
                    screenWidth = screenWidth,
                    screenHeight = screenHeight
                )
            } catch (e: kotlinx.coroutines.CancellationException) {
                throw e // Preserve coroutine cancellation semantics (DR-133)
            } catch (e: Exception) {
                AppLogger.e("retryPagination: Failed to paginate book '${book.title}': ${e.message}", e)
                _errorEvents.trySend("Failed to paginate book: ${e.message}")
            }
        }
    }

    companion object {
        private const val DEFAULT_SCREEN_WIDTH = 1080
        private const val DEFAULT_PAGE_HEIGHT = 1000
    }

    private fun triggerPagination(book: Book) {
        viewModelScope.launch {
            try {
                paginateBookUseCase(
                    book = book,
                    screenWidth = DEFAULT_SCREEN_WIDTH,
                    screenHeight = DEFAULT_PAGE_HEIGHT
                )
            } catch (e: kotlinx.coroutines.CancellationException) {
                throw e // Preserve coroutine cancellation semantics (DR-133)
            } catch (e: Exception) {
                AppLogger.e("triggerPagination: Failed to paginate book '${book.title}' after import: ${e.message}", e)
                _errorEvents.trySend("Failed to paginate book after import: ${e.message}")
            }
        }
    }

    private val exporter = BookmarkExporter()

    suspend fun formatBookmarksForExport(
        bookId: String,
        format: ExportFormat,
    ): Pair<String, String>? {
        val book = bookRepository.getBookById(bookId) ?: return null
        val bookmarks = try {
            bookmarkRepository.getBookmarksForBook(bookId).first()
        } catch (e: kotlinx.coroutines.CancellationException) {
            throw e // Preserve cancellation semantics (DR-176)
        } catch (e: Exception) {
            AppLogger.e("formatBookmarksForExport: Failed to load bookmarks for book $bookId: ${e.message}", e)
            return null
        }
        if (bookmarks.isEmpty()) return null

        val exportable = bookmarks.map { bm ->
            ExportableBookmark(
                bookTitle = book.title,
                bookAuthor = book.author,
                pageIndex = bm.pageIndex,
                chapterIndex = bm.chapterIndex,
                textSnippet = bm.textSnippet,
                note = bm.note,
                createdAt = bm.createdAt,
            )
        }

        val content = exporter.export(exportable, format)
        val safeTitle = book.title.replace(Regex("[^a-zA-Z0-9 _-]"), "").take(50).trim()
        val fileName = "${safeTitle}_annotations.${exporter.fileExtension(format)}"
        return content to fileName
    }

    override fun onCleared() {
        super.onCleared()
        // DR-098: Close Channel to prevent resource leaks
        _errorEvents.close()
    }
}
