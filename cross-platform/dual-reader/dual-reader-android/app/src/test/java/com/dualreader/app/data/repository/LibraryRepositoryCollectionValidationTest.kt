package com.dualreader.app.data.repository

import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.mockk
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test

/**
 * Regression tests for collection name validation (DR-107).
 * Ensures empty or whitespace-only collection names are silently rejected.
 */
class LibraryRepositoryCollectionValidationTest {

    private lateinit var repository: LibraryRepositoryImpl
    private val mockBookDao = mockk<com.dualreader.app.data.local.dao.BookDao>(relaxed = true)
    private val mockBookTagDao = mockk<com.dualreader.app.data.local.dao.BookTagDao>(relaxed = true)
    private val mockCollectionDao = mockk<com.dualreader.app.data.local.dao.CollectionDao>(relaxed = true)

    @Before
    fun setup() {
        repository = LibraryRepositoryImpl(
            mockBookDao,
            mockBookTagDao,
            mockCollectionDao
        )
    }

    @Test
    fun `createCollection rejects empty string`() = runTest {
        val result = repository.createCollection("")
        // Should return -1L to indicate rejection
        assertEquals(-1L, result)
        // Should not call insert
        coVerify(exactly = 0) { mockCollectionDao.insert(any()) }
    }

    @Test
    fun `createCollection rejects whitespace-only string`() = runTest {
        val result = repository.createCollection("   \t\n")
        // Should return -1L to indicate rejection
        assertEquals(-1L, result)
        // Should not call insert
        coVerify(exactly = 0) { mockCollectionDao.insert(any()) }
    }

    @Test
    fun `createCollection accepts valid name`() = runTest {
        val expectedId = 123L
        coEvery { mockCollectionDao.insert(any()) } returns expectedId

        val result = repository.createCollection("My Collection")
        // Should return the collection ID
        assertEquals(expectedId, result)
        // Should call insert with trimmed name
        coVerify(exactly = 1) { mockCollectionDao.insert(match { it.name == "My Collection" }) }
    }

    @Test
    fun `createCollection trims whitespace from valid name`() = runTest {
        val expectedId = 123L
        coEvery { mockCollectionDao.insert(any()) } returns expectedId

        val result = repository.createCollection("  My Collection  ")
        // Should return the collection ID
        assertEquals(expectedId, result)
        // Should call insert with trimmed name
        coVerify(exactly = 1) { mockCollectionDao.insert(match { it.name == "My Collection" }) }
    }

    @Test
    fun `renameCollection rejects empty string`() = runTest {
        val existingEntity = com.dualreader.app.data.local.entity.CollectionEntity(id = 1, name = "Old Name", createdAt = 0)
        coEvery { mockCollectionDao.getById(1) } returns existingEntity

        repository.renameCollection(1, "")
        // Should not call update
        coVerify(exactly = 0) { mockCollectionDao.update(any()) }
    }

    @Test
    fun `renameCollection rejects whitespace-only string`() = runTest {
        val existingEntity = com.dualreader.app.data.local.entity.CollectionEntity(id = 1, name = "Old Name", createdAt = 0)
        coEvery { mockCollectionDao.getById(1) } returns existingEntity

        repository.renameCollection(1, "   \t\n")
        // Should not call update
        coVerify(exactly = 0) { mockCollectionDao.update(any()) }
    }

    @Test
    fun `renameCollection accepts valid name`() = runTest {
        val existingEntity = com.dualreader.app.data.local.entity.CollectionEntity(id = 1, name = "Old Name", createdAt = 0)
        coEvery { mockCollectionDao.getById(1) } returns existingEntity

        repository.renameCollection(1, "New Name")
        // Should call update with trimmed name
        coVerify(exactly = 1) {
            mockCollectionDao.update(match { it.name == "New Name" })
        }
    }

    @Test
    fun `renameCollection trims whitespace from valid name`() = runTest {
        val existingEntity = com.dualreader.app.data.local.entity.CollectionEntity(id = 1, name = "Old Name", createdAt = 0)
        coEvery { mockCollectionDao.getById(1) } returns existingEntity

        repository.renameCollection(1, "  New Name  ")
        // Should call update with trimmed name
        coVerify(exactly = 1) {
            mockCollectionDao.update(match { it.name == "New Name" })
        }
    }

    @Test
    fun `renameCollection does nothing for non-existent collection`() = runTest {
        coEvery { mockCollectionDao.getById(999) } returns null

        repository.renameCollection(999, "New Name")
        // Should not call update
        coVerify(exactly = 0) { mockCollectionDao.update(any()) }
    }
}