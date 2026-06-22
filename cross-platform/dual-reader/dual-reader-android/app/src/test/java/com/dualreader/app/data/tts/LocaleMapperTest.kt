package com.dualreader.app.data.tts

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Locale

class LocaleMapperTest {

    // ── toLocale ──────────────────────────────────────────────────

    @Test
    fun `toLocale returns mapped locale for known code`() {
        val locale = LocaleMapper.toLocale("es")
        assertEquals("es", locale.language)
        assertEquals("ES", locale.country)
    }

    @Test
    fun `toLocale returns correct locale for French`() {
        val locale = LocaleMapper.toLocale("fr")
        assertEquals("fr", locale.language)
        assertEquals("FR", locale.country)
    }

    @Test
    fun `toLocale returns correct locale for Japanese`() {
        val locale = LocaleMapper.toLocale("ja")
        assertEquals("ja", locale.language)
        assertEquals("JP", locale.country)
    }

    @Test
    fun `toLocale returns correct locale for Chinese`() {
        val locale = LocaleMapper.toLocale("zh")
        assertEquals("zh", locale.language)
        assertEquals("CN", locale.country)
    }

    @Test
    fun `toLocale returns correct locale for Arabic`() {
        val locale = LocaleMapper.toLocale("ar")
        assertEquals("ar", locale.language)
        assertEquals("SA", locale.country)
    }

    @Test
    fun `toLocale falls back to bare Locale for unmapped code`() {
        val locale = LocaleMapper.toLocale("xx")
        assertEquals("xx", locale.language)
        assertEquals("", locale.country)
    }

    @Test
    fun `toLocale for empty string returns empty locale`() {
        val locale = LocaleMapper.toLocale("")
        assertEquals("", locale.language)
    }

    @Test
    fun `toLocale for all major mapped languages`() {
        val expected = mapOf(
            "de" to "DE",
            "it" to "IT",
            "pt" to "PT",
            "ru" to "RU",
            "ko" to "KR",
            "hi" to "IN",
            "tr" to "TR",
            "nl" to "NL",
            "pl" to "PL",
            "sv" to "SE",
            "uk" to "UA",
            "cs" to "CZ",
            "th" to "TH",
            "vi" to "VN",
            "id" to "ID",
            "el" to "GR",
            "he" to "IL",
            "fi" to "FI",
            "da" to "DK",
            "no" to "NO",
            "ro" to "RO",
            "hu" to "HU",
            "bg" to "BG",
            "hr" to "HR",
            "sk" to "SK",
            "sl" to "SI",
        )
        for ((code, country) in expected) {
            val locale = LocaleMapper.toLocale(code)
            assertEquals("Language $code", code, locale.language)
            assertEquals("Country for $code", country, locale.country)
        }
    }

    // ── toLocaleCandidates ────────────────────────────────────────

    @Test
    fun `toLocaleCandidates for Portuguese returns BR and PT variants`() {
        val candidates = LocaleMapper.toLocaleCandidates("pt")
        assertEquals(2, candidates.size)
        assertEquals("BR", candidates[0].country) // BR first (largest speaker base)
        assertEquals("PT", candidates[1].country)
    }

    @Test
    fun `toLocaleCandidates for Chinese returns 3 variants`() {
        val candidates = LocaleMapper.toLocaleCandidates("zh")
        assertEquals(3, candidates.size)
        assertEquals("CN", candidates[0].country)
        assertEquals("TW", candidates[1].country)
        assertEquals("HK", candidates[2].country)
    }

    @Test
    fun `toLocaleCandidates for English returns US, UK, AU, IN`() {
        val candidates = LocaleMapper.toLocaleCandidates("en")
        assertEquals(4, candidates.size)
        assertEquals("US", candidates[0].country)
        assertEquals("GB", candidates[1].country)
        assertEquals("AU", candidates[2].country)
        assertEquals("IN", candidates[3].country)
    }

    @Test
    fun `toLocaleCandidates for mapped language without fallback returns single locale`() {
        val candidates = LocaleMapper.toLocaleCandidates("es")
        assertEquals(1, candidates.size)
        assertEquals("ES", candidates[0].country)
    }

    @Test
    fun `toLocaleCandidates for unmapped language returns single bare locale`() {
        val candidates = LocaleMapper.toLocaleCandidates("xx")
        assertEquals(1, candidates.size)
        assertEquals("xx", candidates[0].language)
    }

    @Test
    fun `toLocaleCandidates never returns empty list`() {
        for (code in listOf("es", "fr", "en", "pt", "zh", "xx", "", "de")) {
            val candidates = LocaleMapper.toLocaleCandidates(code)
            assertTrue("Candidates for '$code' should not be empty", candidates.isNotEmpty())
        }
    }

    @Test
    fun `all toLocaleCandidates are non-null`() {
        for (code in listOf("es", "fr", "en", "pt", "zh", "xx")) {
            for (locale in LocaleMapper.toLocaleCandidates(code)) {
                assertNotNull(locale)
            }
        }
    }
}
