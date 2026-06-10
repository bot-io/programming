package com.dualreader.app.domain.usecases

import com.dualreader.app.domain.repositories.TranslationCacheRepository
import com.dualreader.app.domain.services.BatchTranslationResult
import com.dualreader.app.domain.services.TranslationException
import com.dualreader.app.domain.services.TranslationService
import io.mockk.*
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test

/**
 * Additional tests for TranslatePageUseCase covering:
 * - buildContext: context truncation, null inputs, combined context
 * - collectBatch: char limit enforcement, cached page boundary
 * - translateBatchWithContext: batch failure → individual fallback
 * - translateBatchWithContext: service failure mid-batch
 * - Legacy translateBatch method
 */
class TranslatePageUseCaseAdditionalTest {

    private lateinit var translationService: TranslationService
    private lateinit var cacheRepository: TranslationCacheRepository
    private lateinit var useCase: TranslatePageUseCase

    @Before
    fun setUp() {
        translationService = mockk {
            every { providerName } returns "test-provider"
        }
        cacheRepository = mockk()
        useCase = TranslatePageUseCase(translationService, cacheRepository)
    }

    @After
    fun tearDown() {
        unmockkAll()
    }

    // ─── buildContext: truncation at MAX_CONTEXT_CHARS (300) ──────────────

    @Test
    fun `context is truncated when previousTranslation exceeds 300 chars`() = runTest {
        val longTranslation = "а".repeat(500)
        coEvery { cacheRepository.get(any(), any(), any()) } returns null
        coEvery { translationService.translate(any(), any(), any(), any()) } returns "result"
        coEvery { cacheRepository.put(any(), any(), any(), any()) } just Runs

        useCase("text", "bg", "en", previousTranslation = longTranslation)

        coVerify {
            translationService.translate(eq("text"), eq("bg"), eq("en"), match { ctx ->
                ctx != null && ctx.contains("а".repeat(300)) && ctx.contains("...")
            })
        }
    }

    @Test
    fun `context is not truncated when under 300 chars`() = runTest {
        val shortTranslation = "Кратък текст"
        coEvery { cacheRepository.get(any(), any(), any()) } returns null
        coEvery { translationService.translate(any(), any(), any(), any()) } returns "result"
        coEvery { cacheRepository.put(any(), any(), any(), any()) } just Runs

        useCase("text", "bg", "en", previousTranslation = shortTranslation)

        coVerify {
            translationService.translate(eq("text"), eq("bg"), eq("en"), match { ctx ->
                ctx != null && ctx.contains(shortTranslation) && !ctx.contains("...")
            })
        }
    }

    @Test
    fun `context is null when both previousOriginal and previousTranslation are null`() = runTest {
        coEvery { cacheRepository.get(any(), any(), any()) } returns null
        coEvery { translationService.translate(any(), any(), any(), any()) } returns "result"
        coEvery { cacheRepository.put(any(), any(), any(), any()) } just Runs

        useCase("text", "bg", "en")

        coVerify {
            translationService.translate("text", "bg", "en", null)
        }
    }

    @Test
    fun `context includes both original and translation when provided`() = runTest {
        coEvery { cacheRepository.get(any(), any(), any()) } returns null
        coEvery { translationService.translate(any(), any(), any(), any()) } returns "result"
        coEvery { cacheRepository.put(any(), any(), any(), any()) } just Runs

        useCase("text", "bg", "en", previousOriginal = "original", previousTranslation = "translation")

        coVerify {
            translationService.translate(eq("text"), eq("bg"), eq("en"), match { ctx ->
                ctx != null && ctx.contains("original") && ctx.contains("translation")
            })
        }
    }

    @Test
    fun `context includes previousOriginal when only original is provided`() = runTest {
        coEvery { cacheRepository.get(any(), any(), any()) } returns null
        coEvery { translationService.translate(any(), any(), any(), any()) } returns "result"
        coEvery { cacheRepository.put(any(), any(), any(), any()) } just Runs

        useCase("text", "bg", "en", previousOriginal = "original text")

        coVerify {
            translationService.translate(eq("text"), eq("bg"), eq("en"), match { ctx ->
                ctx != null && ctx.contains("original text")
            })
        }
    }

    // ─── collectBatch: char limit enforcement ─────────────────────────────

    @Test
    fun `batch collection stops at char limit`() = runTest {
        // MAX_BATCH_CHARS = 10000, BATCH_SIZE = 5
        // Create 3 pages each ~4000 chars → only 2 should fit in one batch
        val pages = listOf(
            PageToTranslate(index = 0, text = "a".repeat(4500)),
            PageToTranslate(index = 1, text = "b".repeat(4500)),
            PageToTranslate(index = 2, text = "c".repeat(4500)),
        )

        coEvery { cacheRepository.get(any(), any(), any()) } returns null

        // Batch call for first 2 pages (total ~9000 chars, under 10000)
        coEvery {
            translationService.translatePages(any(), any(), any(), any())
        } returns BatchTranslationResult(mapOf(0 to "T0", 1 to "T1"), "test")
        // Individual call for page 2 (single page batch)
        coEvery { translationService.translate(any(), any(), any(), any()) } returns "T2"
        coEvery { cacheRepository.put(any(), any(), any(), any()) } just Runs

        val result = useCase.translateBatchWithContext(pages, "bg", "en")

        assertTrue(result.isSuccess)
        val translations = result.getOrThrow().translations
        assertEquals("T0", translations[0])
        assertEquals("T1", translations[1])
        assertEquals("T2", translations[2])
    }

    @Test
    fun `batch collection stops at cached page boundary`() = runTest {
        val pages = listOf(
            PageToTranslate(index = 0, text = "P0"),
            PageToTranslate(index = 1, text = "P1"), // cached
            PageToTranslate(index = 2, text = "P2"),
        )

        coEvery { cacheRepository.get("P0", "en", "bg") } returns null
        coEvery { cacheRepository.get("P1", "en", "bg") } returns "Cached P1"
        coEvery { cacheRepository.get("P2", "en", "bg") } returns null

        // P0 is single page batch → individual call
        coEvery { translationService.translate("P0", "bg", "en", any()) } returns "T0"
        // P2 is single page batch → individual call
        coEvery { translationService.translate("P2", "bg", "en", any()) } returns "T2"
        coEvery { cacheRepository.put(any(), any(), any(), any()) } just Runs

        val result = useCase.translateBatchWithContext(pages, "bg", "en")

        assertTrue(result.isSuccess)
        assertEquals("T0", result.getOrThrow().translations[0])
        assertEquals("Cached P1", result.getOrThrow().translations[1])
        assertEquals("T2", result.getOrThrow().translations[2])
    }

    // ─── Batch failure → individual fallback ──────────────────────────────

    @Test
    fun `batch call fails, falls back to individual calls`() = runTest {
        val pages = listOf(
            PageToTranslate(index = 0, text = "P0"),
            PageToTranslate(index = 1, text = "P1"),
        )

        coEvery { cacheRepository.get(any(), any(), any()) } returns null

        // Batch endpoint fails
        coEvery {
            translationService.translatePages(any(), any(), any(), any())
        } throws TranslationException("batch endpoint down")

        // Individual calls succeed
        coEvery { translationService.translate("P0", "bg", "en", any()) } returns "T0"
        coEvery { translationService.translate("P1", "bg", "en", any()) } returns "T1"
        coEvery { cacheRepository.put(any(), any(), any(), any()) } just Runs

        val result = useCase.translateBatchWithContext(pages, "bg", "en")

        assertTrue(result.isSuccess)
        assertEquals("T0", result.getOrThrow().translations[0])
        assertEquals("T1", result.getOrThrow().translations[1])
    }

    @Test
    fun `batch fails, individual fallback also fails for one page - partial results`() = runTest {
        val pages = listOf(
            PageToTranslate(index = 0, text = "P0"),
            PageToTranslate(index = 1, text = "P1"),
        )

        coEvery { cacheRepository.get(any(), any(), any()) } returns null

        // Batch endpoint fails
        coEvery {
            translationService.translatePages(any(), any(), any(), any())
        } throws TranslationException("batch down")

        // P0 succeeds individually, P1 also fails individually
        coEvery { translationService.translate("P0", "bg", "en", any()) } returns "T0"
        coEvery { translationService.translate("P1", "bg", "en", any()) } throws TranslationException("individual fail")
        coEvery { cacheRepository.put(any(), any(), any(), any()) } just Runs

        val result = useCase.translateBatchWithContext(pages, "bg", "en")

        assertTrue(result.isSuccess)
        assertEquals("T0", result.getOrThrow().translations[0])
        // P1 failed individually and was skipped
        assertNull(result.getOrThrow().translations[1])
    }

    // ─── Service failure mid-batch ────────────────────────────────────────

    @Test
    fun `translateBatchWithContext returns failure on unexpected exception`() = runTest {
        coEvery { cacheRepository.get(any(), any(), any()) } throws RuntimeException("boom")

        val pages = listOf(PageToTranslate(index = 0, text = "P0"))

        val result = useCase.translateBatchWithContext(pages, "bg", "en")

        assertTrue(result.isFailure)
    }

    // ─── Legacy translateBatch ───────────────────────────────────────────

    @Test
    fun `legacy translateBatch delegates to service`() = runTest {
        coEvery {
            translationService.translateBatch(listOf("A", "B"), "bg", "en")
        } returns listOf("А", "Б")

        val result = useCase.translateBatch(listOf("A", "B"), "bg", "en")

        assertTrue(result.isSuccess)
        assertEquals(listOf("А", "Б"), result.getOrThrow())
    }

    @Test
    fun `legacy translateBatch returns failure on service error`() = runTest {
        coEvery {
            translationService.translateBatch(any(), any(), any())
        } throws TranslationException("service error")

        val result = useCase.translateBatch(listOf("A"), "bg")

        assertTrue(result.isFailure)
    }

    // ─── Callback invocation ──────────────────────────────────────────────

    @Test
    fun `onPageTranslated callback is called for each page in order`() = runTest {
        val pages = listOf(
            PageToTranslate(index = 0, text = "A"),
            PageToTranslate(index = 1, text = "B"),
        )

        coEvery { cacheRepository.get(any(), any(), any()) } returns null
        coEvery {
            translationService.translatePages(any(), any(), any(), any())
        } returns BatchTranslationResult(mapOf(0 to "А", 1 to "Б"), "test")
        coEvery { cacheRepository.put(any(), any(), any(), any()) } just Runs

        val callbacks = mutableListOf<Pair<Int, String>>()
        val result = useCase.translateBatchWithContext(
            pages, "bg", "en",
            onPageTranslated = { idx, text -> callbacks.add(idx to text) },
        )

        assertTrue(result.isSuccess)
        assertEquals(listOf(0 to "А", 1 to "Б"), callbacks)
    }

    @Test
    fun `onPageTranslated is called for cached pages too`() = runTest {
        val pages = listOf(
            PageToTranslate(index = 0, text = "A"),
        )

        coEvery { cacheRepository.get("A", "en", "bg") } returns "А"

        val callbacks = mutableListOf<Pair<Int, String>>()
        val result = useCase.translateBatchWithContext(
            pages, "bg", "en",
            onPageTranslated = { idx, text -> callbacks.add(idx to text) },
        )

        assertTrue(result.isSuccess)
        assertEquals(listOf(0 to "А"), callbacks)
    }
}
