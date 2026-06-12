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
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.map
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

    private val sortState = MutableStateFlow(LibrarySortState())

    val uiState: StateFlow<LibraryUiState> = sortState
        .flatMapLatest { state ->
            libraryRepository.getAllBooksSorted(state.sortOrder)
                .combine(libraryRepository.getAllTags()) { books, allTags ->
                    // Filter by tag if one is selected
                    val filteredBooks = if (state.selectedTag != null) {
                        val tagBookIds = allTags.let { _ ->
                            // Use a suspend call but we're in combine, need to be smarter
                            // Actually, let's just filter based on bookTags
                            books // Will be filtered below
                        }
                        // We'll handle tag filtering in the map below
                        books
                    } else {
                        books
                    }
                    Pair(filteredBooks, allTags)
                }
        }
        .map { (books, _) ->
            if (books.isEmpty()) {
                LibraryUiState.Empty
            } else {
                // Load tags for each book and filter if needed
                val currentTag = sortState.value.selectedTag
                val tagMap = mutableMapOf<String, List<String>>()
                for (book in books) {
                    tagMap[book.id] = libraryRepository.getTagsForBook(book.id)
                }

                val filteredBooks = if (currentTag != null) {
                    books.filter { book ->
                        tagMap[book.id]?.contains(currentTag) == true
                    }
                } else {
                    books
                }

                if (filteredBooks.isEmpty() && currentTag != null) {
                    // Tag selected but no books have it — show empty with context
                    LibraryUiState.Success(
                        books = emptyList(),
                        bookTags = tagMap,
                        selectedTag = currentTag,
                    )
                } else {
                    LibraryUiState.Success(
                        books = filteredBooks,
                        bookTags = tagMap,
                        selectedTag = currentTag,
                    )
                }
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
            libraryRepository.addTag(bookId, tag)
        }
    }

    fun removeTagFromBook(bookId: String, tag: String) {
        viewModelScope.launch {
            libraryRepository.removeTag(bookId, tag)
        }
    }

    fun createCollection(name: String) {
        viewModelScope.launch {
            libraryRepository.createCollection(name)
        }
    }

    fun deleteCollection(id: Long) {
        viewModelScope.launch {
            libraryRepository.deleteCollection(id)
        }
    }

    fun renameCollection(id: Long, newName: String) {
        viewModelScope.launch {
            libraryRepository.renameCollection(id, newName)
        }
    }

    fun addBookToCollection(collectionId: Long, bookId: String) {
        viewModelScope.launch {
            libraryRepository.addBookToCollection(collectionId, bookId)
        }
    }

    fun removeBookFromCollection(collectionId: Long, bookId: String) {
        viewModelScope.launch {
            libraryRepository.removeBookFromCollection(collectionId, bookId)
        }
    }

    fun importBook(filePath: String) {
        viewModelScope.launch {
            importBookUseCase(filePath)
                .onSuccess { book ->
                    triggerPagination(book)
                }
                .onFailure { e ->
                    // Import failure is reflected through the flow;
                    // the book simply won't appear in the library.
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
        private const val DEFAULT_SCREEN_WIDTH = 1080
        private const val DEFAULT_PAGE_HEIGHT = 1000
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

    private val exporter = BookmarkExporter()

    suspend fun formatBookmarksForExport(
        bookId: String,
        format: ExportFormat,
    ): Pair<String, String>? {
        val book = bookRepository.getBookById(bookId) ?: return null
        val bookmarks = bookmarkRepository.getBookmarksForBook(bookId).first()
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
}
