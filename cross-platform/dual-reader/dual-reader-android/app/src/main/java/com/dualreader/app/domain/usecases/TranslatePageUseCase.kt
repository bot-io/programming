package com.dualreader.app.domain.usecases

import com.dualreader.app.domain.repositories.TranslationCacheRepository
import com.dualreader.app.domain.services.TranslationService
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive
import javax.inject.Inject

/**
 * Context-aware translation use case with local caching.
 *
 * - Checks the local cache before calling any translation service
 * - Stores every successful translation in the cache
 * - Re-translations overwrite the cache entry (model upgrade → better quality)
 * - Sends surrounding pages as context for better quality
 */
class TranslatePageUseCase @Inject constructor(
    private val translationService: TranslationService,
    private val cacheRepository: TranslationCacheRepository,
) {
    companion object {
        /** Minimum delay between batch requests to respect worker rate limits. */
        private const val BATCH_DELAY_MS = 500L

        /** Maximum context length (chars) to keep requests small. */
        private const val MAX_CONTEXT_CHARS = 300
    }

    /**
     * Translate a single page with optional surrounding context.
     * Uses cached translation if available, otherwise calls the service and caches the result.
     */
    suspend operator fun invoke(
        text: String,
        targetLanguage: String,
        sourceLanguage: String? = null,
        previousOriginal: String? = null,
        previousTranslation: String? = null,
        forceRetranslate: Boolean = false,
    ): Result<String> {
        return runCatching {
            // Check cache first (unless forced retranslate)
            if (!forceRetranslate) {
                val cached = cacheRepository.get(text, sourceLanguage, targetLanguage)
                if (cached != null) return Result.success(cached)
            }

            // Cache miss or forced — call the service
            val context = buildContext(previousOriginal, previousTranslation)
            val translated = translationService.translate(
                text = text,
                targetLanguage = targetLanguage,
                sourceLanguage = sourceLanguage,
                context = context,
            )

            // Store in cache (overwrites if exists = model upgrade)
            cacheRepository.put(text, sourceLanguage, targetLanguage, translated)

            translated
        }
    }

    /**
     * Translate multiple pages with context continuity.
     *
     * Translates pages one at a time, passing the previous translation as context.
     * Skips pages that are already cached (unless forceRetranslate).
     */
    suspend fun translateBatchWithContext(
        pages: List<PageToTranslate>,
        targetLanguage: String,
        sourceLanguage: String? = null,
        onPageTranslated: (index: Int, translation: String) -> Unit = { _, _ -> },
        forceRetranslate: Boolean = false,
    ): Result<Map<Int, String>> {
        val results = mutableMapOf<Int, String>()
        var lastTranslation: String? = null

        try {
            for ((i, page) in pages.withIndex()) {
                // Check for cancellation before each page
                currentCoroutineContext().ensureActive()

                // Check cache first
                if (!forceRetranslate) {
                    val cached = cacheRepository.get(page.text, sourceLanguage, targetLanguage)
                    if (cached != null) {
                        results[page.index] = cached
                        onPageTranslated(page.index, cached)
                        lastTranslation = cached
                        continue
                    }
                }

                val prevOriginal = if (i > 0) pages[i - 1].text else null

                val result = invoke(
                    text = page.text,
                    targetLanguage = targetLanguage,
                    sourceLanguage = sourceLanguage,
                    previousOriginal = prevOriginal,
                    previousTranslation = lastTranslation,
                    forceRetranslate = true, // Already checked cache above
                ).getOrThrow()

                results[page.index] = result
                onPageTranslated(page.index, result)
                lastTranslation = result
            }
            return Result.success(results)
        } catch (e: kotlinx.coroutines.CancellationException) {
            throw e // Propagate cancellation
        } catch (e: Exception) {
            return Result.failure(e)
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
