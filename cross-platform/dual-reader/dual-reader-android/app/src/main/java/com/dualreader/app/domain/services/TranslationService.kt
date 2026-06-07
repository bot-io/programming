package com.dualreader.app.domain.services

/**
 * Translation service interface.
 *
 * Lesson from Flutter: ML Kit on-device translation produced terrible quality
 * for book-length text. The models are designed for short phrases.
 *
 * New strategy: LLM-first with tiered fallback.
 * - Tier 1: GLM-4.7-Flash (free, excellent quality for literary text)
 * - Tier 2: GLM-4.7-FlashX ($0.07/book, faster)
 * - Tier 3: GLM-4.5 ($0.30/book, best quality)
 * - Tier 4: On-device ML Kit (offline, lowest quality)
 *
 * LLMs translate paragraph-by-paragraph with context instructions,
 * producing dramatically better results than sentence-level MT.
 */
interface TranslationService {
    /**
     * Translate text to the target language.
     *
     * @param text The text to translate (typically a paragraph or page)
     * @param targetLanguage ISO 639-1 code (e.g., "es", "bg", "fr")
     * @param sourceLanguage ISO 639-1 code (e.g., "en"), or null for auto-detect
     * @param context Optional surrounding context for better quality
     * @return Translated text
     */
    suspend fun translate(
        text: String,
        targetLanguage: String,
        sourceLanguage: String? = null,
        context: String? = null,
    ): String

    /**
     * Translate a batch of text segments. More efficient than individual calls
     * for LLM providers (single API call with multiple paragraphs).
     */
    suspend fun translateBatch(
        texts: List<String>,
        targetLanguage: String,
        sourceLanguage: String? = null,
    ): List<String>

    /**
     * Detect the language of the given text.
     * @return ISO 639-1 language code
     */
    suspend fun detectLanguage(text: String): String

    /**
     * Check if this service is available (e.g., network for LLM, models downloaded for ML Kit).
     */
    suspend fun isAvailable(): Boolean

    /**
     * Human-readable name of this translation provider.
     */
    val providerName: String
}

/**
 * Result of a translation operation with metadata.
 */
data class TranslationResult(
    val translatedText: String,
    val sourceLanguage: String,
    val targetLanguage: String,
    val provider: String,
    val characterCount: Int,
    val cached: Boolean = false,
)

class TranslationException(message: String, cause: Throwable? = null) : Exception(message, cause)
