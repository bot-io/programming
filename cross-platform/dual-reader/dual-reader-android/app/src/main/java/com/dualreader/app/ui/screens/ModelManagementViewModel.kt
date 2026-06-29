package com.dualreader.app.ui.screens

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.dualreader.app.data.translation.LanguageModelInfo
import com.dualreader.app.data.translation.MlKitModelManager
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

data class ModelManagementUiState(
    val models: List<LanguageModelInfo> = emptyList(),
    val isLoading: Boolean = false,
    val downloadingLang: String? = null,
    val searchQuery: String = "",
    val error: String? = null,
)

@HiltViewModel
class ModelManagementViewModel @Inject constructor(
    private val modelManager: MlKitModelManager,
) : ViewModel() {

    private val _uiState = MutableStateFlow(ModelManagementUiState(isLoading = true))
    val uiState: StateFlow<ModelManagementUiState> = _uiState.asStateFlow()

    init {
        loadModels()
    }

    fun loadModels() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, error = null)
            try {
                val models = modelManager.getAvailableModels()
                _uiState.value = _uiState.value.copy(models = models, isLoading = false)
            } catch (e: kotlinx.coroutines.CancellationException) {
                throw e // VM cleared — don't show spurious error (DR-052)
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(isLoading = false, error = e.message)
            }
        }
    }

    fun downloadModel(langCode: String) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(downloadingLang = langCode)
            try {
                modelManager.downloadModel(langCode)
                loadModels()
            } catch (e: kotlinx.coroutines.CancellationException) {
                throw e // VM cleared — don't show spurious error (DR-052)
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(error = "Download failed: ${e.message}")
            } finally {
                _uiState.value = _uiState.value.copy(downloadingLang = null)
            }
        }
    }

    fun deleteModel(langCode: String) {
        viewModelScope.launch {
            try {
                modelManager.deleteModel(langCode)
                loadModels()
            } catch (e: kotlinx.coroutines.CancellationException) {
                throw e // VM cleared — don't show spurious error (DR-052)
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(error = "Delete failed: ${e.message}")
            }
        }
    }

    fun updateSearchQuery(query: String) {
        _uiState.value = _uiState.value.copy(searchQuery = query)
    }
}
