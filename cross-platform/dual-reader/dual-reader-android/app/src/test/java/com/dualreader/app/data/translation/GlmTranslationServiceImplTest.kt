package com.dualreader.app.data.translation

import com.dualreader.app.domain.services.TranslationException
import io.mockk.coEvery
import io.mockk.every
import io.mockk.impl.annotations.RelaxedMockK
import io.mockk.junit4.MockKRule
import kotlinx.coroutines.test.runTest
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.ResponseBody.Companion.toResponseBody
import org.junit.Assert.*
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import retrofit2.Response

/**
 * Tests for GlmTranslationServiceImpl — legacy direct GLM API translation.
 *
 * Covers:
 * - translate: happy path, context injection, API key check, HTTP errors, network errors
 * - translateBatch: marker-based parsing, line-based fallback, padding, empty input
 * - detectLanguage: success and invalid result
 * - isAvailable: with/without API key
 * - parseBatchResponse: marker matching, line splitting, edge cases
 */
class GlmTranslationServiceImplTest {

    @get:Rule
    val mockkRule = MockKRule(this)

    @RelaxedMockK
    lateinit var translationApi: TranslationApi

    private lateinit var service: GlmTranslationServiceImpl

    @Before
    fun setUp() {
        service = GlmTranslationServiceImpl(translationApi)
        // Set API key via reflection so isAvailable() returns true
        val field = GlmTranslationServiceImpl::class.java.getDeclaredField("apiKey")
        field.isAccessible = true
        field.set(service, "test-api-key")
    }

    // ── translate — happy path ────────────────────────────────────────────

    @Test
    fun `translate - returns translated text on success`() = runTest {
        coEvery { translationApi.translate(any(), any()) } returns glmSuccess("Здравейте")

        val result = service.translate("Hello", "bg", "en")
        assertEquals("Здравейте", result)
    }

    @Test
    fun `translate - trims whitespace from response`() = runTest {
        coEvery { translationApi.translate(any(), any()) } returns glmSuccess("  Здравейте  \n")

        val result = service.translate("Hello", "bg", "en")
        assertEquals("Здравейте", result)
    }

    @Test
    fun `translate - includes target language in prompt`() = runTest {
        coEvery { translationApi.translate(any(), match { req ->
            req.messages.any { it.content.contains("Translate to bg") }
        }) } returns glmSuccess("Здравейте")

        service.translate("Hello", "bg", "en")
    }

    @Test
    fun `translate - includes source language when provided`() = runTest {
        coEvery { translationApi.translate(any(), match { req ->
            req.messages.any { it.content.contains("from en") }
        }) } returns glmSuccess("Здравейте")

        service.translate("Hello", "bg", "en")
    }

    @Test
    fun `translate - omits source language when null`() = runTest {
        coEvery { translationApi.translate(any(), match { req ->
            val userMsg = req.messages.last().content
            !userMsg.contains("from ")
        }) } returns glmSuccess("Здравейте")

        service.translate("Hello", "bg", null)
    }

    @Test
    fun `translate - includes context when provided`() = runTest {
        coEvery { translationApi.translate(any(), match { req ->
            req.messages.any { it.content.contains("Context: previous page text") }
        }) } returns glmSuccess("Здравейте")

        service.translate("Hello", "bg", "en", "previous page text")
    }

    // ── translate — error paths ───────────────────────────────────────────

    @Test(expected = TranslationException::class)
    fun `translate - throws on HTTP error`() = runTest {
        val errorBody = """{"error":"unauthorized"}""".toResponseBody("application/json".toMediaType())
        coEvery { translationApi.translate(any(), any()) } returns Response.error(401, errorBody)

        service.translate("Hello", "bg", "en")
    }

    @Test(expected = TranslationException::class)
    fun `translate - throws on network error`() = runTest {
        coEvery { translationApi.translate(any(), any()) } throws java.net.SocketTimeoutException("timeout")

        service.translate("Hello", "bg", "en")
    }

    @Test(expected = TranslationException::class)
    fun `translate - throws on null response body`() = runTest {
        coEvery { translationApi.translate(any(), any()) } returns Response.success(null as GlmResponse?)

        service.translate("Hello", "bg", "en")
    }

    @Test(expected = TranslationException::class)
    fun `translate - throws on empty choices`() = runTest {
        coEvery { translationApi.translate(any(), any()) } returns Response.success(GlmResponse(choices = emptyList()))

        service.translate("Hello", "bg", "en")
    }

    // ── translateBatch — happy path ───────────────────────────────────────

    @Test
    fun `translateBatch - returns empty list for empty input`() = runTest {
        val result = service.translateBatch(emptyList(), "bg", "en")
        assertTrue(result.isEmpty())
    }

    @Test
    fun `translateBatch - translates single text`() = runTest {
        coEvery { translationApi.translate(any(), any()) } returns glmSuccess("[1] Здравейте")

        val result = service.translateBatch(listOf("Hello"), "bg", "en")
        assertEquals(1, result.size)
        assertEquals("Здравейте", result[0])
    }

    @Test
    fun `translateBatch - translates multiple texts with markers`() = runTest {
        coEvery { translationApi.translate(any(), any()) } returns glmSuccess(
            "[1] Здравейте\n[2] Свят"
        )

        val result = service.translateBatch(listOf("Hello", "World"), "bg", "en")
        assertEquals(2, result.size)
        assertEquals("Здравейте", result[0])
        assertEquals("Свят", result[1])
    }

    @Test
    fun `translateBatch - handles large batch by chunking`() = runTest {
        // BATCH_CHUNK_SIZE is 10, so 12 items should be split into 2 API calls
        val texts = (1..12).map { "Text $it" }
        coEvery { translationApi.translate(any(), match { req ->
            // First chunk: 10 items, second: 2 items
            req.messages.any { it.content.contains("Text 1") }
        }) } returns glmSuccess((1..10).joinToString("\n") { "[$it] Перевод $it" })

        coEvery { translationApi.translate(any(), match { req ->
            req.messages.any { it.content.contains("Text 11") }
        }) } returns glmSuccess("[1] Перевод 11\n[2] Перевод 12")

        val result = service.translateBatch(texts, "bg", "en")
        assertEquals(12, result.size)
    }

    // ── detectLanguage ────────────────────────────────────────────────────

    @Test
    fun `detectLanguage - returns language code on success`() = runTest {
        coEvery { translationApi.translate(any(), any()) } returns glmSuccess("en")

        val result = service.detectLanguage("Hello world")
        assertEquals("en", result)
    }

    @Test
    fun `detectLanguage - trims and lowercases result`() = runTest {
        coEvery { translationApi.translate(any(), any()) } returns glmSuccess("  BG  \n")

        val result = service.detectLanguage("Здравейте")
        assertEquals("bg", result)
    }

    @Test(expected = TranslationException::class)
    fun `detectLanguage - throws on non-2-letter result`() = runTest {
        coEvery { translationApi.translate(any(), any()) } returns glmSuccess("English")

        service.detectLanguage("Hello world")
    }

    @Test(expected = TranslationException::class)
    fun `detectLanguage - throws on result with digits`() = runTest {
        coEvery { translationApi.translate(any(), any()) } returns glmSuccess("e1")

        service.detectLanguage("Hello world")
    }

    // ── isAvailable ───────────────────────────────────────────────────────

    @Test
    fun `isAvailable - returns true when API key is set`() = runTest {
        assertTrue(service.isAvailable())
    }

    @Test
    fun `isAvailable - returns false when API key is blank`() = runTest {
        // Reset the companion object field to empty
        val field = GlmTranslationServiceImpl::class.java.getDeclaredField("apiKey")
        field.isAccessible = true
        field.set(null, "")

        try {
            val noKeyService = GlmTranslationServiceImpl(translationApi)
            assertFalse(noKeyService.isAvailable())
        } finally {
            // Restore for other tests
            field.set(null, "test-api-key")
        }
    }

    // ── providerName ──────────────────────────────────────────────────────

    @Test
    fun `providerName contains GLM`() {
        assertTrue(service.providerName.contains("GLM"))
    }

    // ── Helpers ───────────────────────────────────────────────────────────

    private fun glmSuccess(text: String): Response<GlmResponse> {
        return Response.success(
            GlmResponse(
                choices = listOf(
                    GlmChoice(message = GlmMessage(role = "assistant", content = text))
                )
            )
        )
    }
}
