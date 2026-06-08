package com.dualreader.app.data.repository

import com.dualreader.app.data.local.dao.TranslationCacheDao
import com.dualreader.app.data.local.entity.TranslationCacheEntity
import io.mockk.*
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test

class TranslationCacheRepositoryImplTest {

    private lateinit var dao: TranslationCacheDao
    private lateinit var repository: TranslationCacheRepositoryImpl

    @Before
    fun setUp() {
        dao = mockk(relaxed = true)
        repository = TranslationCacheRepositoryImpl(dao)
    }

    @After
    fun tearDown() {
        unmockkAll()
    }

    // ─── SHA-256 hashing ────────────────────────────────────────────────

    @Test
    fun `sha256 produces consistent hash for same input`() {
        val hash1 = TranslationCacheRepositoryImpl.sha256("Hello world")
        val hash2 = TranslationCacheRepositoryImpl.sha256("Hello world")
        assertEquals(hash1, hash2)
    }

    @Test
    fun `sha256 produces different hash for different input`() {
        val hash1 = TranslationCacheRepositoryImpl.sha256("Hello world")
        val hash2 = TranslationCacheRepositoryImpl.sha256("Hello world!")
        assertNotEquals(hash1, hash2)
    }

    @Test
    fun `sha256 produces 64-char hex string`() {
        val hash = TranslationCacheRepositoryImpl.sha256("test")
        assertEquals(64, hash.length)
        assertTrue(hash.all { it in '0'..'9' || it in 'a'..'f' })
    }

    @Test
    fun `sha256 handles empty string`() {
        val hash = TranslationCacheRepositoryImpl.sha256("")
        assertEquals(64, hash.length)
        // Known SHA-256 of empty string
        assertEquals("e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", hash)
    }

    @Test
    fun `sha256 handles unicode text`() {
        val hash = TranslationCacheRepositoryImpl.sha256("Здравей, свят!")
        assertEquals(64, hash.length)
    }

    @Test
    fun `sha256 handles very long text`() {
        val longText = "a".repeat(100_000)
        val hash = TranslationCacheRepositoryImpl.sha256(longText)
        assertEquals(64, hash.length)
    }

    // ─── get() — cache lookup ───────────────────────────────────────────

    @Test
    fun `get returns cached translation when found`() = runTest {
        val text = "Hello world"
        val hash = TranslationCacheRepositoryImpl.sha256(text)
        val entity = TranslationCacheEntity(
            id = 1, textHash = hash, sourceLang = "en", targetLang = "bg",
            translatedText = "Здравей, свят", model = "gemini-3.5-flash",
        )
        coEvery { dao.get(hash, "en", "bg") } returns entity

        val result = repository.get(text, "en", "bg")

        assertEquals("Здравей, свят", result)
        coVerify(exactly = 1) { dao.get(hash, "en", "bg") }
    }

    @Test
    fun `get returns null when not found`() = runTest {
        val text = "Hello world"
        val hash = TranslationCacheRepositoryImpl.sha256(text)
        coEvery { dao.get(hash, "en", "bg") } returns null

        val result = repository.get(text, "en", "bg")

        assertNull(result)
        coVerify(exactly = 1) { dao.get(hash, "en", "bg") }
    }

    @Test
    fun `get treats null sourceLang as auto`() = runTest {
        val text = "Hello world"
        val hash = TranslationCacheRepositoryImpl.sha256(text)
        coEvery { dao.get(hash, "auto", "bg") } returns null

        repository.get(text, null, "bg")

        coVerify(exactly = 1) { dao.get(hash, "auto", "bg") }
    }

    @Test
    fun `get differentiates same text different target language`() = runTest {
        val text = "Hello world"
        val hash = TranslationCacheRepositoryImpl.sha256(text)
        coEvery { dao.get(hash, "en", "bg") } returns TranslationCacheEntity(
            id = 1, textHash = hash, sourceLang = "en", targetLang = "bg",
            translatedText = "Здравей, свят",
        )
        coEvery { dao.get(hash, "en", "de") } returns null

        assertEquals("Здравей, свят", repository.get(text, "en", "bg"))
        assertNull(repository.get(text, "en", "de"))
    }

    // ─── put() — cache store / update ───────────────────────────────────

    @Test
    fun `put stores new translation`() = runTest {
        val text = "Hello world"
        val hash = TranslationCacheRepositoryImpl.sha256(text)
        coEvery { dao.get(hash, "en", "bg") } returns null
        coEvery { dao.upsert(any()) } just Runs

        repository.put(text, "en", "bg", "Здравей, свят", "gemini-3.5-flash")

        coVerify {
            dao.upsert(match { entry ->
                entry.textHash == hash &&
                entry.sourceLang == "en" &&
                entry.targetLang == "bg" &&
                entry.translatedText == "Здравей, свят" &&
                entry.model == "gemini-3.5-flash" &&
                entry.sourceText == "Hello world" &&
                entry.id == 0L // New entry
            })
        }
    }

    @Test
    fun `put updates existing translation preserving id and createdAt`() = runTest {
        val text = "Hello world"
        val hash = TranslationCacheRepositoryImpl.sha256(text)
        val existing = TranslationCacheEntity(
            id = 42, textHash = hash, sourceLang = "en", targetLang = "bg",
            translatedText = "Old translation", model = "glm-4.7-flash",
            createdAt = 1000L, updatedAt = 1000L,
        )
        coEvery { dao.get(hash, "en", "bg") } returns existing
        coEvery { dao.upsert(any()) } just Runs

        repository.put(text, "en", "bg", "New translation", "gemini-3.5-flash")

        coVerify {
            dao.upsert(match { entry ->
                entry.id == 42L && // Preserved
                entry.createdAt == 1000L && // Preserved
                entry.translatedText == "New translation" &&
                entry.model == "gemini-3.5-flash" &&
                entry.updatedAt > 1000L // Updated
            })
        }
    }

    @Test
    fun `put truncates source text to 500 chars`() = runTest {
        val longText = "a".repeat(1000)
        val hash = TranslationCacheRepositoryImpl.sha256(longText)
        coEvery { dao.get(hash, "en", "bg") } returns null
        coEvery { dao.upsert(any()) } just Runs

        repository.put(longText, "en", "bg", "translation")

        coVerify {
            dao.upsert(match { entry ->
                entry.sourceText.length == 500 &&
                entry.sourceText == "a".repeat(500)
            })
        }
    }

    @Test
    fun `put treats null sourceLang as auto`() = runTest {
        val text = "Hello"
        val hash = TranslationCacheRepositoryImpl.sha256(text)
        coEvery { dao.get(hash, "auto", "bg") } returns null
        coEvery { dao.upsert(any()) } just Runs

        repository.put(text, null, "bg", "Здравей")

        coVerify {
            dao.upsert(match { entry ->
                entry.sourceLang == "auto"
            })
        }
    }

    // ─── clearAll() ─────────────────────────────────────────────────────

    @Test
    fun `clearAll returns count of deleted entries`() = runTest {
        coEvery { dao.count() } returns 42
        coEvery { dao.clearAll() } just Runs

        val deleted = repository.clearAll()

        assertEquals(42, deleted)
        coVerifyOrder {
            dao.count()
            dao.clearAll()
        }
    }

    @Test
    fun `clearAll with empty cache returns zero`() = runTest {
        coEvery { dao.count() } returns 0
        coEvery { dao.clearAll() } just Runs

        val deleted = repository.clearAll()

        assertEquals(0, deleted)
    }

    // ─── count() ────────────────────────────────────────────────────────

    @Test
    fun `count returns dao count`() = runTest {
        coEvery { dao.count() } returns 15

        assertEquals(15, repository.count())
    }

    @Test
    fun `count returns zero for empty cache`() = runTest {
        coEvery { dao.count() } returns 0

        assertEquals(0, repository.count())
    }

    // ─── Integration-style: get → put → get flow ────────────────────────

    @Test
    fun `full get-put-get cycle works correctly`() = runTest {
        val text = "The old man walked slowly."
        val hash = TranslationCacheRepositoryImpl.sha256(text)

        // First get: cache miss
        coEvery { dao.get(hash, "en", "bg") } returns null
        assertNull(repository.get(text, "en", "bg"))

        // Put: store translation
        val stored = TranslationCacheEntity(
            id = 1, textHash = hash, sourceLang = "en", targetLang = "bg",
            translatedText = "Старецът вървеше бавно.", model = "gemini-3.5-flash",
        )
        coEvery { dao.get(hash, "en", "bg") } returns stored

        // Second get: cache hit
        assertEquals("Старецът вървеше бавно.", repository.get(text, "en", "bg"))
    }

    @Test
    fun `same text different languages are independent`() = runTest {
        val text = "Hello"
        val hash = TranslationCacheRepositoryImpl.sha256(text)

        coEvery { dao.get(hash, "en", "bg") } returns TranslationCacheEntity(
            id = 1, textHash = hash, sourceLang = "en", targetLang = "bg",
            translatedText = "Здравей",
        )
        coEvery { dao.get(hash, "en", "de") } returns TranslationCacheEntity(
            id = 2, textHash = hash, sourceLang = "en", targetLang = "de",
            translatedText = "Hallo",
        )

        assertEquals("Здравей", repository.get(text, "en", "bg"))
        assertEquals("Hallo", repository.get(text, "en", "de"))
    }

    @Test
    fun `model upgrade overwrites old translation`() = runTest {
        val text = "Hello world"
        val hash = TranslationCacheRepositoryImpl.sha256(text)

        // First put with GLM model
        coEvery { dao.get(hash, "en", "bg") } returns null
        repository.put(text, "en", "bg", "Здравей, свят (GLM)", "glm-4.7-flash")

        // Simulate the entry was stored, now simulate re-translation
        val existingEntry = TranslationCacheEntity(
            id = 5, textHash = hash, sourceLang = "en", targetLang = "bg",
            translatedText = "Здравей, свят (GLM)", model = "glm-4.7-flash",
            createdAt = 1000L, updatedAt = 1000L,
        )
        coEvery { dao.get(hash, "en", "bg") } returns existingEntry

        // Re-put with Gemini model (upgrade)
        repository.put(text, "en", "bg", "Здравей, свят (Gemini)", "gemini-3.5-flash")

        coVerify {
            dao.upsert(match { entry ->
                entry.id == 5L && // Preserved
                entry.translatedText == "Здравей, свят (Gemini)" &&
                entry.model == "gemini-3.5-flash"
            })
        }
    }

    // ─── Delete for texts (book deletion) ────────────────────────────────

    @Test
    fun `deleteForTexts removes cache entries by hash`() = runTest {
        val texts = listOf("Page one text", "Page two text", "Page three text")
        val hashes = texts.map { TranslationCacheRepositoryImpl.sha256(it) }

        coEvery { dao.deleteByHash(any()) } just Runs

        repository.deleteForTexts(texts)

        coVerify(exactly = 3) { dao.deleteByHash(any()) }
        coVerify { dao.deleteByHash(hashes[0]) }
        coVerify { dao.deleteByHash(hashes[1]) }
        coVerify { dao.deleteByHash(hashes[2]) }
    }

    @Test
    fun `deleteForTexts with empty list does nothing`() = runTest {
        repository.deleteForTexts(emptyList())
        coVerify(exactly = 0) { dao.deleteByHash(any()) }
    }

    @Test
    fun `deleteForTexts hashes match put hashes`() = runTest {
        val text = "Some unique page content"
        val hash = TranslationCacheRepositoryImpl.sha256(text)

        coEvery { dao.get(any(), any(), any()) } returns null
        coEvery { dao.upsert(any()) } just Runs
        coEvery { dao.deleteByHash(any()) } just Runs

        // Put a translation
        repository.put(text, "en", "bg", "Някакъв превод")
        coVerify { dao.upsert(match { it.textHash == hash }) }

        // Delete by text should use the same hash
        repository.deleteForTexts(listOf(text))
        coVerify { dao.deleteByHash(hash) }
    }
}
