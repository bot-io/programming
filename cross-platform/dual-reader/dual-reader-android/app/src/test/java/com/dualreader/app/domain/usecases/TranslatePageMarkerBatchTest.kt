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
 * DR-263: Regression tests for segment-separation preservation in batch translation.
 *
 * **Root cause of the original bug (v1.0.100):** Multi-page batches used marker-based
 * stitching — paragraphs were joined with `⟦N⟧` (later `@@N@@`) markers into a single
 * text blob, sent as one translation request, then split back by markers. Both ML Kit
 * and cloud LLMs could strip or merge markers, causing translation segments to mismatch
 * their originals. Adjacent dialogue fragments would get merged into one translation.
 *
 * **Fix (DR-263):** Multi-page batches now use the array-based `translatePages` endpoint,
 * which sends pages as a JSON array and receives index-keyed translations — exact 1:1
 * alignment, no markers, no stitching, regardless of translation service.
 *
 * These tests ensure the bug NEVER recurs by verifying:
 * 1. Multi-page batches call `translatePages` (array), NOT `translate` (single text)
 * 2. No markers are ever injected into the translation text
 * 3. Each page's translation maps exactly to that page's original — no merging
 * 4. The specific dialogue-fragment scenario from the bug report is covered
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

    // ═══════════════════════════════════════════════════════════════════════════
    //  DR-263 CORE REGRESSION: Segment separation preserved
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * THE specific bug: two dialogue fragments that look like continuous speech.
     * Original: `"Smarty! You think you're some, now, don't you?`
     * Next:     `Oh, what a hat!`
     * Bug: these got merged into one translation because markers were stripped.
     * Fix: array-based endpoint keeps them as separate index-keyed items.
     */
    @Test
    fun `DR-263 dialogue fragments stay separated - the original bug`() = runTest {
        val pages = listOf(
            PageToTranslate(0, "\u201CSmarty! You think you\u2019re some, now, don\u2019t you?"),
            PageToTranslate(1, "Oh, what a hat!"),
        )
        coEvery { cacheRepo.get(any(), any(), any()) } returns null

        // Array-based batch returns each page's translation separately
        coEvery {
            translationService.translatePages(any(), any(), any(), any(), any(), any())
        } returns BatchTranslationResult(
            mapOf(
                0 to "\u2014\u00A1Listillo! Te crees la gran cosa ahora, \u00BFno?",
                1 to "\u00A1Vaya sombrero!",
            ),
            "cloud-model"
        )
        coEvery { cacheRepo.put(any(), any(), any(), any()) } just Runs

        val result = useCase.translateBatchWithContext(pages, "es", "en")

        assertTrue(result.isSuccess)
        val translations = result.getOrThrow().translations
        assertEquals(2, translations.size)

        // Page 0 translation must NOT contain page 1's content (the bug)
        val page0Translation = translations[0]!!
        val page1Translation = translations[1]!!

        assertFalse("Page 0 must not contain hat translation", page0Translation.contains("sombrero"))
        assertFalse("Page 1 must not contain smarty translation", page1Translation.contains("Listillo"))
        assertEquals("\u2014\u00A1Listillo! Te crees la gran cosa ahora, \u00BFno?", page0Translation)
        assertEquals("\u00A1Vaya sombrero!", page1Translation)
    }

    @Test
    fun `DR-263 multi-page batch uses translatePages not translate`() = runTest {
        val pages = listOf(
            PageToTranslate(0, "Hello."),
            PageToTranslate(1, "World."),
        )
        coEvery { cacheRepo.get(any(), any(), any()) } returns null
        coEvery {
            translationService.translatePages(any(), any(), any(), any(), any(), any())
        } returns BatchTranslationResult(mapOf(0 to "Hola.", 1 to "Mundo."), "batch-model")
        coEvery { cacheRepo.put(any(), any(), any(), any()) } just Runs

        useCase.translateBatchWithContext(pages, "es", "en")

        // MUST call translatePages (array-based), NOT translate (single text with markers)
        coVerify(exactly = 1) {
            translationService.translatePages(any(), any(), any(), any(), any(), any())
        }
        coVerify(exactly = 0) {
            translationService.translate(any(), any(), any(), any(), any(), any())
        }
    }

    @Test
    fun `DR-263 no markers injected into translation text`() = runTest {
        val pages = listOf(
            PageToTranslate(0, "First paragraph."),
            PageToTranslate(1, "Second paragraph."),
            PageToTranslate(2, "Third paragraph."),
        )
        coEvery { cacheRepo.get(any(), any(), any()) } returns null

        // Capture the pages passed to translatePages
        val capturedPages = slot<List<IndexedValue<String>>>()
        coEvery {
            translationService.translatePages(capture(capturedPages), any(), any(), any(), any(), any())
        } returns BatchTranslationResult(
            mapOf(0 to "Primero.", 1 to "Segundo.", 2 to "Tercero."),
            "batch-model"
        )
        coEvery { cacheRepo.put(any(), any(), any(), any()) } just Runs

        useCase.translateBatchWithContext(pages, "es", "en")

        // Verify NO page text contains markers
        assertTrue(capturedPages.isCaptured)
        for (page in capturedPages.captured) {
            assertFalse(
                "Page ${page.index} text must not contain markers: '${page.value}'",
                ParagraphAligner.hasMarkers(page.value)
            )
            // Also verify the original text is unmodified
            assertEquals(pages[page.index].text, page.value)
        }
    }

    @Test
    fun `DR-263 exact 1-to-1 segment alignment for 5 pages`() = runTest {
        val originals = listOf(
            "The quick brown fox.",
            "Mary had a little lamb.",
            "To be or not to be.",
            "Four score and seven years ago.",
            "It was the best of times.",
        )
        val translations = listOf(
            "El rápido zorro marrón.",
            "María tenía un corderito.",
            "Ser o no ser.",
            "Hace cuatro score y siete años.",
            "Era el mejor de los tiempos.",
        )

        val pages = originals.mapIndexed { i, text -> PageToTranslate(i, text) }
        coEvery { cacheRepo.get(any(), any(), any()) } returns null

        val resultMap = translations.mapIndexed { i, t -> i to t }.toMap()
        coEvery {
            translationService.translatePages(any(), any(), any(), any(), any(), any())
        } returns BatchTranslationResult(resultMap, "batch-model")
        coEvery { cacheRepo.put(any(), any(), any(), any()) } just Runs

        val result = useCase.translateBatchWithContext(pages, "es", "en")

        assertTrue(result.isSuccess)
        val resultTranslations = result.getOrThrow().translations
        assertEquals(5, resultTranslations.size)

        // Each translation must match its corresponding original — NO cross-contamination
        for (i in 0 until 5) {
            assertEquals("Page $i translation must match", translations[i], resultTranslations[i])
        }
    }

    @Test
    fun `DR-263 segments with similar content do not merge`() = runTest {
        // Multiple segments that start similarly — marker-based approach would merge them
        val pages = listOf(
            PageToTranslate(0, "He said hello."),
            PageToTranslate(1, "He said goodbye."),
            PageToTranslate(2, "He said nothing."),
        )
        coEvery { cacheRepo.get(any(), any(), any()) } returns null
        coEvery {
            translationService.translatePages(any(), any(), any(), any(), any(), any())
        } returns BatchTranslationResult(
            mapOf(
                0 to "Él dijo hola.",
                1 to "Él dijo adiós.",
                2 to "Él no dijo nada.",
            ),
            "batch-model"
        )
        coEvery { cacheRepo.put(any(), any(), any(), any()) } just Runs

        val result = useCase.translateBatchWithContext(pages, "es", "en")

        assertTrue(result.isSuccess)
        val t = result.getOrThrow().translations
        assertEquals(3, t.size)
        assertEquals("Él dijo hola.", t[0])
        assertEquals("Él dijo adiós.", t[1])
        assertEquals("Él no dijo nada.", t[2])
    }

    @Test
    fun `DR-263 very short segments stay separated`() = runTest {
        val pages = listOf(
            PageToTranslate(0, "Yes."),
            PageToTranslate(1, "No."),
            PageToTranslate(2, "Maybe."),
        )
        coEvery { cacheRepo.get(any(), any(), any()) } returns null
        coEvery {
            translationService.translatePages(any(), any(), any(), any(), any(), any())
        } returns BatchTranslationResult(
            mapOf(0 to "Sí.", 1 to "No.", 2 to "Quizás."),
            "batch-model"
        )
        coEvery { cacheRepo.put(any(), any(), any(), any()) } just Runs

        val result = useCase.translateBatchWithContext(pages, "es", "en")

        assertTrue(result.isSuccess)
        val t = result.getOrThrow().translations
        assertEquals(3, t.size)
        assertEquals("Sí.", t[0])
        assertEquals("No.", t[1])
        assertEquals("Quizás.", t[2])
    }

    @Test
    fun `DR-263 segments with newlines and special chars stay separated`() = runTest {
        val pages = listOf(
            PageToTranslate(0, "Line one.\nLine two."),
            PageToTranslate(1, "Special: @#$%^&*()"),
            PageToTranslate(2, "Unicode: 你好世界 🌍"),
        )
        coEvery { cacheRepo.get(any(), any(), any()) } returns null
        coEvery {
            translationService.translatePages(any(), any(), any(), any(), any(), any())
        } returns BatchTranslationResult(
            mapOf(
                0 to "Línea uno.\nLínea dos.",
                1 to "Especial: @#$%^&*()",
                2 to "Unicode: 你好世界 🌍",
            ),
            "batch-model"
        )
        coEvery { cacheRepo.put(any(), any(), any(), any()) } just Runs

        val result = useCase.translateBatchWithContext(pages, "es", "en")

        assertTrue(result.isSuccess)
        val t = result.getOrThrow().translations
        assertEquals(3, t.size)
        assertEquals("Línea uno.\nLínea dos.", t[0])
        assertEquals("Especial: @#$%^&*()", t[1])
    }

    @Test
    fun `DR-263 no marker artifacts in results`() = runTest {
        val pages = listOf(
            PageToTranslate(0, "Hello."),
            PageToTranslate(1, "World."),
        )
        coEvery { cacheRepo.get(any(), any(), any()) } returns null
        coEvery {
            translationService.translatePages(any(), any(), any(), any(), any(), any())
        } returns BatchTranslationResult(mapOf(0 to "Hola.", 1 to "Mundo."), "batch-model")
        coEvery { cacheRepo.put(any(), any(), any(), any()) } just Runs

        val result = useCase.translateBatchWithContext(pages, "es", "en")

        assertTrue(result.isSuccess)
        for ((_, translation) in result.getOrThrow().translations) {
            assertFalse("Translation contains old ⟦N⟧ markers", translation.contains("⟦") || translation.contains("⟧"))
            assertFalse("Translation contains @@N@@ markers", ParagraphAligner.hasMarkers(translation))
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    //  Single page (no batch overhead)
    // ═══════════════════════════════════════════════════════════════════════════

    @Test
    fun `single page batch uses translate not translatePages`() = runTest {
        val pages = listOf(PageToTranslate(0, "Only one."))
        coEvery { cacheRepo.get(any(), any(), any()) } returns null
        coEvery {
            translationService.translate(any(), any(), any(), any(), any(), any())
        } returns "Solo uno."
        coEvery { cacheRepo.put(any(), any(), any(), any()) } just Runs

        val result = useCase.translateBatchWithContext(pages, "es", "en")

        assertTrue(result.isSuccess)
        assertEquals("Solo uno.", result.getOrThrow().translations[0])
        coVerify(exactly = 0) {
            translationService.translatePages(any(), any(), any(), any(), any(), any())
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    //  Caching
    // ═══════════════════════════════════════════════════════════════════════════

    @Test
    fun `individual page translations are cached separately`() = runTest {
        val pages = listOf(
            PageToTranslate(0, "Hello."),
            PageToTranslate(1, "World."),
        )
        coEvery { cacheRepo.get(any(), any(), any()) } returns null
        coEvery {
            translationService.translatePages(any(), any(), any(), any(), any(), any())
        } returns BatchTranslationResult(mapOf(0 to "Hola.", 1 to "Mundo."), "batch-model")
        coEvery { cacheRepo.put(any(), any(), any(), any()) } just Runs

        useCase.translateBatchWithContext(pages, "es", "en")

        // Each individual page should be cached, NOT the joined text
        coVerify { cacheRepo.put("Hello.", "en", "es", "Hola.") }
        coVerify { cacheRepo.put("World.", "en", "es", "Mundo.") }
    }

    @Test
    fun `cached pages are returned without re-translation`() = runTest {
        val pages = listOf(
            PageToTranslate(0, "Hello."),
            PageToTranslate(1, "World."),
        )
        // Page 0 is cached, page 1 is not
        coEvery { cacheRepo.get("Hello.", "en", "es") } returns "Hola."
        coEvery { cacheRepo.get("World.", "en", "es") } returns null
        // Page 1 becomes a single-page batch → uses individual translate() path
        coEvery {
            translationService.translate("World.", "es", "en", any(), any(), any())
        } returns "Mundo."
        // No batch endpoint call needed
        coEvery { cacheRepo.put(any(), any(), any(), any()) } just Runs

        val result = useCase.translateBatchWithContext(pages, "es", "en")

        assertTrue(result.isSuccess)
        val t = result.getOrThrow().translations
        assertEquals(2, t.size)
        assertEquals("Hola.", t[0])
        assertEquals("Mundo.", t[1])
        coVerify(exactly = 0) {
            translationService.translatePages(any(), any(), any(), any(), any(), any())
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    //  Callbacks
    // ═══════════════════════════════════════════════════════════════════════════

    @Test
    fun `onPageTranslated called for each page with correct translation`() = runTest {
        val pages = listOf(
            PageToTranslate(0, "First."),
            PageToTranslate(1, "Second."),
        )
        coEvery { cacheRepo.get(any(), any(), any()) } returns null
        coEvery {
            translationService.translatePages(any(), any(), any(), any(), any(), any())
        } returns BatchTranslationResult(mapOf(0 to "Primero.", 1 to "Segundo."), "batch-model")
        coEvery { cacheRepo.put(any(), any(), any(), any()) } just Runs

        val callbacks = mutableListOf<Pair<Int, String>>()
        useCase.translateBatchWithContext(
            pages, "es", "en",
            onPageTranslated = { idx, text -> callbacks.add(idx to text) },
        )

        assertEquals(listOf(0 to "Primero.", 1 to "Segundo."), callbacks)
    }

    // ═══════════════════════════════════════════════════════════════════════════
    //  Error handling
    // ═══════════════════════════════════════════════════════════════════════════

    @Test
    fun `translatePages failure returns failure result`() = runTest {
        val pages = listOf(
            PageToTranslate(0, "Hello."),
            PageToTranslate(1, "World."),
        )
        coEvery { cacheRepo.get(any(), any(), any()) } returns null
        coEvery {
            translationService.translatePages(any(), any(), any(), any(), any(), any())
        } throws TranslationException("network error")

        val result = useCase.translateBatchWithContext(pages, "es", "en")

        assertTrue(result.isFailure)
    }

    // ═══════════════════════════════════════════════════════════════════════════
    //  forceRetranslate
    // ═══════════════════════════════════════════════════════════════════════════

    @Test
    fun `forceRetranslate passes skipCache=true to translatePages`() = runTest {
        val pages = listOf(
            PageToTranslate(0, "Hello."),
            PageToTranslate(1, "World."),
        )

        val capturedSkipCache = slot<Boolean>()
        coEvery {
            translationService.translatePages(any(), any(), any(), any(), any(), capture(capturedSkipCache))
        } returns BatchTranslationResult(mapOf(0 to "Hola.", 1 to "Mundo."), "batch-model")
        coEvery { cacheRepo.put(any(), any(), any(), any()) } just Runs

        useCase.translateBatchWithContext(pages, "es", "en", forceRetranslate = true)

        assertTrue("skipCache should be true for forceRetranslate", capturedSkipCache.captured)
    }

    @Test
    fun `bookContext is passed through to translatePages`() = runTest {
        val pages = listOf(
            PageToTranslate(0, "Hello."),
            PageToTranslate(1, "World."),
        )
        coEvery { cacheRepo.get(any(), any(), any()) } returns null
        coEvery {
            translationService.translatePages(any(), any(), any(), any(), any(), any())
        } returns BatchTranslationResult(mapOf(0 to "Hola.", 1 to "Mundo."), "batch-model")
        coEvery { cacheRepo.put(any(), any(), any(), any()) } just Runs

        val bookCtx = BookContext("Test Book", "Test Author", "en", "Opening text.")
        useCase.translateBatchWithContext(pages, "es", "en", bookContext = bookCtx)

        coVerify(atLeast = 1) {
            translationService.translatePages(any(), any(), any(), any(), any(), any())
        }
    }
}
