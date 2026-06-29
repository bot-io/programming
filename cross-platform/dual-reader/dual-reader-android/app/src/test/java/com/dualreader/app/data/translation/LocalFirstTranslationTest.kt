package com.dualreader.app.data.translation

import com.dualreader.app.domain.services.BatchTranslationResult
import com.dualreader.app.domain.services.TranslationException
import com.dualreader.app.domain.services.TranslationService
import com.dualreader.app.domain.usecases.SerializedBookContext
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.mockk
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.delay
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import kotlinx.coroutines.test.resetMain
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.Assert.*
import kotlin.collections.IndexedValue

/**
 * Tests for the local-first translation strategy (DR-108):
 * - ML Kit returns instantly, cloud upgrades in background
 * - Callback fires when cloud upgrade completes
 * - Tier 3 fallback: cloud direct when ML Kit unavailable
 * - translatePages: batch ML Kit + per-page cloud upgrade
 *
 * Token-efficient: all mocks, zero real API calls.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class LocalFirstTranslationTest {

    private lateinit var cloudService: TranslationService
    private lateinit var mlKitService: TranslationService
    private lateinit var service: FallbackTranslationService

    private val testDispatcher = StandardTestDispatcher()

    @Before
    fun setup() {
        Dispatchers.setMain(testDispatcher)
        FallbackTranslationService.testUpgradeDispatcher = testDispatcher
        cloudService = mockk(relaxed = true)
        mlKitService = mockk(relaxed = true)
        service = FallbackTranslationService(cloudService, mlKitService)
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
        FallbackTranslationService.testUpgradeDispatcher = null
    }

    // ── translate(): ML Kit instant → cloud background upgrade ──

    @Test
    fun `translate returns ML Kit result immediately`() = runTest {
        coEvery { mlKitService.translate(any(), any(), any()) } returns "instant-mlkit"
        coEvery { cloudService.translate(any(), any(), any(), any(), any(), any()) } returns "cloud-result"

        val result = service.translate("Hello", "bg", "en")

        assertEquals("instant-mlkit", result)
        coVerify { mlKitService.translate("Hello", "bg", "en") }
    }

    @Test
    fun `translate fires cloud upgrade callback when cloud completes`() = runTest {
        var upgradeText: String? = null
        var upgradeLang: String? = null

        service.cloudUpgradeCallback = { _, translation, lang ->
            upgradeText = translation
            upgradeLang = lang
        }

        coEvery { mlKitService.translate(any(), any(), any()) } returns "ml-kit-result"
        coEvery { cloudService.translate(any(), any(), any(), any(), any(), any()) } returns "cloud-result"

        service.translate("Hello", "bg", "en")
        advanceUntilIdle()

        assertEquals("cloud-result", upgradeText)
        assertEquals("bg", upgradeLang)
    }

    @Test
    fun `translate does not fire callback when callback is null`() = runTest {
        coEvery { mlKitService.translate(any(), any(), any()) } returns "ml-kit-result"
        coEvery { cloudService.translate(any(), any(), any(), any(), any(), any()) } returns "cloud-result"

        val result = service.translate("Hello", "bg", "en")
        advanceUntilIdle()

        assertEquals("ml-kit-result", result)
    }

    @Test
    fun `translate keeps ML Kit result when cloud upgrade fails`() = runTest {
        var upgradeFired = false
        service.cloudUpgradeCallback = { _, _, _ -> upgradeFired = true }

        coEvery { mlKitService.translate(any(), any(), any()) } returns "ml-kit-result"
        coEvery { cloudService.translate(any(), any(), any(), any(), any(), any()) } throws
            TranslationException("503 Service Unavailable")

        val result = service.translate("Hello", "bg", "en")
        advanceUntilIdle()

        assertEquals("ml-kit-result", result)
        assertFalse("Upgrade callback should NOT fire when cloud fails", upgradeFired)
    }

    // ── Tier 3: Cloud direct fallback when ML Kit unavailable ──

    @Test
    fun `translate falls back to cloud when ML Kit throws`() = runTest {
        coEvery { mlKitService.translate(any(), any(), any()) } throws
            TranslationException("ML Kit model not downloaded")
        coEvery { cloudService.translate(any(), any(), any(), any(), any(), any()) } returns "cloud-direct"

        val result = service.translate("Hello", "bg", "en")

        assertEquals("cloud-direct", result)
        coVerify { cloudService.translate("Hello", "bg", "en", any(), any(), any()) }
    }

    @Test
    fun `translate throws when both ML Kit and cloud fail`() = runTest {
        coEvery { mlKitService.translate(any(), any(), any()) } throws
            TranslationException("ML Kit error")
        coEvery { cloudService.translate(any(), any(), any(), any(), any(), any()) } throws
            TranslationException("503 error")

        try {
            service.translate("Hello", "bg", "en")
            fail("Should have thrown TranslationException")
        } catch (e: TranslationException) {
            assertTrue(e.message!!.contains("Both ML Kit and cloud"))
        }
    }

    // ── translatePages: batch ML Kit + per-page cloud upgrade ──

    @Test
    fun `translatePages returns ML Kit results instantly for all pages`() = runTest {
        val pages = listOf(
            IndexedValue(0, "Page zero text"),
            IndexedValue(1, "Page one text"),
            IndexedValue(2, "Page two text"),
        )

        coEvery { mlKitService.translate(any(), any(), any()) } returnsMany listOf(
            "стр.0", "стр.1", "стр.2"
        )
        coEvery { cloudService.translate(any(), any(), any(), any(), any(), any()) } returns "cloud"

        val result: BatchTranslationResult = service.translatePages(pages, "bg", "en", null, null, false)

        assertEquals(3, result.translations.size)
        assertEquals("стр.0", result.translations[0])
        assertEquals("стр.1", result.translations[1])
        assertEquals("стр.2", result.translations[2])
    }

    @Test
    fun `translatePages fires cloud upgrade for each page`() = runTest {
        val pages = listOf(
            IndexedValue(0, "Page zero"),
            IndexedValue(1, "Page one"),
        )
        val upgrades = mutableMapOf<String, String>()

        service.cloudUpgradeCallback = { original, translation, _ ->
            upgrades[original] = translation
        }

        coEvery { mlKitService.translate(any(), any(), any()) } returns "mlkit"
        coEvery { cloudService.translate(any(), any(), any(), any(), any(), any()) } returnsMany listOf(
            "cloud-0", "cloud-1"
        )

        service.translatePages(pages, "bg", "en", null, null, false)
        advanceUntilIdle()

        assertEquals("cloud-0", upgrades["Page zero"])
        assertEquals("cloud-1", upgrades["Page one"])
    }

    @Test
    fun `translatePages returns partial ML Kit results when some pages fail`() = runTest {
        val pages = listOf(
            IndexedValue(0, "Page zero"),
            IndexedValue(1, "Page one"),
        )

        coEvery { mlKitService.translate("Page zero", any(), any()) } returns "mlkit-0"
        coEvery { mlKitService.translate("Page one", any(), any()) } throws TranslationException("ML Kit failed")

        val result: BatchTranslationResult = service.translatePages(pages, "bg", "en", null, null, false)

        assertEquals(1, result.translations.size)
        assertEquals("mlkit-0", result.translations[0])
    }

    @Test
    fun `translatePages falls back to cloud batch when all ML Kit fails`() = runTest {
        val pages = listOf(
            IndexedValue(0, "Page zero"),
            IndexedValue(1, "Page one"),
        )

        coEvery { mlKitService.translate(any(), any(), any()) } throws TranslationException("no model")
        coEvery { cloudService.translatePages(any(), any(), any(), any(), any(), any()) } returns
            BatchTranslationResult(mapOf(0 to "cloud-0", 1 to "cloud-1"), "gemini")

        val result: BatchTranslationResult = service.translatePages(pages, "bg", "en", null, null, false)

        assertEquals(2, result.translations.size)
        assertEquals("cloud-0", result.translations[0])
        assertEquals("cloud-1", result.translations[1])
    }

    @Test
    fun `translatePages throws when all tiers fail`() = runTest {
        val pages = listOf(IndexedValue(0, "Page zero"))

        coEvery { mlKitService.translate(any(), any(), any()) } throws TranslationException("mlkit fail")
        coEvery { cloudService.translatePages(any(), any(), any(), any(), any(), any()) } throws
            TranslationException("cloud fail")

        try {
            service.translatePages(pages, "bg", "en", null, null, false)
            fail("Should have thrown")
        } catch (e: TranslationException) {
            assertTrue(e.message!!.contains("Both ML Kit and cloud"))
        }
    }

    @Test
    fun `translatePages with empty pages returns empty result`() = runTest {
        val result: BatchTranslationResult = service.translatePages(emptyList(), "bg", "en", null, null, false)
        assertTrue(result.translations.isEmpty())
    }

    // ── Chunking: multi-chunk text splits across ML Kit calls ──

    @Test
    fun `long text splits into chunks and each gets ML Kit translation`() = runTest {
        val longParagraph = "A".repeat(800)
        val text = "$longParagraph\n\n$longParagraph"

        coEvery { mlKitService.translate(any(), any(), any()) } returns "chunk-result"

        val result = service.translate(text, "bg", "en")

        assertTrue(result.contains("chunk-result"))
        coVerify(atLeast = 2) { mlKitService.translate(any(), "bg", "en") }
    }
}
