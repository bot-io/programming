package com.dualreader.app.data.translation

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import com.dualreader.app.util.AppLogger
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Provides a unique, persistent Installation ID for this app install.
 *
 * The ID is a UUID generated on first access and stored in the settings DataStore.
 * It survives app updates and is unique per device/install.
 * Used for per-device quota tracking on the Cloudflare Worker.
 */
@Singleton
class InstallationIdProvider @Inject constructor(
    @ApplicationContext private val context: Context,
    private val dataStore: DataStore<Preferences>,
) {
    companion object {
        private const val TAG = "InstallationId"
        private val KEY_INSTALLATION_ID = stringPreferencesKey("installation_id")
    }

    private var cachedId: String? = null

    /**
     * Get the installation ID, generating one if needed.
     * Caches the result in memory for fast repeated access.
     */
    suspend fun getInstallationId(): String {
        cachedId?.let { return it }

        // Try to read from DataStore
        val existing = dataStore.data.map { prefs ->
            prefs[KEY_INSTALLATION_ID]
        }.first()

        if (existing != null) {
            cachedId = existing
            AppLogger.i("$TAG: Loaded existing installation ID: ${existing.take(8)}...")
            return existing
        }

        // Generate new ID
        val newId = UUID.randomUUID().toString()
        dataStore.edit { prefs ->
            prefs[KEY_INSTALLATION_ID] = newId
        }
        cachedId = newId
        AppLogger.i("$TAG: Generated new installation ID: ${newId.take(8)}...")
        return newId
    }

    /**
     * Get cached ID synchronously (returns null if not yet loaded).
     * Useful for cases where coroutine context isn't available.
     */
    fun getInstallationIdSync(): String? = cachedId
}
