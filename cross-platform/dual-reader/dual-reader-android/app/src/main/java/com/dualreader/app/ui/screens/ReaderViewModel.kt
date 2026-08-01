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
import kotlinx.coroutines.flow.filterNotNull
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeoutOrNull
import kotlinx.coroutines.CancellationException
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
    private val translatePageUseCase: TranslatePageUseCase,
    private val paginateBookUseCase: PaginateBookUseCase,
    private val translationCacheRepository: TranslationCacheRepository,
    private val ttsService: com.dualreader.app.domain.services.TtsService,
    private val translationService: com.dualreader.app.domain.services.TranslationService,
    private val fallbackTranslationService: com.dualreader.app.data.translation.FallbackTranslationService,
    private val mlKitModelManager: com.dualreader.app.data.translation.MlKitModelManager,
) : ViewModel() {

    companion object {
        private const val KEY_BOOK_ID = "bookId"

        /** How many pages to translate around the current page when user taps "Translate". */
        const val TRANSLATE_WINDOW_SIZE = 15

        /** Maximum number of position snap marks to retain. */
        const val MAX_POSITION_HISTORY = 5

        /** Minimum distance between snap points, as fraction of total pages. */
        const val MIN_SNAP_FRACTION = 0.02f

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
    private val _book = MutableStateFlow<Book?>(null)

    // DR-063: Reading position history for slider snap-to-navigation.
    // Tracks pages the user spent time at, enabling quick jumps between reading spots.
    private val _positionHistory = MutableStateFlow<List<Int>>(emptyList())
    val positionHistory: StateFlow<List<Int>> = _positionHistory.asStateFlow()

    private val _isTranslating = MutableStateFlow(false)
    private val _translationError = MutableStateFlow<String?>(null)
    private val _paragraphsTranslating = MutableStateFlow<Set<Int>>(emptySet())
    val paragraphsTranslating: StateFlow<Set<Int>> = _paragraphsTranslating.asStateFlow()
    private var translationJob: Job? = null
    private var loadJob: Job? = null
    private var loadOuterJob: Job? = null
    private var ttsRetryJob: Job? = null // DR-092: Track TTS retry coroutine
    private var persistJob: Job? = null // DR-181: Track persistence coroutine to prevent post-clear DB writes

    // ── Translation events (one-time UI events for Snackbar) ──────────────
    sealed class TranslationEvent {
        data class Error(val message: String, val canRetry: Boolean, val canDownloadModel: Boolean) : TranslationEvent()
        data class OfflineFallback(val pagesTranslated: Int) : TranslationEvent()
        data class Success(val pagesTranslated: Int) : TranslationEvent()
        data class PersistenceError(val failedPages: Int) : TranslationEvent() // DR-106: Notify user when persistence fails
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
        val sourceLang = if (isFromOriginal) _book.value?.language else state.settings.targetLanguage
        val targetLang = if (isFromOriginal) state.settings.targetLanguage else _book.value?.language ?: "en"

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
            } catch (e: kotlinx.coroutines.CancellationException) {
                throw e // Rapid word lookups cancel prior job — don't show spurious error (DR-051)
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

        // Register cloud upgrade callback: when background cloud translation
        // completes, find the matching page by original text and replace the
        // ML Kit translation with the higher-quality cloud version.
        fallbackTranslationService.cloudUpgradeCallback = originalText@{ originalText, cloudTranslation, targetLang ->
            val pages = _pages.value
            val bookId = currentBookId
            val pageToUpdate = _pages.value.find {
                it.bookId == bookId &&
                it.originalText.trim() == originalText.trim() &&
                it.originalText.contains(originalText.take(100))
            }
            if (pageToUpdate != null && bookId != null) {
                // Double-check bookId after finding page to catch concurrent loadBook
                val currentPage = _pages.value.getOrNull(pageToUpdate.index)
                val pageOriginalText = currentPage?.originalText?.trim()
                if (pageOriginalText != null && pageOriginalText == originalText.trim()) {
                    AppLogger.i("Cloud upgrade: replacing ML Kit translation for page ${pageToUpdate.index}")
                    applyTranslation(pageToUpdate.index, targetLang, cloudTranslation, "cloud-upgrade")
                }
            }
        }
    }

    /**
     * Reload pages from the database without resetting scroll position.
     * Called when returning from Settings after clearing translations.
     */
    fun reloadPages() {
        val bookId = currentBookId ?: return
        viewModelScope.launch(ioDispatcher) {
            try {
                val pages = bookRepository.getPagesForBook(bookId)
                AppLogger.i("reloadPages: loaded ${pages.size} pages, ${pages.count { it.translations.isNotEmpty() }} with translations")
                _pages.value = pages
            } catch (e: kotlinx.coroutines.CancellationException) {
                throw e // Preserve coroutine cancellation semantics (DR-138)
            } catch (e: Exception) {
                AppLogger.e("reloadPages: Failed to reload pages for book $bookId: ${e.message}", e)
            }
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
                _book.value = book

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
                    // DR-060: Include _book in the combine so scroll position changes
                    // propagate to uiState immediately. Previously _book was a plain var
                    // read inside collect — updates to currentPage were invisible to the
                    // UI and to translateCurrentPage(), causing stale translation starts.
                    combine(
                        settingsRepository.settings,
                        bookmarkRepository.getBookmarksForBook(bookId),
                        _pages,
                        combine(_isTranslating, _translationError) { t, e ->
                            UiExtras(t, e)
                        },
                        _book,
                    ) { settingsFlow, bookmarksFlow, pagesFlow, extras, bookFlow ->
                    // Only emit when we have a book loaded and pages parsed
                    if (bookFlow == null) {
                        null
                    } else {
                        val cp = pagesFlow.getOrNull(bookFlow.currentPage)
                            ?: pagesFlow.firstOrNull()
                        if (cp == null) {
                            AppLogger.e("loadBook: No page data found for bookId=${bookFlow.id}, currentPage=${bookFlow.currentPage}, pagesFlow.size=${pagesFlow.size}")
                            null
                        } else {
                                ReaderUiState.ReaderReady(
                                    book = bookFlow,
                                    pages = pagesFlow,
                                    currentPage = cp,
                                    settings = settingsFlow,
                                    bookmarks = bookmarksFlow,
                                    isTranslating = extras.isTranslating,
                                    translationError = extras.translationError,
                                )
                            }
                        }
                    }.filterNotNull().collect { readyState ->
                        _settings.value = readyState.settings
                        _bookmarks.value = readyState.bookmarks
                        _uiState.value = readyState
                    }
                }
            } catch (e: kotlinx.coroutines.CancellationException) {
                throw e // Book switch / VM clear — don't emit phantom Error state (DR-051)
            } catch (e: Exception) {
                AppLogger.e("loadBook failed: ${e.message}", e)
                _uiState.value = ReaderUiState.Error(e.message ?: "Failed to load book")
            }
        }
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

                // DR-061: Collect partial results via onPageTranslated callback.
                // If the overall timeout fires, we still apply whatever was
                // translated before the deadline instead of losing everything.
                // DR-140: Use AtomicReference for thread-safe model tracking (partialModel)
                val partialResults = mutableMapOf<Int, String>()
                val partialModel = java.util.concurrent.atomic.AtomicReference<String?>(null)

                val result = withTimeoutOrNull(120_000L) {
                    translatePageUseCase.translateBatchWithContext(
                        pages = pageTranslations,
                        targetLanguage = targetLang,
                        sourceLanguage = _book.value?.language,
                        onPageTranslated = { index, translation ->
                            partialResults[index] = translation
                        },
                        bookContext = _bookContext,
                    )
                }

                // If timeout: apply whatever partial results we collected
                if (result == null && partialResults.isNotEmpty()) {
                    AppLogger.w("translateCurrentPage timed out but got ${partialResults.size}/${pagesToTranslate.size} partial results — applying")
                    applyTranslationsBatch(partialResults, targetLang, partialModel.get() ?: "unknown")
                    _isTranslating.value = false
                    _translationError.value = null
                    _translationEvents.trySend(TranslationEvent.Success(partialResults.size))
                    return@launch
                }

                val finalResult = result ?: run {
                    AppLogger.e("Translation timed out for ${pagesToTranslate.size} pages, no partial results")
                    Result.failure(Exception("Translation timed out"))
                }

                finalResult.fold(
                    onSuccess = { batchResult ->
                        AppLogger.i("Translation success: ${batchResult.translations.size} pages, model=${batchResult.model}")
                        partialModel.set(batchResult.model)
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
            } catch (e: kotlinx.coroutines.CancellationException) {
                throw e // User cancelled translation — don't show spurious error (DR-051)
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
        // DR-061: Same partial-results pattern as translateCurrentPage
        val partialResults = mutableMapOf<Int, String>()

        val result = withTimeoutOrNull(120_000L) {
            translatePageUseCase.translateBatchWithContext(
                pages = pageTranslations,
                targetLanguage = targetLang,
                sourceLanguage = _book.value?.language,
                onPageTranslated = { index, translation ->
                    partialResults[index] = translation
                },
                bookContext = _bookContext,
            )
        }

        // Apply partial results even on timeout
        if (result == null && partialResults.isNotEmpty()) {
            AppLogger.w("retryBatchTranslation timed out but got ${partialResults.size} partial results — applying")
            applyTranslationsBatch(partialResults, targetLang, "unknown")
            _isTranslating.value = false
            _translationError.value = null
            _translationEvents.trySend(TranslationEvent.Success(partialResults.size))
            return
        }

        val finalResult = result ?: Result.failure(Exception("Translation timed out"))

        finalResult.fold(
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
        } catch (e: kotlinx.coroutines.CancellationException) {
            throw e // Propagate cancellation — don't set spurious error (DR-053)
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
                try {
                    translateCurrentPage()
                } catch (e: kotlinx.coroutines.CancellationException) {
                    throw e // User cancelled — don't treat as error (DR-149)
                } catch (e: Exception) {
                    AppLogger.e("downloadModelForCurrentLang: Translation failed after model download: ${e.message}", e)
                    handleTranslationFailure(e, targetLang)
                }
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

            _paragraphsTranslating.update { it + index } // DR-104: Atomic update (non-atomic .value = loses concurrent updates)
            _translationError.value = null

            try {
                val result = translatePageUseCase.translateBatchWithContext(
                    pages = listOf(PageToTranslate(index = page.index, text = page.originalText)),
                    targetLanguage = targetLang,
                    sourceLanguage = _book.value?.language,
                    bookContext = _bookContext,
                    forceRetranslate = forceRetranslate,
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
                _paragraphsTranslating.update { it - index } // DR-103: Atomic update (non-atomic .value = loses concurrent updates)
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
                    sourceLanguage = _book.value?.language,
                    onPageTranslated = { index, translation ->
                        // Apply each page as it's translated for live UI updates
                        applyTranslation(index, targetLang, translation)
                    },
                    bookContext = _bookContext,
                )

                result.fold(
                    onSuccess = { batchResult ->
                        // Also apply via batch in case callback wasn't invoked
                        // (idempotent — applyTranslationsBatch overwrites same values)
                        applyTranslationsBatch(batchResult.translations, targetLang, batchResult.model)
                        _isTranslating.value = false
                        _translationError.value = null
                    },
                    onFailure = { error ->
                        AppLogger.e("translateAllPages failed: ${error.message}", error)
                        _isTranslating.value = false
                        _translationError.value = error.message ?: "Batch translation failed"
                    }
                )
            } catch (e: kotlinx.coroutines.CancellationException) {
                throw e // User cancelled batch translation — don't set spurious error (DR-051)
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
        // NonCancellable was removed in DR-063 — cancellation is unlikely in result.fold context,
        // and avoiding unnecessary background work on navigation is worth the small risk.
        val bookId = _book.value?.id
        if (bookId != null) {
            val converters = com.dualreader.app.data.local.Converters()
            // DR-181: Cancel previous persist job to prevent duplicate DB writes
            persistJob?.cancel()
            persistJob = viewModelScope.launch(ioDispatcher) {
                // DR-106: Retry failed persistence operations with exponential backoff
                val failedPages = mutableMapOf<Int, Page>()
                for (page in updatedPagesList) {
                    var persisted = false
                    var lastError: Throwable? = null
                    
                    // Retry with exponential backoff: 1s, 2s, 4s
                    for (attempt in 1..3) {
                        try {
                            bookRepository.updatePageTranslation(
                                bookId = bookId,
                                pageIndex = page.index,
                                translationsJson = converters.toTranslationsJson(page.translations),
                                modelsJson = converters.toTranslationsJson(page.translationModels),
                            )
                            persisted = true
                            break
                        } catch (e: kotlinx.coroutines.CancellationException) {
                            throw e // Preserve coroutine cancellation semantics (DR-132)
                        } catch (e: Exception) {
                            lastError = e
                            AppLogger.w("applyTranslationsBatch: persist attempt $attempt/3 failed for page ${page.index}: ${e.message}")
                            if (attempt < 3) {
                                val delayMs = 1000L * (1 shl (attempt - 1)) // 1s, 2s, 4s
                                kotlinx.coroutines.delay(delayMs)
                            }
                        }
                    }
                    
                    if (!persisted) {
                        AppLogger.e("applyTranslationsBatch: persist failed permanently for page ${page.index} after 3 attempts", lastError)
                        failedPages[page.index] = page
                    }
                }
                
                // Notify user if any pages failed to persist
                if (failedPages.isNotEmpty()) {
                    AppLogger.e("applyTranslationsBatch: ${failedPages.size} pages failed to persist after retries")
                    _translationEvents.trySend(TranslationEvent.PersistenceError(failedPages.size))
                }
            }
        }
    }

    /**
     * Collect up to [TRANSLATE_WINDOW_SIZE] untranslated paragraphs around the
     * current scroll position.
     *
     * DR-062: Interleaves forward and backward scanning so pages NEAR the
     * current position are prioritized regardless of direction. Previously,
     * forward scanning filled the entire window first — so backward pages
     * were never reached when there were 15+ untranslated pages ahead.
     */
    private fun collectTranslateWindow(
        allPages: List<Page>,
        centerIndex: Int,
        targetLang: String,
    ): List<Page> {
        val window = mutableListOf<Page>()

        // Start with current page itself
        val centerPage = allPages.getOrNull(centerIndex)
        if (centerPage != null && !centerPage.hasTranslation(targetLang)) {
            window.add(centerPage)
        }

        // Alternate: 1 forward, 1 backward, expanding outward
        var forwardOffset = 1
        var backwardOffset = 1

        while (window.size < TRANSLATE_WINDOW_SIZE &&
            (centerIndex + forwardOffset < allPages.size || centerIndex - backwardOffset >= 0)
        ) {
            // Try forward
            if (centerIndex + forwardOffset < allPages.size) {
                val page = allPages[centerIndex + forwardOffset]
                if (!page.hasTranslation(targetLang)) {
                    window.add(page)
                    if (window.size >= TRANSLATE_WINDOW_SIZE) break
                }
                forwardOffset++
            }
            // Try backward
            if (centerIndex - backwardOffset >= 0) {
                val page = allPages[centerIndex - backwardOffset]
                if (!page.hasTranslation(targetLang)) {
                    window.add(page)
                    if (window.size >= TRANSLATE_WINDOW_SIZE) break
                }
                backwardOffset++
            }
        }

        return window.sortedBy { it.index }
    }

    fun updateCurrentPage(index: Int) {
        val pages = _pages.value
        val page = pages.getOrNull(index) ?: return
        if (_book.value == null) return
        _book.update { current ->
            current?.copy(currentPage = page.index, lastReadAt = java.time.LocalDateTime.now())
        }
        // Track this position for slider snap-to navigation
        trackReadingPosition(index, pages.size)
        // Persist currentPage to repo (fire-and-forget)
        viewModelScope.launch(ioDispatcher) {
            try {
                val book = _book.value ?: return@launch
                bookRepository.updateBook(book)
            } catch (e: kotlinx.coroutines.CancellationException) {
                throw e // Preserve coroutine cancellation semantics (DR-138)
            } catch (e: Exception) {
                AppLogger.e("updateCurrentPage: Failed to persist current page (page ${page.index}): ${e.message}", e)
            }
        }
    }

    /**
     * DR-063: Jump to a specific page via the navigation slider.
     * Unlike updateCurrentPage, this does NOT track the old position again
     * (the jump itself is the navigation action, not a reading position).
     */
    fun jumpToPosition(index: Int) {
        val pages = _pages.value
        if (index !in pages.indices) return
        if (_book.value == null) return
        _book.update { current ->
            current?.copy(currentPage = index, lastReadAt = java.time.LocalDateTime.now())
        }
        viewModelScope.launch(ioDispatcher) {
            try {
                val book = _book.value ?: return@launch
                bookRepository.updateBook(book)
            } catch (e: kotlinx.coroutines.CancellationException) {
                throw e // Preserve coroutine cancellation semantics (DR-138)
            } catch (e: Exception) {
                AppLogger.e("jumpToPosition: Failed to persist: ${e.message}", e)
            }
        }
    }

    /**
     * DR-063: Track a reading position for slider snap marks.
     * DR-091: Use atomic update to prevent race condition in rapid scrolling scenarios.
     * Deduplicates nearby positions (within MIN_SNAP_DISTANCE % of book).
     * Keeps at most MAX_POSITION_HISTORY entries, evicting oldest by time (FIFO).
     */
    fun trackReadingPosition(pageIndex: Int, totalPages: Int) {
        if (totalPages <= 0) return
        _positionHistory.update { current ->
            val mutable = current.toMutableList()
            // Remove marks too close to the new position (within 2% of book or at least 1 page)
            val minDistance = (totalPages * MIN_SNAP_FRACTION).toInt().coerceAtLeast(1)
            mutable.removeAll { kotlin.math.abs(it - pageIndex) <= minDistance }

            // Add new position (at end = newest)
            mutable.add(pageIndex)

            // Evict oldest if over limit (FIFO — first in is at index 0)
            while (mutable.size > MAX_POSITION_HISTORY) {
                mutable.removeAt(0)
            }

            mutable
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
            } catch (e: kotlinx.coroutines.CancellationException) {
                throw e // Preserve coroutine cancellation semantics (DR-138)
            } catch (e: Exception) {
                AppLogger.e("addBookmark: Failed to add bookmark for book $bookId (page ${state.currentPage.index}): ${e.message}", e)
            }
        }
    }

    fun removeBookmark(id: String) {
        viewModelScope.launch(ioDispatcher) {
            try {
                bookmarkRepository.deleteBookmark(id)
            } catch (e: kotlinx.coroutines.CancellationException) {
                throw e // Preserve coroutine cancellation semantics (DR-138)
            } catch (e: Exception) {
                AppLogger.e("removeBookmark: Failed to delete bookmark $id: ${e.message}", e)
            }
        }
    }

    private val exporter = BookmarkExporter()

    /**
     * Convert current bookmarks to exportable format with book metadata.
     */
    fun getExportableBookmarks(): List<ExportableBookmark> {
        val book = _book.value ?: return emptyList()
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
        val book = _book.value ?: return "annotations"
        val safeTitle = book.title.replace(Regex("[^a-zA-Z0-9 _-]"), "").take(50).trim()
        val ext = exporter.fileExtension(format)
        return "${safeTitle}_annotations.$ext"
    }

    fun updateSettings(transform: (ReadingSettings) -> ReadingSettings) {
        viewModelScope.launch(ioDispatcher) {
            val currentSettings = _settings.value ?: return@launch
            try {
                // DR-146: Persist to DataStore so the settings flow re-emits and updates uiState reactively.
                // Simply setting _settings.value is NOT enough — uiState is built from
                // settingsRepository.settings flow, not _settings directly.
                // DR-146: Update repository first, then local state. If cancelled between these,
                // the flow will still emit the correct value and fix _settings. This prevents
                // race conditions where _settings diverges from persisted data.
                settingsRepository.updateSettings { transform(it) }
                _settings.value = transform(currentSettings)
            } catch (e: kotlinx.coroutines.CancellationException) {
                throw e // Propagate cancellation — don't swallow (DR-146)
            }
        }
    }

    fun toggleImmersiveMode() {
        viewModelScope.launch(ioDispatcher) {
            _settings.value ?: return@launch
            try {
                // DR-146: Persist to DataStore so the preference survives app restart (DR-027).
                // The settings flow re-emits and updates _settings + uiState reactively.
                settingsRepository.updateSettings { it.copy(isImmersiveMode = !it.isImmersiveMode) }
            } catch (e: kotlinx.coroutines.CancellationException) {
                throw e // Propagate cancellation — don't swallow (DR-146)
            }
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

        // Check TTS engine status
        if (!ttsService.isReady) {
            if (ttsService.isInitFailed) {
                // TTS init failed - try reinitialize
                val reinitTriggered = ttsService.reinitialize()
                if (reinitTriggered) {
                    _ttsState.value = _ttsState.value.copy(
                        error = "TTS engine failed to initialize. Retrying..."
                    )
                    // DR-092: Track retry coroutine to prevent post-clear execution
                    // DR-130: Wrap retry in try-catch to log errors and show error to user
                    ttsRetryJob?.cancel()
                    ttsRetryJob = viewModelScope.launch {
                        try {
                            kotlinx.coroutines.delay(500)
                            speakCurrentPage(paragraphIndex)
                        } catch (e: kotlinx.coroutines.CancellationException) {
                            throw e // Propagate cancellation
                        } catch (e: Exception) {
                            AppLogger.e("TTS retry failed for speakCurrentPage: ${e.message}")
                            _ttsState.value = _ttsState.value.copy(
                                error = "TTS retry failed. Please try again.",
                                isSpeaking = false
                            )
                        }
                    }
                } else {
                    _ttsState.value = _ttsState.value.copy(
                        error = "TTS engine not ready. Initialization is in progress."
                    )
                }
            } else {
                _ttsState.value = _ttsState.value.copy(
                    error = "TTS engine not ready. Wait a moment and try again."
                )
            }
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

        // Check TTS engine status
        if (!ttsService.isReady) {
            if (ttsService.isInitFailed) {
                // TTS init failed - try reinitialize
                val reinitTriggered = ttsService.reinitialize()
                if (reinitTriggered) {
                    _ttsState.value = _ttsState.value.copy(
                        error = "TTS engine failed to initialize. Retrying..."
                    )
                    // DR-092: Track retry coroutine to prevent post-clear execution
                    // DR-130: Wrap retry in try-catch to log errors and show error to user
                    ttsRetryJob?.cancel()
                    ttsRetryJob = viewModelScope.launch {
                        try {
                            kotlinx.coroutines.delay(500)
                            speakParagraph(index)
                        } catch (e: kotlinx.coroutines.CancellationException) {
                            throw e // Propagate cancellation
                        } catch (e: Exception) {
                            AppLogger.e("TTS retry failed for speakParagraph: ${e.message}")
                            _ttsState.value = _ttsState.value.copy(
                                error = "TTS retry failed. Please try again.",
                                isSpeaking = false
                            )
                        }
                    }
                } else {
                    _ttsState.value = _ttsState.value.copy(
                        error = "TTS engine not ready. Initialization is in progress."
                    )
                }
            } else {
                _ttsState.value = _ttsState.value.copy(
                    error = "TTS engine not ready. Wait a moment and try again."
                )
            }
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
        // DR-180: Cancel all tracked jobs to prevent post-clear execution
        translationJob?.cancel()
        loadJob?.cancel()
        loadOuterJob?.cancel()
        ttsRetryJob?.cancel()
        persistJob?.cancel() // DR-185: Cancel persistence job to prevent post-clear DB writes
        wordJob?.cancel() // DR-193: Cancel word translation job to prevent post-clear UI updates
        // DR-098: Close Channel to prevent resource leaks
        _translationEvents.close()
        // DR-141: Clear cloud upgrade callback to prevent memory leaks and post-clear updates
        fallbackTranslationService.cloudUpgradeCallback = null
        try {
            ttsService.stop()
        } catch (e: CancellationException) {
            throw e // Preserve coroutine cancellation semantics (DR-202)
        } catch (e: Exception) {
            AppLogger.w("Failed to stop TTS service: ${e.message}")
        }
        try {
            ttsService.release()
        } catch (e: CancellationException) {
            throw e // Preserve coroutine cancellation semantics (DR-202)
        } catch (e: Exception) {
            AppLogger.w("Failed to release TTS service: ${e.message}")
        }
    }

    @VisibleForTesting
    internal fun callOnClearedForTesting() {
        onCleared()
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
)
