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
        /** Minimum delay between batch requests to respect worker rate limits. */
        private const val BATCH_DELAY_MS = 3500L   // Must be >= worker cooldown (3s)
    }

    // ── translate ──────────────────────────────────────────────────────────────

    override suspend fun translate(
        text: String,
        targetLanguage: String,
        sourceLanguage: String?,
        context: String?,
        bookContext: SerializedBookContext?,
    ): String = withContext(Dispatchers.IO) {
        val installationId = installationIdProvider.getInstallationId()
        // Context is already formatted by TranslatePageUseCase with clear instructions.
        // Just pass it through to the proxy — the worker adds it before the text.
        val request = ProxyTranslateRequest(
            text = if (context != null) "$context\n\n--- Text to translate ---\n$text" else text,
            sourceLang = sourceLanguage,
            targetLang = targetLanguage,
            installationId = installationId,
            bookContext = bookContext?.let {
                ProxyBookContext(title = it.title, author = it.author, openingText = it.openingText)
            },
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
    ): BatchTranslationResult = withContext(Dispatchers.IO) {
        if (pages.isEmpty()) return@withContext BatchTranslationResult(emptyMap())
        val installationId = installationIdProvider.getInstallationId()

        // Try the batch endpoint first
        try {
            AppLogger.i("translatePages: sending ${pages.size} pages to batch endpoint")
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
            )

            val response = proxyApi.translateBatch(request)
            val batchModel: String? = response.body()?.model?.takeIf { it.isNotBlank() }
            AppLogger.i("translatePages: response code=${response.code()} model=${batchModel ?: "n/a"}")
            if (response.isSuccessful) {
                val body = response.body()
                if (body?.error == null && body?.translations?.isNotEmpty() == true) {
                    val modelUsed = batchModel ?: "unknown"
                    val results = mutableMapOf<Int, String>()
                    for (t in body.translations) {
                        if (t.translatedText.isNotBlank()) {
                            results[t.index] = t.translatedText.trim()
                        }
                    }
                    // Verify we got translations for all pages
                    if (results.size == pages.size) {
                        return@withContext BatchTranslationResult(results, modelUsed)
                    }
                    // Partial success — fill gaps with individual calls
                    AppLogger.w("Batch returned ${results.size}/${pages.size} pages, filling gaps individually")
                    for (page in pages) {
                        if (page.index !in results) {
                            try {
                                val singleResult = translate(page.value, targetLanguage, sourceLanguage, context)
                                results[page.index] = singleResult
                            } catch (e: Exception) {
                                AppLogger.e("Individual fallback failed for page ${page.index}: ${e.message}")
                            }
                        }
                    }
                    if (results.size == pages.size) return@withContext BatchTranslationResult(results, modelUsed)
                }
            }
        } catch (e: Exception) {
            AppLogger.w("Batch translation failed, falling back to individual: ${e.message}")
        }

        // Fallback: individual calls
        val results = mutableMapOf<Int, String>()
        for ((i, page) in pages.withIndex()) {
            if (i > 0) delay(BATCH_DELAY_MS)
            try {
                results[page.index] = translate(page.value, targetLanguage, sourceLanguage, context)
            } catch (e: Exception) {
                AppLogger.e("Individual translation failed for page ${page.index}: ${e.message}")
            }
        }
        BatchTranslationResult(results, providerName)
    }

    // ── detectLanguage ─────────────────────────────────────────────────────────

    override suspend fun detectLanguage(text: String): String = withContext(Dispatchers.IO) {
        requireNetwork()

        // Ask the proxy to translate with auto-detect — then we infer language.
        // For simplicity, we use the same proxy endpoint with a special target.
        val installationId = installationIdProvider.getInstallationIdSync()
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
            AppLogger.e("callProxy: error $${response.code()}: $errorBody")
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
            3000L
        }
    }
}
