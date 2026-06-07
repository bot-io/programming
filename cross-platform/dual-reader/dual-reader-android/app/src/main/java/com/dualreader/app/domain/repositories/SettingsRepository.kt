package com.dualreader.app.domain.repositories

import com.dualreader.app.domain.entities.ReadingSettings
import kotlinx.coroutines.flow.Flow

interface SettingsRepository {
    val settings: Flow<ReadingSettings>
    suspend fun updateSettings(transform: (ReadingSettings) -> ReadingSettings)
    suspend fun getSettings(): ReadingSettings
}
