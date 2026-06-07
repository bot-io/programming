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
}
