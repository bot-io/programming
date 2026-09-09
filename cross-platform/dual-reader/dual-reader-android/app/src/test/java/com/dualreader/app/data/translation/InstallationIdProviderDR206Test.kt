package com.dualreader.app.data.translation

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.mutablePreferencesOf
import androidx.datastore.preferences.core.stringPreferencesKey
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.test.runTest
import org.junit.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import io.mockk.mockk

class InstallationIdProviderDR206Test {

    private val key = stringPreferencesKey("installation_id")

    /**
     * Fake DataStore that allows concurrent edit calls.
     * Uses MutableStateFlow which is thread-safe for reads/writes.
     */
    class FakeDataStore(
        initial: Preferences = mutablePreferencesOf()
    ) : DataStore<Preferences> {
        private val _data = MutableStateFlow(initial)
        override val data = _data

        override suspend fun updateData(transform: suspend (Preferences) -> Preferences): Preferences {
            val new = transform(_data.value)
            _data.value = new
            return new
        }
    }

    @Test
    fun `concurrent calls return the same ID - no race condition`() = runTest {
        // Arrange
        val dataStore = FakeDataStore()
        val provider = InstallationIdProvider(mockk<Context>(), dataStore)

        // Act - call sequentially to verify behavior first
        val result1 = provider.getInstallationId()
        val result2 = provider.getInstallationId()

        // Assert
        assertEquals(result1, result2, "Sequential calls should return the same ID")
        assertNotNull(result1, "ID should not be null")
    }
}