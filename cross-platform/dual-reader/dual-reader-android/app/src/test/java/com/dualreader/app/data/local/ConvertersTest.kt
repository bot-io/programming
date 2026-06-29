package com.dualreader.app.data.local

import com.dualreader.app.domain.entities.BookChapter
import com.dualreader.app.domain.entities.BookFormat
import com.dualreader.app.domain.entities.PaginationStatus
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.time.LocalDateTime
import java.time.ZoneOffset

class ConvertersTest {

    private lateinit var converters: Converters

    @Before
    fun setUp() {
        converters = Converters()
    }

    // ── Timestamp ──────────────────────────────────────────────────

    @Test
    fun `fromTimestamp null returns null`() {
        assertNull(converters.fromTimestamp(null))
    }

    @Test
    fun `fromTimestamp converts epoch millis to LocalDateTime`() {
        // 123 ms non-zero to verify sub-second precision (DR-056)
        val epochMillis = 1_700_000_000_123L
        val result = converters.fromTimestamp(epochMillis)
        assertEquals(
            LocalDateTime.of(2023, 11, 14, 22, 13, 20, 123_000_000),
            result,
        )
    }

    @Test
    fun `toTimestamp null returns null`() {
        assertNull(converters.toTimestamp(null))
    }

    @Test
    fun `toTimestamp converts LocalDateTime to epoch millis`() {
        val dateTime = LocalDateTime.of(2024, 6, 15, 12, 30, 0)
        val expected = dateTime.atZone(ZoneOffset.UTC).toInstant().toEpochMilli()
        assertEquals(expected, converters.toTimestamp(dateTime))
    }

    @Test
    fun `timestamp round trip preserves value`() {
        val original = LocalDateTime.of(2024, 1, 1, 0, 0, 0)
        val restored = converters.fromTimestamp(converters.toTimestamp(original))
        assertEquals(original, restored)
    }

    @Test
    fun `timestamp round trip preserves millisecond precision`() {
        // DR-056: sub-second millis was silently dropped on round-trip.
        val original = LocalDateTime.of(2024, 6, 15, 10, 30, 45, 789_000_000)
        val restored = converters.fromTimestamp(converters.toTimestamp(original))
        assertEquals(original, restored)
    }

    // ── Chapters JSON ──────────────────────────────────────────────

    @Test
    fun `fromChaptersJson empty string returns empty list`() {
        assertTrue(converters.fromChaptersJson("").isEmpty())
    }

    @Test
    fun `fromChaptersJson empty array returns empty list`() {
        assertTrue(converters.fromChaptersJson("[]").isEmpty())
    }

    @Test
    fun `fromChaptersJson parses single chapter`() {
        val json = """[{"index":0,"title":"Chapter 1","level":0,"startIndex":0,"endIndex":10}]"""
        val result = converters.fromChaptersJson(json)
        assertEquals(1, result.size)
        assertEquals(BookChapter(0, "Chapter 1", 0, 0, 10), result[0])
    }

    @Test
    fun `fromChaptersJson parses multiple chapters`() {
        val json = """[{"index":0,"title":"Ch1","level":0,"startIndex":0,"endIndex":5},{"index":1,"title":"Ch2","level":1,"startIndex":6,"endIndex":10}]"""
        val result = converters.fromChaptersJson(json)
        assertEquals(2, result.size)
        assertEquals("Ch1", result[0].title)
        assertEquals("Ch2", result[1].title)
        assertEquals(1, result[1].level)
    }

    @Test
    fun `fromChaptersJson defaults missing optional fields to zero`() {
        val json = """[{"index":0,"title":"Minimal"}]"""
        val result = converters.fromChaptersJson(json)
        assertEquals(1, result.size)
        assertEquals(0, result[0].level)
        assertEquals(0, result[0].startIndex)
        assertEquals(0, result[0].endIndex)
    }

    @Test
    fun `toChaptersJson empty list returns empty array string`() {
        assertEquals("[]", converters.toChaptersJson(emptyList()))
    }

    @Test
    fun `toChaptersJson serializes chapters correctly`() {
        val chapters = listOf(
            BookChapter(0, "Chapter A", level = 0, startIndex = 0, endIndex = 5),
            BookChapter(1, "Chapter B", level = 1, startIndex = 6, endIndex = 10),
        )
        val json = converters.toChaptersJson(chapters)
        val restored = converters.fromChaptersJson(json)
        assertEquals(chapters, restored)
    }

    @Test
    fun `chapters round trip preserves data`() {
        val original = listOf(
            BookChapter(5, "Conclusion", 2, 100, 200),
            BookChapter(0, "Intro", 0, 0, 10),
        )
        val json = converters.toChaptersJson(original)
        val restored = converters.fromChaptersJson(json)
        assertEquals(original, restored)
    }

    // ── PaginationStatus ───────────────────────────────────────────

    @Test
    fun `fromPaginationStatus valid value returns enum`() {
        assertEquals(PaginationStatus.COMPLETED, converters.fromPaginationStatus("COMPLETED"))
        assertEquals(PaginationStatus.IN_PROGRESS, converters.fromPaginationStatus("IN_PROGRESS"))
        assertEquals(PaginationStatus.NOT_STARTED, converters.fromPaginationStatus("NOT_STARTED"))
        assertEquals(PaginationStatus.FAILED, converters.fromPaginationStatus("FAILED"))
    }

    @Test
    fun `fromPaginationStatus invalid value returns NOT_STARTED`() {
        assertEquals(PaginationStatus.NOT_STARTED, converters.fromPaginationStatus("INVALID"))
        assertEquals(PaginationStatus.NOT_STARTED, converters.fromPaginationStatus(""))
    }

    @Test
    fun `toPaginationStatus returns name`() {
        assertEquals("COMPLETED", converters.toPaginationStatus(PaginationStatus.COMPLETED))
        assertEquals("FAILED", converters.toPaginationStatus(PaginationStatus.FAILED))
    }

    @Test
    fun `pagination status round trip`() {
        for (status in PaginationStatus.entries) {
            val restored = converters.fromPaginationStatus(converters.toPaginationStatus(status))
            assertEquals(status, restored)
        }
    }

    // ── BookFormat ─────────────────────────────────────────────────

    @Test
    fun `fromBookFormat valid value returns enum`() {
        assertEquals(BookFormat.EPUB, converters.fromBookFormat("EPUB"))
    }

    @Test
    fun `fromBookFormat invalid value defaults to EPUB`() {
        assertEquals(BookFormat.EPUB, converters.fromBookFormat("PDF"))
        assertEquals(BookFormat.EPUB, converters.fromBookFormat(""))
    }

    @Test
    fun `toBookFormat returns name`() {
        assertEquals("EPUB", converters.toBookFormat(BookFormat.EPUB))
    }

    // ── Translations Map ───────────────────────────────────────────

    @Test
    fun `fromTranslationsJson null returns empty map`() {
        assertTrue(converters.fromTranslationsJson(null).isEmpty())
    }

    @Test
    fun `fromTranslationsJson blank returns empty map`() {
        assertTrue(converters.fromTranslationsJson("").isEmpty())
        assertTrue(converters.fromTranslationsJson("  ").isEmpty())
    }

    @Test
    fun `fromTranslationsJson empty object returns empty map`() {
        assertTrue(converters.fromTranslationsJson("{}").isEmpty())
    }

    @Test
    fun `fromTranslationsJson parses single entry`() {
        val json = """{"bg":"Здравей"}"""
        val result = converters.fromTranslationsJson(json)
        assertEquals(1, result.size)
        assertEquals("Здравей", result["bg"])
    }

    @Test
    fun `fromTranslationsJson parses multiple entries`() {
        val json = """{"bg":"Здравей","ru":"Привет","de":"Hallo"}"""
        val result = converters.fromTranslationsJson(json)
        assertEquals(3, result.size)
        assertEquals("Привет", result["ru"])
        assertEquals("Hallo", result["de"])
    }

    @Test
    fun `fromTranslationsJson invalid JSON returns empty map`() {
        assertTrue(converters.fromTranslationsJson("not json").isEmpty())
        assertTrue(converters.fromTranslationsJson("{broken").isEmpty())
    }

    @Test
    fun `fromTranslationsJson handles unicode values`() {
        val json = """{"ja":"こんにちは","zh":"你好","ar":"مرحبا"}"""
        val result = converters.fromTranslationsJson(json)
        assertEquals(3, result.size)
        assertEquals("こんにちは", result["ja"])
        assertEquals("你好", result["zh"])
        assertEquals("مرحبا", result["ar"])
    }

    @Test
    fun `toTranslationsJson empty map returns null`() {
        assertNull(converters.toTranslationsJson(emptyMap()))
    }

    @Test
    fun `toTranslationsJson single entry`() {
        val json = converters.toTranslationsJson(mapOf("bg" to "Здравей"))
        val restored = converters.fromTranslationsJson(json)
        assertEquals(mapOf("bg" to "Здравей"), restored)
    }

    @Test
    fun `translations round trip preserves data`() {
        val original = mapOf(
            "bg" to "Тест на български",
            "en" to "Test in English",
            "ja" to "日本語テスト",
        )
        val json = converters.toTranslationsJson(original)
        val restored = converters.fromTranslationsJson(json)
        assertEquals(original, restored)
    }

    @Test
    fun `translations round trip with empty values`() {
        val original = mapOf("bg" to "", "en" to "text")
        val json = converters.toTranslationsJson(original)
        val restored = converters.fromTranslationsJson(json)
        assertEquals(original, restored)
    }

    // ── Translation Timestamps Map ─────────────────────────────────

    @Test
    fun `fromTranslationTimestampsJson null returns empty map`() {
        assertTrue(converters.fromTranslationTimestampsJson(null).isEmpty())
    }

    @Test
    fun `fromTranslationTimestampsJson blank returns empty map`() {
        assertTrue(converters.fromTranslationTimestampsJson("").isEmpty())
    }

    @Test
    fun `fromTranslationTimestampsJson empty object returns empty map`() {
        assertTrue(converters.fromTranslationTimestampsJson("{}").isEmpty())
    }

    @Test
    fun `fromTranslationTimestampsJson parses entries`() {
        val json = """{"bg":1700000000000,"en":1700000001000}"""
        val result = converters.fromTranslationTimestampsJson(json)
        assertEquals(2, result.size)
        assertEquals(1_700_000_000_000L, result["bg"])
        assertEquals(1_700_000_001_000L, result["en"])
    }

    @Test
    fun `fromTranslationTimestampsJson invalid JSON returns empty map`() {
        assertTrue(converters.fromTranslationTimestampsJson("not json").isEmpty())
    }

    @Test
    fun `toTranslationTimestampsJson empty map returns null`() {
        assertNull(converters.toTranslationTimestampsJson(emptyMap()))
    }

    @Test
    fun `timestamps round trip preserves data`() {
        val original = mapOf(
            "bg" to 1_700_000_000_000L,
            "en" to 1_700_000_001_000L,
            "ja" to 1_700_000_002_000L,
        )
        val json = converters.toTranslationTimestampsJson(original)
        val restored = converters.fromTranslationTimestampsJson(json)
        assertEquals(original, restored)
    }
}
