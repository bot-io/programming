package com.dualreader.app.domain.repositories

import com.dualreader.app.domain.entities.ReadingSettings
import kotlinx.coroutines.flow.Flow

interface SettingsRepository {
    val settings: Flow<ReadingSettings>
    suspend fun updateSettings(transform: (ReadingSettings) -> ReadingSettings)
    suspend fun getSettings(): ReadingSettings

    /** Whether the user has completed the onboarding flow. */
    val isOnboardingCompleted: Flow<Boolean>
    suspend fun setOnboardingCompleted()

    /** Target language (shortcut for reading). */
    val targetLanguage: Flow<String>
    suspend fun setTargetLanguage(lang: String)
}
