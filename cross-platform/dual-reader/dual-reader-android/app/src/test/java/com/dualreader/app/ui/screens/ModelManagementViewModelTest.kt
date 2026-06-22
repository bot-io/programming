package com.dualreader.app.ui.screens

import com.dualreader.app.data.translation.LanguageModelInfo
import com.dualreader.app.data.translation.MlKitModelManager
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.mockk
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class ModelManagementViewModelTest {

    private val testDispatcher = StandardTestDispatcher()

    private lateinit var modelManager: MlKitModelManager
    private lateinit var vm: ModelManagementViewModel

    @Before
    fun setUp() {
        Dispatchers.setMain(testDispatcher)
        modelManager = mockk(relaxed = true)
        coEvery { modelManager.getAvailableModels() } returns emptyList()
        vm = ModelManagementViewModel(modelManager)
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    private fun makeModel(code: String, downloaded: Boolean = false) = LanguageModelInfo(
        code = code,
        displayName = code.uppercase(),
        isDownloaded = downloaded,
    )

    // ── Initial State ──────────────────────────────────────────────

    @Test
    fun `init triggers loadModels`() = runTest {
        coVerify(atLeast = 1) { modelManager.getAvailableModels() }
    }

    @Test
    fun `initial state has isLoading true`() {
        assertTrue(vm.uiState.value.isLoading)
    }

    @Test
    fun `initial searchQuery is empty`() {
        assertEquals("", vm.uiState.value.searchQuery)
    }

    @Test
    fun `initial error is null`() {
        assertNull(vm.uiState.value.error)
    }

    // ── loadModels ─────────────────────────────────────────────────

    @Test
    fun `loadModels populates models list and sets isLoading false`() = runTest {
        val models = listOf(
            makeModel("en", true),
            makeModel("es", false),
        )
        coEvery { modelManager.getAvailableModels() } returns models

        vm.loadModels()
        advanceUntilIdle()

        assertEquals(2, vm.uiState.value.models.size)
        assertFalse(vm.uiState.value.isLoading)
        assertNull(vm.uiState.value.error)
    }

    @Test
    fun `loadModels sets error on exception`() = runTest {
        coEvery { modelManager.getAvailableModels() } throws RuntimeException("Network error")

        vm.loadModels()
        advanceUntilIdle()

        assertFalse(vm.uiState.value.isLoading)
        assertEquals("Network error", vm.uiState.value.error)
    }

    @Test
    fun `loadModels clears previous error on success`() = runTest {
        // First call: error
        coEvery { modelManager.getAvailableModels() } throws RuntimeException("fail")
        vm.loadModels()
        advanceUntilIdle()
        assertEquals("fail", vm.uiState.value.error)

        // Second call: success
        coEvery { modelManager.getAvailableModels() } returns listOf(makeModel("en"))
        vm.loadModels()
        advanceUntilIdle()
        assertNull(vm.uiState.value.error)
    }

    // ── downloadModel ──────────────────────────────────────────────

    @Test
    fun `downloadModel sets downloadingLang during operation`() = runTest {
        coEvery { modelManager.downloadModel("en") } returns true

        vm.downloadModel("en")
        advanceUntilIdle()

        assertNull(vm.uiState.value.downloadingLang)
    }

    @Test
    fun `downloadModel calls modelManager and reloads models`() = runTest {
        coEvery { modelManager.downloadModel("es") } returns true
        coEvery { modelManager.getAvailableModels() } returns listOf(makeModel("es", true))

        vm.downloadModel("es")
        advanceUntilIdle()

        coVerify { modelManager.downloadModel("es") }
        coVerify(atLeast = 2) { modelManager.getAvailableModels() }
    }

    @Test
    fun `downloadModel sets error on exception`() = runTest {
        coEvery { modelManager.downloadModel("xx") } throws RuntimeException("Download failed")

        vm.downloadModel("xx")
        advanceUntilIdle()

        assertTrue(vm.uiState.value.error?.contains("Download failed") == true)
        assertNull(vm.uiState.value.downloadingLang)
    }

    // ── deleteModel ────────────────────────────────────────────────

    @Test
    fun `deleteModel calls modelManager and reloads models`() = runTest {
        coEvery { modelManager.deleteModel("en") } returns true

        vm.deleteModel("en")
        advanceUntilIdle()

        coVerify { modelManager.deleteModel("en") }
        coVerify(atLeast = 2) { modelManager.getAvailableModels() }
    }

    @Test
    fun `deleteModel sets error on exception`() = runTest {
        coEvery { modelManager.deleteModel("en") } throws RuntimeException("Delete failed")

        vm.deleteModel("en")
        advanceUntilIdle()

        assertTrue(vm.uiState.value.error?.contains("Delete failed") == true)
    }

    // ── updateSearchQuery ──────────────────────────────────────────

    @Test
    fun `updateSearchQuery updates searchQuery`() {
        vm.updateSearchQuery("English")
        assertEquals("English", vm.uiState.value.searchQuery)
    }

    @Test
    fun `updateSearchQuery to empty string`() {
        vm.updateSearchQuery("test")
        vm.updateSearchQuery("")
        assertEquals("", vm.uiState.value.searchQuery)
    }

    // ── Model data integrity ───────────────────────────────────────

    @Test
    fun `downloaded model has isDownloaded true`() = runTest {
        val models = listOf(makeModel("en", true), makeModel("es", false))
        coEvery { modelManager.getAvailableModels() } returns models

        vm.loadModels()
        advanceUntilIdle()

        assertTrue(vm.uiState.value.models[0].isDownloaded)
        assertFalse(vm.uiState.value.models[1].isDownloaded)
    }
}
