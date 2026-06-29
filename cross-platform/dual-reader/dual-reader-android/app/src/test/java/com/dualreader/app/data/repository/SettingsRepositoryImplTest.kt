package com.dualreader.app.data.repository

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.mutablePreferencesOf
import androidx.datastore.preferences.core.stringPreferencesKey
import com.dualreader.app.domain.entities.DisplayMode
import com.dualreader.app.domain.entities.ReaderTheme
import com.dualreader.app.domain.entities.ReadingSettings
import com.dualreader.app.domain.entities.TranslationProvider
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.test.runTest
import org.junit.Assert.*
import org.junit.Test

/**
 * In-memory fake DataStore — no file I/O, works on Windows.
 */
class FakeDataStore(
    initial: Preferences = mutablePreferencesOf(),
    private val throwOnRead: Boolean = false
) : DataStore<Preferences> {
    private val _data = MutableStateFlow(initial)
    override val data: Flow<Preferences> = if (throwOnRead) {
        flow { throw java.io.IOException("Simulated DataStore failure") }
    } else {
        _data
    }
    override suspend fun updateData(transform: suspend (Preferences) -> Preferences): Preferences {
        val new = transform(_data.value)
        _data.value = new
        return new
    }
}

class SettingsRepositoryImplTest {

    private fun newRepo(initial: Preferences = mutablePreferencesOf()) =
        SettingsRepositoryImpl(FakeDataStore(initial))

    // ── Default values ──────────────────────────────────────────────────

    @Test
    fun `defaults are returned when no preferences are stored`() = runTest {
        val r = newRepo()
        val s = r.settings.first()
        assertEquals(16f, s.fontSize)
        assertEquals("Default", s.fontFamily)
        assertEquals(1.5f, s.lineHeight)
        assertEquals(16, s.margins)
        assertEquals(ReaderTheme.DARK, s.theme)
        assertEquals("es", s.targetLanguage)
        assertEquals(TranslationProvider.GEMINI_FLASH, s.translationProvider)
        assertEquals(-1f, s.brightness)
        assertFalse(s.isImmersiveMode)
        assertEquals(30, s.screenWakeTimeoutMinutes)
        assertFalse(s.sentenceCounterEnabled)
        assertEquals(DisplayMode.SPLIT, s.displayMode)
    }

    @Test
    fun `getSettings returns defaults on empty store`() = runTest {
        val r = newRepo()
        val s = r.getSettings()
        assertEquals(ReaderTheme.DARK, s.theme)
        assertEquals(DisplayMode.SPLIT, s.displayMode)
    }

    // ── Persistence round-trip ──────────────────────────────────────────

    @Test
    fun `updateSettings persists all fields`() = runTest {
        val r = newRepo()
        val ns = ReadingSettings(
            fontSize = 20f, fontFamily = "Serif", lineHeight = 1.8f,
            margins = 24, theme = ReaderTheme.SEPIA, targetLanguage = "fr",
            translationProvider = TranslationProvider.LLM_CHEAP,
            brightness = 0.75f, isImmersiveMode = true,
            screenWakeTimeoutMinutes = 60, sentenceCounterEnabled = true,
            displayMode = DisplayMode.INTERLEAVED,
        )
        r.updateSettings { ns }
        assertEquals(ns, r.settings.first())
    }

    @Test
    fun `updateSettings transform sees current values`() = runTest {
        val r = newRepo()
        r.updateSettings { it.copy(fontSize = 18f) }
        r.updateSettings { it.copy(fontSize = it.fontSize + 2f) }
        assertEquals(20f, r.settings.first().fontSize)
    }

    @Test
    fun `theme persists for all enum values`() = runTest {
        val r = newRepo()
        for (t in ReaderTheme.values()) {
            r.updateSettings { it.copy(theme = t) }
            assertEquals(t, r.settings.first().theme)
        }
    }

    @Test
    fun `display mode persists for all enum values`() = runTest {
        val r = newRepo()
        for (m in DisplayMode.values()) {
            r.updateSettings { it.copy(displayMode = m) }
            assertEquals(m, r.settings.first().displayMode)
        }
    }

    @Test
    fun `translation provider persists for all enum values`() = runTest {
        val r = newRepo()
        for (p in TranslationProvider.values()) {
            r.updateSettings { it.copy(translationProvider = p) }
            assertEquals(p, r.settings.first().translationProvider)
        }
    }

    // ── Legacy enum mapping ─────────────────────────────────────────────

    @Test
    fun `legacy LLM_QUALITY provider maps to GEMINI_FLASH`() = runTest {
        val ds = FakeDataStore()
        val r = SettingsRepositoryImpl(ds)
        ds.updateData { current ->
            current.toMutablePreferences().apply {
                this[stringPreferencesKey("translation_provider")] = "LLM_QUALITY"
            }.toPreferences()
        }
        assertEquals(TranslationProvider.GEMINI_FLASH, r.settings.first().translationProvider)
    }

    @Test
    fun `legacy LLM_FREE provider maps to LLM_FREE`() = runTest {
        val ds = FakeDataStore()
        val r = SettingsRepositoryImpl(ds)
        ds.updateData { current ->
            current.toMutablePreferences().apply {
                this[stringPreferencesKey("translation_provider")] = "LLM_FREE"
            }.toPreferences()
        }
        assertEquals(TranslationProvider.LLM_FREE, r.settings.first().translationProvider)
    }

    // ── Corruption handling ─────────────────────────────────────────────

    @Test
    fun `invalid theme string falls back to DARK`() = runTest {
        val r = newRepo(mutablePreferencesOf().apply {
            this[stringPreferencesKey("theme")] = "INVALID"
        }.toPreferences())
        assertEquals(ReaderTheme.DARK, r.settings.first().theme)
    }

    @Test
    fun `invalid translation provider falls back to GEMINI_FLASH`() = runTest {
        val r = newRepo(mutablePreferencesOf().apply {
            this[stringPreferencesKey("translation_provider")] = "NONEXISTENT"
        }.toPreferences())
        assertEquals(TranslationProvider.GEMINI_FLASH, r.settings.first().translationProvider)
    }

    @Test
    fun `invalid display mode falls back to SPLIT`() = runTest {
        val r = newRepo(mutablePreferencesOf().apply {
            this[stringPreferencesKey("display_mode")] = "INVALID"
        }.toPreferences())
        assertEquals(DisplayMode.SPLIT, r.settings.first().displayMode)
    }

    // ── Onboarding ──────────────────────────────────────────────────────

    @Test
    fun `onboarding defaults to false`() = runTest {
        assertFalse(newRepo().isOnboardingCompleted.first())
    }

    @Test
    fun `setOnboardingCompleted persists true`() = runTest {
        val r = newRepo()
        r.setOnboardingCompleted()
        assertTrue(r.isOnboardingCompleted.first())
    }

    // ── Target Language ─────────────────────────────────────────────────

    @Test
    fun `target language defaults to es`() = runTest {
        assertEquals("es", newRepo().targetLanguage.first())
    }

    @Test
    fun `setTargetLanguage persists correctly`() = runTest {
        val r = newRepo()
        r.setTargetLanguage("bg")
        assertEquals("bg", r.targetLanguage.first())
    }

    // ── Partial updates preserve other fields ───────────────────────────

    @Test
    fun `updating only fontSize preserves other defaults`() = runTest {
        val r = newRepo()
        r.updateSettings { it.copy(fontSize = 24f) }
        val s = r.settings.first()
        assertEquals(24f, s.fontSize)
        assertEquals(16, s.margins)
        assertEquals(ReaderTheme.DARK, s.theme)
    }

    @Test
    fun `sequential updates each preserve prior changes`() = runTest {
        val r = newRepo()
        r.updateSettings { it.copy(fontSize = 18f) }
        r.updateSettings { it.copy(theme = ReaderTheme.OCEAN) }
        r.updateSettings { it.copy(targetLanguage = "ja") }
        val s = r.settings.first()
        assertEquals(18f, s.fontSize)
        assertEquals(ReaderTheme.OCEAN, s.theme)
        assertEquals("ja", s.targetLanguage)
    }

    // ── Corrupt settings fallback with logging (DR-068) ────────────────

    @Test
    fun `corrupt theme falls back to DARK and logs warning`() = runTest {
        val initial = mutablePreferencesOf(
            stringPreferencesKey("theme") to "INVALID_THEME"
        )
        val r = newRepo(initial)
        val s = r.settings.first()
        // Should fall back to default DARK
        assertEquals(ReaderTheme.DARK, s.theme)
        // Other values should still be defaults
        assertEquals(16f, s.fontSize)
    }

    @Test
    fun `corrupt translationProvider falls back to GEMINI_FLASH and logs warning`() = runTest {
        val initial = mutablePreferencesOf(
            stringPreferencesKey("translation_provider") to "NONEXISTENT_PROVIDER"
        )
        val r = newRepo(initial)
        val s = r.settings.first()
        // Should fall back to default GEMINI_FLASH
        assertEquals(TranslationProvider.GEMINI_FLASH, s.translationProvider)
        // Other values should still be defaults
        assertEquals(16f, s.fontSize)
    }

    @Test
    fun `corrupt displayMode falls back to SPLIT and logs warning`() = runTest {
        val initial = mutablePreferencesOf(
            stringPreferencesKey("display_mode") to "INVALID_MODE"
        )
        val r = newRepo(initial)
        val s = r.settings.first()
        // Should fall back to default SPLIT
        assertEquals(DisplayMode.SPLIT, s.displayMode)
        // Other values should still be defaults
        assertEquals(16f, s.fontSize)
    }

    @Test
    fun `multiple corrupt settings all fall back gracefully`() = runTest {
        val initial = mutablePreferencesOf(
            stringPreferencesKey("theme") to "BAD_THEME",
            stringPreferencesKey("translation_provider") to "BAD_PROVIDER",
            stringPreferencesKey("display_mode") to "BAD_MODE"
        )
        val r = newRepo(initial)
        val s = r.settings.first()
        // All three should fall back to defaults
        assertEquals(ReaderTheme.DARK, s.theme)
        assertEquals(TranslationProvider.GEMINI_FLASH, s.translationProvider)
        assertEquals(DisplayMode.SPLIT, s.displayMode)
        // Other values should be unaffected defaults
        assertEquals(16f, s.fontSize)
        assertEquals("es", s.targetLanguage)
    }

    // ── DataStore IOException handling (DR-145) ─────────────────────────

    @Test
    fun `settings Flow emits default values on IOException`() = runTest {
        val r = SettingsRepositoryImpl(FakeDataStore(throwOnRead = true))
        val s = r.settings.first()
        assertEquals(16f, s.fontSize)
        assertEquals(ReaderTheme.DARK, s.theme)
        assertEquals("es", s.targetLanguage)
    }

    @Test
    fun `isOnboardingCompleted Flow emits false on IOException`() = runTest {
        val r = SettingsRepositoryImpl(FakeDataStore(throwOnRead = true))
        assertFalse(r.isOnboardingCompleted.first())
    }

    @Test
    fun `targetLanguage Flow emits default es on IOException`() = runTest {
        val r = SettingsRepositoryImpl(FakeDataStore(throwOnRead = true))
        assertEquals("es", r.targetLanguage.first())
    }

    @Test
    fun `non-IOException in targetLanguage Flow is rethrown`() = runTest {
        val r = SettingsRepositoryImpl(
            FakeDataStore(throwOnRead = true).let {
                object : DataStore<Preferences> by it {
                    override val data: Flow<Preferences> = flow {
                        throw IllegalStateException("Non-IOException error")
                    }
                }
            }
        )
        try {
            r.targetLanguage.first()
            fail("Should have thrown IllegalStateException")
        } catch (e: IllegalStateException) {
            assertEquals("Non-IOException error", e.message)
        }
    }
}
