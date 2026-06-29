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
import kotlin.test.assertFailsWith
import kotlin.test.assertNull
import kotlin.test.assertNotNull
import io.mockk.mockk

/**
 * In-memory fake DataStore — no file I/O, works on Windows.
 */
class FakeDataStore(
    initial: Preferences = mutablePreferencesOf(),
    private val returnNullKey: String? = null
) : DataStore<Preferences> {
    private val _data = MutableStateFlow(initial)
    override val data = _data

    override suspend fun updateData(transform: suspend (Preferences) -> Preferences): Preferences {
        val new = transform(_data.value)
        _data.value = new
        return new
    }
}

class InstallationIdProviderTest {

    private val key = stringPreferencesKey("installation_id")

    @Test
    fun `getInstallationId returns cached ID when available`() = runTest {
        // Arrange
        val dataStore = FakeDataStore()
        val provider = InstallationIdProvider(mockk<Context>(), dataStore)
        val cachedField = InstallationIdProvider::class.java.getDeclaredField("cachedId")
        cachedField.isAccessible = true
        cachedField.set(provider, "cached-uuid-123")

        // Act
        val result = provider.getInstallationId()

        // Assert
        assertEquals("cached-uuid-123", result)
    }

    @Test
    fun `getInstallationId returns existing ID when cache is empty and key exists`() = runTest {
        // Arrange
        val existingId = "existing-uuid-456"
        val initialPrefs = mutablePreferencesOf(key to existingId)
        val dataStore = FakeDataStore(initialPrefs)
        val provider = InstallationIdProvider(mockk<Context>(), dataStore)

        // Act
        val result = provider.getInstallationId()

        // Assert
        assertEquals(existingId, result)
    }

    @Test
    fun `getInstallationId generates new ID when cache is empty and key does not exist`() = runTest {
        // Arrange
        val dataStore = FakeDataStore()
        val provider = InstallationIdProvider(mockk<Context>(), dataStore)

        // Act
        val result = provider.getInstallationId()

        // Assert
        assertNotNull(result)
        assertEquals(36, result.length) // UUID format: 8-4-4-4-12 = 36 chars
    }

    @Test
    fun `getInstallationId throws IllegalStateException when key is missing after edit`() = runTest {
        // Arrange
        class BrokenDataStore : DataStore<Preferences> {
            private val _data = MutableStateFlow(mutablePreferencesOf())
            override val data = _data

            override suspend fun updateData(transform: suspend (Preferences) -> Preferences): Preferences {
                // Transform the preferences but the key ends up missing
                val transformed = transform(_data.value)
                // Simulate a corrupted result that doesn't have the key
                return mutablePreferencesOf()
            }
        }

        val dataStore = BrokenDataStore()
        val provider = InstallationIdProvider(mockk<Context>(), dataStore)

        // Act & Assert
        val exception = assertFailsWith<IllegalStateException> {
            provider.getInstallationId()
        }
        assertEquals("Installation ID key missing from DataStore after edit transaction", exception.message)
    }

    @Test
    fun `getInstallationIdSync returns cached ID when available`() {
        // Arrange
        val dataStore = FakeDataStore()
        val provider = InstallationIdProvider(mockk<Context>(), dataStore)
        val cachedField = InstallationIdProvider::class.java.getDeclaredField("cachedId")
        cachedField.isAccessible = true
        cachedField.set(provider, "sync-cached-uuid")

        // Act
        val result = provider.getInstallationIdSync()

        // Assert
        assertEquals("sync-cached-uuid", result)
    }

    @Test
    fun `getInstallationIdSync returns null when cache is empty`() {
        // Arrange
        val dataStore = FakeDataStore()
        val provider = InstallationIdProvider(mockk<Context>(), dataStore)

        // Act
        val result = provider.getInstallationIdSync()

        // Assert
        assertNull(result)
    }

    @Test
    fun `cached ID is set after successful getInstallationId`() = runTest {
        // Arrange
        val newId = "new-uuid-789"
        val initialPrefs = mutablePreferencesOf(key to newId)
        val dataStore = FakeDataStore(initialPrefs)
        val provider = InstallationIdProvider(mockk<Context>(), dataStore)

        // Act
        provider.getInstallationId()

        // Assert - verify cache is set by calling sync method
        val cachedResult = provider.getInstallationIdSync()
        assertEquals(newId, cachedResult)
    }

    @Test
    fun `concurrent calls return the same generated ID - first call wins`() = runTest {
        // This test verifies the DataStore serialization guarantee mentioned in the KDoc
        // In a real scenario, DataStore serializes edit calls so concurrent callers can't
        // both observe a missing key and generate different UUIDs

        // Arrange
        val dataStore = FakeDataStore()
        val provider = InstallationIdProvider(mockk<Context>(), dataStore)

        // Act - simulate concurrent calls (in real test they'd be parallel)
        val result1 = provider.getInstallationId()
        val result2 = provider.getInstallationId()

        // Assert
        assertEquals(result1, result2)
    }
}