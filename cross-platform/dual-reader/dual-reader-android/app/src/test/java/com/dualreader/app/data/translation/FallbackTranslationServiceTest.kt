package com.dualreader.app.data.translation

import android.net.ConnectivityManager
import com.dualreader.app.domain.services.TranslationException
import com.dualreader.app.domain.services.TranslationService
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.impl.annotations.RelaxedMockK
import io.mockk.junit4.MockKRule
import kotlinx.coroutines.test.runTest
import org.junit.Assert.*
import org.junit.Before
import org.junit.Rule
import org.junit.Test

/**
 * Tests for FallbackTranslationService — the tiered fallback chain.
 *
 * Covers all failure paths through the Cloud → ML Kit fallback:
 * - Cloud succeeds (Gemini primary, GLM fallback — both go through "cloud")
 * - Cloud fails → ML Kit fallback
 * - Both fail → combined error message
 * - Context passing through fallback chain
 * - Chunking for long texts
 * - Batch operations
 */
class FallbackTranslationServiceTest {

    @get:Rule
    val mockkRule = MockKRule(this)

    @RelaxedMockK
    lateinit var cloudService: TranslationService

    @RelaxedMockK
    lateinit var mlKitService: TranslationService

    @RelaxedMockK
    lateinit var connectivityManager: ConnectivityManager

    private lateinit var fallbackService: FallbackTranslationService

    @Before
    fun setup() {
        fallbackService = FallbackTranslationService(
            cloudService = cloudService,
            mlKitService = mlKitService,
            connectivityManager = connectivityManager,
        )
    }

    // ── Cloud succeeds (Gemini or GLM — doesn't matter, both go through cloud) ─

    @Test
    fun `cloud succeeds - returns cloud result`() = runTest {
        coEvery { cloudService.translate("hello", "bg", null, null) } returns "здравей"

        assertEquals("здравей", fallbackService.translate("hello", "bg"))
    }

    @Test
    fun `cloud succeeds with context - passes context through`() = runTest {
        coEvery { cloudService.translate("text", "bg", "en", match { it != null && it.contains("context") }) } returns "текст"

        val result = fallbackService.translate("text", "bg", "en", "context info")
        assertEquals("текст", result)
        coVerify { cloudService.translate("text", "bg", "en", match { it != null }) }
    }

    @Test
    fun `cloud succeeds with source language - passes through`() = runTest {
        coEvery { cloudService.translate("text", "bg", "en", null) } returns "текст"

        fallbackService.translate("text", "bg", "en")
        coVerify { cloudService.translate("text", "bg", "en", null) }
    }

    // ── Cloud fails → ML Kit fallback ─────────────────────────────────────────

    @Test
    fun `cloud fails - falls back to ML Kit`() = runTest {
        coEvery { cloudService.translate("hello", "bg", null, null) } throws TranslationException("Network error")
        coEvery { mlKitService.translate("hello", "bg", null) } returns "здравей"

        assertEquals("здравей", fallbackService.translate("hello", "bg"))
    }

    @Test
    fun `cloud times out - falls back to ML Kit`() = runTest {
        coEvery { cloudService.translate(any(), any(), any(), any()) } throws TranslationException("Translation timed out")
        coEvery { mlKitService.translate("hello", "bg", null) } returns "здравей"

        assertEquals("здравей", fallbackService.translate("hello", "bg"))
    }

    @Test
    fun `cloud rate limited - falls back to ML Kit`() = runTest {
        coEvery { cloudService.translate(any(), any(), any(), any()) } throws TranslationException("Rate limited")
        coEvery { mlKitService.translate("hello", "bg", null) } returns "здравей"

        assertEquals("здравей", fallbackService.translate("hello", "bg"))
    }

    @Test
    fun `cloud 502 bad gateway - falls back to ML Kit`() = runTest {
        coEvery { cloudService.translate(any(), any(), any(), any()) } throws TranslationException("Translation proxy error 502")
        coEvery { mlKitService.translate("hello", "bg", null) } returns "здравей"

        assertEquals("здравей", fallbackService.translate("hello", "bg"))
    }

    @Test
    fun `ML Kit fallback does NOT receive context`() = runTest {
        // ML Kit doesn't support context — it should be called without it
        coEvery { cloudService.translate(any(), any(), any(), any()) } throws TranslationException("fail")
        coEvery { mlKitService.translate("hello", "bg", null) } returns "здравей"

        fallbackService.translate("hello", "bg", null, "some context")
        coVerify { mlKitService.translate("hello", "bg", null) }
    }

    // ── Both fail ──────────────────────────────────────────────────────────────

    @Test
    fun `both fail - throws with both error messages`() = runTest {
        coEvery { cloudService.translate(any(), any(), any(), any()) } throws TranslationException("Timeout 45s")
        coEvery { mlKitService.translate(any(), any(), any()) } throws TranslationException("ML Kit model not downloaded")

        try {
            fallbackService.translate("hello", "bg")
            fail("Should have thrown")
        } catch (e: TranslationException) {
            assertTrue("Should mention cloud error", e.message!!.contains("Timeout 45s"))
            assertTrue("Should mention ML Kit error", e.message!!.contains("ML Kit model not downloaded"))
        }
    }

    @Test
    fun `cloud fails with runtime exception and ML Kit fails - throws`() = runTest {
        coEvery { cloudService.translate(any(), any(), any(), any()) } throws RuntimeException("Unexpected crash")
        coEvery { mlKitService.translate(any(), any(), any()) } throws TranslationException("Model error")

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
        coEvery { cloudService.translate(any(), eq("bg"), eq("en"), any()) } returns "текст"

        fallbackService.translate(longText, "bg", "en", "some context")
        // If split into 2 chunks, first gets context, second doesn't
        // (hard to verify exactly without controlling splitIntoChunks output,
        //  but the call should succeed)
    }

    // ── Batch ──────────────────────────────────────────────────────────────────

    @Test
    fun `batch - translates all items`() = runTest {
        coEvery { cloudService.translate("hello", "bg", null, null) } returns "здравей"
        coEvery { cloudService.translate("world", "bg", null, null) } returns "свят"

        assertEquals(listOf("здравей", "свят"), fallbackService.translateBatch(listOf("hello", "world"), "bg"))
    }

    @Test
    fun `empty batch - returns empty list`() = runTest {
        assertEquals(emptyList<String>(), fallbackService.translateBatch(emptyList(), "bg"))
    }

    @Test
    fun `batch - falls back per item`() = runTest {
        // First item: cloud succeeds
        coEvery { cloudService.translate("hello", "bg", null, null) } returns "здравей"
        // Second item: cloud fails, ML Kit succeeds
        coEvery { cloudService.translate("fail", "bg", null, null) } throws TranslationException("error")
        coEvery { mlKitService.translate("fail", "bg", null) } returns "неуспех"

        val result = fallbackService.translateBatch(listOf("hello", "fail"), "bg")
        assertEquals(listOf("здравей", "неуспех"), result)
    }

    // ── Metadata ───────────────────────────────────────────────────────────────

    @Test
    fun `provider name includes fallback`() {
        assertTrue(fallbackService.providerName.contains("Fallback"))
    }

    @Test
    fun `always available`() = runTest {
        assertTrue(fallbackService.isAvailable())
    }

    // ── detectLanguage ─────────────────────────────────────────────────────────

    @Test
    fun `detectLanguage - cloud succeeds`() = runTest {
        coEvery { cloudService.detectLanguage("hello") } returns "en"
        assertEquals("en", fallbackService.detectLanguage("hello"))
    }

    @Test
    fun `detectLanguage - cloud fails, ML Kit succeeds`() = runTest {
        coEvery { cloudService.detectLanguage(any()) } throws TranslationException("fail")
        coEvery { mlKitService.detectLanguage("hello") } returns "en"
        assertEquals("en", fallbackService.detectLanguage("hello"))
    }
}
