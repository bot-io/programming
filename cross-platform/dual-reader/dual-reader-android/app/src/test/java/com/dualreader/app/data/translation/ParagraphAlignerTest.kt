package com.dualreader.app.data.translation

import org.junit.Assert.*
import org.junit.Test

/**
 * DR-263: ParagraphAligner is now a defensive cleaner for legacy cache entries.
 *
 * Marker-based stitching was REMOVED in DR-263 after the user reported (twice)
 * that translation boxes mismatched their original segments: both ML Kit and
 * cloud LLMs strip/merge inline markers, so stitched batches could not be
 * reliably split back. The array-based `translatePages` endpoint replaced it.
 *
 * What remains: [ParagraphAligner.stripMarkers] cleans markers from pre-DR-263
 * cache entries (both `⟦N⟧` v1 and `@@N@@` v2 formats) before display.
 *
 * These tests lock in:
 * 1. Both marker formats are stripped from cache hits
 * 2. Normal text passes through unchanged
 * 3. hasMarkers only flags v2 @@N@@ (active marker detection)
 */
class ParagraphAlignerTest {

    // ── stripMarkers: v2 format (@@N@@) ────────────────────────────────────────

    @Test
    fun `stripMarkers removes v2 marker from start of text`() {
        assertEquals("Hola mundo.", ParagraphAligner.stripMarkers("@@1@@ Hola mundo."))
    }

    @Test
    fun `stripMarkers removes multiple v2 markers`() {
        assertEquals("Uno. Dos.", ParagraphAligner.stripMarkers("@@1@@ Uno. @@2@@ Dos."))
    }

    @Test
    fun `stripMarkers removes marker inside sentence`() {
        assertEquals("Texto con marcador.", ParagraphAligner.stripMarkers("Texto @@5@@ con marcador."))
    }

    @Test
    fun `stripMarkers removes large marker numbers`() {
        assertEquals("Fin.", ParagraphAligner.stripMarkers("@@12345@@ Fin."))
    }

    @Test
    fun `stripMarkers removes marker with newline after it`() {
        assertEquals("Uno.\nDos.", ParagraphAligner.stripMarkers("@@1@@ Uno.\n@@2@@ Dos."))
    }

    // ── stripMarkers: legacy v1 format (⟦N⟧) ───────────────────────────────────

    @Test
    fun `stripMarkers removes legacy v1 markers`() {
        assertEquals("Hola mundo.", ParagraphAligner.stripMarkers("\u27E61\u27E7 Hola mundo."))
    }

    @Test
    fun `stripMarkers removes multiple legacy markers`() {
        assertEquals("Uno. Dos.", ParagraphAligner.stripMarkers("\u27E61\u27E7 Uno. \u27E62\u27E7 Dos."))
    }

    @Test
    fun `stripMarkers removes legacy marker with newline`() {
        assertEquals("Uno.\nDos.", ParagraphAligner.stripMarkers("\u27E61\u27E7 Uno.\n\u27E62\u27E7 Dos."))
    }

    @Test
    fun `stripMarkers handles mixed v1 and v2 markers`() {
        assertEquals("Uno. Dos. Tres.",
            ParagraphAligner.stripMarkers("\u27E61\u27E7 Uno. @@2@@ Dos. \u27E63\u27E7 Tres."))
    }

    // ── stripMarkers: clean text passthrough ───────────────────────────────────

    @Test
    fun `stripMarkers leaves plain text unchanged`() {
        assertEquals("Just a normal sentence.", ParagraphAligner.stripMarkers("Just a normal sentence."))
    }

    @Test
    fun `stripMarkers leaves text with single at-signs unchanged`() {
        // Single @ is NOT a marker (markers are double @@N@@)
        assertEquals("user@example.com wrote @me", ParagraphAligner.stripMarkers("user@example.com wrote @me"))
    }

    @Test
    fun `stripMarkers leaves email addresses unchanged`() {
        assertEquals("Contact a@b.co.", ParagraphAligner.stripMarkers("Contact a@b.co."))
    }

    @Test
    fun `stripMarkers trims surrounding whitespace`() {
        assertEquals("Trimmed.", ParagraphAligner.stripMarkers("  Trimmed.  "))
    }

    @Test
    fun `stripMarkers handles empty string`() {
        assertEquals("", ParagraphAligner.stripMarkers(""))
    }

    @Test
    fun `stripMarkers preserves unicode content`() {
        assertEquals("你好世界", ParagraphAligner.stripMarkers("\u27E61\u27E7 你好世界"))
    }

    @Test
    fun `stripMarkers preserves cyrillic content`() {
        assertEquals("Привет мир.", ParagraphAligner.stripMarkers("@@1@@ Привет мир."))
    }

    // ── hasMarkers (v2 only) ───────────────────────────────────────────────────

    @Test
    fun `hasMarkers true for v2 marked text`() {
        assertTrue(ParagraphAligner.hasMarkers("@@1@@ Hello."))
    }

    @Test
    fun `hasMarkers false for plain text`() {
        assertFalse(ParagraphAligner.hasMarkers("Plain text."))
    }

    @Test
    fun `hasMarkers false for single at-signs`() {
        assertFalse(ParagraphAligner.hasMarkers("@home @work"))
    }

    @Test
    fun `hasMarkers false for legacy v1 markers`() {
        // Legacy markers are dead — only stripMarkers knows them
        assertFalse(ParagraphAligner.hasMarkers("\u27E61\u27E7 Hello."))
    }

    @Test
    fun `hasMarkers false for empty string`() {
        assertFalse(ParagraphAligner.hasMarkers(""))
    }
}
