package com.dualreader.app.ui.screens

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.dualreader.app.domain.entities.ReadingSettings
import com.dualreader.app.domain.repositories.SettingsRepository
import com.dualreader.app.domain.repositories.TranslationCacheRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class SettingsViewModel @Inject constructor(
    private val settingsRepository: SettingsRepository,
    private val cacheRepository: TranslationCacheRepository,
) : ViewModel() {

    val settings: StateFlow<ReadingSettings> = settingsRepository.settings
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), ReadingSettings())

    private val _cachedCount = MutableStateFlow(0)
    val cachedCount: StateFlow<Int> = _cachedCount.asStateFlow()

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

    private fun refreshCacheCount() {
        viewModelScope.launch {
            _cachedCount.value = cacheRepository.count()
        }
    }
}
