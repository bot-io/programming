package com.dualreader.app.domain.usecases

import com.dualreader.app.domain.repositories.TranslationCacheRepository
import com.dualreader.app.domain.services.BatchTranslationResult
import com.dualreader.app.domain.services.TranslationService
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.mockk
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class TranslatePageUseCaseTest {

    private lateinit var translationService: TranslationService
    private lateinit var cacheRepo: TranslationCacheRepository
    private lateinit var useCase: TranslatePageUseCase

    @Before
    fun setUp() {
        translationService = mockk(relaxed = true)
        cacheRepo = mockk(relaxed = true)
        useCase = TranslatePageUseCase(translationService, cacheRepo)
    }

    // ── Constants ─────────────────────────────────────────────────

    @Test
    fun `BATCH_SIZE is 15`() {
        assertEquals(15, TranslatePageUseCase.BATCH_SIZE)
    }

    // ── Single page translation ───────────────────────────────────

    @Test
    fun `invoke returns cached translation when available`() = runTest {
        coEvery { cacheRepo.get("hello", "en", "es") } returns "hola"

        val result = useCase("hello", "es", "en")

        assertTrue(result.isSuccess)
        assertEquals("hola", result.getOrNull())
    }

    @Test
    fun `invoke calls service when cache miss`() = runTest {
        coEvery { cacheRepo.get(any(), any(), any()) } returns null
        coEvery { translationService.translate(any(), any(), any(), any(), any(), any()) } returns "hola"

        val result = useCase("hello", "es", "en")

        assertEquals("hola", result.getOrNull())
        coVerify { translationService.translate(any(), "es", "en", any(), any(), any()) }
    }

    @Test
    fun `invoke caches result after service call`() = runTest {
        coEvery { cacheRepo.get(any(), any(), any()) } returns null
        coEvery { translationService.translate(any(), any(), any(), any(), any(), any()) } returns "hola"

        useCase("hello", "es", "en")

        coVerify { cacheRepo.put("hello", "en", "es", "hola") }
    }

    @Test
    fun `invoke skips cache when forceRetranslate`() = runTest {
        coEvery { translationService.translate(any(), any(), any(), any(), any(), any()) } returns "nueva"

        val result = useCase("hello", "es", "en", forceRetranslate = true)

        assertEquals("nueva", result.getOrNull())
        coVerify(exactly = 0) { cacheRepo.get(any(), any(), any()) }
    }

    @Test
    fun `invoke overwrites cache on retranslate`() = runTest {
        coEvery { translationService.translate(any(), any(), any(), any(), any(), any()) } returns "updated"

        useCase("hello", "es", "en", forceRetranslate = true)

        coVerify { cacheRepo.put("hello", "en", "es", "updated") }
    }

    @Test
    fun `invoke returns failure on exception`() = runTest {
        coEvery { cacheRepo.get(any(), any(), any()) } returns null
        coEvery { translationService.translate(any(), any(), any(), any(), any(), any()) } throws RuntimeException("API down")

        val result = useCase("hello", "es", "en")

        assertTrue(result.isFailure)
        assertEquals("API down", result.exceptionOrNull()?.message)
    }

    @Test
    fun `invoke with null sourceLanguage uses null for cache lookup`() = runTest {
        coEvery { cacheRepo.get("hello", null, "es") } returns "hola"

        val result = useCase("hello", "es")

        assertEquals("hola", result.getOrNull())
        coVerify { cacheRepo.get("hello", null, "es") }
    }

    // ── Batch translation ─────────────────────────────────────────

    @Test
    fun `translateBatchWithContext returns all cached results`() = runTest {
        val pages = listOf(
            PageToTranslate(0, "hello"),
            PageToTranslate(1, "world"),
        )
        coEvery { cacheRepo.get("hello", "en", "es") } returns "hola"
        coEvery { cacheRepo.get("world", "en", "es") } returns "mundo"

        val result = useCase.translateBatchWithContext(pages, "es", "en")

        assertTrue(result.isSuccess)
        assertEquals(2, result.getOrNull()?.translations?.size)
        assertEquals("hola", result.getOrNull()?.translations?.get(0))
        assertEquals("mundo", result.getOrNull()?.translations?.get(1))
    }

    @Test
    fun `translateBatchWithContext calls service for uncached pages`() = runTest {
        val pages = listOf(PageToTranslate(0, "hello"))
        coEvery { cacheRepo.get(any(), any(), any()) } returns null
        coEvery { translationService.translate(any(), any(), any(), any(), any(), any()) } returns "hola"

        val result = useCase.translateBatchWithContext(pages, "es", "en")

        assertEquals("hola", result.getOrNull()?.translations?.get(0))
    }

    @Test
    fun `translateBatchWithContext returns failure on exception`() = runTest {
        val pages = listOf(PageToTranslate(0, "hello"))
        coEvery { cacheRepo.get(any(), any(), any()) } returns null
        coEvery { translationService.translate(any(), any(), any(), any(), any(), any()) } throws RuntimeException("fail")

        val result = useCase.translateBatchWithContext(pages, "es", "en")

        assertTrue(result.isFailure)
    }

    @Test
    fun `translateBatchWithContext empty pages returns empty result`() = runTest {
        val result = useCase.translateBatchWithContext(emptyList(), "es", "en")

        assertTrue(result.isSuccess)
        assertTrue(result.getOrNull()?.translations?.isEmpty() == true)
    }

    @Test
    fun `translateBatchWithContext caches translated results`() = runTest {
        val pages = listOf(PageToTranslate(0, "hello"))
        coEvery { cacheRepo.get(any(), any(), any()) } returns null
        coEvery { translationService.translate(any(), any(), any(), any(), any(), any()) } returns "hola"

        useCase.translateBatchWithContext(pages, "es", "en")

        coVerify { cacheRepo.put("hello", "en", "es", "hola") }
    }

    @Test
    fun `translateBatchWithContext calls onPageTranslated callback`() = runTest {
        val pages = listOf(PageToTranslate(0, "hello"))
        coEvery { cacheRepo.get(any(), any(), any()) } returns "hola"

        val translated = mutableListOf<Int>()
        useCase.translateBatchWithContext(
            pages, "es", "en",
            onPageTranslated = { idx, _ -> translated.add(idx) },
        )

        assertEquals(listOf(0), translated)
    }

    // ── Legacy batch ──────────────────────────────────────────────

    @Test
    fun `legacy translateBatch delegates to service`() = runTest {
        coEvery { translationService.translateBatch(any(), any(), any()) } returns listOf("hola", "mundo")

        val result = useCase.translateBatch(listOf("hello", "world"), "es", "en")

        assertTrue(result.isSuccess)
        assertEquals(listOf("hola", "mundo"), result.getOrNull())
    }
}
