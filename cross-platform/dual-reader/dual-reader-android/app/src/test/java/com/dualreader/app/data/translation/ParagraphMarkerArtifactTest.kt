package com.dualreader.app.data.translation

import org.junit.Assert.*
import org.junit.Test

/**
 * DR-263: Marker artifacts must never reach the reader UI.
 *
 * History: marker-based stitching (v1 `⟦N⟧`, v2 `@@N@@`) was removed because
 * both ML Kit and cloud LLMs strip/merge inline markers — reported twice as
 * "translation boxes don't match original segments". The array-based
 * `translatePages` endpoint replaced stitching entirely.
 *
 * This suite locks in the defensive layer: even if a marker somehow survives
 * into a cached translation (old pre-DR-263 cache entries), [ParagraphAligner.stripMarkers]
 * removes every artifact before display.
 */
class ParagraphMarkerArtifactTest {

    // ── No marker artifacts in final displayed text ────────────────────────────

    @Test
    fun `cleaned text never contains v2 markers`() {
        val dirty = listOf(
            "@@1@@ Primero.",
            "Texto @@2@@ intermedio.",
            "@@10@@ Último con número grande.",
        )
        for (d in dirty) {
            val clean = ParagraphAligner.stripMarkers(d)
            assertFalse("Should not contain @@: '$clean'", clean.contains("@@"))
            assertTrue("Should not be blank: '$clean'", clean.isNotBlank())
        }
    }

    @Test
    fun `cleaned text never contains legacy brackets`() {
        val dirty = listOf(
            "\u27E61\u27E7 Primero.",
            "Texto \u27E62\u27E7 intermedio.",
            "\u27E612\u27E7 Número grande.",
        )
        for (d in dirty) {
            val clean = ParagraphAligner.stripMarkers(d)
            assertFalse("Should not contain ⟦: '$clean'", clean.contains("\u27E6"))
            assertFalse("Should not contain ⟧: '$clean'", clean.contains("\u27E7"))
            assertTrue("Should not be blank: '$clean'", clean.isNotBlank())
        }
    }

    @Test
    fun `cleaned text never contains marker numbers`() {
        // Stripping must remove the ENTIRE marker including the digits —
        // a stray "1" left behind changes the meaning of the sentence.
        val clean = ParagraphAligner.stripMarkers("@@1@@ Primero.")
        assertEquals("Primero.", clean)
        assertFalse(clean.startsWith("1"))
    }

    @Test
    fun `marker in the middle is stripped cleanly`() {
        assertEquals("Hola mundo.", ParagraphAligner.stripMarkers("Hola @@3@@ mundo."))
    }

    @Test
    fun `repeated markers are all stripped`() {
        val clean = ParagraphAligner.stripMarkers("@@1@@ A @@1@@ B @@1@@ C")
        assertEquals("A B C", clean)
    }

    @Test
    fun `markers with newlines are stripped cleanly`() {
        assertEquals("Uno\nDos", ParagraphAligner.stripMarkers("@@1@@ Uno\n@@2@@ Dos"))
    }

    // ── Real-world bug scenarios ───────────────────────────────────────────────

    @Test
    fun `user-reported dialogue fragments cache cleanup`() {
        // From the user's bug report (v1.0.101):
        // original: “Smarty! You think you’re some, now, don’t you?
        // next:     Oh, what a hat!
        // A pre-DR-263 cache entry might hold the merged, marker-tagged text
        val cachedDirty = "@@1@@ \u2014\u00A1Listillo! Te crees la gran cosa ahora, \u00BFno? \u00A1Vaya sombrero!"
        val clean = ParagraphAligner.stripMarkers(cachedDirty)
        assertFalse(clean.contains("@@"))
        assertTrue(clean.startsWith("\u2014\u00A1Listillo"))
    }

    @Test
    fun `stripMarkers is idempotent`() {
        val once = ParagraphAligner.stripMarkers("@@1@@ Hola @@2@@ mundo")
        val twice = ParagraphAligner.stripMarkers(once)
        assertEquals(once, twice)
    }

    // ── hasMarkers gating ──────────────────────────────────────────────────────

    @Test
    fun `hasMarkers detects markers that need stripping`() {
        assertTrue(ParagraphAligner.hasMarkers("@@1@@ Text"))
        assertTrue(ParagraphAligner.hasMarkers("Text @@99@@ more"))
    }

    @Test
    fun `hasMarkers ignores normal prose`() {
        val prose = listOf(
            "Hello world.",
            "Email me at a@b.com",
            "100% done @ noon",
            "\u201CSmarty! You think you\u2019re some, now, don\u2019t you?",
            "Oh, what a hat!",
        )
        for (p in prose) {
            assertFalse("'$p' should not be flagged", ParagraphAligner.hasMarkers(p))
        }
    }
}
