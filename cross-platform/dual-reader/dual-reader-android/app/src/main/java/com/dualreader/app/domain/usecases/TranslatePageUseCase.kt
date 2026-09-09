package com.dualreader.app.domain.usecases

import com.dualreader.app.data.translation.ParagraphAligner
import com.dualreader.app.domain.repositories.TranslationCacheRepository
import com.dualreader.app.domain.services.BatchTranslationResult
import com.dualreader.app.domain.services.TranslationService
import com.dualreader.app.util.AppLogger
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive
import javax.inject.Inject

/** Serialized book context string sent to the Worker. */
data class SerializedBookContext(
    val title: String,
    val author: String,
    val openingText: String,
)

/**
 * Context-aware translation use case with local caching and batch optimization.
 *
 * - Checks the local cache before calling any translation service
 * - Stores every successful translation in the cache
 * - Re-translations overwrite the cache entry (model upgrade → better quality)
 * - Sends up to [BATCH_SIZE] pages per API call for efficiency
 * - Fails fast if batch endpoint fails (no individual fallback)
 */
class TranslatePageUseCase @Inject constructor(
    private val translationService: TranslationService,
    private val cacheRepository: TranslationCacheRepository,
) {
    companion object {
        /** Number of pages to translate in a single API call. */
        const val BATCH_SIZE = 15

        /** Maximum total chars per batch to stay within API limits. */
        private const val MAX_BATCH_CHARS = 30000

        /** Minimum delay between batch requests to respect worker rate limits. */
        private const val BATCH_DELAY_MS = 200L

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
        bookContext: BookContext? = null,
    ): Result<String> {
        val result = runCatching {
            // Check cache first (unless forced retranslate)
            if (!forceRetranslate) {
                val cached = cacheRepository.get(text, sourceLanguage, targetLanguage)
                if (cached != null) return Result.success(cached)
            }

            // Cache miss or forced — call the service
            val context = buildContext(previousOriginal, previousTranslation)
            val serializedBookCtx = bookContext?.let { serializeBookContext(it) }
            val translated = translationService.translate(
                text = text,
                targetLanguage = targetLanguage,
                sourceLanguage = sourceLanguage,
                context = context,
                bookContext = serializedBookCtx,
                skipCache = forceRetranslate,
            )

            // Store in cache (overwrites if exists = model upgrade)
            cacheRepository.put(text, sourceLanguage, targetLanguage, translated)

            translated
        }

        // DR-173: Rethrow CancellationException to preserve structured concurrency
        result.exceptionOrNull()?.let { if (it is CancellationException) throw it }
        return result
    }

    /**
     * Translate multiple pages with context continuity and batch optimization.
     *
     * Groups up to [BATCH_SIZE] uncached pages per API call.
     * Skips pages that are already cached (unless forceRetranslate).
     * Fails fast if the batch endpoint fails (no individual fallback).
     */
    suspend fun translateBatchWithContext(
        pages: List<PageToTranslate>,
        targetLanguage: String,
        sourceLanguage: String? = null,
        onPageTranslated: (index: Int, translation: String) -> Unit = { _, _ -> },
        forceRetranslate: Boolean = false,
        bookContext: BookContext? = null,
    ): Result<BatchTranslationResult> {
        val results = mutableMapOf<Int, String>()
        var lastTranslation: String? = null
        var lastModel = "unknown"
        val serializedBookCtx = bookContext?.let { serializeBookContext(it) }

        try {
            var i = 0
            while (i < pages.size) {
                // Check for cancellation
                currentCoroutineContext().ensureActive()

                val page = pages[i]

                // Check cache first
                if (!forceRetranslate) {
                    val cached = cacheRepository.get(page.text, sourceLanguage, targetLanguage)
                    if (cached != null) {
                        // DR-092: Strip markers from cached results too (old cache entries may have them)
                        val cleanCached = ParagraphAligner.stripMarkers(cached)
                        results[page.index] = cleanCached
                        onPageTranslated(page.index, cleanCached)
                        lastTranslation = cleanCached
                        i++
                        continue
                    }
                }

                // Collect a batch of uncached pages starting from current position
                val batch = collectBatch(pages, i, sourceLanguage, targetLanguage, forceRetranslate)
                if (batch.isEmpty()) {
                    i++
                    continue
                }

                // Try batch translation
                val batchResult = translateBatch(batch, targetLanguage, sourceLanguage, lastTranslation, serializedBookCtx, forceRetranslate)
                lastModel = batchResult.model

                // Process results — use a lookup map for O(1) page text access
                val pageByTextIndex = pages.associateBy { it.index }
                for ((pageIndex, translation) in batchResult.translations) {
                    // DR-092: Strip any residual markers from batch endpoint results too
                    val cleanTranslation = ParagraphAligner.stripMarkers(translation)
                    results[pageIndex] = cleanTranslation
                    onPageTranslated(pageIndex, cleanTranslation)
                    lastTranslation = cleanTranslation

                    // Cache each result (O(1) lookup instead of pages.find)
                    val pageText = pageByTextIndex[pageIndex]?.text ?: continue
                    cacheRepository.put(pageText, sourceLanguage, targetLanguage, translation)
                }

                i += batch.size

                // Small delay between batches
                if (i < pages.size) {
                    kotlinx.coroutines.delay(BATCH_DELAY_MS)
                }
            }
            return Result.success(BatchTranslationResult(results, lastModel))
        } catch (e: kotlinx.coroutines.CancellationException) {
            throw e // Propagate cancellation
        } catch (e: Exception) {
            return Result.failure(e)
        }
    }

    /**
     * Collect a batch of consecutive uncached pages for batch translation.
     * Returns up to [BATCH_SIZE] pages, respecting total char limits.
     */
    private suspend fun collectBatch(
        pages: List<PageToTranslate>,
        startIndex: Int,
        sourceLanguage: String?,
        targetLanguage: String,
        forceRetranslate: Boolean,
    ): List<PageToTranslate> {
        val batch = mutableListOf<PageToTranslate>()
        var totalChars = 0

        for (j in startIndex until minOf(startIndex + BATCH_SIZE, pages.size)) {
            val page = pages[j]

            // Skip cached pages (they'll be handled in the main loop)
            if (!forceRetranslate) {
                val cached = cacheRepository.get(page.text, sourceLanguage, targetLanguage)
                if (cached != null) break // Stop batch at cached boundary
            }

            if (totalChars + page.text.length > MAX_BATCH_CHARS) break
            batch.add(page)
            totalChars += page.text.length
        }

        return batch
    }

    /**
     * Translate a batch of pages.
     *
     * DR-263: Uses the **array-based** batch endpoint ([translatePages]) which
     * sends pages as a JSON array and receives index-keyed translations back.
     * This preserves exact 1:1 segment alignment for BOTH ML Kit and cloud —
     * no markers, no stitching, no proportional fallback needed.
     *
     * Previous marker-based approach (DR-013) was fragile: the LLM/ML Kit
     * could strip or merge markers, causing translation segments to mismatch
     * their originals. The array endpoint eliminates this class of bugs.
     *
     * For single-page batches, an individual call is used (with context).
     */
    private suspend fun translateBatch(
        batch: List<PageToTranslate>,
        targetLanguage: String,
        sourceLanguage: String?,
        previousTranslation: String?,
        serializedBookContext: SerializedBookContext? = null,
        forceRetranslate: Boolean = false,
    ): BatchTranslationResult {
        if (batch.isEmpty()) return BatchTranslationResult(emptyMap())

        // Single page — use individual call with context
        if (batch.size == 1) {
            val page = batch[0]
            val context = buildContext(null, previousTranslation)
            val result = translationService.translate(
                text = page.text,
                targetLanguage = targetLanguage,
                sourceLanguage = sourceLanguage,
                context = context,
                bookContext = serializedBookContext,
                skipCache = forceRetranslate,
            )
            return BatchTranslationResult(mapOf(page.index to result), translationService.providerName)
        }

        // Multiple pages — use array-based batch endpoint (DR-263)
        val indexedPages = batch.map { IndexedValue(it.index, it.text) }
        val context = buildContext(null, previousTranslation)

        return translationService.translatePages(
            indexedPages, targetLanguage, sourceLanguage,
            context, serializedBookContext, forceRetranslate,
        )
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
        val result = runCatching {
            translationService.translateBatch(
                texts = texts,
                targetLanguage = targetLanguage,
                sourceLanguage = sourceLanguage,
            )
        }

        // DR-173: Rethrow CancellationException to preserve structured concurrency
        result.exceptionOrNull()?.let { if (it is CancellationException) throw it }
        return result
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

    /**
     * Serialize a [BookContext] into a compact format for the Worker.
     */
    private fun serializeBookContext(ctx: BookContext): SerializedBookContext {
        return SerializedBookContext(
            title = ctx.title,
            author = ctx.author,
            openingText = ctx.openingText,
        )
    }
}

/**
 * Represents a page to be translated with its index and original text.
 */
data class PageToTranslate(
    val index: Int,
    val text: String,
)
