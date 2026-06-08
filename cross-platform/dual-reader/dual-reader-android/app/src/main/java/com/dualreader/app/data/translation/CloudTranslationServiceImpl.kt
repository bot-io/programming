package com.dualreader.app.data.translation

import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import com.dualreader.app.domain.services.TranslationException
import com.dualreader.app.domain.services.TranslationService
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext
import javax.inject.Inject
import javax.inject.Singleton

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
    private val connectivityManager: ConnectivityManager
) : TranslationService {

    override val providerName: String = "Gemini 3.5 Flash / GLM-4.7-Flash (cloud)"

    companion object {
        /** Minimum delay between batch requests to respect worker rate limits. */
        private const val BATCH_DELAY_MS = 500L
    }

    // ── translate ──────────────────────────────────────────────────────────────

    override suspend fun translate(
        text: String,
        targetLanguage: String,
        sourceLanguage: String?,
        context: String?
    ): String = withContext(Dispatchers.IO) {
        // Context is already formatted by TranslatePageUseCase with clear instructions.
        // Just pass it through to the proxy — the worker adds it before the text.
        val request = ProxyTranslateRequest(
            text = if (context != null) "$context\n\n--- Text to translate ---\n$text" else text,
            sourceLang = sourceLanguage,
            targetLang = targetLanguage,
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

        // Send texts one by one through the proxy to avoid oversized requests.
        // The worker rate-limits per IP so we add small delays between calls.
        val results = mutableListOf<String>()
        for ((index, text) in texts.withIndex()) {
            if (index > 0) delay(BATCH_DELAY_MS)

            val request = ProxyTranslateRequest(
                text = text,
                sourceLang = sourceLanguage,
                targetLang = targetLanguage,
            )
            results.add(callProxy(request))
        }
        results
    }

    // ── detectLanguage ─────────────────────────────────────────────────────────

    override suspend fun detectLanguage(text: String): String = withContext(Dispatchers.IO) {
        requireNetwork()

        // Ask the proxy to translate with auto-detect — then we infer language.
        // For simplicity, we use the same proxy endpoint with a special target.
        val request = ProxyTranslateRequest(
            text = "Detect the language of this text, reply with ISO 639-1 code only:\n$text",
            sourceLang = "auto",
            targetLang = "en",
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
        val response = try {
            proxyApi.translate(request)
        } catch (e: Exception) {
            throw TranslationException("Network error calling translation proxy", e)
        }

        if (!response.isSuccessful) {
            val errorBody = response.errorBody()?.string()?.take(300) ?: "no body"
            throw TranslationException("Translation proxy error ${response.code()}: $errorBody")
        }

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
}
