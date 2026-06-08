package com.dualreader.app.domain.usecases

import com.dualreader.app.domain.repositories.TranslationCacheRepository
import com.dualreader.app.domain.services.TranslationException
import com.dualreader.app.domain.services.TranslationService
import io.mockk.*
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test

class TranslatePageUseCaseTest {

    private lateinit var translationService: TranslationService
    private lateinit var cacheRepository: TranslationCacheRepository
    private lateinit var useCase: TranslatePageUseCase

    @Before
    fun setUp() {
        translationService = mockk()
        cacheRepository = mockk()
        useCase = TranslatePageUseCase(translationService, cacheRepository)
    }

    @After
    fun tearDown() {
        unmockkAll()
    }

    // ─── Cache hit: skips service call ──────────────────────────────────

    @Test
    fun `cache hit returns cached translation without calling service`() = runTest {
        coEvery { cacheRepository.get("Hello", "en", "bg") } returns "Здравей"

        val result = useCase("Hello", "bg", "en")

        assertTrue(result.isSuccess)
        assertEquals("Здравей", result.getOrThrow())
        coVerify(exactly = 0) { translationService.translate(any(), any(), any(), any()) }
    }

    @Test
    fun `cache hit with null sourceLang passes null to cache`() = runTest {
        // UseCase passes sourceLanguage=null directly to cacheRepository.get
        coEvery { cacheRepository.get("Hello", null, "bg") } returns "Здравей"

        val result = useCase("Hello", "bg", null)

        assertTrue(result.isSuccess)
        assertEquals("Здравей", result.getOrThrow())
    }

    // ─── Cache miss: calls service and stores result ────────────────────

    @Test
    fun `cache miss calls service and stores result`() = runTest {
        coEvery { cacheRepository.get("Hello", "en", "bg") } returns null
        coEvery {
            translationService.translate("Hello", "bg", "en", null)
        } returns "Здравей"
        coEvery { cacheRepository.put("Hello", "en", "bg", "Здравей") } just Runs

        val result = useCase("Hello", "bg", "en")

        assertTrue(result.isSuccess)
        assertEquals("Здравей", result.getOrThrow())
        coVerify(exactly = 1) { translationService.translate("Hello", "bg", "en", null) }
        coVerify(exactly = 1) { cacheRepository.put("Hello", "en", "bg", "Здравей") }
    }

    @Test
    fun `cache miss with context passes context to service`() = runTest {
        coEvery { cacheRepository.get(any(), any(), any()) } returns null
        coEvery {
            translationService.translate("Page 2", "bg", "en", any())
        } returns "Страница 2"
        coEvery { cacheRepository.put(any(), any(), any(), any()) } just Runs

        val result = useCase(
            text = "Page 2",
            targetLanguage = "bg",
            sourceLanguage = "en",
            previousOriginal = "Page 1 original",
            previousTranslation = "Страница 1",
        )

        assertTrue(result.isSuccess)
        coVerify {
            translationService.translate("Page 2", "bg", "en", match { ctx ->
                ctx != null && ctx.contains("Страница 1")
            })
        }
    }

    // ─── Force retranslate: bypasses cache ──────────────────────────────

    @Test
    fun `forceRetranslate bypasses cache and overwrites`() = runTest {
        // Cache has a value but we force retranslate
        coEvery {
            translationService.translate("Hello", "bg", "en", null)
        } returns "New translation"
        coEvery { cacheRepository.put("Hello", "en", "bg", "New translation") } just Runs

        val result = useCase("Hello", "bg", "en", forceRetranslate = true)

        assertTrue(result.isSuccess)
        assertEquals("New translation", result.getOrThrow())
        // Cache lookup was skipped
        coVerify(exactly = 0) { cacheRepository.get(any(), any(), any()) }
        // Service was called
        coVerify(exactly = 1) { translationService.translate("Hello", "bg", "en", null) }
        // Result was stored in cache (overwriting old)
        coVerify(exactly = 1) { cacheRepository.put("Hello", "en", "bg", "New translation") }
    }

    // ─── Service failure: does not cache ────────────────────────────────

    @Test
    fun `service failure returns error without caching`() = runTest {
        coEvery { cacheRepository.get("Hello", "en", "bg") } returns null
        coEvery {
            translationService.translate("Hello", "bg", "en", null)
        } throws TranslationException("API error")

        val result = useCase("Hello", "bg", "en")

        assertTrue(result.isFailure)
        assertEquals("API error", result.exceptionOrNull()?.message)
        coVerify(exactly = 0) { cacheRepository.put(any(), any(), any(), any()) }
    }

    // ─── Batch with cache ───────────────────────────────────────────────

    @Test
    fun `batch skips cached pages and translates uncached`() = runTest {
        val pages = listOf(
            PageToTranslate(index = 0, text = "Page 0"),
            PageToTranslate(index = 1, text = "Page 1"),
            PageToTranslate(index = 2, text = "Page 2"),
        )

        // Page 0 cached, Page 1 and 2 not cached
        coEvery { cacheRepository.get("Page 0", "en", "bg") } returns "Стр. 0"
        coEvery { cacheRepository.get("Page 1", "en", "bg") } returns null
        coEvery { cacheRepository.get("Page 2", "en", "bg") } returns null

        coEvery { translationService.translate("Page 1", "bg", "en", any()) } returns "Стр. 1"
        coEvery { translationService.translate("Page 2", "bg", "en", any()) } returns "Стр. 2"
        coEvery { cacheRepository.put(any(), any(), any(), any()) } just Runs

        val translated = mutableListOf<Pair<Int, String>>()
        val result = useCase.translateBatchWithContext(
            pages = pages,
            targetLanguage = "bg",
            sourceLanguage = "en",
            onPageTranslated = { idx, text -> translated.add(idx to text) },
        )

        assertTrue(result.isSuccess)
        val map = result.getOrThrow()
        assertEquals("Стр. 0", map[0]) // From cache
        assertEquals("Стр. 1", map[1]) // From service
        assertEquals("Стр. 2", map[2]) // From service

        // Callbacks fired in order
        assertEquals(3, translated.size)
        assertEquals(0 to "Стр. 0", translated[0])
        assertEquals(1 to "Стр. 1", translated[1])
        assertEquals(2 to "Стр. 2", translated[2])

        // Only 2 service calls (page 0 was cached)
        coVerify(exactly = 2) { translationService.translate(any(), any(), any(), any()) }
    }

    @Test
    fun `batch all cached skips all service calls`() = runTest {
        val pages = listOf(
            PageToTranslate(index = 0, text = "A"),
            PageToTranslate(index = 1, text = "B"),
        )

        coEvery { cacheRepository.get("A", "en", "bg") } returns "А"
        coEvery { cacheRepository.get("B", "en", "bg") } returns "Б"

        val result = useCase.translateBatchWithContext(pages, "bg", "en")

        assertTrue(result.isSuccess)
        assertEquals("А", result.getOrThrow()[0])
        assertEquals("Б", result.getOrThrow()[1])
        coVerify(exactly = 0) { translationService.translate(any(), any(), any(), any()) }
    }

    @Test
    fun `batch with forceRetranslate ignores cache`() = runTest {
        val pages = listOf(PageToTranslate(index = 0, text = "Hello"))

        coEvery { translationService.translate("Hello", "bg", "en", any()) } returns "Fresh"
        coEvery { cacheRepository.put("Hello", "en", "bg", "Fresh") } just Runs

        val result = useCase.translateBatchWithContext(
            pages = pages,
            targetLanguage = "bg",
            sourceLanguage = "en",
            forceRetranslate = true,
        )

        assertTrue(result.isSuccess)
        assertEquals("Fresh", result.getOrThrow()[0])
        coVerify(exactly = 0) { cacheRepository.get(any(), any(), any()) }
        coVerify(exactly = 1) { translationService.translate(any(), any(), any(), any()) }
    }

    // ─── Context continuity across pages ────────────────────────────────

    @Test
    fun `batch passes previous translation as context for uncached pages`() = runTest {
        val pages = listOf(
            PageToTranslate(index = 0, text = "First page"),
            PageToTranslate(index = 1, text = "Second page"),
        )

        coEvery { cacheRepository.get(any(), any(), any()) } returns null
        coEvery { translationService.translate("First page", "bg", "en", any()) } returns "Първа страница"
        coEvery { translationService.translate("Second page", "bg", "en", any()) } returns "Втора страница"
        coEvery { cacheRepository.put(any(), any(), any(), any()) } just Runs

        useCase.translateBatchWithContext(pages, "bg", "en")

        // Second call should have context from first translation
        coVerify {
            translationService.translate(
                "Second page", "bg", "en",
                match { it != null && it.contains("Първа страница") }
            )
        }
    }

    @Test
    fun `cached page in middle of batch still provides context for next`() = runTest {
        val pages = listOf(
            PageToTranslate(index = 0, text = "P0"),
            PageToTranslate(index = 1, text = "P1"), // Will be cached
            PageToTranslate(index = 2, text = "P2"),
        )

        coEvery { cacheRepository.get("P0", "en", "bg") } returns null
        coEvery { cacheRepository.get("P1", "en", "bg") } returns "Кеширана P1"
        coEvery { cacheRepository.get("P2", "en", "bg") } returns null

        coEvery { translationService.translate("P0", "bg", "en", any()) } returns "T0"
        coEvery { translationService.translate("P2", "bg", "en", any()) } returns "T2"
        coEvery { cacheRepository.put(any(), any(), any(), any()) } just Runs

        useCase.translateBatchWithContext(pages, "bg", "en")

        // P2 should receive cached P1 translation as context
        coVerify {
            translationService.translate(
                "P2", "bg", "en",
                match { it != null && it.contains("Кеширана P1") }
            )
        }
    }
}
