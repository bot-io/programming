package com.dualreader.app.data.translation

import com.dualreader.app.domain.services.TranslationException
import com.dualreader.app.domain.services.TranslationService
import com.google.mlkit.nl.languageid.LanguageIdentification
import com.google.mlkit.nl.translate.TranslateLanguage
import com.google.mlkit.nl.translate.Translation
import com.google.mlkit.nl.translate.TranslatorOptions
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import javax.inject.Inject

/**
 * On-device translation fallback using Google ML Kit.
 *
 * Quality note: ML Kit is good for simple/technical text but struggles
 * with literary translations. It serves as a free, offline fallback when
 * the GLM API is unavailable or quota is exhausted.
 */
class MlKitTranslationServiceImpl @Inject constructor() : TranslationService {

    override val providerName: String = "ML Kit (On-device)"

    override suspend fun translate(
        text: String,
        targetLanguage: String,
        sourceLanguage: String?,
        context: String?,
    ): String = withContext(Dispatchers.IO) {
        val src = sourceLanguage ?: detectLanguage(text)

        val srcCode = TranslateLanguage.fromLanguageTag(src)
            ?: throw TranslationException("Unsupported source language: $src")
        val tgtCode = TranslateLanguage.fromLanguageTag(targetLanguage)
            ?: throw TranslationException("Unsupported target language: $targetLanguage")

        val options = TranslatorOptions.Builder()
            .setSourceLanguage(srcCode)
            .setTargetLanguage(tgtCode)
            .build()
        val translator = Translation.getClient(options)

        try {
            // Download model if needed
            try {
                translator.downloadModelIfNeeded().await()
            } catch (_: Exception) {
                // May already be downloaded
            }

            translator.translate(text).await()
        } catch (e: Exception) {
            throw TranslationException("ML Kit translation failed: ${e.message}", e)
        } finally {
            translator.close()
        }
    }

    override suspend fun translateBatch(
        texts: List<String>,
        targetLanguage: String,
        sourceLanguage: String?,
    ): List<String> = withContext(Dispatchers.IO) {
        val src = sourceLanguage ?: detectLanguage(texts.firstOrNull() ?: "")
        texts.map { translate(it, targetLanguage, src) }
    }

    override suspend fun detectLanguage(text: String): String = withContext(Dispatchers.IO) {
        val detector = LanguageIdentification.getClient()
        try {
            val langCode = detector.identifyLanguage(text).await()
            if (langCode == "und" || langCode.length != 2) {
                throw TranslationException("Could not identify language for text")
            }
            langCode
        } finally {
            detector.close()
        }
    }

    override suspend fun isAvailable(): Boolean = true
}
