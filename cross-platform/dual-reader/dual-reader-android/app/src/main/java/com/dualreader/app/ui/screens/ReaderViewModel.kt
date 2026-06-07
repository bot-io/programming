package com.dualreader.app.ui.screens

import androidx.annotation.VisibleForTesting
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.dualreader.app.domain.entities.Book
import com.dualreader.app.domain.entities.Bookmark
import com.dualreader.app.domain.entities.Page
import com.dualreader.app.domain.entities.ReadingSettings
import com.dualreader.app.domain.repositories.BookRepository
import com.dualreader.app.domain.repositories.BookmarkRepository
import com.dualreader.app.domain.repositories.SettingsRepository
import com.dualreader.app.domain.usecases.TranslatePageUseCase
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeoutOrNull
import java.time.LocalDateTime
import java.util.UUID
import javax.inject.Inject

sealed class ReaderUiState {
    data object Loading : ReaderUiState()
    data class ReaderReady(
        val book: Book,
        val pages: List<Page>,
        val currentPage: Page,
        val settings: ReadingSettings,
        val bookmarks: List<Bookmark>,
        val isTranslating: Boolean = false,
        val translationError: String? = null,
    ) : ReaderUiState()

    data class Error(val message: String) : ReaderUiState()
}

@HiltViewModel
class ReaderViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val bookRepository: BookRepository,
    private val settingsRepository: SettingsRepository,
    private val bookmarkRepository: BookmarkRepository,
    private val translatePageUseCase: TranslatePageUseCase
) : ViewModel() {

    companion object {
        private const val KEY_BOOK_ID = "bookId"

        /**
         * Visible for testing — allows unit tests to replace Dispatchers.IO
         * with a TestDispatcher so coroutine execution is deterministic.
         */
        @VisibleForTesting
        internal var testIoDispatcher: CoroutineDispatcher? = null
    }

    /** Dispatcher used for all background work; falls back to IO in production. */
    private val ioDispatcher: CoroutineDispatcher
        get() = testIoDispatcher ?: Dispatchers.IO

    private val _uiState = MutableStateFlow<ReaderUiState>(ReaderUiState.Loading)
    val uiState: StateFlow<ReaderUiState> = _uiState.asStateFlow()

    private var currentBookId: String? = savedStateHandle[KEY_BOOK_ID]

    private val _pages = MutableStateFlow<List<Page>>(emptyList())
    private val _bookmarks = MutableStateFlow<List<Bookmark>>(emptyList())
    private val _settings = MutableStateFlow<ReadingSettings?>(null)
    private var _book: Book? = null

    // Translation state as StateFlows so combine picks up changes immediately
    private val _isTranslating = MutableStateFlow(false)
    private val _translationError = MutableStateFlow<String?>(null)

    init {
        currentBookId?.let { loadBook(it) }
    }

    fun loadBook(bookId: String) {
        currentBookId = bookId
        _uiState.value = ReaderUiState.Loading

        viewModelScope.launch(ioDispatcher) {
            try {
                val book = bookRepository.getBookById(bookId)
                if (book == null) {
                    _uiState.value = ReaderUiState.Error("Book not found: $bookId")
                    return@launch
                }
                _book = book

                val pages = bookRepository.getPagesForBook(bookId)
                _pages.value = pages

                val settings = settingsRepository.getSettings()
                _settings.value = settings

                val currentPage = pages.getOrNull(book.currentPage)
                    ?: bookRepository.getPage(bookId, book.currentPage)
                    ?: pages.firstOrNull()

                if (currentPage == null) {
                    _uiState.value = ReaderUiState.Error("No pages found for book: $bookId")
                    return@launch
                }

                // Start collecting reactive flows
                launch {
                    combine(
                        settingsRepository.settings,
                        bookmarkRepository.getBookmarksForBook(bookId),
                        _pages,
                        _isTranslating,
                        _translationError
                    ) { settingsFlow, bookmarksFlow, pagesFlow, translating, error ->
                        Quintuple(settingsFlow, bookmarksFlow, pagesFlow, translating, error)
                    }.collect { (settingsVal, bookmarksVal, pagesVal, isTranslating, translationError) ->
                        _settings.value = settingsVal
                        _bookmarks.value = bookmarksVal

                        val currentBookRef = _book
                        if (currentBookRef != null) {
                            val currentPg = pagesVal.getOrNull(currentBookRef.currentPage)
                                ?: pagesVal.firstOrNull()

                            if (currentPg != null) {
                                _uiState.value = ReaderUiState.ReaderReady(
                                    book = currentBookRef,
                                    pages = pagesVal,
                                    currentPage = currentPg,
                                    settings = settingsVal,
                                    bookmarks = bookmarksVal,
                                    isTranslating = isTranslating,
                                    translationError = translationError
                                )
                            }
                        }
                    }
                }
            } catch (e: Exception) {
                _uiState.value = ReaderUiState.Error(e.message ?: "Failed to load book")
            }
        }
    }

    fun goToPage(index: Int) {
        val book = _book ?: return
        val pages = _pages.value
        val settings = _settings.value ?: return
        val bookmarks = _bookmarks.value
        if (index < 0 || index >= pages.size) return

        val currentPage = pages[index]
        val updatedBook = book.copy(currentPage = index)
        _book = updatedBook

        // Update UI state immediately (don't rely on combine collector)
        _uiState.value = ReaderUiState.ReaderReady(
            book = updatedBook,
            pages = pages,
            currentPage = currentPage,
            settings = settings,
            bookmarks = bookmarks,
            isTranslating = _isTranslating.value,
            translationError = _translationError.value
        )

        // Persist in background
        viewModelScope.launch(ioDispatcher) {
            try { bookRepository.updateBook(updatedBook) } catch (_: Exception) { }
        }
    }

    fun nextPage() {
        val state = _uiState.value as? ReaderUiState.ReaderReady ?: return
        goToPage(state.currentPage.index + 1)
    }

    fun previousPage() {
        val state = _uiState.value as? ReaderUiState.ReaderReady ?: return
        goToPage(state.currentPage.index - 1)
    }

    fun translateCurrentPage() {
        viewModelScope.launch(ioDispatcher) {
            val state = _uiState.value as? ReaderUiState.ReaderReady ?: return@launch
            if (_isTranslating.value) return@launch  // Already translating

            _isTranslating.value = true
            _translationError.value = null

            try {
                // Get previous page for context (better translation quality)
                val prevOriginal = state.pages.getOrNull(state.currentPage.index - 1)?.originalText
                val prevTranslation = state.pages.getOrNull(state.currentPage.index - 1)?.translatedText

                val result = withTimeoutOrNull(45_000L) {
                    translatePageUseCase(
                        text = state.currentPage.originalText,
                        targetLanguage = state.settings.targetLanguage,
                        sourceLanguage = _book?.language,
                        previousOriginal = prevOriginal,
                        previousTranslation = prevTranslation,
                    )
                } ?: Result.failure(Exception("Translation timed out. Tap Retry."))

                result.fold(
                    onSuccess = { translatedText ->
                        val updatedPages = _pages.value.map { page ->
                            if (page.index == state.currentPage.index)
                                page.copy(translatedText = translatedText)
                            else page
                        }
                        _pages.value = updatedPages

                        try {
                            bookRepository.savePages(updatedPages)
                        } catch (_: Exception) { }

                        _isTranslating.value = false
                        _translationError.value = null
                    },
                    onFailure = { error ->
                        _isTranslating.value = false
                        _translationError.value = error.message ?: "Translation failed"
                    }
                )
            } catch (e: Exception) {
                _isTranslating.value = false
                _translationError.value = e.message ?: "Translation failed"
            }
        }
    }

    fun translateAllPages() {
        viewModelScope.launch(ioDispatcher) {
            val state = _uiState.value as? ReaderUiState.ReaderReady ?: return@launch
            if (_isTranslating.value) return@launch

            val untranslated = state.pages.filter { it.translatedText == null }
            if (untranslated.isEmpty()) return@launch

            _isTranslating.value = true

            try {
                val pagesToTranslate = untranslated.map { page ->
                    com.dualreader.app.domain.usecases.PageToTranslate(
                        index = page.index,
                        text = page.originalText,
                    )
                }

                val result = translatePageUseCase.translateBatchWithContext(
                    pages = pagesToTranslate,
                    targetLanguage = state.settings.targetLanguage,
                    sourceLanguage = _book?.language,
                    onPageTranslated = { pageIndex, _ ->
                        // Update progress: mark page as "being processed"
                        val updatedPages = _pages.value.map { page ->
                            if (page.index == pageIndex) page
                            else page
                        }
                        _pages.value = updatedPages
                    },
                )

                result.fold(
                    onSuccess = { translations ->
                        val updatedPages = _pages.value.map { page ->
                            val translation = translations[page.index]
                            if (translation != null) page.copy(translatedText = translation)
                            else page
                        }
                        _pages.value = updatedPages

                        try {
                            bookRepository.savePages(updatedPages)
                        } catch (_: Exception) { }

                        _isTranslating.value = false
                    },
                    onFailure = { error ->
                        _isTranslating.value = false
                        _translationError.value = error.message ?: "Batch translation failed"
                    }
                )
            } catch (e: Exception) {
                _isTranslating.value = false
                _translationError.value = e.message ?: "Batch translation failed"
            }
        }
    }

    fun addBookmark(note: String) {
        viewModelScope.launch(ioDispatcher) {
            val state = _uiState.value as? ReaderUiState.ReaderReady ?: return@launch
            val bookId = currentBookId ?: return@launch

            val bookmark = Bookmark(
                id = UUID.randomUUID().toString(),
                bookId = bookId,
                pageIndex = state.currentPage.index,
                chapterIndex = state.currentPage.chapterIndex,
                textSnippet = state.currentPage.originalText.take(100),
                note = note,
                createdAt = LocalDateTime.now()
            )

            try {
                bookmarkRepository.addBookmark(bookmark)
            } catch (_: Exception) { }
        }
    }

    fun removeBookmark(id: String) {
        viewModelScope.launch(ioDispatcher) {
            try {
                bookmarkRepository.deleteBookmark(id)
            } catch (_: Exception) { }
        }
    }

    fun updateSettings(transform: (ReadingSettings) -> ReadingSettings) {
        viewModelScope.launch(ioDispatcher) {
            val currentSettings = _settings.value ?: return@launch
            _settings.value = transform(currentSettings)
        }
    }

    fun toggleImmersiveMode() {
        viewModelScope.launch(ioDispatcher) {
            val currentSettings = _settings.value ?: return@launch
            _settings.value = currentSettings.copy(isImmersiveMode = !currentSettings.isImmersiveMode)
        }
    }

    // ── Search ─────────────────────────────────────────────────────────────

    data class SearchResult(
        val pageIndex: Int,
        val matchOffset: Int,
        val snippet: String,
    )

    private val _searchQuery = MutableStateFlow("")
    val searchQuery: StateFlow<String> = _searchQuery.asStateFlow()

    private val _searchResults = MutableStateFlow<List<SearchResult>>(emptyList())
    val searchResults: StateFlow<List<SearchResult>> = _searchResults.asStateFlow()

    fun search(query: String) {
        _searchQuery.value = query
        if (query.isBlank()) {
            _searchResults.value = emptyList()
            return
        }
        val pages = _pages.value
        val results = mutableListOf<SearchResult>()
        for (page in pages) {
            var startIndex = 0
            while (true) {
                val offset = page.originalText.indexOf(query, startIndex, true)
                if (offset == -1) break
                val snippetStart = (offset - 30).coerceAtLeast(0)
                val snippetEnd = (offset + query.length + 30).coerceAtMost(page.originalText.length)
                results.add(SearchResult(
                    pageIndex = page.index,
                    matchOffset = offset,
                    snippet = page.originalText.substring(snippetStart, snippetEnd),
                ))
                startIndex = offset + 1
                if (results.size >= 100) break
            }
            if (results.size >= 100) break
        }
        _searchResults.value = results
    }

    fun clearSearch() {
        _searchQuery.value = ""
        _searchResults.value = emptyList()
    }
}

/** 5-tuple for combine with 5 flows. */
private data class Quintuple<A, B, C, D, E>(
    val first: A, val second: B, val third: C, val fourth: D, val fifth: E
)
