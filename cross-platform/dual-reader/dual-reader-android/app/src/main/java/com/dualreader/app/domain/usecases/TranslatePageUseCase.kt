package com.dualreader.app.domain.usecases

import com.dualreader.app.domain.services.TranslationService
import javax.inject.Inject

/**
 * Context-aware translation use case.
 *
 * Sends surrounding pages as context so the LLM can:
 * - Resolve pronouns and references across page boundaries
 * - Maintain consistent tone, style, and character names
 * - Avoid repeating or contradicting previous translations
 *
 * For batch mode (Translate All), groups pages into batches of [BATCH_SIZE]
 * and carries forward the last translated paragraph as context for the next batch.
 */
class TranslatePageUseCase @Inject constructor(
    private val translationService: TranslationService,
) {
    companion object {
        /** Minimum delay between batch requests to respect worker rate limits. */
        private const val BATCH_DELAY_MS = 500L

        /** Maximum context length (chars) to keep requests small. */
        private const val MAX_CONTEXT_CHARS = 300
    }

    /**
     * Translate a single page with optional surrounding context.
     *
     * @param text The page text to translate.
     * @param targetLanguage ISO 639-1 target language code.
     * @param sourceLanguage Optional source language (null = auto-detect).
     * @param previousOriginal Text from the previous page (original language).
     * @param previousTranslation Translation of the previous page (if available).
     */
    suspend operator fun invoke(
        text: String,
        targetLanguage: String,
        sourceLanguage: String? = null,
        previousOriginal: String? = null,
        previousTranslation: String? = null,
    ): Result<String> {
        return runCatching {
            val context = buildContext(previousOriginal, previousTranslation)
            translationService.translate(
                text = text,
                targetLanguage = targetLanguage,
                sourceLanguage = sourceLanguage,
                context = context,
            )
        }
    }

    /**
     * Translate multiple pages with context continuity.
     *
     * Translates pages one at a time, passing the previous translation as context.
     * This keeps requests small and avoids timeouts from oversized payloads.
     */
    suspend fun translateBatchWithContext(
        pages: List<PageToTranslate>,
        targetLanguage: String,
        sourceLanguage: String? = null,
        onPageTranslated: (index: Int, translation: String) -> Unit = { _, _ -> },
    ): Result<Map<Int, String>> {
        return runCatching {
            val results = mutableMapOf<Int, String>()
            var lastTranslation: String? = null

            for ((i, page) in pages.withIndex()) {
                val prevOriginal = if (i > 0) pages[i - 1].text else null

                val result = invoke(
                    text = page.text,
                    targetLanguage = targetLanguage,
                    sourceLanguage = sourceLanguage,
                    previousOriginal = prevOriginal,
                    previousTranslation = lastTranslation,
                ).getOrThrow()

                results[page.index] = result
                onPageTranslated(page.index, result)
                lastTranslation = result
            }

            results
        }
    }

    /**
     * Legacy batch method — translates pages individually without context.
     * Kept for backward compatibility.
     */
    suspend fun translateBatch(
        texts: List<String>,
        targetLanguage: String,
        sourceLanguage: String? = null,
    ): Result<List<String>> {
        return runCatching {
            translationService.translateBatch(
                texts = texts,
                targetLanguage = targetLanguage,
                sourceLanguage = sourceLanguage,
            )
        }
    }

    /**
     * Build a context string from previous page info.
     * This tells the LLM what came before so it can maintain continuity.
     */
    private fun buildContext(
        previousOriginal: String?,
        previousTranslation: String?,
    ): String? {
        if (previousTranslation == null && previousOriginal == null) return null

        return buildString {
            append("Previous context (do NOT translate, use only for understanding):\n")
            if (previousTranslation != null) {
                append(previousTranslation.take(MAX_CONTEXT_CHARS))
                if (previousTranslation.length > MAX_CONTEXT_CHARS) append("...")
                append("\n")
            }
            if (previousOriginal != null) {
                append(previousOriginal.take(MAX_CONTEXT_CHARS))
                if (previousOriginal.length > MAX_CONTEXT_CHARS) append("...")
                append("\n")
            }
        }
    }
}

/**
 * Represents a page to be translated with its index and original text.
 */
data class PageToTranslate(
    val index: Int,
    val text: String,
)
