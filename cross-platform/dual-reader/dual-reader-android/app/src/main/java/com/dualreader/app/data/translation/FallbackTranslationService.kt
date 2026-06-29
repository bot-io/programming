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

    override val providerName: String = "ML Kit → Cloud Upgrade"

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
        // Tier 1: ML Kit on-device (instant)
        try {
            val result = mlKitService.translate(text, targetLanguage, sourceLanguage)
            AppLogger.d("ML Kit translation succeeded (${result.length} chars)")

            // Tier 2: Background cloud upgrade (fire-and-forget, caller handles replacement)
            // DR-141: Capture callback in local variable to avoid race condition
            val callback = cloudUpgradeCallback
            if (callback != null) {
                upgradeScope.launch(upgradeDispatcher) {
                    try {
                        val cloudResult = cloudService.translate(
                            text, targetLanguage, sourceLanguage, context, bookContext, skipCache
                        )
                        AppLogger.d("Cloud upgrade succeeded (${cloudResult.length} chars), notifying callback")
                        callback(text, cloudResult, targetLanguage)
                    } catch (e: CancellationException) {
                        // scope cancelled — stop upgrade
                    } catch (e: Exception) {
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

        // Tier 3: Cloud direct fallback (ML Kit model unavailable)
        var cloudError: String? = null
        try {
            val result = cloudService.translate(text, targetLanguage, sourceLanguage, context, bookContext, skipCache)
            AppLogger.d("Cloud translation succeeded (${result.length} chars)")
            // DR-147: Invoke callback when cloud fallback succeeds (same as Tier 1)
            val callback = cloudUpgradeCallback
            if (callback != null) {
                upgradeScope.launch(upgradeDispatcher) {
                    try {
                        callback(text, result, targetLanguage)
                    } catch (e: CancellationException) {
                        // scope cancelled
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

        if (mlKitResults.isNotEmpty()) {
            AppLogger.i("translatePages: ML Kit instant result for ${mlKitResults.size}/${pages.size} pages")

            // Tier 2: Background cloud upgrade for each page
            // DR-141: Capture callback in local variable to avoid race condition
            val callback = cloudUpgradeCallback
            if (callback != null) {
                for (page in pages) {
                    upgradeScope.launch(upgradeDispatcher) {
                        try {
                            val cloudResult = cloudService.translate(
                                page.value, targetLanguage, sourceLanguage, context, bookContext, skipCache
                            )
                            callback(page.value, cloudResult, targetLanguage)
                        } catch (e: CancellationException) {
                            // scope cancelled
                        } catch (e: Exception) {
                            AppLogger.w("Cloud upgrade failed for page ${page.index}: ${e.message}")
                        }
                    }
                }
            }

            return BatchTranslationResult(mlKitResults.toMap(), mlKitService.providerName)
        }

        // Tier 3: ML Kit fully unavailable — try cloud batch directly
        AppLogger.w("ML Kit unavailable for all pages, trying cloud batch directly")
        try {
            val batchResult = cloudService.translatePages(pages, targetLanguage, sourceLanguage, context, bookContext, skipCache)
            // DR-147: Invoke callback for each page when cloud batch succeeds (same as Tier 1)
            val callback = cloudUpgradeCallback
            if (callback != null) {
                for (page in pages) {
                    upgradeScope.launch(upgradeDispatcher) {
                        try {
                            val translation = batchResult.translations[page.index]
                            if (translation != null) {
                                callback(page.value, translation, targetLanguage)
                            }
                        } catch (e: CancellationException) {
                            // scope cancelled
                        } catch (e: Exception) {
                            AppLogger.w("Cloud fallback callback failed for page ${page.index}: ${e.message}")
                        }
                    }
                }
            }
            return batchResult
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            throw TranslationException("Both ML Kit and cloud translation failed: ${e.message}")
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
