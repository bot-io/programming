package com.dualreader.app.data.repository

import com.dualreader.app.data.local.dao.TranslationCacheDao
import com.dualreader.app.data.local.entity.TranslationCacheEntity
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.mockk
import kotlinx.coroutines.test.runTest
import org.junit.Test
import kotlin.test.assertEquals

/**
 * Regression test for DR-203: Translation cache cleanup must use composite key (textHash, sourceLang, targetLang)
 * instead of textHash alone to avoid deleting translations from other books.
 */
class TranslationCacheRepositoryImplDR203Test {

    @Test
    fun `deleteForTexts uses composite key with source language`() = runTest {
        // Arrange
        val mockDao = mockk<TranslationCacheDao>(relaxed = true)
        val repo = TranslationCacheRepositoryImpl(mockDao)
        val texts = listOf("Hello world", "Test text")
        val sourceLang = "en"

        // Act
        repo.deleteForTexts(texts, sourceLang)

        // Assert
        texts.forEach { text ->
            val expectedHash = TranslationCacheRepositoryImpl.sha256(text)
            coVerify(exactly = 1) { mockDao.deleteByHash(expectedHash, sourceLang) }
        }
    }

    @Test
    fun `deleteForTexts uses auto when sourceLang is null`() = runTest {
        // Arrange
        val mockDao = mockk<TranslationCacheDao>(relaxed = true)
        val repo = TranslationCacheRepositoryImpl(mockDao)
        val texts = listOf("Test text")
        val sourceLang: String? = null

        // Act
        repo.deleteForTexts(texts, sourceLang)

        // Assert
        val expectedHash = TranslationCacheRepositoryImpl.sha256("Test text")
        coVerify(exactly = 1) { mockDao.deleteByHash(expectedHash, "auto") }
    }

    @Test
    fun `deleteForTexts rejects blank texts`() = runTest {
        // Arrange
        val mockDao = mockk<TranslationCacheDao>(relaxed = true)
        val repo = TranslationCacheRepositoryImpl(mockDao)

        // Act & Assert
        try {
            repo.deleteForTexts(listOf("Valid text", "   ", ""), "en")
            throw AssertionError("Should have thrown IllegalArgumentException")
        } catch (e: IllegalArgumentException) {
            assertEquals("All texts in delete list must not be blank", e.message)
        }

        // Verify DAO was not called - deleteForTexts should fail before calling DAO
        coVerify(exactly = 0) { mockDao.deleteByHash(match { true }, match { true }) }
    }

    @Test
    fun `deleteForTexts only deletes entries matching source language`() = runTest {
        // Arrange
        val mockDao = mockk<TranslationCacheDao>(relaxed = true)
        val repo = TranslationCacheRepositoryImpl(mockDao)
        val text = "Hello world"
        val sourceLangEn = "en"
        val sourceLangEs = "es"

        // Act - delete only English entries
        repo.deleteForTexts(listOf(text), sourceLangEn)

        // Assert - verify delete was called for English only
        val expectedHash = TranslationCacheRepositoryImpl.sha256(text)
        coVerify(exactly = 1) { mockDao.deleteByHash(expectedHash, "en") }
        coVerify(exactly = 0) { mockDao.deleteByHash(expectedHash, "es") }
    }
}