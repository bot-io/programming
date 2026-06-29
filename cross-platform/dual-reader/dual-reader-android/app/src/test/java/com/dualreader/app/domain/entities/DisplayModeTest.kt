package com.dualreader.app.domain.entities

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class DisplayModeTest {

    @Test
    fun `DisplayMode has SPLIT and INTERLEAVED values`() {
        val values = DisplayMode.values()
        assertEquals(2, values.size)
        assertTrue(values.contains(DisplayMode.SPLIT))
        assertTrue(values.contains(DisplayMode.INTERLEAVED))
    }

    @Test
    fun `default display mode is SPLIT`() {
        val settings = ReadingSettings()
        assertEquals(DisplayMode.SPLIT, settings.displayMode)
    }

    @Test
    fun `ReadingSettings can be created with INTERLEAVED mode`() {
        val settings = ReadingSettings(displayMode = DisplayMode.INTERLEAVED)
        assertEquals(DisplayMode.INTERLEAVED, settings.displayMode)
    }

    @Test
    fun `ReadingSettings can switch display mode`() {
        val original = ReadingSettings(displayMode = DisplayMode.SPLIT)
        val updated = original.copy(displayMode = DisplayMode.INTERLEAVED)
        assertEquals(DisplayMode.INTERLEAVED, updated.displayMode)
    }

    @Test
    fun `ReadingSettings can switch back to SPLIT`() {
        val original = ReadingSettings(displayMode = DisplayMode.INTERLEAVED)
        val updated = original.copy(displayMode = DisplayMode.SPLIT)
        assertEquals(DisplayMode.SPLIT, updated.displayMode)
    }

    @Test
    fun `ReadingSettings display mode is independent of immersive mode`() {
        val settings = ReadingSettings(displayMode = DisplayMode.INTERLEAVED, isImmersiveMode = true)
        assertEquals(DisplayMode.INTERLEAVED, settings.displayMode)
        assertTrue(settings.isImmersiveMode)

        val settings2 = ReadingSettings(displayMode = DisplayMode.SPLIT, isImmersiveMode = false)
        assertEquals(DisplayMode.SPLIT, settings2.displayMode)
        assertFalse(settings2.isImmersiveMode)
    }

    @Test
    fun `DisplayMode valueOf works for both values`() {
        assertEquals(DisplayMode.SPLIT, DisplayMode.valueOf("SPLIT"))
        assertEquals(DisplayMode.INTERLEAVED, DisplayMode.valueOf("INTERLEAVED"))
    }

    @Test
    fun `ReadingSettings immersive mode toggles independently`() {
        var settings = ReadingSettings(isImmersiveMode = false)
        assertFalse(settings.isImmersiveMode)

        settings = settings.copy(isImmersiveMode = true)
        assertTrue(settings.isImmersiveMode)

        settings = settings.copy(isImmersiveMode = false)
        assertFalse(settings.isImmersiveMode)
    }
}
