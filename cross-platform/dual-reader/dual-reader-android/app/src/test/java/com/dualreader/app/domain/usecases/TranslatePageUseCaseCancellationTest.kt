package com.dualreader.app.domain.usecases

import com.dualreader.app.domain.repositories.TranslationCacheRepository
import com.dualreader.app.domain.services.TranslationService
import com.dualreader.app.util.AppLogger
import io.mockk.coEvery
import io.mockk.mockk
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Before
import org.junit.Test

/**
 * DR-173: Regression tests for CancellationException handling in TranslatePageUseCase.
 *
 * Same bug as DR-170 (ImportBookUseCase): runCatching() wraps CancellationException
 * in Result.failure, breaking structured concurrency.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class TranslatePageUseCaseCancellationTest {

    private val testDispatcher = StandardTestDispatcher()

    private val mockTranslationService: TranslationService = mockk()
    private val mockCacheRepository: TranslationCacheRepository = mockk()

    private lateinit var useCase: TranslatePageUseCase

    @Before
    fun setup() {
        Dispatchers.setMain(testDispatcher)
        useCase = TranslatePageUseCase(
            translationService = mockTranslationService,
            cacheRepository = mockCacheRepository,
        )
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun invoke_throws_CancellationException_when_coroutine_is_cancelled() = runTest {
        // Arrange: Translation service throws CancellationException
        coEvery {
            mockTranslationService.translate(
                text = any(),
                targetLanguage = any(),
                sourceLanguage = any(),
                context = any(),
                bookContext = any(),
                skipCache = any(),
            )
        } throws CancellationException("Translation cancelled by user")

        coEvery { mockCacheRepository.get(any(), any(), any()) } returns null
        coEvery { mockCacheRepository.put(any(), any(), any(), any()) } returns Unit

        // Act & Assert: CancellationException should be rethrown, not wrapped in Result.failure
        try {
            useCase.invoke(
                text = "Test text",
                targetLanguage = "bg",
                sourceLanguage = "en",
            )
            throw AssertionError("Expected CancellationException to be thrown")
        } catch (e: CancellationException) {
            // Expected: CancellationException was rethrown
            AppLogger.d("DR-173: CancellationException properly rethrown from invoke()")
        } catch (e: AssertionError) {
            throw e
        } catch (e: Exception) {
            throw AssertionError("CancellationException was wrapped in Result.failure: ${e.message}")
        }
    }

    @Test
    fun translateBatch_throws_CancellationException_when_coroutine_is_cancelled() = runTest {
        // Arrange: Translation service throws CancellationException
        coEvery {
            mockTranslationService.translateBatch(
                texts = any(),
                targetLanguage = any(),
                sourceLanguage = any(),
            )
        } throws CancellationException("Batch translation cancelled by user")

        // Act & Assert: CancellationException should be rethrown, not wrapped in Result.failure
        try {
            useCase.translateBatch(
                texts = listOf("Text 1", "Text 2"),
                targetLanguage = "bg",
                sourceLanguage = "en",
            )
            throw AssertionError("Expected CancellationException to be thrown")
        } catch (e: CancellationException) {
            // Expected: CancellationException was rethrown
            AppLogger.d("DR-173: CancellationException properly rethrown from translateBatch()")
        } catch (e: AssertionError) {
            throw e
        } catch (e: Exception) {
            throw AssertionError("CancellationException was wrapped in Result.failure: ${e.message}")
        }
    }

    @Test
    fun invoke_returns_Result_failure_for_non_cancellation_exceptions() = runTest {
        // Arrange: Translation service throws generic Exception (not CancellationException)
        val genericException = RuntimeException("Network error")
        coEvery {
            mockTranslationService.translate(
                text = any(),
                targetLanguage = any(),
                sourceLanguage = any(),
                context = any(),
                bookContext = any(),
                skipCache = any(),
            )
        } throws genericException

        coEvery { mockCacheRepository.get(any(), any(), any()) } returns null
        coEvery { mockCacheRepository.put(any(), any(), any(), any()) } returns Unit

        // Act: Call invoke()
        val result = useCase.invoke(
            text = "Test text",
            targetLanguage = "bg",
            sourceLanguage = "en",
        )

        // Assert: Generic exceptions should still be wrapped in Result.failure
        assert(result.isFailure) { "Result should be failure for generic exceptions" }
        assert(result.exceptionOrNull() == genericException) { "Exception should be preserved in Result" }
        AppLogger.d("DR-173: Generic exceptions still wrapped in Result.failure as expected")
    }

    @Test
    fun translateBatch_returns_Result_failure_for_non_cancellation_exceptions() = runTest {
        // Arrange: Translation service throws generic Exception (not CancellationException)
        val genericException = RuntimeException("Batch network error")
        coEvery {
            mockTranslationService.translateBatch(
                texts = any(),
                targetLanguage = any(),
                sourceLanguage = any(),
            )
        } throws genericException

        // Act: Call translateBatch()
        val result = useCase.translateBatch(
            texts = listOf("Text 1", "Text 2"),
            targetLanguage = "bg",
            sourceLanguage = "en",
        )

        // Assert: Generic exceptions should still be wrapped in Result.failure
        assert(result.isFailure) { "Result should be failure for generic exceptions" }
        assert(result.exceptionOrNull() == genericException) { "Exception should be preserved in Result" }
        AppLogger.d("DR-173: Generic exceptions still wrapped in Result.failure as expected")
    }
}