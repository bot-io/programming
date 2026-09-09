package com.dualreader.app.data.repository

import com.dualreader.app.data.local.dao.TranslationCacheDao
import com.dualreader.app.data.local.entity.TranslationCacheEntity
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.mockk
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test

class TranslationCacheRepositoryImplTest {

    private lateinit var dao: TranslationCacheDao
    private lateinit var repo: TranslationCacheRepositoryImpl

    @Before
    fun setUp() {
        dao = mockk(relaxed = true)
        repo = TranslationCacheRepositoryImpl(dao)
    }

    // ── sha256 ────────────────────────────────────────────────────

    @Test
    fun `sha256 produces consistent hash for same input`() {
        val hash1 = TranslationCacheRepositoryImpl.sha256("hello")
        val hash2 = TranslationCacheRepositoryImpl.sha256("hello")
        assertEquals(hash1, hash2)
    }

    @Test
    fun `sha256 produces different hash for different input`() {
        val hash1 = TranslationCacheRepositoryImpl.sha256("hello")
        val hash2 = TranslationCacheRepositoryImpl.sha256("world")
        assert(hash1 != hash2)
    }

    @Test
    fun `sha256 returns 64-char hex string`() {
        val hash = TranslationCacheRepositoryImpl.sha256("test")
        assertEquals(64, hash.length)
    }

    @Test(expected = IllegalArgumentException::class)
    fun `sha256 for empty string throws IllegalArgumentException`() {
        TranslationCacheRepositoryImpl.sha256("")
    }

    @Test
    fun `sha256 for unicode text`() {
        val hash = TranslationCacheRepositoryImpl.sha256("你好世界")
        assertEquals(64, hash.length)
        assertNotNull(hash)
    }

    @Test(expected = IllegalArgumentException::class)
    fun `sha256 for whitespace-only string throws IllegalArgumentException`() {
        TranslationCacheRepositoryImpl.sha256("   ")
    }

    // ── get ───────────────────────────────────────────────────────

    @Test(expected = IllegalArgumentException::class)
    fun `get throws IllegalArgumentException for empty text`() = runTest {
        repo.get("", "en", "es")
    }

    @Test(expected = IllegalArgumentException::class)
    fun `get throws IllegalArgumentException for whitespace-only text`() = runTest {
        repo.get("   ", "en", "es")
    }

    @Test(expected = IllegalArgumentException::class)
    fun `get throws IllegalArgumentException for empty targetLang`() = runTest {
        repo.get("hello", "en", "")
    }

    @Test(expected = IllegalArgumentException::class)
    fun `get throws IllegalArgumentException for empty sourceLang`() = runTest {
        repo.get("hello", "", "es")
    }

    @Test(expected = IllegalArgumentException::class)
    fun `get throws IllegalArgumentException for whitespace-only sourceLang`() = runTest {
        repo.get("hello", "   ", "es")
    }

    @Test
    fun `get returns translatedText when entry exists`() = runTest {
        val text = "hello"
        val hash = TranslationCacheRepositoryImpl.sha256(text)
        coEvery { dao.get(hash, "auto", "es") } returns TranslationCacheEntity(
            textHash = hash,
            sourceLang = "auto",
            targetLang = "es",
            translatedText = "hola",
        )
        val result = repo.get(text, null, "es")
        assertEquals("hola", result)
    }

    @Test
    fun `get returns null when entry does not exist`() = runTest {
        coEvery { dao.get(any(), any(), any()) } returns null
        val result = repo.get("missing", "en", "es")
        assertNull(result)
    }

    @Test
    fun `get uses auto when sourceLang is null`() = runTest {
        coEvery { dao.get(any(), "auto", "es") } returns null
        repo.get("text", null, "es")
        coVerify { dao.get(any(), "auto", "es") }
    }

    @Test
    fun `get uses provided sourceLang when not null`() = runTest {
        coEvery { dao.get(any(), "en", "es") } returns null
        repo.get("text", "en", "es")
        coVerify { dao.get(any(), "en", "es") }
    }

    // ── put ───────────────────────────────────────────────────────

    @Test(expected = IllegalArgumentException::class)
    fun `put throws IllegalArgumentException for empty text`() = runTest {
        repo.put("", "en", "es", "hola", "model")
    }

    @Test(expected = IllegalArgumentException::class)
    fun `put throws IllegalArgumentException for whitespace-only text`() = runTest {
        repo.put("   ", "en", "es", "hola", "model")
    }

    @Test(expected = IllegalArgumentException::class)
    fun `put throws IllegalArgumentException for empty targetLang`() = runTest {
        repo.put("hello", "en", "", "hola", "model")
    }

    @Test(expected = IllegalArgumentException::class)
    fun `put throws IllegalArgumentException for empty sourceLang`() = runTest {
        repo.put("hello", "", "es", "hola", "model")
    }

    @Test(expected = IllegalArgumentException::class)
    fun `put throws IllegalArgumentException for whitespace-only sourceLang`() = runTest {
        repo.put("hello", "   ", "es", "hola", "model")
    }

    @Test
    fun `put inserts new entry when not exists`() = runTest {
        val text = "hello"
        val hash = TranslationCacheRepositoryImpl.sha256(text)
        coEvery { dao.get(hash, "auto", "es") } returns null

        repo.put(text, null, "es", "hola", "gemini-2.5-flash")

        coVerify {
            dao.upsert(match {
                it.textHash == hash &&
                it.sourceLang == "auto" &&
                it.targetLang == "es" &&
                it.translatedText == "hola" &&
                it.model == "gemini-2.5-flash" &&
                it.sourceText == "hello" // Under 500 chars
            })
        }
    }

    @Test
    fun `put updates existing entry preserving id and createdAt`() = runTest {
        val text = "hello"
        val hash = TranslationCacheRepositoryImpl.sha256(text)
        val existing = TranslationCacheEntity(
            id = 42,
            textHash = hash,
            sourceLang = "auto",
            targetLang = "es",
            translatedText = "old translation",
            model = "old-model",
            createdAt = 1000L,
            updatedAt = 2000L,
        )
        coEvery { dao.get(hash, "auto", "es") } returns existing

        repo.put(text, null, "es", "new translation", "new-model")

        coVerify {
            dao.upsert(match {
                it.id == 42L &&
                it.createdAt == 1000L &&
                it.translatedText == "new translation" &&
                it.model == "new-model" &&
                it.updatedAt > 2000L
            })
        }
    }

    @Test
    fun `put truncates sourceText to 500 chars`() = runTest {
        val longText = "a".repeat(600)
        coEvery { dao.get(any(), any(), any()) } returns null

        repo.put(longText, "en", "es", "translated", "model")

        coVerify {
            dao.upsert(match { it.sourceText.length == 500 })
        }
    }

    @Test
    fun `put stores exact text when under 500 chars`() = runTest {
        val shortText = "short text"
        coEvery { dao.get(any(), any(), any()) } returns null

        repo.put(shortText, "en", "es", "traducido", "model")

        coVerify {
            dao.upsert(match { it.sourceText == "short text" })
        }
    }

    // ── clearAll ──────────────────────────────────────────────────

    @Test
    fun `clearAll returns count before clearing`() = runTest {
        coEvery { dao.count() } returns 150
        val count = repo.clearAll()
        assertEquals(150, count)
        coVerify { dao.clearAll() }
    }

    @Test
    fun `clearAll returns 0 when cache empty`() = runTest {
        coEvery { dao.count() } returns 0
        val count = repo.clearAll()
        assertEquals(0, count)
    }

    // ── count ─────────────────────────────────────────────────────

    @Test
    fun `count delegates to dao count`() = runTest {
        coEvery { dao.count() } returns 42
        assertEquals(42, repo.count())
    }

    // ── deleteForTexts ────────────────────────────────────────────

    @Test(expected = IllegalArgumentException::class)
    fun `deleteForTexts throws IllegalArgumentException for empty text in list`() = runTest {
        repo.deleteForTexts(listOf("hello", "", "world"), "en")
    }

    @Test(expected = IllegalArgumentException::class)
    fun `deleteForTexts throws IllegalArgumentException for whitespace-only text in list`() = runTest {
        repo.deleteForTexts(listOf("hello", "   ", "world"), "en")
    }

    @Test
    fun `deleteForTexts deletes each text by hash with source language`() = runTest {
        val texts = listOf("hello", "world", "test")
        repo.deleteForTexts(texts, "en")

        for (text in texts) {
            val hash = TranslationCacheRepositoryImpl.sha256(text)
            coVerify { dao.deleteByHash(hash, "en") }
        }
    }

    @Test
    fun `deleteForTexts with empty list does nothing`() = runTest {
        repo.deleteForTexts(emptyList(), "en")
        coVerify(exactly = 0) { dao.deleteByHash(any(), any()) }
    }

    @Test
    fun `deleteForTexts with single text deletes one entry`() = runTest {
        repo.deleteForTexts(listOf("only one"), "en")
        coVerify(exactly = 1) { dao.deleteByHash(any(), any()) }
    }
}
