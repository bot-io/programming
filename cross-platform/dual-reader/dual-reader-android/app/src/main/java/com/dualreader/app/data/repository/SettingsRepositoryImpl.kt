package com.dualreader.app.data.repository

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.*
import com.dualreader.app.domain.entities.ReaderTheme
import com.dualreader.app.domain.entities.ReadingSettings
import com.dualreader.app.domain.entities.TranslationProvider
import com.dualreader.app.domain.repositories.SettingsRepository
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
    }

    override val settings: Flow<ReadingSettings> = dataStore.data
        .catch { if (it is IOException) emit(emptyPreferences()) else throw it }
        .map { prefs ->
            ReadingSettings(
                fontSize = prefs[Keys.FONT_SIZE] ?: 16f,
                fontFamily = prefs[Keys.FONT_FAMILY] ?: "Default",
                lineHeight = prefs[Keys.LINE_HEIGHT] ?: 1.5f,
                margins = prefs[Keys.MARGINS] ?: 16,
                theme = try { ReaderTheme.valueOf(prefs[Keys.THEME] ?: "DARK") } catch (_: Exception) { ReaderTheme.DARK },
                targetLanguage = prefs[Keys.TARGET_LANGUAGE] ?: "es",
                translationProvider = try { TranslationProvider.valueOf(prefs[Keys.TRANSLATION_PROVIDER] ?: "LLM_FREE") } catch (_: Exception) { TranslationProvider.LLM_FREE },
                brightness = prefs[Keys.BRIGHTNESS] ?: -1f,
                isImmersiveMode = prefs[Keys.IMMERSIVE_MODE] ?: false,
            )
        }

    override suspend fun updateSettings(transform: (ReadingSettings) -> ReadingSettings) {
        dataStore.edit { prefs ->
            val current = ReadingSettings(
                fontSize = prefs[Keys.FONT_SIZE] ?: 16f,
                fontFamily = prefs[Keys.FONT_FAMILY] ?: "Default",
                lineHeight = prefs[Keys.LINE_HEIGHT] ?: 1.5f,
                margins = prefs[Keys.MARGINS] ?: 16,
                theme = try { ReaderTheme.valueOf(prefs[Keys.THEME] ?: "DARK") } catch (_: Exception) { ReaderTheme.DARK },
                targetLanguage = prefs[Keys.TARGET_LANGUAGE] ?: "es",
                translationProvider = try { TranslationProvider.valueOf(prefs[Keys.TRANSLATION_PROVIDER] ?: "LLM_FREE") } catch (_: Exception) { TranslationProvider.LLM_FREE },
                brightness = prefs[Keys.BRIGHTNESS] ?: -1f,
                isImmersiveMode = prefs[Keys.IMMERSIVE_MODE] ?: false,
            )
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
        }
    }

    override suspend fun getSettings(): ReadingSettings =
        settings.first()
}
