package com.dualreader.app.data.translation

import android.net.ConnectivityManager
import com.dualreader.app.domain.services.BatchTranslationResult
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
 * Tests for FallbackTranslationService.translatePages — the batch optimization
 * with cloud-first and ML Kit gap filling.
 *
 * Covers:
 * - Cloud batch succeeds for all pages
 * - Cloud batch partially succeeds → ML Kit fills gaps
 * - Cloud batch fails → individual fallback through full chain
 * - Empty input
 * - Single page
 */
class FallbackTranslationServiceTranslatePagesTest {

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

    // ── Cloud batch succeeds for all pages ────────────────────────────────

    @Test
    fun `translatePages - cloud batch succeeds for all pages`() = runTest {
        val pages = listOf(
            IndexedValue(0, "Page 0"),
            IndexedValue(1, "Page 1"),
        )

        coEvery {
            cloudService.translatePages(any(), "bg", "en", any())
        } returns BatchTranslationResult(mapOf(0 to "Стр. 0", 1 to "Стр. 1"), "gemini-2.5-flash")

        val result = fallbackService.translatePages(pages, "bg", "en", null)

        assertEquals("Стр. 0", result.translations[0])
        assertEquals("Стр. 1", result.translations[1])
        assertEquals("gemini-2.5-flash", result.model)

        // ML Kit should NOT be called
        coVerify(exactly = 0) { mlKitService.translate(any(), any(), any(), any()) }
    }

    @Test
    fun `translatePages - cloud batch with non-sequential indices`() = runTest {
        val pages = listOf(
            IndexedValue(5, "Five"),
            IndexedValue(10, "Ten"),
        )

        coEvery {
            cloudService.translatePages(any(), "bg", "en", any())
        } returns BatchTranslationResult(mapOf(5 to "Пет", 10 to "Десет"), "gemini-2.5-flash")

        val result = fallbackService.translatePages(pages, "bg", "en", null)

        assertEquals(setOf(5, 10), result.translations.keys)
        assertEquals("Пет", result.translations[5])
        assertEquals("Десет", result.translations[10])
    }

    // ── Cloud batch partial success → ML Kit fills gaps ───────────────────

    @Test
    fun `translatePages - cloud returns partial results, ML Kit fills gaps`() = runTest {
        val pages = listOf(
            IndexedValue(0, "Page 0"),
            IndexedValue(1, "Page 1"),
            IndexedValue(2, "Page 2"),
        )

        // Cloud returns only page 0 and 2, missing page 1
        coEvery {
            cloudService.translatePages(any(), "bg", "en", any())
        } returns BatchTranslationResult(mapOf(0 to "Стр. 0", 2 to "Стр. 2"), "gemini-2.5-flash")

        // ML Kit fills page 1
        coEvery { mlKitService.translate("Page 1", "bg", "en") } returns "Стр. 1 ML"

        val result = fallbackService.translatePages(pages, "bg", "en", null)

        assertEquals("Стр. 0", result.translations[0])
        assertEquals("Стр. 1 ML", result.translations[1])
        assertEquals("Стр. 2", result.translations[2])
    }

    @Test
    fun `translatePages - cloud returns only one of three pages, ML Kit fills two`() = runTest {
        val pages = listOf(
            IndexedValue(0, "A"),
            IndexedValue(1, "B"),
            IndexedValue(2, "C"),
        )

        coEvery {
            cloudService.translatePages(any(), "bg", "en", any())
        } returns BatchTranslationResult(mapOf(1 to "Б"), "glm-4.7-flash")

        coEvery { mlKitService.translate("A", "bg", "en") } returns "А (ML)"
        coEvery { mlKitService.translate("C", "bg", "en") } returns "Ц (ML)"

        val result = fallbackService.translatePages(pages, "bg", "en", null)

        assertEquals("А (ML)", result.translations[0])
        assertEquals("Б", result.translations[1])
        assertEquals("Ц (ML)", result.translations[2])
    }

    // ── Cloud batch throws → individual fallback through full chain ────────

    @Test
    fun `translatePages - cloud batch throws, falls back to individual`() = runTest {
        val pages = listOf(
            IndexedValue(0, "Page 0"),
            IndexedValue(1, "Page 1"),
        )

        // Cloud batch throws
        coEvery {
            cloudService.translatePages(any(), "bg", "en", any())
        } throws TranslationException("batch failed")

        // Individual cloud calls succeed
        coEvery { cloudService.translate("Page 0", "bg", "en", any()) } returns "Стр. 0"
        coEvery { cloudService.translate("Page 1", "bg", "en", any()) } returns "Стр. 1"

        val result = fallbackService.translatePages(pages, "bg", "en", null)

        assertEquals("Стр. 0", result.translations[0])
        assertEquals("Стр. 1", result.translations[1])
    }

    @Test
    fun `translatePages - cloud batch throws, individual cloud fails, ML Kit succeeds`() = runTest {
        val pages = listOf(
            IndexedValue(0, "Page 0"),
        )

        coEvery {
            cloudService.translatePages(any(), "bg", "en", any())
        } throws TranslationException("batch failed")

        // Individual cloud also fails (translateSingle calls cloudService.translate with 4 args)
        coEvery { cloudService.translate("Page 0", "bg", "en", any()) } throws TranslationException("cloud down")

        // ML Kit succeeds (translateSingle calls mlKitService.translate with 3 args - no context)
        coEvery { mlKitService.translate("Page 0", "bg", "en") } returns "Стр. 0 (ML)"

        val result = fallbackService.translatePages(pages, "bg", "en", null)

        assertEquals("Стр. 0 (ML)", result.translations[0])
    }

    // ── Empty and single page ─────────────────────────────────────────────

    @Test
    fun `translatePages - returns empty for empty input`() = runTest {
        val result = fallbackService.translatePages(emptyList(), "bg", "en")
        assertTrue(result.translations.isEmpty())
    }

    @Test
    fun `translatePages - single page through cloud batch`() = runTest {
        val pages = listOf(IndexedValue(0, "Hello"))

        coEvery {
            cloudService.translatePages(any(), "bg", "en", any())
        } returns BatchTranslationResult(mapOf(0 to "Здравей"), "gemini-2.5-flash")

        val result = fallbackService.translatePages(pages, "bg", "en", null)

        assertEquals("Здравей", result.translations[0])
    }

    // ── Context passing ──────────────────────────────────────────────────

    @Test
    fun `translatePages - passes context to cloud batch`() = runTest {
        val pages = listOf(IndexedValue(0, "Hello"))

        coEvery {
            cloudService.translatePages(any(), "bg", "en", match { it != null && it.contains("context") })
        } returns BatchTranslationResult(mapOf(0 to "Здравей"), "gemini")

        fallbackService.translatePages(pages, "bg", "en", "some context info")

        coVerify {
            cloudService.translatePages(any(), "bg", "en", match { it != null })
        }
    }
}
