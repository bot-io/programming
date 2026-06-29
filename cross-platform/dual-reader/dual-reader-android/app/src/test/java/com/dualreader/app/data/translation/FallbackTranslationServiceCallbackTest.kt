package com.dualreader.app.data.translation

import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.impl.annotations.RelaxedMockK
import io.mockk.junit4.MockKRule
import io.mockk.mockk
import io.mockk.verify
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.runTest
import org.junit.Assert.*
import org.junit.Before
import org.junit.Rule
import org.junit.Test

/**
 * DR-147 regression tests: cloudUpgradeCallback invoked in Tier 3 fallback paths.
 *
 * Tests that the cloudUpgradeCallback is called when:
 * 1. ML Kit succeeds (Tier 1) - existing behavior
 * 2. ML Kit fails and cloud succeeds (Tier 3) - DR-147 fix
 * 3. translatePages Tier 3 fallback (ML Kit fails for all, cloud batch succeeds) - DR-147 fix
 */
class FallbackTranslationServiceCallbackTest {

    @get:Rule
    val mockkRule = MockKRule(this)

    @RelaxedMockK
    lateinit var cloudService: com.dualreader.app.domain.services.TranslationService

    @RelaxedMockK
    lateinit var mlKitService: com.dualreader.app.domain.services.TranslationService

    private lateinit var fallbackService: FallbackTranslationService
    private val testDispatcher = StandardTestDispatcher()

    @Before
    fun setup() {
        fallbackService = FallbackTranslationService(
            cloudService = cloudService,
            mlKitService = mlKitService,
        )
        FallbackTranslationService.testUpgradeDispatcher = testDispatcher
    }

    // ── translateSingle - Tier 1 (ML Kit success) callback ─────────────────────

    @Test
    fun `translateSingle Tier 1 - ML Kit success invokes callback`() = runTest(testDispatcher) {
        val callback = mockk<suspend (String, String, String) -> Unit>(relaxed = true)
        fallbackService.cloudUpgradeCallback = callback

        coEvery { mlKitService.translate("hello", "bg", null) } returns "здравей"
        coEvery {
            cloudService.translate("hello", "bg", null, any(), any(), any())
        } returns "здравей"

        val result = fallbackService.translate("hello", "bg")

        assertEquals("здравей", result)
        coVerify { mlKitService.translate("hello", "bg", null) }

        // Callback should be invoked (in background scope)
        testDispatcher.scheduler.advanceUntilIdle()
        coVerify { callback("hello", "здравей", "bg") }
    }

    // ── translateSingle - Tier 3 fallback callback (DR-147) ─────────────────────

    @Test
    fun `translateSingle Tier 3 - ML Kit fails, cloud succeeds, invokes callback`() = runTest(testDispatcher) {
        val callback = mockk<suspend (String, String, String) -> Unit>(relaxed = true)
        fallbackService.cloudUpgradeCallback = callback

        coEvery {
            mlKitService.translate("hello", "bg", null)
        } throws com.dualreader.app.domain.services.TranslationException("ML Kit error")
        coEvery {
            cloudService.translate("hello", "bg", null, null, null, false)
        } returns "здравей"

        val result = fallbackService.translate("hello", "bg")

        assertEquals("здравей", result)
        coVerify { mlKitService.translate("hello", "bg", null) }
        coVerify { cloudService.translate("hello", "bg", null, null, null, false) }

        // DR-147: Callback should be invoked even in Tier 3 fallback
        testDispatcher.scheduler.advanceUntilIdle()
        coVerify { callback("hello", "здравей", "bg") }
    }

    @Test
    fun `translateSingle Tier 3 - cloud fallback passes skipCache to callback`() = runTest(testDispatcher) {
        val callback = mockk<suspend (String, String, String) -> Unit>(relaxed = true)
        fallbackService.cloudUpgradeCallback = callback

        coEvery {
            mlKitService.translate("text", "es", "en")
        } throws com.dualreader.app.domain.services.TranslationException("ML Kit error")
        coEvery {
            cloudService.translate("text", "es", "en", null, null, true)
        } returns "texto"

        val result = fallbackService.translate("text", "es", "en", skipCache = true)

        assertEquals("texto", result)
        coVerify {
            cloudService.translate("text", "es", "en", null, null, skipCache = true)
        }

        testDispatcher.scheduler.advanceUntilIdle()
        coVerify { callback("text", "texto", "es") }
    }

    @Test
    fun `translateSingle Tier 3 - cloud fallback with context passes context to cloud`() = runTest {
        val callback = mockk<suspend (String, String, String) -> Unit>(relaxed = true)
        fallbackService.cloudUpgradeCallback = callback

        coEvery {
            mlKitService.translate(any(), any(), any())
        } throws com.dualreader.app.domain.services.TranslationException("ML Kit error")
        coEvery {
            cloudService.translate(
                text = "text",
                targetLanguage = "es",
                sourceLanguage = "en",
                context = match { it != null && it.contains("context") },
                bookContext = null,
                skipCache = false
            )
        } returns "texto"

        val result = fallbackService.translate("text", "es", "en", context = "context info")

        assertEquals("texto", result)
        coVerify {
            cloudService.translate(
                text = "text",
                targetLanguage = "es",
                sourceLanguage = "en",
                context = match { it != null && it.contains("context") },
                bookContext = null,
                skipCache = false
            )
        }
    }

    @Test
    fun `translateSingle Tier 3 - both ML Kit and cloud fail, no callback`() = runTest(testDispatcher) {
        var callbackInvoked = false
        val callback: suspend (String, String, String) -> Unit = { _, _, _ -> callbackInvoked = true }
        fallbackService.cloudUpgradeCallback = callback

        coEvery {
            mlKitService.translate(any(), any(), any())
        } throws com.dualreader.app.domain.services.TranslationException("ML Kit error")
        coEvery {
            cloudService.translate(any(), any(), any(), any(), any(), any())
        } throws com.dualreader.app.domain.services.TranslationException("Cloud error")

        assertThrows(com.dualreader.app.domain.services.TranslationException::class.java) {
            runBlocking { fallbackService.translate("hello", "bg") }
        }

        testDispatcher.scheduler.advanceUntilIdle()
        assertFalse("Callback should not be invoked when both ML Kit and cloud fail", callbackInvoked)
    }

    // ── translatePages - Tier 3 fallback callback (DR-147) ──────────────────────

    @Test
    fun `translatePages Tier 3 - all ML Kit fail, cloud batch succeeds, invokes callback for each`() = runTest(testDispatcher) {
        val callback = mockk<suspend (String, String, String) -> Unit>(relaxed = true)
        fallbackService.cloudUpgradeCallback = callback

        val pages = listOf(
            kotlin.collections.IndexedValue(0, "hello"),
            kotlin.collections.IndexedValue(1, "world"),
        )

        coEvery {
            mlKitService.translate(any(), any(), any())
        } throws com.dualreader.app.domain.services.TranslationException("ML Kit error")

        coEvery {
            cloudService.translatePages(any(), any(), any(), any(), any(), any())
        } returns com.dualreader.app.domain.services.BatchTranslationResult(
            translations = mapOf(0 to "здравей", 1 to "свет"),
            model = "cloud"
        )

        val result = fallbackService.translatePages(pages, "bg", null)

        assertEquals("здравей", result.translations[0])
        assertEquals("свет", result.translations[1])

        // DR-147: Callback should be invoked for each page in Tier 3 fallback
        testDispatcher.scheduler.advanceUntilIdle()
        coVerify { callback("hello", "здравей", "bg") }
        coVerify { callback("world", "свет", "bg") }
    }

    @Test
    fun `translatePages Tier 3 - cloud batch callback passes correct original text`() = runTest(testDispatcher) {
        val callback = mockk<suspend (String, String, String) -> Unit>(relaxed = true)
        fallbackService.cloudUpgradeCallback = callback

        val pages = listOf(
            kotlin.collections.IndexedValue(0, "first paragraph"),
            kotlin.collections.IndexedValue(1, "second paragraph"),
        )

        coEvery {
            mlKitService.translate(any(), any(), any())
        } throws com.dualreader.app.domain.services.TranslationException("ML Kit error")

        coEvery {
            cloudService.translatePages(any(), any(), any(), any(), any(), any())
        } returns com.dualreader.app.domain.services.BatchTranslationResult(
            translations = mapOf(0 to "първи параграф", 1 to "втори параграф"),
            model = "cloud"
        )

        fallbackService.translatePages(pages, "bg", null)

        testDispatcher.scheduler.advanceUntilIdle()
        coVerify { callback("first paragraph", "първи параграф", "bg") }
        coVerify { callback("second paragraph", "втори параграф", "bg") }
    }

    @Test
    fun `translatePages Tier 3 - cloud batch fails, no callback`() = runTest(testDispatcher) {
        var callbackInvoked = false
        val callback: suspend (String, String, String) -> Unit = { _, _, _ -> callbackInvoked = true }
        fallbackService.cloudUpgradeCallback = callback

        val pages = listOf(kotlin.collections.IndexedValue(0, "hello"))

        coEvery {
            mlKitService.translate(any(), any(), any())
        } throws com.dualreader.app.domain.services.TranslationException("ML Kit error")

        coEvery {
            cloudService.translatePages(any(), any(), any(), any(), any(), any())
        } throws com.dualreader.app.domain.services.TranslationException("Cloud error")

        assertThrows(com.dualreader.app.domain.services.TranslationException::class.java) {
            runBlocking { fallbackService.translatePages(pages, "bg", null) }
        }

        testDispatcher.scheduler.advanceUntilIdle()
        assertFalse("Callback should not be invoked when cloud batch fails", callbackInvoked)
    }

    @Test
    fun `translatePages Tier 3 - callback not invoked when callback is null`() = runTest {
        fallbackService.cloudUpgradeCallback = null

        val pages = listOf(kotlin.collections.IndexedValue(0, "hello"))

        coEvery {
            mlKitService.translate(any(), any(), any())
        } throws com.dualreader.app.domain.services.TranslationException("ML Kit error")

        coEvery {
            cloudService.translatePages(any(), any(), any(), any(), any(), any())
        } returns com.dualreader.app.domain.services.BatchTranslationResult(
            translations = mapOf(0 to "здравей"),
            model = "cloud"
        )

        val result = fallbackService.translatePages(pages, "bg", null)
        assertEquals("здравей", result.translations[0])
        // No crash when callback is null
    }
}