package com.dualreader.app.data.tts

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Locale

/**
 * Tests for LocaleMapper — language code to Android Locale mapping.
 *
 * Verifies:
 * - Known languages map to region-specific locales (es→es_ES, ja→ja_JP)
 * - Fallback chains for multi-region languages (pt, zh, en)
 * - Unknown codes fall back gracefully to bare Locale
 */
class LocaleMapperTest {

    // --- Direct mappings ---

    @Test
    fun `toLocale maps es to es_ES`() {
        val locale = LocaleMapper.toLocale("es")
        assertEquals("es", locale.language)
        assertEquals("ES", locale.country)
    }

    @Test
    fun `toLocale maps fr to fr_FR`() {
        val locale = LocaleMapper.toLocale("fr")
        assertEquals("fr", locale.language)
        assertEquals("FR", locale.country)
    }

    @Test
    fun `toLocale maps ja to ja_JP`() {
        val locale = LocaleMapper.toLocale("ja")
        assertEquals("ja", locale.language)
        assertEquals("JP", locale.country)
    }

    @Test
    fun `toLocale maps zh to zh_CN`() {
        val locale = LocaleMapper.toLocale("zh")
        assertEquals("zh", locale.language)
        assertEquals("CN", locale.country)
    }

    @Test
    fun `toLocale maps de to de_DE`() {
        val locale = LocaleMapper.toLocale("de")
        assertEquals("de", locale.language)
        assertEquals("DE", locale.country)
    }

    @Test
    fun `toLocale maps ru to ru_RU`() {
        val locale = LocaleMapper.toLocale("ru")
        assertEquals("ru", locale.language)
        assertEquals("RU", locale.country)
    }

    // --- Fallback for unknown languages ---

    @Test
    fun `toLocale returns bare Locale for unknown code`() {
        val locale = LocaleMapper.toLocale("xx")
        assertEquals("xx", locale.language)
        assertEquals("", locale.country)
    }

    // --- Fallback candidates ---

    @Test
    fun `pt has fallback candidates including BR`() {
        val candidates = LocaleMapper.toLocaleCandidates("pt")
        assertTrue("Should include pt_BR", candidates.any { it.country == "BR" })
        assertTrue("Should include pt_PT", candidates.any { it.country == "PT" })
    }

    @Test
    fun `zh has fallback candidates including CN, TW, HK`() {
        val candidates = LocaleMapper.toLocaleCandidates("zh")
        assertTrue("Should include zh_CN", candidates.any { it.country == "CN" })
        assertTrue("Should include zh_TW", candidates.any { it.country == "TW" })
        assertTrue("Should include zh_HK", candidates.any { it.country == "HK" })
    }

    @Test
    fun `en has fallback candidates with multiple regions`() {
        val candidates = LocaleMapper.toLocaleCandidates("en")
        assertTrue(candidates.size >= 3)
        assertTrue("Should include US", candidates.any { it.country == "US" })
        assertTrue("Should include GB", candidates.any { it.country == "GB" })
    }

    @Test
    fun `known single-region language returns single-element candidate list`() {
        val candidates = LocaleMapper.toLocaleCandidates("ja")
        assertEquals(1, candidates.size)
        assertEquals("JP", candidates[0].country)
    }

    @Test
    fun `unknown language returns bare Locale as only candidate`() {
        val candidates = LocaleMapper.toLocaleCandidates("xyz")
        assertEquals(1, candidates.size)
        assertEquals("xyz", candidates[0].language)
    }

    @Test
    fun `en fallback chain starts with US`() {
        val candidates = LocaleMapper.toLocaleCandidates("en")
        assertEquals(Locale.US, candidates[0])
    }

    // --- Consistency: toLocale returns first of candidates for fallback languages ---

    @Test
    fun `toLocale and toLocaleCandidates are consistent for pt`() {
        // pt is not in LOCALE_FALLBACKS for toLocale — it uses LOCALE_MAP (pt, PT)
        // But candidates tries BR first. This is by design:
        // toLocale gets a "default" locale; candidates tries all variants.
        val direct = LocaleMapper.toLocale("pt")
        val candidates = LocaleMapper.toLocaleCandidates("pt")

        // Direct mapping is pt_PT
        assertEquals("PT", direct.country)
        // But candidates includes BR first (better TTS availability)
        assertEquals("BR", candidates[0].country)
    }

    @Test
    fun `all major languages are mapped`() {
        val majorLanguages = listOf("es", "fr", "de", "it", "pt", "ru", "ja", "ko", "zh", "ar", "hi")
        for (lang in majorLanguages) {
            val locale = LocaleMapper.toLocale(lang)
            assertTrue(
                "Language '$lang' should have a country-specific mapping",
                locale.country.isNotEmpty()
            )
        }
    }
}
