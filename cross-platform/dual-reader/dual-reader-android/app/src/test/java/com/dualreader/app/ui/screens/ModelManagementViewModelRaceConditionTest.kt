package com.dualreader.app.ui.screens

import app.cash.turbine.test
import com.dualreader.app.data.translation.LanguageModelInfo
import com.dualreader.app.data.translation.MlKitModelManager
import io.mockk.coEvery
import io.mockk.mockk
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.delay
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Before
import org.junit.Test

/**
 * Regression test for DR-198: Race condition in ModelManagementViewModel.downloadModel()
 *
 * This test verifies that:
 * 1. Multiple concurrent loadModels() calls don't cause race conditions
 * 2. downloadModel() properly cancels pending loadModels() before launching a new one
 * 3. downloadingLang state is correctly managed during concurrent operations
 */
@ExperimentalCoroutinesApi
class ModelManagementViewModelRaceConditionTest {

    private lateinit var viewModel: ModelManagementViewModel
    private val mockModelManager: MlKitModelManager = mockk()

    private val testDispatcher = StandardTestDispatcher()

    @Before
    fun setup() {
        Dispatchers.setMain(testDispatcher)
        coEvery { mockModelManager.getAvailableModels() } returns emptyList()
        coEvery { mockModelManager.downloadModel(any()) } returns true
        coEvery { mockModelManager.deleteModel(any()) } returns true
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun `loadModels() cancels pending job before starting new one`() = runTest {
        // Arrange
        viewModel = ModelManagementViewModel(mockModelManager)
        val slowModels = listOf(
            LanguageModelInfo("en", "English", true)
        )
        coEvery { mockModelManager.getAvailableModels() } coAnswers {
            delay(100) // Simulate slow load
            slowModels
        }

        // Act: Start multiple loadModels() calls concurrently
        viewModel.loadModels()
        testScheduler.advanceUntilIdle()
        viewModel.loadModels()
        testScheduler.advanceTimeBy(50) // Don't advance enough to finish first load
        viewModel.loadModels()
        testScheduler.advanceUntilIdle()

        // Assert: Should not throw, and state should be consistent
        viewModel.uiState.test {
            val finalState = awaitItem()
            // Verify we got the expected models
            assert(finalState.models == slowModels)
            // Verify loading is complete
            assert(!finalState.isLoading)
            // Verify no error
            assert(finalState.error == null)
        }
    }

    @Test
    fun `downloadModel() handles concurrent calls correctly`() = runTest {
        // Arrange
        viewModel = ModelManagementViewModel(mockModelManager)
        val modelsAfter = listOf(
            LanguageModelInfo("fr", "French", true)
        )
        var callCount = 0
        coEvery { mockModelManager.getAvailableModels() } coAnswers {
            callCount++
            if (callCount > 1) {
                modelsAfter
            } else {
                delay(50)
                modelsAfter
            }
        }

        testScheduler.advanceUntilIdle()

        // Act: Start multiple downloads concurrently
        viewModel.downloadModel("fr")
        testScheduler.advanceTimeBy(10) // Don't finish first download
        viewModel.downloadModel("de")
        testScheduler.advanceTimeBy(10)
        viewModel.downloadModel("es")
        testScheduler.advanceUntilIdle()

        // Assert: State should be consistent
        viewModel.uiState.test {
            val state = awaitItem()
            // downloadingLang should be null after all downloads complete
            assert(state.downloadingLang == null)
        }
    }

    @Test
    fun `loadModels() called during download does not cause race condition`() = runTest {
        // Arrange
        viewModel = ModelManagementViewModel(mockModelManager)
        val models = listOf(
            LanguageModelInfo("en", "English", true)
        )
        coEvery { mockModelManager.getAvailableModels() } coAnswers {
            delay(50)
            models
        }

        testScheduler.advanceUntilIdle()

        // Act: Start a download, then call loadModels() before it finishes
        viewModel.downloadModel("fr")
        testScheduler.advanceTimeBy(10) // Partial progress on download
        viewModel.loadModels()
        testScheduler.advanceUntilIdle()

        // Assert: Both operations should complete without race
        viewModel.uiState.test {
            val state = awaitItem()
            // Should have models from loadModels()
            assert(state.models == models)
            // Downloading should be complete
            assert(state.downloadingLang == null)
            // No loading or error states
            assert(!state.isLoading)
            assert(state.error == null)
        }
    }

    @Test
    fun `consecutive loadModels() calls do not cause state corruption`() = runTest {
        // Arrange
        viewModel = ModelManagementViewModel(mockModelManager)
        val models1 = listOf(
            LanguageModelInfo("en", "English", true)
        )
        val models2 = listOf(
            LanguageModelInfo("fr", "French", true)
        )
        var callCount = 0
        coEvery { mockModelManager.getAvailableModels() } coAnswers {
            delay(30)
            if (callCount++ % 2 == 0) models1 else models2
        }

        // Act: Trigger multiple loadModels() calls rapidly
        repeat(5) {
            viewModel.loadModels()
            testScheduler.advanceTimeBy(10)
        }
        testScheduler.advanceUntilIdle()

        // Assert: Final state should be consistent
        viewModel.uiState.test {
            val state = awaitItem()
            // Should have either models1 or models2, never corrupted state
            assert(state.models == models1 || state.models == models2)
            assert(!state.isLoading)
            assert(state.error == null)
        }
    }
}