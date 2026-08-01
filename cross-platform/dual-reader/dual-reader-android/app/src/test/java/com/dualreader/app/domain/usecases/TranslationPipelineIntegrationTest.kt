package com.dualreader.app.domain.usecases


import com.dualreader.app.data.translation.FallbackTranslationService
import com.dualreader.app.domain.repositories.TranslationCacheRepository
import com.dualreader.app.domain.services.BatchTranslationResult
import com.dualreader.app.domain.services.TranslationException
import com.dualreader.app.domain.services.TranslationService
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.impl.annotations.RelaxedMockK
import io.mockk.junit4.MockKRule
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test

/**
 * End-to-end integration tests for the translation pipeline.
 *
 * Unlike [TranslatePageUseCaseTest] (which mocks the TranslationService), these tests
 * wire up the REAL [FallbackTranslationService] between the use case and the mocked
 * cloud/ML-Kit services. This verifies the full composition actually works:
 *
 *   text → TranslatePageUseCase → FallbackTranslationService → cloud (mock) / ML-Kit (mock) → result
 *
 * Covers DR-041 acceptance criteria:
 *  1. End-to-end translate through the real fallback chain
 *  2. skipCache flag propagation
 *  3. Fallback chain (ML Kit → cloud)
 *  4. Batch translation error recovery
 *
 * NOTE on MockK + Kotlin default params: calls that use defaulted trailing args (e.g. the
 * cloud `translate` call from FallbackService omits `skipCache`) must be stubbed/verified
 * with matchers ONLY for the explicitly-passed args (≤5 for translate, 3 for ML-Kit). The
 * batch `translatePages` path passes all args explicitly so 6-matchers verify correctly.
 */
class TranslationPipelineIntegrationTest {

    @get:Rule
    val mockkRule = MockKRule(this)

    @RelaxedMockK
    lateinit var cloudService: TranslationService

    @RelaxedMockK
    lateinit var mlKitService: TranslationService

    @RelaxedMockK
    lateinit var cacheRepository: TranslationCacheRepository

    private lateinit var fallbackService: FallbackTranslationService
    private lateinit var useCase: TranslatePageUseCase

    @Before
    fun setup() {
        fallbackService = FallbackTranslationService(
            cloudService = cloudService,
            mlKitService = mlKitService,
        )
        useCase = TranslatePageUseCase(fallbackService, cacheRepository)
        // Relaxed mock returns "" (not null) for String? — force explicit cache misses.
        coEvery { cacheRepository.get(any(), any(), any()) } returns null
        coEvery { cacheRepository.put(any(), any(), any(), any(), any()) } returns Unit
        // DR-147: @RelaxedMockK returns empty string for ML Kit by default, which is treated as failure
        // Tests that need ML Kit to succeed will override this in their body with explicit coEvery
        // Tests that need ML Kit to throw will override this with explicit coEvery throws
    }

    // ════════════════════════════════════════════════════════════════════════
    //  CRITERION 1: End-to-end (text → UseCase → Fallback → cloud mock → result)
    // ════════════════════════════════════════════════════════════════════════

    @Test
    fun `e2e - cache miss translates through cloud via fallback and caches result`() = runTest {
        // DR-147: ML Kit throws to fall through to cloud (Tier 3)
        coEvery { mlKitService.translate(any(), any(), any()) } throws TranslationException("ML Kit unavailable")
        coEvery { cloudService.translate(any(), any(), any(), any()) } returns "Здравей"

        val result = useCase("hello", targetLanguage = "bg", sourceLanguage = "en")

        assertTrue(result.isSuccess)
        assertEquals("Здравей", result.getOrThrow())
        coVerify(exactly = 1) { cloudService.translate("hello", "bg", "en", any()) }
        coVerify(exactly = 1) { cacheRepository.put("hello", "en", "bg", "Здравей") }
    }

    @Test
    fun `e2e - cache hit returns cached value without invoking fallback`() = runTest {
        coEvery { cacheRepository.get("hello", "en", "bg") } returns "Здравей (cached)"

        val result = useCase("hello", targetLanguage = "bg", sourceLanguage = "en")

        assertTrue(result.isSuccess)
        assertEquals("Здравей (cached)", result.getOrThrow())
        coVerify(exactly = 0) { cloudService.translate(any(), any(), any(), any()) }
        coVerify(exactly = 0) { mlKitService.translate(any(), any(), any()) }
        coVerify(exactly = 0) { cacheRepository.put(any(), any(), any(), any()) }
    }

    @Test
    fun `e2e - batch with multiple pages translates through cloud batch endpoint`() = runTest {
        // DR-147: ML Kit throws to fall through to cloud (Tier 3)
        coEvery { mlKitService.translate(any(), any(), any()) } throws TranslationException("ML Kit unavailable")
        val pages = listOf(
            PageToTranslate(index = 0, text = "First page"),
            PageToTranslate(index = 1, text = "Second page"),
        )
        coEvery { cloudService.translatePages(any(), "bg", "en", any()) } returns
            BatchTranslationResult(mapOf(0 to "Първа", 1 to "Втора"), "gemini-2.5-flash")

        val result = useCase.translateBatchWithContext(pages, targetLanguage = "bg", sourceLanguage = "en")

        assertTrue(result.isSuccess)
        val translations = result.getOrThrow().translations
        assertEquals("Първа", translations[0])
        assertEquals("Втора", translations[1])
        assertEquals("gemini-2.5-flash", result.getOrThrow().model)
        coVerify(exactly = 1) { cloudService.translatePages(any(), "bg", "en", any()) }
        coVerify(exactly = 1) { cacheRepository.put("First page", "en", "bg", "Първа") }
        coVerify(exactly = 1) { cacheRepository.put("Second page", "en", "bg", "Втора") }
    }

    @Test
    fun `e2e - book context is serialized and propagated through fallback to cloud`() = runTest {
        // DR-147: ML Kit throws to fall through to cloud (Tier 3)
        coEvery { mlKitService.translate(any(), any(), any()) } throws TranslationException("ML Kit unavailable")
        coEvery { cloudService.translate(any(), any(), any(), any()) } returns "translated"
        val ctx = BookContext(
            title = "The Old Man and the Sea",
            author = "Hemingway",
            language = "en",
            openingText = "He was an old man who fished alone...",
        )

        useCase("hello", targetLanguage = "bg", sourceLanguage = "en", bookContext = ctx)

        // The SerializedBookContext (title/author) must reach the cloud service through
        // the real FallbackTranslationService. translate() passes the first 5 args explicitly.
        coVerify {
            cloudService.translate(
                eq("hello"), eq("bg"), eq("en"), any(),
                match { it != null && it.title == "The Old Man and the Sea" && it.author == "Hemingway" },
            )
        }
    }

    // ════════════════════════════════════════════════════════════════════════
    //  CRITERION 2: skipCache flag propagation
    // ════════════════════════════════════════════════════════════════════════

    @Test
    fun `skipCache - forceRetranslate bypasses cache read end-to-end`() = runTest {
        // DR-147: ML Kit throws to fall through to cloud (Tier 3)
        coEvery { mlKitService.translate(any(), any(), any()) } throws TranslationException("ML Kit unavailable")
        coEvery { cloudService.translate(any(), any(), any(), any(), any(), eq(true)) } returns "Fresh translation"

        val result = useCase("hello", targetLanguage = "bg", sourceLanguage = "en", forceRetranslate = true)

        assertTrue(result.isSuccess)
        assertEquals("Fresh translation", result.getOrThrow())
        // Cache read MUST be skipped
        coVerify(exactly = 0) { cacheRepository.get(any(), any(), any()) }
        // skipCache=true now reaches the cloud through FallbackTranslationService (DR-047 fix)
        coVerify(exactly = 1) { cloudService.translate("hello", "bg", "en", any(), any(), eq(true)) }
        // Fresh result overwrites the cache entry
        coVerify(exactly = 1) { cacheRepository.put("hello", "en", "bg", "Fresh translation") }
    }

    @Test
    fun `skipCache - batch forceRetranslate propagates skipCache=true to cloud endpoint`() = runTest {
        // DR-147: ML Kit throws to fall through to cloud (Tier 3)
        coEvery { mlKitService.translate(any(), any(), any()) } throws TranslationException("ML Kit unavailable")
        val pages = listOf(
            PageToTranslate(index = 0, text = "P0"),
            PageToTranslate(index = 1, text = "P1"),
        )
        coEvery { cloudService.translatePages(any(), "bg", "en", any()) } returns
            BatchTranslationResult(mapOf(0 to "T0", 1 to "T1"), "gemini")

        useCase.translateBatchWithContext(
            pages, targetLanguage = "bg", sourceLanguage = "en", forceRetranslate = true,
        )

        // skipCache=true must reach the cloud through the real Fallback batch path (all 6 args explicit)
        coVerify { cloudService.translatePages(any(), "bg", "en", any(), any(), eq(true)) }
        coVerify(exactly = 0) { cacheRepository.get(any(), any(), any()) }
    }

    @Test
    fun `skipCache - normal batch passes skipCache=false to cloud endpoint`() = runTest {
        // DR-147: ML Kit throws to fall through to cloud (Tier 3)
        coEvery { mlKitService.translate(any(), any(), any()) } throws TranslationException("ML Kit unavailable")
        val pages = listOf(
            PageToTranslate(index = 0, text = "P0"),
            PageToTranslate(index = 1, text = "P1"),
        )
        coEvery { cloudService.translatePages(any(), "bg", "en", any()) } returns
            BatchTranslationResult(mapOf(0 to "T0", 1 to "T1"), "gemini")

        useCase.translateBatchWithContext(pages, targetLanguage = "bg", sourceLanguage = "en")

        coVerify { cloudService.translatePages(any(), "bg", "en", any(), any(), eq(false)) }
    }

    // ════════════════════════════════════════════════════════════════════════
    // ════════════════════════════════════════════════════════════════════════
    //  CRITERION 3: Fallback chain (ML Kit → cloud)
    // ════════════════════════════════════════════════════════════════════════

    @Test
    fun `fallback - ML Kit failure falls back to cloud through use case`() = runTest {
        // ML Kit fails (Tier 1), cloud succeeds (Tier 3)
        coEvery { mlKitService.translate(any(), any(), any()) } throws TranslationException("ML Kit unavailable")
        coEvery { cloudService.translate(any(), any(), any(), any()) } returns "Здравей (cloud)"

        val result = useCase("hello", targetLanguage = "bg", sourceLanguage = "en")

        assertTrue(result.isSuccess)
        assertEquals("Здравей (cloud)", result.getOrThrow())
        coVerify(exactly = 1) { mlKitService.translate("hello", "bg", "en") }
        coVerify(exactly = 1) { cloudService.translate("hello", "bg", "en", any()) }
        coVerify(exactly = 1) { cacheRepository.put("hello", "en", "bg", "Здравей (cloud)") }
    }

    @Test
    fun `fallback - ML Kit and cloud both fail returns Result failure`() = runTest {
        // ML Kit fails (Tier 1), cloud also fails (Tier 3)
        coEvery { mlKitService.translate(any(), any(), any()) } throws TranslationException("ML Kit unavailable")
        coEvery { cloudService.translate(any(), any(), any(), any()) } throws TranslationException("cloud timeout")

        val result = useCase("hello", targetLanguage = "bg", sourceLanguage = "en")

        assertTrue(result.isFailure)
        val ex = result.exceptionOrNull()
        assertNotNull(ex)
        assertTrue(ex!!.message!!.contains("Translation failed"))
        assertTrue(ex.message!!.contains("cloud timeout"))
        coVerify(exactly = 0) { cacheRepository.put(any(), any(), any(), any()) }
    }

    @Test
    fun `fallback - batch cloud returns partial results, throws exception`() = runTest {
        // DR-147: ML Kit throws to fall through to cloud (Tier 3)
        // DR-054: Cloud partial success is a failure - throw instead of silent data loss
        coEvery { mlKitService.translate(any(), any(), any()) } throws TranslationException("ML Kit unavailable")
        val pages = listOf(
            PageToTranslate(index = 0, text = "P0"),
            PageToTranslate(index = 1, text = "P1"),
            PageToTranslate(index = 2, text = "P2"),
        )
        coEvery { cloudService.translatePages(any(), "bg", "en", any()) } returns
            BatchTranslationResult(mapOf(0 to "T0", 2 to "T2"), "gemini")

        val result = useCase.translateBatchWithContext(pages, targetLanguage = "bg", sourceLanguage = "en")

        // DR-054: Cloud must return all requested pages or throw
        assertTrue(result.isFailure)
        val ex = result.exceptionOrNull()
        assertNotNull(ex)
        assertTrue(ex!!.message!!.contains("missing"))
    }

    // ════════════════════════════════════════════════════════════════════════
    //  CRITERION 4: Batch translation error recovery
    // ════════════════════════════════════════════════════════════════════════

    @Test
    fun `recovery - batch cloud throws, recovers via ML Kit per page`() = runTest {
        val pages = listOf(
            PageToTranslate(index = 0, text = "P0"),
            PageToTranslate(index = 1, text = "P1"),
        )
        coEvery { cloudService.translatePages(any(), "bg", "en", any()) } throws
            TranslationException("batch endpoint 500")
        // Fail-fast design: batch failure → ML Kit for all pages (no individual cloud calls)
        coEvery { mlKitService.translate("P0", "bg", "en") } returns "T0"
        coEvery { mlKitService.translate("P1", "bg", "en") } returns "T1"

        val result = useCase.translateBatchWithContext(pages, targetLanguage = "bg", sourceLanguage = "en")

        assertTrue(result.isSuccess)
        val translations = result.getOrThrow().translations
        assertEquals("T0", translations[0])
        assertEquals("T1", translations[1])
        coVerify(exactly = 1) { cacheRepository.put("P0", "en", "bg", "T0") }
        coVerify(exactly = 1) { cacheRepository.put("P1", "en", "bg", "T1") }
    }

    @Test
    fun `recovery - batch failure falls back to ML Kit per page`() = runTest {
        val pages = listOf(
            PageToTranslate(index = 0, text = "P0"),
            PageToTranslate(index = 1, text = "P1"),
        )
        coEvery { cloudService.translatePages(any(), "bg", "en", any()) } throws TranslationException("batch down")
        coEvery { cloudService.translate(any(), any(), any(), any()) } throws TranslationException("cloud down")
        coEvery { mlKitService.translate("P0", "bg", "en") } returns "T0-ml"
        coEvery { mlKitService.translate("P1", "bg", "en") } returns "T1-ml"

        val result = useCase.translateBatchWithContext(pages, targetLanguage = "bg", sourceLanguage = "en")

        assertTrue(result.isSuccess)
        assertEquals("T0-ml", result.getOrThrow().translations[0])
        assertEquals("T1-ml", result.getOrThrow().translations[1])
    }

    @Test
    fun `recovery - batch cloud returns partial results, callback not invoked for missing pages`() = runTest {
        // DR-147: ML Kit throws to fall through to cloud (Tier 3)
        // DR-054: Cloud partial success is a failure - throw before callbacks
        coEvery { mlKitService.translate(any(), any(), any()) } throws TranslationException("ML Kit unavailable")
        val pages = listOf(
            PageToTranslate(index = 0, text = "P0"),
            PageToTranslate(index = 1, text = "P1"),
            PageToTranslate(index = 2, text = "P2"),
        )
        coEvery { cloudService.translatePages(any(), "bg", "en", any()) } returns
            BatchTranslationResult(mapOf(0 to "T0", 2 to "T2"), "gemini")

        val callbacks = mutableSetOf<Pair<Int, String>>()
        val result = useCase.translateBatchWithContext(
            pages, targetLanguage = "bg", sourceLanguage = "en",
            onPageTranslated = { idx, text -> callbacks.add(idx to text) },
        )

        // DR-054: Cloud partial results cause failure - no callbacks invoked
        assertTrue(result.isFailure)
        assertEquals(0, callbacks.size)
    }

    @Test
    fun `recovery - total batch failure with no fallback returns Result failure`() = runTest {
        val pages = listOf(
            PageToTranslate(index = 0, text = "P0"),
            PageToTranslate(index = 1, text = "P1"),
        )
        coEvery { cloudService.translatePages(any(), "bg", "en", any()) } throws TranslationException("batch down")
        coEvery { cloudService.translate(any(), any(), any(), any()) } throws TranslationException("cloud down")
        coEvery { mlKitService.translate(any(), any(), any()) } throws TranslationException("no model")

        val result = useCase.translateBatchWithContext(pages, targetLanguage = "bg", sourceLanguage = "en")

        assertTrue(result.isFailure)
        assertNotNull(result.exceptionOrNull())
    }

    @Test
    fun `recovery - empty page list returns empty result without any service calls`() = runTest {
        val result = useCase.translateBatchWithContext(emptyList(), targetLanguage = "bg", sourceLanguage = "en")

        assertTrue(result.isSuccess)
        assertTrue(result.getOrThrow().translations.isEmpty())
        coVerify(exactly = 0) { cloudService.translatePages(any(), any(), any(), any()) }
        coVerify(exactly = 0) { cloudService.translate(any(), any(), any(), any()) }
    }
}
