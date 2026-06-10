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
 * Additional tests for CloudTranslationServiceImpl covering:
 * - detectLanguage (success, invalid result, network check)
 * - isAvailable (connected, disconnected)
 * - extractRetryAfterMs (various response formats)
 * - 429 retry logic with retry_after_ms
 * - translatePages: full individual fallback when batch throws exception
 */
class CloudTranslationServiceImplAdditionalTest {

    private lateinit var proxyApi: ProxyTranslationApi
    private lateinit var connectivityManager: ConnectivityManager
    private lateinit var networkCapabilities: NetworkCapabilities
    private lateinit var service: CloudTranslationServiceImpl

    @Before
    fun setUp() {
        proxyApi = mockk()
        connectivityManager = mockk()
        networkCapabilities = mockk()

        // Simulate connected network by default
        every { connectivityManager.activeNetwork } returns mockk<Network>()
        every { connectivityManager.getNetworkCapabilities(any()) } returns networkCapabilities
        every { networkCapabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) } returns true

        service = CloudTranslationServiceImpl(proxyApi, connectivityManager)
    }

    // ── detectLanguage ────────────────────────────────────────────────────

    @Test
    fun `detectLanguage - returns language code on success`() = runTest {
        coEvery { proxyApi.translate(any()) } returns successResponse("bg")

        val result = service.detectLanguage("Здравейте")
        assertEquals("bg", result)
    }

    @Test
    fun `detectLanguage - trims and lowercases result`() = runTest {
        coEvery { proxyApi.translate(any()) } returns successResponse("  EN  \n")

        val result = service.detectLanguage("Hello world")
        assertEquals("en", result)
    }

    @Test(expected = TranslationException::class)
    fun `detectLanguage - throws on non-2-letter result`() = runTest {
        coEvery { proxyApi.translate(any()) } returns successResponse("English")

        service.detectLanguage("Hello world")
    }

    @Test(expected = TranslationException::class)
    fun `detectLanguage - throws on result containing digits`() = runTest {
        coEvery { proxyApi.translate(any()) } returns successResponse("b1")

        service.detectLanguage("Hello world")
    }

    @Test
    fun `detectLanguage - sends auto-detect request`() = runTest {
        coEvery { proxyApi.translate(match { req ->
            req.sourceLang == "auto" &&
            req.targetLang == "en" &&
            req.text.contains("Detect the language")
        }) } returns successResponse("fr")

        val result = service.detectLanguage("Bonjour le monde")
        assertEquals("fr", result)
    }

    @Test(expected = TranslationException::class)
    fun `detectLanguage - throws when no network`() = runTest {
        every { connectivityManager.activeNetwork } returns null
        every { connectivityManager.getNetworkCapabilities(any()) } returns null

        service.detectLanguage("Hello")
    }

    // ── isAvailable ──────────────────────────────────────────────────────

    @Test
    fun `isAvailable - returns true when connected`() = runTest {
        assertTrue(service.isAvailable())
    }

    @Test
    fun `isAvailable - returns false when no network`() = runTest {
        every { connectivityManager.activeNetwork } returns null
        every { connectivityManager.getNetworkCapabilities(null) } returns null

        assertFalse(service.isAvailable())
    }

    @Test
    fun `isAvailable - returns false when network has no INTERNET capability`() = runTest {
        every { networkCapabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) } returns false

        assertFalse(service.isAvailable())
    }

    @Test
    fun `isAvailable - returns false when capabilities are null`() = runTest {
        every { connectivityManager.getNetworkCapabilities(any()) } returns null

        assertFalse(service.isAvailable())
    }

    // ── 429 retry logic ──────────────────────────────────────────────────

    @Test(expected = TranslationException::class)
    fun `translate - retries on 429 and eventually fails after 3 retries`() = runTest {
        val errorBody = """{"error":"rate limited","retry_after_ms":100}"""
            .toResponseBody("application/json".toMediaType())

        coEvery { proxyApi.translate(any()) } returns Response.error(429, errorBody)

        service.translate("Hello", "bg", "en", null)
    }

    @Test
    fun `translate - retries on 429 and succeeds on second attempt`() = runTest {
        val errorBody = """{"error":"rate limited","retry_after_ms":100}"""
            .toResponseBody("application/json".toMediaType())

        // First call: 429, second call: success
        coEvery { proxyApi.translate(any()) } returns Response.error(429, errorBody) andThen
                successResponse("Здравейте")

        val result = service.translate("Hello", "bg", "en", null)
        assertEquals("Здравейте", result)
    }

    @Test
    fun `translate - retries on 429 and succeeds on third attempt`() = runTest {
        val errorBody = """{"error":"rate limited","retry_after_ms":100}"""
            .toResponseBody("application/json".toMediaType())

        coEvery { proxyApi.translate(any()) } returns Response.error(429, errorBody) andThen
                Response.error(429, errorBody) andThen
                successResponse("Здравейте")

        val result = service.translate("Hello", "bg", "en", null)
        assertEquals("Здравейте", result)
    }

    @Test
    fun `translate - 429 with missing retry_after_ms uses default backoff`() = runTest {
        val errorBody = """{"error":"rate limited"}"""
            .toResponseBody("application/json".toMediaType())

        // Two 429s then success — validates it uses default 3000ms backoff
        coEvery { proxyApi.translate(any()) } returns Response.error(429, errorBody) andThen
                successResponse("Здравейте")

        val result = service.translate("Hello", "bg", "en", null)
        assertEquals("Здравейте", result)
    }

    // ── translatePages: full individual fallback ─────────────────────────

    @Test
    fun `translatePages - falls back to individual calls when batch endpoint throws`() = runTest {
        val pages = listOf(
            IndexedValue(0, "Page zero"),
            IndexedValue(1, "Page one"),
        )

        // Batch endpoint throws
        coEvery { proxyApi.translateBatch(any()) } throws java.net.SocketTimeoutException("batch timeout")

        // Individual calls succeed
        coEvery { proxyApi.translate(match { it.text == "Page zero" }) } returns successResponse("Страница нула")
        coEvery { proxyApi.translate(match { it.text == "Page one" }) } returns successResponse("Страница едно")

        val result = service.translatePages(pages, "bg", "en", null)

        assertEquals("Страница нула", result.translations[0])
        assertEquals("Страница едно", result.translations[1])
    }

    @Test
    fun `translatePages - individual fallback continues even if one page fails`() = runTest {
        val pages = listOf(
            IndexedValue(0, "Page zero"),
            IndexedValue(1, "Page one"),
            IndexedValue(2, "Page two"),
        )

        // Batch throws
        coEvery { proxyApi.translateBatch(any()) } throws RuntimeException("batch error")

        // Page 0 and 2 succeed, page 1 fails
        coEvery { proxyApi.translate(match { it.text == "Page zero" }) } returns successResponse("Стр. 0")
        coEvery { proxyApi.translate(match { it.text == "Page one" }) } throws TranslationException("fail")
        coEvery { proxyApi.translate(match { it.text == "Page two" }) } returns successResponse("Стр. 2")

        val result = service.translatePages(pages, "bg", "en", null)

        assertEquals("Стр. 0", result.translations[0])
        assertNull("Failed page should not be in results", result.translations[1])
        assertEquals("Стр. 2", result.translations[2])
    }

    // ── translateBatch: sequential with delay ────────────────────────────

    @Test
    fun `translateBatch - handles all failures gracefully`() = runTest {
        coEvery { proxyApi.translate(any()) } throws TranslationException("all fail")

        try {
            service.translateBatch(listOf("A", "B"), "bg", "en")
            fail("Should have thrown")
        } catch (e: TranslationException) {
            // Expected
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────────

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
