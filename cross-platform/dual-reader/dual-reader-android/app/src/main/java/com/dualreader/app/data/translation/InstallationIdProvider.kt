package com.dualreader.app.data.translation

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import com.dualreader.app.util.AppLogger
import dagger.hilt.android.qualifiers.ApplicationContext
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

    @Volatile
    private var cachedId: String? = null

    /**
     * Get the installation ID, generating one if needed.
     * Caches the result in memory for fast repeated access.
     *
     * The read-or-generate logic runs inside a single [dataStore.edit] block,
     * which DataStore serializes — so concurrent first-access callers can
     * never both observe a missing key and generate different UUIDs.
     */
    suspend fun getInstallationId(): String {
        cachedId?.let { return it }

        // Atomically read-or-create within a single DataStore edit transaction.
        // DataStore serializes all edit calls, so concurrent callers can never
        // both observe a missing key and generate different UUIDs (DR-055).
        val result = dataStore.edit { prefs ->
            if (prefs[KEY_INSTALLATION_ID] == null) {
                prefs[KEY_INSTALLATION_ID] = UUID.randomUUID().toString()
                AppLogger.i("$TAG: Generated new installation ID")
            }
        }
        val id = result[KEY_INSTALLATION_ID]
            ?: throw IllegalStateException("Installation ID key missing from DataStore after edit transaction")
        cachedId = id
        AppLogger.i("$TAG: Installation ID: ${id.take(8)}...")
        return id
    }

    /**
     * Get cached ID synchronously (returns null if not yet loaded).
     * Useful for cases where coroutine context isn't available.
     */
    fun getInstallationIdSync(): String? = cachedId
}
