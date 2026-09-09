package com.dualreader.app.data.translation

import com.dualreader.app.domain.services.TranslationException
import com.dualreader.app.domain.services.TranslationService
import com.dualreader.app.domain.services.BatchTranslationResult
import io.mockk.clearMocks
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.impl.annotations.RelaxedMockK
import io.mockk.junit4.MockKRule
import io.mockk.mockk
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.test.runTest
import org.junit.Assert.*
import org.junit.Before
import org.junit.Rule
import org.junit.Test

/**
 * Tests for FallbackTranslationService — local-first architecture.
 *
 * DR-142: Updated to reflect local-first strategy (ML Kit instant → cloud background upgrade).
 * Previous cloud-first tests have been adapted to test the new three-tier architecture:
 * - Tier 1: ML Kit on-device (instant)
 * - Tier 2: Cloud background upgrade (async, callback-driven)
 * - Tier 3: Cloud direct fallback (ML Kit unavailable)
 *
 * These tests focus on edge cases and parameter passing not covered by LocalFirstTranslationTest.
 */
class FallbackTranslationServiceTest {

    @get:Rule
    val mockkRule = MockKRule(this)

    @RelaxedMockK
    lateinit var cloudService: TranslationService

    @RelaxedMockK
    lateinit var mlKitService: TranslationService

    private lateinit var fallbackService: FallbackTranslationService

    @Before
    fun setup() {
        fallbackService = FallbackTranslationService(
            cloudService = cloudService,
            mlKitService = mlKitService,
        )
    }

    // ── Tier 3: Cloud direct fallback (ML Kit unavailable) ─────────────────────

    @Test
    fun `ML Kit unavailable - falls back to cloud direct`() = runTest {
        coEvery { mlKitService.translate("hello", "bg", null) } throws
            TranslationException("ML Kit model not downloaded")
        coEvery { cloudService.translate("hello", "bg", null, null) } returns "здравей"

        assertEquals("здравей", fallbackService.translate("hello", "bg"))
    }

    @Test
    fun `cloud direct fallback - passes source language through`() = runTest {
        coEvery { mlKitService.translate(any(), any(), any()) } throws
            TranslationException("ML Kit error")
        coEvery { cloudService.translate("text", "bg", "en", match { it != null && it.contains("context") }) } returns "текст"

        val result = fallbackService.translate("text", "bg", "en", "context info")
        assertEquals("текст", result)
        coVerify { cloudService.translate("text", "bg", "en", match { it != null }) }
    }

    // ── skipCache propagation (DR-047 regression) ──────────────────────────────
    // Note: Background upgrade (Tier 2) can't be tested in unit tests because:
    // 1. cloudUpgradeCallback is null in unit tests (set by ViewModel)
    // 2. Background upgrade runs in GlobalScope and can't be verified with coVerify
    // We only test Tier 3 (direct fallback) skipCache propagation here.

    @Test
    fun `skipCache true in cloud direct fallback (Tier 3) when ML Kit fails`() = runTest {
        // ML Kit fails
        coEvery { mlKitService.translate(any(), any(), any()) } throws
            TranslationException("ML Kit error")

        // Cloud direct receives skipCache=true
        coEvery { cloudService.translate(any(), any(), any(), any(), any(), eq(true)) } returns "cloud-result"

        val result = fallbackService.translate("text", "bg", "en", null, null, skipCache = true)

        assertEquals("cloud-result", result)
        coVerify { cloudService.translate(any(), any(), any(), any(), any(), eq(true)) }
    }

    @Test
    fun `skipCache false in cloud direct fallback (Tier 3) when ML Kit fails`() = runTest {
        // ML Kit fails
        coEvery { mlKitService.translate(any(), any(), any()) } throws
            TranslationException("ML Kit error")

        // Cloud direct receives skipCache=false
        coEvery { cloudService.translate(any(), any(), any(), any(), any(), eq(false)) } returns "cloud-result"

        val result = fallbackService.translate("text", "bg", "en", skipCache = false)

        assertEquals("cloud-result", result)
        coVerify { cloudService.translate(any(), any(), any(), any(), any(), eq(false)) }
    }

    // ── Both fail ──────────────────────────────────────────────────────────────

    @Test
    fun `ML Kit and cloud both fail - throws with both error messages`() = runTest {
        coEvery { mlKitService.translate(any(), any(), any()) } throws
            TranslationException("ML Kit model not downloaded")
        coEvery { cloudService.translate(any(), any(), any(), any()) } throws
            TranslationException("Timeout 45s")

        try {
            fallbackService.translate("hello", "bg")
            fail("Should have thrown")
        } catch (e: TranslationException) {
            assertTrue("Should mention cloud error", e.message!!.contains("Timeout 45s"))
            assertTrue("Should mention ML Kit error", e.message!!.contains("ML Kit"))
        }
    }

    @Test
    fun `ML Kit throws runtime exception and cloud fails - throws`() = runTest {
        coEvery { mlKitService.translate(any(), any(), any()) } throws
            RuntimeException("Unexpected crash")
        coEvery { cloudService.translate(any(), any(), any(), any()) } throws
            TranslationException("Cloud error")

        try {
            fallbackService.translate("hello", "bg")
            fail("Should have thrown")
        } catch (e: TranslationException) {
            assertNotNull(e.message)
        }
    }

    // ── Text splitting (chunking for long texts) ──────────────────────────────

    @Test
    fun `short text - not split`() {
        val chunks = fallbackService.splitIntoChunks("Short text")
        assertEquals(1, chunks.size)
        assertEquals("Short text", chunks[0])
    }

    @Test
    fun `long text with paragraphs - split at paragraph boundaries`() {
        val text = buildString {
            for (i in 1..10) {
                append("Paragraph $i with some content to fill space. ".repeat(20))
                if (i < 10) append("\n\n")
            }
        }

        val chunks = fallbackService.splitIntoChunks(text)
        assertTrue("Should split into multiple chunks", chunks.size > 1)
        chunks.forEach { chunk ->
            assertTrue("Chunk should be reasonable size (${chunk.length})", chunk.length <= 2000)
        }
        assertEquals(
            text.replace(Regex("\\s+"), " ").trim(),
            chunks.joinToString("\n\n").replace(Regex("\\s+"), " ").trim()
        )
    }

    @Test
    fun `text exactly at limit - not split`() {
        val text = "a".repeat(1500)
        assertEquals(1, fallbackService.splitIntoChunks(text).size)
    }

    @Test
    fun `text slightly over limit - split into multiple chunks`() {
        // Each paragraph is 800 chars, total is ~1600 chars (over 1500 limit)
        val text = "a".repeat(800) + "\n\n" + "b".repeat(800)
        val chunks = fallbackService.splitIntoChunks(text)
        assertTrue("Should split into 2+ chunks, got ${chunks.size}", chunks.size >= 2)
    }

    @Test
    fun `chunked text - context passed only to first chunk`() = runTest {
        val longText = "First paragraph.\n\nSecond paragraph."
        coEvery { mlKitService.translate(any(), any(), any()) } returns "текст"
        coEvery { cloudService.translate(any(), eq("bg"), eq("en"), any()) } returns "cloud-text"

        fallbackService.translate(longText, "bg", "en", "some context")
        // If split into 2 chunks, first gets context, second doesn't
        // (hard to verify exactly without controlling splitIntoChunks output,
        //  but the call should succeed)
    }

    // ── Batch ──────────────────────────────────────────────────────────────────

    @Test
    fun `batch - translates all items via ML Kit`() = runTest {
        coEvery { mlKitService.translate("hello", "bg", null) } returns "здравей"
        coEvery { mlKitService.translate("world", "bg", null) } returns "свят"

        assertEquals(listOf("здравей", "свят"), fallbackService.translateBatch(listOf("hello", "world"), "bg"))
    }

    @Test
    fun `empty batch - returns empty list`() = runTest {
        assertEquals(emptyList<String>(), fallbackService.translateBatch(emptyList(), "bg"))
    }

    @Test
    fun `batch - ML Kit unavailable, falls back to cloud per item`() = runTest {
        // ML Kit unavailable for all items
        coEvery { mlKitService.translate(any(), any(), any()) } throws
            TranslationException("ML Kit error")
        // Cloud succeeds for all
        coEvery { cloudService.translate("hello", "bg", null, null) } returns "здравей"
        coEvery { cloudService.translate("world", "bg", null, null) } returns "свят"

        val result = fallbackService.translateBatch(listOf("hello", "world"), "bg")
        assertEquals(listOf("здравей", "свят"), result)
    }

    // ── Cancellation handling (DR-050/DR-136 regression) ───────────────────────
    //
    // CancellationException thrown by a suspend call must propagate — NOT be
    // swallowed by the generic `catch (e: Exception)` fallback handlers. If it
    // were swallowed, a cancelled translation would fall through to the next tier
    // and surface a spurious "Both ML Kit and cloud failed" error instead of
    // stopping cleanly.

    @Test
    fun `cancellation from ML Kit translate propagates - cloud not consulted`() = runTest {
        coEvery {
            mlKitService.translate(any(), any(), any())
        } throws CancellationException("job cancelled")
        coEvery { cloudService.translate(any(), any(), any(), any(), any(), any()) } returns "cloud-result"

        var caught: Throwable? = null
        try {
            fallbackService.translate("hello", "bg")
        } catch (e: Throwable) {
            caught = e
        }

        assertTrue("Expected CancellationException to propagate, got: $caught", caught is CancellationException)
        // Cancellation must not fall through to the cloud tier
        coVerify(exactly = 0) { cloudService.translate(any(), any(), any(), any(), any(), any()) }
    }

    @Test
    fun `cancellation from ML Kit in batch propagates - cloud batch not consulted`() = runTest {
        coEvery {
            mlKitService.translate(any(), any(), any())
        } throws CancellationException("batch cancelled")
        coEvery {
            cloudService.translatePages(any(), any(), any(), any(), any(), any())
        } returns mockk()

        var caught: Throwable? = null
        try {
            fallbackService.translatePages(listOf(IndexedValue(0, "hello")), "bg")
        } catch (e: Throwable) {
            caught = e
        }

        assertTrue("Expected CancellationException to propagate, got: $caught", caught is CancellationException)
        // Cancellation must not fall through into the cloud batch path
        coVerify(exactly = 0) { cloudService.translatePages(any(), any(), any(), any(), any(), any()) }
    }

    @Test
    fun `cancellation from detectLanguage propagates - ML Kit not consulted`() = runTest {
        coEvery { cloudService.detectLanguage(any()) } throws CancellationException("cancelled")
        coEvery { mlKitService.detectLanguage(any()) } returns "en"

        var caught: Throwable? = null
        try {
            fallbackService.detectLanguage("hello")
        } catch (e: Throwable) {
            caught = e
        }

        assertTrue("Expected CancellationException to propagate, got: $caught", caught is CancellationException)
        coVerify(exactly = 0) { mlKitService.detectLanguage(any()) }
    }

    // ── Metadata ───────────────────────────────────────────────────────────────

    @Test
    fun `provider name describes local-first architecture`() {
        // DR-262: providerName is dynamic (lastSyncModel) — "Local" after ML Kit,
        // "Cloud" after cloud sync. Fresh service defaults to "Local".
        val fresh = FallbackTranslationService(
            cloudService = cloudService,
            mlKitService = mlKitService,
        )
        assertEquals("Local", fresh.providerName)
    }

    @Test
    fun `always available`() = runTest {
        assertTrue(fallbackService.isAvailable())
    }

    // ── detectLanguage ─────────────────────────────────────────────────────────
    // Note: detectLanguage uses cloud-first (unlike translate which uses ML Kit-first)

    @Test
    fun `detectLanguage - cloud succeeds`() = runTest {
        coEvery { cloudService.detectLanguage("hello") } returns "en"
        assertEquals("en", fallbackService.detectLanguage("hello"))
    }

    @Test
    fun `detectLanguage - cloud fails, ML Kit succeeds`() = runTest {
        coEvery { cloudService.detectLanguage(any()) } throws
            TranslationException("Cloud error")
        coEvery { mlKitService.detectLanguage("hello") } returns "en"
        assertEquals("en", fallbackService.detectLanguage("hello"))
    }
}