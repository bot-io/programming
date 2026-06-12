package com.dualreader.app.data.translation

import com.dualreader.app.domain.services.TranslationException
import com.dualreader.app.domain.services.TranslationService
import com.dualreader.app.domain.usecases.SerializedBookContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Legacy direct GLM API translation — kept for reference / "bring your own key" mode.
 * NOT bound as the primary TranslationService (see TranslationModule).
 *
 * TODO: For "bring your own key" mode, re-enable this with user-provided API key.
 */
@Singleton
class GlmTranslationServiceImpl @Inject constructor(
    private val translationApi: TranslationApi
) : TranslationService {

    override val providerName: String = "GLM-4-Flash (direct)"

    companion object {
        private var apiKey: String = ""
        private const val MODEL = "glm-4-flash"
        private const val SYSTEM_PROMPT =
            "You are a professional literary translator. Translate the given text accurately, " +
                "preserving the tone, style, and nuance of the original. Output only the " +
                "translation — no explanations, no notes, no quotation marks around the result."

        /** Maximum number of segments that can be sent in a single batch request. */
        private const val BATCH_CHUNK_SIZE = 10
    }

    // ── translate ──────────────────────────────────────────────────────────────

    override suspend fun translate(
        text: String,
        targetLanguage: String,
        sourceLanguage: String?,
        context: String?,
        bookContext: SerializedBookContext?,
    ): String = withContext(Dispatchers.IO) {
        val userPrompt = buildString {
            append("Translate to $targetLanguage")
            sourceLanguage?.let { append(" from $it") }
            append(":\n")
            context?.let {
                append("Context: $it\n")
            }
            append(text)
        }

        val request = GlmRequest(
            model = MODEL,
            messages = listOf(
                GlmMessage(role = "system", content = SYSTEM_PROMPT),
                GlmMessage(role = "user", content = userPrompt)
            )
        )

        callApi(request)
    }

    // ── translateBatch ─────────────────────────────────────────────────────────

    override suspend fun translateBatch(
        texts: List<String>,
        targetLanguage: String,
        sourceLanguage: String?
    ): List<String> = withContext(Dispatchers.IO) {
        if (texts.isEmpty()) return@withContext emptyList()

        // Process in chunks of BATCH_CHUNK_SIZE to stay within token limits.
        val results = mutableListOf<String>()
        for (chunk in texts.chunked(BATCH_CHUNK_SIZE)) {
            val combined = chunk.mapIndexed { index, text -> "[${index + 1}] $text" }
                .joinToString("\n\n")

            val userPrompt = buildString {
                append("Translate each numbered segment to $targetLanguage")
                sourceLanguage?.let { append(" from $it") }
                append(". Keep the [N] markers in your reply, one per line.\n\n")
                append(combined)
            }

            val systemPrompt =
                "You are a professional literary translator. Translate each numbered segment. " +
                    "Preserve the [N] marker at the start of each translated segment. " +
                    "Output one segment per line."

            val request = GlmRequest(
                model = MODEL,
                messages = listOf(
                    GlmMessage(role = "system", content = systemPrompt),
                    GlmMessage(role = "user", content = userPrompt)
                ),
                temperature = 0.3
            )

            val raw = callApi(request)
            val parsed = parseBatchResponse(raw, chunk.size)
            results.addAll(parsed)
        }
        results
    }

    // ── detectLanguage ─────────────────────────────────────────────────────────

    override suspend fun detectLanguage(text: String): String = withContext(Dispatchers.IO) {
        val request = GlmRequest(
            model = MODEL,
            messages = listOf(
                GlmMessage(
                    role = "user",
                    content = "Detect the language of this text, reply with ISO 639-1 code only:\n$text"
                )
            ),
            temperature = 0.0
        )

        val result = callApi(request).trim().lowercase()
        // Sanity-check: ISO 639-1 codes are exactly 2 letters.
        if (result.length != 2 || !result.all { it.isLetter() }) {
            throw TranslationException(
                "Unexpected language detection result: '$result'. Expected a 2-letter ISO 639-1 code."
            )
        }
        result
    }

    // ── isAvailable ────────────────────────────────────────────────────────────

    override suspend fun isAvailable(): Boolean = withContext(Dispatchers.IO) {
        apiKey.isNotBlank()
    }

    // ── Internal helpers ───────────────────────────────────────────────────────

        private suspend fun callApi(request: GlmRequest): String {
        val authHeader = "Bearer $apiKey"

        if (apiKey.isBlank()) {
            throw TranslationException("API key not configured. Use CloudTranslationService instead.")
        }

        val response = try {
            translationApi.translate(authHeader, request)
        } catch (e: Exception) {
            throw TranslationException("Network error calling ${providerName} API", e)
        }

        if (!response.isSuccessful) {
            val errorBody = response.errorBody()?.string()?.take(500) ?: "no body"
            throw TranslationException(
                "${providerName} API error ${response.code()}: $errorBody"
            )
        }

        val body = response.body()
            ?: throw TranslationException("${providerName} API returned an empty response body.")

        val content = body.choices.firstOrNull()?.message?.content
            ?: throw TranslationException("${providerName} API response contained no choices.")

        return content.trim()
    }

    /**
     * Splits a batch response back into individual translations by looking for [N] markers.
     * Falls back to line-based splitting when markers are missing.
     */
    private fun parseBatchResponse(raw: String, expectedCount: Int): List<String> {
        // Try marker-based extraction: [1] text ... [2] text ...
        val markerRegex = Regex("""\[(\d+)]\s*(.*?)(?=\[\d+]|\Z)""", RegexOption.DOT_MATCHES_ALL)
        val markerMatches = markerRegex.findAll(raw).toList()

        if (markerMatches.size == expectedCount) {
            return markerMatches.map { it.groupValues[2].trim() }
        }

        // Fallback: split by newlines, filter empties.
        val lines = raw.lines().map { it.trim() }.filter { it.isNotBlank() }
        if (lines.size == expectedCount) {
            val prefixRegex = Regex("""\[\d+]\s*""")
            return lines.map { prefixRegex.replace(it, "") }
        }

        // Last resort: return what we got, padded or trimmed.
        val cleaned = lines.ifEmpty { listOf(raw) }
        return when {
            cleaned.size >= expectedCount -> cleaned.take(expectedCount)
            else -> cleaned + List(expectedCount - cleaned.size) { "" }
        }
    }
}
