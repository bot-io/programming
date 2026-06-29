package com.dualreader.app.domain.usecases

import com.dualreader.app.data.translation.ParagraphAligner
import com.dualreader.app.domain.repositories.TranslationCacheRepository
import com.dualreader.app.domain.services.BatchTranslationResult
import com.dualreader.app.domain.services.TranslationService
import com.dualreader.app.util.AppLogger
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
        return runCatching {
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
     * For multi-page batches (DR-013), we use a **marker-based** approach:
     * all paragraphs are joined with numbered markers (`⟦N⟧`) and sent as a
     * SINGLE translation request. This gives the LLM full cross-paragraph
     * context, producing higher-quality, more coherent translations.
     * The markers are then parsed from the output to split the result back
     * into individual paragraph translations.
     *
     * If the LLM strips the markers, we fall back to [ParagraphAligner]align
     * (proportional alignment on `\n\n` boundaries) using the same translated
     * text — no extra network call.
     *
     * Only if the marker-based call itself throws (network/rate-limit error)
     * do we fall back to the batch endpoint ([translatePages]).
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

        // Multiple pages — try marker-based batch (full paragraph context, DR-013)
        try {
            val markerResult = translateBatchWithMarkers(
                batch, targetLanguage, sourceLanguage,
                previousTranslation, serializedBookContext, forceRetranslate,
            )
            if (markerResult != null) return markerResult
        } catch (e: kotlinx.coroutines.CancellationException) {
            throw e
        } catch (e: Exception) {
            // Marker call failed (network/rate-limit) — fall through to batch endpoint
        }

        // Fallback: batch endpoint (fail fast, no individual fallback)
        val indexedPages = batch.map { IndexedValue(it.index, it.text) }
        val context = buildContext(null, previousTranslation)

        return translationService.translatePages(indexedPages, targetLanguage, sourceLanguage, context, serializedBookContext, forceRetranslate)
    }

    /**
     * Marker-based batch translation (DR-013).
     *
     * Joins all paragraphs with numbered markers into one text, sends a single
     * translation request (full context for the LLM), then splits the result
     * by markers back into individual paragraph translations.
     *
     * @return [BatchTranslationResult] on success, or `null` if the marker-based
     *         call fails with a non-cancellation exception (caller falls back to
     *         the batch endpoint).
     */
    private suspend fun translateBatchWithMarkers(
        batch: List<PageToTranslate>,
        targetLanguage: String,
        sourceLanguage: String?,
        previousTranslation: String?,
        serializedBookContext: SerializedBookContext?,
        forceRetranslate: Boolean,
    ): BatchTranslationResult? {
        val markedText = ParagraphAligner.injectMarkers(batch.map { it.text })
        val context = buildContext(null, previousTranslation)

        val translated = translationService.translate(
            text = markedText,
            targetLanguage = targetLanguage,
            sourceLanguage = sourceLanguage,
            context = context,
            bookContext = serializedBookContext,
            skipCache = forceRetranslate,
        )

        // If the translate call returned blank/empty text, fall back to batch endpoint
        if (translated.isBlank()) return null

        // Try to split by markers first (exact paragraph alignment)
        val split = ParagraphAligner.extractByMarkers(translated, batch.size)

        val results: Map<Int, String> = if (split != null && split.size == batch.size) {
            // Markers preserved — exact 1:1 alignment
            batch.mapIndexed { i, page -> page.index to split[i] }.toMap()
        } else {
            // Markers stripped — proportional alignment on the returned text
            AppLogger.i("[DR-013] Markers not preserved, falling back to proportional alignment")
            // DR-092: Strip residual markers before alignment so they don't leak into results
            val cleanedTranslated = ParagraphAligner.stripMarkers(translated)
            val origJoined = batch.joinToString("\n\n") { it.text }
            val aligned = ParagraphAligner.align(origJoined, cleanedTranslated)
            batch.mapIndexed { i, page ->
                page.index to (aligned.getOrNull(i)?.second ?: "")
            }.filter { it.second.isNotBlank() }.toMap()
        }

        // DR-092: Safety net — strip any residual markers from ALL results before returning.
        // Belt-and-suspenders: even if extractByMarkers or align missed an edge case,
        // this guarantees no ⟦N⟧ artifacts reach the user.
        val sanitizedResults = results.mapValues { (_, text) ->
            ParagraphAligner.stripMarkers(text)
        }.filterValues { it.isNotBlank() }

        // If no usable results (e.g., translate returned empty/unparseable text),
        // fall back to the batch endpoint
        if (sanitizedResults.isEmpty()) return null

        return BatchTranslationResult(sanitizedResults, translationService.providerName)
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
