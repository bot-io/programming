package com.dualreader.app.ui.screens

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.dualreader.app.domain.entities.Page
import com.dualreader.app.domain.entities.ReadingSettings
import com.dualreader.app.domain.repositories.BookRepository
import com.dualreader.app.domain.repositories.SettingsRepository
import com.dualreader.app.domain.repositories.TranslationCacheRepository
import com.dualreader.app.util.AppLogger
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

/** Summary of a page's translations for the info dialog. */
data class PageTranslationInfo(
    val pageIndex: Int,
    val languages: Map<String, String>,
    val models: Map<String, String?>,
)

@HiltViewModel
class SettingsViewModel @Inject constructor(
    private val settingsRepository: SettingsRepository,
    private val cacheRepository: TranslationCacheRepository,
    private val bookRepository: BookRepository,
) : ViewModel() {

    val settings: StateFlow<ReadingSettings> = settingsRepository.settings
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), ReadingSettings())

    private val _cachedCount = MutableStateFlow(0)
    val cachedCount: StateFlow<Int> = _cachedCount.asStateFlow()

    private val _translationInfo = MutableStateFlow<List<PageTranslationInfo>>(emptyList())
    val translationInfo: StateFlow<List<PageTranslationInfo>> = _translationInfo.asStateFlow()

    // DR-113: Track clear translations errors to show user feedback
    private val _clearError = MutableStateFlow<String?>(null)
    val clearError: StateFlow<String?> = _clearError.asStateFlow()

    // DR-115: Track loadTranslationInfo errors to show user feedback
    private val _loadInfoError = MutableStateFlow<String?>(null)
    val loadInfoError: StateFlow<String?> = _loadInfoError.asStateFlow()

    init {
        refreshCacheCount()
    }

    fun updateSettings(settings: ReadingSettings) {
        viewModelScope.launch {
            try {
                settingsRepository.updateSettings { settings }
            } catch (e: kotlinx.coroutines.CancellationException) {
                throw e // Preserve coroutine cancellation semantics (DR-128)
            } catch (e: Exception) {
                AppLogger.e("updateSettings: Failed to save settings: ${e.message}", e)
            }
        }
    }

    fun clearAllTranslations() {
        _clearError.value = null
        viewModelScope.launch {
            try {
                cacheRepository.clearAll()
                bookRepository.clearAllTranslations()
                refreshCacheCount()
                _translationInfo.value = emptyList()
            } catch (e: kotlinx.coroutines.CancellationException) {
                throw e // Preserve coroutine cancellation semantics (DR-128)
            } catch (e: Exception) {
                AppLogger.e("clearAllTranslations: Failed to clear translations: ${e.message}", e)
                _clearError.value = "Failed to clear translations: ${e.message}"
            }
        }
    }

    // DR-113: Clear the error state after snackbar is shown
    fun clearErrorShown() {
        _clearError.value = null
    }

    // DR-115: Clear the loadInfoError state
    fun loadInfoErrorShown() {
        _loadInfoError.value = null
    }

    fun loadTranslationInfo() {
        _loadInfoError.value = null
        viewModelScope.launch {
            try {
                val books = bookRepository.getAllBooks().first()
                val allInfo = mutableListOf<PageTranslationInfo>()
                for (book in books) {
                    val pages = bookRepository.getPagesForBook(book.id)
                    for (page in pages) {
                        if (page.translations.isNotEmpty()) {
                            allInfo.add(
                                PageTranslationInfo(
                                    pageIndex = page.index,
                                    languages = page.translations.mapValues { (_, text) ->
                                        text.take(80) + if (text.length > 80) "…" else ""
                                    },
                                    models = page.translations.keys.associateWith { lang ->
                                        page.translationModel(lang)
                                    },
                                )
                            )
                        }
                    }
                }
                _translationInfo.value = allInfo
            } catch (e: kotlinx.coroutines.CancellationException) {
                throw e // Preserve coroutine cancellation semantics (DR-128)
            } catch (e: Exception) {
                AppLogger.e("loadTranslationInfo: Failed to load translation info: ${e.message}", e)
                _loadInfoError.value = "Failed to load translation info: ${e.message}"
            }
        }
    }

    private fun refreshCacheCount() {
        viewModelScope.launch {
            try {
                // Count translated pages from the pages table (what users see in the reader)
                _cachedCount.value = bookRepository.getTranslatedPageCount()
            } catch (e: kotlinx.coroutines.CancellationException) {
                throw e // Preserve coroutine cancellation semantics (DR-128)
            } catch (e: Exception) {
                AppLogger.e("refreshCacheCount: Failed to fetch translated page count: ${e.message}", e)
                // Keep the previous count on error - don't silently reset to 0
            }
        }
    }
}