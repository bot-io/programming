package com.dualreader.app.ui.screens

import com.dualreader.app.data.translation.LanguageModelInfo
import com.dualreader.app.data.translation.MlKitModelManager
import io.mockk.MockKAnnotations
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.impl.annotations.MockK
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
 * Regression test for DR-191: Verify that loading state is properly reset
 * when CancellationException is thrown in ModelManagementViewModel methods.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class ModelManagementViewModelCancellationTest {

    @MockK
    private lateinit var modelManager: MlKitModelManager

    private lateinit var viewModel: ModelManagementViewModel

    private val testDispatcher = StandardTestDispatcher()

    @Before
    fun setup() {
        MockKAnnotations.init(this)
        Dispatchers.setMain(testDispatcher)
        viewModel = ModelManagementViewModel(modelManager)
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun `loadModels resets isLoading to false on CancellationException`() = runTest {
        // Arrange: Mock getAvailableModels to throw CancellationException
        coEvery { modelManager.getAvailableModels() } throws kotlinx.coroutines.CancellationException("Test cancellation")

        // Act: Call loadModels and advance dispatcher
        viewModel.loadModels()
        testDispatcher.scheduler.advanceUntilIdle()

        // Assert: isLoading should be false, not stuck in loading state
        val state = viewModel.uiState.value
        require(!state.isLoading) { "isLoading should be false after CancellationException, but was ${state.isLoading}" }
    }

    @Test
    fun `loadModels resets isLoading to false on Exception`() = runTest {
        // Arrange: Mock getAvailableModels to throw Exception
        coEvery { modelManager.getAvailableModels() } throws RuntimeException("Test error")

        // Act: Call loadModels and advance dispatcher
        viewModel.loadModels()
        testDispatcher.scheduler.advanceUntilIdle()

        // Assert: isLoading should be false
        val state = viewModel.uiState.value
        require(!state.isLoading) {
            "isLoading should be false after Exception, but was ${state.isLoading}"
        }
        // Error should be set
        require(state.error == "Test error") {
            "Error should be 'Test error', but was '${state.error}'"
        }
    }

    @Test
    fun `loadModels succeeds and resets isLoading to false`() = runTest {
        // Arrange: Mock successful model loading
        val mockModels = listOf(
            LanguageModelInfo("en", "English", true),
            LanguageModelInfo("es", "Spanish", false)
        )
        coEvery { modelManager.getAvailableModels() } returns mockModels

        // Act: Call loadModels and advance dispatcher
        viewModel.loadModels()
        testDispatcher.scheduler.advanceUntilIdle()

        // Assert: isLoading should be false and models should be loaded
        val state = viewModel.uiState.value
        require(!state.isLoading) {
            "isLoading should be false after success, but was ${state.isLoading}"
        }
        require(state.models == mockModels) {
            "Models should be loaded"
        }
        require(state.error == null) {
            "Error should be null after success"
        }
    }

    @Test
    fun `downloadModel cancels and resets downloadingLang to null`() = runTest {
        // Arrange: Mock downloadModel to throw CancellationException
        coEvery { modelManager.downloadModel(any()) } throws kotlinx.coroutines.CancellationException("Test cancellation")

        // Act: Call downloadModel and advance dispatcher
        viewModel.downloadModel("es")
        testDispatcher.scheduler.advanceUntilIdle()

        // Assert: downloadingLang should be null (reset by finally block)
        val state = viewModel.uiState.value
        require(state.downloadingLang == null) {
            "downloadingLang should be null after CancellationException, but was ${state.downloadingLang}"
        }
    }

    @Test
    fun `downloadModel succeeds and resets downloadingLang to null`() = runTest {
        // Arrange: Mock successful download
        val mockModels = listOf(
            LanguageModelInfo("en", "English", true),
            LanguageModelInfo("es", "Spanish", true)
        )
        coEvery { modelManager.downloadModel(any()) } returns true
        coEvery { modelManager.getAvailableModels() } returns mockModels

        // Act: Call downloadModel and advance dispatcher
        viewModel.downloadModel("es")
        testDispatcher.scheduler.advanceUntilIdle()

        // Assert: downloadingLang should be null
        val state = viewModel.uiState.value
        require(state.downloadingLang == null) {
            "downloadingLang should be null after success, but was ${state.downloadingLang}"
        }
        // Models should be reloaded
        coVerify { modelManager.downloadModel("es") }
        coVerify { modelManager.getAvailableModels() }
    }

    @Test
    fun `deleteModel handles CancellationException`() = runTest {
        // Arrange: Mock deleteModel to throw CancellationException
        coEvery { modelManager.deleteModel(any()) } throws kotlinx.coroutines.CancellationException("Test cancellation")

        // Act: Call deleteModel and advance dispatcher
        viewModel.deleteModel("es")
        testDispatcher.scheduler.advanceUntilIdle()

        // Assert: deleteModel was called (exception is rethrown)
        coVerify { modelManager.deleteModel("es") }
    }

    @Test
    fun `deleteModel succeeds and calls loadModels`() = runTest {
        // Arrange: Mock successful delete
        val mockModels = listOf(
            LanguageModelInfo("en", "English", true)
        )
        coEvery { modelManager.deleteModel(any()) } returns true
        coEvery { modelManager.getAvailableModels() } returns mockModels

        // Act: Call deleteModel and advance dispatcher
        viewModel.deleteModel("es")
        testDispatcher.scheduler.advanceUntilIdle()

        // Assert: deleteModel and loadModels were called
        coVerify { modelManager.deleteModel("es") }
        coVerify { modelManager.getAvailableModels() }
        // Models should be updated
        val state = viewModel.uiState.value
        require(state.models.size == 1) {
            "Should have 1 model after delete"
        }
    }
}