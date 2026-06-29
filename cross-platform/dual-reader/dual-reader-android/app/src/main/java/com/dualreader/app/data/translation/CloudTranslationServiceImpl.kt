package com.dualreader.app.data.translation

import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import com.dualreader.app.domain.services.TranslationException
import com.dualreader.app.domain.services.BatchTranslationResult
import com.dualreader.app.domain.services.TranslationService
import com.dualreader.app.util.AppLogger
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext
import javax.inject.Inject
import javax.inject.Singleton

import com.dualreader.app.domain.usecases.SerializedBookContext

/**
 * Primary translation backend — calls our Cloudflare Worker proxy
 * which forwards to Z.AI's GLM-4-Flash (free tier).
 *
 * The API key lives server-side in the Worker, never in the APK.
 * Rate limiting is enforced by the Worker (per-IP, daily limits).
 */
@Singleton
class CloudTranslationServiceImpl @Inject constructor(
    private val proxyApi: ProxyTranslationApi,
    private val connectivityManager: ConnectivityManager,
    private val installationIdProvider: InstallationIdProvider,
) : TranslationService {

    override val providerName: String = "Gemini 3.5 Flash / GLM-4.7-Flash (cloud)"

    companion object {
        private const val TAG = "CloudTranslation"
        /** Delay between sequential individual translate calls (legacy batch). */
        private const val BATCH_DELAY_MS = 200L   // Worker batch endpoint handles rate limiting
    }

    // ── translate ──────────────────────────────────────────────────────────────

    override suspend fun translate(
        text: String,
        targetLanguage: String,
        sourceLanguage: String?,
        context: String?,
        bookContext: SerializedBookContext?,
        skipCache: Boolean,
    ): String = withContext(Dispatchers.IO) {
        val installationId = installationIdProvider.getInstallationId()
        
        // Log book context for debugging translation quality issues
        if (bookContext != null) {
            AppLogger.i("translate: bookContext provided - title='${bookContext.title}', author='${bookContext.author}', openingText=${bookContext.openingText.take(50)}...")
        } else {
            AppLogger.w("translate: bookContext is null - translation quality may suffer")
        }
        
        val request = ProxyTranslateRequest(
            text = text,
            sourceLang = sourceLanguage,
            targetLang = targetLanguage,
            installationId = installationId,
            bookContext = bookContext?.let {
                ProxyBookContext(title = it.title, author = it.author, openingText = it.openingText)
            },
            skipCache = skipCache,
        )

        callProxy(request)
    }

    // ── translateBatch ─────────────────────────────────────────────────────────

    override suspend fun translateBatch(
        texts: List<String>,
        targetLanguage: String,
        sourceLanguage: String?
    ): List<String> = withContext(Dispatchers.IO) {
        if (texts.isEmpty()) return@withContext emptyList()
        val installationId = installationIdProvider.getInstallationId()

        // Send texts one by one through the proxy to avoid oversized requests.
        // The worker rate-limits per IP so we add small delays between calls.
        val results = mutableListOf<String>()
        for ((index, text) in texts.withIndex()) {
            if (index > 0) delay(BATCH_DELAY_MS)

            val request = ProxyTranslateRequest(
                text = text,
                sourceLang = sourceLanguage,
                targetLang = targetLanguage,
                installationId = installationId,
            )
            results.add(callProxy(request))
        }
        results
    }

    // ── translatePages (batch optimization) ────────────────────────────────────

    override suspend fun translatePages(
        pages: List<IndexedValue<String>>,
        targetLanguage: String,
        sourceLanguage: String?,
        context: String?,
        bookContext: SerializedBookContext?,
        skipCache: Boolean,
    ): BatchTranslationResult = withContext(Dispatchers.IO) {
        if (pages.isEmpty()) return@withContext BatchTranslationResult(emptyMap())
        val installationId = installationIdProvider.getInstallationId()

        // Log book context for debugging translation quality issues
        if (bookContext != null) {
            AppLogger.i("translatePages: bookContext provided - title='${bookContext.title}', author='${bookContext.author}', openingText=${bookContext.openingText.take(50)}...")
        } else {
            AppLogger.w("translatePages: bookContext is null - translation quality may suffer")
        }

        AppLogger.i("translatePages: sending ${pages.size} pages to batch endpoint")

        // ── Try batch endpoint first (1 API call for all pages) ──
        try {
            val batchResult = callBatchEndpoint(
                pages, targetLanguage, sourceLanguage, installationId, bookContext, skipCache
            )
            if (batchResult != null) {
                AppLogger.i("translatePages: batch success, got ${batchResult.translations.size}/${pages.size} translations")
                return@withContext batchResult
            }
        } catch (e: kotlinx.coroutines.CancellationException) {
            throw e // Preserve coroutine cancellation semantics (DR-139)
        } catch (e: Exception) {
            AppLogger.w("translatePages: batch endpoint failed (${e.message}), falling back to single-page translation...")
        }

        // ── Fallback: translate pages individually ──
        // If batch fails (503, 502, network error, parse failure), try each page
        // one-by-one through the single /translate endpoint. Return partial results
        // so the user gets whatever succeeded instead of nothing.
        val singleResults = mutableMapOf<Int, String>()
        var singleModel: String? = null
        for ((i, page) in pages.withIndex()) {
            try {
                if (i > 0) delay(BATCH_DELAY_MS)
                val translated = translate(
                    text = page.value,
                    targetLanguage = targetLanguage,
                    sourceLanguage = sourceLanguage,
                    context = context,
                    bookContext = bookContext,
                    skipCache = skipCache,
                )
                if (translated.isNotBlank()) {
                    singleResults[page.index] = translated.trim()
                }
            } catch (e: kotlinx.coroutines.CancellationException) {
                throw e // Propagate cancellation — don't return partial results (DR-112)
            } catch (e: Exception) {
                AppLogger.w("translatePages: single-page fallback failed for page ${page.index}: ${e.message}")
                // Continue — return partial results
            }
        }

        if (singleResults.isEmpty()) {
            throw TranslationException("All translation methods failed (batch + single-page fallback)")
        }

        AppLogger.i("translatePages: single-page fallback got ${singleResults.size}/${pages.size} translations")
        BatchTranslationResult(singleResults, singleModel ?: "fallback")
    }

    /**
     * Call the batch endpoint and return a [BatchTranslationResult] on success,
     * or null if the response is unusable (caller decides fallback).
     * Throws on network-level failures so the caller can catch and fall back.
     */
    private suspend fun callBatchEndpoint(
        pages: List<IndexedValue<String>>,
        targetLanguage: String,
        sourceLanguage: String?,
        installationId: String,
        bookContext: SerializedBookContext?,
        skipCache: Boolean,
    ): BatchTranslationResult? {
        val batchPages = pages.map { (index, text) ->
            BatchPage(index = index, text = text)
        }
        val request = ProxyBatchTranslateRequest(
            pages = batchPages,
            sourceLang = sourceLanguage,
            targetLang = targetLanguage,
            installationId = installationId,
            bookContext = bookContext?.let {
                ProxyBookContext(title = it.title, author = it.author, openingText = it.openingText)
            },
            skipCache = skipCache,
        )

        val response = proxyApi.translateBatch(request)
        val batchModel: String? = response.body()?.model?.takeIf { it.isNotBlank() }
        AppLogger.i("callBatchEndpoint: response code=${response.code()} model=${batchModel ?: "n/a"}")

        if (!response.isSuccessful) {
            val errorBody = response.errorBody()?.string()?.take(300) ?: "no body"
            throw TranslationException("Batch endpoint error ${response.code()}: $errorBody")
        }

        val body = response.body()
            ?: throw TranslationException("Batch endpoint returned empty response")

        if (body.error != null) {
            throw TranslationException("Batch translation error: ${body.error}")
        }

        if (body.translations.isEmpty()) {
            throw TranslationException("Batch endpoint returned no translations")
        }

        val modelUsed = batchModel ?: "unknown"
        val results = mutableMapOf<Int, String>()
        for (t in body.translations) {
            if (t.translatedText.isNotBlank()) {
                results[t.index] = t.translatedText.trim()
            }
        }

        if (results.isEmpty()) {
            throw TranslationException("Batch endpoint returned no valid translations")
        }

        return BatchTranslationResult(results, modelUsed)
    }

    // ── detectLanguage ─────────────────────────────────────────────────────────

    override suspend fun detectLanguage(text: String): String = withContext(Dispatchers.IO) {
        requireNetwork()

        // Ask the proxy to translate with auto-detect — then we infer language.
        // For simplicity, we use the same proxy endpoint with a special target.
        val installationId = installationIdProvider.getInstallationId()
        val request = ProxyTranslateRequest(
            text = "Detect the language of this text, reply with ISO 639-1 code only:\n$text",
            sourceLang = "auto",
            targetLang = "en",
            installationId = installationId,
        )

        val result = callProxy(request).trim().lowercase()
        if (result.length != 2 || !result.all { it.isLetter() }) {
            throw TranslationException(
                "Unexpected language detection result: '$result'. Expected a 2-letter ISO 639-1 code."
            )
        }
        result
    }

    // ── isAvailable ────────────────────────────────────────────────────────────

    override suspend fun isAvailable(): Boolean = withContext(Dispatchers.IO) {
        val network = connectivityManager.activeNetwork
        val capabilities = connectivityManager.getNetworkCapabilities(network)
        capabilities != null && capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
    }

    // ── Internal helpers ───────────────────────────────────────────────────────

    private fun requireNetwork() {
        val network = connectivityManager.activeNetwork
        val capabilities = connectivityManager.getNetworkCapabilities(network)
        if (capabilities == null || !capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)) {
            throw TranslationException("No internet connection available.")
        }
    }

    private suspend fun callProxy(request: ProxyTranslateRequest): String {
        AppLogger.i("callProxy: sending ${request.text.length} chars, ${request.sourceLang}->${request.targetLang}")
        
        // Retry up to 3 times on 429 (rate limit) with server-suggested backoff
        var lastError: String? = null
        repeat(3) { attempt ->
            val response = try {
                proxyApi.translate(request)
            } catch (e: kotlinx.coroutines.CancellationException) {
                throw e // Propagate cancellation — don't mask as network error (DR-052)
            } catch (e: Exception) {
                AppLogger.e("callProxy: network error: ${e.message}", e)
                throw TranslationException("Network error calling translation proxy", e)
            }

            AppLogger.i("callProxy: response code=${response.code()}")
            if (response.isSuccessful) {
                val body = response.body()
                    ?: throw TranslationException("Translation proxy returned empty response.")
                if (body.error != null) {
                    throw TranslationException("Translation error: ${body.error}")
                }
                if (body.translatedText.isBlank()) {
                    throw TranslationException("Translation returned empty text.")
                }
                return body.translatedText.trim()
            }

            // Handle 429 rate limit — wait and retry
            if (response.code() == 429) {
                val errorBody = response.errorBody()?.string()?.take(300) ?: "no body"
                val retryAfter = extractRetryAfterMs(errorBody)
                lastError = "429 rate limited (attempt ${attempt + 1}/3, retry after ${retryAfter}ms)"
                AppLogger.w("callProxy: 429 rate limited, waiting ${retryAfter}ms (attempt ${attempt + 1}/3)")
                delay(retryAfter.coerceAtLeast(1000L))
                return@repeat
            }

            // Non-429 error — don't retry
            val errorBody = response.errorBody()?.string()?.take(300) ?: "no body"
            AppLogger.e("callProxy: error ${response.code()}: $errorBody")
            throw TranslationException("Translation proxy error ${response.code()}: $errorBody")
        }

        throw TranslationException("Translation proxy rate limited after 3 retries: $lastError")
    }

    /** Extract retry_after_ms from worker 429 JSON response. */
    private fun extractRetryAfterMs(errorBody: String): Long {
        return try {
            val regex = """"retry_after_ms"\s*:\s*(\d+)""".toRegex()
            regex.find(errorBody)?.groupValues?.get(1)?.toLongOrNull() ?: 3000L
        } catch (_: Exception) {
            AppLogger.w("Failed to parse retry_after_ms from 429 response, using default 3000ms")
            3000L
        }
    }
}
