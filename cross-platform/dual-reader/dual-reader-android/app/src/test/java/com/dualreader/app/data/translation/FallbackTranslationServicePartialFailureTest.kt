package com.dualreader.app.data.translation

import com.dualreader.app.domain.services.TranslationException
import com.dualreader.app.domain.services.TranslationService
import io.mockk.every
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.impl.annotations.RelaxedMockK
import io.mockk.junit4.MockKRule
import io.mockk.mockk
import kotlinx.coroutines.test.runTest
import org.junit.Assert.*
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import kotlin.collections.IndexedValue

/**
 * DR-054: Regression tests for partial ML Kit failure in translatePages().
 *
 * Tests that when ML Kit succeeds for some pages but fails for others, the service
 * falls back to cloud batch to translate the remaining pages. If cloud also fails or
 * returns incomplete results, the function throws instead of returning partial results
 * (silent data loss bug).
 */
class FallbackTranslationServicePartialFailureTest {

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

    @Test
    fun `translatePages - ML Kit partial success, cloud fills gaps`() = runTest {
        val pages = listOf(
            IndexedValue(0, "page 0"),
            IndexedValue(1, "page 1"),
            IndexedValue(2, "page 2"),
            IndexedValue(3, "page 3"),
        )

        // ML Kit succeeds for pages 0 and 2, fails for 1 and 3
        coEvery { mlKitService.translate("page 0", "bg", null) } returns "страница 0"
        coEvery { mlKitService.translate("page 1", "bg", null) } throws TranslationException("ML Kit error")
        coEvery { mlKitService.translate("page 2", "bg", null) } returns "страница 2"
        coEvery { mlKitService.translate("page 3", "bg", null) } throws TranslationException("ML Kit error")

        // Cloud batch succeeds for failed pages
        val cloudBatchResult = mockk<com.dualreader.app.domain.services.BatchTranslationResult>()
        every { cloudBatchResult.translations } returns mapOf(1 to "облако 1", 3 to "облако 3")
        every { cloudBatchResult.model } returns "cloud-model"
        coEvery {
            cloudService.translatePages(
                match { it.size == 2 && it[0].index == 1 && it[1].index == 3 },
                "bg",
                null,
                null,
                null,
                false
            )
        } returns cloudBatchResult

        val result = fallbackService.translatePages(pages, "bg", null, null, null, false)

        // Should have all 4 pages translated
        assertEquals(4, result.translations.size)
        assertEquals("страница 0", result.translations[0])
        assertEquals("облако 1", result.translations[1])
        assertEquals("страница 2", result.translations[2])
        assertEquals("облако 3", result.translations[3])
        assertEquals("cloud-model", result.model)

        // Verify cloud was called only for failed pages
        coVerify(exactly = 1) {
            cloudService.translatePages(
                match { it.size == 2 },
                any(),
                any(),
                any(),
                any(),
                any()
            )
        }
    }

    @Test
    fun `translatePages - ML Kit all success, returns ML Kit model`() = runTest {
        val pages = listOf(
            IndexedValue(0, "page 0"),
            IndexedValue(1, "page 1"),
        )

        coEvery { mlKitService.translate("page 0", "bg", null) } returns "страница 0"
        coEvery { mlKitService.translate("page 1", "bg", null) } returns "страница 1"

        val result = fallbackService.translatePages(pages, "bg", null, null, null, false)

        assertEquals(2, result.translations.size)
        assertEquals("страница 0", result.translations[0])
        assertEquals("страница 1", result.translations[1])
        assertEquals(mlKitService.providerName, result.model)

        // Cloud should not be called
        coVerify(exactly = 0) { cloudService.translatePages(any(), any(), any(), any(), any(), any()) }
    }

    @Test
    fun `translatePages - ML Kit all fail, cloud batch handles all`() = runTest {
        val pages = listOf(
            IndexedValue(0, "page 0"),
            IndexedValue(1, "page 1"),
        )

        coEvery { mlKitService.translate(any(), any(), any()) } throws TranslationException("ML Kit error")

        val cloudBatchResult = mockk<com.dualreader.app.domain.services.BatchTranslationResult>()
        every { cloudBatchResult.translations } returns mapOf(0 to "облако 0", 1 to "облако 1")
        every { cloudBatchResult.model } returns "cloud-model"
        coEvery {
            cloudService.translatePages(pages, "bg", null, null, null, false)
        } returns cloudBatchResult

        val result = fallbackService.translatePages(pages, "bg", null, null, null, false)

        assertEquals(2, result.translations.size)
        assertEquals("облако 0", result.translations[0])
        assertEquals("облако 1", result.translations[1])
        assertEquals("cloud-model", result.model)
    }

    @Test
    fun `translatePages - cloud also fails, throws with both failures`() = runTest {
        val pages = listOf(IndexedValue(0, "page 0"))

        coEvery { mlKitService.translate(any(), any(), any()) } throws TranslationException("ML Kit error")
        coEvery { cloudService.translatePages(any(), any(), any(), any(), any(), any()) } throws
            TranslationException("Cloud error")

        try {
            fallbackService.translatePages(pages, "bg", null, null, null, false)
            fail("Should have thrown TranslationException")
        } catch (e: TranslationException) {
            assertTrue("Should mention both failures", e.message!!.contains("Both ML Kit and cloud") || e.message!!.contains("Both"))
        }
    }

    @Test
    fun `translatePages - cloud fails with partial ML Kit success, throws error`() = runTest {
        val pages = listOf(
            IndexedValue(0, "page 0"),
            IndexedValue(1, "page 1"),
            IndexedValue(2, "page 2"),
        )

        // ML Kit succeeds for pages 0 and 2
        coEvery { mlKitService.translate("page 0", "bg", null) } returns "страница 0"
        coEvery { mlKitService.translate("page 1", "bg", null) } throws TranslationException("ML Kit error")
        coEvery { mlKitService.translate("page 2", "bg", null) } returns "страница 2"

        // Cloud also fails
        coEvery { cloudService.translatePages(any(), any(), any(), any(), any(), any()) } throws
            TranslationException("Cloud error")

        try {
            fallbackService.translatePages(pages, "bg", null, null, null, false)
            fail("Should have thrown TranslationException")
        } catch (e: TranslationException) {
            assertTrue("Should mention cloud failure", e.message!!.contains("Cloud fallback"))
            assertTrue("Should mention success count", e.message!!.contains("2/3"))
        }
    }

    @Test
    fun `translatePages - cloud returns incomplete results, throws with missing indices`() = runTest {
        val pages = listOf(
            IndexedValue(0, "page 0"),
            IndexedValue(1, "page 1"),
            IndexedValue(2, "page 2"),
        )

        // ML Kit succeeds only for page 0
        coEvery { mlKitService.translate("page 0", "bg", null) } returns "страница 0"
        coEvery { mlKitService.translate("page 1", "bg", null) } throws TranslationException("ML Kit error")
        coEvery { mlKitService.translate("page 2", "bg", null) } throws TranslationException("ML Kit error")

        // Cloud returns only page 1 (missing page 2)
        val cloudBatchResult = mockk<com.dualreader.app.domain.services.BatchTranslationResult>()
        every { cloudBatchResult.translations } returns mapOf(1 to "облако 1")
        every { cloudBatchResult.model } returns "cloud-model"
        coEvery { cloudService.translatePages(any(), any(), any(), any(), any(), any()) } returns cloudBatchResult

        try {
            fallbackService.translatePages(pages, "bg", null, null, null, false)
            fail("Should have thrown TranslationException")
        } catch (e: TranslationException) {
            assertTrue("Should mention missing page count", e.message!!.contains("missing"))
            assertTrue("Should mention missing index", e.message!!.contains("2"))
            assertTrue("Should mention cloud incomplete", e.message!!.contains("Cloud returned incomplete"))
        }
    }
}