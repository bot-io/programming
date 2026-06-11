package com.dualreader.app.ui.screens

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.dualreader.app.domain.entities.Page
import com.dualreader.app.domain.entities.ReadingSettings
import com.dualreader.app.domain.repositories.BookRepository
import com.dualreader.app.domain.repositories.SettingsRepository
import com.dualreader.app.domain.repositories.TranslationCacheRepository
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
    val languages: Map<String, String>,     // lang → translated text (truncated)
    val models: Map<String, String?>,       // lang → model name
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

    init {
        refreshCacheCount()
    }

    fun updateSettings(settings: ReadingSettings) {
        viewModelScope.launch {
            settingsRepository.updateSettings { settings }
        }
    }

    fun clearAllTranslations() {
        viewModelScope.launch {
            cacheRepository.clearAll()
            refreshCacheCount()
        }
    }

    /** Load translation info for all books in the library. */
    fun loadTranslationInfo() {
        viewModelScope.launch {
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
        }
    }

    private fun refreshCacheCount() {
        viewModelScope.launch {
            _cachedCount.value = cacheRepository.count()
        }
    }
}
