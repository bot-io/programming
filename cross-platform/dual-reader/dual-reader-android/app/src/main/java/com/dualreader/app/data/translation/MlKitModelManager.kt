package com.dualreader.app.data.translation

import android.content.Context
import com.dualreader.app.util.AppLogger
import com.google.mlkit.common.model.DownloadConditions
import com.google.mlkit.common.model.RemoteModelManager
import com.google.mlkit.nl.translate.TranslateLanguage
import com.google.mlkit.nl.translate.TranslateRemoteModel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import javax.inject.Inject
import javax.inject.Singleton

data class LanguageModelInfo(
    val code: String,
    val displayName: String,
    val isDownloaded: Boolean,
)

@Singleton
class MlKitModelManager @Inject constructor(
    @ApplicationContext private val context: Context,
) {
    private val modelManager = RemoteModelManager.getInstance()

    private val languageNames = mapOf(
        "en" to "English", "es" to "Spanish", "fr" to "French", "de" to "German",
        "it" to "Italian", "pt" to "Portuguese", "ru" to "Russian", "zh" to "Chinese",
        "ja" to "Japanese", "ko" to "Korean", "ar" to "Arabic", "bg" to "Bulgarian",
        "nl" to "Dutch", "sv" to "Swedish", "pl" to "Polish", "tr" to "Turkish",
        "cs" to "Czech", "ro" to "Romanian", "el" to "Greek", "da" to "Danish",
        "fi" to "Finnish", "no" to "Norwegian", "hu" to "Hungarian", "uk" to "Ukrainian",
        "hi" to "Hindi", "th" to "Thai", "vi" to "Vietnamese", "id" to "Indonesian",
        "he" to "Hebrew", "fa" to "Persian", "ca" to "Catalan", "hr" to "Croatian",
        "lt" to "Lithuanian", "lv" to "Latvian", "sk" to "Slovak", "sl" to "Slovenian",
    )

    suspend fun getAvailableModels(): List<LanguageModelInfo> = withContext(Dispatchers.IO) {
        val downloaded = try {
            modelManager.getDownloadedModels(TranslateRemoteModel::class.java).await()
        } catch (e: Exception) {
            AppLogger.e("[MlKitModelManager] Failed to get downloaded models: ${e.message}")
            emptySet()
        }

        val downloadedLangCodes = downloaded.map { it.language }.toSet()

        TranslateLanguage.getAllLanguages().map { langCode ->
            // langCode is already the BCP-47 tag (e.g. "en", "es")
            LanguageModelInfo(
                code = langCode,
                displayName = languageNames[langCode] ?: langCode,
                isDownloaded = downloadedLangCodes.contains(langCode),
            )
        }.sortedBy { it.displayName }
    }

    suspend fun downloadModel(langCode: String): Boolean = withContext(Dispatchers.IO) {
        try {
            val lang = TranslateLanguage.fromLanguageTag(langCode)
                ?: throw IllegalArgumentException("Unknown language: $langCode")
            val model = TranslateRemoteModel.Builder(lang).build()
            val conditions = DownloadConditions.Builder().build()
            modelManager.download(model, conditions).await()
            AppLogger.d("[MlKitModelManager] Downloaded model for $langCode")
            true
        } catch (e: Exception) {
            AppLogger.e("[MlKitModelManager] Failed to download $langCode: ${e.message}")
            false
        }
    }

    suspend fun deleteModel(langCode: String): Boolean = withContext(Dispatchers.IO) {
        try {
            val lang = TranslateLanguage.fromLanguageTag(langCode)
                ?: throw IllegalArgumentException("Unknown language: $langCode")
            val model = TranslateRemoteModel.Builder(lang).build()
            modelManager.deleteDownloadedModel(model).await()
            AppLogger.d("[MlKitModelManager] Deleted model for $langCode")
            true
        } catch (e: Exception) {
            AppLogger.e("[MlKitModelManager] Failed to delete $langCode: ${e.message}")
            false
        }
    }
}
