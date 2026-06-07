package com.dualreader.app.data.translation

import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.util.Log
import com.dualreader.app.domain.services.TranslationException
import com.dualreader.app.domain.services.TranslationService
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext
import javax.inject.Inject
import javax.inject.Named
import javax.inject.Singleton

/**
 * Tiered fallback translation service.
 *
 * Tier 1: Cloud proxy → GLM-4.7-Flash (free, best quality for literary text)
 * Tier 2: ML Kit on-device (offline, lower quality but always available)
 *
 * If cloud fails (timeout, rate limit, no network), automatically falls back
 * to on-device ML Kit so the user always gets a translation.
 */
@Singleton
class FallbackTranslationService @Inject constructor(
    @Named("cloud") private val cloudService: TranslationService,
    @Named("mlkit") private val mlKitService: TranslationService,
    private val connectivityManager: ConnectivityManager,
) : TranslationService {

    override val providerName: String = "Fallback (Cloud → ML Kit)"

    companion object {
        private const val TAG = "FallbackTranslation"
        /** Max chars per chunk sent to the API. Keeps requests small to avoid timeouts. */
        private const val MAX_CHUNK_SIZE = 1500
    }

    // ── translate ──────────────────────────────────────────────────────────────

    override suspend fun translate(
        text: String,
        targetLanguage: String,
        sourceLanguage: String?,
        context: String?,
    ): String {
        // If text is long, split into paragraphs and translate each
        val chunks = splitIntoChunks(text)
        if (chunks.size <= 1) {
            return translateSingle(text, targetLanguage, sourceLanguage, context)
        }

        // For multi-chunk: pass context only to first chunk (most relevant)
        val results = chunks.mapIndexed { index, chunk ->
            if (index > 0) delay(300L)
            val chunkContext = if (index == 0) context else null
            translateSingle(chunk, targetLanguage, sourceLanguage, chunkContext)
        }
        return results.joinToString("\n\n")
    }

    /**
     * Try cloud first, fall back to ML Kit.
     * Always attempts cloud regardless of network state — let the HTTP call
     * itself determine connectivity (ConnectivityManager is unreliable on some devices).
     */
    private suspend fun translateSingle(
        text: String,
        targetLanguage: String,
        sourceLanguage: String?,
        context: String? = null,
    ): String {
        var cloudError: String? = null

        // Tier 1: Try cloud (always attempt — don't gate on ConnectivityManager)
        try {
            val result = cloudService.translate(text, targetLanguage, sourceLanguage, context)
            Log.d(TAG, "Cloud translation succeeded (${result.length} chars)")
            return result
        } catch (e: Exception) {
            cloudError = e.message ?: "Unknown error"
            Log.w(TAG, "Cloud translation failed: $cloudError, falling back to ML Kit")
        }

        // Tier 2: ML Kit on-device fallback
        try {
            val result = mlKitService.translate(text, targetLanguage, sourceLanguage)
            Log.d(TAG, "ML Kit fallback succeeded (${result.length} chars)")
            return result
        } catch (e: Exception) {
            Log.e(TAG, "ML Kit also failed: ${e.message}")
            throw TranslationException(
                "Translation failed.\n" +
                "Cloud: $cloudError\n" +
                "Offline: ${e.message}"
            )
        }
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

    // ── detectLanguage ─────────────────────────────────────────────────────────

    override suspend fun detectLanguage(text: String): String {
        try { return cloudService.detectLanguage(text) } catch (_: Exception) {}
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
