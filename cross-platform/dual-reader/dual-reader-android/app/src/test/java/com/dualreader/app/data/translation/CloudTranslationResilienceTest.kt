package com.dualreader.app.data.translation

import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import com.dualreader.app.domain.services.BatchTranslationResult
import com.dualreader.app.domain.services.TranslationException
import com.dualreader.app.domain.usecases.SerializedBookContext
import io.mockk.coEvery
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import kotlinx.coroutines.test.resetMain
import okhttp3.ResponseBody.Companion.toResponseBody
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.Assert.*
import retrofit2.Response

/**
 * Tests for cloud translation resilience:
 * - Batch endpoint success → returns batch results
 * - Batch endpoint failure → falls back to single-page translation
 * - Partial results returned when some single-page translations succeed
 * - All methods fail → throws exception
 *
 * No real API calls — all mocked.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class CloudTranslationResilienceTest {

    private val testDispatcher = StandardTestDispatcher()

    private lateinit var proxyApi: ProxyTranslationApi
    private lateinit var connectivityManager: ConnectivityManager
    private lateinit var installationIdProvider: InstallationIdProvider
    private lateinit var service: CloudTranslationServiceImpl

    @Before
    fun setup() {
        Dispatchers.setMain(testDispatcher)

        proxyApi = mockk()
        connectivityManager = mockk()
        installationIdProvider = mockk()

        // Network always available
        val network = mockk<Network>()
        val capabilities = mockk<NetworkCapabilities>()
        every { connectivityManager.activeNetwork } returns network
        every { connectivityManager.getNetworkCapabilities(network) } returns capabilities
        every { capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) } returns true

        coEvery { installationIdProvider.getInstallationId() } returns "test-install-001"

        service = CloudTranslationServiceImpl(proxyApi, connectivityManager, installationIdProvider)
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    // ── Batch Success ──────────────────────────────────────────────────────

    @Test
    fun `batch endpoint success returns all translations`() = runTest(testDispatcher) {
        val pages = listOf(
            IndexedValue(0, "Hello"),
            IndexedValue(1, "World"),
        )

        val batchResponse = ProxyBatchTranslateResponse(
            translations = listOf(
                BatchTranslation(index = 0, translatedText = "Здравей"),
                BatchTranslation(index = 1, translatedText = "Свят"),
            ),
            model = "gemini-2.5-flash",
        )
        coEvery { proxyApi.translateBatch(any()) } returns Response.success(batchResponse)

        val result = service.translatePages(pages, "bg", "en", null, null, false)
        advanceUntilIdle()

        assertEquals(2, result.translations.size)
        assertEquals("Здравей", result.translations[0])
        assertEquals("Свят", result.translations[1])
        assertEquals("gemini-2.5-flash", result.model)
    }

    // ── Batch Failure → Single Fallback ────────────────────────────────────

    @Test
    fun `batch failure falls back to single-page translation`() = runTest(testDispatcher) {
        val pages = listOf(
            IndexedValue(0, "Hello"),
            IndexedValue(1, "World"),
        )

        // Batch endpoint fails with 502
        val errorResponse = retrofit2.Response.error<ProxyBatchTranslateResponse>(
            502, """{"error":"all providers failed"}""".toResponseBody(null)
        )
        coEvery { proxyApi.translateBatch(any()) } returns errorResponse

        // Single translate succeeds for both pages
        coEvery { proxyApi.translate(any()) } returnsMany listOf(
            Response.success(ProxyTranslateResponse(translatedText = "Здравей", model = "glm")),
            Response.success(ProxyTranslateResponse(translatedText = "Свят", model = "glm")),
        )

        val result = service.translatePages(pages, "bg", "en", null, null, false)
        advanceUntilIdle()

        assertEquals(2, result.translations.size)
        assertEquals("Здравей", result.translations[0])
        assertEquals("Свят", result.translations[1])
    }

    @Test
    fun `batch failure with partial single fallback returns partial results`() = runTest(testDispatcher) {
        val pages = listOf(
            IndexedValue(0, "Hello"),
            IndexedValue(1, "World"),
            IndexedValue(2, "Test"),
        )

        // Batch endpoint fails
        val errorResponse = retrofit2.Response.error<ProxyBatchTranslateResponse>(
            502, """{"error":"overloaded"}""".toResponseBody(null)
        )
        coEvery { proxyApi.translateBatch(any()) } returns errorResponse

        // Page 0 succeeds, page 1 fails (429), page 2 succeeds
        val successResp = Response.success(ProxyTranslateResponse(translatedText = "Здравей", model = "glm"))
        val rateLimitResp = retrofit2.Response.error<ProxyTranslateResponse>(
            429, """{"error":"rate limited"}""".toResponseBody(null)
        )
        val successResp2 = Response.success(ProxyTranslateResponse(translatedText = "Проба", model = "glm"))

        // Page 0 succeeds (1 call), page 1 fails after 3×429 retry (3 calls), page 2 succeeds (1 call)
        coEvery { proxyApi.translate(any()) } returnsMany listOf(
            successResp,                                              // page 0: 1 call → success
            rateLimitResp, rateLimitResp, rateLimitResp,            // page 1: 3 calls → all 429 → throws
            successResp2,                                             // page 2: 1 call → success
        )

        val result = service.translatePages(pages, "bg", "en", null, null, false)
        advanceUntilIdle()

        // Should have 2 out of 3 (partial results, not crash)
        assertEquals(2, result.translations.size)
        assertEquals("Здравей", result.translations[0])
        assertEquals("Проба", result.translations[2])
        assertNull(result.translations[1])
    }

    // ── Total Failure ───────────────────────────────────────────────────────

    @Test(expected = TranslationException::class)
    fun `all methods fail throws exception`() = runTest(testDispatcher) {
        val pages = listOf(IndexedValue(0, "Hello"))

        // Batch fails
        val errorResponse = retrofit2.Response.error<ProxyBatchTranslateResponse>(
            502, """{"error":"down"}""".toResponseBody(null)
        )
        coEvery { proxyApi.translateBatch(any()) } returns errorResponse

        // Single also fails (3 retries × 429)
        val rateLimitResp = retrofit2.Response.error<ProxyTranslateResponse>(
            429, """{"error":"rate limited"}""".toResponseBody(null)
        )
        coEvery { proxyApi.translate(any()) } returns rateLimitResp

        service.translatePages(pages, "bg", "en", null, null, false)
        advanceUntilIdle()
    }

    // ── Empty Pages ─────────────────────────────────────────────────────────

    @Test
    fun `empty pages list returns empty result`() = runTest(testDispatcher) {
        val result = service.translatePages(emptyList(), "bg", "en", null, null, false)
        advanceUntilIdle()

        assertTrue(result.translations.isEmpty())
    }

    // ── Single Page Batch ───────────────────────────────────────────────────

    @Test
    fun `single page batch returns result`() = runTest(testDispatcher) {
        val pages = listOf(IndexedValue(5, "Hello"))

        val batchResponse = ProxyBatchTranslateResponse(
            translations = listOf(BatchTranslation(index = 5, translatedText = "Здравей")),
            model = "gemini-2.5-flash",
        )
        coEvery { proxyApi.translateBatch(any()) } returns Response.success(batchResponse)

        val result = service.translatePages(pages, "bg", "en", null, null, false)
        advanceUntilIdle()

        assertEquals(1, result.translations.size)
        assertEquals("Здравей", result.translations[5])
    }

    // ── Batch Returns Error in Body ────────────────────────────────────────

    @Test
    fun `batch returns error field in body falls back to single`() = runTest(testDispatcher) {
        val pages = listOf(IndexedValue(0, "Hello"))

        // Batch endpoint returns 200 but with error field
        val batchResponse = ProxyBatchTranslateResponse(
            translations = emptyList(),
            error = "All providers failed",
        )
        coEvery { proxyApi.translateBatch(any()) } returns Response.success(batchResponse)

        // Single translate succeeds
        coEvery { proxyApi.translate(any()) } returns Response.success(
            ProxyTranslateResponse(translatedText = "Здравей", model = "glm")
        )

        val result = service.translatePages(pages, "bg", "en", null, null, false)
        advanceUntilIdle()

        assertEquals(1, result.translations.size)
        assertEquals("Здравей", result.translations[0])
    }
}
