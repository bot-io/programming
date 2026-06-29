package com.dualreader.app.data.repository

import io.mockk.coVerify
import io.mockk.mockk
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test

/**
 * Regression tests for DR-100: Empty tag validation.
 *
 * Ensures that addTag() rejects empty or whitespace-only tags
 * to prevent database pollution with empty string tags.
 */
class LibraryRepositoryTagValidationTest {

    private lateinit var bookTagDao: com.dualreader.app.data.local.dao.BookTagDao
    private lateinit var repository: LibraryRepositoryImpl

    @Before
    fun setUp() {
        bookTagDao = mockk(relaxed = true)
        val bookDao: com.dualreader.app.data.local.dao.BookDao = mockk(relaxed = true)
        val collectionDao: com.dualreader.app.data.local.dao.CollectionDao = mockk(relaxed = true)
        repository = LibraryRepositoryImpl(bookDao, bookTagDao, collectionDao)
    }

    @Test
    fun addTag_withValidTag_insertsIntoDAO() = runTest {
        repository.addTag("book1", "fiction")
        coVerify { bookTagDao.insert(any()) }
    }

    @Test
    fun addTag_withWhitespaceOnlyTag_doesNOTInsertIntoDAO() = runTest {
        repository.addTag("book1", "   ")
        coVerify(exactly = 0) { bookTagDao.insert(any()) }
    }

    @Test
    fun addTag_withEmptyString_doesNOTInsertIntoDAO() = runTest {
        repository.addTag("book1", "")
        coVerify(exactly = 0) { bookTagDao.insert(any()) }
    }

    @Test
    fun addTag_withTagContainingLeadingTrailingWhitespace_trimsAndInserts() = runTest {
        repository.addTag("book1", "  favorite  ")
        coVerify {
            bookTagDao.insert(
                com.dualreader.app.data.local.entity.BookTagEntity(
                    bookId = "book1",
                    tag = "favorite"
                )
            )
        }
    }

    @Test
    fun addTag_withTabOnlyWhitespace_doesNOTInsertIntoDAO() = runTest {
        repository.addTag("book1", "\t\t")
        coVerify(exactly = 0) { bookTagDao.insert(any()) }
    }

    @Test
    fun addTag_withMixedWhitespace_doesNOTInsertIntoDAO() = runTest {
        repository.addTag("book1", " \t \n ")
        coVerify(exactly = 0) { bookTagDao.insert(any()) }
    }
}