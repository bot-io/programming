package com.dualreader.app.ui.screens

import androidx.annotation.VisibleForTesting
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import com.dualreader.app.util.AppLogger
import androidx.lifecycle.viewModelScope
import com.dualreader.app.domain.entities.Book
import com.dualreader.app.domain.entities.Bookmark
import com.dualreader.app.domain.entities.Page
import com.dualreader.app.domain.entities.ReadingSettings
import com.dualreader.app.domain.services.BatchTranslationResult
import com.dualreader.app.domain.repositories.BookRepository
import com.dualreader.app.domain.repositories.BookmarkRepository
import com.dualreader.app.domain.repositories.SettingsRepository
import com.dualreader.app.domain.repositories.TranslationCacheRepository
import com.dualreader.app.domain.usecases.PageToTranslate
import com.dualreader.app.domain.usecases.PaginateBookUseCase
import com.dualreader.app.domain.usecases.TranslatePageUseCase
import com.dualreader.app.domain.usecases.BookContext
import com.dualreader.app.domain.usecases.BookContextExtractor
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
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
        val isRePaginating: Boolean = false,
    ) : ReaderUiState()

    data class Error(val message: String) : ReaderUiState()
}

@HiltViewModel
class ReaderViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val bookRepository: BookRepository,
    private val settingsRepository: SettingsRepository,
    private val bookmarkRepository: BookmarkRepository,
    private val translatePageUseCase: TranslatePageUseCase,
    private val paginateBookUseCase: PaginateBookUseCase,
    private val translationCacheRepository: TranslationCacheRepository,
) : ViewModel() {

    companion object {
        private const val KEY_BOOK_ID = "bookId"

        /** How many pages to translate around the current page when user taps "Translate". */
        const val TRANSLATE_WINDOW_SIZE = 3

        @VisibleForTesting
        internal var testIoDispatcher: CoroutineDispatcher? = null
    }

    private val ioDispatcher: CoroutineDispatcher
        get() = testIoDispatcher ?: Dispatchers.IO

    private val _uiState = MutableStateFlow<ReaderUiState>(ReaderUiState.Loading)
    val uiState: StateFlow<ReaderUiState> = _uiState.asStateFlow()

    private var currentBookId: String? = savedStateHandle[KEY_BOOK_ID]

    private val _pages = MutableStateFlow<List<Page>>(emptyList())
    private val _bookmarks = MutableStateFlow<List<Bookmark>>(emptyList())
    private val _settings = MutableStateFlow<ReadingSettings?>(null)
    private var _book: Book? = null

    private val _isTranslating = MutableStateFlow(false)
    private val _translationError = MutableStateFlow<String?>(null)
    private var translationJob: Job? = null
    private val _isRePaginating = MutableStateFlow(false)

    /** Extracted book-level context for translation quality. Cached per-book. */
    private var _bookContext: BookContext? = null

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

                // Extract book context from metadata + first pages for translation quality
                _bookContext = if (pages.isNotEmpty()) {
                    BookContextExtractor.extract(book, pages)
                } else {
                    null
                }

                val settings = settingsRepository.getSettings()
                _settings.value = settings

                val currentPage = pages.getOrNull(book.currentPage)
                    ?: bookRepository.getPage(bookId, book.currentPage)
                    ?: pages.firstOrNull()

                if (currentPage == null) {
                    _uiState.value = ReaderUiState.Error("No pages found for book: $bookId")
                    return@launch
                }

                launch {
                    combine(
                        settingsRepository.settings,
                        bookmarkRepository.getBookmarksForBook(bookId),
                        _pages,
                        combine(_isTranslating, _translationError, _isRePaginating) { t, e, r ->
                            UiExtras(t, e, r)
                        },
                    ) { settingsFlow, bookmarksFlow, pagesFlow, extras ->
                        Quadruple(settingsFlow, bookmarksFlow, pagesFlow, extras)
                    }.collect { (settingsVal, bookmarksVal, pagesVal, extras) ->
                        _settings.value = settingsVal
                        _bookmarks.value = bookmarksVal

                        val currentBookRef = _book
                        if (currentBookRef != null) {
                            val currentPg = pagesVal.getOrNull(currentBookRef.currentPage)
                                ?: pagesVal.firstOrNull()

                            if (currentPg != null) {
                                // Debug: log translation state for current page
                                val transLang = settingsVal.targetLanguage
                                val hasTrans = currentPg.translations.containsKey(transLang)
                                val transCount = pagesVal.count { it.translations.containsKey(transLang) }
                                if (hasTrans || transCount > 0) {
                                    AppLogger.i("UI update: page ${currentPg.index} hasTrans=$hasTrans lang=$transLang totalTransPages=$transCount")
                                }

                                _uiState.value = ReaderUiState.ReaderReady(
                                    book = currentBookRef,
                                    pages = pagesVal,
                                    currentPage = currentPg,
                                    settings = settingsVal,
                                    bookmarks = bookmarksVal,
                                    isTranslating = extras.isTranslating,
                                    translationError = extras.translationError,
                                    isRePaginating = extras.isRePaginating,
                                )
                            }
                        }
                    }
                }
            } catch (e: Exception) {
                AppLogger.e("loadBook failed: ${e.message}", e)
                _uiState.value = ReaderUiState.Error(e.message ?: "Failed to load book")
            }
        }
    }

    /**
     * Re-paginate the book with actual measured dimensions from the reader layout.
     * Called once when the content area is first measured with real pixel sizes.
     */
    fun rePaginate(panelWidthPx: Int, panelHeightPx: Int, displayDensity: Float) {
        val book = _book ?: return
        AppLogger.i("rePaginate: ${panelWidthPx}x${panelHeightPx}px density=$displayDensity book=${book.id}")
        viewModelScope.launch(ioDispatcher) {
            _isRePaginating.value = true
            try {
                // Capture old pages BEFORE re-pagination for substring fallback matching
                val oldPages = _pages.value
                val oldTranslated = oldPages.filter { it.translations.isNotEmpty() }
                
                // Set the actual device density so StaticLayout matches Compose rendering
                com.dualreader.app.data.pagination.PaginationServiceImpl.displayDensity = displayDensity
                paginateBookUseCase(
                    book = book,
                    screenWidth = panelWidthPx,
                    screenHeight = panelHeightPx,
                )
                val newPages = bookRepository.getPagesForBook(book.id)
                // Restore cached translations onto the new pages
                val targetLang = settingsRepository.getSettings().targetLanguage
                val restoredPages = try {
                    newPages.map { page ->
                        // 1. Exact cache match (fast path)
                        val cached = translationCacheRepository.get(
                            text = page.originalText,
                            sourceLang = book.language,
                            targetLang = targetLang,
                        )
                        if (cached != null) {
                            page.withTranslation(targetLang, cached)
                        } else {
                            // 2. Substring fallback: check if any old translated page contains this page's text
                            val oldMatch = oldTranslated.firstOrNull { old ->
                                old.originalText.contains(page.originalText)
                            }
                            if (oldMatch != null) {
                                val trans = oldMatch.translations[targetLang]
                                if (trans != null) {
                                    AppLogger.i("rePaginate: substring restore page ${page.index} from old page ${oldMatch.index}")
                                    page.withTranslation(targetLang, trans)
                                } else page
                            } else page
                        }
                    }
                } catch (e: Exception) {
                    AppLogger.e("Cache restore failed: ${e.message}", e)
                    newPages
                }
                _pages.value = restoredPages
                // Re-extract book context with the new pages
                _bookContext = BookContextExtractor.extract(book, restoredPages)
                val updatedBook = bookRepository.getBookById(book.id) ?: book
                _book = updatedBook
                val transCount = restoredPages.count { it.translations.containsKey(targetLang) }
                AppLogger.i("rePaginate done: ${newPages.size} pages, totalPg=${updatedBook.totalPages}, transPages=$transCount")
            } catch (e: Exception) {
                AppLogger.e("rePaginate failed: ${e.message}", e)
                // Keep existing pages
            } finally {
                _isRePaginating.value = false
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
        val updatedBook = book.copy(
            currentPage = index,
            lastReadAt = LocalDateTime.now(),
        )
        _book = updatedBook

        _uiState.value = ReaderUiState.ReaderReady(
            book = updatedBook,
            pages = pages,
            currentPage = currentPage,
            settings = settings,
            bookmarks = bookmarks,
            isTranslating = _isTranslating.value,
            translationError = _translationError.value,
            isRePaginating = _isRePaginating.value,
        )

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

    /**
     * Translate current page + surrounding pages in a batch.
     * Picks [TRANSLATE_WINDOW_SIZE] pages centered on the current page
     * that haven't been translated to the current target language yet.
     */
    fun translateCurrentPage() {
        cancelTranslation()

        translationJob = viewModelScope.launch(ioDispatcher) {
            val state = _uiState.value as? ReaderUiState.ReaderReady ?: return@launch
            val targetLang = state.settings.targetLanguage

            _isTranslating.value = true
            _translationError.value = null

            try {
                val pagesToTranslate = collectTranslateWindow(
                    allPages = state.pages,
                    centerIndex = state.currentPage.index,
                    targetLang = targetLang,
                )

                if (pagesToTranslate.isEmpty()) {
                    _isTranslating.value = false
                    return@launch
                }

                AppLogger.i("translateCurrentPage: ${pagesToTranslate.size} pages, targetLang=$targetLang, center=${state.currentPage.index}")

                val pageTranslations = pagesToTranslate.map { page ->
                    PageToTranslate(index = page.index, text = page.originalText)
                }

                val result = withTimeoutOrNull(120_000L) {
                    translatePageUseCase.translateBatchWithContext(
                        pages = pageTranslations,
                        targetLanguage = targetLang,
                        sourceLanguage = _book?.language,
                        onPageTranslated = { pageIndex, translation ->
                            applyTranslation(pageIndex, targetLang, translation)
                        },
                        bookContext = _bookContext,
                    )
                } ?: run {
                    AppLogger.e("Translation timed out for ${pagesToTranslate.size} pages")
                    Result.failure(Exception("Translation timed out. Tap Retry."))
                }

                result.fold(
                    onSuccess = { batchResult ->
                        AppLogger.i("Translation success: ${batchResult.translations.size} pages, model=${batchResult.model}")
                        batchResult.translations.forEach { (pageIndex, translation) ->
                            applyTranslation(pageIndex, targetLang, translation, batchResult.model)
                        }
                        _isTranslating.value = false
                        _translationError.value = null
                    },
                    onFailure = { error ->
                        AppLogger.e("translateCurrentPage failed: ${error.message}", error)
                        _isTranslating.value = false
                        _translationError.value = error.message ?: "Translation failed"
                    }
                )
            } catch (e: Exception) {
                AppLogger.e("translateCurrentPage exception: ${e.message}", e)
                _isTranslating.value = false
                _translationError.value = e.message ?: "Translation failed"
            }
        }
    }

    fun cancelTranslation() {
        translationJob?.cancel()
        translationJob = null
        _isTranslating.value = false
        _translationError.value = null
    }

    fun translateAllPages() {
        cancelTranslation()

        translationJob = viewModelScope.launch(ioDispatcher) {
            val state = _uiState.value as? ReaderUiState.ReaderReady ?: return@launch
            val targetLang = state.settings.targetLanguage

            val untranslated = state.pages.filter { !it.hasTranslation(targetLang) }
            if (untranslated.isEmpty()) return@launch

            _isTranslating.value = true

            try {
                val pagesToTranslate = untranslated.map { page ->
                    PageToTranslate(index = page.index, text = page.originalText)
                }

                val result = translatePageUseCase.translateBatchWithContext(
                    pages = pagesToTranslate,
                    targetLanguage = targetLang,
                    sourceLanguage = _book?.language,
                    onPageTranslated = { pageIndex, translation ->
                        applyTranslation(pageIndex, targetLang, translation)
                    },
                    bookContext = _bookContext,
                )

                result.fold(
                    onSuccess = { batchResult ->
                        batchResult.translations.forEach { (pageIndex, translation) ->
                            applyTranslation(pageIndex, targetLang, translation, batchResult.model)
                        }
                        _isTranslating.value = false
                    },
                    onFailure = { error ->
                        AppLogger.e("translateAllPages failed: ${error.message}", error)
                        _isTranslating.value = false
                        _translationError.value = error.message ?: "Batch translation failed"
                    }
                )
            } catch (e: Exception) {
                AppLogger.e("translateAllPages exception: ${e.message}", e)
                _isTranslating.value = false
                _translationError.value = e.message ?: "Batch translation failed"
            }
        }
    }

    /**
     * Merge a translation for one page into the pages list, preserving
     * all other language translations on that page.
     */
    private fun applyTranslation(pageIndex: Int, lang: String, translation: String, model: String? = null) {
        AppLogger.i("applyTranslation: pageIndex=$pageIndex lang=$lang model=${model ?: "n/a"} textLen=${translation.length}")
        val updatedPages = _pages.value.map { page ->
            if (page.index == pageIndex) page.withTranslation(lang, translation, model) else page
        }
        _pages.value = updatedPages
        // Verify the page was actually found and updated
        val updated = updatedPages.find { it.index == pageIndex }
        AppLogger.i("applyTranslation: page found=${updated != null}, hasTranslation=${updated?.translations?.containsKey(lang) == true}")
        viewModelScope.launch(ioDispatcher) {
            runCatching { bookRepository.savePages(updatedPages) }
                .onSuccess { AppLogger.i("applyTranslation: saved ${updatedPages.size} pages to repo") }
                .onFailure { AppLogger.e("applyTranslation: save failed: ${it.message}", it) }
        }
    }

    /**
     * Collect up to [TRANSLATE_WINDOW_SIZE] pages around [centerIndex] that need
     * translation to [targetLang]. Prioritizes the current page, then pages after,
     * then pages before.
     */
    private fun collectTranslateWindow(
        allPages: List<Page>,
        centerIndex: Int,
        targetLang: String,
    ): List<Page> {
        val window = mutableListOf<Page>()
        val added = mutableSetOf<Int>()

        // Always include current page if it needs translation
        val currentPage = allPages.getOrNull(centerIndex)
        if (currentPage != null && !currentPage.hasTranslation(targetLang)) {
            window.add(currentPage)
            added.add(centerIndex)
        }

        // Add pages after current
        var i = centerIndex + 1
        while (window.size < TRANSLATE_WINDOW_SIZE && i < allPages.size) {
            val page = allPages[i]
            if (!page.hasTranslation(targetLang) && i !in added) {
                window.add(page)
                added.add(i)
            }
            i++
        }

        // Add pages before current
        i = centerIndex - 1
        while (window.size < TRANSLATE_WINDOW_SIZE && i >= 0) {
            val page = allPages[i]
            if (!page.hasTranslation(targetLang) && i !in added) {
                window.add(page)
                added.add(i)
            }
            i--
        }

        return window.sortedBy { it.index }
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

/** 4-tuple for combine. */
private data class Quadruple<A, B, C, D>(
    val first: A, val second: B, val third: C, val fourth: D,
)

/** UI extras bundled for combine. */
private data class UiExtras(
    val isTranslating: Boolean,
    val translationError: String?,
    val isRePaginating: Boolean,
)
