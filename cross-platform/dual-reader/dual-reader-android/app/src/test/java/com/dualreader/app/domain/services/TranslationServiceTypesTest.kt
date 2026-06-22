package com.dualreader.app.domain.services

import com.dualreader.app.domain.usecases.SerializedBookContext
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class TranslationServiceTypesTest {

    // ── TranslationResult ─────────────────────────────────────────

    @Test
    fun `TranslationResult stores all fields`() {
        val result = TranslationResult(
            translatedText = "hola",
            sourceLanguage = "en",
            targetLanguage = "es",
            provider = "GLM",
            characterCount = 5,
        )
        assertEquals("hola", result.translatedText)
        assertEquals("en", result.sourceLanguage)
        assertEquals("es", result.targetLanguage)
        assertEquals("GLM", result.provider)
        assertEquals(5, result.characterCount)
    }

    @Test
    fun `TranslationResult default cached is false`() {
        val result = TranslationResult("hi", "en", "es", "GLM", 2)
        assertFalse(result.cached)
    }

    @Test
    fun `TranslationResult with cached true`() {
        val result = TranslationResult("hi", "en", "es", "GLM", 2, cached = true)
        assertTrue(result.cached)
    }

    @Test
    fun `TranslationResult copy works`() {
        val original = TranslationResult("hi", "en", "es", "GLM", 2)
        val copy = original.copy(provider = "Gemini")
        assertEquals("Gemini", copy.provider)
        assertEquals("hi", copy.translatedText)
    }

    @Test
    fun `TranslationResult equality`() {
        val r1 = TranslationResult("hi", "en", "es", "GLM", 2)
        val r2 = TranslationResult("hi", "en", "es", "GLM", 2)
        assertEquals(r1, r2)
    }

    // ── TranslationException ──────────────────────────────────────

    @Test
    fun `TranslationException stores message`() {
        val ex = TranslationException("Translation failed")
        assertEquals("Translation failed", ex.message)
    }

    @Test
    fun `TranslationException stores cause`() {
        val cause = RuntimeException("root")
        val ex = TranslationException("wrapper", cause)
        assertEquals("wrapper", ex.message)
        assertEquals(cause, ex.cause)
    }

    @Test
    fun `TranslationException without cause has null cause`() {
        val ex = TranslationException("just a message")
        assertNull(ex.cause)
    }

    @Test
    fun `TranslationException is an Exception`() {
        val ex: Exception = TranslationException("test")
        assertTrue(ex is TranslationException)
    }

    @Test
    fun `TranslationException can be caught as generic Exception`() {
        try {
            throw TranslationException("caught")
        } catch (e: Exception) {
            assertEquals("caught", e.message)
        }
    }

    // ── BatchTranslationResult ────────────────────────────────────

    @Test
    fun `BatchTranslationResult default model is unknown`() {
        val result = BatchTranslationResult(emptyMap())
        assertEquals("unknown", result.model)
    }

    @Test
    fun `BatchTranslationResult with custom model`() {
        val result = BatchTranslationResult(mapOf(0 to "hello"), "gemini-2.5-flash")
        assertEquals("gemini-2.5-flash", result.model)
    }

    @Test
    fun `BatchTranslationResult with multiple translations`() {
        val translations = mapOf(0 to "one", 1 to "two", 2 to "three")
        val result = BatchTranslationResult(translations, "GLM")
        assertEquals(3, result.translations.size)
        assertEquals("two", result.translations[1])
    }

    @Test
    fun `BatchTranslationResult empty translations`() {
        val result = BatchTranslationResult(emptyMap())
        assertTrue(result.translations.isEmpty())
    }

    @Test
    fun `BatchTranslationResult equality`() {
        val r1 = BatchTranslationResult(mapOf(0 to "hi"), "GLM")
        val r2 = BatchTranslationResult(mapOf(0 to "hi"), "GLM")
        assertEquals(r1, r2)
    }

    // ── SerializedBookContext ─────────────────────────────────────

    @Test
    fun `SerializedBookContext stores all fields`() {
        val ctx = SerializedBookContext(
            title = "My Book",
            author = "Jane Doe",
            openingText = "Once upon a time...",
        )
        assertEquals("My Book", ctx.title)
        assertEquals("Jane Doe", ctx.author)
        assertEquals("Once upon a time...", ctx.openingText)
    }

    @Test
    fun `SerializedBookContext with empty strings`() {
        val ctx = SerializedBookContext("", "", "")
        assertEquals("", ctx.title)
    }

    @Test
    fun `SerializedBookContext equality`() {
        val c1 = SerializedBookContext("T", "A", "O")
        val c2 = SerializedBookContext("T", "A", "O")
        assertEquals(c1, c2)
    }

    @Test
    fun `SerializedBookContext copy`() {
        val original = SerializedBookContext("T", "A", "O")
        val copy = original.copy(title = "New Title")
        assertEquals("New Title", copy.title)
        assertEquals("A", copy.author)
    }
}
