package com.dualreader.app.data.repository

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.*
import com.dualreader.app.domain.entities.DisplayMode
import com.dualreader.app.domain.entities.ReaderTheme
import com.dualreader.app.domain.entities.ReadingSettings
import com.dualreader.app.domain.entities.TranslationProvider
import com.dualreader.app.domain.repositories.SettingsRepository
import com.dualreader.app.util.AppLogger
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import java.io.IOException
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class SettingsRepositoryImpl @Inject constructor(
    private val dataStore: DataStore<Preferences>,
) : SettingsRepository {

    private object Keys {
        val FONT_SIZE = floatPreferencesKey("font_size")
        val FONT_FAMILY = stringPreferencesKey("font_family")
        val LINE_HEIGHT = floatPreferencesKey("line_height")
        val MARGINS = intPreferencesKey("margins")
        val THEME = stringPreferencesKey("theme")
        val TARGET_LANGUAGE = stringPreferencesKey("target_language")
        val TRANSLATION_PROVIDER = stringPreferencesKey("translation_provider")
        val BRIGHTNESS = floatPreferencesKey("brightness")
        val IMMERSIVE_MODE = booleanPreferencesKey("immersive_mode")
        val SCREEN_WAKE_TIMEOUT = intPreferencesKey("screen_wake_timeout")
        val SENTENCE_COUNTER = booleanPreferencesKey("sentence_counter")
        val DISPLAY_MODE = stringPreferencesKey("display_mode")
        val ONBOARDING_COMPLETED = booleanPreferencesKey("onboarding_completed")
    }

    override val settings: Flow<ReadingSettings> = dataStore.data
        .catch { if (it is IOException) emit(emptyPreferences()) else throw it }
        .map { prefs -> prefs.toReadingSettings() }

    override suspend fun updateSettings(transform: (ReadingSettings) -> ReadingSettings) {
        dataStore.edit { prefs ->
            val current = prefs.toReadingSettings()
            val updated = transform(current)
            prefs[Keys.FONT_SIZE] = updated.fontSize
            prefs[Keys.FONT_FAMILY] = updated.fontFamily
            prefs[Keys.LINE_HEIGHT] = updated.lineHeight
            prefs[Keys.MARGINS] = updated.margins
            prefs[Keys.THEME] = updated.theme.name
            prefs[Keys.TARGET_LANGUAGE] = updated.targetLanguage
            prefs[Keys.TRANSLATION_PROVIDER] = updated.translationProvider.name
            prefs[Keys.BRIGHTNESS] = updated.brightness
            prefs[Keys.IMMERSIVE_MODE] = updated.isImmersiveMode
            prefs[Keys.SCREEN_WAKE_TIMEOUT] = updated.screenWakeTimeoutMinutes
            prefs[Keys.SENTENCE_COUNTER] = updated.sentenceCounterEnabled
            prefs[Keys.DISPLAY_MODE] = updated.displayMode.name
        }
    }

    override suspend fun getSettings(): ReadingSettings =
        settings.first()

    // ── Onboarding ──────────────────────────────────────────────────
    override val isOnboardingCompleted: Flow<Boolean> = dataStore.data
        .catch { if (it is IOException) emit(emptyPreferences()) else throw it }
        .map { it[Keys.ONBOARDING_COMPLETED] ?: false }

    override suspend fun setOnboardingCompleted() {
        dataStore.edit { it[Keys.ONBOARDING_COMPLETED] = true }
    }

    // ── Target Language ─────────────────────────────────────────────
    override val targetLanguage: Flow<String> = dataStore.data
        .catch { if (it is IOException) emit(emptyPreferences()) else throw it }
        .map { it[Keys.TARGET_LANGUAGE] ?: "es" }

    override suspend fun setTargetLanguage(lang: String) {
        dataStore.edit { it[Keys.TARGET_LANGUAGE] = lang }
    }

    /** Single source of truth for Preferences → ReadingSettings mapping. */
    private fun Preferences.toReadingSettings(): ReadingSettings = ReadingSettings(
        fontSize = this[Keys.FONT_SIZE] ?: 16f,
        fontFamily = this[Keys.FONT_FAMILY] ?: "Default",
        lineHeight = this[Keys.LINE_HEIGHT] ?: 1.5f,
        margins = this[Keys.MARGINS] ?: 16,
        theme = try {
            ReaderTheme.valueOf(this[Keys.THEME] ?: "DARK")
        } catch (e: Exception) {
            val themeValue = this[Keys.THEME]
            AppLogger.w("Failed to parse theme: '$themeValue', using DARK. Error: ${e.message}")
            ReaderTheme.DARK
        },
        targetLanguage = this[Keys.TARGET_LANGUAGE] ?: "es",
        translationProvider = try {
            val name = this[Keys.TRANSLATION_PROVIDER] ?: "GEMINI_FLASH"
            // Map removed enum values to closest equivalent
            when (name) {
                "LLM_QUALITY" -> TranslationProvider.GEMINI_FLASH
                "LLM_FREE" -> TranslationProvider.LLM_FREE
                else -> TranslationProvider.valueOf(name)
            }
        } catch (e: Exception) {
            val providerValue = this[Keys.TRANSLATION_PROVIDER]
            AppLogger.w("Failed to parse translationProvider: '$providerValue', using GEMINI_FLASH. Error: ${e.message}")
            TranslationProvider.GEMINI_FLASH
        },
        brightness = this[Keys.BRIGHTNESS] ?: -1f,
        isImmersiveMode = this[Keys.IMMERSIVE_MODE] ?: false,
        screenWakeTimeoutMinutes = this[Keys.SCREEN_WAKE_TIMEOUT] ?: 30,
        sentenceCounterEnabled = this[Keys.SENTENCE_COUNTER] ?: false,
        displayMode = try {
            DisplayMode.valueOf(this[Keys.DISPLAY_MODE] ?: "SPLIT")
        } catch (e: Exception) {
            val displayModeValue = this[Keys.DISPLAY_MODE]
            AppLogger.w("Failed to parse displayMode: '$displayModeValue', using SPLIT. Error: ${e.message}")
            DisplayMode.SPLIT
        },
    )
}
