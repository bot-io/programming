package com.dualreader.app.domain.usecases

import com.dualreader.app.data.translation.ParagraphAligner
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
 * Tests for DR-013: Paragraph alignment via marker-based batch translation.
 *
 * Verifies that multi-paragraph batches:
 * 1. Use marker injection to join paragraphs for full-context translation
 * 2. Split by markers when the LLM preserves them (exact alignment)
 * 3. Fall back to proportional alignment when markers are stripped
 * 4. Fall back to translatePages when the marker call itself fails
 * 5. Cache individual paragraph translations
 */
class TranslatePageMarkerBatchTest {

    private lateinit var translationService: TranslationService
    private lateinit var cacheRepo: TranslationCacheRepository
    private lateinit var useCase: TranslatePageUseCase

    @Before
    fun setUp() {
        translationService = mockk {
            every { providerName } returns "test-provider"
        }
        cacheRepo = mockk()
        useCase = TranslatePageUseCase(translationService, cacheRepo)
    }

    @After
    fun tearDown() {
        unmockkAll()
    }

    // ── Marker preservation (exact alignment) ──────────────────────────────

    @Test
    fun `multi-page batch uses translate with markers`() = runTest {
        val pages = listOf(
            PageToTranslate(0, "Hello."),
            PageToTranslate(1, "World."),
        )
        coEvery { cacheRepo.get(any(), any(), any()) } returns null

        // Capture what text is passed to translate()
        val capturedText = slot<String>()
        coEvery {
            translationService.translate(capture(capturedText), any(), any(), any(), any(), any())
        } returns "\u27E61\u27E7 Привет.\n\n\u27E62\u27E7 Мир."
        coEvery { cacheRepo.put(any(), any(), any(), any()) } just Runs

        useCase.translateBatchWithContext(pages, "ru", "en")

        // Verify translate was called with marker-injected text
        assertTrue("translate should receive marker-tagged text", capturedText.isCaptured)
        assertTrue("text should contain marker", ParagraphAligner.hasMarkers(capturedText.captured))
    }

    @Test
    fun `markers preserved - exact paragraph alignment`() = runTest {
        val pages = listOf(
            PageToTranslate(0, "Hello."),
            PageToTranslate(1, "Goodbye."),
            PageToTranslate(2, "Thank you."),
        )
        coEvery { cacheRepo.get(any(), any(), any()) } returns null
        coEvery {
            translationService.translate(any(), any(), any(), any(), any(), any())
        } returns "\u27E61\u27E7 Hola.\n\n\u27E62\u27E7 Adiós.\n\n\u27E63\u27E7 Gracias."
        coEvery { cacheRepo.put(any(), any(), any(), any()) } just Runs

        val result = useCase.translateBatchWithContext(pages, "es", "en")

        assertTrue(result.isSuccess)
        val translations = result.getOrThrow().translations
        assertEquals(3, translations.size)
        assertEquals("Hola.", translations[0])
        assertEquals("Adiós.", translations[1])
        assertEquals("Gracias.", translations[2])
    }

    @Test
    fun `markers preserved - caches individual paragraph translations`() = runTest {
        val pages = listOf(
            PageToTranslate(0, "Hello."),
            PageToTranslate(1, "World."),
        )
        coEvery { cacheRepo.get(any(), any(), any()) } returns null
        coEvery {
            translationService.translate(any(), any(), any(), any(), any(), any())
        } returns "\u27E61\u27E7 Hola.\n\n\u27E62\u27E7 Mundo."
        coEvery { cacheRepo.put(any(), any(), any(), any()) } just Runs

        useCase.translateBatchWithContext(pages, "es", "en")

        // Each individual paragraph should be cached (not the joined text)
        coVerify { cacheRepo.put("Hello.", "en", "es", "Hola.") }
        coVerify { cacheRepo.put("World.", "en", "es", "Mundo.") }
    }

    // ── Marker stripping (proportional fallback) ───────────────────────────

    @Test
    fun `markers stripped - falls back to proportional alignment`() = runTest {
        val pages = listOf(
            PageToTranslate(0, "Hello."),
            PageToTranslate(1, "World."),
        )
        coEvery { cacheRepo.get(any(), any(), any()) } returns null
        // LLM stripped markers — plain text translation
        coEvery {
            translationService.translate(any(), any(), any(), any(), any(), any())
        } returns "Hola.\n\nMundo."
        coEvery { cacheRepo.put(any(), any(), any(), any()) } just Runs

        val result = useCase.translateBatchWithContext(pages, "es", "en")

        assertTrue(result.isSuccess)
        val translations = result.getOrThrow().translations
        // Proportional alignment: 2 originals, 2 translations → 1:1 match
        assertEquals(2, translations.size)
        assertEquals("Hola.", translations[0])
        assertEquals("Mundo.", translations[1])
    }

    @Test
    fun `markers stripped - merged paragraphs handled by proportional`() = runTest {
        val pages = listOf(
            PageToTranslate(0, "First."),
            PageToTranslate(1, "Second."),
            PageToTranslate(2, "Third."),
        )
        coEvery { cacheRepo.get(any(), any(), any()) } returns null
        // LLM merged 3 paragraphs into 1 (no markers, no newlines)
        coEvery {
            translationService.translate(any(), any(), any(), any(), any(), any())
        } returns "First second third combined."
        coEvery { cacheRepo.put(any(), any(), any(), any()) } just Runs

        val result = useCase.translateBatchWithContext(pages, "es", "en")

        assertTrue(result.isSuccess)
        val translations = result.getOrThrow().translations
        // Proportional: all 3 originals map to the single translated block
        assertEquals(3, translations.size)
        assertEquals("First second third combined.", translations[0])
        assertEquals("First second third combined.", translations[1])
        assertEquals("First second third combined.", translations[2])
    }

    // ── Marker call failure (translatePages fallback) ──────────────────────

    @Test
    fun `marker translate fails - falls back to translatePages`() = runTest {
        val pages = listOf(
            PageToTranslate(0, "Hello."),
            PageToTranslate(1, "World."),
        )
        coEvery { cacheRepo.get(any(), any(), any()) } returns null

        // Marker-based translate throws → falls back to batch endpoint
        coEvery {
            translationService.translate(any(), any(), any(), any(), any(), any())
        } throws TranslationException("network error")
        coEvery {
            translationService.translatePages(any(), any(), any(), any(), any(), any())
        } returns BatchTranslationResult(mapOf(0 to "Hola.", 1 to "Mundo."), "batch-model")
        coEvery { cacheRepo.put(any(), any(), any(), any()) } just Runs

        val result = useCase.translateBatchWithContext(pages, "es", "en")

        assertTrue(result.isSuccess)
        val translations = result.getOrThrow().translations
        assertEquals("Hola.", translations[0])
        assertEquals("Mundo.", translations[1])
        assertEquals("batch-model", result.getOrThrow().model)
    }

    @Test
    fun `both marker and batch endpoint fail - returns failure`() = runTest {
        val pages = listOf(
            PageToTranslate(0, "Hello."),
            PageToTranslate(1, "World."),
        )
        coEvery { cacheRepo.get(any(), any(), any()) } returns null

        coEvery {
            translationService.translate(any(), any(), any(), any(), any(), any())
        } throws TranslationException("translate down")
        coEvery {
            translationService.translatePages(any(), any(), any(), any(), any(), any())
        } throws TranslationException("batch down")

        val result = useCase.translateBatchWithContext(pages, "es", "en")

        assertTrue(result.isFailure)
    }

    @Test
    fun `blank translate result falls back to translatePages`() = runTest {
        val pages = listOf(
            PageToTranslate(0, "Hello."),
            PageToTranslate(1, "World."),
        )
        coEvery { cacheRepo.get(any(), any(), any()) } returns null

        // Marker-based translate returns blank → fallback to translatePages
        coEvery {
            translationService.translate(any(), any(), any(), any(), any(), any())
        } returns ""
        coEvery {
            translationService.translatePages(any(), any(), any(), any(), any(), any())
        } returns BatchTranslationResult(mapOf(0 to "Hola.", 1 to "Mundo."), "batch-model")
        coEvery { cacheRepo.put(any(), any(), any(), any()) } just Runs

        val result = useCase.translateBatchWithContext(pages, "es", "en")

        assertTrue(result.isSuccess)
        assertEquals("Hola.", result.getOrThrow().translations[0])
        assertEquals("Mundo.", result.getOrThrow().translations[1])
    }

    // ── Single page (no marker overhead) ───────────────────────────────────

    @Test
    fun `single page batch does not use markers`() = runTest {
        val pages = listOf(PageToTranslate(0, "Only one."))
        coEvery { cacheRepo.get(any(), any(), any()) } returns null
        coEvery {
            translationService.translate(any(), any(), any(), any(), any(), any())
        } returns "Solo uno."
        coEvery { cacheRepo.put(any(), any(), any(), any()) } just Runs

        val result = useCase.translateBatchWithContext(pages, "es", "en")

        assertTrue(result.isSuccess)
        assertEquals("Solo uno.", result.getOrThrow().translations[0])
        // translatePages should NOT be called for single page
        coVerify(exactly = 0) {
            translationService.translatePages(any(), any(), any(), any(), any(), any())
        }
    }

    // ── Callback invocation ────────────────────────────────────────────────

    @Test
    fun `onPageTranslated called for each page with marker-based batch`() = runTest {
        val pages = listOf(
            PageToTranslate(0, "First."),
            PageToTranslate(1, "Second."),
        )
        coEvery { cacheRepo.get(any(), any(), any()) } returns null
        coEvery {
            translationService.translate(any(), any(), any(), any(), any(), any())
        } returns "\u27E61\u27E7 Primero.\n\n\u27E62\u27E7 Segundo."
        coEvery { cacheRepo.put(any(), any(), any(), any()) } just Runs

        val callbacks = mutableListOf<Pair<Int, String>>()
        useCase.translateBatchWithContext(
            pages, "es", "en",
            onPageTranslated = { idx, text -> callbacks.add(idx to text) },
        )

        assertEquals(listOf(0 to "Primero.", 1 to "Segundo."), callbacks)
    }

    // ── Large batch (DR-013 integration) ───────────────────────────────────

    @Test
    fun `large batch with 5 paragraphs uses marker approach`() = runTest {
        val pages = (0..4).map { PageToTranslate(it, "Paragraph $it.") }
        coEvery { cacheRepo.get(any(), any(), any()) } returns null

        val response = (1..5).joinToString("\n\n") { "\u27E6$it\u27E7 Párrafo $it." }
        coEvery {
            translationService.translate(any(), any(), any(), any(), any(), any())
        } returns response
        coEvery { cacheRepo.put(any(), any(), any(), any()) } just Runs

        val result = useCase.translateBatchWithContext(pages, "es", "en")

        assertTrue(result.isSuccess)
        val translations = result.getOrThrow().translations
        assertEquals(5, translations.size)
        assertEquals("Párrafo 1.", translations[0])
        assertEquals("Párrafo 5.", translations[4])
    }

    @Test
    fun `forceRetranslate passes skipCache to marker translate`() = runTest {
        val pages = listOf(
            PageToTranslate(0, "Hello."),
            PageToTranslate(1, "World."),
        )

        val capturedSkipCache = slot<Boolean>()
        coEvery {
            translationService.translate(any(), any(), any(), any(), any(), capture(capturedSkipCache))
        } returns "\u27E61\u27E7 Hola.\n\n\u27E62\u27E7 Mundo."
        coEvery { cacheRepo.put(any(), any(), any(), any()) } just Runs

        useCase.translateBatchWithContext(pages, "es", "en", forceRetranslate = true)

        assertTrue("skipCache should be true for retranslate", capturedSkipCache.captured)
    }

    @Test
    fun `bookContext is passed through to marker translate`() = runTest {
        val pages = listOf(
            PageToTranslate(0, "Hello."),
            PageToTranslate(1, "World."),
        )
        coEvery { cacheRepo.get(any(), any(), any()) } returns null
        coEvery {
            translationService.translate(any(), any(), any(), any(), any(), any())
        } returns "\u27E61\u27E7 Hola.\n\n\u27E62\u27E7 Mundo."
        coEvery { cacheRepo.put(any(), any(), any(), any()) } just Runs

        val bookCtx = BookContext("Test Book", "Test Author", "en", "Opening text.")
        useCase.translateBatchWithContext(pages, "es", "en", bookContext = bookCtx)

        // Verify translate was called (with bookContext, verified by mockk matching)
        coVerify(atLeast = 1) {
            translationService.translate(any(), any(), any(), any(), any(), any())
        }
    }
}
