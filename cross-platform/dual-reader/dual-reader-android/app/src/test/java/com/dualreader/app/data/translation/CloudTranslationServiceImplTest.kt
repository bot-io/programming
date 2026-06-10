package com.dualreader.app.data.translation

import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import com.dualreader.app.domain.services.TranslationException
import io.mockk.*
import kotlinx.coroutines.test.runTest
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.ResponseBody.Companion.toResponseBody
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import retrofit2.Response

/**
 * Tests for CloudTranslationServiceImpl — the proxy-based translation service.
 *
 * Covers:
 * - Happy path (single translate, batch translate, with/without context)
 * - Error paths (HTTP errors, empty response, network failures)
 * - Edge cases (empty batch, context formatting, whitespace trimming)
 * - Model tracking (Gemini primary, GLM fallback)
 */
class CloudTranslationServiceImplTest {

    private lateinit var proxyApi: ProxyTranslationApi
    private lateinit var connectivityManager: ConnectivityManager
    private lateinit var networkCapabilities: NetworkCapabilities
    private lateinit var service: CloudTranslationServiceImpl

    @Before
    fun setUp() {
        proxyApi = mockk()
        connectivityManager = mockk()
        networkCapabilities = mockk()

        // Simulate connected network
        every { connectivityManager.activeNetwork } returns mockk<Network>()
        every { connectivityManager.getNetworkCapabilities(any()) } returns networkCapabilities
        every { networkCapabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) } returns true

        service = CloudTranslationServiceImpl(proxyApi, connectivityManager)
    }

    // ── Single translate — happy path ────────────────────────────────────────

    @Test
    fun `translate - returns translated text on success`() = runTest {
        coEvery { proxyApi.translate(any()) } returns successResponse("Здравейте", "gemini-2.5-flash")

        val result = service.translate("Hello", "bg", "en", null)
        assertEquals("Здравейте", result)
    }

    @Test
    fun `translate - trims whitespace from response`() = runTest {
        coEvery { proxyApi.translate(any()) } returns successResponse("  Здравейте  \n", "gemini-2.5-flash")

        val result = service.translate("Hello", "bg", "en", null)
        assertEquals("Здравейте", result)
    }

    @Test
    fun `translate - sends correct request fields`() = runTest {
        coEvery { proxyApi.translate(match { req ->
            req.text == "Hello" &&
            req.sourceLang == "en" &&
            req.targetLang == "bg"
        }) } returns successResponse("Здравейте")

        service.translate("Hello", "bg", "en", null)
    }

    @Test
    fun `translate - with null source language passes null`() = runTest {
        coEvery { proxyApi.translate(match { req ->
            req.sourceLang == null && req.targetLang == "bg"
        }) } returns successResponse("Здравейте")

        service.translate("Hello", "bg", null, null)
    }

    // ── Single translate — with context ──────────────────────────────────────

    @Test
    fun `translate - includes context with separator when provided`() = runTest {
        coEvery { proxyApi.translate(match { req ->
            req.text.contains("--- Text to translate ---") &&
            req.text.contains("Previous context") &&
            req.text.endsWith("Hello")
        }) } returns successResponse("Здравейте")

        service.translate("Hello", "bg", "en", "Previous context")
    }

    @Test
    fun `translate - without context sends text directly`() = runTest {
        coEvery { proxyApi.translate(match { req ->
            req.text == "Hello" && !req.text.contains("---")
        }) } returns successResponse("Здравейте")

        service.translate("Hello", "bg", "en", null)
    }

    // ── Single translate — error paths ───────────────────────────────────────

    @Test(expected = TranslationException::class)
    fun `translate - throws on HTTP 429 rate limit`() = runTest {
        val errorBody = """{"error":"rate limited"}""".toResponseBody("application/json".toMediaType())
        coEvery { proxyApi.translate(any()) } returns Response.error(429, errorBody)

        service.translate("Hello", "bg", "en", null)
    }

    @Test(expected = TranslationException::class)
    fun `translate - throws on HTTP 500 server error`() = runTest {
        val errorBody = """{"error":"internal"}""".toResponseBody("application/json".toMediaType())
        coEvery { proxyApi.translate(any()) } returns Response.error(500, errorBody)

        service.translate("Hello", "bg", "en", null)
    }

    @Test(expected = TranslationException::class)
    fun `translate - throws on HTTP 502 bad gateway`() = runTest {
        val errorBody = """{"error":"upstream failed"}""".toResponseBody("application/json".toMediaType())
        coEvery { proxyApi.translate(any()) } returns Response.error(502, errorBody)

        service.translate("Hello", "bg", "en", null)
    }

    @Test(expected = TranslationException::class)
    fun `translate - throws on empty translated text`() = runTest {
        coEvery { proxyApi.translate(any()) } returns successResponse("")

        service.translate("Hello", "bg", "en", null)
    }

    @Test(expected = TranslationException::class)
    fun `translate - throws on whitespace-only translated text`() = runTest {
        coEvery { proxyApi.translate(any()) } returns successResponse("   \n\t  ")

        service.translate("Hello", "bg", "en", null)
    }

    @Test(expected = TranslationException::class)
    fun `translate - throws on error field in response body`() = runTest {
        coEvery { proxyApi.translate(any()) } returns Response.success(
            ProxyTranslateResponse(error = "Both providers failed", translatedText = "")
        )

        service.translate("Hello", "bg", "en", null)
    }

    @Test(expected = TranslationException::class)
    fun `translate - throws on network timeout`() = runTest {
        coEvery { proxyApi.translate(any()) } throws java.net.SocketTimeoutException("timeout")

        service.translate("Hello", "bg", "en", null)
    }

    @Test(expected = TranslationException::class)
    fun `translate - throws on connection refused`() = runTest {
        coEvery { proxyApi.translate(any()) } throws java.net.ConnectException("Connection refused")

        service.translate("Hello", "bg", "en", null)
    }

    @Test(expected = TranslationException::class)
    fun `translate - throws on null response body`() = runTest {
        coEvery { proxyApi.translate(any()) } returns Response.success(null as ProxyTranslateResponse?)

        service.translate("Hello", "bg", "en", null)
    }

    // ── Single translate — resilience ────────────────────────────────────────

    @Test
    fun `translate - succeeds even when no network info available`() = runTest {
        // After removing requireNetwork() gate, translate should still try the HTTP call
        every { connectivityManager.getNetworkCapabilities(any()) } returns null
        coEvery { proxyApi.translate(any()) } returns successResponse("Здравейте")

        val result = service.translate("Hello", "bg", "en", null)
        assertEquals("Здравейте", result)
    }

    // ── Batch translate — happy path ─────────────────────────────────────────

    @Test
    fun `translateBatch - translates multiple texts sequentially`() = runTest {
        coEvery { proxyApi.translate(match { it.text == "Hello" }) } returns successResponse("Здравейте")
        coEvery { proxyApi.translate(match { it.text == "Goodbye" }) } returns successResponse("Довиждане")

        val result = service.translateBatch(listOf("Hello", "Goodbye"), "bg", "en")
        assertEquals(listOf("Здравейте", "Довиждане"), result)
    }

    @Test
    fun `translateBatch - returns empty list for empty input`() = runTest {
        val result = service.translateBatch(emptyList(), "bg", "en")
        assertTrue(result.isEmpty())
    }

    @Test
    fun `translateBatch - handles single text`() = runTest {
        coEvery { proxyApi.translate(any()) } returns successResponse("Здравейте")

        val result = service.translateBatch(listOf("Hello"), "bg", "en")
        assertEquals(listOf("Здравейте"), result)
    }

    @Test
    fun `translateBatch - translates three texts`() = runTest {
        coEvery { proxyApi.translate(match { it.text == "One" }) } returns successResponse("Едно")
        coEvery { proxyApi.translate(match { it.text == "Two" }) } returns successResponse("Две")
        coEvery { proxyApi.translate(match { it.text == "Three" }) } returns successResponse("Три")

        val result = service.translateBatch(listOf("One", "Two", "Three"), "bg", "en")
        assertEquals(listOf("Едно", "Две", "Три"), result)
    }

    @Test(expected = TranslationException::class)
    fun `translateBatch - propagates error on second text`() = runTest {
        coEvery { proxyApi.translate(match { it.text == "Hello" }) } returns successResponse("Здравейте")
        coEvery { proxyApi.translate(match { it.text == "Error" }) } throws java.net.SocketTimeoutException("timeout")

        service.translateBatch(listOf("Hello", "Error"), "bg", "en")
    }

    // ── Provider name ────────────────────────────────────────────────────────

    @Test
    fun `providerName includes Gemini and GLM`() {
        assertTrue(service.providerName.contains("Gemini"))
        assertTrue(service.providerName.contains("GLM"))
    }

    // ── Model tracking ───────────────────────────────────────────────────────

    @Test
    fun `translate - response from Gemini model passes through`() = runTest {
        coEvery { proxyApi.translate(any()) } returns successResponse("Здравейте", "gemini-2.5-flash")

        val result = service.translate("Hello", "bg", "en", null)
        assertEquals("Здравейте", result)
    }

    @Test
    fun `translate - response from GLM fallback passes through`() = runTest {
        coEvery { proxyApi.translate(any()) } returns successResponse("Здравейте", "glm-4.7-flash")

        val result = service.translate("Hello", "bg", "en", null)
        assertEquals("Здравейте", result)
    }

    // ── translatePages — batch index mapping ──────────────────────────────────

    @Test
    fun `translatePages - returns map with original page indices from batch response`() = runTest {
        // Pages with non-sequential indices 5, 6, 7
        val pages = listOf(
            IndexedValue(5, "Page five"),
            IndexedValue(6, "Page six"),
            IndexedValue(7, "Page seven"),
        )

        coEvery { proxyApi.translateBatch(any()) } returns batchSuccessResponse(
            listOf(
                BatchTranslation(index = 5, translatedText = "Страница пет"),
                BatchTranslation(index = 6, translatedText = "Страница шест"),
                BatchTranslation(index = 7, translatedText = "Страница седем"),
            )
        )

        val result = service.translatePages(pages, "bg", "en", null)

        // Keys MUST be 5, 6, 7 — NOT 0, 1, 2
        assertEquals(setOf(5, 6, 7), result.translations.keys)
        assertEquals("Страница пет", result.translations[5])
        assertEquals("Страница шест", result.translations[6])
        assertEquals("Страница седем", result.translations[7])
    }

    @Test
    fun `translatePages - returns map with sequential indices from batch response`() = runTest {
        val pages = listOf(
            IndexedValue(0, "Page zero"),
            IndexedValue(1, "Page one"),
            IndexedValue(2, "Page two"),
        )

        coEvery { proxyApi.translateBatch(any()) } returns batchSuccessResponse(
            listOf(
                BatchTranslation(index = 0, translatedText = "Страница нула"),
                BatchTranslation(index = 1, translatedText = "Страница едно"),
                BatchTranslation(index = 2, translatedText = "Страница две"),
            )
        )

        val result = service.translatePages(pages, "bg", "en", null)

        assertEquals(setOf(0, 1, 2), result.translations.keys)
        assertEquals("Страница нула", result.translations[0])
        assertEquals("Страница едно", result.translations[1])
        assertEquals("Страница две", result.translations[2])
    }

    @Test
    fun `translatePages - preserves single non-zero index`() = runTest {
        val pages = listOf(IndexedValue(42, "Page forty-two"))

        coEvery { proxyApi.translateBatch(any()) } returns batchSuccessResponse(
            listOf(BatchTranslation(index = 42, translatedText = "Страница 42"))
        )

        val result = service.translatePages(pages, "bg", "en", null)

        assertEquals(setOf(42), result.translations.keys)
        assertEquals("Страница 42", result.translations[42])
        assertNull(result.translations[0])
    }

    @Test
    fun `translatePages - returns empty map for empty input`() = runTest {
        val result = service.translatePages(emptyList(), "bg", "en", null)
        assertTrue(result.translations.isEmpty())
    }

    @Test
    fun `translatePages - does NOT map non-zero indices to zero-based keys`() = runTest {
        // Regression guard: if the implementation incorrectly used loop index instead
        // of the response's index field, indices 5,6,7 would become 0,1,2.
        val pages = listOf(
            IndexedValue(5, "A"),
            IndexedValue(6, "B"),
        )

        coEvery { proxyApi.translateBatch(any()) } returns batchSuccessResponse(
            listOf(
                BatchTranslation(index = 5, translatedText = "А"),
                BatchTranslation(index = 6, translatedText = "Б"),
            )
        )

        val result = service.translatePages(pages, "bg", "en", null)

        // Must NOT contain zero-based keys
        assertFalse("Result should not contain key 0", result.translations.containsKey(0))
        assertFalse("Result should not contain key 1", result.translations.containsKey(1))
        assertTrue(result.translations.containsKey(5))
        assertTrue(result.translations.containsKey(6))
    }

    @Test
    fun `translatePages - batch endpoint receives correct page indices in request`() = runTest {
        val pages = listOf(
            IndexedValue(10, "Ten"),
            IndexedValue(20, "Twenty"),
        )

        coEvery { proxyApi.translateBatch(match { req ->
            val indices = req.pages.map { it.index }
            indices == listOf(10, 20)
        }) } returns batchSuccessResponse(
            listOf(
                BatchTranslation(index = 10, translatedText = "Десет"),
                BatchTranslation(index = 20, translatedText = "Двайсет"),
            )
        )

        val result = service.translatePages(pages, "bg", "en", null)

        assertEquals(mapOf(10 to "Десет", 20 to "Двайсет"), result.translations)
        assertEquals("gemini-2.5-flash", result.model)
    }

    @Test
    fun `translatePages - fallback to individual calls preserves original indices`() = runTest {
        // Batch endpoint fails, forcing individual fallback
        val pages = listOf(
            IndexedValue(5, "Five"),
            IndexedValue(6, "Six"),
        )

        coEvery { proxyApi.translateBatch(any()) } returns Response.success(
            ProxyBatchTranslateResponse(error = "batch failed")
        )
        // Individual translate calls succeed
        coEvery { proxyApi.translate(match { it.text == "Five" }) } returns successResponse("Пет")
        coEvery { proxyApi.translate(match { it.text == "Six" }) } returns successResponse("Шест")

        val result = service.translatePages(pages, "bg", "en", null)

        // Even through fallback path, keys must be 5,6 not 0,1
        assertEquals(setOf(5, 6), result.translations.keys)
        assertEquals("Пет", result.translations[5])
        assertEquals("Шест", result.translations[6])
    }

    @Test
    fun `translatePages - partial batch success fills gaps with individual calls`() = runTest {
        val pages = listOf(
            IndexedValue(3, "Three"),
            IndexedValue(4, "Four"),
        )

        // Batch returns only page 3, missing page 4
        coEvery { proxyApi.translateBatch(any()) } returns batchSuccessResponse(
            listOf(BatchTranslation(index = 3, translatedText = "Три"))
        )
        // Individual fallback for page 4
        coEvery { proxyApi.translate(match { it.text == "Four" }) } returns successResponse("Четири")

        val result = service.translatePages(pages, "bg", "en", null)

        assertEquals(setOf(3, 4), result.translations.keys)
        assertEquals("Три", result.translations[3])
        assertEquals("Четири", result.translations[4])
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    private fun successResponse(
        translatedText: String,
        model: String = "gemini-2.5-flash"
    ): Response<ProxyTranslateResponse> {
        return Response.success(
            ProxyTranslateResponse(
                translatedText = translatedText,
                model = model,
                sourceLang = "en",
                targetLang = "bg",
            )
        )
    }

    private fun batchSuccessResponse(
        translations: List<BatchTranslation>
    ): Response<ProxyBatchTranslateResponse> {
        return Response.success(
            ProxyBatchTranslateResponse(
                translations = translations,
                model = "gemini-2.5-flash",
                sourceLang = "en",
                targetLang = "bg",
            )
        )
    }
}
