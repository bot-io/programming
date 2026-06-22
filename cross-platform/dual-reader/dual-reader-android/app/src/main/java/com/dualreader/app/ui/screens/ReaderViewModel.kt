package com.dualreader.app.ui.screens

import androidx.annotation.VisibleForTesting
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import com.dualreader.app.util.AppLogger
import androidx.lifecycle.viewModelScope
import com.dualreader.app.domain.export.BookmarkExporter
import com.dualreader.app.domain.export.ExportFormat
import com.dualreader.app.domain.export.ExportableBookmark
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
import kotlinx.coroutines.flow.receiveAsFlow
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
    private val ttsService: com.dualreader.app.domain.services.TtsService,
    private val translationService: com.dualreader.app.domain.services.TranslationService,
    private val mlKitModelManager: com.dualreader.app.data.translation.MlKitModelManager,
) : ViewModel() {

    companion object {
        private const val KEY_BOOK_ID = "bookId"

        /** How many pages to translate around the current page when user taps "Translate". */
        const val TRANSLATE_WINDOW_SIZE = 15

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
    private val _paragraphsTranslating = MutableStateFlow<Set<Int>>(emptySet())
    val paragraphsTranslating: StateFlow<Set<Int>> = _paragraphsTranslating.asStateFlow()
    private var translationJob: Job? = null
    private var loadJob: Job? = null
    private var loadOuterJob: Job? = null
    private val _isRePaginating = MutableStateFlow(false)

    // ── Translation events (one-time UI events for Snackbar) ──────────────
    sealed class TranslationEvent {
        data class Error(val message: String, val canRetry: Boolean, val canDownloadModel: Boolean) : TranslationEvent()
        data class OfflineFallback(val pagesTranslated: Int) : TranslationEvent()
        data class Success(val pagesTranslated: Int) : TranslationEvent()
    }
    private val _translationEvents = kotlinx.coroutines.channels.Channel<TranslationEvent>(
        capacity = kotlinx.coroutines.channels.Channel.BUFFERED
    )
    val translationEvents: kotlinx.coroutines.flow.Flow<TranslationEvent> =
        _translationEvents.receiveAsFlow()

    private var hasAutoRetried = false

    // ── Word translation (tap-to-translate) ──────────────────────────────
    data class WordTranslationState(
        val word: String,
        val translation: String = "",
        val isLoading: Boolean = true,
        val error: String? = null,
        val isFromOriginal: Boolean = true,
    )

    private val _wordTranslation = MutableStateFlow<WordTranslationState?>(null)
    val wordTranslation: StateFlow<WordTranslationState?> = _wordTranslation.asStateFlow()
    private var wordJob: Job? = null

    fun translateWord(word: String, isFromOriginal: Boolean) {
        if (word.isBlank()) return
        wordJob?.cancel()

        val state = _uiState.value as? ReaderUiState.ReaderReady ?: return
        val sourceLang = if (isFromOriginal) _book?.language else state.settings.targetLanguage
        val targetLang = if (isFromOriginal) state.settings.targetLanguage else _book?.language ?: "en"

        _wordTranslation.value = WordTranslationState(
            word = word,
            isFromOriginal = isFromOriginal,
        )

        wordJob = viewModelScope.launch(ioDispatcher) {
            try {
                val result = translationService.translate(
                    text = word,
                    targetLanguage = targetLang,
                    sourceLanguage = sourceLang,
                )
                _wordTranslation.value = _wordTranslation.value?.copy(
                    translation = result.trim(),
                    isLoading = false,
                )
            } catch (e: Exception) {
                _wordTranslation.value = _wordTranslation.value?.copy(
                    isLoading = false,
                    error = e.message ?: "Translation failed",
                )
            }
        }
    }

    fun dismissWordTranslation() {
        _wordTranslation.value = null
    }

    /** Extracted book-level context for translation quality. Cached per-book. */
    private var _bookContext: BookContext? = null

    init {
        currentBookId?.let { loadBook(it) }
    }

    /**
     * Reload pages from the database without resetting scroll position.
     * Called when returning from Settings after clearing translations.
     */
    fun reloadPages() {
        val bookId = currentBookId ?: return
        viewModelScope.launch(ioDispatcher) {
            val pages = bookRepository.getPagesForBook(bookId)
            AppLogger.i("reloadPages: loaded ${pages.size} pages, ${pages.count { it.translations.isNotEmpty() }} with translations")
            _pages.value = pages
        }
    }

    fun loadBook(bookId: String) {
        currentBookId = bookId
        _uiState.value = ReaderUiState.Loading
        loadJob?.cancel()
        loadOuterJob?.cancel()

        loadOuterJob = viewModelScope.launch(ioDispatcher) {
            try {
                val book = bookRepository.getBookById(bookId)
                if (book == null) {
                    _uiState.value = ReaderUiState.Error("Book not found: $bookId")
                    return@launch
                }
                _book = book

                val pages = bookRepository.getPagesForBook(bookId)
                val transCount = pages.count { it.translations.isNotEmpty() }
                AppLogger.i("loadBook: loaded ${pages.size} pages from DB, $transCount have translations")
                if (transCount > 0) {
                    pages.filter { it.translations.isNotEmpty() }.take(3).forEach { p ->
                        AppLogger.i("loadBook: page ${p.index} has translations for languages: ${p.translations.keys}")
                    }
                }
                _pages.value = pages

                // Auto-paginate: always re-extract paragraphs to pick up parser improvements
                // (e.g., <br> splitting). Translations are preserved by content matching.
                val effectivePages = if (pages.isEmpty()) {
                    AppLogger.d("[Reader] Book has no pages, auto-paginating: $bookId")
                    val paginateResult = paginateBookUseCase(
                        book = book,
                        screenWidth = 1080,
                        screenHeight = 1800,
                    )
                    if (paginateResult.isSuccess) {
                        val newPages = bookRepository.getPagesForBook(bookId)
                        _pages.value = newPages
                        newPages
                    } else {
                        AppLogger.e("[Reader] Auto-pagination failed: ${paginateResult.exceptionOrNull()?.message}")
                        emptyList()
                    }
                } else {
                    // Re-extract to check for paragraph structure changes (e.g., <br> splits)
                    val paginateResult = paginateBookUseCase(
                        book = book,
                        screenWidth = 1080,
                        screenHeight = 1800,
                    )
                    if (paginateResult.isSuccess) {
                        val refreshedPages = bookRepository.getPagesForBook(bookId)
                        if (refreshedPages.size != pages.size) {
                            AppLogger.i("[Reader] Paragraph count changed: ${pages.size} → ${refreshedPages.size}, refreshing")
                        }
                        _pages.value = refreshedPages
                        refreshedPages
                    } else {
                        // Keep existing pages if re-extraction fails
                        pages
                    }
                }

                // Extract book context from metadata + first pages for translation quality
                _bookContext = if (effectivePages.isNotEmpty()) {
                    BookContextExtractor.extract(book, effectivePages)
                } else {
                    null
                }

                val settings = settingsRepository.getSettings()
                _settings.value = settings

                val currentPage = effectivePages.getOrNull(book.currentPage)
                    ?: bookRepository.getPage(bookId, book.currentPage)
                    ?: effectivePages.firstOrNull()

                if (currentPage == null) {
                    _uiState.value = ReaderUiState.Error("No pages found for book: $bookId")
                    return@launch
                }

                loadJob = launch {
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
     * Translate the next batch of untranslated paragraphs.
     * Starts from the current scroll position and scans forward for the first
     * untranslated paragraph, then collects [TRANSLATE_WINDOW_SIZE] untranslated
     * paragraphs after it. Respects model character limits via the use case's
     * internal batching.
     */
    fun translateCurrentPage() {
        cancelTranslation()
        hasAutoRetried = false

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
                    _translationEvents.trySend(TranslationEvent.Error(
                        message = "All paragraphs already translated to $targetLang",
                        canRetry = false,
                        canDownloadModel = false,
                    ))
                    return@launch
                }

                AppLogger.i("translateCurrentPage: ${pagesToTranslate.size} pages, targetLang=$targetLang, center=${state.currentPage.index}")

                val pageTranslations = pagesToTranslate.map { page ->
                    PageToTranslate(index = page.index, text = page.originalText)
                }

                val result = withTimeoutOrNull(45_000L) {
                    translatePageUseCase.translateBatchWithContext(
                        pages = pageTranslations,
                        targetLanguage = targetLang,
                        sourceLanguage = _book?.language,
                        onPageTranslated = { _, _ -> },
                        bookContext = _bookContext,
                    )
                } ?: run {
                    AppLogger.e("Translation timed out for ${pagesToTranslate.size} pages")
                    Result.failure(Exception("Translation timed out"))
                }

                result.fold(
                    onSuccess = { batchResult ->
                        AppLogger.i("Translation success: ${batchResult.translations.size} pages, model=${batchResult.model}")
                        applyTranslationsBatch(batchResult.translations, targetLang, batchResult.model)
                        _isTranslating.value = false
                        _translationError.value = null
                        hasAutoRetried = false

                        // Notify UI: offline fallback was used
                        if (batchResult.model.contains("ML Kit", ignoreCase = true)) {
                            _translationEvents.trySend(TranslationEvent.OfflineFallback(batchResult.translations.size))
                        } else {
                            _translationEvents.trySend(TranslationEvent.Success(batchResult.translations.size))
                        }
                    },
                    onFailure = { error ->
                        AppLogger.e("translateCurrentPage failed: ${error.message}", error)
                        _isTranslating.value = false

                        // Auto-retry once on transient failures
                        if (!hasAutoRetried) {
                            hasAutoRetried = true
                            AppLogger.i("Auto-retrying translation after 1s…")
                            kotlinx.coroutines.delay(1000L)
                            _isTranslating.value = true
                            retryBatchTranslation(pageTranslations, targetLang)
                            return@fold
                        }

                        // After auto-retry failed: show snackbar with model info
                        handleTranslationFailure(error, targetLang)
                    }
                )
            } catch (e: Exception) {
                AppLogger.e("translateCurrentPage exception: ${e.message}", e)
                _isTranslating.value = false
                handleTranslationFailure(e, targetLang)
            }
        }
    }

    private suspend fun retryBatchTranslation(
        pageTranslations: List<PageToTranslate>,
        targetLang: String,
    ) {
        val result = withTimeoutOrNull(45_000L) {
            translatePageUseCase.translateBatchWithContext(
                pages = pageTranslations,
                targetLanguage = targetLang,
                sourceLanguage = _book?.language,
                onPageTranslated = { _, _ -> },
                bookContext = _bookContext,
            )
        } ?: Result.failure(Exception("Translation timed out"))

        result.fold(
            onSuccess = { batchResult ->
                applyTranslationsBatch(batchResult.translations, targetLang, batchResult.model)
                _isTranslating.value = false
                _translationError.value = null
                hasAutoRetried = false
                if (batchResult.model.contains("ML Kit", ignoreCase = true)) {
                    _translationEvents.trySend(TranslationEvent.OfflineFallback(batchResult.translations.size))
                } else {
                    _translationEvents.trySend(TranslationEvent.Success(batchResult.translations.size))
                }
            },
            onFailure = { error ->
                _isTranslating.value = false
                handleTranslationFailure(error, targetLang)
            }
        )
    }

    private suspend fun handleTranslationFailure(error: Throwable, targetLang: String) {
        val errorMsg = error.message ?: "Translation failed"
        AppLogger.e("handleTranslationFailure: $errorMsg")

        // Check if ML Kit model is available for offline fallback
        val modelAvailable = try {
            mlKitModelManager.getAvailableModels().any { it.code == targetLang && it.isDownloaded }
        } catch (e: Exception) {
            false
        }

        _translationError.value = errorMsg
        _translationEvents.trySend(TranslationEvent.Error(
            message = errorMsg,
            canRetry = true,
            canDownloadModel = !modelAvailable,
        ))
    }

    fun downloadModelForCurrentLang() {
        viewModelScope.launch(ioDispatcher) {
            val state = _uiState.value as? ReaderUiState.ReaderReady ?: return@launch
            val targetLang = state.settings.targetLanguage
            AppLogger.i("Downloading ML Kit model for $targetLang")
            val success = mlKitModelManager.downloadModel(targetLang)
            if (success) {
                _translationEvents.trySend(TranslationEvent.Success(0))
                // Auto-retry translation after model download
                translateCurrentPage()
            } else {
                _translationEvents.trySend(TranslationEvent.Error(
                    message = "Failed to download offline model for $targetLang",
                    canRetry = true,
                    canDownloadModel = false,
                ))
            }
        }
    }

    fun cancelTranslation() {
        translationJob?.cancel()
        translationJob = null
        _isTranslating.value = false
        _translationError.value = null
    }

    /**
     * Translate a single paragraph by index.
     * Skips if already translated (use [reTranslateParagraph] for force).
     */
    fun translateParagraph(index: Int) {
        translateParagraphInternal(index, forceRetranslate = false)
    }

    /**
     * Force re-translate a paragraph, bypassing cache.
     * Used when user wants a fresh translation for poor quality text.
     */
    fun reTranslateParagraph(index: Int) {
        translateParagraphInternal(index, forceRetranslate = true)
    }

    private fun translateParagraphInternal(index: Int, forceRetranslate: Boolean) {
        translationJob?.cancel()
        translationJob = viewModelScope.launch(ioDispatcher) {
            val state = _uiState.value as? ReaderUiState.ReaderReady ?: return@launch
            val targetLang = state.settings.targetLanguage
            val page = state.pages.getOrNull(index) ?: return@launch

            if (!forceRetranslate && page.hasTranslation(targetLang)) return@launch

            _paragraphsTranslating.value = _paragraphsTranslating.value + index
            _translationError.value = null

            try {
                val result = translatePageUseCase.translateBatchWithContext(
                    pages = listOf(PageToTranslate(index = page.index, text = page.originalText)),
                    targetLanguage = targetLang,
                    sourceLanguage = _book?.language,
                    onPageTranslated = { _, _ -> }, // Apply once in fold below (avoid double DB write)
                    forceRetranslate = forceRetranslate,
                    bookContext = _bookContext,
                )

                result.fold(
                    onSuccess = { batchResult ->
                        batchResult.translations.forEach { (pageIndex, translation) ->
                            applyTranslation(pageIndex, targetLang, translation, batchResult.model)
                        }
                    },
                    onFailure = { error ->
                        AppLogger.e("translateParagraph failed: ${error.message}", error)
                        _translationError.value = error.message ?: "Translation failed"
                    }
                )
            } catch (e: kotlinx.coroutines.CancellationException) {
                throw e // Propagate cancellation — don't treat user-initiated cancel as an error
            } catch (e: Exception) {
                AppLogger.e("translateParagraph exception: ${e.message}", e)
                _translationError.value = e.message ?: "Translation failed"
            } finally {
                _paragraphsTranslating.value = _paragraphsTranslating.value - index
            }
        }
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
                    onPageTranslated = { _, _ -> }, // No-op: batch-apply in onSuccess
                    bookContext = _bookContext,
                )

                result.fold(
                    onSuccess = { batchResult ->
                        applyTranslationsBatch(batchResult.translations, targetLang, batchResult.model)
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
        applyTranslationsBatch(mapOf(pageIndex to translation), lang, model)
    }

    /**
     * Apply multiple translations in a SINGLE state update + DB write.
     * This avoids O(n×m) list copies when translating a batch of pages.
     */
    private fun applyTranslationsBatch(
        translations: Map<Int, String>,
        lang: String,
        model: String? = null,
    ) {
        if (translations.isEmpty()) return
        AppLogger.i("applyTranslationsBatch: ${translations.size} pages, lang=$lang, model=${model ?: "n/a"}")

        // Build an index→position map for O(1) lookups instead of find() per page
        val pageIndexMap = _pages.value.withIndex().associate { (pos, page) -> page.index to pos }
        val updatedPages = _pages.value.toMutableList()
        val updatedPagesList = mutableListOf<Page>()

        for ((pageIndex, translation) in translations) {
            val pos = pageIndexMap[pageIndex]
            if (pos != null) {
                val updated = updatedPages[pos].withTranslation(lang, translation, model, System.currentTimeMillis())
                updatedPages[pos] = updated
                updatedPagesList.add(updated)
            }
        }

        if (updatedPagesList.isEmpty()) return
        _pages.value = updatedPages

        // Persist all updated pages in a single background coroutine
        val bookId = _book?.id
        if (bookId != null) {
            val converters = com.dualreader.app.data.local.Converters()
            viewModelScope.launch(ioDispatcher + kotlinx.coroutines.NonCancellable) {
                for (page in updatedPagesList) {
                    runCatching {
                        bookRepository.updatePageTranslation(
                            bookId = bookId,
                            pageIndex = page.index,
                            translationsJson = converters.toTranslationsJson(page.translations),
                            modelsJson = converters.toTranslationsJson(page.translationModels),
                        )
                    }.onFailure { AppLogger.e("applyTranslationsBatch: persist failed for page ${page.index}: ${it.message}") }
                }
            }
        }
    }

    /**
     * Persist translated pages to the repository. Uses targeted UPDATE for
     * pages that have translations, which is more reliable than full REPLACE.
     */
    private fun persistPages() {
        val pagesToSave = _pages.value
        val bookId = _book?.id ?: return
        val converters = com.dualreader.app.data.local.Converters()
        viewModelScope.launch(ioDispatcher) {
            var saved = 0
            for (page in pagesToSave) {
                if (page.translations.isNotEmpty()) {
                    runCatching {
                        bookRepository.updatePageTranslation(
                            bookId = bookId,
                            pageIndex = page.index,
                            translationsJson = converters.toTranslationsJson(page.translations),
                            modelsJson = converters.toTranslationsJson(page.translationModels),
                        )
                    }
                        .onSuccess { saved++ }
                        .onFailure { AppLogger.e("persistPages: failed page ${page.index}: ${it.message}") }
                }
            }
            AppLogger.i("persistPages: saved translations for $saved/${pagesToSave.count { it.translations.isNotEmpty() }} pages")
        }
    }

    /**
     * Collect up to [TRANSLATE_WINDOW_SIZE] untranslated paragraphs starting
     * from the current scroll position. Scans forward first, then backward
     * if nothing is found ahead.
     */
    private fun collectTranslateWindow(
        allPages: List<Page>,
        centerIndex: Int,
        targetLang: String,
    ): List<Page> {
        val window = mutableListOf<Page>()

        // Scan forward from current position
        for (i in centerIndex until allPages.size) {
            if (window.size >= TRANSLATE_WINDOW_SIZE) break
            val page = allPages[i]
            if (!page.hasTranslation(targetLang)) {
                window.add(page)
            }
        }

        // Scan backward from current position to fill remaining window
        for (i in centerIndex - 1 downTo 0) {
            if (window.size >= TRANSLATE_WINDOW_SIZE) break
            val page = allPages[i]
            if (!page.hasTranslation(targetLang)) {
                window.add(page)
            }
        }

        return window.sortedBy { it.index }
    }

    fun updateCurrentPage(index: Int) {
        val pages = _pages.value
        val page = pages.getOrNull(index) ?: return
        val book = _book?.copy(currentPage = page.index, lastReadAt = java.time.LocalDateTime.now()) ?: return
        _book = book
        // Persist currentPage to repo (fire-and-forget)
        viewModelScope.launch(ioDispatcher) {
            try {
                bookRepository.updateBook(book)
            } catch (_: Exception) { }
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

    private val exporter = BookmarkExporter()

    /**
     * Convert current bookmarks to exportable format with book metadata.
     */
    fun getExportableBookmarks(): List<ExportableBookmark> {
        val book = _book ?: return emptyList()
        val bookmarks = _bookmarks.value
        return bookmarks.map { bm ->
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
    }

    /**
     * Format bookmarks for export in the given format.
     */
    fun formatBookmarks(format: ExportFormat): String {
        val exportable = getExportableBookmarks()
        return exporter.export(exportable, format)
    }

    /**
     * Returns the file extension for the given export format.
     */
    fun exportFileExtension(format: ExportFormat): String = exporter.fileExtension(format)

    /**
     * Returns a suggested filename for export.
     */
    fun exportFileName(format: ExportFormat): String {
        val book = _book ?: return "annotations"
        val safeTitle = book.title.replace(Regex("[^a-zA-Z0-9 _-]"), "").take(50).trim()
        val ext = exporter.fileExtension(format)
        return "${safeTitle}_annotations.$ext"
    }

    fun updateSettings(transform: (ReadingSettings) -> ReadingSettings) {
        viewModelScope.launch(ioDispatcher) {
            val currentSettings = _settings.value ?: return@launch
            _settings.value = transform(currentSettings)
        }
    }

    fun toggleImmersiveMode() {
        viewModelScope.launch(ioDispatcher) {
            _settings.value ?: return@launch
            // Persist to DataStore so the preference survives app restart (DR-027).
            // The settings flow re-emits and updates _settings + uiState reactively.
            settingsRepository.updateSettings { it.copy(isImmersiveMode = !it.isImmersiveMode) }
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

    // ── Text-to-Speech ──────────────────────────────────────────────────────

    /** TTS UI state exposed to Compose. */
    data class TtsUiState(
        val isSpeaking: Boolean = false,
        val currentParagraph: Int = -1,
        val error: String? = null,
        val isLanguageAvailable: Boolean = true,
        val speechRate: Float = 1.0f,
    )

    private val _ttsState = MutableStateFlow(TtsUiState())
    val ttsState: StateFlow<TtsUiState> = _ttsState.asStateFlow()

    /** Cached paragraphs for the current page's translated text. */
    private var ttsParagraphs: List<String> = emptyList()

    /**
     * Speak translated paragraphs from the current page.
     * Splits the translated text by double newline to get paragraphs.
     */
    fun speakCurrentPage(paragraphIndex: Int = 0) {
        val state = _uiState.value as? ReaderUiState.ReaderReady ?: return
        val targetLang = state.settings.targetLanguage
        val translation = state.currentPage.translations[targetLang]
        if (translation.isNullOrBlank()) {
            _ttsState.value = _ttsState.value.copy(error = "No translation available. Translate the page first.")
            return
        }

        // Check language availability
        if (!ttsService.isLanguageAvailable(targetLang)) {
            _ttsState.value = _ttsState.value.copy(
                error = "No TTS voice for this language. Install a TTS engine from Settings.",
                isLanguageAvailable = false,
            )
            return
        }

        // Split by paragraph boundaries (double newline, matching ParagraphAligner)
        ttsParagraphs = translation.split("\n\n").filter { it.isNotBlank() }
        if (ttsParagraphs.isEmpty()) {
            _ttsState.value = _ttsState.value.copy(error = "No paragraphs to read.")
            return
        }

        val startIndex = paragraphIndex.coerceIn(0, ttsParagraphs.lastIndex)

        _ttsState.value = _ttsState.value.copy(
            isSpeaking = true,
            currentParagraph = startIndex,
            error = null,
            isLanguageAvailable = true,
            speechRate = ttsService.getSpeechRate(),
        )

        ttsService.speak(
            paragraphs = ttsParagraphs,
            langCode = targetLang,
            startIndex = startIndex,
            onParagraphStarted = { idx ->
                _ttsState.value = _ttsState.value.copy(currentParagraph = idx, isSpeaking = true)
            },
            onCompleted = {
                _ttsState.value = _ttsState.value.copy(isSpeaking = false, currentParagraph = -1)
            },
            onError = { msg ->
                AppLogger.e("TTS error: $msg")
                _ttsState.value = _ttsState.value.copy(isSpeaking = false, currentParagraph = -1, error = msg)
            },
        )
    }

    /** Speak a single paragraph by index — reads that paragraph's translation directly. */
    fun speakParagraph(index: Int) {
        val state = _uiState.value as? ReaderUiState.ReaderReady ?: return
        val targetLang = state.settings.targetLanguage
        val page = state.pages.getOrNull(index) ?: return
        val translation = page.translations[targetLang]

        if (translation.isNullOrBlank()) {
            _ttsState.value = _ttsState.value.copy(error = "No translation available. Translate this paragraph first.")
            return
        }

        if (!ttsService.isLanguageAvailable(targetLang)) {
            _ttsState.value = _ttsState.value.copy(
                error = "No TTS voice for this language. Install a TTS engine from Settings.",
                isLanguageAvailable = false,
            )
            return
        }

        _ttsState.value = _ttsState.value.copy(
            isSpeaking = true,
            currentParagraph = index,
            error = null,
            isLanguageAvailable = true,
            speechRate = ttsService.getSpeechRate(),
        )

        ttsService.speak(
            paragraphs = listOf(translation),
            langCode = targetLang,
            startIndex = 0,
            onParagraphStarted = {
                _ttsState.value = _ttsState.value.copy(currentParagraph = index, isSpeaking = true)
            },
            onCompleted = {
                _ttsState.value = _ttsState.value.copy(isSpeaking = false, currentParagraph = -1)
            },
            onError = { msg ->
                AppLogger.e("TTS error: $msg")
                _ttsState.value = _ttsState.value.copy(isSpeaking = false, currentParagraph = -1, error = msg)
            },
        )
    }

    /** Stop TTS playback. */
    fun stopTts() {
        ttsService.stop()
        _ttsState.value = _ttsState.value.copy(isSpeaking = false, currentParagraph = -1)
    }

    /** Pause TTS playback. */
    fun pauseTts() {
        ttsService.pause()
        _ttsState.value = _ttsState.value.copy(isSpeaking = false)
    }

    /** Set TTS speech rate (0.5 to 2.0). */
    fun setTtsSpeechRate(rate: Float) {
        ttsService.setSpeechRate(rate)
        _ttsState.value = _ttsState.value.copy(speechRate = rate)
    }

    /** Check if TTS is available for the current target language. */
    fun checkTtsAvailability() {
        val state = _uiState.value as? ReaderUiState.ReaderReady ?: return
        val available = ttsService.isLanguageAvailable(state.settings.targetLanguage)
        _ttsState.value = _ttsState.value.copy(isLanguageAvailable = available)
    }

    override fun onCleared() {
        super.onCleared()
        ttsService.stop()
        ttsService.release()
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
