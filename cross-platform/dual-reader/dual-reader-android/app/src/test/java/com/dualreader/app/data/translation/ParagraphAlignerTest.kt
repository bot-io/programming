package com.dualreader.app.data.translation

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ParagraphAlignerTest {

    // ── splitParagraphs ──────────────────────────────────────────────────────

    @Test
    fun `splitParagraphs splits on double newline`() {
        val text = "First paragraph.\n\nSecond paragraph.\n\nThird paragraph."
        val paras = ParagraphAligner.splitParagraphs(text)
        assertEquals(3, paras.size)
        assertEquals("First paragraph.", paras[0])
        assertEquals("Second paragraph.", paras[1])
        assertEquals("Third paragraph.", paras[2])
    }

    @Test
    fun `splitParagraphs handles multiple consecutive newlines`() {
        val text = "Para one.\n\n\n\nPara two."
        val paras = ParagraphAligner.splitParagraphs(text)
        assertEquals(2, paras.size)
    }

    @Test
    fun `splitParagraphs filters blank paragraphs`() {
        val text = "Real content.\n\n   \n\nAlso real."
        val paras = ParagraphAligner.splitParagraphs(text)
        assertEquals(2, paras.size)
    }

    @Test
    fun `splitParagraphs handles single paragraph`() {
        val text = "Just one paragraph with no breaks."
        val paras = ParagraphAligner.splitParagraphs(text)
        assertEquals(1, paras.size)
    }

    @Test
    fun `splitParagraphs handles empty string`() {
        val paras = ParagraphAligner.splitParagraphs("")
        assertEquals(0, paras.size)
    }

    // ── align ────────────────────────────────────────────────────────────────

    @Test
    fun `align perfect 1-to-1 match`() {
        val original = "Hello world.\n\nGoodbye world.\n\nThird paragraph."
        val translated = "Hola mundo.\n\nAdiós mundo.\n\nTercer párrafo."
        val pairs = ParagraphAligner.align(original, translated)
        assertEquals(3, pairs.size)
        assertEquals("Hello world.", pairs[0].first)
        assertEquals("Hola mundo.", pairs[0].second)
        assertEquals("Goodbye world.", pairs[1].first)
        assertEquals("Adiós mundo.", pairs[1].second)
    }

    @Test
    fun `align handles translation with fewer paragraphs (merged by LLM)`() {
        val original = "First original.\n\nSecond original.\n\nThird original."
        val translated = "First and second combined.\n\nThird translated."
        val pairs = ParagraphAligner.align(original, translated)
        assertEquals(3, pairs.size)
        // Proportional: orig[0]→trans[0], orig[1]→trans[0], orig[2]→trans[1]
        assertEquals("First and second combined.", pairs[0].second)
    }

    @Test
    fun `align handles translation with more paragraphs (split by LLM)`() {
        val original = "First original paragraph.\n\nSecond original paragraph."
        val translated = "First part A.\n\nFirst part B.\n\nSecond translated."
        val pairs = ParagraphAligner.align(original, translated)
        assertEquals(2, pairs.size)
        // orig[0] → trans[0] (proportional), orig[1] → trans[2]
        assertTrue(pairs[0].second.isNotBlank())
        assertTrue(pairs[1].second.isNotBlank())
    }

    @Test
    fun `align with empty translation returns pairs with empty translations`() {
        val original = "Some text.\n\nMore text."
        val translated = ""
        val pairs = ParagraphAligner.align(original, translated)
        assertEquals(2, pairs.size)
        assertEquals("", pairs[0].second)
        assertEquals("", pairs[1].second)
    }

    @Test
    fun `align with single paragraph on both sides`() {
        val original = "Single paragraph."
        val translated = "Single traducción."
        val pairs = ParagraphAligner.align(original, translated)
        assertEquals(1, pairs.size)
        assertEquals("Single paragraph.", pairs[0].first)
        assertEquals("Single traducción.", pairs[0].second)
    }

    @Test
    fun `align preserves long text with many paragraphs`() {
        val origParas = (1..10).joinToString("\n\n") { "Paragraph $it of original." }
        val transParas = (1..10).joinToString("\n\n") { "Párrafo $it de traducción." }
        val pairs = ParagraphAligner.align(origParas, transParas)
        assertEquals(10, pairs.size)
        assertEquals("Paragraph 1 of original.", pairs[0].first)
        assertEquals("Párrafo 1 de traducción.", pairs[0].second)
        assertEquals("Paragraph 10 of original.", pairs[9].first)
        assertEquals("Párrafo 10 de traducción.", pairs[9].second)
    }

    @Test
    fun `align handles paragraphs with trailing whitespace`() {
        val original = "Paragraph one.  \n\n  Paragraph two."
        val translated = "Párrafo uno.\n\nPárrafo dos."
        val pairs = ParagraphAligner.align(original, translated)
        assertEquals(2, pairs.size)
        assertEquals("Paragraph one.", pairs[0].first)
        assertEquals("Párrafo uno.", pairs[0].second)
    }

    // ── injectMarkers (DR-013) ───────────────────────────────────────────────

    @Test
    fun `injectMarkers returns empty string for empty list`() {
        val result = ParagraphAligner.injectMarkers(emptyList())
        assertEquals("", result)
    }

    @Test
    fun `injectMarkers marks single paragraph`() {
        val result = ParagraphAligner.injectMarkers(listOf("Hello world."))
        assertEquals("\u27E61\u27E7 Hello world.", result)
    }

    @Test
    fun `injectMarkers marks multiple paragraphs with sequential numbers`() {
        val result = ParagraphAligner.injectMarkers(listOf("First.", "Second.", "Third."))
        assertEquals("\u27E61\u27E7 First.\n\n\u27E62\u27E7 Second.\n\n\u27E63\u27E7 Third.", result)
    }

    @Test
    fun `injectMarkers trims whitespace from paragraphs`() {
        val result = ParagraphAligner.injectMarkers(listOf("  Spaced.  ", "\tTabbed.\t"))
        assertEquals("\u27E61\u27E7 Spaced.\n\n\u27E62\u27E7 Tabbed.", result)
    }

    @Test
    fun `injectMarkers preserves Unicode content`() {
        val paras = listOf("Здравей свят.", "你好世界。", "🎉 Emoji para.")
        val result = ParagraphAligner.injectMarkers(paras)
        assertTrue(result.contains("\u27E61\u27E7 Здравей свят."))
        assertTrue(result.contains("\u27E62\u27E7 你好世界。"))
        assertTrue(result.contains("\u27E63\u27E7 🎉 Emoji para."))
    }

    @Test
    fun `injectMarkers handles paragraph containing marker-like text`() {
        // Natural text with brackets should NOT be confused with markers
        val result = ParagraphAligner.injectMarkers(listOf("See [1] for reference."))
        assertEquals("\u27E61\u27E7 See [1] for reference.", result)
    }

    // ── extractByMarkers (DR-013) ────────────────────────────────────────────

    @Test
    fun `extractByMarkers extracts perfectly preserved markers`() {
        val translated = "\u27E61\u27E7 Hola mundo.\n\n\u27E62\u27E7 Adiós mundo.\n\n\u27E63\u27E7 Tercer párrafo."
        val result = ParagraphAligner.extractByMarkers(translated, 3)
        assertNotNull(result)
        assertEquals(3, result!!.size)
        assertEquals("Hola mundo.", result[0])
        assertEquals("Adiós mundo.", result[1])
        assertEquals("Tercer párrafo.", result[2])
    }

    @Test
    fun `extractByMarkers returns null when no markers present`() {
        val translated = "Hola mundo.\n\nAdiós mundo.\n\nTercer párrafo."
        val result = ParagraphAligner.extractByMarkers(translated, 3)
        assertNull(result)
    }

    @Test
    fun `extractByMarkers returns null when fewer markers than expected`() {
        // Only 2 markers for 3 expected paragraphs — LLM stripped one
        val translated = "\u27E61\u27E7 First and second merged.\n\n\u27E63\u27E7 Third."
        val result = ParagraphAligner.extractByMarkers(translated, 3)
        assertNull(result)
    }

    @Test
    fun `extractByMarkers trims to expected when extra markers present`() {
        // LLM added extra markers
        val translated = "\u27E61\u27E7 Uno.\n\n\u27E62\u27E7 Dos.\n\n\u27E63\u27E7 Tres.\n\n\u27E64\u27E7 Extra."
        val result = ParagraphAligner.extractByMarkers(translated, 3)
        assertNotNull(result)
        assertEquals(3, result!!.size)
        assertEquals("Uno.", result[0])
        assertEquals("Dos.", result[1])
        assertEquals("Tres.", result[2])
    }

    @Test
    fun `extractByMarkers handles markers with surrounding whitespace`() {
        val translated = "\u27E61\u27E7   Spaced out.   \n\n\u27E62\u27E7  Also spaced."
        val result = ParagraphAligner.extractByMarkers(translated, 2)
        assertNotNull(result)
        assertEquals(2, result!!.size)
        assertEquals("Spaced out.", result[0])
        assertEquals("Also spaced.", result[1])
    }

    @Test
    fun `extractByMarkers handles markers on separate lines`() {
        val translated = "\u27E61\u27E7\nFirst paragraph.\n\n\u27E62\u27E7\nSecond paragraph."
        val result = ParagraphAligner.extractByMarkers(translated, 2)
        assertNotNull(result)
        assertEquals(2, result!!.size)
        assertEquals("First paragraph.", result[0])
        assertEquals("Second paragraph.", result[1])
    }

    @Test
    fun `extractByMarkers handles single paragraph`() {
        val translated = "\u27E61\u27E7 Only one."
        val result = ParagraphAligner.extractByMarkers(translated, 1)
        assertNotNull(result)
        assertEquals(1, result!!.size)
        assertEquals("Only one.", result[0])
    }

    @Test
    fun `extractByMarkers handles empty content between markers`() {
        val translated = "\u27E61\u27E7 Real content.\n\n\u27E62\u27E7 \n\n\u27E63\u27E7 More content."
        val result = ParagraphAligner.extractByMarkers(translated, 3)
        // The empty middle segment is filtered out, leaving 2 non-empty for 3 expected → null
        assertNull(result)
    }

    @Test
    fun `extractByMarkers handles markers with leading text before first marker`() {
        val translated = "Some preamble text.\n\n\u27E61\u27E7 First.\n\n\u27E62\u27E7 Second."
        val result = ParagraphAligner.extractByMarkers(translated, 2)
        assertNotNull(result)
        assertEquals(2, result!!.size)
        // Preamble is ignored — content starts after first marker
        assertEquals("First.", result[0])
        assertEquals("Second.", result[1])
    }

    // ── Round-trip: inject → extract ─────────────────────────────────────────

    @Test
    fun `round-trip inject then extract preserves paragraph count`() {
        val originals = listOf(
            "The quick brown fox jumps over the lazy dog.",
            "Mary had a little lamb, its fleece was white as snow.",
            "To be or not to be, that is the question.",
        )
        val marked = ParagraphAligner.injectMarkers(originals)
        // Simulate LLM preserving markers (identity "translation")
        val extracted = ParagraphAligner.extractByMarkers(marked, originals.size)
        assertNotNull(extracted)
        assertEquals(originals.size, extracted!!.size)
        for (i in originals.indices) {
            assertEquals(originals[i], extracted[i])
        }
    }

    @Test
    fun `round-trip with translated content preserves alignment`() {
        val originals = listOf("Hello.", "Goodbye.", "Thank you.")
        val translations = listOf("Hola.", "Adiós.", "Gracias.")
        val marked = ParagraphAligner.injectMarkers(originals)
        // Simulate LLM translating while preserving markers
        val fakeTranslation = "\u27E61\u27E7 ${translations[0]}\n\n\u27E62\u27E7 ${translations[1]}\n\n\u27E63\u27E7 ${translations[2]}"
        val extracted = ParagraphAligner.extractByMarkers(fakeTranslation, originals.size)
        assertNotNull(extracted)
        assertEquals(3, extracted!!.size)
        assertEquals("Hola.", extracted[0])
        assertEquals("Adiós.", extracted[1])
        assertEquals("Gracias.", extracted[2])
    }

    // ── hasMarkers / stripMarkers ────────────────────────────────────────────

    @Test
    fun `hasMarkers returns true for marked text`() {
        val text = "\u27E61\u27E7 Hello.\n\n\u27E62\u27E7 World."
        assertTrue(ParagraphAligner.hasMarkers(text))
    }

    @Test
    fun `hasMarkers returns false for unmarked text`() {
        val text = "Hello.\n\nWorld."
        assertFalse(ParagraphAligner.hasMarkers(text))
    }

    @Test
    fun `hasMarkers returns false for natural bracket text`() {
        // [1] is NOT a marker — our markers use ⟦⟧ not []
        val text = "See [1] and [2] for references."
        assertFalse(ParagraphAligner.hasMarkers(text))
    }

    @Test
    fun `stripMarkers removes all markers`() {
        val text = "\u27E61\u27E7 Hello.\n\n\u27E62\u27E7 World."
        val stripped = ParagraphAligner.stripMarkers(text)
        assertEquals("Hello.\n\nWorld.", stripped)
    }

    @Test
    fun `stripMarkers leaves unmarked text unchanged`() {
        val text = "Hello.\n\nWorld."
        assertEquals("Hello.\n\nWorld.", ParagraphAligner.stripMarkers(text))
    }

    // ── Edge cases for DR-013 integration ────────────────────────────────────

    @Test
    fun `injectMarkers with large batch produces numbered sequence`() {
        val paras = (1..15).map { "Paragraph $it." }
        val marked = ParagraphAligner.injectMarkers(paras)
        for (i in 1..15) {
            assertTrue("Should contain marker $i", marked.contains("\u27E6$i\u27E7"))
        }
    }

    @Test
    fun `extractByMarkers handles Cyrillic content correctly`() {
        val translated = "\u27E61\u27E7 Здравей, свят!\n\n\u27E62\u27E7 Довиждане, свят!"
        val result = ParagraphAligner.extractByMarkers(translated, 2)
        assertNotNull(result)
        assertEquals(2, result!!.size)
        assertEquals("Здравей, свят!", result[0])
        assertEquals("Довиждане, свят!", result[1])
    }

    @Test
    fun `extractByMarkers handles CJK content correctly`() {
        val translated = "\u27E61\u27E7 你好世界。\n\n\u27E62\u27E7 再见世界。"
        val result = ParagraphAligner.extractByMarkers(translated, 2)
        assertNotNull(result)
        assertEquals(2, result!!.size)
        assertEquals("你好世界。", result[0])
        assertEquals("再见世界。", result[1])
    }

    @Test
    fun `markers do not appear in normal English text`() {
        val text = "This is a normal paragraph with [brackets] and {braces} and (parens)."
        assertFalse(ParagraphAligner.hasMarkers(text))
    }

    @Test
    fun `markers do not appear in normal Bulgarian text`() {
        val text = "Това е нормален параграф с [скоби] и {фигурни скоби}."
        assertFalse(ParagraphAligner.hasMarkers(text))
    }
}
