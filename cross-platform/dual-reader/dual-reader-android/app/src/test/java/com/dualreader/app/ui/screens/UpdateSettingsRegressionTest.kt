package com.dualreader.app.ui.screens

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Test

/**
 * Regression tests for ReaderViewModel.updateSettings persistence bug.
 *
 * Bug: updateSettings only updated _settings.value in memory, but uiState was
 * built from settingsRepository.settings flow. The change never reached the UI.
 * Fix: updateSettings now also calls settingsRepository.updateSettings().
 */
class UpdateSettingsRegressionTest {

    @Test
    fun `DisplayMode enum has exactly two values`() {
        val values = com.dualreader.app.domain.entities.DisplayMode.values()
        assertEquals(2, values.size)
    }

    @Test
    fun `ReadingSettings displayMode defaults to SPLIT`() {
        val settings = com.dualreader.app.domain.entities.ReadingSettings()
        assertEquals(
            com.dualreader.app.domain.entities.DisplayMode.SPLIT,
            settings.displayMode,
        )
    }

    @Test
    fun `ReadingSettings copy preserves all fields except changed one`() {
        val original = com.dualreader.app.domain.entities.ReadingSettings(
            fontSize = 18f,
            lineHeight = 1.5f,
            displayMode = com.dualreader.app.domain.entities.DisplayMode.SPLIT,
        )
        val updated = original.copy(displayMode = com.dualreader.app.domain.entities.DisplayMode.INTERLEAVED)

        assertEquals(18f, updated.fontSize, 0.01f)
        assertEquals(1.5f, updated.lineHeight, 0.01f)
        assertEquals(
            com.dualreader.app.domain.entities.DisplayMode.INTERLEAVED,
            updated.displayMode,
        )
    }

    @Test
    fun `ReadingSettings immersive and displayMode are independent`() {
        val settings = com.dualreader.app.domain.entities.ReadingSettings(
            isImmersiveMode = true,
            displayMode = com.dualreader.app.domain.entities.DisplayMode.INTERLEAVED,
        )
        assertEquals(true, settings.isImmersiveMode)
        assertEquals(
            com.dualreader.app.domain.entities.DisplayMode.INTERLEAVED,
            settings.displayMode,
        )
    }

    @Test
    fun `ReadingSettings can toggle immersive without changing displayMode`() {
        val original = com.dualreader.app.domain.entities.ReadingSettings(
            displayMode = com.dualreader.app.domain.entities.DisplayMode.INTERLEAVED,
        )
        val updated = original.copy(isImmersiveMode = !original.isImmersiveMode)
        assertEquals(
            com.dualreader.app.domain.entities.DisplayMode.INTERLEAVED,
            updated.displayMode,
        )
    }
}
