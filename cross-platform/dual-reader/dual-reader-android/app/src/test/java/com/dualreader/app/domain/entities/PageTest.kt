package com.dualreader.app.domain.entities

import org.junit.Assert.*
import org.junit.Test

class PageTest {

    private val basePage = Page(
        index = 0,
        bookId = "book1",
        originalText = "Hello world.",
        chapterIndex = 0,
    )

    // ── Translations map ────────────────────────────────────────────────

    @Test
    fun `effectiveTranslation - returns null when no translations`() {
        assertNull(basePage.effectiveTranslation("bg"))
    }

    @Test
    fun `effectiveTranslation - returns translation for language`() {
        val page = basePage.withTranslation("bg", "Здравей свят.")
        assertEquals("Здравей свят.", page.effectiveTranslation("bg"))
    }

    @Test
    fun `effectiveTranslation - returns null for different language`() {
        val page = basePage.withTranslation("bg", "Здравей.")
        assertNull(page.effectiveTranslation("de"))
    }

    @Test
    fun `withTranslation - adds first translation`() {
        val result = basePage.withTranslation("bg", "Здравей.")
        assertEquals(mapOf("bg" to "Здравей."), result.translations)
    }

    @Test
    fun `withTranslation - adds second language without losing first`() {
        val withBg = basePage.withTranslation("bg", "Здравей.")
        val withDe = withBg.withTranslation("de", "Hallo.")
        assertEquals("Здравей.", withDe.effectiveTranslation("bg"))
        assertEquals("Hallo.", withDe.effectiveTranslation("de"))
    }

    @Test
    fun `withTranslation - overwrites same language`() {
        val first = basePage.withTranslation("bg", "Old translation.")
        val updated = first.withTranslation("bg", "New translation.")
        assertEquals("New translation.", updated.effectiveTranslation("bg"))
        assertEquals(1, updated.translations.size)
    }

    @Test
    fun `hasTranslation - false when no translations`() {
        assertFalse(basePage.hasTranslation("bg"))
    }

    @Test
    fun `hasTranslation - true for translated language`() {
        val page = basePage.withTranslation("bg", "Здравей.")
        assertTrue(page.hasTranslation("bg"))
    }

    @Test
    fun `hasTranslation - false for different language`() {
        val page = basePage.withTranslation("bg", "Здравей.")
        assertFalse(page.hasTranslation("de"))
    }

    @Test
    fun `withTranslation - multiple languages preserves all`() {
        val page = basePage
            .withTranslation("bg", "БГ")
            .withTranslation("de", "ДЕ")
            .withTranslation("es", "ЕС")
            .withTranslation("fr", "ФР")
        assertEquals(4, page.translations.size)
        assertTrue(page.hasTranslation("bg"))
        assertTrue(page.hasTranslation("de"))
        assertTrue(page.hasTranslation("es"))
        assertTrue(page.hasTranslation("fr"))
    }
}
