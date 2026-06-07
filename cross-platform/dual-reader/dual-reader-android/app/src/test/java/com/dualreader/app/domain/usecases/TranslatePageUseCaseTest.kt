package com.dualreader.app.domain.usecases

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
    private lateinit var useCase: TranslatePageUseCase

    @Before
    fun setUp() {
        translationService = mockk()
        useCase = TranslatePageUseCase(translationService)
    }

    @Test
    fun `invoke - translates single text`() = runTest {
        // Given
        coEvery {
            translationService.translate("Hello world", "es", null, null)
        } returns "Hola mundo"

        // When
        val result = useCase("Hello world", "es")

        // Then
        assertTrue(result.isSuccess)
        assertEquals("Hola mundo", result.getOrThrow())
    }

    @Test
    fun `invoke - passes source language when provided`() = runTest {
        // Given
        coEvery {
            translationService.translate("Bonjour", "en", "fr", null)
        } returns "Hello"

        // When
        val result = useCase("Bonjour", "en", sourceLanguage = "fr")

        // Then
        assertTrue(result.isSuccess)
        coVerify { translationService.translate("Bonjour", "en", "fr", null) }
    }

    @Test
    fun `invoke - wraps service exception in failure result`() = runTest {
        // Given
        coEvery {
            translationService.translate(any(), any(), any(), any())
        } throws RuntimeException("API error")

        // When
        val result = useCase("text", "es")

        // Then
        assertTrue(result.isFailure)
    }

    @Test
    fun `translateBatch - translates multiple texts`() = runTest {
        // Given
        val input = listOf("Hello", "Goodbye", "Thanks")
        val expected = listOf("Hola", "Adiós", "Gracias")
        coEvery {
            translationService.translateBatch(input, "es", null)
        } returns expected

        // When
        val result = useCase.translateBatch(input, "es")

        // Then
        assertTrue(result.isSuccess)
        assertEquals(expected, result.getOrThrow())
    }

    @Test
    fun `translateBatch - empty list returns empty list`() = runTest {
        // Given
        coEvery { translationService.translateBatch(emptyList(), "es", null) } returns emptyList()

        // When
        val result = useCase.translateBatch(emptyList(), "es")

        // Then
        assertTrue(result.isSuccess)
        assertEquals(emptyList<String>(), result.getOrThrow())
    }
}
