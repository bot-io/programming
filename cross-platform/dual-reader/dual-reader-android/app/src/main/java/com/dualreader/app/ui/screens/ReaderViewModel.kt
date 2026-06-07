package com.dualreader.app.ui.screens

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
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
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
        val isTranslating: Boolean = false
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
    }

    private val _uiState = MutableStateFlow<ReaderUiState>(ReaderUiState.Loading)
    val uiState: StateFlow<ReaderUiState> = _uiState.asStateFlow()

    private var currentBookId: String? = savedStateHandle[KEY_BOOK_ID]

    private val _pages = MutableStateFlow<List<Page>>(emptyList())
    private val _bookmarks = MutableStateFlow<List<Bookmark>>(emptyList())
    private val _settings = MutableStateFlow<ReadingSettings?>(null)
    private var _book: Book? = null

    init {
        currentBookId?.let { loadBook(it) }
    }

    fun loadBook(bookId: String) {
        currentBookId = bookId
        _uiState.value = ReaderUiState.Loading

        viewModelScope.launch(Dispatchers.IO) {
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
                        _pages
                    ) { settingsFlow, bookmarksFlow, pagesFlow ->
                        Triple(settingsFlow, bookmarksFlow, pagesFlow)
                    }.collect { (settingsVal, bookmarksVal, pagesVal) ->
                        _settings.value = settingsVal
                        _bookmarks.value = bookmarksVal

                        val currentBookRef = _book
                        if (currentBookRef != null) {
                            val currentPg = pagesVal.getOrNull(currentBookRef.currentPage)
                                ?: pagesVal.firstOrNull()

                            if (currentPg != null) {
                                val prevState = _uiState.value
                                val isTranslating = (prevState as? ReaderUiState.ReaderReady)?.isTranslating ?: false
                                _uiState.value = ReaderUiState.ReaderReady(
                                    book = currentBookRef,
                                    pages = pagesVal,
                                    currentPage = currentPg,
                                    settings = settingsVal,
                                    bookmarks = bookmarksVal,
                                    isTranslating = isTranslating
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
        viewModelScope.launch(Dispatchers.IO) {
            val book = _book ?: return@launch
            val pages = _pages.value
            val settings = _settings.value ?: return@launch
            val bookmarks = _bookmarks.value

            if (index < 0 || index >= pages.size) return@launch

            val currentPage = pages[index]
            val updatedBook = book.copy(currentPage = index)
            _book = updatedBook

            try {
                bookRepository.updateBook(updatedBook)
            } catch (_: Exception) { /* best effort persist */ }

            val isTranslating = (_uiState.value as? ReaderUiState.ReaderReady)?.isTranslating ?: false
            _uiState.value = ReaderUiState.ReaderReady(
                book = updatedBook,
                pages = pages,
                currentPage = currentPage,
                settings = settings,
                bookmarks = bookmarks,
                isTranslating = isTranslating
            )
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
        viewModelScope.launch(Dispatchers.IO) {
            val state = _uiState.value as? ReaderUiState.ReaderReady ?: return@launch
            val settings = state.settings

            // Mark as translating
            _uiState.value = state.copy(isTranslating = true)

            try {
                val result = translatePageUseCase(
                    text = state.currentPage.originalText,
                    targetLanguage = settings.targetLanguage,
                    sourceLanguage = _book?.language
                )

                result.fold(
                    onSuccess = { translatedText ->
                        val updatedPage = state.currentPage.copy(translatedText = translatedText)
                        val updatedPages = state.pages.map { page ->
                            if (page.index == updatedPage.index) updatedPage else page
                        }
                        _pages.value = updatedPages

                        try {
                            bookRepository.savePages(updatedPages)
                        } catch (_: Exception) { }

                        _uiState.value = state.copy(
                            pages = updatedPages,
                            currentPage = updatedPage,
                            isTranslating = false
                        )
                    },
                    onFailure = { error ->
                        _uiState.value = state.copy(isTranslating = false)
                        _uiState.value = ReaderUiState.Error(
                            error.message ?: "Translation failed"
                        )
                    }
                )
            } catch (e: Exception) {
                _uiState.value = state.copy(isTranslating = false)
                _uiState.value = ReaderUiState.Error(e.message ?: "Translation failed")
            }
        }
    }

    fun translateAllPages() {
        viewModelScope.launch(Dispatchers.IO) {
            val state = _uiState.value as? ReaderUiState.ReaderReady ?: return@launch
            val settings = state.settings
            val untranslated = state.pages.filter { it.translatedText == null }

            if (untranslated.isEmpty()) return@launch

            _uiState.value = state.copy(isTranslating = true)

            try {
                val texts = untranslated.map { it.originalText }
                val result = translatePageUseCase.translateBatch(
                    texts = texts,
                    targetLanguage = settings.targetLanguage,
                    sourceLanguage = _book?.language
                )

                result.fold(
                    onSuccess = { translations ->
                        val updatedPages = state.pages.toMutableList()
                        untranslated.forEachIndexed { i, page ->
                            val idx = updatedPages.indexOfFirst { it.index == page.index }
                            if (idx >= 0 && i < translations.size) {
                                updatedPages[idx] = page.copy(translatedText = translations[i])
                            }
                        }
                        _pages.value = updatedPages

                        try {
                            bookRepository.savePages(updatedPages)
                        } catch (_: Exception) { }

                        val currentPg = updatedPages.find { it.index == state.currentPage.index }
                            ?: state.currentPage

                        _uiState.value = state.copy(
                            pages = updatedPages,
                            currentPage = currentPg,
                            isTranslating = false
                        )
                    },
                    onFailure = { error ->
                        _uiState.value = state.copy(isTranslating = false)
                        _uiState.value = ReaderUiState.Error(
                            error.message ?: "Batch translation failed"
                        )
                    }
                )
            } catch (e: Exception) {
                _uiState.value = state.copy(isTranslating = false)
                _uiState.value = ReaderUiState.Error(e.message ?: "Batch translation failed")
            }
        }
    }

    fun addBookmark(note: String) {
        viewModelScope.launch(Dispatchers.IO) {
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
        viewModelScope.launch(Dispatchers.IO) {
            try {
                bookmarkRepository.deleteBookmark(id)
            } catch (_: Exception) { }
        }
    }

    fun updateSettings(transform: (ReadingSettings) -> ReadingSettings) {
        viewModelScope.launch(Dispatchers.IO) {
            val currentSettings = _settings.value ?: return@launch
            val newSettings = transform(currentSettings)
            _settings.value = newSettings

            val state = _uiState.value as? ReaderUiState.ReaderReady ?: return@launch
            _uiState.value = state.copy(settings = newSettings)
        }
    }

    fun toggleImmersiveMode() {
        viewModelScope.launch(Dispatchers.IO) {
            val currentSettings = _settings.value ?: return@launch
            val toggled = currentSettings.copy(isImmersiveMode = !currentSettings.isImmersiveMode)
            _settings.value = toggled

            val state = _uiState.value as? ReaderUiState.ReaderReady ?: return@launch
            _uiState.value = state.copy(settings = toggled)
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
        val ignoreCase = true
        val results = mutableListOf<SearchResult>()
        for (page in pages) {
            var startIndex = 0
            while (true) {
                val offset = page.originalText.indexOf(query, startIndex, ignoreCase)
                if (offset == -1) break
                val snippetStart = (offset - 30).coerceAtLeast(0)
                val snippetEnd = (offset + query.length + 30).coerceAtMost(page.originalText.length)
                val snippet = page.originalText.substring(snippetStart, snippetEnd)
                results.add(
                    SearchResult(
                        pageIndex = page.index,
                        matchOffset = offset,
                        snippet = snippet,
                    )
                )
                startIndex = offset + 1
                if (results.size >= 100) break // cap results
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
