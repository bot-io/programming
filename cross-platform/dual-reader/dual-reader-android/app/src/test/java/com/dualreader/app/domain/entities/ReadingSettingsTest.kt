package com.dualreader.app.domain.entities

import org.junit.Assert.*
import org.junit.Test

class ReadingSettingsTest {

    @Test
    fun `default screenWakeTimeoutMinutes is 30`() {
        val settings = ReadingSettings()
        assertEquals(30, settings.screenWakeTimeoutMinutes)
    }

    @Test
    fun `default sentenceCounterEnabled is false`() {
        val settings = ReadingSettings()
        assertFalse(settings.sentenceCounterEnabled)
    }

    @Test
    fun `screenWakeTimeoutMinutes can be set to 0 (disabled)`() {
        val settings = ReadingSettings(screenWakeTimeoutMinutes = 0)
        assertEquals(0, settings.screenWakeTimeoutMinutes)
    }

    @Test
    fun `screenWakeTimeoutMinutes can be set to 60`() {
        val settings = ReadingSettings(screenWakeTimeoutMinutes = 60)
        assertEquals(60, settings.screenWakeTimeoutMinutes)
    }

    @Test
    fun `sentenceCounterEnabled can be toggled`() {
        val on = ReadingSettings(sentenceCounterEnabled = true)
        assertTrue(on.sentenceCounterEnabled)
        val off = on.copy(sentenceCounterEnabled = false)
        assertFalse(off.sentenceCounterEnabled)
    }

    @Test
    fun `copy preserves all fields when changing one`() {
        val original = ReadingSettings(
            fontSize = 20f,
            lineHeight = 1.8f,
            targetLanguage = "de",
            screenWakeTimeoutMinutes = 15,
            sentenceCounterEnabled = true,
        )
        val updated = original.copy(screenWakeTimeoutMinutes = 60)
        assertEquals(20f, updated.fontSize, 0.01f)
        assertEquals(1.8f, updated.lineHeight, 0.01f)
        assertEquals("de", updated.targetLanguage)
        assertEquals(60, updated.screenWakeTimeoutMinutes)
        assertTrue(updated.sentenceCounterEnabled)
    }

    @Test
    fun `all ReaderTheme values are parseable`() {
        for (theme in ReaderTheme.entries) {
            val parsed = ReaderTheme.valueOf(theme.name)
            assertEquals(theme, parsed)
        }
    }

    @Test
    fun `all TranslationProvider values are parseable`() {
        for (provider in TranslationProvider.entries) {
            val parsed = TranslationProvider.valueOf(provider.name)
            assertEquals(provider, parsed)
        }
    }
}
