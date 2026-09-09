package com.dualreader.app.data.translation

import com.dualreader.app.domain.services.TranslationException
import com.dualreader.app.domain.services.BatchTranslationResult
import com.dualreader.app.domain.services.TranslationService
import com.dualreader.app.domain.usecases.SerializedBookContext
import com.dualreader.app.util.AppLogger
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import javax.inject.Inject
import javax.inject.Named
import javax.inject.Singleton
import kotlin.collections.IndexedValue

/**
 * Local-first translation service with background cloud upgrade.
 *
 * Tier 1: ML Kit on-device (~0.5s, instant result)
 * Tier 2: Cloud proxy background upgrade (Gemini/GLM, better quality)
 * Tier 3: Cloud direct fallback (if ML Kit model unavailable)
 *
 * User sees an instant ML Kit translation, then it gets silently upgraded
 * to cloud quality when the background request completes.
 */
@Singleton
class FallbackTranslationService @Inject constructor(
    @Named("cloud") private val cloudService: TranslationService,
    @Named("mlkit") private val mlKitService: TranslationService,
) : TranslationService {

    /**
     * DR-262: Dynamic provider name — reflects what actually produced the
     * most recent synchronous result. After ML Kit → "Local", after cloud →
     * the cloud service's provider name (e.g. "Cloud").
     *
     * This fixes re-translate: the old static "Local" caused grade protection
     * to block cloud results from replacing existing translations.
     */
    override val providerName: String get() = lastSyncModel

    private var lastSyncModel: String = "Local"

    companion object {
        /** Max chars per chunk sent to the API. Keeps requests small to avoid timeouts. */
        private const val MAX_CHUNK_SIZE = 1500

        /** Test override for the upgrade dispatcher. Set before creating the service. */
        @Volatile
        internal var testUpgradeDispatcher: CoroutineDispatcher? = null
    }

    /**
     * Background scope for cloud upgrade jobs. Uses SupervisorJob so one failed
     * upgrade doesn't cancel others. Lives for the lifetime of this Singleton.
     */
    private val upgradeDispatcher: CoroutineDispatcher
        get() = testUpgradeDispatcher ?: Dispatchers.IO

    private val upgradeScope = CoroutineScope(SupervisorJob())

    /**
     * Called when a cloud upgrade completes. Set by the ViewModel to receive
     * upgraded translations and replace ML Kit results in the UI.
     *
     * Parameters: (originalText, upgradedTranslation, targetLanguage)
     */
    @Volatile
    var cloudUpgradeCallback: ((suspend (String, String, String) -> Unit))? = null

    /**
     * Called when a cloud upgrade STARTS for a given original text.
     * Lets the UI show a spinner while the upgrade is in flight.
     */
    @Volatile
    var cloudUpgradeStartedCallback: ((String) -> Unit)? = null

    /**
     * Called when a cloud upgrade FAILS for a given original text.
     * Lets the UI stop the spinner and keep the ML Kit result.
     */
    @Volatile
    var cloudUpgradeFailedCallback: ((String) -> Unit)? = null

    // ── translate ──────────────────────────────────────────────────────────────

    override suspend fun translate(
        text: String,
        targetLanguage: String,
        sourceLanguage: String?,
        context: String?,
        bookContext: SerializedBookContext?,
        skipCache: Boolean,
    ): String {
        // If text is long, split into paragraphs and translate each
        val chunks = splitIntoChunks(text)
        if (chunks.size <= 1) {
            return translateSingle(text, targetLanguage, sourceLanguage, context, bookContext, skipCache)
        }

        // For multi-chunk: pass context only to first chunk (most relevant)
        val results = chunks.mapIndexed { index, chunk ->
            if (index > 0) delay(300L)
            val chunkContext = if (index == 0) context else null
            translateSingle(chunk, targetLanguage, sourceLanguage, chunkContext, bookContext, skipCache)
        }
        return results.joinToString("\n\n")
    }

    /**
     * Local-first strategy: ML Kit instant → cloud background upgrade.
     *
     * Tier 1: ML Kit (on-device, ~0.5s) — user sees result immediately
     * Tier 2: Cloud (background upgrade — better quality, replaces ML Kit when done)
     * Tier 3: Cloud direct fallback (if ML Kit model unavailable)
     *
     * If [cloudUpgradeCallback] is provided, cloud translation runs in the
     * caller's scope and the callback fires when the upgrade completes.
     */
    private suspend fun translateSingle(
        text: String,
        targetLanguage: String,
        sourceLanguage: String?,
        context: String? = null,
        bookContext: SerializedBookContext? = null,
        skipCache: Boolean = false,
    ): String {
        // DR-253: When re-translating (skipCache=true), skip ML Kit and go straight to cloud
        // so the user actually gets a fresh, higher-quality translation instead of the same
        // cached ML Kit result.
        if (!skipCache) {
            // Tier 1: ML Kit on-device (instant)
            try {
                val result = mlKitService.translate(text, targetLanguage, sourceLanguage)
                AppLogger.d("ML Kit translation succeeded (${result.length} chars)")
                lastSyncModel = "Local" // DR-262

                // DR-262: Background cloud upgrade (fire-and-forget, caller handles replacement)
                // DR-141: Capture callbacks in local variables to avoid race condition
                val callback = cloudUpgradeCallback
                val startedCallback = cloudUpgradeStartedCallback
                val failedCallback = cloudUpgradeFailedCallback
                if (callback != null) {
                    upgradeScope.launch(upgradeDispatcher) {
                        startedCallback?.invoke(text)
                        try {
                            val cloudResult = cloudService.translate(
                                text, targetLanguage, sourceLanguage, context, bookContext, skipCache
                            )
                            AppLogger.d("Cloud upgrade succeeded (${cloudResult.length} chars), notifying callback")
                            callback(text, cloudResult, targetLanguage)
                        } catch (e: CancellationException) {
                            failedCallback?.invoke(text)
                            // scope cancelled — stop upgrade
                        } catch (e: Exception) {
                            failedCallback?.invoke(text)
                            AppLogger.w("Cloud upgrade failed: ${e.message} — keeping ML Kit result")
                        }
                    }
                }

                return result
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                AppLogger.w("ML Kit failed: ${e.message}, trying cloud directly")
            }
        }

        // Tier 3: Cloud direct fallback (ML Kit model unavailable OR re-translate)
        var cloudError: String? = null
        try {
            val result = cloudService.translate(text, targetLanguage, sourceLanguage, context, bookContext, skipCache)
            AppLogger.d("Cloud translation succeeded (${result.length} chars)")
            lastSyncModel = cloudService.providerName // DR-262: report actual cloud model

            // DR-147: Invoke callback when cloud fallback succeeds (same as Tier 1).
            // This was accidentally dropped in the v1.0.98-101 rewrites — restored.
            val callback = cloudUpgradeCallback
            if (callback != null) {
                upgradeScope.launch(upgradeDispatcher) {
                    try {
                        callback(text, result, targetLanguage)
                    } catch (e: CancellationException) {
                        // scope cancelled — stop
                    } catch (e: Exception) {
                        AppLogger.w("Cloud fallback callback failed: ${e.message}")
                    }
                }
            }
            return result
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            cloudError = e.message ?: "Unknown error"
            AppLogger.w("Cloud also failed: $cloudError")
        }

        throw TranslationException(
            "Translation failed. Both ML Kit and cloud are unavailable.\n" +
            "Cloud: $cloudError"
        )
    }

    // ── translateBatch ─────────────────────────────────────────────────────────

    override suspend fun translateBatch(
        texts: List<String>,
        targetLanguage: String,
        sourceLanguage: String?,
    ): List<String> {
        if (texts.isEmpty()) return emptyList()
        return texts.map { translate(it, targetLanguage, sourceLanguage) }
    }

    // ── translatePages (batch optimization) ────────────────────────────────────

    override suspend fun translatePages(
        pages: List<IndexedValue<String>>,
        targetLanguage: String,
        sourceLanguage: String?,
        context: String?,
        bookContext: SerializedBookContext?,
        skipCache: Boolean,
    ): BatchTranslationResult {
        // DR-253: When re-translating (skipCache=true), go straight to cloud, skip ML Kit
        if (skipCache) {
            lastSyncModel = cloudService.providerName // DR-262
            return cloudService.translatePages(pages, targetLanguage, sourceLanguage, context, bookContext, skipCache)
        }

        // Tier 1: ML Kit for all pages (instant, on-device)
        val mlKitResults = mutableMapOf<Int, String>()
        for (page in pages) {
            try {
                mlKitResults[page.index] = mlKitService.translate(page.value, targetLanguage, sourceLanguage)
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                AppLogger.w("ML Kit failed for page ${page.index}: ${e.message}")
            }
        }

        // DR-054: Check if all pages succeeded
        if (mlKitResults.size == pages.size) {
            // All pages translated by ML Kit
            AppLogger.i("translatePages: ML Kit succeeded for all ${pages.size} pages")
            lastSyncModel = "Local" // DR-262

            // Tier 2: Background cloud upgrade using array-based batch endpoint
            // DR-263: translatePages sends a JSON array, receives index-keyed results —
            // exact 1:1 alignment, no markers or stitching.
            if (cloudUpgradeCallback != null) {
                triggerCloudUpgradeForPages(
                    pages = pages,
                    targetLanguage = targetLanguage,
                    sourceLanguage = sourceLanguage,
                    context = context,
                    bookContext = bookContext,
                )
            }

            return BatchTranslationResult(mlKitResults.toMap(), mlKitService.providerName)
        }

        // DR-054: ML Kit failed for some or all pages — try cloud batch
        val failedPages = pages.filter { it.index !in mlKitResults }
        if (mlKitResults.isEmpty()) {
            AppLogger.w("ML Kit unavailable for all pages, trying cloud batch directly")
        } else {
            AppLogger.i("translatePages: ML Kit succeeded for ${mlKitResults.size}/${pages.size} pages, trying cloud for the rest")
        }

        try {
            val cloudResult = cloudService.translatePages(failedPages, targetLanguage, sourceLanguage, context, bookContext, skipCache)

            // Combine results
            val allResults = mlKitResults.toMutableMap()
            allResults.putAll(cloudResult.translations)

            if (allResults.size < pages.size) {
                val missingIndices = pages.map { it.index }.filter { it !in allResults }
                throw TranslationException("Cloud returned incomplete results: missing ${missingIndices.size} pages (indices $missingIndices)")
            }

            // DR-147: Invoke callback for cloud-translated pages (Tier 3 fallback).
            // Restored — was accidentally dropped in the v1.0.98-101 rewrites.
            val callback = cloudUpgradeCallback
            if (callback != null) {
                val pageByIndex = pages.associateBy { it.index }
                upgradeScope.launch(upgradeDispatcher) {
                    for ((pageIndex, translation) in cloudResult.translations) {
                        val originalText = pageByIndex[pageIndex]?.value ?: continue
                        try {
                            callback(originalText, translation, targetLanguage)
                        } catch (e: CancellationException) {
                            return@launch
                        } catch (e: Exception) {
                            AppLogger.w("Cloud fallback callback failed for page $pageIndex: ${e.message}")
                        }
                    }
                }
            }

            return BatchTranslationResult(allResults, cloudResult.model)
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            if (mlKitResults.isEmpty()) {
                throw TranslationException("Both ML Kit and cloud translation failed: ${e.message}")
            } else {
                val successCount = mlKitResults.size
                val totalCount = pages.size
                throw TranslationException("Cloud fallback failed after ML Kit success for $successCount/$totalCount pages: ${e.message}")
            }
        }
    }

    // ── detectLanguage ─────────────────────────────────────────────────────────

    override suspend fun detectLanguage(text: String): String {
        try {
            return cloudService.detectLanguage(text)
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            AppLogger.w("Cloud language detection failed: ${e.message}, falling back to ML Kit")
        }
        return mlKitService.detectLanguage(text)
    }

    // ── isAvailable ────────────────────────────────────────────────────────────

    override suspend fun isAvailable(): Boolean = true

    // ── Internal ───────────────────────────────────────────────────────────────

    fun cleanup() {
        upgradeScope.cancel()
        cloudUpgradeCallback = null
        cloudUpgradeStartedCallback = null
        cloudUpgradeFailedCallback = null
    }

    /**
     * DR-263: Explicitly trigger background cloud upgrades for a list of pages.
     *
     * Uses the **array-based** batch endpoint ([cloudService.translatePages])
     * which sends pages as a JSON array and receives index-keyed translations.
     * This preserves exact 1:1 segment alignment without markers or stitching.
     *
     * Previous marker-based approach was fragile: the LLM could strip or merge
     * markers, causing segments to mismatch. The array endpoint eliminates this.
     *
     * Grade protection is handled by the cloudUpgradeCallback in the ViewModel.
     */
    fun triggerCloudUpgradeForPages(
        pages: List<IndexedValue<String>>,
        targetLanguage: String,
        sourceLanguage: String?,
        context: String? = null,
        bookContext: SerializedBookContext? = null,
    ) {
        val callback = cloudUpgradeCallback
        val startedCallback = cloudUpgradeStartedCallback
        val failedCallback = cloudUpgradeFailedCallback
        if (callback == null) {
            AppLogger.w("triggerCloudUpgradeForPages: no callback registered, skipping")
            return
        }

        if (pages.isEmpty()) return

        upgradeScope.launch(upgradeDispatcher) {
            // Notify start for all pages
            for (page in pages) {
                startedCallback?.invoke(page.value)
            }

            try {
                // DR-263: Use array-based batch endpoint — no markers, no stitching.
                // The server receives a JSON array of {index, text} and returns
                // a JSON array of {index, translatedText}. Exact 1:1 alignment.
                val cloudResult = cloudService.translatePages(
                    pages, targetLanguage, sourceLanguage, context, bookContext, false
                )

                // Build original-text → translated-text map for callbacks
                val pageByIndex = pages.associateBy { it.index }
                for ((pageIndex, translation) in cloudResult.translations) {
                    val originalText = pageByIndex[pageIndex]?.value
                    if (originalText != null && translation.isNotBlank()) {
                        callback(originalText, translation, targetLanguage)
                    }
                }

                // Handle pages that didn't get a result
                val missingIndices = pages.map { it.index } - cloudResult.translations.keys
                for (missingIndex in missingIndices) {
                    val originalText = pageByIndex[missingIndex]?.value
                    if (originalText != null) {
                        failedCallback?.invoke(originalText)
                    }
                }

                AppLogger.i("triggerCloudUpgradeForPages: ${cloudResult.translations.size}/${pages.size} pages succeeded")
            } catch (e: CancellationException) {
                for (page in pages) failedCallback?.invoke(page.value)
            } catch (e: Exception) {
                AppLogger.w("triggerCloudUpgradeForPages failed: ${e.message}")
                for (page in pages) failedCallback?.invoke(page.value)
            }
        }
    }

    /**
     * Split text into chunks at paragraph boundaries, each ≤ [MAX_CHUNK_SIZE] chars.
     */
    internal fun splitIntoChunks(text: String): List<String> {
        if (text.length <= MAX_CHUNK_SIZE) return listOf(text)

        val paragraphs = text.split(Regex("\\n\\s*\\n")).filter { it.isNotBlank() }
        val chunks = mutableListOf<String>()
        val currentChunk = StringBuilder()
        var currentSize = 0

        for (paragraph in paragraphs) {
            val pSize = paragraph.length
            if (currentSize + pSize > MAX_CHUNK_SIZE && currentChunk.isNotEmpty()) {
                chunks.add(currentChunk.toString().trim())
                currentChunk.clear()
                currentSize = 0
            }
            if (currentChunk.isNotEmpty()) currentChunk.append("\n\n")
            currentChunk.append(paragraph)
            currentSize += pSize
        }
        if (currentChunk.isNotEmpty()) {
            chunks.add(currentChunk.toString().trim())
        }

        return chunks
    }
}
