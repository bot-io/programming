package com.dualreader.app.domain.usecases

import com.dualreader.app.domain.services.TranslationService
import javax.inject.Inject

/**
 * Translate a page of book text.
 *
 * Lesson from Flutter: translating sentence-by-sentence with ML Kit
 * produced terrible results. The new approach translates entire
 * paragraphs/pages at once with LLM, preserving context and style.
 *
 * Translation results are cached at the data layer — this use case
 * doesn't handle caching directly.
 */
class TranslatePageUseCase @Inject constructor(
    private val translationService: TranslationService,
) {
    suspend operator fun invoke(
        text: String,
        targetLanguage: String,
        sourceLanguage: String? = null,
    ): Result<String> {
        return runCatching {
            translationService.translate(
                text = text,
                targetLanguage = targetLanguage,
                sourceLanguage = sourceLanguage,
            )
        }
    }

    /**
     * Translate multiple pages in a single batch.
     * More efficient for LLM providers (fewer API calls).
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
}
