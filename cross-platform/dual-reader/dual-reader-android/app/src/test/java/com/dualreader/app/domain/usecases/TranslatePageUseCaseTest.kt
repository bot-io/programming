package com.dualreader.app.domain.usecases

import com.dualreader.app.domain.services.TranslationException
import com.dualreader.app.domain.services.TranslationService
import io.mockk.*
import kotlinx.coroutines.test.runTest
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test

/**
 * Comprehensive tests for TranslatePageUseCase — the context-aware translation orchestrator.
 *
 * Covers:
 * - Single page translation (with/without context)
 * - Context building (truncation, format, both/null)
 * - Batch with context (continuity, callback, error propagation)
 * - Legacy batch (backward compat)
 * - Error wrapping (service failures → Result.failure)
 */
class TranslatePageUseCaseTest {

    private lateinit var translationService: TranslationService
    private lateinit var useCase: TranslatePageUseCase

    @Before
    fun setUp() {
        translationService = mockk()
        useCase = TranslatePageUseCase(translationService)
    }

    // ── Single invoke — happy path ───────────────────────────────────────────

    @Test
    fun `invoke - translates single text without context`() = runTest {
        coEvery { translationService.translate("Hello world", "es", null, null) } returns "Hola mundo"

        val result = useCase("Hello world", "es")
        assertTrue(result.isSuccess)
        assertEquals("Hola mundo", result.getOrThrow())
    }

    @Test
    fun `invoke - passes source language when provided`() = runTest {
        coEvery { translationService.translate("Bonjour", "en", "fr", null) } returns "Hello"

        val result = useCase("Bonjour", "en", sourceLanguage = "fr")
        assertTrue(result.isSuccess)
        coVerify { translationService.translate("Bonjour", "en", "fr", null) }
    }

    @Test
    fun `invoke - passes previous original and translation as context`() = runTest {
        coEvery { translationService.translate(
            eq("Page 2 text"), eq("bg"), eq("en"),
            match { ctx -> ctx != null && ctx.contains("Page 1 translation") && ctx.contains("Page 1 original") }
        ) } returns "Страница 2"

        val result = useCase(
            "Page 2 text", "bg", "en",
            previousOriginal = "Page 1 original",
            previousTranslation = "Page 1 translation"
        )
        assertTrue(result.isSuccess)
        assertEquals("Страница 2", result.getOrThrow())
    }

    @Test
    fun `invoke - passes only previous original when no translation`() = runTest {
        coEvery { translationService.translate(
            eq("Text"), eq("bg"), eq("en"),
            match { ctx -> ctx != null && ctx.contains("Previous original") && !ctx.contains("translation") }
        ) } returns "Текст"

        val result = useCase("Text", "bg", "en", previousOriginal = "Previous original")
        assertTrue(result.isSuccess)
    }

    @Test
    fun `invoke - passes only previous translation when no original`() = runTest {
        coEvery { translationService.translate(
            eq("Text"), eq("bg"), eq("en"),
            match { ctx -> ctx != null && ctx.contains("Previous translation") }
        ) } returns "Текст"

        val result = useCase("Text", "bg", "en", previousTranslation = "Previous translation")
        assertTrue(result.isSuccess)
    }

    @Test
    fun `invoke - context null when no previous info`() = runTest {
        coEvery { translationService.translate("Text", "bg", "en", null) } returns "Текст"

        val result = useCase("Text", "bg", "en")
        assertTrue(result.isSuccess)
        coVerify { translationService.translate("Text", "bg", "en", null) }
    }

    // ── Context building — edge cases ────────────────────────────────────────

    @Test
    fun `invoke - truncates long context to 300 chars`() = runTest {
        val longTranslation = "А".repeat(500)
        coEvery { translationService.translate(
            any(), any(), any(),
            match { ctx -> ctx != null && ctx.contains("А".repeat(300)) && ctx.contains("...") }
        ) } returns "Текст"

        useCase("Text", "bg", "en", previousTranslation = longTranslation)
    }

    @Test
    fun `invoke - context contains do NOT translate instruction`() = runTest {
        coEvery { translationService.translate(
            any(), any(), any(),
            match { ctx -> ctx != null && ctx.contains("do NOT translate") }
        ) } returns "Текст"

        useCase("Text", "bg", "en", previousTranslation = "Some context")
    }

    // ── Single invoke — error paths ──────────────────────────────────────────

    @Test
    fun `invoke - wraps service exception in failure result`() = runTest {
        coEvery { translationService.translate(any(), any(), any(), any()) } throws RuntimeException("API error")

        val result = useCase("text", "es")
        assertTrue(result.isFailure)
    }

    @Test
    fun `invoke - wraps TranslationException in failure result`() = runTest {
        coEvery { translationService.translate(any(), any(), any(), any()) } throws TranslationException("Rate limited")

        val result = useCase("text", "es")
        assertTrue(result.isFailure)
    }

    // ── Batch with context ───────────────────────────────────────────────────

    @Test
    fun `translateBatchWithContext - translates pages one at a time with rolling context`() = runTest {
        // Page 0: no context
        coEvery { translationService.translate("Page 0", "bg", "en", null) } returns "Страница 0"
        // Page 1: gets page 0's translation + original as context
        coEvery { translationService.translate(
            eq("Page 1"), eq("bg"), eq("en"),
            match { ctx -> ctx != null && ctx.contains("Страница 0") && ctx.contains("Page 0") }
        ) } returns "Страница 1"
        // Page 2: gets page 1's translation + original as context
        coEvery { translationService.translate(
            eq("Page 2"), eq("bg"), eq("en"),
            match { ctx -> ctx != null && ctx.contains("Страница 1") && ctx.contains("Page 1") }
        ) } returns "Страница 2"

        val pages = listOf(
            PageToTranslate(0, "Page 0"),
            PageToTranslate(1, "Page 1"),
            PageToTranslate(2, "Page 2"),
        )

        val result = useCase.translateBatchWithContext(pages, "bg", "en")
        assertTrue(result.isSuccess)

        val translations = result.getOrThrow()
        assertEquals(3, translations.size)
        assertEquals("Страница 0", translations[0])
        assertEquals("Страница 1", translations[1])
        assertEquals("Страница 2", translations[2])
    }

    @Test
    fun `translateBatchWithContext - calls onPageTranslated for each page`() = runTest {
        coEvery { translationService.translate(any(), eq("bg"), any(), any()) } returns "Текст"

        val pages = listOf(
            PageToTranslate(5, "Text A"),
            PageToTranslate(10, "Text B"),
        )

        val callbacks = mutableListOf<Pair<Int, String>>()
        useCase.translateBatchWithContext(pages, "bg", "en") { index, translation ->
            callbacks.add(index to translation)
        }

        assertEquals(2, callbacks.size)
        assertEquals(5, callbacks[0].first)
        assertEquals(10, callbacks[1].first)
    }

    @Test
    fun `translateBatchWithContext - returns empty map for empty input`() = runTest {
        val result = useCase.translateBatchWithContext(emptyList(), "bg", "en")
        assertTrue(result.isSuccess)
        assertTrue(result.getOrThrow().isEmpty())
    }

    @Test
    fun `translateBatchWithContext - single page gets no context`() = runTest {
        coEvery { translationService.translate("Only page", "bg", "en", null) } returns "Само страница"

        val result = useCase.translateBatchWithContext(
            listOf(PageToTranslate(0, "Only page")), "bg", "en"
        )
        assertTrue(result.isSuccess)
        assertEquals("Само страница", result.getOrThrow()[0])
    }

    @Test
    fun `translateBatchWithContext - propagates failure on page error`() = runTest {
        coEvery { translationService.translate("Page 0", "bg", "en", null) } returns "Страница 0"
        coEvery { translationService.translate(eq("Page 1"), any(), any(), any()) } throws TranslationException("Timeout")

        val pages = listOf(
            PageToTranslate(0, "Page 0"),
            PageToTranslate(1, "Page 1"),
        )

        val result = useCase.translateBatchWithContext(pages, "bg", "en")
        assertTrue(result.isFailure)
    }

    @Test
    fun `translateBatchWithContext - preserves page indices in result map`() = runTest {
        coEvery { translationService.translate(any(), eq("bg"), any(), any()) } returns "Текст"

        val pages = listOf(
            PageToTranslate(42, "Page forty-two"),
            PageToTranslate(99, "Page ninety-nine"),
        )

        val result = useCase.translateBatchWithContext(pages, "bg", "en")
        val translations = result.getOrThrow()
        assertTrue(translations.containsKey(42))
        assertTrue(translations.containsKey(99))
    }

    // ── Legacy batch ─────────────────────────────────────────────────────────

    @Test
    fun `translateBatch - translates multiple texts`() = runTest {
        val input = listOf("Hello", "Goodbye", "Thanks")
        val expected = listOf("Hola", "Adiós", "Gracias")
        coEvery { translationService.translateBatch(input, "es", null) } returns expected

        val result = useCase.translateBatch(input, "es")
        assertTrue(result.isSuccess)
        assertEquals(expected, result.getOrThrow())
    }

    @Test
    fun `translateBatch - empty list returns empty list`() = runTest {
        coEvery { translationService.translateBatch(emptyList(), "es", null) } returns emptyList()

        val result = useCase.translateBatch(emptyList(), "es")
        assertTrue(result.isSuccess)
        assertEquals(emptyList<String>(), result.getOrThrow())
    }

    @Test
    fun `translateBatch - wraps service error in failure`() = runTest {
        coEvery { translationService.translateBatch(any(), any(), any()) } throws TranslationException("Failed")

        val result = useCase.translateBatch(listOf("Text"), "es")
        assertTrue(result.isFailure)
    }

    @Test
    fun `translateBatch - passes source language`() = runTest {
        coEvery { translationService.translateBatch(any(), eq("bg"), eq("en")) } returns listOf("Текст")

        useCase.translateBatch(listOf("Text"), "bg", "en")
        coVerify { translationService.translateBatch(listOf("Text"), "bg", "en") }
    }
}
